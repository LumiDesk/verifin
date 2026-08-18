# AI Agent · 工具登记与维护

> Issue #32 的双协议 Agent、工具步骤展示与可靠性整改已经实现。设计背景、边界和分阶段
> 方案保留在 [ai-agent-design.md](ai-agent-design.md)，当前实现事实以本文和源码为准。

「和 AI 对话查询账目」功能里，AI 通过调用一组**只读工具**来查询本地账目数据，再把结果以图表 / 列表 / 卡片 + Markdown 文字呈现给用户。本文件是**工具注册表的活文档**：新增工具、修改工具、修复工具问题都必须同步更新此处。

- 协议与注册表：[lib/app/ai/ai_query_tool.dart](../../lib/app/ai/ai_query_tool.dart)
- Agent 状态机：[lib/app/ai/ai_agent_engine.dart](../../lib/app/ai/ai_agent_engine.dart)
- 双协议实现：[lib/app/ai/ai_native_tool_protocol.dart](../../lib/app/ai/ai_native_tool_protocol.dart)、[lib/app/ai/ai_prompt_tool_protocol.dart](../../lib/app/ai/ai_prompt_tool_protocol.dart)
- 结构化传输：[lib/app/ai/ai_client.dart](../../lib/app/ai/ai_client.dart)
- 通用交易筛选纯函数：[lib/app/ai/ledger_query.dart](../../lib/app/ai/ledger_query.dart)
- 单测：[test/ai_agent_engine_test.dart](../../test/ai_agent_engine_test.dart)、[test/ai_prompt_tool_protocol_test.dart](../../test/ai_prompt_tool_protocol_test.dart)、[test/ai_query_tool_test.dart](../../test/ai_query_tool_test.dart)、[test/ledger_query_test.dart](../../test/ledger_query_test.dart)

## 架构约定

- **Agent 同时支持两种协议**：优先使用 OpenAI 兼容的原生 Tool Calls；端点明确不支持时，自动模式在本次请求内安全降级到带边界标记的兼容提示词协议。用户也可在 AI 设置中固定协议。
- **工具 schema 是单一事实来源**：每个工具通过 `AiToolSchema` / `AiToolParameter` 声明参数，同时生成原生 function definition 和兼容协议说明，避免两套协议的参数约定漂移。
- **工具全部只读、纯函数**：输入 `AiToolContext` 数据快照（当前活动账本的交易 / 账户 + 全局分类 / 标签 + 余额查询 + 账本本位币 + 当前时间），不触达 controller，便于单测。**绝不提供任何写数据的工具。**
- **每个工具产出 `AiToolResult`**：
  - `summary`：紧凑的结构化文本，**回喂模型**继续推理（含关键数字）。
  - `display`：给聊天页渲染的规格（`AiResultDisplay` 的子类），可为 null。
- **数据范围**：仅当前活动账本（与 App 内其它数据工具一致）。
- **金额口径**：统计、金额筛选和工具摘要统一使用交易保存时冻结的账本本位币金额，并在提示词、工具回传与结果卡片中明确 ISO 货币代码；具体交易列表仍以交易原币为主金额展示。
- **边界**：对话主循环最多 5 轮、累计 10 次工具调用；单次回喂结果与历史上下文都有限额。传输层校验 `finish_reason` / `[DONE]`，网络失败至多重试一次，且只有尚未执行工具时才允许非流式回退。

## 新增一个工具（三步）

1. 在 `ai_query_tool.dart` 写一个实现 `AiQueryTool` 的类：`name`（全局唯一、小驼峰）/ `description`（给模型看：查什么、何时用）/ `schema`（强类型 `AiToolSchema`，参数用 `AiToolParameter` 声明）/ `run(ctx, args)`。
2. 在 `buildAiQueryTools()` 注册一行。
3. **更新本文档的「工具清单」表 + 加单测**（至少覆盖正常路径 + 非法参数降级）。

实现须对缺省 / 非法参数**优雅降级、不抛异常**（有个通用测试会对每个工具喂非法参数断言 `returnsNormally`）。时间窗解析用 `_window(args, now, fallback:)`、类型用 `_type(args)`、取参用 `_str/_num/_int`——复用这些助手，别各写一套。

## 修复工具问题

