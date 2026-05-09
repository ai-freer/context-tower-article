#!/bin/bash
# 重启 gateway，让 patched lossless-claw 生效，并验证
set -uo pipefail

echo "=== 重启 gateway ==="
PRE_PID=$(systemctl show -p MainPID --value openclaw-gateway-root.service)
echo "pre pid: $PRE_PID"

systemctl restart openclaw-gateway-root.service
sleep 2

for i in {1..30}; do
  STATE=$(systemctl is-active openclaw-gateway-root.service 2>&1)
  NEW_PID=$(systemctl show -p MainPID --value openclaw-gateway-root.service)
  if [ "$STATE" = "active" ] && [ "$NEW_PID" != "$PRE_PID" ] && [ "$NEW_PID" != "0" ]; then
    echo "✅ active, new pid=$NEW_PID (was $PRE_PID); waited ${i}s"
    break
  fi
  sleep 1
done

echo
echo "--- 看 gateway 启动日志（含 lossless-claw startup banner） ---"
journalctl -u openclaw-gateway-root.service --since "$(date -u -d '60 seconds ago' +%FT%TZ)" --no-pager 2>&1 | grep -iE "lossless|lcm|patch|redact|gateway started" | head -10

echo
echo "--- 验证新 dist 在 gateway 上加载 ---"
echo "dist size: $(stat -c%s /root/lossless-claw-enhanced/dist/index.js) bytes"
echo "redactLcmSecrets in loaded dist: $(grep -c redactLcmSecrets /root/lossless-claw-enhanced/dist/index.js)"

echo
echo "=== 完成 ==="
