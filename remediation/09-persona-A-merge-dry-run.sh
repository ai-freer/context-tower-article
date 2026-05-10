#!/bin/bash
# DRY-RUN 模式 - 只 diff 和打印，不动文件
# 验证 persona-A/Persona-A/agent-A 目录合并方案

set -uo pipefail
SI="/root/.openclaw/workspace/memory/self-improving"

echo "=== Step 2 dry-run: persona-A/Persona-A/agent-A 目录合并 ==="
echo "时间: $(date -u +%FT%TZ)"
echo

echo "=== A. 当前文件清单 ==="
for d in persona-A Persona-A agent-A; do
  p="$SI/${d}"
  echo "--- ${d}/ ---"
  for f in "$p"/*.md; do
    [ -f "$f" ] || continue
    bytes=$(stat -c%s "$f")
    mtime=$(stat -c%y "$f" | cut -d. -f1)
    echo "  $(basename $f) $bytes B  $mtime"
  done
  if [ -d "$p/corrrections.md" ]; then
    echo "  corrrections.md/ DIR (typo, $(ls -la $p/corrrections.md/ | wc -l) entries)"
  fi
done
echo

echo "=== B. 内容差异分析 ==="

echo "--- B1. persona-A/hot.md 中 agent-A/hot.md 缺失的条目 ---"
# agent-A/hot.md 已经包含 'Legacy alias merge (2026-05-05)' 把 persona-A 的内容合并进去
# 但 persona-A 在 2026-05-07/08/09 又有了新条目
echo "persona-A/hot.md 中 ts=2026-05-07/08/09 条目（应迁到 agent-A/）:"
sudo -n cat "$SI/persona-A/hot.md" | grep -E "ts: 2026-05-0[789]" | head -10
echo

echo "--- B2. persona-A/signals.md vs agent-A/signals.md ---"
echo "persona-A/ 包含 W19 (2026-05-09) 数据；agent-A/ 缺这部分"
echo "persona-A/signals.md 中 '## 2026-W19' section 行数:"
sudo -n cat "$SI/persona-A/signals.md" | awk '/^## 2026-W19/,EOF' | wc -l
echo "agent-A/signals.md 中是否已含 '## 2026-W19':"
sudo -n grep -c "^## 2026-W19" "$SI/agent-A/signals.md" || echo 0
echo

echo "--- B3. Persona-A/hot.md (5/2 老内容，已通过 alias merge 入 agent-A) ---"
echo "Persona-A/hot.md 全部内容（应已在 agent-A/hot.md 的 alias-merge 里）:"
sudo -n cat "$SI/Persona-A/hot.md"
echo
echo "agent-A/hot.md 中是否含 alias-merge 标记:"
sudo -n grep -E "Legacy alias merge|From self-improving/Persona-A" "$SI/agent-A/hot.md" | head -3
echo

echo "--- B4. typo dir /corrrections.md/ ---"
sudo -n ls -la "$SI/persona-A/corrrections.md/" 2>&1 | head -5
echo

echo "--- B5. Cron 引用 persona-A/ 的 ID ==="
sudo -n /usr/bin/openclaw cron list --json 2>/dev/null | grep -v "Config warnings\|qqbot" | python3 -c "
import json,sys
data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get('items', data.get('jobs', []))
for j in items:
    p = j.get('payload',{})
    msg = p.get('message','') if isinstance(p,dict) else ''
    if 'self-improving/persona-A' in msg or 'self-improving/Persona-A' in msg:
        print(f\"id={j.get('id')} name={j.get('name')} agent={j.get('agentId')}\")
        print(f\"  payload.message snippet: {msg[:200]}...\")
"
echo

echo "=== C. 预期执行清单（dry-run 不执行） ==="
cat <<'EOF'
[计划]
1. 整体 backup 到 /root/.openclaw/workspace/memory/.archive/persona-A-merge-$(date +%Y%m%d-%H%M%S)/
2. 把 persona-A/hot.md 中 ts=2026-05-07/08/09 的 5 条 self-audit 记录追加到 agent-A/hot.md
   (agent-A/hot.md 加一段 ## 2026-05-10 persona-A-dir merge tail)
3. 把 persona-A/signals.md 的 ## 2026-W19 section 整体 append 到 agent-A/signals.md
4. 删除 persona-A/corrrections.md/ (空目录)
5. 删除 Persona-A/ 整个目录 (内容已在 agent-A 的 5/5 alias merge 里)
6. 删除 persona-A/ 整个目录 (内容已迁到 agent-A/)
7. 编辑 cron <CRON_ID_MAIN> payload（self-improving-daily-reflection-persona-A 那一条），把
   "memory/self-improving/persona-A/" 改成 "memory/self-improving/agent-A/"
8. 验证 patrol 脚本 patrol.sh 期望的目录结构
EOF
echo
echo "=== dry-run 结束。要执行请运行 10-persona-A-merge-execute.sh ==="
