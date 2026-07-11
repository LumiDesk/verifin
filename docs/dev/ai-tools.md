# AI 对话查询 · 工具登记与维护

「和 AI 对话查询账目」功能里，AI 通过调用一组**只读工具**来查询本地账目数据，再把结果以图表 / 列表 / 卡片 + Markdown 文字呈现给用户。本文件是**工具注册表的活文档**：新增工具、修改工具、修复工具问题都必须同步更新此处。

- 协议与注册表：[lib/app/ai/ai_query_tool.dart](../../lib/app/ai/ai_query_tool.dart)
- 通用交易筛选纯函数：[lib/app/ai/ledger_query.dart](../../lib/app/ai/ledger_query.dart)
- 单测：[test/ai_query_tool_test.dart](../../test/ai_query_tool_test.dart)、[test/ledger_query_test.dart](../../test/ledger_query_test.dart)

## 架构约定

- **实现路线是「提示词工具协议」**，不是 OpenAI 原生 function calling。系统提示词描述可用工具 + 让模型输出 `{tool, args}` JSON，本地执行后把结果回喂，多轮循环直到模型给最终答复。原因见 `tech-decisions.md`（要兼容用户自配的各种本地 / 云端模型，很多不支持原生 function calling）。
- **工具全部只读、纯函数**：输入 `AiToolContext` 数据快照（当前活动账本的交易 / 账户 + 全局分类 / 标签 + 余额查询 + 当前时间），不触达 controller，便于单测。**绝不提供任何写数据的工具。**
- **每个工具产出 `AiToolResult`**：
  - `summary`：紧凑的结构化文本，**回喂模型**继续推理（含关键数字）。
  - `display`：给聊天页渲染的规格（`AiResultDisplay` 的子类），可为 null。
- **数据范围**：仅当前活动账本（与 App 内其它数据工具一致）。
- **边界**：对话主循环设工具调用轮次上限（防打转烧 token）；单次回喂结果做截断。

## 新增一个工具（三步）

1. 在 `ai_query_tool.dart` 写一个实现 `AiQueryTool` 的类：`name`（全局唯一、小驼峰）/ `description`（给模型看：查什么、何时用）/ `argsSchema`（`{参数名: 说明}`，会序列化进提示词）/ `run(ctx, args)`。
2. 在 `buildAiQueryTools()` 注册一行。
3. **更新本文档的「工具清单」表 + 加单测**（至少覆盖正常路径 + 非法参数降级）。

实现须对缺省 / 非法参数**优雅降级、不抛异常**（有个通用测试会对每个工具喂非法参数断言 `returnsNormally`）。时间窗解析用 `_window(args, now, fallback:)`、类型用 `_type(args)`、取参用 `_str/_num/_int`——复用这些助手，别各写一套。

## 修复工具问题

修 bug / 调整口径时：改实现 → 更新/补单测 → **在本文档对应行或下方「变更记录」写一句**（改了什么、为什么），保证「工具当前行为」始终可从本文档查到。

## 结果渲染类型（`AiResultDisplay`）

| 类型 | 用途 | 聊天页渲染（落地顺序第 3 步实现） |
|------|------|------|
| `AiStatDisplay` | 一组指标（收支汇总等） | 统计卡 |
| `AiRankingDisplay` | 排行 / 占比（分类、标签） | 柱状图 `InteractiveBarChart` + 明细 |
| `AiTrendDisplay` | 时间序列 | 折线图 `InteractiveTrendChart` |
| `AiTransactionsDisplay` | 一组具体交易（`entryIds`） | **可点击**交易列表 `TransactionListCard`，点击进详情页 |
| `AiTableDisplay` | 模型自定义多列数据 | 表格 |

> `display` 里的 `title` 目前是中文默认文案；国际化（zh/en）随聊天页 UI 的 i18n 一并处理（落地顺序第 5 步）。

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
- 接入对话主循环与 UI：流式客户端 `aiChatStream`、对话引擎 `ai_chat_engine.dart`、聊天页 `ai_chat_page.dart` + 结果渲染 `ai_result_view.dart`（图表/列表/统计卡/表格），看板页头「问 AI」入口；聊天历史落 KV `verifin.ai_chat.v1`（仅文本、设备本地、不进备份、初始化保留）。
- UI 打磨 + 结果卡片可持久化：`AiResultDisplay` 增加 `toJson`/`aiResultDisplayFromJson`，聊天历史每条可带 `displays`（序列化的结果卡片），**重开时连同图表一并还原**（交易列表仍只存 id、按当前数据实时解析）；聊天页改用通用 `VeriHeader`、输入栏/发送按钮/间距/字号/图表纵轴/表格样式全面优化；AI 设置页加「清空配置」。
