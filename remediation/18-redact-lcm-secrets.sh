#!/bin/bash
# P0a: redact existing API keys / tokens in lcm.db summaries
# 不动 messages 表（保留原始对话）；只清理 summaries（那是泄露放大点）
set -uo pipefail

DB=/root/.openclaw/lcm.db
TS=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP="/root/.openclaw/lcm.db.pre-redact-$TS"

echo "=== P0a: redact summaries in lcm.db ==="
echo "时间: $TS"
echo

echo "--- 1. 备份 lcm.db ---"
cp -p "$DB" "$BACKUP"
echo "✅ backup: $BACKUP ($(du -h $BACKUP | cut -f1))"
echo

echo "--- 2. PRE-redact 统计 ---"
sqlite3 "$DB" "
SELECT 'leaves with sk-[a-zA-Z0-9]{40+}', COUNT(*) FROM summaries WHERE content GLOB '*sk-[A-Za-z0-9]*' AND length(substr(content, instr(content,'sk-')+3, 50)) > 30;
SELECT 'leaves with bot_token=...', COUNT(*) FROM summaries WHERE content LIKE '%bot_token%' OR content LIKE '%access_token%';
SELECT 'leaves with API_KEY mention', COUNT(*) FROM summaries WHERE content LIKE '%API_KEY%' OR content LIKE '%api_key%';
"
echo

echo "--- 3. 应用 redaction（regex via Python，sqlite 没原生 regex_replace） ---"
python3 <<'PYEOF'
import sqlite3, re

DB = "/root/.openclaw/lcm.db"
conn = sqlite3.connect(DB)
conn.row_factory = sqlite3.Row

# Redaction patterns (顺序敏感 — 先匹配长的)
PATTERNS = [
    # OpenAI / ltcraft / saic 风格 sk-XXXXXXX (40+ chars)
    (re.compile(r'sk-[A-Za-z0-9_-]{32,}'), '[REDACTED_API_KEY]'),
    # Bearer tokens
    (re.compile(r'(?i)bearer\s+[A-Za-z0-9_\.\-]{20,}'), 'Bearer [REDACTED_TOKEN]'),
    # Telegram bot token: 数字:大写小写数字串
    (re.compile(r'\b\d{8,12}:[A-Za-z0-9_-]{30,}\b'), '[REDACTED_BOT_TOKEN]'),
    # Generic "api_key":"..." or api_key=...
    (re.compile(r'(?i)("?api[_-]?key"?\s*[:=]\s*"?)([A-Za-z0-9_\-]{20,})'), r'\1[REDACTED]'),
    # access_token, bot_token, refresh_token
    (re.compile(r'(?i)("?(access|bot|refresh|secret)_?token"?\s*[:=]\s*"?)([A-Za-z0-9_\-\.]{20,})'), r'\1[REDACTED]'),
]

cur = conn.execute("SELECT summary_id, content FROM summaries")
to_update = []
for row in cur:
    original = row['content']
    redacted = original
    hit_patterns = []
    for pat, replacement in PATTERNS:
        new, count = pat.subn(replacement, redacted)
        if count > 0:
            hit_patterns.append((pat.pattern[:40], count))
            redacted = new
    if redacted != original:
        to_update.append((row['summary_id'], redacted, hit_patterns))

print(f"Found {len(to_update)} summaries to redact")
print()
for sid, _, hits in to_update[:8]:
    print(f"  {sid}: " + ", ".join([f"{p}:{c}" for p,c in hits]))
if len(to_update) > 8:
    print(f"  ... and {len(to_update)-8} more")
print()

# Apply updates
for sid, content, _ in to_update:
    conn.execute("UPDATE summaries SET content = ? WHERE summary_id = ?", (content, sid))
conn.commit()

# Rebuild FTS to sync redaction into searchable index
print("Rebuilding summaries_fts to sync redactions...")
conn.execute("INSERT INTO summaries_fts(summaries_fts) VALUES('rebuild')")
conn.commit()
print(f"✅ Redacted {len(to_update)} summary rows. FTS rebuilt.")

# 验证：扫一遍看还有没有残留 sk- 模式
post = list(conn.execute("SELECT summary_id, substr(content, instr(content,'sk-'), 60) FROM summaries WHERE content GLOB '*sk-[A-Za-z0-9]*'"))
remaining = [(sid,snip) for sid,snip in post if re.search(r'sk-[A-Za-z0-9_-]{20,}', snip)]
print(f"\nPost-redact: {len(remaining)} leaves still match sk-XXX pattern (likely false-positives like sk-id or sk- in URLs)")
for sid, snip in remaining[:5]:
    print(f"  {sid}: ...{snip}...")
PYEOF

echo
echo "--- 4. POST-redact 验证 ---"
sqlite3 "$DB" "
SELECT 'summaries total', COUNT(*) FROM summaries;
SELECT 'leaves still matching sk-[40+] pattern', COUNT(*) FROM summaries WHERE content GLOB '*sk-[A-Za-z0-9]*' AND length(substr(content, instr(content,'sk-')+3, 50)) > 30;
SELECT '[REDACTED_*] markers in content', COUNT(*) FROM summaries WHERE content LIKE '%[REDACTED%';
"
echo
echo "✅ 完成。如需还原: sudo cp $BACKUP $DB"
