#!/usr/bin/env node
/**
 * Patch: defensive parseQmdQueryJson
 *
 * 起因：当 qmd CLI 收到 -c <collection> 但该 collection 在 qmd registry
 * 暂时不可见时（e.g. 索引漂移、collection 重命名、空 query），qmd 在 stdout
 * 打印 "Warning: collection 'X' not found, skipping" 或 "Usage: qmd query ..."
 * 等非 JSON 文本，下游 parseQmdQueryJson 在以下场景仍会抛错：
 *
 *   - stdout 是 "Usage: qmd query [options] <query>" (空 query 触发的 CLI 帮助)
 *   - stdout 是非 JSON 错误文本且没有可恢复的 [...] 片段
 *
 * 一旦抛错，runQueryAcrossCollections 整个 for 循环立刻中断，主调用方
 * memory_search 退化到 builtin backend (慢 12s+ 且 hits=0)，导致 active-memory
 * 主动召回大面积失效（实测最近 50 次调用约 43% 失败）。
 *
 * 修复策略：把 parseQmdQueryJson 内部的所有 throw 改成 log.warn + return []，
 * 这样：
 *   - 多 collection 路径仍可继续遍历其他 collection
 *   - active-memory 拿到 [] 比拿到 builtin fallback 慢路径更好
 *   - 真问题仍记录在日志中可追溯
 *
 * 幂等：用 sentinel 注释 "// PATCH:qmd-defensive-parse" 检测是否已应用。
 *
 * 升级风险：如果 OpenClaw 升级修改了 parseQmdQueryJson 函数体，本脚本会
 * 失败（找不到匹配段），需要重新对齐。所以每次应用前先 grep sentinel，
 * 已应用就跳过；找不到目标块就报错让 ExecStartPre 失败（fail closed）。
 */
"use strict";

const fs = require("fs");
const path = require("path");

const DIST_DIR = process.env.OPENCLAW_DIST_DIR || "/usr/lib/node_modules/openclaw/dist";
const SENTINEL = "// PATCH:qmd-defensive-parse";

function findEngineQmdFile() {
  const files = fs.readdirSync(DIST_DIR)
    .filter(f => /^engine-qmd-[A-Za-z0-9_-]+\.js$/.test(f))
    .map(f => path.join(DIST_DIR, f));
  if (files.length === 0) {
    throw new Error(`No engine-qmd-*.js found in ${DIST_DIR}`);
  }
  // 选 mtime 最新的，规避升级残留旧文件
  files.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
  return files[0];
}

function applyPatch(file) {
  const original = fs.readFileSync(file, "utf8");
  if (original.includes(SENTINEL)) {
    console.log(`[patch:qmd-defensive-parse] already applied to ${path.basename(file)}, skipping`);
    return;
  }

  // 目标 1: 空 stdout 抛错改为返回 []
  const target1 = `if (!trimmedStdout) {
		const message = \`stdout empty\${trimmedStderr ? \` (stderr: \${summarizeQmdStderr(trimmedStderr)})\` : ""}\`;
		log.warn(\`qmd query returned invalid JSON: \${message}\`);
		throw new Error(\`qmd query returned invalid JSON: \${message}\`);
	}`;

  const replacement1 = `if (!trimmedStdout) {
		const message = \`stdout empty\${trimmedStderr ? \` (stderr: \${summarizeQmdStderr(trimmedStderr)})\` : ""}\`;
		log.warn(\`qmd query returned invalid JSON: \${message}; treating as no-results\`); ${SENTINEL}
		return [];
	}
	// PATCH:qmd-defensive-parse: 空 query 触发 qmd CLI 打印 Usage screen，识别后返回 []
	if (/^usage:\\s/i.test(trimmedStdout.split("\\n")[0] || "")) {
		log.warn("qmd query returned CLI usage screen (likely empty/invalid query); treating as no-results");
		return [];
	}`;

  if (!original.includes(target1)) {
    throw new Error(`[patch:qmd-defensive-parse] target1 (empty-stdout throw) not found in ${path.basename(file)}; aborting (file may have changed structure)`);
  }

  let patched = original.replace(target1, replacement1);

  // 目标 2: parse-fail 抛错改为返回 []
  const target2 = `try {
		const parsed = parseQmdQueryResultArray(trimmedStdout);
		if (parsed !== null) return parsed;
		const noisyPayload = extractBalancedJsonPrefix(trimmedStdout, { openers: ["["] })?.json;
		if (!noisyPayload) throw new Error("qmd query JSON response was not an array");
		const fallback = parseQmdQueryResultArray(noisyPayload);
		if (fallback !== null) return fallback;
		throw new Error("qmd query JSON response was not an array");
	} catch (err) {
		const message = formatErrorMessage(err);
		log.warn(\`qmd query returned invalid JSON: \${message}\`);
		throw new Error(\`qmd query returned invalid JSON: \${message}\`, { cause: err });
	}`;

  const replacement2 = `try {
		const parsed = parseQmdQueryResultArray(trimmedStdout);
		if (parsed !== null) return parsed;
		const noisyPayload = extractBalancedJsonPrefix(trimmedStdout, { openers: ["["] })?.json;
		if (!noisyPayload) {
			log.warn(\`qmd query JSON response was not an array; stdout snippet: \${summarizeQmdStderr(trimmedStdout)}; treating as no-results\`);
			return [];
		}
		const fallback = parseQmdQueryResultArray(noisyPayload);
		if (fallback !== null) return fallback;
		log.warn("qmd query JSON response was not an array (after extraction); treating as no-results");
		return [];
	} catch (err) {
		const message = formatErrorMessage(err);
		log.warn(\`qmd query parse error: \${message}; treating as no-results\`);
		return [];
	}`;

  if (!patched.includes(target2)) {
    throw new Error(`[patch:qmd-defensive-parse] target2 (parse-fail throw block) not found in ${path.basename(file)}; aborting`);
  }

  patched = patched.replace(target2, replacement2);

  // 备份原文件 (gateway 启动前每次跑一遍，备份避免覆盖)
  const backupFile = `${file}.bak-qmd-defensive-parse`;
  if (!fs.existsSync(backupFile)) {
    fs.writeFileSync(backupFile, original);
  }
  fs.writeFileSync(file, patched);
  console.log(`[patch:qmd-defensive-parse] applied to ${path.basename(file)} (backup: ${path.basename(backupFile)})`);
}

function main() {
  const file = findEngineQmdFile();
  console.log(`[patch:qmd-defensive-parse] target: ${file}`);
  applyPatch(file);
}

main();
