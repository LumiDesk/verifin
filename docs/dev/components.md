# 组件清单（Component Registry）

Veri Fin 已有的**可复用 widget / 弹窗 helper / 对话框 / 纯函数**目录。**写任何新组件、弹窗、格式化或计算之前，先在本表查一遍有没有现成的**：命中就复用或参数化扩展，不要新建变体、不要复制粘贴脚手架。规范见 `AGENTS.md` 的「代码规范 · 组件化」一节。

> 行号为编写时快照，可能随重构漂移；**以符号名为准**（IDE 里搜名字即可）。新增/重命名可复用件时，请同步更新本表。

调用约定速记：
- 底部弹窗一律经顶层 `show*Sheet(context, ...)` 函数打开（内部封 `showModalBottomSheet` + 统一 chrome），**不要**在页面里裸包 `showModalBottomSheet`。
- 「取消 / 未选」一律返回 `null`；账户「无账户」返回 **id 为空串的哨兵 `Account`**；分类特殊项用命名常量 `categoryPickerAll` / `categoryPickerTopLevel`。
- 需要触感（`hapticsEnabled`）的组件由 helper 内部从 `VeriFinScope` 取，调用方不手传。
- 应用内短反馈统一走 `VeriFeedbackHost.of(context)` / `VeriFeedbackController`；调用、队列和迁移规则见 `feedback-system.md`，新代码不得增加旧式 Material 横条。

---

## 族 1 — 布局脚手架 / 页面容器

`VeriGlassSurface` / `VeriGlassBackdrop` 位于 `glass_material.dart`，经公共入口导出，
负责默认关闭的磨砂材质预览；卡片可共享过滤组，重叠菜单/弹层使用独立过滤。
`sheets.dart` 的 `_showVeriModalSheet` 只统一材质封装，外部仍使用各领域 `show…Sheet`。
范围见 [玻璃材质预览](glass-material-preview.md)。

`VeriPage`、`VeriHeader` / `PageHeader` 与 `VeriCard` 支持显式 `compact` 参数。
当前只由开启设计预览的首页使用：16dp 页边距、56dp Header、16dp 卡片圆角，默认内边距
横向 14dp、纵向 12dp；`VeriCard.padding` 显式传入时仍优先。其余调用默认行为保持不变。

> **新建页面的标准骨架与头部对齐规则见 `docs/ui-guidelines.md`「顶部 Header 与页面骨架」**：`Scaffold > SafeArea > VeriPage > ListView(padding: fromLTRB(14,8,14,…))` + `VeriHeader`；`VeriHeader` 自身无横向内边距，头部缩进全靠外层 padding，带固定页脚的页面须单独给头部套 `Padding(fromLTRB(14,8,14,0))`。

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `VeriPage` | Widget | `common_widgets.dart` | 渐变背景 + 居中 + `maxWidth` 约束的页根容器 |
| `VeriCard` | Widget | `common_widgets.dart` | 统一圆角/描边/阴影卡片，可点击（`quietTap` 长按吞噬变体） |
| `VeriHeader` | Widget | `common_widgets.dart` | 页眉（标题+副标题+返回+actions，固定高 52） |
| `PageHeader` | Widget | `common_widgets.dart` | `VeriHeader` 的薄封装（单 trailing） |
| `VeriRootNavigation` / `VeriRootNavigationBody` / `VeriNavigationDestination` / `veriRootPageListPadding` | Widget / 值类 / 布局 helper | `root_navigation.dart` | 四个根页面的中性玻璃导航胶囊；Body 隔离 `extendBody` 注入的底栏 padding，避免嵌套日历/宫格增高；根列表再用 helper 按真实底栏高度避让，完整约定见 `liquid-glass-navigation.md` |
| `VeriFeedbackHost` / `VeriFeedbackController` / `VeriFeedbackRequest` / `VeriFeedbackResult` | 根级 Widget / Controller / 模型 | `feedback.dart` | 跨路由应用内轻提示：内容自适应宽高与三行正文、四条可见栈、优先级等待队列、2/4/8 秒与常驻、单操作 Future 结果、显式去重、前后台暂停；完整规范见 `feedback-system.md` |
| `SectionTitle` | Widget | `common_widgets.dart` | 区块标题 + 可选 trailing |
| `EmptyState` | Widget | `common_widgets.dart` | 空状态（图标+标题+描述） |
| `HeaderAction` / `HeaderTextAction` / `HeaderInline` / `VeriSectionAction` | Widget | `common_widgets.dart` | 页眉动作族（图标钮/文字钮/宽度约束/填充色小图标钮）；需要弹出操作菜单时使用 `VeriAnchoredMenuButton` |
| `VeriAnchoredMenuAnchor` / `VeriAnchoredMenuButton` / `VeriAnchoredChoice<T>` / `VeriMenuItem` / `VeriMenuDivider` | Widget / 菜单模型 | `common_widgets.dart` | Veri Fin 锚点菜单：图标、标题、副标题、分割线、选中/禁用态、根/默认子菜单/单项子菜单独立宽度、从点击行原位展开的容器变换，以及缩放/压暗但不丢失的完整祖先卡片栈；任意触发器用 `Anchor`，Header 图标入口用 `Button`，2–8 项静态受控单选优先用 `Choice`；完整用法见 [anchored-menu.md](anchored-menu.md) |
| `SaveHeaderAction` | Widget | `common_widgets.dart` | 全屏编辑页统一保存动作；固定软碟语义的 `Icons.save_outlined` 和本地化 tooltip，支持禁用态 |
| `SortModeHeaderActions` | Widget | `common_widgets.dart` | 管理页显式排序模式的统一 Header 动作；普通态进入排序，排序态提供取消与软碟保存，未改动时禁用保存 |

