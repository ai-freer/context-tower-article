# 上下文管理九层塔：OpenClaw Agent 的长期记忆、主动召回与自我进化架构

> 一个真正长期运行的 AI Agent，需要的不是更大的上下文窗口，而是一套完整的上下文治理体系。

---

## 引言：大窗口的幻觉

上下文窗口从 4K 到 128K 再到 1M+，很多人以为"窗口够大就不需要记忆管理了"。

这是一个危险的幻觉。

窗口变大解决的是"能放多少"，但没有解决：
- 放什么进去？
- 什么时候放？
- 过期的怎么清？
- 跨会话怎么延续？
- 多 Agent 怎么共享又隔离？
- 错误记忆怎么修正？
- 经验怎么沉淀成能力？

这些问题，不是靠"更大的窗口"能解决的。它们需要的是 **Context Engineering**——对上下文的工程化治理。

本文介绍一套经过近一个月迭代、在 OpenClaw 多 Agent 环境中实际运行的上下文管理架构。我们称之为"九层塔"。

---

## 从三层到九层：为什么简单记忆不够

最基础的记忆架构分三层：

- **Layer 0**：身份与规范（静态，低频修改）
- **Layer 1**：知识积累与检索（持续增长）
- **Layer 2**：驱动行动（实时运转）

三层架构能让 Agent "记住东西"。但当你开始长期运行——跨天、跨周、多会话、多 Agent 协作——你会发现三层不够：

1. **记忆膨胀**：文件越来越多，bootstrap 注入被截断
2. **噪声累积**：系统日志、heartbeat、maintenance 消息混入记忆
3. **召回失败**：记了但找不到，或找到的不是最相关的
4. **压缩丢失**：长会话被 compaction 后，关键决策丢了
5. **重复劳动**：同样的任务做了十次，每次从零开始

九层塔就是为了解决这些问题而逐步演化出来的。

---

## 九层塔总览

```
┌─────────────────────────────────────────────┐
│  L9  能力进化层   经验 → 可复用技能           │
│  L8  自我迭代层   错误/反馈 → 行为规则        │
│  L7  后台整理层   短期上下文 → 长期记忆        │
├─────────────────────────────────────────────┤
│  L6  会话生存层   Lossless Context Engine / compaction / flush │
│  L5  主动召回层   消息前主动注入相关上下文      │
│  L4  语义检索层   embedding / search / fallback │
├─────────────────────────────────────────────┤
│  L3  文件记忆层   Markdown 长期事实            │
│  L2  规则治理层   行为边界 / 工具协议          │
│  L1  身份注入层   身份 / 用户 / persona        │
└─────────────────────────────────────────────┘
```

三组，每组三层：

- **基础层（L1-L3）**：定义 Agent 是谁、该怎么做、记住了什么
- **运行时层（L4-L6）**：让记忆在对话中真正发挥作用
- **进化层（L7-L9）**：让系统随时间变得更好

---

## L1 身份注入层：Agent 是谁

**解决的问题**：Agent 需要一个稳定的身份锚点，否则在长对话或多 Agent 场景中会"人格漂移"。

**OpenClaw 中的实现**：
- `SOUL.md` — 定义人格、语气、行为边界
- `IDENTITY.md` — 基本信息：名字、角色、emoji
- `USER.md` — 用户画像：偏好、沟通风格、技术栈

**关键设计**：这些文件在每次 session 启动时自动注入 context window，不依赖 Agent 主动读取。

**常见坑**：
- 身份文件写得太长，挤占有效上下文空间
- 多 Agent 场景中，从 chat history 推断身份而非从配置文件确认
- persona 写得太强，压过任务目标

---

## L2 规则治理层：Agent 该怎么行动

**解决的问题**：Agent 需要明确的操作边界——什么能做、什么不能做、怎么做。

**OpenClaw 中的实现**：
- `AGENTS.md` — 操作手册：读写边界、协作协议、安全规则
- `TOOLS.md` — 工具使用规范：什么场景用什么工具
- Bootstrap 配置 — 启动时的行为指令

**关键设计**：规则分层——身份规则 > 安全规则 > 任务协议 > 工具偏好。优先级明确，冲突时高优先级覆盖。

**常见坑**：
- 规则堆太多，Agent 遵循率下降
- 规则没有分层，任务协议和人格描述混在一起
- 缺少"完成后必须汇报/落盘"的闭环要求

---

## L3 文件记忆层：长期事实载体

**解决的问题**：Agent 需要一个持久化的、可人工修正的知识库。

**OpenClaw 中的实现**：
```
memory/
  shared/        ← 所有 Agent 可读写：项目、偏好、决策
  daily/         ← 每日共享日志
  private/       ← 各 Agent 私有记忆
  self-improving/ ← 行为改进记录
```

