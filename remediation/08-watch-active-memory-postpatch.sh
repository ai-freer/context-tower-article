#!/bin/bash
# 持续监控 lcm.db，看 active-memory 在 patch 后的失败率
set -uo pipefail

# 起始 message_id（从重启后开始计数）
START_MSGID=$(sqlite3 /root/.openclaw/lcm.db "SELECT MAX(message_id) FROM messages")
echo "[$(date -u +%FT%TZ)] watching from message_id > $START_MSGID"
echo "press Ctrl+C to stop"
echo

LAST_REPORTED=0

while true; do
  # 查询新进来的 active-memory tool messages
  ROWS=$(sqlite3 /root/.openclaw/lcm.db "
SELECT m.message_id, m.created_at,
  CASE
    WHEN m.content LIKE '%qmd query returned invalid JSON%' THEN 'OLD_BUG'
    WHEN m.content LIKE '%treating as no-results%' THEN 'PATCH_FIRED'
    WHEN m.content LIKE '%backend\":\"builtin%' AND m.content NOT LIKE '%treating as no-results%' THEN 'BUILTIN_FALLBACK'
    WHEN m.content LIKE '%backend\":\"qmd%' AND m.content LIKE '%hits\":\"_%' THEN 'QMD_OK'
    WHEN m.content LIKE '%backend\":\"qmd%' THEN 'QMD_OK'
    ELSE 'OTHER'
  END AS verdict
FROM messages m
JOIN conversations c ON m.conversation_id = c.conversation_id
WHERE m.message_id > $START_MSGID
  AND m.role = 'tool'
  AND c.session_id LIKE 'active-memory-%'
ORDER BY m.message_id
LIMIT 50;
")
  if [ -n "$ROWS" ]; then
    NEW_LINES=$(echo "$ROWS" | awk -v last=$LAST_REPORTED -F '|' '$1 > last { print }')
    if [ -n "$NEW_LINES" ]; then
      echo "$NEW_LINES" | while IFS='|' read -r mid ts verdict; do
        case "$verdict" in
          OLD_BUG)         icon="❌" ;;
          PATCH_FIRED)     icon="✅⚠" ;;
          BUILTIN_FALLBACK) icon="⚠" ;;
          QMD_OK)          icon="✅" ;;
          *)               icon="❓" ;;
        esac
        echo "[$ts] mid=$mid $icon $verdict"
      done
      LAST_REPORTED=$(echo "$ROWS" | tail -1 | cut -d'|' -f1)
    fi
  fi

  # 累计统计
  STATS=$(sqlite3 /root/.openclaw/lcm.db "
SELECT
  SUM(CASE WHEN m.content LIKE '%qmd query returned invalid JSON%' AND m.content NOT LIKE '%treating as no-results%' THEN 1 ELSE 0 END) AS old_bug,
  SUM(CASE WHEN m.content LIKE '%treating as no-results%' THEN 1 ELSE 0 END) AS patch_fired,
  SUM(CASE WHEN m.content LIKE '%backend\":\"qmd%' THEN 1 ELSE 0 END) AS qmd_ok,
  COUNT(*) AS total
FROM messages m
JOIN conversations c ON m.conversation_id = c.conversation_id
WHERE m.message_id > $START_MSGID
  AND m.role = 'tool'
  AND c.session_id LIKE 'active-memory-%';
")
  echo -n "[$(date -u +%FT%TZ)] cumulative stats: $STATS  "
  echo

  sleep 15
done
