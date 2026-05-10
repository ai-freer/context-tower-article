#!/bin/bash
# 对 4 个 agent 的 qmd index 跑 cleanup，去 orphan vectors
# 串行执行避免并发竞争
set -uo pipefail

echo "=== Step 4: qmd cleanup orphan vectors ==="
echo "时间: $(date -u +%FT%TZ)"
echo

# 对每个 agent 配置完整 env 后跑 qmd cleanup
for agent in agent-A-B agent-C agent-D; do
  CACHE="/root/.openclaw/agents/${agent}/qmd/xdg-cache"
  CONFIG="/root/.openclaw/agents/${agent}/qmd/xdg-config"
  DB="$CACHE/qmd/index.sqlite"

  echo "============================================================"
  echo "agent: ${agent}"
  echo "============================================================"
  PRE_SIZE=$(stat -c%s "$DB")
  PRE_VECS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM content_vectors;")
  PRE_ORPH=$(sqlite3 "$DB" "SELECT COUNT(*) FROM content_vectors WHERE hash NOT IN (SELECT hash FROM content);")
  echo "PRE:  size=$((PRE_SIZE/1048576))MB  vectors=$PRE_VECS  orphan=$PRE_ORPH"
  echo "running qmd cleanup (no backup; if corrupted, qmd update --pull rebuilds embedding cache)..."

  T0=$(date +%s)
  XDG_CONFIG_HOME="$CONFIG" \
  XDG_CACHE_HOME="$CACHE" \
  QMD_CONFIG_DIR="$CONFIG/qmd" \
  QMD_OPENAI_API_KEY=dummy \
  QMD_OPENAI_BASE_URL=http://127.0.0.1:18790/v1 \
  QMD_OPENAI_EMBED_MODEL=doubao-embedding-vision-251215 \
  QMD_EMBED_PROVIDER=openai \
  /usr/local/bin/qmd cleanup 2>&1 | head -10
  T1=$(date +%s)

  POST_SIZE=$(stat -c%s "$DB")
  POST_VECS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM content_vectors;")
  POST_ORPH=$(sqlite3 "$DB" "SELECT COUNT(*) FROM content_vectors WHERE hash NOT IN (SELECT hash FROM content);")
  SAVED=$((PRE_SIZE - POST_SIZE))
  echo "POST: size=$((POST_SIZE/1048576))MB  vectors=$POST_VECS  orphan=$POST_ORPH"
  echo "DELTA: -$((SAVED/1048576))MB  (cleanup took $((T1-T0))s)"
  echo
done

echo "=== 全部完成 ==="
