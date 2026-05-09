#!/bin/bash
# 执行 lolita/Lolita/main 目录合并
# 失败可从 .archive/lolita-merge-* 还原
set -uo pipefail

SI="/root/.openclaw/workspace/memory/self-improving"
ARCHIVE_ROOT="/root/.openclaw/workspace/memory/.archive"
TS=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP="$ARCHIVE_ROOT/lolita-merge-$TS"
MERGE_MARK="<!-- lolita-dir-merge $TS -->"

echo "=== Step 2 EXECUTE: lolita/Lolita/main 目录合并 ==="
echo "时间: $TS"
echo "backup → $BACKUP"
echo

echo "--- 1. 创建 archive backup ---"
mkdir -p "$BACKUP"
for d in lolita Lolita main; do
  cp -a "$SI/$d" "$BACKUP/$d"
done
echo "✅ backup 完成: $(du -sh $BACKUP | cut -f1)"
echo

echo "--- 2. lolita/hot.md 增量追加到 main/hot.md ---"
NEW_HOT_LINES=$(grep -E "^- ts: 2026-05-0[789]" "$SI/lolita/hot.md" || true)
if [ -n "$NEW_HOT_LINES" ]; then
  cat >> "$SI/main/hot.md" <<EOF


$MERGE_MARK lolita/ → main/ migration begin
## $(date +%Y-%m-%d) lolita-dir merge tail

Merged from \`self-improving/lolita/hot.md\` (post-5/5 alias-merge entries):

$NEW_HOT_LINES
$MERGE_MARK lolita/ → main/ migration end
EOF
  echo "✅ 追加 $(echo "$NEW_HOT_LINES" | wc -l) 条新 hot.md 条目"
else
  echo "（无 5/7-9 新条目可追加）"
fi
echo

echo "--- 3. lolita/signals.md W19 追加到 main/signals.md ---"
W19_SECTION=$(awk '/^## 2026-W19/,EOF' "$SI/lolita/signals.md")
if [ -n "$W19_SECTION" ]; then
  if grep -q "^## 2026-W19" "$SI/main/signals.md"; then
    echo "⚠ main/signals.md 已经有 W19 section，跳过避免重复"
  else
    cat >> "$SI/main/signals.md" <<EOF


$MERGE_MARK lolita/ → main/ migration begin
$W19_SECTION
$MERGE_MARK lolita/ → main/ migration end
EOF
    echo "✅ 追加 W19 section ($(echo "$W19_SECTION" | wc -l) 行)"
  fi
fi
echo

echo "--- 4. 删除 typo dir corrrections.md/ ---"
if [ -d "$SI/lolita/corrrections.md" ]; then
  rmdir "$SI/lolita/corrrections.md"
  echo "✅ removed empty typo dir"
fi
echo

echo "--- 5. 删除 Lolita/ (内容已在 main/ 5/5 alias merge) ---"
rm -rf "$SI/Lolita"
echo "✅ removed Lolita/"
echo

echo "--- 6. 删除 lolita/ (内容已迁到 main/) ---"
rm -rf "$SI/lolita"
echo "✅ removed lolita/"
echo

echo "--- 7. 编辑 cron payload: lolita/ → main/ ---"
NEW_MSG="Self-improving 主动反思检查（自动触发）。

步骤：
1. 读 memory/self-improving/main/hot.md 最后一条 ts
2. 读 memory/self-improving/main/corrections.md 最后一条 ts
3. 如果任一文件最后写入超过 2 天：
   a. 读 memory/daily/ 最近 2 天的 daily 文件
   b. 从中提取任何值得记住的内容
   c. 写入 hot.md（至少 1 条有意义的 observation）
4. 如果都在 2 天内有写入，回复「✅ 无需补写」即可"

/usr/bin/openclaw cron edit ae3745b9-a90b-4ef9-8f9b-d2faf49c5bb2 --message "$NEW_MSG" 2>&1 | grep -v "Config warnings\|qqbot\|^$" | head -10
echo

echo "--- 8. 验证最终状态 ---"
echo "self-improving 当前 agent 子目录:"
ls -d "$SI"/*/ 2>/dev/null | sed 's|.*/||;s|/$||' | sort
echo
echo "main/ 内容:"
ls -la "$SI/main/" | grep -v "^total\|\.\.\.$" | head -5
echo
echo "main/hot.md 最后 5 行:"
tail -5 "$SI/main/hot.md"
echo

echo "=== 完成 ==="
echo "如需还原: rm -rf $SI/main && cp -a $BACKUP/* $SI/"
