#!/bin/bash
# Step 6 MVP: 周日晚增加 wiki synthesis cron
set -uo pipefail

PROMPT="周度 wiki synthesis（自动触发，不需要用户确认）。

你今天 20:00 已经做完 weekly-signal-digest，将信号汇总写到了 memory/daily/$(date +%Y-%m-%d).md 或 self-improving/lisa/signals.md。

现在做下一步：从本周采集到的信号 + 本周 daily memory 的关键内容里，提炼 1-2 个 emerging concept / theme，写成 wiki synthesis 页面。

步骤：
1. 读 memory/self-improving/*/signals.md 中本周条目（## 2026-W$(date +%V)）
2. 读 memory/daily/ 最近 3 天文件
3. 找出反复出现的 1-2 个核心主题（例如：'agent skill 范式''AI 金融垂直模型''context engineering 工具化'）
4. 对每个主题：
   - 写一段 200-400 字的浓缩摘要（不要堆 bullet，要有论点）
   - 写一句开放式 question（这个主题接下来值得追什么）
   - 给一个 confidence 分数 0.0-1.0
5. 用 openclaw wiki apply synthesis 写入：
   openclaw wiki apply synthesis <title> --body <body> --confidence <n> --question <q>

注意：
- 不要为了凑数而强行写。如果本周信号确实没有清晰主题，回复「✅ 无 synthesis 候选」即可。
- 一周 1-2 个高质量比 5 个空泛主题强。
- 主题应该是跨多条信号能聚合的，不是单点新闻复述。"

echo "=== 添加 weekly-wiki-synthesis cron ==="
sudo_check=$(/usr/bin/openclaw cron list 2>&1 | grep -c "weekly-wiki-synthesis" || echo 0)
if [ "$sudo_check" -gt 0 ]; then
  echo "cron weekly-wiki-synthesis 已存在，跳过"
  exit 0
fi

/usr/bin/openclaw cron add \
  --name "weekly-wiki-synthesis" \
  --cron "0 22 * * 0" \
  --agent lisa \
  --message "$PROMPT" \
  --tz "Asia/Shanghai" \
  --description "周度 wiki synthesis：从信号汇总提炼 1-2 emerging concepts → wiki apply synthesis" \
  2>&1 | grep -v "Config warnings\|qqbot\|^$\|^├\|^│\|^╭\|^╰\|^◇" | head -20

echo
echo "=== 列出新增 cron ==="
/usr/bin/openclaw cron list 2>&1 | grep -E "wiki-synthesis|signal-digest|signal-remind"
