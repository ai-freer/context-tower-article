#!/bin/bash
# 重跑 nyx 的 qmd cleanup（之前那次未完成）
set -uo pipefail

CACHE="/root/.openclaw/agents/nyx/qmd/xdg-cache"
CONFIG="/root/.openclaw/agents/nyx/qmd/xdg-config"
DB="$CACHE/qmd/index.sqlite"

echo "=== nyx cleanup retry ==="
PRE_SIZE=$(stat -c%s "$DB")
PRE_VECS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM content_vectors;")
PRE_ORPH=$(sqlite3 "$DB" "SELECT COUNT(*) FROM content_vectors WHERE hash NOT IN (SELECT hash FROM content);")
echo "PRE: size=$((PRE_SIZE/1048576))MB vectors=$PRE_VECS orphan=$PRE_ORPH"

T0=$(date +%s)
XDG_CONFIG_HOME="$CONFIG" \
XDG_CACHE_HOME="$CACHE" \
QMD_CONFIG_DIR="$CONFIG/qmd" \
QMD_OPENAI_API_KEY=dummy \
QMD_OPENAI_BASE_URL=http://127.0.0.1:18790/v1 \
QMD_OPENAI_EMBED_MODEL=doubao-embedding-vision-251215 \
QMD_EMBED_PROVIDER=openai \
/usr/local/bin/qmd cleanup
T1=$(date +%s)

POST_SIZE=$(stat -c%s "$DB")
POST_VECS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM content_vectors;")
POST_ORPH=$(sqlite3 "$DB" "SELECT COUNT(*) FROM content_vectors WHERE hash NOT IN (SELECT hash FROM content);")
echo "POST: size=$((POST_SIZE/1048576))MB vectors=$POST_VECS orphan=$POST_ORPH"
echo "DELTA: -$((($PRE_SIZE - $POST_SIZE)/1048576))MB cleanup took $((T1-T0))s"
