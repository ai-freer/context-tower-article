#!/bin/bash
# 清理 the-strategist/（无 cron 引用）+ 迁移 workspace-lisa 副本到 main workspace
# 同时把 4 个 reflection cron 改成绝对路径，杜绝复发
set -uo pipefail

WS="/root/.openclaw/workspace"
SI="$WS/memory/self-improving"
ARCHIVE="$WS/memory/.archive/strategist-and-lisa-dup-$(date -u +%Y%m%dT%H%M%SZ)"

echo "=== Step 2 续：清 the-strategist + lisa 副本 + cron 绝对路径 ==="
mkdir -p "$ARCHIVE"

echo
echo "--- A. backup the-strategist + workspace-lisa/.../lisa ---"
cp -a "$SI/the-strategist" "$ARCHIVE/the-strategist"
cp -a /root/.openclaw/workspace-lisa/memory/self-improving "$ARCHIVE/workspace-lisa-self-improving"
echo "✅ backup → $ARCHIVE"

echo
echo "--- B. 把 workspace-lisa 副本里 5/8 内容追加到 main 的 lisa/hot.md 和 corrections.md ---"
SRC_HOT="/root/.openclaw/workspace-lisa/memory/self-improving/lisa/hot.md"
SRC_COR="/root/.openclaw/workspace-lisa/memory/self-improving/lisa/corrections.md"
DST_HOT="$SI/lisa/hot.md"
DST_COR="$SI/lisa/corrections.md"
TS=$(date -u +%Y%m%dT%H%M%SZ)
MARK="<!-- workspace-lisa-dup-merge $TS -->"

if [ -s "$SRC_HOT" ]; then
  cat >> "$DST_HOT" <<EOF


$MARK begin
## $(date +%Y-%m-%d) Migrated from workspace-lisa副本

EOF
  cat "$SRC_HOT" >> "$DST_HOT"
  echo "" >> "$DST_HOT"
  echo "$MARK end" >> "$DST_HOT"
  echo "✅ 追加 $(stat -c%s $SRC_HOT)B 到 $DST_HOT"
fi

if [ -s "$SRC_COR" ]; then
  cat >> "$DST_COR" <<EOF


$MARK begin
## $(date +%Y-%m-%d) Migrated from workspace-lisa副本

EOF
  cat "$SRC_COR" >> "$DST_COR"
  echo "" >> "$DST_COR"
  echo "$MARK end" >> "$DST_COR"
  echo "✅ 追加 $(stat -c%s $SRC_COR)B 到 $DST_COR"
fi

echo
echo "--- C. 删除 workspace-lisa 副本 + the-strategist ---"
rm -rf /root/.openclaw/workspace-lisa/memory/self-improving
rm -rf "$SI/the-strategist"
echo "✅ removed both"

echo
echo "--- D. 改 4 个 reflection cron 用绝对路径 ---"
# 使用前请把下面 4 个 <CRON_ID_*> 替换为你环境里实际的 cron UUID
# 通过 `openclaw cron list --json | jq -r '.[] | select(.name | startswith("self-improving-daily-reflection")) | "\(.id) \(.agentId)"'` 查出
declare -A CRONS=(
  [<CRON_ID_LISA>]=lisa
  [<CRON_ID_DOUBAO>]=doubao
  [<CRON_ID_NYX>]=nyx
  [<CRON_ID_MAIN>]=main
)

for cron_id in "${!CRONS[@]}"; do
  agent_dir="${CRONS[$cron_id]}"
  abs_path="/root/.openclaw/workspace/memory/self-improving/${agent_dir}"
  echo "  - cron $cron_id → agent_dir=$agent_dir abs_path=$abs_path"

  NEW_MSG="Self-improving 主动反思检查（自动触发）。

步骤：
1. 读 ${abs_path}/hot.md 最后一条 ts
2. 读 ${abs_path}/corrections.md 最后一条 ts
3. 如果任一文件最后写入超过 2 天：
   a. 读 /root/.openclaw/workspace/memory/daily/ 最近 2 天的 daily 文件
   b. 从中提取任何值得记住的内容（新知识、有效方法、差点犯的错、用户偏好）
   c. 写入 ${abs_path}/hot.md（至少 1 条有意义的 observation）
   d. 如果发现有被纠正但没记录的，写 ${abs_path}/corrections.md
4. 如果两个文件都在 2 天内有写入，回复「✅ 无需补写」即可

注意：必须使用绝对路径，避免不同 cwd 导致写到不同 workspace。"

  /usr/bin/openclaw cron edit "$cron_id" --message "$NEW_MSG" 2>&1 | grep -v "Config warnings\|qqbot\|^$\|^├\|^│\|^╭\|^╰\|^◇" | head -5 | head -2
done

echo
echo "--- E. 跑 patrol 看违规数 ---"
/bin/bash $SI/patrol.sh 2>&1 | tail -20
