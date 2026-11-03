# 九层塔 2.0 主报告补充资料（证据底稿）

> 用途：给 `04-context-tower-2.0.md` 补实践证据。只读调查，2026-11-04 整理；未改配置、代码、数据或文章，未做生产测试。
> 标注：【验】本地已验证 ·【官】官方文档描述 ·【推】基于证据的推断 ·【未】未确认或未测试。
> 占位：`<state>` = OpenClaw 状态目录；`<scripts>` = 运维脚本目录；`<engine>` = 本地 lossless-claw 源码目录；`<audits>` = 共享审计报告目录。已去掉群聊、会话标识、主机名、密钥和授权链接。

## 0. 相对上一轮群内消息的更正

- **cli-metadata 报错冲突已查清。** 10-31 22:42 的 4 条报错来自 skill-evolution 插件（`<state>/staging/skill-evolution-source`），不是 lossless-claw【验，openclaw.log 原文】。lossless-claw 的修复成立；skill-evolution 有同类问题，目前未修【验】。
- **QMD 迁移冲突部分查清。** 9-05 01:29 有一份成功的 doctor 日志（`repair-20260905-doctor-fix.log`）：删除了 4 个 agent 的 QMD 工作区，修复 41 个带旧状态的 transcript，迁移 Memory Core 事件到 SQLite，结尾 "Doctor complete"【验】。另一份写「无法进入维护」的日志（`doctor-20260901-fix.log`，mtime 9-05 19:39）是之后又跑了一次、失败了【验】。日志里没有「QMD 内容导入内置 Memory」这样的条目，所以内容是否带过来了仍【未】。
- **storage-patrol 已改写。** `storage-patrol.sh` 在 10-26 重写为只读的 Memory Status Patrol，脚本头注明 "No QMD path"【验】。上一轮说它「还在引用 qmd」，只是指注释里的这一句，结论应改为「已替换」。

## 1. 当前版本与九层分工

版本【验】：OpenClaw 2026.10.8（dc2523e），Node 24.22.1；lossless-claw 0.5.2（本地 fork + 本地补丁，从 `plugins.load.paths` 加载）；skill-evolution（staging 源码加载）；插件槽位：memory=memory-core，contextEngine=lossless-claw。

| 层 | 承担者 | 类型 | 状态 |
|---|---|---|---|
| L1 身份 | 工作区 AGENTS / SOUL / IDENTITY | 宿主原生 | 运行【验】 |
| L2 规则 | 工具策略 + AGENTS.md + `shared-rules.md`（每日晋升，只追加） | 原生 + 自建 | 运行【验】 |
| L3 文件记忆 | Markdown 记忆 + self-improving（corrections / hot / signals） | 原生 + 自建 | 运行【验】 |
| L4 检索 | 内置 Memory：每个 agent 一份索引，来源 memory + sessions，OpenAI 兼容 embedding（2048 维），extraPaths 为空 | 宿主原生 | 运行【验】；11-02 手动增量同步后才清掉 dirty |
| L4 检索 | memory-wiki：shared 后端，corpus=all，unsafe-local 读 4 个工作区的 memory 和 DREAMS | 外部插件 | 运行【验】 |
| L5 主动召回 | active-memory：4 个 agent 开启，allowedChatTypes=direct+group，30 秒超时，摘要上限 220 字 | 宿主插件 | 运行【验】 |
| L6 会话存储 | 每个 agent 一个 SQLite 会话库；compaction=safeguard + memoryFlush | 宿主原生 | 运行【验】 |
| L6 上下文引擎 | lossless-claw：独立库，阈值 0.75，freshTail 32，cron 和子 agent 会话不入库 | 外部插件（本地 fork） | 运行【验】 |
| L7 后台整理 | dreaming 03:00（light / rem / deep） | 宿主原生 | 运行【验】 |
| L7 后台整理 | memory-wiki 每日编译；4 个 agent 每日反思 cron；root crontab 03:00 `run-promote.sh` | 外部插件 + 自建 | 运行【验】 |
| L8 自我迭代 | 晋升流程 + 提案登记表（22 条：已实施 11 / 待批 6 / 只记录 5） | 自建 + 人工审批 | 运行【验】 |
| L9 能力进化 | Skill Workshop（auto）；skill-evolution 直接发布到 shared-skills（dryRun=false，评审最低分 0.6） | 原生 + 外部插件 | 运行【验】 |

