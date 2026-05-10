#!/bin/bash
# C-#6: lossless-claw 周度健康监控 cron
# 目的：在 5/9 之前那种"40 天沉默"再次发生时，1 周内能被发现
#
# 使用前请替换占位符：
#   <TELEGRAM_GROUP_ID>  替换成你自己的 Telegram supergroup chatId
#                        （形如 -100XXXXXXXXXX，可通过 openclaw directory 查）
set -uo pipefail

TELEGRAM_GROUP_ID="<TELEGRAM_GROUP_ID>"  # 部署前替换

PROMPT='lossless-claw 周度健康检查（自动触发）。

执行以下 SQL 收集 lcm.db 健康指标，对照阈值，写报告：

1. 用 sqlite3 查 /root/.openclaw/lcm.db：
   - msgs_total, msgs_24h, msgs_7d
   - leaf_summaries, condensed_summaries
   - leaf_24h, condensed_24h
   - newest_message_age_hours, newest_summary_age_hours
   - conversations_count, lcm_db_bytes, lcm_wal_bytes

2. 对照阈值评级：
   - 🟢 ingest_active (msgs_24h > 100)
   - 🔴 ingest_silent (msgs_24h == 0 且 msgs_7d < 100) ← 类比 5/9 修复前
   - 🟡 dag_shallow (condensed/leaf < 0.05 持续 7 天)
   - 🔴 lcm_stalled (newest_msg_age_hours > 168)
   - 🟡 wal_bloat (wal > 50MB)
   - 🔴 wal_corrupted (wal > 200MB)

3. 写报告到 memory/shared/audits/lossless-claw-health-$(date +%Y-W%V).md
   - 标题：Lossless-Claw 健康周报 W{week}
   - 包含所有指标 + 评级 + 同比上周变化（若上周报告存在）
   - 末尾给出 1-2 句话结论：稳定 / 需关注 / 需立刻干预

4. 如果有 🔴 项：
   - 在 telegram 群 <TELEGRAM_GROUP_ID> 发简短告警（一句话+指标）
   - 否则只写报告，不打扰

参考：上次 lossless-claw 沉默是 2026-03-30 → 2026-05-09，40 天才发现。这个监控就是为了把"40 天"压到"1 周"。'

echo "=== 添加 weekly-lossless-claw-health cron ==="
EXIST=$(/usr/bin/openclaw cron list 2>&1 | grep -c "weekly-lossless-claw-health" || true)
if [ "${EXIST:-0}" -gt 0 ]; then
  echo "cron weekly-lossless-claw-health 已存在，跳过"
  exit 0
fi

/usr/bin/openclaw cron add \
  --name "weekly-lossless-claw-health" \
  --cron "30 9 * * 1" \
  --tz "Asia/Shanghai" \
  --agent agent-B \
  --message "$PROMPT" \
  --description "周一 09:30 agent-B 跑：lcm.db 健康指标 + 报告 + 异常告警" \
  --announce \
  --channel "telegram" \
  --to "$TELEGRAM_GROUP_ID" \
  2>&1 | grep -v "Config warnings\|qqbot:.*duplicate\|^$\|^├\|^│\|^╭\|^╰\|^◇" | head -20

echo
echo "=== 验证 ==="
/usr/bin/openclaw cron list 2>&1 | grep "lossless-claw-health\|memory-health-check"
