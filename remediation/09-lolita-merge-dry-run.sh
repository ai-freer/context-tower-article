#!/bin/bash
# DRY-RUN 模式 - 只 diff 和打印，不动文件
# 验证 lolita/Lolita/main 目录合并方案

set -uo pipefail
SI="/root/.openclaw/workspace/memory/self-improving"

echo "=== Step 2 dry-run: lolita/Lolita/main 目录合并 ==="
echo "时间: $(date -u +%FT%TZ)"
echo

echo "=== A. 当前文件清单 ==="
for d in lolita Lolita main; do
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

echo "--- B1. lolita/hot.md 中 main/hot.md 缺失的条目 ---"
# main/hot.md 已经包含 'Legacy alias merge (2026-05-05)' 把 lolita 的内容合并进去
# 但 lolita 在 2026-05-07/08/09 又有了新条目
echo "lolita/hot.md 中 ts=2026-05-07/08/09 条目（应迁到 main/）:"
sudo -n cat "$SI/lolita/hot.md" | grep -E "ts: 2026-05-0[789]" | head -10
echo

echo "--- B2. lolita/signals.md vs main/signals.md ---"
echo "lolita/ 包含 W19 (2026-05-09) 数据；main/ 缺这部分"
echo "lolita/signals.md 中 '## 2026-W19' section 行数:"
sudo -n cat "$SI/lolita/signals.md" | awk '/^## 2026-W19/,EOF' | wc -l
echo "main/signals.md 中是否已含 '## 2026-W19':"
sudo -n grep -c "^## 2026-W19" "$SI/main/signals.md" || echo 0
echo

echo "--- B3. Lolita/hot.md (5/2 老内容，已通过 alias merge 入 main) ---"
echo "Lolita/hot.md 全部内容（应已在 main/hot.md 的 alias-merge 里）:"
sudo -n cat "$SI/Lolita/hot.md"
echo
echo "main/hot.md 中是否含 alias-merge 标记:"
sudo -n grep -E "Legacy alias merge|From self-improving/Lolita" "$SI/main/hot.md" | head -3
echo

echo "--- B4. typo dir /corrrections.md/ ---"
sudo -n ls -la "$SI/lolita/corrrections.md/" 2>&1 | head -5
echo

echo "--- B5. Cron 引用 lolita/ 的 ID ==="
sudo -n /usr/bin/openclaw cron list --json 2>/dev/null | grep -v "Config warnings\|qqbot" | python3 -c "
import json,sys
data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get('items', data.get('jobs', []))
for j in items:
    p = j.get('payload',{})
    msg = p.get('message','') if isinstance(p,dict) else ''
    if 'self-improving/lolita' in msg or 'self-improving/Lolita' in msg:
        print(f\"id={j.get('id')} name={j.get('name')} agent={j.get('agentId')}\")
        print(f\"  payload.message snippet: {msg[:200]}...\")
"
echo

echo "=== C. 预期执行清单（dry-run 不执行） ==="
cat <<'EOF'
[计划]
1. 整体 backup 到 /root/.openclaw/workspace/memory/.archive/lolita-merge-$(date +%Y%m%d-%H%M%S)/
2. 把 lolita/hot.md 中 ts=2026-05-07/08/09 的 5 条 self-audit 记录追加到 main/hot.md
   (main/hot.md 加一段 ## 2026-05-10 lolita-dir merge tail)
3. 把 lolita/signals.md 的 ## 2026-W19 section 整体 append 到 main/signals.md
4. 删除 lolita/corrrections.md/ (空目录)
5. 删除 Lolita/ 整个目录 (内容已在 main 的 5/5 alias merge 里)
6. 删除 lolita/ 整个目录 (内容已迁到 main/)
7. 编辑 cron <CRON_ID_MAIN> payload（self-improving-daily-reflection-lolita 那一条），把
   "memory/self-improving/lolita/" 改成 "memory/self-improving/main/"
8. 验证 patrol 脚本 patrol.sh 期望的目录结构
EOF
echo
echo "=== dry-run 结束。要执行请运行 10-lolita-merge-execute.sh ==="
