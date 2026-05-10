#!/bin/bash
# 完整重启 gateway，含前后对比快照
set -uo pipefail

LOG="/tmp/gateway-restart-$(date -u +%Y%m%dT%H%M%SZ).log"
exec > >(tee -a "$LOG") 2>&1

echo "=== 重启日志 ==="
echo "log: $LOG"
echo "时间: $(date -u +%FT%TZ)"
echo

echo "=== 1. PRE-RESTART snapshot ==="
PRE_PID=$(systemctl show -p MainPID --value openclaw-gateway-root.service)
echo "gateway agent-A pid: $PRE_PID"
PRE_MSGS=$(sqlite3 /root/.openclaw/lcm.db "SELECT COUNT(*) FROM messages")
PRE_CONVS=$(sqlite3 /root/.openclaw/lcm.db "SELECT COUNT(*) FROM conversations")
PRE_QMD_ERRS=$(sqlite3 /root/.openclaw/lcm.db "SELECT COUNT(*) FROM messages WHERE role='tool' AND content LIKE '%qmd query returned invalid JSON%' AND created_at > datetime('now','-1 day')")
echo "lcm messages: $PRE_MSGS"
echo "lcm conversations: $PRE_CONVS"
echo "qmd JSON errors in last 24h (pre-restart baseline): $PRE_QMD_ERRS"
echo

echo "=== 2. 确认 patch 已 live in target file ==="
if grep -q "PATCH:qmd-defensive-parse" /usr/lib/node_modules/openclaw/dist/engine-qmd-DAYKPzcH.js; then
  echo "✅ sentinel found in production file"
else
  echo "❌ sentinel MISSING - patch not applied; ABORTING restart"
  exit 1
fi
echo

echo "=== 3. 执行 systemctl restart ==="
T0=$(date +%s)
systemctl restart openclaw-gateway-root.service
RC=$?
T1=$(date +%s)
echo "restart command returned in $((T1-T0))s with rc=$RC"
echo

echo "=== 4. 等服务进入 active 状态 ==="
for i in {1..30}; do
  STATE=$(systemctl is-active openclaw-gateway-root.service 2>&1)
  if [ "$STATE" = "active" ]; then
    NEW_PID=$(systemctl show -p MainPID --value openclaw-gateway-root.service)
    if [ "$NEW_PID" != "$PRE_PID" ] && [ "$NEW_PID" != "0" ]; then
      echo "service active, new pid=$NEW_PID (was $PRE_PID), waited ${i}s"
      break
    fi
  fi
  sleep 1
done

echo
echo "=== 5. 看 ExecStartPre apply-patches.sh 输出 ==="
journalctl -u openclaw-gateway-root.service --since "$(date -u -d '60 seconds ago' +%FT%TZ)" --no-pager 2>&1 | grep -E "patch|patches" | head -20
echo

echo "=== 6. 看 gateway 启动 banner / 错误 ==="
journalctl -u openclaw-gateway-root.service --since "$(date -u -d '60 seconds ago' +%FT%TZ)" --no-pager 2>&1 | tail -40
echo

echo "=== 7. POST-RESTART status ==="
systemctl status openclaw-gateway-root.service --no-pager 2>&1 | head -10
echo

echo "=== 完成 ==="
