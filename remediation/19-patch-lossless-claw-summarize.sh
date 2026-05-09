#!/bin/bash
# P0b + P1: 改 lossless-claw summarize.ts 加 secret redaction 和 short-source skip
# 然后用 esbuild 重新打包，并备份替换 dist/index.js
set -uo pipefail

LC=/root/lossless-claw-enhanced
SRC="$LC/src/summarize.ts"
DIST="$LC/dist/index.js"
TS=$(date -u +%Y%m%dT%H%M%SZ)

echo "=== Step P0b+P1: patch lossless-claw summarizer ==="
echo "时间: $TS"
echo

# --- 1. 备份 ---
echo "--- 1. backup src + dist ---"
cp -p "$SRC" "${SRC}.pre-redact-skip-$TS"
cp -p "$DIST" "${DIST}.pre-redact-skip-$TS"
echo "✅ src backup: ${SRC}.pre-redact-skip-$TS"
echo "✅ dist backup: ${DIST}.pre-redact-skip-$TS"
echo

# --- 2. 检测 sentinel（幂等） ---
if grep -q "PATCH:secret-redaction-and-short-skip" "$SRC"; then
  echo "[idempotent] sentinel found in src; skipping edit"
else
  echo "--- 2. 应用源码 patch ---"
  LCM_SRC="$SRC" python3 <<'PYEOF'
import os, re
SRC = os.environ["LCM_SRC"]
with open(SRC, "r") as f:
    content = f.read()

# A. 在 SUMMARIZER_TIMEOUT_MS 常量后插入 redaction utilities
ANCHOR_A = 'const SUMMARIZER_TIMEOUT_MS = 60_000;'
INSERT_A = '''const SUMMARIZER_TIMEOUT_MS = 60_000;

// PATCH:secret-redaction-and-short-skip ─ added 2026-05-10
// Strip secrets BEFORE LLM call so they don't end up in summaries (which
// then leak into summaries_fts and vector index). Found 41+ existing leaked
// summaries during 2026-05-09 audit; redacting at source eliminates
// recurrence.
const LCM_SECRET_PATTERNS: Array<readonly [RegExp, string]> = [
  [/sk-[A-Za-z0-9_-]{32,}/g, "[REDACTED_API_KEY]"],
  [/Bearer\\s+[A-Za-z0-9_.\\-]{20,}/gi, "Bearer [REDACTED_TOKEN]"],
  [/\\b\\d{8,12}:[A-Za-z0-9_-]{30,}\\b/g, "[REDACTED_BOT_TOKEN]"],
  [/("?(api|access|bot|refresh|secret)[_-]?(?:key|token)"?\\s*[:=]\\s*"?)([A-Za-z0-9_\\-\\.]{20,})/gi, "$1[REDACTED]"],
];
function redactLcmSecrets(text: string): string {
  let out = text;
  for (const [pat, repl] of LCM_SECRET_PATTERNS) {
    out = out.replace(pat, repl);
  }
  return out;
}
// Skip LLM call when source already small enough — fixes the
// "summary longer than source" failure mode (sum_69c192 case in audit).
const LCM_SHORT_SOURCE_SKIP_TOKENS = 200;'''

if ANCHOR_A not in content:
    raise SystemExit("anchor A (SUMMARIZER_TIMEOUT_MS) not found")
content = content.replace(ANCHOR_A, INSERT_A, 1)

# B. 在 fn body 的 "if (!text.trim()) return '';" 之后插入 redact + skip
ANCHOR_B = '''    if (!text.trim()) {
      return "";
    }

    const mode: SummaryMode = aggressive ? "aggressive" : "normal";'''
INSERT_B = '''    if (!text.trim()) {
      return "";
    }

    // PATCH:secret-redaction-and-short-skip ─ apply BEFORE any LLM call
    text = redactLcmSecrets(text);
    if (estimateTokens(text) < LCM_SHORT_SOURCE_SKIP_TOKENS) {
      return text;
    }

    const mode: SummaryMode = aggressive ? "aggressive" : "normal";'''

if ANCHOR_B not in content:
    raise SystemExit("anchor B (text.trim + mode) not found")
content = content.replace(ANCHOR_B, INSERT_B, 1)

with open(SRC, "w") as f:
    f.write(content)
print("✅ patch applied to summarize.ts")
PYEOF
fi
echo

# --- 3. 验证 patch ---
echo "--- 3. patch verification ---"
echo "redactLcmSecrets count: $(grep -c "redactLcmSecrets" $SRC)"
echo "LCM_SHORT_SOURCE_SKIP_TOKENS count: $(grep -c "LCM_SHORT_SOURCE_SKIP_TOKENS" $SRC)"
echo "PATCH:secret-redaction-and-short-skip sentinel: $(grep -c "PATCH:secret-redaction-and-short-skip" $SRC)"
echo

# --- 4. esbuild 编译 ---
echo "--- 4. esbuild bundle ---"
cd "$LC"
ESBUILD="$LC/node_modules/.bin/esbuild"
if [ ! -x "$ESBUILD" ]; then
  echo "❌ esbuild not found at $ESBUILD"
  exit 1
fi

T0=$(date +%s)
"$ESBUILD" index.ts \
  --bundle \
  --platform=node \
  --format=esm \
  --target=es2022 \
  --external:@mariozechner/pi-agent-core \
  --external:@mariozechner/pi-ai \
  --external:openclaw \
  --outfile=dist/index.js \
  --log-level=warning \
  2>&1 | tail -10
RC=$?
T1=$(date +%s)
echo "esbuild took $((T1-T0))s, rc=$RC"

if [ $RC -ne 0 ]; then
  echo "❌ esbuild FAILED, restoring backup..."
  cp -p "${DIST}.pre-redact-skip-$TS" "$DIST"
  cp -p "${SRC}.pre-redact-skip-$TS" "$SRC"
  exit 1
fi
echo

# --- 5. 验证新 dist 含我们的 patch 标记 ---
echo "--- 5. dist verification ---"
NEW_SIZE=$(stat -c%s "$DIST")
echo "dist/index.js size: $NEW_SIZE bytes"
if grep -q "redactLcmSecrets\|LCM_SHORT_SOURCE_SKIP_TOKENS\|REDACTED_API_KEY" "$DIST"; then
  echo "✅ patch markers found in compiled dist"
else
  echo "❌ patch markers NOT in dist (compile may not have used patched src)"
  exit 1
fi
echo

echo "=== 完成。下一步: 重启 gateway 让新 plugin 生效 ==="
echo "建议 sudo systemctl restart openclaw-gateway-root.service"
