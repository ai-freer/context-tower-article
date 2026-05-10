# 上下文管理九层塔：OpenClaw Context Engineering 文章主笔输入包

- Date: 2026-05-06
- Purpose: 脱敏后，将当前 OpenClaw 上下文管理实践抽象成一篇可公开的架构/教程文章。
- Intended lead writer: Lisa
- Engineering validation contributors: peer agents (e.g. nyx / doubao)

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
- **检索 CLI 的 stdout 容错**：当检索层 shell-out 到第三方 CLI（如 qmd）时，CLI 在 collection 不存在 / 参数异常时可能往 stdout 写 `Warning:` / `Usage:` 等非 JSON 文本。下游 JSON parser 必须**容错地跳过非 JSON 前缀**而不是抛错——抛错会让多 collection 路径整体退化到慢 fallback。最佳实践：parser 失败时 log warn + 返回空数组，让上层继续遍历其他 collection。
- **Index hygiene**：定期对每个 agent 的 index 跑 `cleanup`，去除 orphan 向量（content 已删但 vector 未清的脏数据）。orphan 比例 > 50% 是 index 体积膨胀的常见原因。

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
- **检索后端单点失败传染整条链路**：active memory 通常调用底层检索（L4），底层在多 collection 模式下若任一子 query 抛错，会让整条召回 retreat 到 builtin slow path（>10s / 0 hits）。要让底层容错（见 L4 parser 建议），主动召回层才能稳定。

治理建议：

- 注入内容标记为 untrusted context。
- 加质量阈值、空结果过滤、debug summary。
- 对慢 query 可以选择更轻的 search/vsearch 模式。
- **隔离失败域**：active memory 一次召回内部可能跨多个 collection / 多个数据源。任一子查询失败应该只丢自己的结果，不应让整条召回链失败。这要求 L4 parser 是 forgiving 的（fail-soft 返回 []），不是 fail-hard 抛异常。

### L6 会话生存层 + 无损压缩引擎：长会话不丢上下文

组件示例：

- Pluggable context engine（绑定到 `plugins.slots.contextEngine`）
- 实时摄入消息的 LCM-style sqlite store（lcm.db）
- DAG 层级摘要（leaf → condensed → root）
- Session Memory hook + session transcript export
- compaction safeguard + memoryFlush（兜底）
- lcm_grep / lcm_describe / lcm_expand_query（会话历史检索补充 L4）

职责：

- 将会话历史**实时摄入**到结构化 store，独立于 model context window。
- 在 context window 接近极限时，从 DAG 中选取相关摘要 + 保留最近 N 条原文，组装下一轮 model context。
- 大文件 / 大工具输出超阈值自动摘要（防 context 爆炸）。
- 支持上层 agent 通过专用工具（lcm_grep 等）反向查询会话历史。

最佳实践：

- **绑定 context engine slot**：必须在配置里显式 `plugins.slots.contextEngine: "<engine-id>"`，否则系统默认使用 legacy 截断引擎（简单 FIFO 截断），即使 plugin 安装了也不会被加载。这是一个安静失败模式——文件 size 不增长、wal 不写入是排查信号。
- **运行时上下文生存 ≠ 持久化记忆**：context engine 解决"当前长会话怎样继续保持连贯"；durable memory（L3）解决"跨 session 长期事实如何积累"。memoryFlush 是后者的 fallback safety rail，不是 L6 的主机制。
- **ignoreSessionPatterns**：把 cron / subagent 等内部 session 排除在摄入之外，从源头减少噪声进入 DAG 和下游 L7 整理。
- **🔒 LLM 摘要前 redact secrets**：摘要器（doubao/lite 类小模型）会原样保留源消息里的 API key / bot token 等敏感字符串。这些 secrets 一旦进入 summaries 表就会被 FTS 索引、被 vector embedding 收录、并在下次 context assembly 时再次注入新 prompt——形成持续放大。**最佳实践**：在调 summarize LLM **之前**对源做 regex redaction（`sk-[A-Za-z0-9_-]{32,}` / Bearer / `\d{8,12}:[token]` 等），让 LLM 永远见不到原始 secret。
- **短源跳过 LLM**：源 < 200 tokens 直接 store-as-is，不调 summarizer。否则会出现"摘要比源还长"的反向情况（LLM 只是把原文加 timestamp 包装），既浪费 LLM 调用又虚耗 token。

常见坑：

- compaction/heartbeat/system prompt 被写入 transcript，后续又被 Dreaming 晋升。
- 只依赖大窗口模型，不做显式持久化。
- 长任务没有外化 plan，压缩后目标漂移。
- **配置级安静失败**：`plugins.slots.contextEngine` 缺失时系统不报错，只是 lcm.db 永不增长。需要 L7 的健康监控（见下）才能在第 1 周内发现，否则是"40 天才知道"级别的回归。
- **secrets 经摘要放大**：raw 消息里的 secret 容易识别（grep）也容易脱敏；但 LLM 摘要把它换个上下文重新包装后，固定的 grep 规则不一定能再 catch。在源头 redact 比事后 audit 容易得多。

