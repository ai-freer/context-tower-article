# 上下文管理九层塔 · OpenClaw Context Engineering

> 一个真正长期运行的 AI Agent，需要的不是更大的上下文窗口，而是一套完整的上下文治理体系。

本仓库收录 OpenClaw 多 Agent 环境中"上下文管理九层塔"架构的报告、写作输入包与配套修复脚本。

## 在线阅读

| 入口 | 内容 |
|---|---|
| **[在线 HTML 报告（推荐）](https://ai-freer.github.io/context-tower-article/03-report.html)** | 渲染好的九层塔架构教程，含目录导航、阅读进度、自动 light/dark 主题 |
| [项目首页 / 文档导航](https://ai-freer.github.io/context-tower-article/) | 4 个文档卡片入口 |

## 文档清单

| # | 文件 | 角色 |
|---|---|---|
| 01 | [`01-brief.md`](01-brief.md) | 写作输入包（Brief）—— 文章定位、脱敏原则、9 层模板、踩坑清单 |
| 02 | [`02-report.md`](02-report.md) | 报告 markdown 源（v2，含本次更新后的最佳实践） |
| 03 | [`03-report.html`](03-report.html) | 报告 HTML 版（独立单文件，可直接打开） |

> 注：审计文档（运维过程时间线，含具体 chat ID / 内部 session key 等）出于隐私考虑未公开发布。

## 当前工程状态

2026-06-08 最新一轮上下文治理修复已闭环，详情见
[`remediation/22-qmd-retention-and-patrol-status-2026-06-08.md`](remediation/22-qmd-retention-and-patrol-status-2026-06-08.md)。

本轮把九层塔中的 L4/L5/L6/L7 从"能召回、能压缩"推进到"能巡检、能清噪、能验证、能防回流"：

- QMD stale `custom-*` collection 清理完成，4 个 agent 回到向量水位上限内。
- `qmd-session-retention.py` + retention manifest + QMD manager skip 补丁已落地并在 gateway restart 后生效。
- `storage-patrol.sh` 已增加真实 vector 水位和 retained/session summary 指标。
- doubao warm compression live 已跑通，summary stub 召回验证通过。
- cron 侧 signals 提炼、`lolita` -> `main` 映射、doubao cap 10K 修正均已完成。
- LCM weekly audit 健康：DB 309.8MB，WAL 5.7MB，无 size alert。

## 配套：remediation/

[`remediation/`](remediation/) 目录收录 21 个 idempotent 脚本，覆盖修复过程中的各步骤——qmd 容错 patch、lossless-claw secret redaction、目录合并、qmd cleanup、wiki synthesis cron 等。可作为类似系统的迁移参考。

## License

CC BY 4.0 — 可以自由引用、改写、二次创作，注明来源即可。
