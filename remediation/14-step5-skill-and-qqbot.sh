#!/bin/bash
# Step 5: 重命名截断的 skill + 移除 qqbot 重复声明
set -uo pipefail

SKILLS=/root/.openclaw/shared-skills
OLD_SKILL="audit-openclaw-agent-message-routing-configurati"  # 48 chars (truncated)
NEW_SKILL="audit-agent-message-routing"                       # 27 chars (clear)

echo "=== Step 5: skill rename + qqbot dedupe ==="
echo

# A. 重命名截断的 skill
echo "--- A. rename skill: $OLD_SKILL → $NEW_SKILL ---"
if [ -d "$SKILLS/$OLD_SKILL" ]; then
  if [ -d "$SKILLS/$NEW_SKILL" ]; then
    echo "❌ target $NEW_SKILL already exists, aborting"
    exit 1
  fi
  mv "$SKILLS/$OLD_SKILL" "$SKILLS/$NEW_SKILL"
  echo "✅ moved dir"
  # 更新 SKILL.md 的 slug 字段
  sed -i "s|^slug: ${OLD_SKILL}\$|slug: ${NEW_SKILL}|" "$SKILLS/$NEW_SKILL/SKILL.md"
  echo "✅ updated slug in SKILL.md"
  grep "^slug:" "$SKILLS/$NEW_SKILL/SKILL.md"
else
  echo "skill $OLD_SKILL not found, may have been renamed already"
fi
echo

# B. 移除 qqbot duplicate plugin 声明
echo "--- B. remove plugins.entries.qqbot from openclaw.json ---"
echo "(bundled qqbot 自动加载，本地空 config={} 不贡献任何东西，只触发 duplicate warning)"
/usr/bin/openclaw config unset plugins.entries.qqbot 2>&1 | grep -v "Config warnings\|qqbot:.*duplicate\|^$\|^├\|^│\|^╭\|^╰\|^◇" | head -10

echo
echo "--- 验证：再次运行 openclaw 看是否还有 qqbot warning ---"
/usr/bin/openclaw cron status 2>&1 | grep -E "qqbot|duplicate" | head -3
echo "(若上面无输出则 qqbot warning 已消除)"

echo
echo "--- 列出 shared-skills 看新命名 ---"
ls $SKILLS/ | sort | head -50