### L7 后台整理层：Dreaming 消化上下文

组件示例：

- Memory Core Dreaming
- deep / light / REM sleep
- promotion artifacts
- session-corpus
- post-sweep watchdog
- L6 健康监控 cron（监控 lcm.db 增长 + DAG 比例 + WAL 状态）

职责：

- 将短期 recall、session corpus、daily notes 做后台整理。
- 提炼候选长期记忆，去重、晋升、生成摘要。
- **监控 L6 引擎本身的健康度**：context engine 是个安静失败的组件（不写入即等于沉默），需要后台周期性巡检指标。

工程案例：post-dreaming hygiene

- Dreaming 本身能整理记忆，但也可能把 heartbeat / maintenance / compaction 噪声纳入候选。
- 因此需要 post-sweep watchdog：检查产物、清理噪声、统计 promotion ratio、报告异常。

工程案例：L6 健康监控 cron 阈值（推荐周度跑）

```
🔴 ingest_silent: msgs_24h == 0 且 msgs_7d < 100 (引擎沉默)
🔴 lcm_stalled: newest_message_age > 7 天 (组装停摆)
🔴 wal_corrupted: WAL > 200MB (checkpoint 死锁)
🟡 dag_shallow: condensed/leaf < 5% (压缩没在做层级聚合)
🟡 wal_bloat: WAL > 50MB (checkpoint 滞后)
🟢 healthy: 以上都不触发
```

只有 🔴 才发告警；🟡/🟢 只写报告不打扰，避免告警疲劳。

常见坑：

- 后台任务成功，但报告投递失败，导致无人知道结果。
- 噪声进入 corpus 后被长期污染。
- promotion threshold 太宽，低价值内容晋升。
- **健康监控空缺**：context engine 等"安静失败"组件如果不被周期性 sanity-check，回归发现窗口可能从"1 周"变成"40 天"。

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

最佳实践：

- **agent identity mapping 唯一规范**：自我迭代目录用 agent id（如 `main` / `lisa` / `doubao` / `nyx`），不用 persona name（如 `Lolita`）。所有跨进程协作（cron、patrol、promotion、reflection）都按这同一份 mapping 走。
- **cron payload 用绝对路径**：周期性自反思任务的提示词不要写相对路径 `memory/self-improving/X/hot.md`——cwd 取决于 agent workspace，会把同一 agent 的内容写到不同 workspace 的同名目录里造成 split。统一用 `/root/.openclaw/workspace/memory/self-improving/<agent-id>/...` 的绝对路径。
- **patrol 用枚举白名单**：`KNOWN_AGENTS=("lisa" "main" "doubao" "nyx")` + `KNOWN_FILES=("hot.md" "corrections.md" "signals.md" "README.md")`，扫到不在白名单的就报"未知 agent 目录" / "未知文件"。这能在第 1 周内发现命名漂移、拼写错误（如 `corrrections.md` 三个 r）、persona vs agent-id 大小写分裂等。

常见坑：

- 目录命名/agent identity mapping 不一致，导致扫描漏项。
- 把一次性偏好过早晋升为全局规则。
- 没有 reviewer 或 threshold，规则膨胀。
- **persona vs agent-id 双轨命名**：当 agent 有 persona name（如 Lolita）和 system identifier（如 main）时，若不显式约定唯一规范，cron / 自反思 / patrol 之间会各自用不同名字写入，最终在文件系统上分裂为多个目录。

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

## 9. doubao 可补充内容

建议 doubao agent 补：

1. 脱敏后的配置片段。
2. post-dreaming watchdog 的伪代码或流程图。
3. QMD timeout / rerank 成本的工程说明。
4. promotion stats 如何作为健康指标。
5. active-memory 质量过滤建议。

## 10. nyx 可补充内容

nyx agent 可补：

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

## 15. 源码层适配 / Upstream adaptations

九层塔里有几个组件是开源 / 第三方实现，落地到生产时**对原项目做了少量源码适配**而不是只调配置。这是一种"工程现实"——读者应当被坦诚告知。

### 15.1 哪些层涉及

- **L4 语义检索**：检索 CLI 的输出 JSON parser 改成 fail-soft（warn + 返回 []，不 throw）。这避免单 collection 的 stdout 噪声把整条多 collection 检索拖垮。
- **L6 会话生存 / 无损压缩引擎**：摘要 LLM 调用前注入 secret redaction（regex 替换 `sk-XXX` / Bearer / bot token 等），并加短源跳过阈值（< 200 tokens 直接 store，不调 LLM）。

### 15.2 适配的 packaging 模式

