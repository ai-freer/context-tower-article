# 上下文管理九层塔：OpenClaw Agent 的长期记忆、主动召回与自我进化架构

> 一个真正长期运行的 AI Agent，需要的不是更大的上下文窗口，而是一套完整的上下文治理体系。

---

## 摘要（Executive Summary）

如果你只读这一段：

- **大上下文窗口 ≠ 上下文管理**。窗口解决"能装多少"，不解决"装什么、何时召回、如何压缩、怎样进化"。
- **长期运行 Agent 需要 9 个维度的治理**，分成基础层（L1–L3 身份 / 规则 / 记忆）、运行时层（L4–L6 检索 / 召回 / 会话生存）、进化层（L7–L9 整理 / 迭代 / 技能化），构成闭环而非线性流水线。
- **最容易"安静吃亏"的两点都在 L6**：`plugins.slots.contextEngine` 不绑定时系统不报错，只是悄悄退化到 legacy 截断；以及 LLM 摘要器没做 secrets redaction，API key 会经 FTS + vector 被持续放大注入。建议搭 L6 时一次到位。
- **不需要一次性搭满九层**。L1–L3 几小时上手；L4–L6 是质变临界点；L7–L9 让系统真正自愈。
- **工程态度比单点修复更关键**。开源组件需要的小修整（L4 parser fail-soft / L6 摘要前 redact）要做成 idempotent + boot-time 自愈的"工程资产"，而不是一次性 hotfix。

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

本文介绍一套在 OpenClaw 多 Agent 环境中运行三个多月、并在近一个多月集中升级整理出的上下文管理架构。我们称之为"九层塔"。

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
> 搜索 timeout 从 15s 提到 60s 只解决了配置层问题。真正的瓶颈在 query expansion + LLM rerank 路径。搜索系统需要区分：索引是否更新、embedding 是否覆盖、query path 是否稳定、ranking 是否符合预期。最近一次 audit 里，active-memory 直连 QMD 的长尾曾达到 55-121s；加入 P0.1 direct timeout guard 后，超时被稳定限制在约 10s，代价是慢查询返回空结果而不是继续等待。

**常见坑**：
- 只看"文件已索引"，忽略 embedding 覆盖率
- Fallback 静默工作，掩盖 primary backend 的性能问题
- exact query 被日志文件排在源文件前面（rerank 偏差）
- 检索 CLI 的 stdout 不是干净 JSON——遇到 collection 不存在 / 参数异常时会先打印 `Warning:` 或 `Usage:` 文本再给 JSON。下游 parser 必须容错地跳过非 JSON 前缀，**抛错会让多 collection 路径整体退化到慢 fallback**
- per-agent 索引会累积大量 orphan 向量（content 已删但 vector 留着），需要周期性 cleanup；orphan 占比 > 50% 是 sqlite 体积膨胀的常见原因

---

## L5 主动召回层：消息前自动带上下文

**解决的问题**：用户不应该每次都说"帮我查一下记忆"。系统应该自动判断需要什么上下文。

**OpenClaw 中的实现**：
- Active Memory 插件：在用户消息进入 Agent 前，自动搜索相关记忆
- 将召回结果压缩为短摘要注入 prompt
- 结果标记为 untrusted context：明确告知 Agent 这部分内容来自自动召回而非用户原话，可以质疑、忽略或反向校验，不必作为权威事实直接采用

**关键设计**：
- 主动召回 ≠ 无脑注入。有质量阈值、空结果过滤、相关性判断
- 注入内容明确标记来源，Agent 可以选择忽略
- 对慢 query 可以选择更轻的搜索模式
- 对直连检索路径要设置短超时护栏：例如 direct search timeout capped at 10s，并在 debug metadata 里标记 `direct-timeout` / `timedOut`，让空结果可解释、可追踪