修 bug / 调整口径时：改实现 → 更新/补单测 → **在本文档对应行或下方「变更记录」写一句**（改了什么、为什么），保证「工具当前行为」始终可从本文档查到。

## 结果渲染类型（`AiResultDisplay`）

| 类型 | 用途 | 聊天页当前渲染 |
|------|------|------|
| `AiStatDisplay` | 一组指标（收支汇总等） | 统计卡 |
| `AiRankingDisplay` | 排行 / 占比（分类、标签） | 柱状图 `InteractiveBarChart` + 明细 |
| `AiTrendDisplay` | 时间序列 | 折线图 `InteractiveTrendChart` |
| `AiTransactionsDisplay` | 一组具体交易（`entryIds`） | **可点击**交易列表 `TransactionListCard`，点击进详情页 |
| `AiTableDisplay` | 模型自定义多列数据 | 表格 |

> `display` 里的 `title` 目前仍是纯函数产生的中文默认文案；这是当前已知的 i18n 缺口，后续本地化时需保持工具层无 `BuildContext`。

## 工具清单（当前已实现）

| 工具名 | 作用 | 主要参数 | 底层 | 展示 |
|--------|------|---------|------|------|
| `summary` | 某时间段收入 / 支出 / 净额与笔数 | `range` | `reportSummary` | Stat |
| `categoryRanking` | 某时间段某类型按顶级分类的金额排行与占比 | `type`,`range`,`limit` | `reportCategoryStats` | Ranking |
| `tagRanking` | 某时间段某类型按标签的金额排行与占比 | `type`,`range`,`limit` | `reportTagStats` | Ranking |
| `queryTransactions` | 按类型 / 时间 / 金额区间 / 关键词筛选具体交易 | `type`,`range`,`minAmount`,`maxAmount`,`keyword`,`sortBy`,`limit` | `queryLedgerEntries` | Transactions |
| `largestTransactions` | 某时间段某类型金额最大 / 最小的若干笔 | `type`,`range`,`limit`,`ascending` | `queryLedgerEntries` | Transactions |

**时间窗参数 `range` 预设**：`thisMonth` / `lastMonth` / `thisYear` / `lastYear` / `last7Days` / `last30Days` / `last3Months` / `last6Months` / `last12Months` / `all`；或用 `start`+`end`（`YYYY-MM-DD`）指定显式区间。

## 待实现工具（下一批）

按需补齐，各自复用现成纯函数，实现后移入上表：

| 计划工具 | 作用 | 底层 |
|---------|------|------|
| `trend` | 收支趋势序列（日 / 月粒度） | `reportTrend` |
| `compare` | 环比 / 同比对比 | `reportMonthlyComparison` |
| `accountsOverview` | 各账户余额一览 | `ctx.balanceOf` |
| `netWorth` | 资产 / 负债 / 净资产 | `home_metrics` |
| `budgetStatus` | 预算执行情况 | 预算逻辑 |
| `creditCardBill` | 信用卡本期账单 | `credit_card.dart` |

## 变更记录

- 初版：建立工具协议 + 注册表 + 通用交易筛选纯函数，首批工具 `summary` / `categoryRanking` / `tagRanking` / `queryTransactions` / `largestTransactions`。
- Agent 升级（issue #32）：旧的文本猜测循环替换为 `AiAgentEngine`；原生 Tool Calls 与兼容标记协议共用强类型消息、工具 schema、执行边界和结构化事件。传输层新增完整 SSE 结束校验、空闲超时、错误分类、安全重试与非流式回退；聊天页展示并持久化已完成的工具步骤，不渲染推理文本、原始工具 JSON 或底层异常。
- UI 打磨 + 结果卡片可持久化：`AiResultDisplay` 增加 `toJson`/`aiResultDisplayFromJson`，聊天历史每条可带 `displays`（序列化的结果卡片），**重开时连同图表一并还原**（交易列表仍只存 id、按当前数据实时解析）；聊天页改用通用 `VeriHeader`、输入栏/发送按钮/间距/字号/图表纵轴/表格样式全面优化；AI 设置页加「清空配置」。
- 多币种：`AiToolContext` 增加账本本位币；统计与金额筛选明确采用冻结本位币口径，摘要和结果卡片展示 ISO 代码；AI 记账草稿可解析 ISO 4217 原币并在保存前继续由用户复核。
