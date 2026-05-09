# 上下文管理九层塔：OpenClaw Context Engineering 文章主笔输入包

- Date: 2026-05-06
- Purpose: 脱敏后，将当前 OpenClaw 上下文管理实践抽象成一篇可公开的架构/教程文章。
- Intended lead writer: Lisa
- Engineering validation contributors: Nyx / 桃子

## 1. 文章定位

这篇文章不是审计报告，也不是私有系统复盘。它应该是一篇面向 OpenClaw 进阶用户与 AI Agent builder 的架构教程：

> 如果“三层记忆架构”回答的是“如何开始让 Agent 记住东西”，那么“上下文管理九层塔”回答的是“如何让 Agent 在长期运行、多会话、多任务、多 Agent 协作中持续治理上下文”。

核心观点：

- 大上下文窗口不是上下文管理。
- 记忆不是简单堆文件或向量库。
- 一个可长期运行的 Agent，需要把身份、规则、记忆、检索、召回、压缩、整理、反思、技能化连成闭环。
- Context Engineering 的关键是“治理上下文”：写入、召回、压缩、清噪、晋升、验证、回滚。

## 2. 脱敏原则

写作时应删除或抽象：

1. 个人姓名、私有昵称、私聊关系、群聊名称、Telegram topic、具体 sender id。
2. 具体绝对路径中的个人空间痕迹；可改成 `~/.openclaw/workspace/memory/...`。
3. 私有 memory 内容、真实项目细节、sentinel 字符串、内部 token、账号、URL。
4. 把“昨天/今天某 bot 修复了什么”改成“在一次运行中观察到的问题”。
5. 保留工程经验，但改成通用案例：timeout、噪声污染、watchdog、fallback、rerank 成本。

## 3. 推荐标题

主标题：

**上下文管理九层塔：OpenClaw Agent 的长期记忆、主动召回与自我进化架构**

备选：

- **Context Management Pyramid: OpenClaw Agent 的九层上下文工程实践**
- **不只是 Memory：OpenClaw Agent 的九层上下文管理架构**
- **从记忆到治理：OpenClaw 上下文管理九层塔**

## 4. 九层塔总览（三组三层）

### 第一组：基础上下文层 / Foundation

| 层 | 名称 | 核心职责 |
|---|---|---|
| L1 | 身份注入层 | 定义 Agent 是谁、面向谁、默认语气和边界 |
| L2 | 规则治理层 | 定义工具使用、读写边界、安全和任务协议 |
| L3 | 文件记忆层 | 用 durable files 保存长期事实、项目、偏好、决策 |

### 第二组：运行时召回层 / Runtime Recall

| 层 | 名称 | 核心职责 |
|---|---|---|
| L4 | 语义检索层 | 用 embedding / hybrid search / fallback 从长期记忆中找材料 |
| L5 | 主动召回层 | 在用户消息进入 Agent 前自动注入相关摘要 |
| L6 | 会话生存层 | 保存会话、处理 compaction、避免长任务中断丢失 |

### 第三组：长期进化层 / Long-term Evolution

| 层 | 名称 | 核心职责 |
|---|---|---|
| L7 | 后台整理层 | 定期 digest、去重、清噪、晋升短期记忆 |
| L8 | 自我迭代层 | 从纠错、反思、信号中沉淀行为规则 |
| L9 | 能力进化层 | 将高频 workflow 提炼成可复用 skills |

## 5. 每层写法模板

每层建议都按同一结构写：

1. 这层解决什么问题
2. OpenClaw 中对应哪些组件
3. 输入是什么 / 输出是什么
4. 最小配置或目录示例
5. 常见坑
6. 和上一层 / 下一层如何连接

## 6. 九层细化

### L1 身份注入层：Agent 是谁

组件示例：

- `SOUL.md`
- `IDENTITY.md`
- `USER.md`
- persona / tone / role prompt

职责：

- 定义 Agent 的身份、角色、默认语气、边界。
- 给所有后续上下文一个解释框架。

常见坑：

- 身份文件过长，挤占有效上下文。
- 多 Agent 场景中身份相互污染。
- persona 写得太强，压过任务目标。

### L2 规则治理层：Agent 该怎么行动

组件示例：

- `AGENTS.md`
- `BOOTSTRAP.md`
- `TOOLS.md`
- tool policy / task protocol / watchdog protocol

职责：

- 定义工具使用规则。
- 定义 memory 读写边界。
- 定义安全边界、untrusted context 标记、协作协议。

常见坑：

- 规则堆太多，Agent 遵循率下降。
- 规则没有分层，任务协议、人格、工具说明混在一起。
- 缺少“任务完成后必须汇报/落盘”的闭环。

### L3 文件记忆层：长期事实载体

组件示例：

```text
memory/
  shared/
  daily/
  projects/
  private/
  self-improving/
```

职责：

- 保存长期事实、决策、项目状态、用户偏好。
- Markdown 可读、可 diff、可备份、可人工修正。

常见坑：

- 把短期日志和长期事实混在一起。
- shared/private 边界不清。
- MEMORY.md 变成垃圾桶，导致 bootstrap 截断。

