#!/bin/bash
# 用 main agent 的真实 XDG 路径 + 跨 collection 复现
set -u
AGENT="main"

export XDG_CACHE_HOME="/root/.openclaw/agents/${AGENT}/qmd/xdg-cache"
export XDG_CONFIG_HOME="/root/.openclaw/agents/${AGENT}/qmd/xdg-config"
export QMD_OPENAI_API_KEY=dummy
export QMD_OPENAI_BASE_URL=http://127.0.0.1:18790/v1
export QMD_OPENAI_EMBED_MODEL=doubao-embedding-vision-251215
export QMD_EMBED_PROVIDER=openai
export QMD_OPENAI_MODEL=doubao-seed-2-0-lite-260215
export QMD_QUERY_EXPANSION_PROVIDER=openai
export QMD_RERANK_PROVIDER=openai
export QMD_RERANK_MODE=llm

cd /root/.openclaw/workspace || exit 1

echo "=== qmd collection list (确认 6 个 collection 都加载) ==="
/usr/local/bin/qmd collection list 2>&1 | head -30
echo

# 复现：跨 collection 调用，--collection 指定单个 collection
QUERY="九层塔架构"
echo "============================================================"
echo "完整 collection 列表（按 plugin 多 collection 路径调用）"
echo "============================================================"
for col in custom-1-main custom-2-main custom-3-main memory-root-main memory-dir-main sessions-main; do
  echo "--- collection=$col ---"
  out=$(/usr/local/bin/qmd query "$QUERY" --json -n 8 -c "$col" --timeout 60 2>&1)
  ec=$?
  first=$(printf '%s' "$out" | head -c 1)
  case "$first" in
    "[") verdict="OK_JSON_ARRAY" ;;
    "")  verdict="EMPTY" ;;
    *)   verdict="NOT_JSON_ARRAY (first char: '$first')" ;;
  esac
  echo "verdict: $verdict (exit=$ec)"
  echo "first 300 chars:"
  printf '%s' "$out" | head -c 300
  echo
  echo
done