## 族 2 — 图标渲染（统一入口，勿绕过）

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `CategoryIconBox` | Widget | `common_widgets.dart` | **分类图标带色块盒**（自动区分内置图标 / `emoji:` 前缀） |
| `CategoryGlyph` | Widget | `common_widgets.dart` | 分类裸字形（无背景，Chip/内联用） |
| `AccountIconBox` | Widget | `common_widgets.dart` | 账户图标统一渲染入口：通用/品牌均为 SVG，固定纯白底、10% 内边距与 8% 黑色描边；未知 code 回退钱包 SVG，不走 Material 图标分支 |
| `VeriIconBox` | Widget | `common_widgets.dart` | 通用色块图标盒（给定 `IconData`） |
| `iconForCode` | 纯函数 | `icon_catalog.dart` | code→`IconData`（**底层，渲染点勿直接调，走上面的盒子**，否则 emoji 会回退成钱包图标） |
| `isEmojiIconCode` / `emojiOfIconCode` / `emojiIconCode` | 纯函数 | `icon_catalog.dart` | emoji 图标编解码 |
| `iconLabelForCode` | 纯函数 | `icon_catalog.dart` | 图标 code→本地化名称 |

## 族 3 — 账户相关

| 名称 | 类型 | 位置 | 用途 / 关键点 |
|---|---|---|---|
| `showAccountPickerSheet` | Sheet 函数 | `sheets.dart` | 账户选择弹窗（图标+余额+卡号后四位）；**按当前资产视图模式分区**（类型视图=按 `AccountType`，分组视图=按分组+未分组，分区/区内顺序复用 `sortedAssetSections`/`sortedAccountsForAssetSection`，随备份还原）；`noneLabel` 非空时列首加「无账户」→ 返回 **id 为空串哨兵 `Account`**；`allLabel` 非空时列首加「全部」→ 返回 **id 为 `accountPickerAllId` 哨兵 `Account`**（筛选场景）；取消返回 `null` |
| `showAccountIconSheet` | Sheet 函数 | `sheets.dart` + `account_icon_picker.dart` | 账户图标选择；按通用、支付、信用、投资理财、卡组织、跨境与数字账户、银行分组网格浏览，支持中英文名、简称和机构缩写搜索 |
| `confirmDeleteAccount` | Dialog 函数 | `sheets.dart` | 删账户流程（有流水→隐藏/删除三选；级联提示停用周期规则）；返回命令是否完成，由带 Guard 的调用页统一退出 |
| `CardNumberFields` | Widget | `common_widgets.dart` | 完整卡号 + 后四位输入组，含「后四位跟随卡号」开关（信用卡/储蓄卡录入用）；**受控**：`follows`/`onFollowsChanged` 由调用方持久化（`Account.cardLast4Follows`），组件不自行反推 |
| `showCardNumberDialog` | Dialog 函数 | `sheets.dart` | 编辑完整卡号+后四位+跟随开关，返回 `({number, last4, follows})?`（内部用 `CardNumberFields`，后四位以 `cardLast4Of` 归一化） |
| `CreditRepaymentPage` | 页面 Widget | `credit_repayment_page.dart` | 信用卡/信用账户还款页；预填欠款、扣款账户可选/可代还，落一笔转账 |
| `AccountSectionCard` | Widget | `common_widgets.dart` | 资产页账户分区卡（可折叠 + 分区合计）；同时服务类型、文件夹分组和隐藏账户等分区，仅传 `sectionDragIndex` / `onReorderAccounts` 时启用拖拽 |
| `accountBalanceColor` | 纯函数 | `common_widgets.dart` | **账户余额上色**（不计入资产=弱化，负=红，正=青绿） |
| `accountDisplayName` | 纯函数 | `model_lookup.dart` | 按 id 取账户名，空 id→noneLabel（**展示层用它**，避免误回退首个账户） |
| `accountById` | 纯函数 | `model_lookup.dart` | 按 id 取账户（会回退首个，展示层慎用） |

