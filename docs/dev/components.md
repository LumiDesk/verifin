# 组件清单（Component Registry）

Veri Fin 已有的**可复用 widget / 弹窗 helper / 对话框 / 纯函数**目录。**写任何新组件、弹窗、格式化或计算之前，先在本表查一遍有没有现成的**：命中就复用或参数化扩展，不要新建变体、不要复制粘贴脚手架。规范见 `AGENTS.md` 的「代码规范 · 组件化」一节。

> 行号为编写时快照，可能随重构漂移；**以符号名为准**（IDE 里搜名字即可）。新增/重命名可复用件时，请同步更新本表。

调用约定速记：
- 底部弹窗一律经顶层 `show*Sheet(context, ...)` 函数打开（内部封 `showModalBottomSheet` + 统一 chrome），**不要**在页面里裸包 `showModalBottomSheet`。
- 「取消 / 未选」一律返回 `null`；账户「无账户」返回 **id 为空串的哨兵 `Account`**；分类特殊项用命名常量 `categoryPickerAll` / `categoryPickerTopLevel`。
- 需要触感（`hapticsEnabled`）的组件由 helper 内部从 `VeriFinScope` 取，调用方不手传。

---

## 族 1 — 布局脚手架 / 页面容器

> **新建页面的标准骨架与头部对齐规则见 `docs/ui-guidelines.md`「顶部 Header 与页面骨架」**：`Scaffold > SafeArea > VeriPage > ListView(padding: fromLTRB(14,8,14,…))` + `VeriHeader`；`VeriHeader` 自身无横向内边距，头部缩进全靠外层 padding，带固定页脚的页面须单独给头部套 `Padding(fromLTRB(14,8,14,0))`。

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `VeriPage` | Widget | `common_widgets.dart` | 渐变背景 + 居中 + `maxWidth` 约束的页根容器 |
| `VeriCard` | Widget | `common_widgets.dart` | 统一圆角/描边/阴影卡片，可点击（`quietTap` 长按吞噬变体） |
| `VeriHeader` | Widget | `common_widgets.dart` | 页眉（标题+副标题+返回+actions，固定高 52） |
| `PageHeader` | Widget | `common_widgets.dart` | `VeriHeader` 的薄封装（单 trailing） |
| `SectionTitle` | Widget | `common_widgets.dart` | 区块标题 + 可选 trailing |
| `EmptyState` | Widget | `common_widgets.dart` | 空状态（图标+标题+描述） |
| `HeaderAction` / `HeaderPopupAction<T>` / `HeaderTextAction` / `HeaderInline` / `VeriSectionAction` | Widget | `common_widgets.dart` | 页眉动作族（图标钮/弹菜单/文字钮/宽度约束/填充色小图标钮） |

## 族 2 — 图标渲染（统一入口，勿绕过）

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `CategoryIconBox` | Widget | `common_widgets.dart` | **分类图标带色块盒**（自动区分内置图标 / `emoji:` 前缀） |
| `CategoryGlyph` | Widget | `common_widgets.dart` | 分类裸字形（无背景，Chip/内联用） |
| `AccountIconBox` | Widget | `common_widgets.dart` | 账户图标盒（SVG 资产图标，否则回退 `VeriIconBox`） |
| `VeriIconBox` | Widget | `common_widgets.dart` | 通用色块图标盒（给定 `IconData`） |
| `iconForCode` | 纯函数 | `icon_catalog.dart` | code→`IconData`（**底层，渲染点勿直接调，走上面的盒子**，否则 emoji 会回退成钱包图标） |
| `isEmojiIconCode` / `emojiOfIconCode` / `emojiIconCode` | 纯函数 | `icon_catalog.dart` | emoji 图标编解码 |
| `iconLabelForCode` | 纯函数 | `icon_catalog.dart` | 图标 code→本地化名称 |

## 族 3 — 账户相关