与文章相关的配置差异：
- 文章写「群组和频道排除在外」，这是官方默认【官】；本地 active-memory 开了群聊召回【验】。
- 共享技能目录 111 项，大量是 skill-evolution 生成的细粒度近义技能，例如十余个 `audit-*-freshness-*`【验】。两条流水线会不会重复发布同一条经验【推，可能】；没有去重验证【未】。

## 2. 第一版到现在的变化（对应 04 第 7 节）

| 项 | 以前 | 现在 | 时间 / 原因 | 已验证 | 未验证 | 归类 |
|---|---|---|---|---|---|---|
| QMD | 每个 agent 一套 QMD 向量集合，带防御性解析补丁和 stale 清理 | 4/4 backend=builtin【验】 | 9-05 doctor 删除了 QMD 工作区【验】；随宿主 2.0 退役【官】 | 后端切换和目录删除【验】 | QMD 内容是否导入内置 Memory【未】 | 已替换 |
| retention / 防重新导出 | `qmd-session-retention.py` + manifest + 跳过补丁 | 载体随 QMD 一起消失；脚本还在 `<scripts>`【验】 | 9-05 | 6-08 的 QMD 时期闭环（历史证据） | 内置 Memory 上的等价能力【未】 | 退役（脚本没删） |
| 向量水位巡检 | QMD Storage Patrol（docs / vectors / payload 水位，W34–W36 有报告） | 10-26 重写为只读 Memory Status Patrol【验】 | QMD 退役 | 脚本头声明不用 QMD【验】 | W45 那次运行超时没出报告【验】；13:01 的报告与实测有出入（provider、lisa dirty）【验】 | 已替换（质量待调查） |
| warm compression phase2 | 每日把 doubao 冷会话压成摘要，再写回 QMD | crontab 已注释；脚本、日志、412 份摘要保留【验】 | 10-31 经批准停用：9-05 之后每天报找不到 QMD 库 | 停用和保留【验】 | 召回测试 0/8，原因未查明 | 已退役，不建替代 |
| LCM retention | `lcm-retention.sh` 按 QMD 生命周期做 buffer / 删除 / VACUUM | 仍在用，由每周审计 cron 跟踪【验】 | — | cron 状态 ok【验】 | 是否实际执行过删除、删除后能否找回【未】 | 保留（待调查） |
| 上下文引擎摄入 | afterTurn 入库 | commitTurn 在一个事务里入库（10-31 修复）【验】 | 见案例 A | 见案例 A | 缺口没回填，也没做 ID 级对账 | 已替换（修复） |

本地补丁现状（`<patches>` + `<engine>/dist` 备份）【验】：
- 保留：lossless-claw secret redaction、registrationMode 守卫、commitTurn-ingest、workspace-root-mode-guard（附带一个每 30 分钟执行 chmod 的 crontab 临时措施）。
- 归档：QMD 防御性解析补丁（`_archive-2026-0x`）。
- 待调查：消息工具 final 契约、telegram spoiler 等非记忆类补丁，未逐项核对它们在当前宿主上是否仍需要。

## 3. 真实案例

### 案例 A：组件全绿，消息却没进上下文引擎（L6）