## 族 4 — 分类相关

| 名称 | 类型 | 位置 | 用途 / 关键点 |
|---|---|---|---|
| `showCategoryPickerSheet` | Sheet 函数 | `sheets.dart` | **多级分类选择弹窗**（展开/收起层级树，**按 支出/收入/转账 分区并各带类型标题**，图标按 `colorForType` 上色，区内保持列表顺序）；`allLabel` 非空加「全部」→ 返回 `categoryPickerAll`；`topLevelLabel` 加「移到顶级」→ 返回 `categoryPickerTopLevel`（「全部」「移到顶级」用中性主题色）。**选分类一律用它**，不要裸包 `showModalBottomSheet` |
| `CategoryPickerSheet` | Widget | `entry_sheets.dart` | 上面 helper 的内部 widget（一般经 `showCategoryPickerSheet`）；`categoryPickerAll` / `categoryPickerTopLevel` 哨兵常量在此 |
| `showCategoryIconPickerSheet` | Sheet 函数 | `sheets.dart` | 分类图标（内置网格 + emoji 快选 + 自由输入） |
| `categoryById` / `categoryByIdFrom` / `categoriesFor` | 纯函数 | `model_lookup.dart` | 取分类 / 按类型过滤 |
| 分类树工具集 | 纯函数 | `category_tree.dart` | `categoryIndex` `rootCategories` `childrenOf` `hasChildren` `ancestorIds` `rootIdOf` `descendantIds` `isDescendantOf` `depthOf` `pathLabel` `flattenTree`（均带环检测）；`CategoryNode` 携带 depth |

## 族 5 — 金额输入 / 计算

| 名称 | 类型 | 位置 | 用途 / 关键点 |
|---|---|---|---|
| `showNumberPadSheet` | Sheet 函数 | `sheets.dart` | **数字键盘弹窗**（四则算式 + 结果预览）；货币金额传 `currencyCode` 自动遵循 ISO minor unit，汇率输入才显式用 `maxFractionDigits:10`；`maxAmount` 的展示/比较也随币种精度，JPY 自动禁用小数点。触感偏好内部自取。**输金额一律用它**，不要弹系统 TextField、不要裸包 `showModalBottomSheet` |
| `NumberPadSheet` | Widget | `entry_sheets.dart` | 上面 helper 的内部 widget（一般经 `showNumberPadSheet`） |
| `showCurrencyPickerSheet` | Sheet 函数 | `sheets.dart` | 可搜索的离线 ISO 4217 法定货币选择器（代码/中英文名/符号，支持常用/业务优先币种与排除项）；取消返回 `null` |
| `evaluateAmountExpression` / `amountExpressionHasOperator` | 纯函数 | `calc_expression.dart` | 算式求值（不完整返回 null，结果已规整到分）/ 是否含运算符 |
| `CurrencyCatalog` | 静态目录 | `currency_catalog.dart` | 离线 ISO 4217 法定货币定义、常用币种排序与中英文搜索；业务层不得另建货币清单 |
| `normalizeCurrencyAmount` / `formatCurrencyNumber` / `formatMoney` / `formatUserMoney` / `formatSignedUserMoney` / `displayCurrencyUnit` / `formatRateValue` / `formatRateValueExact` | 纯函数 | `currency_math.dart` | 按币种 minor unit 规整与格式化；用户界面优先用 `formatUserMoney` 族，自动遵循符号/代码与单币种隐藏偏好；`formatRateValue` 是 4/6/8 位自适应的界面文本，CSV 等精确往返必须用 `formatRateValueExact` |
| `exchangeRateAt` / `rateToBaseAt` / `convertCurrencyAmount` | 纯函数 | `currency_math.dart` | 按交易日取最近历史汇率（不使用未来值）/ 经本位币交叉换算；缺汇率返回强类型结果 |
| `convertAccountBalancesToBase` / `ConvertedAccountBalances` | 纯函数 / 结果类型 | `currency_math.dart` | 把账户原币余额完整折算到本位币；任一账户缺率时 `completeTotal == null`，并返回缺失币种和受影响账户，禁止展示部分总额 |