| 名称 | 类型 | 位置 | 用途 / 关键点 |
|---|---|---|---|
| `showAccountPickerSheet` | Sheet 函数 | `sheets.dart` | 账户选择弹窗（图标+余额+卡号后四位）；`noneLabel` 非空时列首加「无账户」→ 返回 **id 为空串哨兵 `Account`**；取消返回 `null` |
| `showAccountIconSheet` | Sheet 函数 | `sheets.dart` | 账户/分组图标选择；`includeAssetIcons:false` 只列通用图标（分组用） |
| `confirmDeleteAccount` | Dialog 函数 | `sheets.dart` | 删账户流程（有流水→隐藏/删除三选；级联提示停用周期规则） |
| `CardNumberFields` | Widget | `common_widgets.dart` | 完整卡号 + 后四位输入组，含「后四位跟随卡号」开关（信用卡/储蓄卡录入用）；**受控**：`follows`/`onFollowsChanged` 由调用方持久化（`Account.cardLast4Follows`），组件不自行反推 |
| `showCardNumberDialog` | Dialog 函数 | `sheets.dart` | 编辑完整卡号+后四位+跟随开关，返回 `({number, last4, follows})?`（内部用 `CardNumberFields`，后四位以 `cardLast4Of` 归一化） |
| `CreditRepaymentPage` | 页面 Widget | `credit_repayment_page.dart` | 信用卡/信用账户还款页；预填欠款、扣款账户可选/可代还，落一笔转账 |
| `AccountGroupCard` | Widget | `common_widgets.dart` | 资产页账户分组卡（可折叠 + 拖拽排序 + 组合计） |
| `accountBalanceColor` | 纯函数 | `common_widgets.dart` | **账户余额上色**（不计入资产=弱化，负=红，正=青绿） |
| `accountDisplayName` | 纯函数 | `model_lookup.dart` | 按 id 取账户名，空 id→noneLabel（**展示层用它**，避免误回退首个账户） |
| `accountById` | 纯函数 | `model_lookup.dart` | 按 id 取账户（会回退首个，展示层慎用） |

## 族 4 — 分类相关

| 名称 | 类型 | 位置 | 用途 / 关键点 |
|---|---|---|---|
| `showCategoryPickerSheet` | Sheet 函数 | `sheets.dart` | **多级分类选择弹窗**（展开/收起层级树）；`allLabel` 非空加「全部」→ 返回 `categoryPickerAll`；`topLevelLabel` 加「移到顶级」→ 返回 `categoryPickerTopLevel`。**选分类一律用它**，不要裸包 `showModalBottomSheet` |
| `CategoryPickerSheet` | Widget | `entry_sheets.dart` | 上面 helper 的内部 widget（一般经 `showCategoryPickerSheet`）；`categoryPickerAll` / `categoryPickerTopLevel` 哨兵常量在此 |
| `showCategoryIconPickerSheet` | Sheet 函数 | `sheets.dart` | 分类图标（内置网格 + emoji 快选 + 自由输入） |
| `categoryById` / `categoryByIdFrom` / `categoriesFor` | 纯函数 | `model_lookup.dart` | 取分类 / 按类型过滤 |
| 分类树工具集 | 纯函数 | `category_tree.dart` | `categoryIndex` `rootCategories` `childrenOf` `hasChildren` `ancestorIds` `rootIdOf` `descendantIds` `isDescendantOf` `depthOf` `pathLabel` `flattenTree`（均带环检测）；`CategoryNode` 携带 depth |

## 族 5 — 金额输入 / 计算

| 名称 | 类型 | 位置 | 用途 / 关键点 |
|---|---|---|---|
| `showNumberPadSheet` | Sheet 函数 | `sheets.dart` | **数字键盘弹窗**（四则算式 + 结果预览）；`initialAmount` `allowNegative` `allowZero`；触感偏好内部自取。**输金额一律用它**，不要弹系统 TextField、不要裸包 `showModalBottomSheet` |
| `NumberPadSheet` | Widget | `entry_sheets.dart` | 上面 helper 的内部 widget（一般经 `showNumberPadSheet`） |
| `evaluateAmountExpression` / `amountExpressionHasOperator` | 纯函数 | `calc_expression.dart` | 算式求值（不完整返回 null，结果已规整到分）/ 是否含运算符 |

