# 上下文管理九层塔 · Agent Context Engineering

> 一个真正长期运行的 AI Agent，需要的不是更大的上下文窗口，而是一套完整的上下文治理体系。

本仓库收录"上下文管理九层塔"的报告、写作输入包与配套修复脚本。九层塔讨论的是通用 Agent 的记忆与上下文管理；我们的实验场是 OpenClaw 多 Agent 环境，具体实现只作为例子。

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

## 九层塔 2.0（未发布）

- [架构升级正文](04-context-tower-2.0.md)：宿主运行时变强之后，重新梳理九层职责、状态边界与跨层契约；以 OpenClaw 2.0 为例的落地放在附录。
- [迁移验收清单](05-context-tower-2.0-validation.md)：18 个行为验收场景及发布门槛，尚未执行。
- 保留原版报告；不将设计建议当作当前生产状态。

## 当前工程状态（实验场：OpenClaw）

OpenClaw 2.0 已退役 QMD，检索和召回改由内置 Memory 负责。基于 QMD 的 retention、巡检和 warm compression 机制随之停用：旧的每日 warm compression 定时入口已于 2026-10-31 停用，相关巡检改为检查内置记忆。内置记忆上的 retention 与召回质量尚未验收。

2026-06-08 QMD 时期的治理闭环记录保留在
[`remediation/22-qmd-retention-and-patrol-status-2026-06-08.md`](remediation/22-qmd-retention-and-patrol-status-2026-06-08.md)，仅作历史参考。

## 配套：remediation/

[`remediation/`](remediation/) 目录收录 21 个 idempotent 脚本，是第一版九层塔（QMD 时期）修复过程的记录，包括 qmd 容错 patch、lossless-claw secret redaction、目录合并、qmd cleanup、wiki synthesis cron 等。其中 QMD 相关脚本不适用于 OpenClaw 2.0，仅作历史参考。

## License

CC BY 4.0 — 可以自由引用、改写、二次创作，注明来源即可。