**常见坑**：
- 低质量摘要污染当前对话
- Active memory 输出被误当作 trusted fact
- 召回 subagent timeout 太短，导致频繁空结果
- **检索后端单点失败传染整条召回链**：active memory 调底层多 collection 检索时，任一子查询抛错会让整条召回退化到 builtin slow path（>10s / 0 hits）。L4 parser 必须 fail-soft（warn + 返回空数组），主动召回层才能稳定
- **直连检索没有 timeout guard 会产生长尾卡顿**：P0 direct path 可以绕开 subagent 慢路径，但也必须配 P0.1 超时护栏；实测 48.9s / 55-121s 长尾可被压到约 10s，超时返回 empty 是可接受的 fail-closed 行为

---

## L6 会话生存层：长会话不丢上下文

> L6 是九层塔最复杂、也最容易"安静吃亏"的一层——本节多数 critical 标注集中在这里，建议慢读。

**解决的问题**：长对话会超过模型上下文窗口。只靠简单截断或一次性 compaction，会让早期约定、任务状态和关键决策从当前对话里消失。

**OpenClaw 中的实现**：
- Lossless Context Engine（lossless-claw）：作为 `plugins.slots.contextEngine` 的运行时上下文引擎，实时摄入消息，并用 DAG/摘要/分层压缩来组装下一轮模型上下文
- Session Memory hook：实时保存会话 transcript，保留可审计的原始时间线
- Compaction Memory Flush：压缩前自动将重要信息写入 durable memory，作为最后一道持久化防线
- Session transcript 被索引，可供 L4 语义检索和后续 Dreaming 使用

**关键设计**：
- L6 的中心不是单纯 flush，而是"运行时上下文生存"：谁负责摄入、压缩、组装当前会话
- 检索层回答"该找回什么长期记忆"，context engine 回答"当前这条长会话怎样继续保持连贯"——两者互补，不互相替代
- memoryFlush / safeguard compaction 是 fallback safety rail，不是替代 context engine 的主机制
- 长任务应该外化 plan 到文件，而不是只存在 context 里
- **必须显式绑定 `plugins.slots.contextEngine`**：不绑定不会报错，只会悄悄退化到 legacy 截断引擎（详见坑 #6）
- **摘要 LLM 调用前必须 regex redact secrets**：否则 sk-XXX / token 会经 FTS + vector 持续放大注入（详见坑 #7）
- **短源 (< 200 tokens) 跳过 summarizer**：避免"摘要 = timestamp + 原文"的反向膨胀（详见坑 #8）

**工程 Insight**：
> compaction / heartbeat / system prompt 被写入 transcript 后，可能被后台整理层（L7）错误晋升为长期记忆。会话生存层和后台整理层之间需要噪声过滤机制。

> Secrets 在 raw 消息里容易识别（grep 一抓一个准），但 LLM 摘要把它换个上下文重新表述后，固定的 grep 规则就不一定 catch 得到了。在源头 redact 比事后 audit 容易得多——这是 L6 必须正视的安全责任。

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
- **L7 还要监控 L6 引擎本身**：context engine 是个安静失败的组件（不写入即等于沉默）。L7 应当包含一个周度健康监控 cron，监控 lcm.db 增长、DAG leaf/condensed 比例、WAL 状态。否则一次配置回归可能要 40 天才被发现

**工程 Insight**：
> Dreaming 会把 heartbeat、maintenance、compaction 通知等系统噪声纳入候选。因此需要 post-sweep watchdog：每天 Dreaming 完成后自动清理噪声、统计 promotion ratio、报告异常。典型数据：每天清理 200+ 行噪声，promotion 率约 4-6%。

> 健康监控阈值要分级——🔴 才告警（ingest 沉默 / lcm 停摆 / WAL 损坏），🟡 只写报告不打扰（DAG 浅 / WAL 滞后），🟢 静默通过。否则告警疲劳会让真问题被淹没。

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
- **agent identity 用唯一规范**：自我迭代目录用 agent id（`agent-A` / `agent-B` / ...），不用 persona name（`Persona-A` / `Persona-B` 这类用户自定义显示名）。所有跨进程协作（cron、patrol、promotion）用同一份 mapping
- **cron payload 用绝对路径**：周期性自反思任务里写 `memory/self-improving/X/hot.md` 这种相对路径会被不同 cwd 解析到不同 workspace，造成同一 agent 的内容分裂到多处。统一用 `/root/.openclaw/workspace/memory/self-improving/<id>/...` 的绝对路径
- **patrol 用枚举白名单**：`KNOWN_AGENTS` + `KNOWN_FILES` 列表化，扫到不在白名单的就报警。这能在第 1 周内发现命名漂移、拼写错误（如 `corrrections.md` 多打一个 r）、persona vs agent-id 大小写分裂

