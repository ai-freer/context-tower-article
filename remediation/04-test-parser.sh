#!/bin/bash
# 测试 parseQmdQueryJson 是否正确处理 "Warning: ... [json]" 模式

cat > /tmp/test-parser.mjs <<'JSEOF'
import { s as parseQmdQueryJson } from '/usr/lib/node_modules/openclaw/dist/engine-qmd-DAYKPzcH.js';

const cases = [
  { name: "valid JSON array",
    stdout: '[{"docid":"#abc","score":1,"file":"x.md"}]', stderr: '' },
  { name: "warning + JSON array (single warn)",
    stdout: "Warning: collection 'custom-1-agent-A' not found, skipping\n[{\"docid\":\"#abc\",\"score\":1,\"file\":\"x.md\"}]", stderr: '' },
  { name: "two warnings + JSON array",
    stdout: "Warning: collection 'a' not found, skipping\nWarning: collection 'b' not found, skipping\n[{\"docid\":\"#abc\",\"score\":1,\"file\":\"x.md\"}]", stderr: '' },
  { name: "no results",
    stdout: "No results found.", stderr: '' },
  { name: "Usage screen (empty query)",
    stdout: "Usage: qmd query [options] <query>", stderr: '' },
  { name: "warning + empty JSON",
    stdout: "Warning: collection 'foo' not found, skipping\n[]", stderr: '' },
];

for (const c of cases) {
  try {
    const out = parseQmdQueryJson(c.stdout, c.stderr);
    console.log(`✅ ${c.name}: returned ${Array.isArray(out) ? `array(len=${out.length})` : typeof out}`);
  } catch (e) {
    console.log(`❌ ${c.name}: THREW — ${e.message}`);
  }
}
JSEOF
node /tmp/test-parser.mjs 2>&1
rm -f /tmp/test-parser.mjs
