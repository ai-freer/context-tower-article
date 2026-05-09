#!/bin/bash
# 把 lossless-claw 源码改动提交到它自己的 repo（独立于 userfiles）
set -uo pipefail

REPO=/root/lossless-claw-enhanced

echo "=== lossless-claw repo info ==="
git -C "$REPO" remote -v 2>&1 | head -3
git -C "$REPO" branch --show-current
echo

echo "=== status ==="
git -C "$REPO" status --short 2>&1 | head -20
echo

echo "=== 最近提交风格 ==="
git -C "$REPO" log --oneline -5 2>&1
echo

echo "=== 看看 dist/ 是否被 gitignore ==="
git -C "$REPO" check-ignore -v dist/index.js 2>&1 || echo "(dist not ignored)"
echo

echo "=== 看 .gitignore ==="
cat "$REPO/.gitignore" 2>/dev/null | head -10
