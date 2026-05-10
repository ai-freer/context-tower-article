#!/bin/bash
# 执行 persona-A/Persona-A/agent-A 目录合并
# 失败可从 .archive/persona-A-merge-* 还原
set -uo pipefail

SI="/root/.openclaw/workspace/memory/self-improving"
ARCHIVE_ROOT="/root/.openclaw/workspace/memory/.archive"
TS=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP="$ARCHIVE_ROOT/persona-A-merge-$TS"
MERGE_MARK="<!-- persona-A-dir-merge $TS -->"

echo "=== Step 2 EXECUTE: persona-A/Persona-A/agent-A 目录合并 ==="
echo "时间: $TS"
echo "backup → $BACKUP"
echo

echo "--- 1. 创建 archive backup ---"
mkdir -p "$BACKUP"
for d in persona-A Persona-A agent-A; do
  cp -a "$SI/$d" "$BACKUP/$d"
done
echo "✅ backup 完成: $(du -sh $BACKUP | cut -f1)"
echo

echo "--- 2. persona-A/hot.md 增量追加到 agent-A/hot.md ---"
NEW_HOT_LINES=$(grep -E "^- ts: 2026-05-0[789]" "$SI/persona-A/hot.md" || true)
if [ -n "$NEW_HOT_LINES" ]; then
  cat >> "$SI/agent-A/hot.md" <<EOF


$MERGE_MARK persona-A/ → agent-A/ migration begin
## $(date +%Y-%m-%d) persona-A-dir merge tail

Merged from \`self-improving/persona-A/hot.md\` (post-5/5 alias-merge entries):

$NEW_HOT_LINES
$MERGE_MARK persona-A/ → agent-A/ migration end
EOF
  echo "✅ 追加 $(echo "$NEW_HOT_LINES" | wc -l) 条新 hot.md 条目"
else
  echo "（无 5/7-9 新条目可追加）"
fi
echo

echo "--- 3. persona-A/signals.md W19 追加到 agent-A/signals.md ---"
W19_SECTION=$(awk '/^## 2026-W19/,EOF' "$SI/persona-A/signals.md")
if [ -n "$W19_SECTION" ]; then
  if grep -q "^## 2026-W19" "$SI/agent-A/signals.md"; then
    echo "⚠ agent-A/signals.md 已经有 W19 section，跳过避免重复"
  else
    cat >> "$SI/agent-A/signals.md" <<EOF


$MERGE_MARK persona-A/ → agent-A/ migration begin
$W19_SECTION
$MERGE_MARK persona-A/ → agent-A/ migration end
EOF
    echo "✅ 追加 W19 section ($(echo "$W19_SECTION" | wc -l) 行)"
  fi
fi
echo

echo "--- 4. 删除 typo dir corrrections.md/ ---"
if [ -d "$SI/persona-A/corrrections.md" ]; then
  rmdir "$SI/persona-A/corrrections.md"
  echo "✅ removed empty typo dir"
fi
echo

echo "--- 5. 删除 Persona-A/ (内容已在 agent-A/ 5/5 alias merge) ---"
rm -rf "$SI/Persona-A"
echo "✅ removed Persona-A/"
echo

echo "--- 6. 删除 persona-A/ (内容已迁到 agent-A/) ---"
rm -rf "$SI/persona-A"
echo "✅ removed persona-A/"
echo

echo "--- 7. 编辑 cron payload: persona-A/ → agent-A/ ---"
NEW_MSG="Self-improving 主动反思检查（自动触发）。

步骤：
1. 读 memory/self-improving/agent-A/hot.md 最后一条 ts
2. 读 memory/self-improving/agent-A/corrections.md 最后一条 ts
3. 如果任一文件最后写入超过 2 天：
   a. 读 memory/daily/ 最近 2 天的 daily 文件
   b. 从中提取任何值得记住的内容
   c. 写入 hot.md（至少 1 条有意义的 observation）
4. 如果都在 2 天内有写入，回复「✅ 无需补写」即可"

# 替换为你环境里 self-improving-daily-reflection-persona-A 那条 cron 的 UUID
CRON_ID_MAIN_REFLECTION="<CRON_ID_MAIN_REFLECTION>"
/usr/bin/openclaw cron edit "$CRON_ID_MAIN_REFLECTION" --message "$NEW_MSG" 2>&1 | grep -v "Config warnings\|qqbot\|^$" | head -10
echo

echo "--- 8. 验证最终状态 ---"
echo "self-improving 当前 agent 子目录:"
ls -d "$SI"/*/ 2>/dev/null | sed 's|.*/||;s|/$||' | sort
echo
echo "agent-A/ 内容:"
ls -la "$SI/agent-A/" | grep -v "^total\|\.\.\.$" | head -5
echo
echo "agent-A/hot.md 最后 5 行:"
tail -5 "$SI/agent-A/hot.md"
echo

echo "=== 完成 ==="
echo "如需还原: rm -rf $SI/agent-A && cp -a $BACKUP/* $SI/"
