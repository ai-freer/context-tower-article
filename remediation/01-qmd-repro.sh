#!/bin/bash
# 用 agent-A 的真实 QMD home 复现 active-memory 的查询场景
# 跑一组 query，看哪些会触发 "JSON not array" 错误

set -u
AGENT="agent-A"
QUERIES=(
  "memory system audit"
  "recent project status"
  "lossless-claw"
  "openclaw"
  "你好"
  ""
  "xyz789nomatch"
  "telegram bot"
  "skill evolution"
  "self improving"
)

export XDG_CACHE_HOME="/root/.openclaw/agents/${AGENT}/qmd/xdg-cache"
export QMD_OPENAI_API_KEY=dummy
export QMD_OPENAI_BASE_URL=http://127.0.0.1:18790/v1
export QMD_OPENAI_EMBED_MODEL=doubao-embedding-vision-251215
export QMD_EMBED_PROVIDER=openai
export QMD_OPENAI_MODEL=doubao-seed-2-0-lite-260215
export QMD_QUERY_EXPANSION_PROVIDER=openai
export QMD_RERANK_PROVIDER=openai
export QMD_RERANK_MODE=llm

cd /root/.openclaw/workspace || exit 1

echo "=== qmd collection list (验证认到的是 ${AGENT} 的索引) ==="
/usr/local/bin/qmd collection list 2>&1 | head -15
echo

for q in "${QUERIES[@]}"; do
  echo "============================================================"
  echo "QUERY: \"${q}\""
  echo "============================================================"
  out=$(/usr/local/bin/qmd query "$q" --json -n 8 --timeout 60 2>&1)
  ec=$?
  # 判断 stdout 首字符
  first=$(echo "$out" | head -c 1)
  case "$first" in
    "[") verdict="OK_JSON_ARRAY" ;;
    "")  verdict="EMPTY" ;;
    *)   verdict="NOT_JSON_ARRAY (first char: $first)" ;;
  esac
  echo "verdict: $verdict (exit=$ec)"
  echo "first 200 chars of output:"
  echo "$out" | head -c 200
  echo
  echo
done
