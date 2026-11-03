# 上下文管理九层塔 · Agent Context Engineering

> 一个真正长期运行的 AI Agent，需要的不是更大的上下文窗口，而是一套完整的上下文治理体系。

本仓库收录「上下文管理九层塔」的两版报告、验收清单和写作输入包。九层塔讨论的是通用 Agent 的记忆与上下文管理；我们的实验场是 OpenClaw 多 Agent 环境，具体实现只作为例子。

当前版本是 **九层塔 2.0：从记忆组件到可托付的 Agent Runtime**。它没有增加层数，而是在九层能力之外，理清了五类状态、四条跨层契约和 18 个验收场景。

## 在线阅读

| 入口 | 内容 |
|---|---|
| **[九层塔 2.0 报告（推荐）](https://ai-freer.github.io/context-tower-article/04-context-tower-2.0.html)** | 交互版报告：九层剖面、周报案例、提交水位、回执核验、撤销演示和验收矩阵 |
| [项目首页](https://ai-freer.github.io/context-tower-article/) | 2.0 总览、文档导航和第一版档案 |
| [第一版报告](https://ai-freer.github.io/context-tower-article/03-report.html) | 第一版九层塔架构教程，含目录导航、阅读进度和 light/dark 主题 |

## 文档清单

### 九层塔 2.0

| 文件 | 内容 |
|---|---|
| [`04-context-tower-2.0.html`](04-context-tower-2.0.html) | 交互版报告，独立单文件，可直接打开 |
| [`04-context-tower-2.0.md`](04-context-tower-2.0.md) | 报告 Markdown 源 |
| [`05-context-tower-2.0-validation.md`](05-context-tower-2.0-validation.md) | 迁移验收清单：18 个行为验收场景和记录模板，尚未执行 |

报告中的架构和验收标准是设计建议，不代表当前生产状态。OpenClaw 2.0 的相关能力放在附录，按 2026-10-31 的官方文档整理，以目标版本为准。

### 第一版

| 文件 | 内容 |
|---|---|
| [`03-report.html`](03-report.html) | 第一版报告 HTML，独立单文件，可直接打开 |
| [`02-report.md`](02-report.md) | 第一版报告 Markdown 源 |
| [`01-brief.md`](01-brief.md) | 写作输入包：文章定位、脱敏原则、九层模板和踩坑清单 |

第一版写于 QMD 时期，其中 QMD 相关做法不适用于 OpenClaw 2.0，仅作历史参考。

> 注：审计文档（运维过程时间线，含具体 chat ID / 内部 session key 等）出于隐私考虑未公开发布。

## 当前工程状态（实验场：OpenClaw）

OpenClaw 2.0 已退役 QMD，检索和召回改由内置 Memory 负责。基于 QMD 的 retention、巡检和 warm compression 机制随之停用：旧的每日 warm compression 定时入口已于 2026-10-31 停用，相关巡检改为检查内置记忆。内置记忆上的 retention 与召回质量尚未验收。

## License

CC BY 4.0 — 可以自由引用、改写、二次创作，注明来源即可。