**关键设计**：
- Markdown 格式：可读、可 diff、可版本控制、可人工修正
- shared/private 分区：多 Agent 协作时既共享又隔离
- 写入规则明确：什么信息写哪里，由 AGENTS.md 定义

**常见坑**：
- MEMORY.md 变成垃圾桶，什么都往里塞，导致 bootstrap 截断
- shared 区被某个 Agent 意外覆盖
- 短期日志和长期事实混在一起，信噪比下降

---

## L4 语义检索层：从记忆中找上下文

**解决的问题**：记忆文件越来越多，不可能全部塞进 prompt。需要按需召回。

**OpenClaw 中的实现**：
- 向量索引（embedding）+ 混合搜索（BM25 + semantic）
- 多源检索：memory 文件 + session transcript
- Fallback 机制：primary backend 超时时降级到 builtin index

**关键设计**：
- 不只是"向量相似度"，还有 temporal decay（时间衰减）和 MMR（多样性）
- 索引定期更新（扫描 + embedding）
- 搜索结果有质量阈值，不是"找到就注入"

**工程 Insight**：
> 搜索 timeout 从 15s 提到 60s 只解决了配置层问题。真正的瓶颈在 query expansion + LLM rerank 路径。搜索系统需要区分：索引是否更新、embedding 是否覆盖、query path 是否稳定、ranking 是否符合预期。

**常见坑**：
- 只看"文件已索引"，忽略 embedding 覆盖率
- Fallback 静默工作，掩盖 primary backend 的性能问题
- exact query 被日志文件排在源文件前面（rerank 偏差）

---

## L5 主动召回层：消息前自动带上下文

**解决的问题**：用户不应该每次都说"帮我查一下记忆"。系统应该自动判断需要什么上下文。

**OpenClaw 中的实现**：
- Active Memory 插件：在用户消息进入 Agent 前，自动搜索相关记忆
- 将召回结果压缩为短摘要注入 prompt
- 结果标记为 untrusted context（不作为绝对事实）

**关键设计**：
- 主动召回 ≠ 无脑注入。有质量阈值、空结果过滤、相关性判断
- 注入内容明确标记来源，Agent 可以选择忽略
- 对慢 query 可以选择更轻的搜索模式

**常见坑**：
- 低质量摘要污染当前对话
- Active memory 输出被误当作 trusted fact
- 召回 subagent timeout 太短，导致频繁空结果

---

## L6 会话生存层：长会话不丢上下文

**解决的问题**：长对话会超过模型上下文窗口。只靠简单截断或一次性 compaction，会让早期约定、任务状态和关键决策从当前对话里消失。

**OpenClaw 中的实现**：
- Lossless Context Engine（lossless-claw）：作为 `plugins.slots.contextEngine` 的运行时上下文引擎，实时摄入消息，并用 DAG/摘要/分层压缩来组装下一轮模型上下文
- Session Memory hook：实时保存会话 transcript，保留可审计的原始时间线
- Compaction Memory Flush：压缩前自动将重要信息写入 durable memory，作为最后一道持久化防线
- Session transcript 被索引，可供 L4 语义检索和后续 Dreaming 使用

**关键设计**：
- 不依赖“大窗口就不会压缩”——任何窗口都有极限
- L6 的中心不是单纯 flush，而是“运行时上下文生存”：谁负责摄入、压缩、组装当前会话
- memoryFlush / safeguard compaction 是 fallback safety rail，不是替代 context engine 的主机制
- 长任务应该外化 plan 到文件，而不是只存在 context 里

**工程 Insight**：
> 一个成熟 Agent 需要“会话生存层”，而不只是更大的上下文窗口。检索层回答“该找回什么长期记忆”，context engine 回答“当前这条长会话怎样继续保持连贯”。两者互补，不互相替代。

> compaction/heartbeat/system prompt 被写入 transcript 后，可能被后台整理层（L7）错误晋升为长期记忆。会话生存层和后台整理层之间需要噪声过滤机制。

**常见坑**：
- 只依赖大窗口模型，不做显式 context engine / 持久化治理
- 把 memoryFlush 当成主机制，而不是 fallback safety rail
- 长任务没有外化 plan，压缩后目标漂移
- 系统消息混入 transcript，污染下游

---

## L7 后台整理层：Dreaming 消化上下文

**解决的问题**：短期记忆和 session transcript 会无限增长。需要定期整理、去重、提炼。

**OpenClaw 中的实现**：
- Memory Core Dreaming：每日自动运行
  - Deep sleep：修复 recall store
  - Light sleep：从 session corpus 中提炼候选记忆
  - REM：生成摘要和关联