- **时间与背景**：9-17 打了一个本地补丁，引擎声明支持「原子、幂等的轮次推进」，并实现了 commitTurn。2026.10.x 宿主对做了这种声明的引擎不再调 afterTurn，改为只通过 `commitTurn(messages)` 交付消息【验：源码 + 宿主契约文档 context-engine.md，见 10-30 排查记录】。
- **现象**：插件注册成功；宿主那边每轮都显示已提交；健康报告没有报错。W44 的引擎周报总评是 🟢，msgs_7d 只有 167【验，W44 报告】。
- **排查**（10-30）：拷贝引擎库做只读查询。9-16 以来有 3074 条轮次提交记录，涉及 2820 个会话，其中 2780 个在引擎库里没有任何消息【验；拷贝不是原子的，有快照误差】。
- **确认的原因**：补丁里的 commitTurn 只 `INSERT OR IGNORE` 一个幂等 key，没处理 messages；宿主据此认为已经提交【验】。只有走旧 afterTurn 路径的内部会话还在入库【验】。
- **处理**：改成在同一个事务里先查 key，有就返回 duplicate；没有就逐条入库，最后写 key。新增 3 条测试：旧代码 2 条失败，新代码 3 条通过；全量测试里 6 条失败是原本就有的【验，10-30 记录】。10-31 01:29 部署，02:22 网关重启【验：dist mtime、进程启动时间】。
- **结果与限制**：修复后本话题会话连续入库【验，10-31 记录】；W45 msgs_7d=1,924【验】。9-16 至 10-30 的缺口**没有回填**，也没定方案【验】；没做 ID 级对账【未】。
- **可提炼的教训**：「宿主确认提交」和「引擎实际持久化」是两回事。健康阈值只看库里有没有新增，所以这个缺口长期没被发现：内部会话的入库让 msgs_24h 一直不为零【推】。

### 案例 A'：同一次修复中的误判（04 第 5.1 节「提交点」）

- 10-30 21:24 重启上线修复，22:02 查库没有新消息，被判为「完全停写」【验】。
- 后来更正：这段时间里跑完的只有 cron 轮次，cron 在忽略名单里本来就不入库；查库时用户那一轮还没结束。之后本话题会话从 52 条涨到 90 条【验，10-31 / 11-02 记录】。
- 写作建议：A 和 A' 一起写。只写 A'，读者会以为什么都没丢；实际是先丢了约 6 周，修复后又差点被误判为没修好。

### 案例 B：元数据加载阶段的插件报错（04 第 5.2 节）

- **现象**：宿主的 CLI 元数据注册阶段报 `runtime is intentionally unavailable during "cli-metadata" registration`。lossless-claw 在 10-14、10-26、10-30 出现过【验，日志】。
- **原因**：register() 没区分注册模式，在非 full 模式下也去访问 runtime【验】。
- **处理**：registrationMode 不是 full 就提前返回，缺这个字段按 full 处理。10-31 01:29 部署，备份为 `.pre-regmode-guard-20261031`【验】。
- **结果**：之后 lossless-claw 没再报这个错【验】。10-31 22:42 出现的同类报错来自 **skill-evolution**，到现在没修【验】。
- 写作建议：这个案例能说明「同一类宿主变化会在多个插件上重复出现」，迁移时应该全量扫描，不能只修当时报错的那一个。

## 4. 撤销、遗忘与权限边界（对应 04 第 5.3 节）

前提：本地从未执行过 `memory forget`，也没有配置任何准入策略，memory-core 只配了 dreaming【验】。下表是「如果要求撤销」时各类数据的处理方式。

| 数据 | 谁来处理 | 依据 | 是否验证不会回流 |
|---|---|---|---|
| 原始会话 | 宿主留存策略；forget 不删原始记录 | 【官】 | — |
| 派生记忆（dreaming 产物 / MEMORY.md） | forget 可删除，并标记为已遗忘 | 【官】；本地未用 | 【未】 |
| 内置检索索引 | 随 memory-core | 【官】 | 重建后是否恢复已撤销内容【未】 |
| 引擎库（LCM 摘要 DAG） | forget 管不到【官：只覆盖 memory-core】；只有自建的 secret redaction、以及按时间做的 lcm-retention | 【验】 | 【未】 |
| memory-wiki | 直接读 4 个工作区的 memory 和 DREAMS，编译成共享 vault | 【验，配置】 | forget 之后 wiki 里是否还留着【未】 |
| 412 份旧摘要 / 每日备份 / 引擎备份 | 没有撤销传播，只能人工处理 | 【推】 | 【未】 |
| shared-rules.md | 只追加；没有按来源撤回的机制，只能整份文件回退到 .bak | 【验】 | — |
| 技能 | Workshop 有版本，可以 restore【验】；skill-evolution 发布的技能有没有来源可追、能不能回滚【未】 | | 【未】 |

