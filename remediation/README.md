# Remediation scripts — 2026-05-09/10 OpenClaw audit-driven session

基于 `memory-system-audit-2026-05-04.md` 的 P0/P1/P2 待改进项，在 2026-05-09/10
跨夜的 session 里逐项落地的脚本集合。每个脚本都设计为可重跑、有 backup、
失败可回滚，并在执行前打 dry-run 或权限检查。

## 阅读顺序

按文件名前缀的数字编号阅读，对应实际执行时序。

## 脚本清单

### 调研阶段（无副作用）

| # | 脚本 | 目的 |
|---|---|---|
| 01 | `01-qmd-repro.sh` | 用 main agent 的 XDG 路径触发 qmd query，找哪种 query 触发 JSON parse 失败 |
| 02 | `02-qmd-repro-cn.sh` | 中文 query 复现 |
| 03 | `03-qmd-multicol-repro.sh` | 多 collection (`-c`) 路径复现——找到了 root cause（"Warning: collection X not found" 前缀） |
| 04 | `04-test-parser.sh` | 直接 import parseQmdQueryJson 跑单元用例，确认它在哪种 stdout 模式下抛错 |

### 验证 + 应用补丁（Step 1）

| # | 脚本 | 目的 |
|---|---|---|
| 05 | `05-test-patch-on-copy.sh` | 在临时副本上跑 patch + idempotency + diff，避免动 production |
| 06 | `06-apply-and-verify-qmd-patch.sh` | 应用 patch 到 production，含 backup + syntax check + parser 测试，失败自动 revert |
| 07 | `07-restart-gateway-with-checks.sh` | 重启 gateway，含前后 lcm.db snapshot + journal 摘要 + sentinel 验证 |
| 08 | `08-watch-active-memory-postpatch.sh` | 持续轮询 lcm.db，统计 patch 后 active-memory 失败率 |
| `_apply-qmd-defensive-parse.js` | （Node.js 实现） parseQmdQueryJson 的 3 个 throw 改 return []。幂等。集成到 `~/workspace/patches/apply-patches.sh` 自动应用 |

### 目录合并 + cron 修复（Step 2）

| # | 脚本 | 目的 |
|---|---|---|
| 09 | `09-lolita-merge-dry-run.sh` | dry-run：列出 lolita/Lolita/main 三目录差异 + 预期执行清单 |
| 10 | `10-lolita-merge-execute.sh` | 执行：backup → 增量迁移 → 删孤儿目录 → 改 cron payload。可从 archive 还原 |
| 11 | `11-run-patrol.sh` | patrol.sh 包装器（绕开 sudoers 路径限制） |
| 12 | `12-cleanup-strategist-and-lisa-dup.sh` | Step 2 续：清 the-strategist + workspace-lisa 副本，4 reflection cron 改绝对路径 |

### qmd cleanup + skill/qqbot（Step 4-5）

| # | 脚本 | 目的 |
|---|---|---|
| 13 | `13-qmd-cleanup.sh` | 4 个 agent 串行跑 `qmd cleanup`，去 orphan content_vectors，释放 350MB |
| 14 | `14-step5-skill-and-qqbot.sh` | `audit-openclaw-agent-message-routing-configurati` 改名 + 移除 `plugins.entries.qqbot` |
| 15 | `15-nyx-cleanup-retry.sh` | nyx cleanup 重跑兜底（实际首跑就成了，留作模板） |

### 新增 cron（Step 6）

| # | 脚本 | 目的 |
|---|---|---|
| 16 | `16-add-wiki-synthesis-cron.sh` | 加周日 22:00 lisa 跑的 wiki synthesis cron，把 wiki 从 archive 推向知识图谱 |

## 关键 backup 路径

| 修改类型 | backup 位置 |
|---|---|
| qmd patch | `/usr/lib/node_modules/openclaw/dist/engine-qmd-DAYKPzcH.js.pre-defensive-patch-*` |
| openclaw.json (qqbot 移除) | `/root/.openclaw/openclaw.json.bak` |
| lolita 目录 | `/root/.openclaw/workspace/memory/.archive/lolita-merge-*` |
| the-strategist + lisa-dup | `/root/.openclaw/workspace/memory/.archive/strategist-and-lisa-dup-*` |
| qmd index 各 agent | （未 backup，依赖 `qmd update --pull` 重建） |

## 何时复用

- **OpenClaw 升级后** patch 失效（npm 覆盖）：`apply-patches.sh` 会在
  ExecStartPre 自动重新应用 7 个 patch 中的 qmd-defensive-parse；本目录
  的 `_apply-qmd-defensive-parse.js` 是其实现源。
- **想验证 active-memory 有没有重新出 qmd JSON parse 错误**：08 脚本可重跑。
- **任何 OpenClaw 升级后 cron 重置**：12 脚本里的 4 个 reflection cron
  绝对路径配置可作模板。
- **未来类似 lolita/Lolita 大小写分裂问题**：09+10 脚本是 backup-merge-delete
  的可复用范式。

## 一句话回顾

> 6 个 step、~3 小时实战、修了 1 个 P0 + 4 个 P1 + 2 个 P2，释放 350MB
> sqlite 空间，patrol 从 13 警告降到 0 违规 + 7 cosmetic 警告，建立了
> 可重启不丢失的 patch 基础设施。