- Post-sweep watchdog：检查 Dreaming 产物、清理噪声、统计健康指标

**关键设计**：
- Dreaming 不是简单的"把所有东西都记住"，而是有选择地晋升
- Promotion threshold：只有高价值内容才会从短期进入长期
- 噪声清理是 Dreaming 的必要后置步骤

**工程 Insight**：
> Dreaming 会把 heartbeat、maintenance、compaction 通知等系统噪声纳入候选。因此需要 post-sweep watchdog：每天 Dreaming 完成后自动清理噪声、统计 promotion ratio、报告异常。典型数据：每天清理 200+ 行噪声，promotion 率约 4-6%。

**常见坑**：
- 后台任务成功但报告投递失败，无人知道结果
- 噪声进入 corpus 后被长期污染
- Promotion threshold 太宽，低价值内容晋升

---

## L8 自我迭代层：从错误中改进行为

**解决的问题**：Agent 会犯错。同样的错误不应该犯第二次。

**OpenClaw 中的实现**：
```
memory/self-improving/
  hot/           ← 当前活跃的行为信号
  corrections/   ← 被纠正的错误记录
  signals/       ← 观察到的行为模式
  shared-rules/  ← 晋升为稳定规则的条目
```

**关键设计**：
- 错误记录 → 信号积累 → 规则晋升：不是一次犯错就改规则，而是重复出现才晋升
- shared-rules 跨 Agent 共享：一个 Agent 的教训，所有 Agent 受益
- 有 reviewer 和 threshold，防止规则膨胀

**常见坑**：
- 把一次性偏好过早晋升为全局规则
- 没有 deprecation 机制，过时规则永远存在
- 目录命名不一致，导致扫描漏项

---

## L9 能力进化层：把经验变成技能

**解决的问题**：Agent 反复做同样的事情，每次从零开始。经验应该固化为可复用能力。

**OpenClaw 中的实现**：
- Skill Evolution：从历史任务中 harvest → synthesize → review → promote
- 产出的 skill 存入 shared-skills 目录，所有 Agent 可调用
- 定期审计：清理过窄、过时、重复的 skill

**关键设计**：
- 技能不是手动写的，而是从实际任务中自动提炼
- 有 review 环节：不是所有 workflow 都值得变成 skill
- 技能有生命周期：创建 → 使用 → 验证 → 可能 deprecate

**常见坑**：
- 技能过窄，只适用于特定场景
- 命名差，其他 Agent 找不到
- 私有上下文被错误抽象成 shared skill

---

## 九层之间的数据流

```
用户消息
  ↓
L1/L2 身份+规则（自动注入）
  ↓
L5 主动召回（自动搜索相关记忆）
  ↓
L4 语义检索（按需查找）
  ↓
Agent 回答/执行
  ↓
L6 会话生存（lossless-claw 组装当前上下文 + transcript/flush 兜底）
  ↓
L3 文件记忆（显式写入 durable memory）
  ↓
L7 Dreaming（每日整理、晋升）
  ↓
L8 自我迭代（纠错 → 规则）
  ↓
L9 技能进化（workflow → skill）
  ↓
下一轮对话继续使用
```

这不是线性流程，而是一个闭环。每一层的输出都是其他层的输入。

---

## 搭建路径建议

不需要一次性搭建九层。建议分阶段：

**第一阶段：基础可用（L1-L3）**
- 写好 SOUL.md、IDENTITY.md、USER.md
- 建立 memory/ 目录结构
- 定义 AGENTS.md 中的读写规则

**第二阶段：检索与召回（L4-L6）**
- 启用 memory search + embedding
- 配置 Active Memory 插件
- 启用 session memory 和 compaction flush

**第三阶段：自动进化（L7-L9）**
- 启用 Dreaming + post-sweep watchdog
- 建立 self-improving 目录和晋升机制
- 启用 Skill Evolution

每个阶段都可以独立运行。但完整的九层塔才能形成真正的闭环。

---

## 结语

九层塔不是为了复杂而复杂。它是因为长期运行的 Agent 面临的问题天然分布在九个不同维度：

- 身份要稳定
- 规则要明确
- 记忆要持久
- 检索要精准
- 召回要主动
- 会话要存活
- 噪声要清理
- 错误要修正
- 经验要复用

好的 Agent 不是"记得更多"，而是"知道什么该记、什么时候召回、何时压缩、如何清噪、怎样从经验中进化"。

这就是 Context Engineering 的本质：不是管理上下文的大小，而是管理上下文的生命周期。

---

_本文基于 OpenClaw 多 Agent 环境中近一个月的实际运行经验。九层塔不是一次性设计出来的，而是在解决一个又一个实际问题的过程中逐步演化而成。运维治理本身也是架构成熟的一部分。_
