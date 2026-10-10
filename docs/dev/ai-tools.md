# AI Agent · 工具登记与维护

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
- **工具全部只读、纯函数**：输入 `AiToolContext` 数据快照（当前活动账本的交易 / 账户 / 汇率 + 全局分类 / 标签 + 余额查询 + 账本本位币 + `l10n` 语言 + `currencyDisplay` 币种显示口径 + 预算回调 + 当前时间），不触达 controller，便于单测。**绝不提供任何写数据的工具。**
- **新增 `AiToolContext` 字段**：① 同步更新上一条的输入清单；② 在本文件的架构约定与工具清单里写明字段含义、默认值（默认值须保留改动前的行为，供只关心金额口径的单测使用）与注入点（`lib/pages/ai_chat_page.dart` 的 `_send`，从 controller 快照组装）；③ 若字段影响展示或回喂文本，补一条单测钉住两种形态（多币种 / 单币种隐藏单位）。
- **每个工具产出 `AiToolResult`**：
  - `summary`：紧凑的结构化文本，**回喂模型**继续推理（含关键数字）。
  - `display`：给聊天页渲染的规格（`AiResultDisplay` 的子类），可为 null。
- **数据范围**：仅当前活动账本（与 App 内其它数据工具一致）。
- **金额口径**：收支统计、金额筛选和工具摘要使用交易保存时冻结的账本本位币金额；转账不计收支且 `baseAmount == 0`，其金额筛选/排序按交易日有效汇率临时折算转出端真实金额，摘要对**跨币种**转账展示转出/转入两端原币（同币种两端金额相同，只报一次）。金额里的币种标识跟随 `AiToolContext.currencyDisplay`（见上条），也就是跟随设置里的「单位样式」：多币种账本、或单币种账本未开「隐藏单位」时摘要按样式输出 `100 ¥` 或 `CNY 100`；单币种 + 隐藏单位时值为 `MoneyCodeDisplay.none`，摘要与表格都不写币种，给模型的系统提示词也不再告知币种代码。多币种表格必须保留币种列或直接在金额中带单位；具体交易列表仍以交易原币为主金额展示。
- **边界**：对话主循环最多 5 轮、累计 10 次工具调用；单次回喂结果与历史上下文都有限额。传输层校验 `finish_reason` / `[DONE]`，网络失败至多重试一次，且只有尚未执行工具时才允许非流式回退。

## 新增一个工具（三步）

1. 在 `ai_query_tool.dart` 写一个实现 `AiQueryTool` 的类：`name`（全局唯一、小驼峰）/ `description`（给模型看：查什么、何时用）/ `schema`（强类型 `AiToolSchema`，参数用 `AiToolParameter` 声明）/ `run(ctx, args)`。
2. 在 `buildAiQueryTools()` 注册一行。
3. **更新本文档的「工具清单」表 + 加单测**（至少覆盖正常路径 + 非法参数降级）。

实现须对缺省 / 非法参数**优雅降级、不抛异常**（有个通用测试会对每个工具喂非法参数断言 `returnsNormally`）。时间窗解析用 `_window(args, now, fallback:)`、类型用 `_type(args)`、取参用 `_str/_num/_int`——复用这些助手，别各写一套。

**新增任何输出或展示金额的位置，一律跟随 `ctx.currencyDisplay`**：摘要走 `_baseMoney(ctx, v)`，两端金额等个别格式化走 `formatMoney(..., display: ctx.currencyDisplay)`；不要用 `formatCurrencyNumber` 拼摘要、也不要裸拼 `account.currencyCode`。整列只有同一种币种时（如账户表的「币种」列）用 `ctx.currencyDisplay != MoneyCodeDisplay.none` 判断是否输出整列。单币种隐藏单位下摘要写出币种会把模型引向「合计 CNY 4,300」这类与卡片矛盾的正文。

## 修复工具问题

修 bug / 调整口径时：改实现 → 更新/补单测 → **更新本文件对应行**，保证「工具当前行为」始终可从本文档查到。

## 结果渲染类型（`AiResultDisplay`）

| 类型 | 用途 | 聊天页当前渲染 |
|------|------|------|
| `AiStatDisplay` | 一组指标（收支汇总等） | 统计卡 |
| `AiRankingDisplay` | 排行 / 占比（分类、标签） | 柱状图 `InteractiveBarChart` + 明细 |
| `AiTrendDisplay` | 时间序列 | 折线图 `InteractiveTrendChart` |
| `AiTransactionsDisplay` | 一组具体交易（`entryIds`） | **可点击**交易列表 `TransactionListCard`，点击进详情页 |
| `AiTableDisplay` | 模型自定义多列数据 | 表格 |

> `display` 里的 `title`、统计项 `label` 与表头，以及回喂模型的 `summary`，都经 `AiToolContext.l10n`（`AppLocalizations`）按当前语言解析；工具层仍无 `BuildContext`，语言由上层（聊天页）传入。`description` 与参数 schema 保持中文——它们只给模型看，不随界面语言变化。

## 工具清单

| 工具名 | 作用 | 主要参数 | 底层 | 展示 |
|--------|------|---------|------|------|
| `summary` | 某时间段收入 / 支出 / 净额与笔数 | `range` | `reportSummary` | Stat |
| `categoryRanking` | 某时间段某类型按顶级分类的金额排行与占比 | `type`,`range`,`limit` | `reportCategoryStats` | Ranking |
| `tagRanking` | 某时间段某类型按标签的金额排行与占比 | `type`,`range`,`limit` | `reportTagStats` | Ranking |
| `queryTransactions` | 按类型 / 时间 / 金额区间 / 关键词筛选具体交易 | `type`,`range`,`minAmount`,`maxAmount`,`keyword`,`sortBy`,`limit` | `queryLedgerEntries` | Transactions |
| `largestTransactions` | 某时间段某类型金额最大 / 最小的若干笔 | `type`,`range`,`limit`,`ascending` | `queryLedgerEntries` | Transactions |
| `trend` | 某时间段某类型的趋势序列（短范围按天、长范围按月） | `type`,`range` | `reportTrend` | Trend |
| `compare` | 指定月份与上月、去年同月的收支环比 / 同比 | `month` | `reportMonthlyComparison` | Stat |
| `accountsOverview` | 各账户名称、币种与余额一览（不含隐藏账户；隐藏单位时整列不输出「币种」） | — | `ctx.balanceOf` + `convertAccountBalancesToBase` | Table |
| `netWorth` | 总资产 / 总负债 / 净资产（本位币口径） | — | `convertAccountBalancesToBase` | Stat |
| `creditCardBill` | 信用类账户的欠款、可用额度、本期账单与还款日；多币种时表格保留币种列 | — | `credit_card.dart` | Table |
| `budgetStatus` | 某预算期的预算、已花、剩余、剩余日均与需要关注的分类（预算口径，排除标记「不计入预算」的支出） | `month` | `budget_status.dart` | Stat |

**时间窗参数 `range` 预设**：`thisMonth` / `lastMonth` / `thisYear` / `lastYear` / `last7Days` / `last30Days` / `last3Months` / `last6Months` / `last12Months` / `all`；或用 `start`+`end`（`YYYY-MM-DD`）指定显式区间。

