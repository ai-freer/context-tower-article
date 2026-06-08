# QMD Retention + Patrol Status — 2026-06-08

This note records the current OpenClaw context-governance status behind the "context tower" project. It is an operational snapshot, not a public article draft.

## Scope

- Layer coverage: L4 semantic retrieval, L5 active recall, L6 session survival, L7 background maintenance.
- Systems touched: QMD indexes, LCM weekly audit, session retention, storage patrol, weekly promote / signal cron jobs.
- Goal: keep long-running multi-agent memory searchable while preventing vector growth, stale collection buildup, and retained-session re-export loops.

## Final Status

The 2026-06-08 repair round is closed.

Final vector waterline:

| Agent | Vectors | Cap | % Cap | Status |
|---|---:|---:|---:|---|
| main | 11,653 | 12,000 | 97% | green, near cap |
| lisa | 16,838 | 20,000 | 84% | green |
| nyx | 8,863 | 15,000 | 59% | green |
| doubao | 7,652 | 10,000 | 77% | green |

LCM weekly audit:

- DB size: 309.8MB.
- WAL size: 5.7MB.
- Size alert: none, below 500MB threshold.
- Conversation count: 1,803.
- Message count: 41,573.
- Summary count: 825.

## Completed Work

### Phase 1: stale QMD collection cleanup

- Cleared 12 stale `custom-*` QMD collections.
- Confirmed all four agents returned under their configured vector caps.
- Added real vector stats to patrol reporting so over-cap and stale collection drift are visible before they become failures.

### Phase 2: session retention loop

- Added `/opt/scripts/qmd-session-retention.py`.
- Added retention manifest semantics so retained sessions can be summarized and original vectors can be pruned without losing recall.
- Patched QMD manager so retained sessions are skipped during `exportSessions()` and do not get re-exported from raw `.jsonl`.
- Gateway restart completed after approval, making the manifest skip patch active in the running process.

Doubao trial result:

- Retained sessions: 1.
- Original vectors released: 848.
- Summary/archive records: 1 each.
- Doubao vector count moved from 8,407 to 7,652 during the Phase 2 test path.

### Recall validation

- Doubao warm compression live completed for the eligible warm session.
- Summary stub recall validation passed.
- Test query: `共享规则 code-name-binding 2026-06-07`.
- Result: two matching memory fragments were returned for the compressed session content.

### Cron and patrol fixes

- `run-promote-weekly.sh`: added `signals.md` extraction step.
- `memory-health-check.sh`: fixed grep behavior and `lolita` -> `main` mapping.
- `weekly-signal-remind-saturday`: fixed `lolita` -> `main` mapping.
- `storage-patrol-weekly`: corrected doubao cap from 12K to 10K.
- W23 signals migration was confirmed complete: `main/signals.md` contains W16-W23 records and `lolita/signals.md` was cleared.

## Operational Meaning

Before this round, the system could index and recall long-term memory but had weak enforcement around stale collections, retained-session re-export, and vector cap visibility.

After this round:

- QMD vector growth is observable by agent and cap.
- Stale `custom-*` collections can be detected and removed.
- High-vector sessions can be compressed into summary/archive form.
- Retained sessions are protected from automatic re-export.
- Recall can be tested against compressed session summary stubs.
- Weekly maintenance now includes signal extraction and correct agent-name mapping.

## Remaining Watch Items

- `main` sits at 97% of its vector cap. It is green, but the next dreaming / patrol cycle should consider pruning or retention candidates.
- W25 storage patrol should compare doubao vectors against this snapshot to confirm retention remains stable over time.
- Any future OpenClaw upgrade must preserve or reinstall the QMD manager retention skip behavior before relying on retained-session pruning.

## Public-Article Abstraction

For the public九层塔 article, this maps to the following reusable lessons:

- L4 retrieval needs index hygiene, not just embedding coverage.
- L5 active recall depends on fail-soft retrieval paths and clean summary stubs.
- L6 session survival must include retention manifests, not just one-shot compaction.
- L7 background maintenance needs measurable patrol reports and weekly deltas.
- Context governance is only closed when cleanup, compression, recall QA, and re-export prevention are all verified.
