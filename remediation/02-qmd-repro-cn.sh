#!/bin/bash
# 复现真实失败的中文 query
set -u
AGENT="main"

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

QUERIES=(
  "九层塔架构"
  "九层塔"
  "context engineering"
  "MEMORY.md slimming"
  "active memory recall"
  "doubao seed"
  "embedding coverage"
)

for q in "${QUERIES[@]}"; do
  echo "============================================================"
  echo "QUERY: \"${q}\""
  echo "============================================================"
  out=$(/usr/local/bin/qmd query "$q" --json -n 8 --timeout 60 2>&1)
  ec=$?
  first=$(printf '%s' "$out" | head -c 1)
  case "$first" in
    "[") verdict="OK_JSON_ARRAY" ;;
    "")  verdict="EMPTY" ;;
    *)   verdict="NOT_JSON_ARRAY (first char: '$first')" ;;
  esac
  echo "verdict: $verdict (exit=$ec)"
  echo "first 400 chars:"
  printf '%s' "$out" | head -c 400
  echo
  echo "stderr-ish lines (lines not starting with [ or {):"
  printf '%s' "$out" | head -50 | grep -vE '^[\[\{ ]' | head -10
  echo
done