读取与召回边界：
- 内置索引按 agent 隔离，4 个各自独立【验】。
- active-memory 在群聊里也会召回【验，配置】。官方默认是只召回同一 agent 的私聊，群组排除【官】。
- memory-wiki 配了 `allowPrivateMemoryCoreAccess=true`、`corpus=all`，4 个工作区都在读取路径里，4 个 AGENTS.md 也都提到了 wiki 工具【验】。这形成了一条跨 agent 读取路径【推】，没测过实际会不会召回别的 agent 的私聊内容【未】。
- 信任边界：单个 Gateway、单个操作者【验】，符合官方「一个 Gateway 一条信任边界」的前提【官】。
- 私聊与群聊隔离、合成私密标记、跨 agent 泄漏这几类测试：没找到任何记录【未】。

## 5. 一条完整数据流（脱敏，对应 04 第 4 节图示）

示例：用户在群话题里问了一个问题，agent 回答。

| 步骤 | 责任组件 | 可观察的状态 | 已知失败点 |
|---|---|---|---|
| 1 持久化 | 宿主：该 agent 的会话库 | transcript 记录 | 打开库时做完整性校验，需要 8–12 秒【验，11-02】 |
| 2 引擎摄入 | lossless-claw，轮次结束时 commitTurn | 轮次提交表 + 消息序号 | 只写 key 不存消息（案例 A）；在轮次结束前去查（案例 A'）【验】 |
| 3 压缩 | 引擎在 0.75 时生成 leaf / condensed；宿主 memoryFlush 写当日记忆 | newest_summary_age | 摘要模型超时后转 fallback；W44 摘要停产约 181 小时【验】 |
| 4 后台整理 | dreaming 03:00；wiki 编译；自建每日反思和晋升 | dreaming 审计（可疑语料数）、promote.log | cron 会话不进 dreaming【官】 |
| 5 索引 | memory-core（memory + sessions） | dirty、files/eligible、健康检查 | dirty 长期清不掉；检索时顺带的同步被「owner closed」拒绝；embedding 偶发 502【验，11-02】 |
| 6 召回 | active-memory 子 agent（30 秒 / 220 字）、memory_search、wiki 工具 | 召回 transcript（persistTranscripts=true） | 召回是否正确、是否越权【未】 |
| 7 进入模型上下文 | 引擎组装（freshTail 32 + 摘要）+ 召回注入 | — | 重复注入、预算超限【未】 |

## 6. 对照 05 验收清单

环境：生产网关，OpenClaw 2026.10.8，单机。「有条件接受」不等于通过。

| 场景 | 结论 | 时间 / 证据 |
|---|---|---|
| 新消息摄入 | 有条件接受 | 10-31 本话题会话连续入库（161 条，序号连续）；W45 msgs_7d=1,924。没做按来源 ID 的对账 |
| 重启恢复 | 有条件接受 | 10-31 02:22 重启后继续入库；待办任务状态是否恢复【未】 |
| 重复输入 | 只有测试库证据 | 10-31 引擎套件 84/84，另有 commitTurn 3 条测试；生产未测 |
| 摘要压缩 | 未测 | — |
| 索引重建 | 有条件接受 | 11-02 增量同步后 4/4 dirty 清零。健康检查 11:13 失败（4/4 dirty），15:10 失败（main embedding 502），15:13 通过（exit 0）。「不恢复已撤销内容」未测 |
| retention 防回流 | 只有旧环境历史证据 | 6-08 QMD 时期闭环；当前未测 |
| 来源排除 / forget | 未测 | 本地从未使用 |
| 私聊与群聊 / 多 agent 权限 | 未测 | 没有任何测试记录；wiki 跨 agent 读取路径待测 |
| 双检索路径 | 未测 | 内置 Memory + wiki + active-memory 三路并存 |
| 双学习流水线 | 未测 | Workshop + skill-evolution 同时运行；存在大量近义技能【验】 |
| 技能所有权 | 未测 | — |
| 技能发现 | 有条件接受 | 10-30 4 个工作区的 skills 软链都指向 shared-skills【验】；版本和依赖一致性未测 |
| 外部任务恢复 / 分支与迁移 | 未测 | — |
| 摘要服务失败 | 只有观察 | 10-31 摘要模型 60 秒超时后转 fallback（W45 周报），不算测试 |
| 备份恢复 | 有条件接受（仅远端最新版） | 10-25 恢复清单：「good for remote-latest recovery, with known gaps」。快照完整性和能否解密未测；恢复演练需要在持有私钥的机器上做，尚未执行【验】 |