## 族 6 — 交易展示

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `TransactionTile` | Widget | `common_widgets.dart` | 单条交易行（图标+分类+时间/备注+金额+账户 pill+待报销/已退款徽标，多选态内建） |
| `TransactionListCard` | Widget | `common_widgets.dart` | 交易列表卡（多条 `TransactionTile` + 分隔线） |
| `DateGroupHeader` | Widget | `common_widgets.dart` | 日期分组小标题（日期+今天/昨天+当日合计） |
| `groupEntriesByDate` / `relativeDay` | 纯函数 | `common_widgets.dart` | 按日分组、日期倒序 / 相对今天；`DateEntryGroup` 分组模型 |
| `CalendarPreview` | Widget | `common_widgets.dart` | 月历预览（内建月份切换 + 日收支）；必传 `currencyCode`，卡片右下角显示轻量单位提示 |
| `EntryTagField` | Widget | `common_widgets.dart` | 记账表单标签行 |
| `AttachmentsEditor` | Widget | `attachments_editor.dart` | 多图片附件横向缩略图、全屏查看和逐张删除；默认自带标题与拍照/相册添加入口，记账页的轻量元数据布局通过 `showHeader:false` / `showAddButton:false` 只复用缩略图条，添加入口由页面标签触发 |
| `TagSelectorSheet` / `pickEntryTags` | Widget / Sheet 函数 | `entry_sheets.dart` / `sheets.dart` | 交易标签多选（即时新建）/ 接 controller 的弹窗封装 |
| `RefundSection` / `showRefundSheet` | Widget / Sheet 函数 | `refund_editor.dart` | 支出详情页的受控「退款」草稿区（列退款明细+净支出+添加）/ 添加·编辑退款弹窗（金额截剩余可退、到账账户、已到账开关+到账日期、发起日期、备注、删除）；Sheet 保存只回传父交易草稿，交易页最终与本体、附件原子保存。待退款清单独立编辑时由调用方在 Sheet 确认后提交 |
| `PendingRefundsPage` | Widget | `pending_refunds_page.dart` | 「待退款」清单页（汇总当前账本所有待到账退款、一键标记已到账核销）；入口在交易列表页头 |

## 族 7 — 表单 / 设置行 / 通用列表行

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `SelectField` | Widget | `common_widgets.dart` | 下拉选择字段；`leading` 可传自定义前置（如账户图标），`suffixIcon` 可替换默认箭头提供清除等局部操作 |
| `SectionLabel` | Widget | `common_widgets.dart` | 分组小标题（分区 `VeriCard` 上方的灰色标签，设置页/账户详情页分模块用） |
| `SettingsRow` | Widget | `common_widgets.dart` | 设置行（图标+标题+trailing 文本+chevron）；`leading` 可传账户图标等自定义前置，`contentColor` 可上色（如危险操作红色） |
| `CompactSwitchRow` | Widget | `common_widgets.dart` | 紧凑开关行；`onChanged:null` 保留原生禁用语义，用于不支持的浏览器能力 |
| `DetailInfoRow` | Widget | `common_widgets.dart` | 详情页 label/value 行（可点击带 chevron） |
| `CurrencyAmountField` | Widget | `common_widgets.dart` | 交易/退款/周期编辑器统一的货币金额行；按 ISO minor unit 格式化且强制带单位，避免同一表单多币换算歧义；`amount == null` 时显示明确缺失态 |
| `MoneyUnitLabel` | Widget | `common_widgets.dart` | 聚合卡片/页面的轻量「单位：¥/CNY」提示；概览、预算、日历、看板等已在统一上下文标单位的组件复用，不要在每个数字旁堆标识 |
| `SummaryMetric` | Widget | `common_widgets.dart` | **指标块**（label+value+color+detail）。各类统计小块一律用它，勿新造 `_XxxMetric`/`_XxxTile` |
| `FilterPill` | Widget | `common_widgets.dart` | 筛选胶囊（标签+可选图标+chevron） |
| `ToolEntry` | Widget | `common_widgets.dart` | 工具入口图标块 |