### L4 语义检索层：从记忆中找上下文

组件示例：

- `memory_search`
- QMD
- embedding provider
- hybrid search / BM25 / vector search
- fallback builtin index

职责：

- 不把所有记忆塞进 prompt，而是按需召回。
- 让 Agent 在回答前检索相关 durable memory 和 session transcript。

工程案例：QMD query latency

- QMD query 不只是向量检索，可能包含 query expansion、hybrid search、LLM rerank。
- 单纯把 timeout 从 15s 提到 60s 只能解决配置层问题；如果 query fan-out 和 rerank 太重，仍需调优。
- 搜索系统要区分：索引是否更新、embedding 是否覆盖、query path 是否稳定、ranking 是否符合预期。

常见坑：

- 只看“文件已索引”，忽略 embedding 覆盖率。
- exact query 被日志/评论文件排在源文件前面。
- fallback 静默工作，掩盖 primary backend 的性能问题。

### L5 主动召回层：消息前自动带上下文

组件示例：

- Active Memory plugin
- before-prompt recall subagent
- short summary injection

职责：

- 用户无需显式说“查记忆”，系统自动找相关上下文。
- 将召回结果压缩为短摘要注入 prompt。

常见坑：

- 低质量摘要污染当前对话。
- active memory 输出被误当作 trusted fact。
- recall subagent timeout 太短或模型太弱。

治理建议：

- 注入内容标记为 untrusted context。
- 加质量阈值、空结果过滤、debug summary。
- 对慢 query 可以选择更轻的 search/vsearch 模式。

### L6 会话生存层：长会话不丢上下文

组件示例：

- Session Memory hook
- session transcript export
- compaction safeguard
- memoryFlush before compaction
- lossless/context compaction plugin（如有）

职责：

- 将会话历史保存为可恢复、可搜索的材料。
- 在上下文窗口接近极限时，先把重要信息写入 durable memory。

常见坑：

- compaction/heartbeat/system prompt 被写入 transcript，后续又被 Dreaming 晋升。
- 只依赖大窗口模型，不做显式持久化。
- 长任务没有外化 plan，压缩后目标漂移。

### L7 后台整理层：Dreaming 消化上下文

组件示例：

- Memory Core Dreaming
- deep / light / REM sleep
- promotion artifacts
- session-corpus
- post-sweep watchdog

职责：

- 将短期 recall、session corpus、daily notes 做后台整理。
- 提炼候选长期记忆，去重、晋升、生成摘要。

工程案例：post-dreaming hygiene

- Dreaming 本身能整理记忆，但也可能把 heartbeat / maintenance / compaction 噪声纳入候选。
- 因此需要 post-sweep watchdog：检查产物、清理噪声、统计 promotion ratio、报告异常。

常见坑：

- 后台任务成功，但报告投递失败，导致无人知道结果。
- 噪声进入 corpus 后被长期污染。
- promotion threshold 太宽，低价值内容晋升。

### L8 自我迭代层：从错误中改进行为

组件示例：

```text
memory/self-improving/
  hot/
  corrections/
  signals/
  shared-rules/
```

职责：

- 保存错误、纠正、反思、行为信号。
- 将重复出现的纠错晋升为稳定规则。

常见坑：

- 目录命名/agent identity mapping 不一致，导致扫描漏项。
- 把一次性偏好过早晋升为全局规则。
- 没有 reviewer 或 threshold，规则膨胀。

### L9 能力进化层：把经验变成技能

组件示例：

- Skill Evolution
- harvest / synthesize / review / promote
- shared skills directory

职责：

- 从重复任务中提炼 reusable skill。
- 将 workflow 固化为可复用能力，而不是每次从零做。

常见坑：

- 技能过窄、命名差、数量爆炸。
- 私有上下文被错误抽象成 shared skill。
- 缺少定期审计和 deprecation。

## 7. 推荐正文结构

### 开头

- 讲大上下文窗口的幻觉：窗口变大，不等于系统会管理上下文。
- 引出九层塔：从身份、规则、记忆，到检索、主动召回、压缩，再到 Dreaming、自我改进和技能化。

### 第一部分：为什么需要九层

- 长期 Agent 面临的问题：遗忘、混淆、噪声、重复劳动、压缩丢失、跨会话断裂。
- 单一 memory 文件或向量库无法解决全链路问题。

### 第二部分：九层塔总览图

建议图示：

```text
L9 Skill Evolution        经验 → 可复用技能
L8 Self-Improving         错误/反馈 → 行为规则
L7 Dreaming               短期上下文 → 长期记忆
────────────────────────────────────────
L6 Session Survival       会话保存 / compaction / flush
L5 Active Recall          消息前主动召回
L4 Semantic Retrieval     embedding / search / fallback
────────────────────────────────────────
L3 Durable Memory Files   Markdown 长期事实
L2 Rule Governance        行为边界 / 工具协议
L1 Identity Injection     身份 / 用户 / persona
```

### 第三部分：逐层详解

按 L1-L9 展开。

### 第四部分：三个工程案例