## 7. 规则与技能的实际演进（对应 04 第 5.4 / 6 节）

案例：11-03 的每日晋升【验，promote.log】
1. 来源：各 agent 的 corrections / hot / signals（自建，agent 自己记录）。
2. 筛选：root crontab 03:00 跑 `run-promote.sh`，窗口为 [前一天 03:00, 当天 03:00)。按规则 1–5 做跨 agent 聚合，由模型判定。当天结果是 2 条 MERGE、若干条 SKIP（已覆盖或过于具体）。
3. 写入：先对 staging.patch 做 dry-run，再追加到 `shared-rules.md`，记录前后 sha，并保留 `.bak-pre-promote-*`。
4. 生效：4 个工作区的 AGENTS.md 都引用了 shared-rules【验】。下一个会话是否真的按新规则执行【推】，没做行为验证【未】。
5. 审核：每日晋升自动写入。每周 fullscan 把候选登记为提案，needs-approval 的必须由 Daniel 批准【验】。
6. 版本与回滚：只能整份文件回退；单条规则没有版本，也没有退役机制。文件已经长到 5,681 行【验】。

技能侧：Workshop 自动修改技能并在群里通知，可以按版本 restore；例如 11-03 更新了 validate-host-memory-retrieval 和 write-wechat-tech-article【验】。skill-evolution 每天 03:30 合成、由模型评审、直接发布到共享目录【验，配置】。

为什么保留自建：Workshop 以单个 agent 的技能为单位。跨 agent 聚合、证据阈值、共享规则文件，在当前配置和已读的官方文档里都找不到对应能力【推，没有逐条对照文档】。反过来，skill-evolution 和 Workshop 的职责有重叠，是否应该收敛是一个开放问题。

## 8. 汇总

**可以直接用于文章**
- 九层分工表和版本（第 1 节），注明本地配置与官方默认的差异。
- 案例 A + A'：commitTurn 丢消息，以及修复后因为不知道提交点而产生的误判。必须写明缺口没有回填。
- 案例 B：注册模式报错在两个插件上都出现了，只修了其中一个。
- QMD 退役：warm compression 每天对着不存在的库报错约 8 周后才停用；storage-patrol 已重写。
- 规则晋升链路，以及「单条规则不可回滚、规则文件持续膨胀」这个缺口。
- 健康检查一天内两次失败、第三次才通过的过程，以及为此加的错开重试（只对 probe 重试，并保留失败痕迹）。

**需要进一步核实**
- QMD 的内容是否导入了内置 Memory。
- Memory Status Patrol 的报告质量：W45 超时，字段与实测不符。
- lcm-retention 是否实际删除过数据。
- wiki 是否真的会跨 agent 召回私聊内容。
- 两条技能流水线之间是否重复发布。
- 本地非记忆类补丁在当前宿主上是否仍需要。
- skill-evolution 的 cli-metadata 报错会不会影响实际功能。

**当前没有证据**
- forget 和准入策略的实际效果，以及重建索引、后台整理之后是否会把已撤销内容学回来。
- 私聊与群聊、跨 agent 的隔离测试。
- 内置 Memory 的召回质量和 retention。
- 9-16 至 10-30 缺口的影响范围。
- 任何备份的实际恢复演练。
- 新规则是否真的改变了 agent 行为。