## 族 6 — 交易展示

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `TransactionTile` | Widget | `common_widgets.dart` | 单条交易行（图标+分类+时间/备注+金额+账户 pill+待报销/已退款徽标，多选态内建） |
| `TransactionListCard` | Widget | `common_widgets.dart` | 交易列表卡（多条 `TransactionTile` + 分隔线） |
| `DateGroupHeader` | Widget | `common_widgets.dart` | 日期分组小标题（日期+今天/昨天+当日合计） |
| `groupEntriesByDate` / `relativeDay` | 纯函数 | `common_widgets.dart` | 按日分组、日期倒序 / 相对今天；`DateEntryGroup` 分组模型 |
| `CalendarPreview` | Widget | `common_widgets.dart` | 月历预览（内建月份切换 + 日收支） |
| `EntryTagField` | Widget | `common_widgets.dart` | 记账表单标签行 |
| `TagSelectorSheet` / `pickEntryTags` | Widget / Sheet 函数 | `entry_sheets.dart` / `sheets.dart` | 交易标签多选（即时新建）/ 接 controller 的弹窗封装 |
| `RefundSection` / `showRefundSheet` | Widget / Sheet 函数 | `refund_editor.dart` | 支出详情页的「退款」区（列退款明细+净支出+添加）/ 添加·编辑退款弹窗（金额截剩余可退、到账账户、已到账开关+到账日期、发起日期、备注、删除）。**退款一律走这里**，经 controller `addRefund`/`updateRefund`/`deleteRefund` 即时落库 |
| `PendingRefundsPage` | Widget | `pending_refunds_page.dart` | 「待退款」清单页（汇总当前账本所有待到账退款、一键标记已到账核销）；入口在交易列表页头 |

## 族 7 — 表单 / 设置行 / 通用列表行

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `SelectField` | Widget | `common_widgets.dart` | 下拉选择字段；`leading` 可传自定义前置（如账户图标） |
| `SectionLabel` | Widget | `common_widgets.dart` | 分组小标题（分区 `VeriCard` 上方的灰色标签，设置页/账户详情页分模块用） |
| `SettingsRow` | Widget | `common_widgets.dart` | 设置行（图标+标题+trailing 文本+chevron）；`contentColor` 可上色（如危险操作红色） |
| `CompactSwitchRow` | Widget | `common_widgets.dart` | 紧凑开关行 |
| `DetailInfoRow` | Widget | `common_widgets.dart` | 详情页 label/value 行（可点击带 chevron） |
| `SummaryMetric` | Widget | `common_widgets.dart` | **指标块**（label+value+color+detail）。各类统计小块一律用它，勿新造 `_XxxMetric`/`_XxxTile` |
| `FilterPill` | Widget | `common_widgets.dart` | 筛选胶囊（标签+可选图标+chevron） |
| `ToolEntry` | Widget | `common_widgets.dart` | 工具入口图标块 |

## 族 8 — 对话框 / 弹窗 helper

| 名称 | 类型 | 位置 | 用途 / 返回约定 |
|---|---|---|---|
| `showConfirmDialog` | Dialog 函数 | `common_widgets.dart` | **统一确认框**；`destructive` 红色；返回 `bool`（取消/点外=false）。**禁止内联两按钮 `AlertDialog`** |
| `showTextInputDialog` | Dialog 函数 | `sheets.dart` | **统一文本输入**；`allowEmpty`、`keyboardType`；返回 trim 后 `String?` |
| `showOptionSheet<T>` | Sheet 函数 | `sheets.dart` | 通用单选底部弹窗（枚举/简单值）；`labelOf`、`showSelectedMarker`；返回 `T?` |
| `runWithLoadingDialog<T>` | Dialog 函数 | `common_widgets.dart` | 不可关闭加载态，任务完成自动关并返回结果 |
| `confirmCleartextIfRisky` | Dialog 函数 | `sheets.dart` | 明文 http 凭证风险确认 |

## 族 9 — 图表（全部必须支持点击气泡，见 `docs/ui-guidelines.md`）

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `InteractiveTrendChart` | Widget | `chart_painters.dart` | 可交互折线图；`values, xLabels, yLabels, glow, tooltipOf` |
| `InteractiveBarChart` | Widget | `chart_painters.dart` | 可交互柱状图；`values, xLabels, yLabels, tooltipOf` |
| `TrendLinePainter` / `BarChartPainter` / `BudgetRingPainter` | CustomPainter | `chart_painters.dart` | 底层绘制（预算环等） |
| `ChartTooltip` / `ChartTooltipLine` | 值类 | `chart_painters.dart` | 气泡数据模型 |
| `trendChartRect` / `barChartRect` / `chartNearestIndex` / `chartSlotIndex` / `drawChartTooltip` | 纯函数 | `chart_painters.dart` | 绘图区计算 / 命中测试 / 气泡绘制 |

## 族 10 — 纯计算（领域逻辑，无 Flutter 依赖或仅叶子级）