把这种"小修小补"打包成可观测、可重启自愈的形式，而不是临时 hotfix：

| 要素 | 说明 |
|---|---|
| sentinel | 在 patched 区域留一行 `// PATCH:<name>` 注释，apply 脚本据此判断幂等 |
| apply script | 单一的 idempotent shell / node 脚本，能反复跑 |
| boot 集成 | gateway 启动时 `ExecStartPre` 自动跑 apply 脚本——npm 升级或 git pull 覆盖目标后下次重启自动重打 |
| backup 文件 | apply 前自动 timestamp 备份，rollback 路径明确 |
| descriptor 入版控 | `.patch` 文件（unified diff + prose 解释）入 git，记录"为什么做、做了什么"，编译产物 gitignore |
| fail-closed | 找不到 anchor（上游改了函数体）则 patch 退出非零，apply 主流程容错继续，但日志留 trace 等待人工 review |

这套机制让"对开源组件的小修整"成为**可维护的工程资产**，而不是"换台机器就丢"的临时改动。

### 15.3 公开表述建议

文章里如果要讲到这些适配，建议用类似措辞：

> 这套架构里有两处对开源组件做了源码层小幅适配：检索层 parser 的容错、以及压缩层调 LLM 摘要前的 secret redaction。它们都通过启动时自动重打补丁的 patch 系统来持久化，对原项目无侵入，对升级友好。

不必把每个 patch 的具体 diff 贴出来——重点是让读者知道"这是工程治理的一部分，不是设计上预期的开箱即用"。

## 16. 踩坑提醒清单 / Operational pitfalls

整篇文章末尾建议加一个集中的"运维真心话"小节，让读者一眼看到哪些是容易踩的雷。建议覆盖：

| # | 坑 | 出现层 | 一句话提醒 |
|---|---|---|---|
| 1 | bootstrap 注入文件超阈值被截断 | L1/L2/L3 | MEMORY.md 这类文件要严格限定为"规则 + 索引"，自动 promotion 内容拆出去 |
| 2 | embedding 覆盖率 ≠ 索引完成率 | L4 | "indexed=812"是文件级，"embedded chunks"是向量级，两者可以差几个数量级 |
| 3 | 检索 CLI stdout 非 JSON 噪声 | L4 | qmd / vespa / 类似 CLI 在 collection 异常时往 stdout 写 warning，要 fail-soft parser |
| 4 | 多 collection 路径单点失败传染 | L4/L5 | 一个 collection 的子查询抛错不应让整条 active-memory 退化到 builtin |
| 5 | active-memory 注入低质量摘要 | L5 | 需要 minRelevanceScore + 模板化 fallback 过滤 + untrusted context 标记 |
| 6 | context engine slot 没绑定 = 安静失败 | L6 | `plugins.slots.contextEngine` 缺失时系统不会报错，只是 lcm.db 永不增长——必须有 L7 健康监控 |
| 7 | LLM 摘要把 secrets 经 FTS 放大 | L6 | 摘要器原样保留 sk-XXX / token，进 summaries_fts 后 lcm_grep 命中、vector embedding 收录、下次组装再注入 prompt——必须在调 LLM 前 redact |
| 8 | 短源做 summary 反而变长 | L6 | 源 < 200 tokens 直接 return 原文，不要走 LLM——避免"摘要 = timestamp + 原文"的反向膨胀 |
| 9 | session 内部消息（cron/subagent）污染 corpus | L6/L7 | `ignoreSessionPatterns` 在源头排除，比在 Dreaming 后清理高效 |
| 10 | post-sweep watchdog 投递失败 → 无人知 | L7 | watchdog 自身也要监控；delivery 失败要降级到 local log + 告警 |
| 11 | persona 名 vs agent id 双轨写入造成目录分裂 | L8 | 全局只用 agent id（main/lisa/...）；persona name 不进文件系统 |
| 12 | cron payload 写相对路径在不同 cwd 下落到不同 workspace | L8 | 自反思 cron 一律用绝对路径 `/root/.openclaw/workspace/memory/self-improving/<id>/...` |
| 13 | qmd / per-agent index 累积 orphan 向量 | L4 | 周期性 `qmd cleanup`，否则 sqlite 体积持续膨胀（实测可达 80%+ 是 orphan） |
| 14 | sudoers 文件名带 `.` 被默认忽略 | 运维 | `/etc/sudoers.d/X.tmp` 不生效；要用 `X` 不带后缀，否则 `#includedir` 默认跳过 |
| 15 | 升级后所有 patch 失效 | 运维 | npm 升级 / 上游 git pull 会盖掉源码——用 systemd `ExecStartPre` 自动重打的 patch 系统才能保护 |

写文章时不需要列全 15 项，挑 5-7 个最有代表性的做深入解释即可（推荐：3, 6, 7, 8, 11, 13）。