1. Query timeout：从“调大 timeout”到“治理 query path”。
2. Dreaming 噪声：为什么后台整理后还需要 watchdog。
3. Session survival：为什么 compaction 前必须 flush durable memory。

### 第五部分：如何逐步搭建

建议路径：

1. 先建 L1-L3：身份、规则、文件记忆。
2. 再接 L4-L6：检索、主动召回、会话保存。
3. 最后启用 L7-L9：Dreaming、自我改进、技能进化。

### 结尾

核心总结：

> 好的 Agent 不是“记得更多”，而是“知道什么该记、什么时候召回、何时压缩、如何清噪、怎样从经验中进化”。

## 8. Lisa 主笔注意事项

- 语气：清晰、结构化、有叙事感；不要像内部审计报告。
- 避免过多内部路径和事故细节。
- 保留工程真实性：timeout、fallback、watchdog、noise cleanup 可以作为案例。
- 面向读者：OpenClaw 进阶用户 + AI Agent builder。
- 每层给一个“为什么需要它”的直觉例子。

## 9. 桃子可补充内容

建议桃子补：

1. 脱敏后的配置片段。
2. post-dreaming watchdog 的伪代码或流程图。
3. QMD timeout / rerank 成本的工程说明。
4. promotion stats 如何作为健康指标。
5. active-memory 质量过滤建议。

## 10. Nyx 可补充内容

Nyx 可补：

1. 从审计报告抽象出的系统健康矩阵。
2. 九层之间的数据流。
3. 常见故障模式表。
4. 最终文章的术语统一。

## 11. Daniel 的最终定位补充

Daniel 对文章定位的补充意见：

1. 主要面向 OpenClaw，但这套 context architecture 有一定通用性，可让更广泛的 AI Agent builder 读懂。
2. 本文是半独立文章：可以和之前“三层记忆架构”做对比，但不依赖读者读过前文。
3. 不需要 step-by-step 安装教程，但可以解释关键依赖与关键因素；定位介于纯架构文章和轻教程之间。
4. 名称固定为“九层塔”。九层不算多，因为每层处理不同维度的上下文事务。
5. 文章需要体现：这套架构来自近一个月迭代和运维治理，不是一次性设计；运维措施也是架构成熟的一部分。
6. 相比简单三层架构，九层塔在 session 中的效果更明显，并强化了 Agent 的基础身份认知。
7. 目标是更完整的上下文管理与压缩：不是单点记忆能力，而是把上下文相关功能纳入一个可治理系统。

写作建议：

- 可以在开头明确：“九层塔不是为了复杂而复杂，而是因为长期 Agent 运行中出现的问题天然分布在九类不同层面。”
- 可以加入和三层架构的对比表：三层解决入门记忆，九层塔解决长期运行治理。
- 结尾强调：九层塔的价值不是多一堆模块，而是让上下文进入可观测、可修复、可进化的工程闭环。

---

## 14. 2026-05-09 Update: fold Lossless Context Engine into V1

V1 must be revised before publication because the earlier architecture brief underplayed one important layer: the pluggable runtime context engine. In this deployment, that layer is lossless-claw.

### 14.1 Revised nine-layer tower

| Layer | Name | Core responsibility |
|---|---|---|
| L1 | Identity Injection | Who the agent is, who it serves, tone, boundaries |
| L2 | Rule Governance | Tool rules, safety boundaries, memory write/read protocols |
| L3 | Durable File Memory | Markdown/project/preference/decision memory as stable source of truth |
| L4 | Semantic Retrieval | QMD / embedding / hybrid search over memory and sessions |
| L5 | Active Recall | Pre-turn automatic recall summaries injected before reasoning |
| L6 | Session Survival + Lossless Context Engine | Preserve long-session continuity through pluggable context assembly, DAG/summary/LCM-style compression, and fallback compaction |
| L7 | Offline Consolidation | Dreaming / promotion / cleanup from short-term traces into long-term memory |
| L8 | Knowledge Wiki + Audit Surfaces | Compiled knowledge, dashboards, reports, searchable source archive |
| L9 | Self-Improvement + Skills + Watchdogs | Corrections, rules promotion, workflow skill harvesting, cron/subagent operational loops |

### 14.2 How to explain lossless-claw publicly

Do not present lossless-claw as “the memory system.” Present it as the runtime continuity layer:

- It sits between raw conversation history and the model’s finite context window.
- It complements retrieval rather than replacing it.
- It helps long sessions remain coherent before facts have been distilled into durable memory.
- It still needs durable memory writes, retrieval, dreaming, and watchdog validation around it.

Suggested public wording:

> A mature agent needs a session-survival layer, not just a bigger context window. In OpenClaw this can be implemented as a pluggable context engine: it ingests the conversation stream, assembles the next model context, and handles compression when the raw transcript no longer fits. Retrieval and long-term memory answer “what should we bring back?”; the context engine answers “how do we keep this live conversation coherent right now?”

### 14.3 V1 article implication

The article should no longer imply that compaction memoryFlush is the main session-survival mechanism. MemoryFlush is a durable fallback. The center of L6 should be the context-engine slot, with memoryFlush and safeguard compaction as safety rails.
