#!/bin/bash
# 应用 qmd-defensive-parse patch 到 production，含完整 backup + syntax check + parser test
# 失败自动回滚。运行后 gateway 还需 SIGUSR1 hot-reload 才生效。

set -uo pipefail

DIST="/usr/lib/node_modules/openclaw/dist"
TARGET="$(ls $DIST/engine-qmd-*.js | head -1)"
echo "[apply] target: $TARGET"

# 1. 一次性外部 backup（不依赖 patch 脚本自带的 .bak）
EXT_BACKUP="${TARGET}.pre-defensive-patch-$(date -u +%Y%m%dT%H%M%SZ)"
echo "[apply] external backup: $EXT_BACKUP"
cp -p "$TARGET" "$EXT_BACKUP"

# 2. 应用 patch
echo "[apply] running patch script..."
node /home/admindaniel/workspace/projects/context-tower-article/remediation/_apply-qmd-defensive-parse.js
RC=$?
if [ $RC -ne 0 ]; then
  echo "[apply] PATCH FAILED rc=$RC, reverting..."
  cp -p "$EXT_BACKUP" "$TARGET"
  exit 1
fi

# 3. Node syntax check
echo "[apply] syntax check..."
if ! node --check "$TARGET"; then
  echo "[apply] SYNTAX CHECK FAILED, reverting..."
  cp -p "$EXT_BACKUP" "$TARGET"
  exit 1
fi
echo "[apply] syntax OK"

# 4. 直接 import production 文件跑 parser 测试
echo "[apply] running parser test against production patched file..."
cat > /tmp/test-prod-patched.mjs <<JSEOF
import { s as parseQmdQueryJson } from "$TARGET";
const cases = [
  { name: "valid JSON array", stdout: '[{"docid":"#a","score":1}]' },
  { name: "warning + JSON", stdout: "Warning: collection 'x' not found, skipping\n[{\"docid\":\"#a\"}]" },
  { name: "Usage screen (THE BUG)", stdout: "Usage: qmd query [options] <query>" },
  { name: "garbled non-JSON", stdout: "Some random error text" },
  { name: "empty stdout with stderr", stdout: "", stderr: "qmd: connection refused" },
  { name: "no results found", stdout: "No results found." },
];
let ok=0, fail=0;
for (const c of cases) {
  try {
    const out = parseQmdQueryJson(c.stdout, c.stderr || "");
    console.log(\`PASS: \${c.name} -> array(len=\${out.length})\`);
    ok++;
  } catch(e) {
    console.log(\`FAIL: \${c.name} -> \${e.message}\`);
    fail++;
  }
}
console.log(\`---\\n\${fail===0 ? "ALL TESTS PASSED ("+ok+")" : fail+" FAILED"}\`);
process.exit(fail === 0 ? 0 : 1);
JSEOF

if ! node /tmp/test-prod-patched.mjs; then
  echo "[apply] PARSER TEST FAILED, reverting..."
  rm -f /tmp/test-prod-patched.mjs
  cp -p "$EXT_BACKUP" "$TARGET"
  exit 1
fi
rm -f /tmp/test-prod-patched.mjs
echo
echo "[apply] ✅ ALL CHECKS PASSED. Patch live in target file."
echo "[apply] backup retained at: $EXT_BACKUP"
echo "[apply] next: SIGUSR1 to gateway (pid 652738) to hot-reload"
