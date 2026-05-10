#!/bin/bash
# 在临时副本上测试 qmd-defensive-parse patch，不动 production
set -u

SRC="/usr/lib/node_modules/openclaw/dist"
TMP=$(mktemp -d)
echo "[test] tmp dir: $TMP"

# 复制 dist 整个目录到临时区（patch 脚本用 dist 整体识别 hash 文件）
cp -r "$SRC" "$TMP/dist"

echo "=== 应用 patch ==="
OPENCLAW_DIST_DIR="$TMP/dist" node /home/admindaniel/workspace/projects/context-tower-article/remediation/_apply-qmd-defensive-parse.js

echo
echo "=== 再次应用（验证幂等） ==="
OPENCLAW_DIST_DIR="$TMP/dist" node /home/admindaniel/workspace/projects/context-tower-article/remediation/_apply-qmd-defensive-parse.js

echo
echo "=== diff 概览 ==="
PATCHED=$(ls "$TMP/dist"/engine-qmd-*.js | head -1)
ORIG=$(ls "$SRC"/engine-qmd-*.js | head -1)
diff -u "$ORIG" "$PATCHED" | head -80

echo
echo "=== 用 patched 副本跑一遍 parser 测试 ==="
cat > /tmp/test-patched-parser.mjs <<JSEOF
import { s as parseQmdQueryJson } from "${PATCHED}";

const cases = [
  { name: "valid JSON array",
    stdout: '[{"docid":"#abc","score":1,"file":"x.md"}]', stderr: '' },
  { name: "warning + JSON array",
    stdout: "Warning: collection 'custom-1-agent-A' not found, skipping\n[{\"docid\":\"#abc\",\"score\":1}]", stderr: '' },
  { name: "two warnings + JSON array",
    stdout: "Warning: collection 'a' not found, skipping\nWarning: collection 'b' not found, skipping\n[{\"docid\":\"#abc\"}]", stderr: '' },
  { name: "no results found",
    stdout: "No results found.", stderr: '' },
  { name: "Usage screen (THE BUG)",
    stdout: "Usage: qmd query [options] <query>", stderr: '' },
  { name: "completely garbled stdout",
    stdout: "Some random error text without any JSON whatsoever", stderr: '' },
  { name: "empty stdout",
    stdout: "", stderr: "qmd: connection refused" },
  { name: "warning + empty array",
    stdout: "Warning: collection 'foo' not found, skipping\n[]", stderr: '' },
];

let failed = 0;
for (const c of cases) {
  try {
    const out = parseQmdQueryJson(c.stdout, c.stderr);
    console.log(\`PASS: \${c.name} -> array(len=\${out.length})\`);
  } catch (e) {
    console.log(\`FAIL: \${c.name} THREW \${e.message}\`);
    failed++;
  }
}
console.log(\`---\\n\${failed === 0 ? "ALL TESTS PASSED" : failed + " test(s) FAILED"}\`);
process.exit(failed === 0 ? 0 : 1);
JSEOF

node /tmp/test-patched-parser.mjs
TEST_EXIT=$?
rm -f /tmp/test-patched-parser.mjs

echo
echo "=== 清理 tmp ==="
rm -rf "$TMP"
echo "tmp removed"
exit $TEST_EXIT