**常见坑**：
- 把一次性偏好过早晋升为全局规则
- 没有 deprecation 机制，过时规则永远存在
- 目录命名不一致，导致扫描漏项
- persona name vs agent id 双轨命名不统一，cron 跟 patrol 各走各的写出多份目录
- cron payload 用相对路径，cwd 一漂全军覆没

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

不需要一次性搭建九层。建议分阶段（在 GitHub Web UI 阅读时，下方 checkbox 可点击勾选作为自我评估）：

**第一阶段：基础可用（L1-L3）**
- [ ] 写好 SOUL.md、IDENTITY.md、USER.md
- [ ] 建立 memory/ 目录结构
- [ ] 定义 AGENTS.md 中的读写规则

**第二阶段：检索与召回（L4-L6）**
- [ ] 启用 memory search + embedding
- [ ] 配置 Active Memory 插件
- [ ] 启用 session memory 和 compaction flush

**第三阶段：自动进化（L7-L9）**
- [ ] 启用 Dreaming + post-sweep watchdog
- [ ] 建立 self-improving 目录和晋升机制
- [ ] 启用 Skill Evolution

每个阶段都可以独立运行。但完整的九层塔才能形成真正的闭环。

> 在 GitHub 渲染下这些 checkbox 可以直接点击勾选；在 [HTML 版](https://ai-freer.github.io/context-tower-article/03-report.html#path) 中勾选状态会写入浏览器 localStorage，下次打开仍保留。

---

## 源码层的小修整：把开源组件做成"工程资产"

诚实地说，把九层塔落到生产时，光配置是不够的。前文 L4（parser fail-soft / QMD JSON 输出与 snippet fallback）、L5（active-memory direct path + 10s timeout guard）和 L6（摘要前 redact secrets / 短源跳过 LLM）提到的几处问题，都需要在开源组件源码上做小幅适配。

这一节不再重复"改什么"，重点谈"怎样让这种修改活下去"——临时 hotfix 会随着 npm 升级或上游 git pull 失效；只有做成可观测、可重启自愈的工程资产，才能真正成为架构的一部分。最佳实践是：

| 要素 | 做法 |
|---|---|
| sentinel / marker | 在 patched 区域留 `// PATCH:<name>` 或可 grep 的 marker（如 `direct-timeout` / `timedOut`），apply 脚本据此判断幂等 |
| apply script | 单一 idempotent shell/node/python 脚本，能反复跑 |
| boot 集成 | gateway 启动时 `ExecStartPre` 自动跑 apply 脚本——上游覆盖目标后下次重启自动重打 |
| backup 文件 | apply 前 timestamp 备份，rollback 路径明确 |
| descriptor 入版控 | `.patch` 文件或可读 reinstaller（unified diff + 解释）入 git，编译产物 gitignore |
| fail-closed | sentinel/anchor 找不到（上游改了函数体）就 fail，主流程容错继续，日志留 trace |

最新 audit 中，这套机制已经扩展为一个 post-upgrade reinstaller：`/root/.openclaw/workspace/patches/_apply-qmd-active-memory-hotpatches.py`，并作为 `apply-patches.sh` 的 Patch 14 在 `openclaw-gateway-root.service` 的 `ExecStartPre` 中运行。它覆盖 `qmd-manager-*.js` 的 `--json` / snippet fallback，以及 `extensions/active-memory/index.js` 的 direct recall path + P0.1 10s timeout guard。换句话说，OpenClaw package upgrade / npm reinstall 覆盖 dist 后，下一次 gateway restart 会自动检查并尝试重打这些 hot patch；如果上游结构变了，它会 fail-closed 留日志，而不是冒险改坏产物。

让对开源组件的小修整可被持续维护，而不是"换台机器就丢"。

---

## 运维真心话：14 个最容易踩的坑

九层塔架构清单容易看，但落地时会反复踩一些坑。以下是从实际运行里整理出的高频陷阱，按层归类：

| # | 坑 | 出现层 | 一句话提醒 |
|---|---|---|---|
| 1 | bootstrap 注入文件超阈值被截断 | L1/L2/L3 | MEMORY.md 严格限制为"规则 + 索引"，自动 promotion 内容拆出去 |
| 2 | embedding 覆盖率 ≠ 索引完成率 | L4 | "files indexed" 是文件级，"embedded chunks" 是向量级，两者可以差几个数量级 |
| 3 | 检索 CLI stdout 非 JSON 噪声 | L4 | qmd 类 CLI 在 collection 异常时往 stdout 写 warning，下游 parser 必须 fail-soft |
| 4 | 多 collection 路径单点失败传染 | L4/L5 | 一个 collection 的子查询抛错不应让整条 active-memory 退化到 builtin |
| 5 | active-memory 注入低质量摘要 / 直连检索长尾 | L5 | 加 minRelevanceScore + untrusted context 标记；direct path 必须有约 10s timeout guard，超时返回 empty 并记录 `direct-timeout` |
| 6 | **context engine slot 没绑定 = 安静失败** | L6 | `plugins.slots.contextEngine` 缺失时系统不报错，只是 lcm.db 永不增长——必须有 L7 健康监控 |
| 7 | **LLM 摘要把 secrets 经 FTS 放大** | L6 | 摘要器原样保留 sk-XXX / token，进 summaries 后 lcm_grep 命中、vector embedding 收录、下次组装再注入 prompt——**必须在调 LLM 前 redact** |
| 8 | 短源做 summary 反而变长 | L6 | 源 < 200 tokens 直接 return 原文，避免"摘要 = timestamp + 原文"的反向膨胀 |
| 9 | session 内部消息（cron/subagent）污染 corpus | L6/L7 | `ignoreSessionPatterns` 在源头排除，比在 Dreaming 后清理高效 |
| 10 | post-sweep watchdog 投递失败 → 无人知 | L7 | watchdog 自身也要监控；delivery 失败要降级到 local log + 告警 |
| 11 | persona 名 vs agent id 双轨写入造成目录分裂 | L8 | 全局只用 agent id（agent-A/agent-B/...）；persona name 不进文件系统 |
| 12 | cron payload 用相对路径在不同 cwd 下落到不同 workspace | L8 | 自反思 cron 一律用绝对路径 |
| 13 | per-agent 索引累积 orphan 向量 | L4 | 周期性 cleanup，否则 sqlite 体积膨胀（实测可达 80%+ 都是 orphan） |
| 14 | sudoers 文件名带 `.` 被默认忽略 | 运维 | `/etc/sudoers.d/X.tmp` 不生效；要用 `X` 不带后缀 |

其中 #6 和 #7 是这套架构最容易"安静吃亏"的两点：context engine 不绑 slot，整个 L6 等于没装；摘要器没做 secrets redaction，secrets 会经 FTS 持续放大。这两条强烈建议在搭建 L6 时就一次到位。

---

## 结语

九层塔不是为了复杂而复杂——长期运行的 Agent 面临的问题天然分布在九个不同维度（身份 / 规则 / 记忆 / 检索 / 召回 / 会话生存 / 整理 / 自我迭代 / 技能化），缺一层就会在某个时刻"漏出来"。

好的 Agent 不是"记得更多"，而是知道什么该记、什么时候召回、何时压缩、如何清噪、怎样从经验中进化。这就是 Context Engineering 的本质：**不是管理上下文的大小，而是把上下文的整个生命周期做成可观测、可修复、可进化的工程闭环。**

---

_本文基于 OpenClaw 多 Agent 环境三个多月的实际运行经验，以及近一个多月对九层上下文架构的集中升级与整理。九层塔不是一次性设计出来的，而是在解决一个又一个实际问题的过程中逐步演化而成。运维治理本身也是架构成熟的一部分。_