| 模块 | 位置 | 关键函数 |
|---|---|---|
| 账目数学 | `ledger_math.dart` | `signedAmount` `accountDeltaForEntry` `entryTouchesAccount` `colorForType` `sumByType` `isZeroAmount` `dateOnly` `cumulativeWeekWindowFor` `monthWindowFor` `weekWindowFor` `quarterWindowFor` `quarterOfMonth` `entriesInWindow` `valuesForTypeInWindow` `dailyExpenseValues` `dayExpenseTotal` `monthlyExpenseValues` `monthlyNetValuesForType`；`DateWindow` |
| 金额/时间格式化 | `ledger_math.dart` | `formatAmount` `formatExpenseAmount` `formatIncomeAmount` `formatSignedAmount` `formatCompactAmount` `formatTime`（**金额文本只走这些**，勿内联手拼） |
| 全局金额偏好 | `amount_format.dart` | 顶层量 `amountForceTwoDecimals`（格式化函数读取） |
| 序列/坐标轴 | `series_math.dart` | `isInMonth` `monthAxisLabels` `reportAxisLabels` `isoWeekNumber` `accountBalanceSeries` `accountMonthlyBalanceSeries` `monthlyNetAssetSeries` `balanceAxisLabels` `bookkeepingDays` |
| 统计分析 | `report_analysis.dart` | `reportSummary` `reportMonthlyComparison` `formatChangeRatio` `reportCategoryStats` `reportCategoryStatsByOwn` `reportCategoryChildStats` `reportTagStats` `reportTrend`；`ReportRange` `ReportSummary` `ReportCategoryStat` `ReportTagStat` `ReportTrend` |
| 首页指标 | `home_metrics.dart` | `computeHomeMetric` `homeMetricLabel` `homeMetricGroups` `formatHomeMetric` `homeMetricColor`；`HomeMetric` `HomeMetricContext` `HomeTrendConfig` |
| 周期记账 | `recurring.dart` | `advanceRecurring` `dueDatesFor` |
| 信用类账户 | `credit_card.dart` | `nextDueDate` `daysUntilDue` `nextStatementDate` `currentBillingCycle` `usedCredit` `availableCredit` `billingCycleExpense`；卡号 `cardLast4Of`（在 `models.dart`） |
| 记账自动识别 | `category_suggest.dart` | `suggestEntry`（推断类型/分类/标签/备注）；`EntrySuggestion` |
| AI 对话查询工具 | `ai/ledger_query.dart`、`ai/ai_query_tool.dart` | 通用交易筛选 `queryLedgerEntries`（`LedgerQuery`）；只读工具协议 `AiQueryTool` + `AiToolContext` + `AiToolResult` + `AiResultDisplay`（sealed）+ 注册表 `buildAiQueryTools`（**新增分析工具在此登记，并更新 `ai-tools.md`**） |
| AI 对话引擎 | `ai/ai_chat_engine.dart` | 多轮对话主循环 `AiChatEngine`（注入 `AiChatTransport`，产出 `AiChatEvent`）；流式客户端 `aiChatStream`（`ai/ai_client.dart`） |
| 设计令牌 | `app_theme.dart` | 色 `veriRoyal`(主 #346edb) `veriBlue` `veriIncome` `veriExpense` `veriWarning` 等；圆角 `veriRadiusSm/Md/Lg`；`veriHeaderHeight` `veriPageMaxWidth` |

## 族 11 — AI 对话查询 UI

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `AiChatPage` | 页面 Widget | `ai_chat_page.dart` | 全屏 AI 账目对话页（气泡 + 输入框 + 清空历史，未配置引导去设置）；`debugTransport` 供测试注入假流 |
| `AiResultView` | Widget | `ai_result_view.dart` | 把 `AiResultDisplay` 渲染成统计卡 / 柱状排行 / 折线趋势 / **可点击交易列表** / 表格（新增展示类型在此加一支） |

---

## 维护约定

- 新增可复用件 → 归入对应族、加进本表、放对的文件（通用组件→`common_widgets.dart`，弹窗 helper→`sheets.dart`，记账相关 widget→`entry_sheets.dart`，纯计算→对应 `*_math`/`*_tree` 模块）。
- 同一 UI 片段或逻辑在 **≥2 个文件**出现 → 立即抽共享件，变体用参数表达。
- 删除/重命名可复用件 → 同步改本表与所有调用点。