## 族 8 — 对话框 / 弹窗 helper

| 名称 | 类型 | 位置 | 用途 / 返回约定 |
|---|---|---|---|
| `showConfirmDialog` | Dialog 函数 | `common_widgets.dart` | **统一确认框**；`destructive` 红色；返回 `bool`（取消/点外=false）。**禁止内联两按钮 `AlertDialog`** |
| `showInfoDialog` | Dialog 函数 | `common_widgets.dart` | 统一只读说明框（标题、正文、单个“知道了”按钮）；新调用使用具名 `context:` |
| `showUnsavedChangesDialog` / `EditorExitDecision` | Dialog 函数 / 枚举 | `common_widgets.dart` | 未保存修改的“保存 / 不保存 / 取消”三操作对话框；点遮罩或系统返回视为取消 |
| `UnsavedChangesGuard` / `EditorExitController` | Widget / Controller | `common_widgets.dart` | 统一拦截编辑页 Header、系统与预测性返回；仅 `onSave` 成功后放行，未修改时不拦截；显式保存成功后用 `EditorExitController.exit()` 走同一受控退出路径，避免同帧旧 dirty 状态拦截程序化返回 |
| `showTextInputDialog` | Dialog 函数 | `sheets.dart` | **统一文本输入**；`allowEmpty`、`keyboardType`；返回 trim 后 `String?` |
| `showOptionSheet<T>` | Sheet 函数 | `sheets.dart` | 动态、较长或需 `sectionOf` 分区的通用单选底部弹窗；2–8 项静态受控单选优先用 `VeriAnchoredChoice<T>`；返回 `T?` |
| `showLedgerBookEditorSheet` | Sheet 函数 | `sheets.dart` | 新建账本统一表单，同时收集名称与本位币，返回命名 record；取消返回 `null` |
| `confirmLegacyLedgerCurrency` | Sheet/Dialog 流程 | `sheets.dart` | 旧单币种账本的一次性确认/重解释流程：选币、展示影响数量、二次确认，并调用 Controller 原子迁移；取消或失败返回 `false` |
| `showMonthlyBudgetOverrideSheet` / `showCategoryBudgetOverrideSheet` | Sheet 函数 | `sheets.dart` | 总预算 / 分类预算的单期覆盖管理；按自然月/自定义周期显示“本月/本期”，可设置或调整所选期额度，有覆盖时可清除并恢复默认；内部复用 `showOptionSheet` + `showNumberPadSheet`，调用方只传 `context:`、键月与可选分类 |
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
| 日历日算术 | `calendar_days.dart`（经 `ledger_math.dart` re-export） | `calendarDaysBetween` `addCalendarDays`——**「相隔几天」「往后推 N 天」一律走这两个，禁止裸用 `difference().inDays` / `add(Duration(days:))`**：那是绝对时间，跨夏令时会差一小时→错一天（CI 在 UTC 恒绿，只在欧美时区暴露） |
| 账目数学 | `ledger_math.dart` | `signedAmount` `accountDeltaForEntry` `entryTouchesAccount` `colorForType` `sumByType` `isZeroAmount` `normalizeAmount`（金额按分规整）；`dateOnly` `cumulativeWeekWindowFor` `monthWindowFor` `weekWindowFor` `quarterWindowFor` `quarterOfMonth` `entriesInWindow` `valuesForTypeInWindow` `dailyExpenseValues` `dayExpenseTotal` `monthlyExpenseValues` `monthlyNetValuesForType`；`DateWindow` |
| 金额/时间格式化 | `ledger_math.dart` | `formatAmount` `formatExpenseAmount` `formatIncomeAmount` `formatSignedAmount` `formatCompactAmount` `formatTime`（**金额文本只走这些**，勿内联手拼） |
| 全局金额偏好 | `amount_format.dart` | 顶层量 `currencyFractionStyle`（紧凑/货币标准小数位）、`moneyUnitStyle`（符号后置/代码前置）、`hideUnitInSingleCurrency` 与 `activeBookUsesMultipleCurrencies`；Controller 单向同步，界面不直接修改顶层状态；`amountForceTwoDecimals` 仅为旧设置兼容入口 |
| 序列/坐标轴 | `series_math.dart` | `isInMonth` `monthAxisLabels` `reportAxisLabels` `isoWeekNumber` `accountBalanceSeries` `accountMonthlyBalanceSeries` `monthlyNetAssetSeries` `balanceAxisLabels` `bookkeepingDays` |
| 统计分析 | `report_analysis.dart` | `reportSummary` `reportMonthlyComparison` `formatChangeRatio` `reportCategoryStats` `reportCategoryStatsByOwn` `reportCategoryChildStats` `reportTagStats` `reportTrend`；`ReportRange` `ReportSummary` `ReportCategoryStat` `ReportTagStat` `ReportTrend` |
| 首页指标 | `home_metrics.dart` | `computeHomeMetric` `homeMetricLabel` `homeMetricGroups` `formatHomeMetric` `homeMetricColor`；`HomeMetric` `HomeMetricContext` `HomeTrendConfig` |
| 周期记账 | `recurring.dart` | `advanceRecurring` `dueDatesFor` |
| 信用类账户 | `credit_card.dart` | `nextDueDate` `daysUntilDue` `nextStatementDate` `currentBillingCycle` `usedCredit` `availableCredit` `billingCycleExpense`；卡号 `cardLast4Of`（在 `models.dart`） |
| 记账自动识别 | `category_suggest.dart` | `suggestEntry`（推断类型/分类/标签/备注）；`EntrySuggestion` |
| 多币种草稿缩放 | `entry_currency_draft.dart` | `scaleDependentCurrencyAmount`——手工/导入/旧数据或固定周期规则改原币金额时保持既有结算比例，并按目标币种规整 |
| 账目数据校验 | `ledger_data_validation.dart` | `validateLedgerEntries` `LedgerDataValidationIssue`——交易聚合、账单导入和备份恢复共用的三层金额/退款/引用校验 |
| AI 对话查询工具 | `ai/ledger_query.dart`、`ai/ai_query_tool.dart`、`ai/ai_tool_schema.dart` | 通用交易筛选 `queryLedgerEntries`（`LedgerQuery`）；只读工具协议 `AiQueryTool` + `AiToolContext` + `AiToolResult` + `AiResultDisplay`（sealed）+ typed Schema + 注册表 `buildAiQueryTools`（**新增分析工具在此登记，并更新 `ai-tools.md`**） |
| AI Agent 引擎 | `ai/ai_agent_engine.dart`、`ai/ai_native_tool_protocol.dart`、`ai/ai_prompt_tool_protocol.dart` | 双协议只读 Agent 状态机（结构化 `AiAgentMessage` / `AiAgentEvent`）；原生 Tool Calls 与兼容标记协议共用工具执行、轮次和重试边界；结构化传输入口为 `aiAgentStream` / `aiAgentComplete` |
| 设计令牌 | `app_theme.dart` | 色 `veriRoyal`(主 #346edb) `veriBlue` `veriIncome` `veriExpense` `veriWarning` 等；圆角 `veriRadiusSm/Md/Lg/Xl`；`veriHeaderHeight` `veriPageMaxWidth` |

## 族 11 — AI 对话查询 UI

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `AiChatPage` | 页面 Widget | `ai_chat_page.dart` | 全屏 AI 财务 Agent 对话页（气泡 + 工具步骤 + 输入框 + 清空历史，未配置引导去设置）；`debugTransport` / `debugCompleteTransport` 供测试注入结构化传输 |
| `AiAgentStepView` | Widget | `ai_agent_step_view.dart` | Agent 工具调用与重试的紧凑可折叠步骤卡；只展示本地化参数与结果摘要，不展示协议 JSON / reasoning / 底层异常 |
| `AiResultView` | Widget | `ai_result_view.dart` | 把 `AiResultDisplay` 渲染成统计卡 / 柱状排行 / 折线趋势 / **可点击交易列表** / 表格（新增展示类型在此加一支） |

---

## 维护约定

- `app_theme.dart` 新增候选材质令牌与纯函数 `veriContentSurfaceColor(Brightness)`，供 `VeriCard` 和资产封面共用；`veriUnifiedDesignPreview` 默认关闭。既有组件的候选行为见 [统一设计候选方案](unified-design-preview.md)。

- 新增可复用件 → 归入对应族、加进本表、放对的文件（通用叶子组件→`common_widgets.dart`，跨路由反馈 Host→`feedback.dart`，弹窗 helper→`sheets.dart`，记账相关 widget→`entry_sheets.dart`，纯计算→对应 `*_math`/`*_tree` 模块）。
- 同一 UI 片段或逻辑在 **≥2 个文件**出现 → 立即抽共享件，变体用参数表达。
- 删除/重命名可复用件 → 同步改本表与所有调用点。
