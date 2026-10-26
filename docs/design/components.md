# 组件清单（Component Registry）

Veri Fin 已有的**可复用 widget / 弹窗 helper / 对话框 / 纯函数**目录。**写任何新组件、弹窗、格式化或计算之前，先在本表查一遍有没有现成的**：命中就复用或参数化扩展，不要新建变体、不要复制粘贴脚手架。规范见 [AGENTS.md](../../AGENTS.md) 的「Coding Style · 组件与设计令牌」一节。

> 行号为编写时快照，可能随重构漂移；**以符号名为准**（IDE 里搜名字即可）。新增/重命名可复用件时，请同步更新本表。

调用约定速记：
- 底部弹窗一律经顶层 `show*Sheet(context, ...)` 函数打开（内部封 `showModalBottomSheet` + 统一 chrome），**不要**在页面里裸包 `showModalBottomSheet`。
- 「取消 / 未选」一律返回 `null`；账户「无账户」返回 **id 为空串的哨兵 `Account`**；分类特殊项用命名常量 `categoryPickerAll` / `categoryPickerTopLevel`。
- 需要触感（`hapticsEnabled`）的组件由 helper 内部从 `VeriFinScope` 取，调用方不手传。
- 应用内短反馈统一走 `VeriFeedbackHost.of(context)` / `VeriFeedbackController`；调用、队列和迁移规则见 `feedback-system.md`，新代码不得增加旧式 Material 横条。

---

## 族 1 — 布局脚手架 / 页面容器

预算圆环用 `VeriBudgetRing`（`chart_painters.dart`，内部是 `fl_chart` 环形图），参数为 value/trackColor/progressColor/center/strokeWidth；轨底 + 进度弧两段，中心内容由调用方给，禁止内外白线。

**表面材质**：除可选的液态玻璃底栏样式外，卡片、导航、快捷按钮、菜单与弹层一律用不透明实色。
`VeriCard`（`common_widgets_scaffold.dart`）走 `veriContentSurfaceColor(brightness)` + 圆角 + 细描边；
页面背景取 `scaffoldBackgroundColor` 的画布纯色；弹层由 `sheets.dart` 的 `_showVeriModalSheet`
统一为实色表面 + 顶部圆角 + 内置拖拽把手，外部仍使用各领域 `show…Sheet`。
**除液态玻璃底栏样式外禁止**为了「做质感」引入 `BackdropFilter`、`ImageFilter.blur`、片元着色器滤镜或整屏渐变。

`OnboardingGate`（`onboarding_page.dart`）位于 PrivacyConsentGate / AppLockGate 内部，完成引导前不构建首页。

`AppLockGate`（`pages/app_lock_gate.dart`）位于根 Navigator 之上，负责冷启动和回前台锁定；
`AppLockSessionScope`（`app/app_lock_session.dart`）的 `waitUntilUnlocked` 是 Shell 外部入口
（分享、快捷记账、小组件路由）的统一排队点。
`AppLockScreen` 支持可选 `config`，供独立小组件配置引擎在读取账本前完成 PIN/图案验证。

`WidgetRefreshScope`（`app/widgets/widget_refresh_scope.dart`）把桌面投影的刷新协调器暴露给页面层，
只服务**退出路径**：Shell 在 `SystemNavigator.pop()` 之前等一次 `flush()`，避免引擎随 Activity
关闭而掐断未完成的发布（详见 [home-widgets.md](../dev/home-widgets.md)「刷新管线」）。

公共骨架只有一套已评审密度：16dp **有效**页边距（页面容器写 14dp，`VeriPage` 再补 2dp）、
56dp Header 最小高度、16dp 卡片圆角，`VeriCard` 默认内边距横向 14dp、纵向 12dp。
`VeriCard.padding` 显式传入时优先。`compact` 是分段控件等局部交互组件的尺寸参数，不是页面级构建开关。

> **新建页面的标准骨架与头部对齐规则见 `docs/design/ui-guidelines.md`「顶部 Header 与页面骨架」**：`Scaffold > SafeArea > VeriPage > ListView(padding: fromLTRB(14,8,14,…))` + `VeriHeader`；`VeriHeader` 自身无横向内边距，头部缩进全靠外层 padding，带固定页脚的页面须单独给头部套 `Padding(fromLTRB(14,8,14,0))`。

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `VeriPage` | Widget | `common_widgets.dart` | 纯色背景 + 居中 + `maxWidth` 约束的页根容器 |
| `VeriFinBootstrap` / `StartupCoordinator` / `StartupErrorSink` | Widget / 协调器 / 错误缓冲 | `app/startup/` | **启动壳**：`main()` 不再在 `runApp()` 前等待数据，首帧先画启动页，再由协调器逐阶段载入偏好、数据库、控制器、周期补记与可选的着色器预热。单阶段看门狗超时显示「启动较慢」，任一阶段失败显示阶段、错误与「复制诊断 / 重试」；`StartupErrorSink` 在 KV 打开前缓冲错误、logger 就绪后按原时间回放。启动壳只显示阶段与诊断，不读账目，也不替代 `PrivacyConsentGate` / `AppLockGate` / `OnboardingGate` |
| `VeriCard` | Widget | `common_widgets.dart` | 统一圆角/描边/阴影卡片，可点击（`quietTap` 长按吞噬变体） |
| `VeriHeader` | Widget | `common_widgets.dart` | 页眉（标题+副标题+返回+actions，最小高度 56；用最小高度而非固定高度，系统字号放大时两行标题不会被裁掉） |
| `PageHeader` | Widget | `common_widgets.dart` | `VeriHeader` 的薄封装（单 trailing）；`subtitle` 为 `String?`，`null` 时整行不渲染；副标题里带「单位：x」必须用 `currencyUnitSubtitle`（族 7）——隐藏单位且无上下文时它返回 `null`，直接传进去即可整段省略 |
| `VeriRootNavigationStyle` / `VeriRootNavigationLayout` / `VeriRootNavigationSpec` / `VeriRootNavigationHost` / `VeriRootNavigationBody` / `VeriNavigationDestination` / `veriRootPageListPadding` | 契约接口 / 值类 / Widget / 布局 helper | `root_navigation.dart` | 根导航的**样式契约**：样式只声明几何事实（`extendBody`、`occupiedHeight`、`listBottomGap`，避让高度由 `contentBottomPadding` 统一推导）和选中动效时长，并实现 `buildBar` 画栏；`buildBar` 只吃纯数据 `spec`，不接触 Controller/KV/Navigator，因此同一实现同时服务真实壳层与样式选择页预览（预览把 `onSelect` 置空）。每个样式必须产出 `keyOf('bottom_nav')`、`keyOf('nav_bar')` 与 `keyOf('nav_item_<下标>')` 稳定 key，测试与无障碍按 key 定位、不依赖几何。壳层经 `VeriRootNavigationHost` 渲染，测试从这里读 `spec`。契约不含记账按钮（按钮与导航栏解耦，硬约束与契约测试清单见 `docs/design/ui-guidelines.md` 的「根导航」）。切页动画被用户交互打断时由 `_finishTabSwitch` 按页面实际落点对齐底栏，不能写死点击目标 |
| `VeriRootNavigationStyles` 注册表（`veriRootNavigationStyles` / `veriRootDefaultNavigationStyle` / `veriRootNavigationStyleFor`） | 常量 / 查表函数 | `root_navigation_styles.dart` | 样式注册表：顺序即样式选择列表顺序；`veriRootNavigationStyleFor` 对缺失/未知标识一律回退默认样式。新增样式须同时加同名 `NavigationStylePreference` 枚举值 |
| `VeriDockedRootNavigationStyle` / `VeriDockedRootNavigation` | 样式实现 / Widget | `root_navigation_docked.dart` | **停靠式底栏**：整宽、不透明、贴底，底色铺到屏幕最底（含系统导航条背后，否则会分成两块）。条目由 `VeriBottomBar`（`veri_bottom_bar.dart`）绘制，**未选中用 `destination.icon`（线框）、选中用 `selectedIcon`（填充）**，中文标签常显。**安全区**用 `SafeArea(minimum: 12, maintainBottomViewPadding: true)` 取 `max(系统留白, 12)`：系统留白可能是 0，不给下限条目会贴边；`maintainBottomViewPadding` 让键盘弹起时底栏不跳。这是**默认样式**，条高 64、列表留白 12 |
| `VeriLiquidGlassRootNavigationStyle` / `VeriLiquidGlassRootNavigation` | 样式实现 / 适配 Widget | `root_navigation_liquid_glass.dart` | **液态玻璃底栏（可选样式）**：适配本地 vendor `third_party/liquid_glass_widgets` 的 `GlassTabBar.bottom`，保留 60dp 胶囊、12dp 左右边距和 24dp 底部留白；`layout` 声明 `extendBody: true`、列表留白 16。四个目的地、选中态、标签常显和 `spec.onSelect` 仍由应用契约提供；条目的稳定 key 由未选中图标上的 `KeyedSubtree` 提供，选中层不重复挂 key。深色模式使用低压白色 tint、低饱和轻磨砂与轻黑色 backer，避免底栏发蓝、发白或形成厚重雾块；浅色模式保持库默认材质。其他页面不得直接使用第三方玻璃组件。 |
| `GlassTabBar.bottom`（本地 vendor） | 第三方 Widget | `third_party/liquid_glass_widgets` | 背景采样、玻璃面板、模糊/折射、Jelly 指示器、拖动切换和选中态语义由库实现；只在 `root_navigation_liquid_glass.dart` 引用，其他页面不得直接使用第三方玻璃组件。 |
| `NavigationStyleSettingsPage` | 页面 Widget | `navigation_style_settings_page.dart` | 导航栏样式选择页（设置 → 外观 → 导航栏样式）。逐样式渲染**冻结预览**：直接复用 `buildBar`，因此预览与真机同源（真实标签、真实表面色）；液态玻璃预览使用 `GlassQuality.minimal` 的静态降级路径，避免父级滚动时 premium shader 沿用旧位置，真实根导航仍使用 premium。预览整块 `IgnorePointer`（条目没有回调），点预览区域等于选中该样式。点选只改页面草稿，保存经 `UnsavedChangesGuard` 回传**样式标识字符串**；页面不写 Controller/KV，落盘由设置页统一保存完成。`styles` 参数默认取注册表，测试或画廊可传子集。 |
| `veriRootNavigationDestinations` | 纯函数 | `root_navigation.dart` | 四个根目的地（首页/资产/看板/我的）的**唯一定义**：Shell 与样式选择页预览共用，新增样式不要再各写一套图标与标签 |
| `NavigationStylePreference` | 枚举 | `models/preferences.dart` | 导航样式偏好（当前 `docked` 默认、`liquidGlass` 可选），枚举名即样式标识、存 KV `verifin.nav_style.v1`；设备本地、不进备份、初始化数据时保留、`resetAllData` 恢复默认。新增样式须同时加枚举值与注册项（测试断言两者一一对应） |
| `VeriBottomBar` / `VeriBottomBarItem` | Widget / 值类 | `veri_bottom_bar.dart` | 停靠样式的条目绘制：切换时两条圆弧扫过、两枚圆点飞过，图标由灰渐变为主题主色并轻微摆动。颜色缺省取 `Theme.of(context).colorScheme.primary`（`circle1Color` / `circle2Color` 缺省跟随主色），不写死品牌蓝；每个条目用 `MergeSemantics` + `Semantics(selected:)` 向读屏软件报告选中态，并按 `itemKey` 暴露稳定条目 key。**自持实现，不依赖上游包**：选中态完全由 `selectedIndex` 驱动并同步更新，`onSelect` 每次点击恰好一次；父级重建不重置图标状态，进度动画不断档，旋转方向随切换方向，`onSelect` 立即回调 |
| `VeriFeedbackHost` / `VeriFeedbackController` / `VeriFeedbackRequest` / `VeriFeedbackResult` | 根级 Widget / Controller / 模型 | `feedback.dart` | 跨路由应用内轻提示：内容自适应宽高与三行正文（`error` 六行）、四条可见栈、优先级等待队列、2/4/8 秒与常驻、单操作 Future 结果、显式去重、前后台暂停；完整规范见 `feedback-system.md` |
| `SectionTitle` | Widget | `common_widgets.dart` | 区块标题 + 可选 trailing（**文字**）；需要在标题行右侧放自定义控件（如紧凑分段控件）时用 `trailingWidget`，它优先于 `trailing` |
| `EmptyState` | Widget | `common_widgets.dart` | 空状态（插画 + 标题 + 描述 + 可选 `action` 操作入口）；插画是原生绘制（倾斜卡片 + 放大镜，镜片里放调用方的语义 `icon`），随 `colorScheme.primary` 与浅/深主题自动适配，不用外部素材；系统开启「减少动态效果」时停在静态插画，不跑循环动画 |
| `AssetMissingRateNotice` | Widget | `common_widgets_scaffold.dart` | 「缺汇率」提示：受影响账户数 + 缺失币种，点按跳 `CurrencyRatesPage`。裸用（看板资产汇总卡）传 `onTap` 时自带点击区与 8dp 纵向内边距；已放在可点卡片里（资产页缺率卡）不要传，避免嵌套点击区 |
| `HeaderAction` / `HeaderTextAction` / `HeaderInline` / `VeriSectionAction` | Widget | `common_widgets.dart` | 页眉动作族（图标钮/文字钮/宽度约束/填充色小图标钮）；需要弹出操作菜单时使用外部库的 `AnchoredMenuButton` |
| `AnchoredMenuAnchor` / `AnchoredMenuButton` / `AnchoredMenuChoice<T>` / `AnchoredMenuItem` / `AnchoredMenuDivider` | Widget / 菜单模型 | `package:anchored_menu/anchored_menu.dart` | 外部锚点菜单库：图标、标题、副标题、分割线、选中/禁用态、内容自适应宽度、从点击行原位展开的容器变换、完整祖先卡片栈、键盘与 RTL 支持；任意触发器用 `Anchor`，Header 图标入口用 `Button`，2–8 项静态受控单选优先用 `Choice`。应用在 `app_theme.dart` 桥接视觉令牌；完整约定见 [anchored-menu.md](../dev/anchored-menu.md) |
| `SaveHeaderAction` | Widget | `common_widgets.dart` | 全屏编辑页统一保存动作；固定软碟语义的 `Icons.save_outlined` 和本地化 tooltip，支持禁用态 |
| `SortModeHeaderActions` | Widget | `common_widgets.dart` | 管理页显式排序模式的统一 Header 动作；普通态进入排序，排序态提供取消与软碟保存，未改动时禁用保存 |
| `CreditsPage` | 页面 Widget | `credits_page.dart` | 鸣谢名单页（设置 → 关于 → 鸣谢）：头像墙（`CreditsAvatar` + 常显称呼，分组标题只在有分组时渲染）+ 底部赞助入口。名单是包内常量（`credits.dart`），页面不读账目状态，只在打开浏览器失败时记日志并给轻提示；赞助链接统一经 `external_links.dart`（`ExternalLinks.donationUrl`）打开系统浏览器，不要在页面里直接调插件或硬写 URL |

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
| `CreditsAvatar` | Widget | `credits_avatar.dart` | 鸣谢头像：`Jdenticon.toSvg(seed)`（SHA1 → 三层几何图形，算法来自本地 vendor 的 `third_party/jdenticon_dart`）经已有的 `flutter_svg` 渲染，并用 `ClipOval` 圆形裁切；上游图案默认透明底，这里按同一哈希色相补一层淡彩圆底，深浅主题下都保持可读、同一个人永远同一张脸。有 `imageAsset` 时改为圆形裁剪真实图片。渲染点不要再手写图案或圆形裁剪，也不要绕开本组件直接调 `Jdenticon` |

## 族 3 — 账户相关

| 名称 | 类型 | 位置 | 用途 / 关键点 |
|---|---|---|---|
| `showAccountPickerSheet` | Sheet 函数 | `sheets.dart` | 账户选择弹窗（图标+余额+卡号后四位）；**按当前资产视图模式分区**（类型视图=按 `AccountType`，分组视图=按分组+未分组，分区/区内顺序复用 `sortedAssetSections`/`sortedAccountsForAssetSection`，随备份还原）；`noneLabel` 非空时列首加「无账户」→ 返回 **id 为空串哨兵 `Account`**；`allLabel` 非空时列首加「全部」→ 返回 **id 为 `accountPickerAllId` 哨兵 `Account`**（筛选场景）；取消返回 `null` |
| `showAccountIconSheet` | Sheet 函数 | `sheets.dart` + `account_icon_picker.dart` | 账户图标选择；按通用、支付、信用、投资理财、卡组织、跨境与数字账户、银行分组网格浏览，支持中英文名、简称和机构缩写搜索 |
| `confirmDeleteAccount` | Dialog 函数 | `sheets.dart` | 删账户流程（有流水→隐藏/删除三选；级联提示停用周期规则）；返回命令是否完成，由带 Guard 的调用页统一退出 |
| `CardNumberFields` | Widget | `common_widgets.dart` | 完整卡号 + 后四位输入组，含「后四位跟随卡号」开关（信用卡/储蓄卡录入用）；**受控**：`follows`/`onFollowsChanged` 由调用方持久化（`Account.cardLast4Follows`），组件不自行反推 |
| `showCardNumberDialog` | Dialog 函数 | `sheets.dart` | 编辑完整卡号+后四位+跟随开关，返回 `({number, last4, follows})?`（内部用 `CardNumberFields`，后四位以 `cardLast4Of` 归一化） |
| `CreditRepaymentPage` | 页面 Widget | `credit_repayment_page.dart` | 信用卡/信用账户还款页；预填欠款、扣款账户可选/可代还，落一笔转账 |
| `AccountSectionCard` | Widget | `common_widgets.dart` | 资产页账户分区卡（可折叠 + 分区合计）；普通资产页折叠状态由 Controller 按账本/视图模式持久化，设置页可在草稿中调整；同时服务类型、文件夹分组和隐藏账户等分区，拖拽只由 `sectionDragIndex != null` 开启，`sectionDragImmediate` 控制即时/延迟拖拽 |
| `accountBalanceColor` | 纯函数 | `common_widgets.dart` | **账户余额上色**（不计入资产=弱化，负=红，正=青绿） |
| `accountDisplayName` | 纯函数 | `model_lookup.dart` | 按 id 取账户名，空 id→noneLabel（**展示层用它**，避免误回退首个账户） |
| `accountById` | 纯函数 | `model_lookup.dart` | 按 id 取账户（会回退首个，展示层慎用） |

## 族 4 — 分类相关

**分类是账本内数据**（`Category.bookId`）：页面一律用 `controller.categories` / `categoriesForType` 等**当前账本作用域**的读取口，需要读其它账本时用 `categoriesForBook(bookId)`。分类 id 一律随机生成、不承载语义，界面不要解析 id；需要识别「系统分类」「未分类」时用 `Category.isBalanceAdjust` / `isUncategorized`（底层是 `Category.key`，见 `lib/app/models/category_keys.dart`）。**标签同口径**（`Tag.bookId`）：取 `controller.tags`、解析用 `tagById`（只解析当前账本），跨账本用 `tagsForBook(bookId)`；交易与退款引用其它账本的分类/标签会被写入守卫拒绝（`EntryValidationCode.categoryOutOfScope` / `tagOutOfScope`）。

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
| `showNumberPadSheet` | Sheet 函数 | `sheets.dart` | **数字键盘弹窗**（四则算式 + 结果预览）；输入区默认空并显示「请输入金额」占位，初始值为 0 时不预填 `0`；`allowNegative` 时可在首位按 `-` 输入负数（`-` 后按小数点补成 `-0.`），`allowZero` 决定清空后能否确认为 0；数字区支持设置中的标准（7 8 9 / 4 5 6 / 1 2 3）与电话（1 2 3 / 4 5 6 / 7 8 9）布局，默认标准；货币金额传 `currencyCode` 自动遵循 ISO minor unit，汇率输入才显式用 `maxFractionDigits:10`；`maxAmount` 的展示/比较也随币种精度，JPY 自动禁用小数点。触感偏好内部自取。**输金额一律用它**（含新建账户初始余额、新手引导的余额与预算），不要弹系统 TextField、不要裸包 `showModalBottomSheet` |
| `NumberPadSheet` | Widget | `entry_sheets.dart` | 上面 helper 的内部 widget（一般经 `showNumberPadSheet`） |
| `showCurrencyPickerSheet` | Sheet 函数 | `sheets.dart` | 可搜索的离线 ISO 4217 法定货币选择器（代码/中英文名/符号，支持常用/业务优先币种与排除项）；取消返回 `null` |
| `evaluateAmountExpression` / `amountExpressionHasOperator` | 纯函数 | `calc_expression.dart` | 算式求值（不完整返回 null，结果已规整到分）/ 是否含运算符 |
| `CurrencyCatalog` | 静态目录 | `currency_catalog.dart` | 离线 ISO 4217 法定货币定义、常用币种排序与中英文搜索；业务层不得另建货币清单 |
| `normalizeCurrencyAmount` / `formatCurrencyNumber` / `formatMoney` / `formatUserMoney` / `formatSignedUserMoney` / `formatRateValue` / `formatRateValueExact` | 纯函数 | `currency_math.dart` | 按币种 minor unit 规整与格式化；**用户界面一律用 `formatUserMoney` 族**，它自动遵循符号/代码与单币种隐藏偏好；`formatMoney` 的 `display` 默认 `MoneyCodeDisplay.code`（恒带单位），界面金额不得吃这个默认值——AI 工具摘要也已改走 `AiToolContext.currencyDisplay`（见族 10）。`formatRateValue` 是 4/6/8 位自适应的界面文本，CSV 等精确往返必须用 `formatRateValueExact` |
| `textCurrencyUnitHidden` / `optionalCurrencyUnit` | getter / 纯函数 | `currency_math.dart` | **单位文字的闸门读取入口**：闸门是 `amount_format.activeMoneyCodeDisplay`（`none` 即隐藏），单币种账本 + 开启隐藏时返回 `true` / `null`。`displayCurrencyUnit` 不读闸门（它只解析符号/代码样式），只允许在币种选择器、汇率等式这类「界面主题就是币种」的地方直接用；页头/卡片副标题走 `currencyUnitSubtitle`、卡片角标走 `MoneyUnitLabel`（族 7）。**唯一例外**：「我的」→「货币与汇率」入口用 `optionalCurrencyUnit(...) ?? ''` 占位保宫格行高（`profile_pages.dart`）；别处拿到 null 一律整段省略，不要渲染空串 |
| `exchangeRateAt` / `rateToBaseAt` / `convertCurrencyAmount` | 纯函数 | `currency_math.dart` | 按交易日取最近历史汇率（不使用未来值）/ 经本位币交叉换算；缺汇率返回强类型结果 |
| `convertAccountBalancesToBase` / `ConvertedAccountBalances` | 纯函数 / 结果类型 | `currency_math.dart` | 把账户原币余额完整折算到本位币；任一账户缺率时 `completeTotal == null`，并返回缺失币种和受影响账户，禁止展示部分总额 |

## 族 6 — 交易展示

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `TransactionTile` | Widget | `common_widgets.dart` | 单条交易行（图标+分类+时间/备注+金额+账户 pill+待报销/已退款徽标，多选态内建）；副行的跨币种换算**只在两端币种不同时**渲染（同币种两端的换算整条是重复信息），`forceUnit: true` 只留给真正同屏出现第二个币种的换算字段；`moneyDisplay` 仅供非活动账本结果（如 AI 对话）显式覆盖单位口径，普通页面保持为空 |
| `TransactionListCard` | Widget | `common_widgets.dart` | 交易列表卡（多条 `TransactionTile` + 分隔线）；可透传 `moneyDisplay`，AI 等非活动账本结果使用；AI 对话调用时不传 `onEntryTap`，保持只读 |
| `DateGroupHeader` | Widget | `common_widgets.dart` | 日期分组小标题（日期+今天/昨天+当日合计） |
| `groupEntriesByDate` / `relativeDay` | 纯函数 | `common_widgets.dart` | 按日分组、日期倒序 / 相对今天；`DateEntryGroup` 分组模型 |
| `CalendarPreview` | Widget | `common_widgets.dart` | 月历预览（内建月份切换、非当前月份显示「本月」回跳按钮 + 日收支）；必传 `currencyCode`；单币种账本隐藏单位时右下角不再显示轻量单位提示，并**连同前置 6dp 间距整块不构建**（`if (!textCurrencyUnitHidden)`，见维护约定），多币种账本照常显示 |
| `VeriCalendarHeatmap` | Widget | `common_widgets_heatmap.dart` | 月历热力图：12 个月各一张迷你日历，按天着色（值越大越深，无记录为浅底）。固定尺寸格子 + `RepaintBoundary`，格子尺寸按可用宽度一次算出（默认 4 列），领空格不生成 Widget；调用方传 `year` / `dailyValues` / 深浅两色 / 月份文案。配套纯函数 `heatmapDayIndexOfYear` 把日期映射成 `dailyValues` 下标（**必须走 `calendarDaysBetween`**，`difference().inDays` 在夏令时地区会少算一天）。看板「收支热力」卡用它 |
| `EntryTagField` | Widget | `common_widgets.dart` | 记账表单标签行 |
| `AttachmentsEditor` | Widget | `attachments_editor.dart` | 多图片附件横向缩略图、全屏查看和逐张删除；默认自带标题与拍照/相册添加入口，记账页的轻量元数据布局通过 `showHeader:false` / `showAddButton:false` 只复用缩略图条，添加入口由页面标签触发 |
| `TagSelectorSheet` / `pickEntryTags` | Widget / Sheet 函数 | `entry_sheets.dart` / `sheets.dart` | 交易标签多选（即时新建）/ 接 controller 的弹窗封装。**标签同样是账本内数据**（`Tag.bookId`）：列表取 `controller.tags`（当前账本），跨账本数据用 `tagsForBook(bookId)` |
| `RefundSection` / `showRefundSheet` | Widget / Sheet 函数 | `refund_editor.dart` | 支出详情页的受控「退款」草稿区（列退款明细+净支出+添加）/ 添加·编辑退款弹窗（金额截剩余可退、到账账户、已到账开关+到账日期、发起日期、备注、删除）；默认剩余可退金额按原币 minor unit 归一化；Sheet 保存只回传父交易草稿，交易页最终与本体、附件原子保存。待退款清单独立编辑时由调用方在 Sheet 确认后提交 |
| `PendingRefundsPage` | Widget | `pending_refunds_page.dart` | 「待退款」清单页（汇总当前账本所有待到账退款、一键标记已到账核销）；入口在交易列表页头 |

## 族 7 — 表单 / 设置行 / 通用列表行

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `SelectField` | Widget | `common_widgets.dart` | 下拉选择字段；`leading` 可传自定义前置（如账户图标），`suffixIcon` 可替换默认箭头提供清除等局部操作 |
| `SectionLabel` | Widget | `common_widgets.dart` | 分组小标题（分区 `VeriCard` 上方的灰色标签，设置页/账户详情页分模块用） |
| `SettingsRow` | Widget | `common_widgets.dart` | 设置行（图标+标题+trailing 文本+chevron）；`leading` 可传账户图标等自定义前置，`contentColor` 可上色（如危险操作红色） |
| `CompactSwitchRow` | Widget | `common_widgets.dart` | 紧凑开关行（整行可点，不只点开关）；`onChanged:null` 保留原生禁用语义，表示当前平台/状态不可用 |
| `VeriSegmentedControl<T>` | Widget | `common_widgets.dart` | **统一分段控件**（文字标签 + 滑动胶囊指示，基于 `animated_toggle_switch`）。所有「N 选一的横向口径切换」一律用它，不要再手写 Row+InkWell 分段条或裸用 Material `SegmentedButton`。颜色只走设计令牌，调用方仅可通过 `accentOf` 指定选中项的语义强调色；`compact: true` 用于卡片标题行内的小切换；`onChanged: null` 整组禁用；自带 `Semantics`（第三方控件本身无语义）。`keyOf` **只给选中项挂 Key**（`rolling` 会把选中项多渲染一份，全挂会撞 Key）——既有契约见记账页 `entry_type_selected_*`。**不用它**：图标型开关（走 `CompactSwitchRow`）、超过 4 项或需要分区的单选（走 `showOptionSheet` / `AnchoredMenuChoice`）、菜单触发器（走 `FilterPill`）、左右步进器（走 `MonthSwitcher`） |
| `VeriEntryTypeToggle` | Widget | `common_widgets.dart` | **支出 / 收入口径切换**（内部就是 `VeriSegmentedControl<EntryType>`，支出红 / 收入绿，选中项挂 `dimension_toggle_<type>` Key）。看板近 7 日面板、收支热力卡与月/年排行卡共用；**放在卡片标题行时一律 `compact: true`**（与资产汇总、收支热力右上角同档，卡片内不要混用两种大小）。新增「支出/收入切换」一律用它，不要各写一份 |
| `MonthSwitcher` | Widget | `common_widgets.dart` | **期间步进器**：`‹ 标签 ›` 前后翻页，预算总览（按月/周期）、收支统计（按周/月/季/年）与看板（按月/按年）共用。`onPrevious` / `onNext` 传 `null` 表示已到边界，箭头保持可见但禁用；`onLabelTap` 非空时中间标签变成可点入口（带下拉箭头，`labelKey` 给测试定位），用于打开「选择月份 / 选择年份」弹层。新增期间切换一律用它，不要另写 Row+IconButton |
| `DetailInfoRow` | Widget | `common_widgets.dart` | 详情页 label/value 行（可点击带 chevron） |
| `CurrencyAmountField` | Widget | `common_widgets.dart` | 交易/退款/周期编辑器统一的货币金额行；按 ISO minor unit 格式化；`amount == null` 时显示明确缺失态。`forceUnit` **默认 `true` 且不要改**：编辑器允许临时选一个账本里还没有的币种，那一刻闸门还关着但同屏已出现两个币种，单位必须保留。只有两端币种被锁死、不可能出现第二币种的地方（退款表单）才显式传 `false` |
| `MoneyUnitLabel` | Widget | `common_widgets.dart` | 聚合卡片的轻量「单位：¥/CNY」提示（首页预算卡、日历卡、AI 结果卡；走势设置页预览复用同一张卡。首页支出走势卡不显示它，那里渲染的是「周／月／季／年」周期标签）；单币种账本隐藏单位时组件自身返回 `SizedBox.shrink`——**只表示看不见，不能拿它判断单位是否显示**；把容器一起收掉的调用点（日历卡）隐藏时根本不构建，`find.byType` 是 `findsNothing`。要断言隐藏用 `find.textContaining('单位：')` |
| `currencyUnitSubtitle` | 纯函数 | `common_widgets.dart` | **页头 / 卡片副标题拼「单位：x」的唯一入口**：传 `l10n`、上下文前缀（书名/账户类型/日期范围，可空）与币种代码。隐藏单位时返回前缀本身（**不会把书名一起丢掉**），无前缀时返回 `null`——调用方必须据此整段省略副标题，不要渲染只剩分隔符的残句 |
| `SummaryMetric` | Widget | `common_widgets.dart` | **指标块**（label+value+color+detail）。各类统计小块一律用它，勿新造 `_XxxMetric`/`_XxxTile` |
| `FilterPill` | Widget | `common_widgets.dart` | 筛选胶囊（标签+可选图标+chevron）；空间受限时传 `flexibleLabel: true`，标签单行省略且不撑破父级 |
| `ToolEntry` | Widget | `common_widgets.dart` | 工具入口图标块 |

## 族 8 — 对话框 / 弹窗 helper

| 名称 | 类型 | 位置 | 用途 / 返回约定 |
|---|---|---|---|
| `showConfirmDialog` | Dialog 函数 | `common_widgets.dart` | **统一确认框**；`destructive` 红色；返回 `bool`（取消/点外=false）。**禁止内联两按钮 `AlertDialog`** |
| `showInfoDialog` | Dialog 函数 | `common_widgets.dart` | 统一只读说明框（标题、正文、单个“知道了”按钮）；新调用使用具名 `context:` |
| `showUnsavedChangesDialog` / `EditorExitDecision` | Dialog 函数 / 枚举 | `common_widgets.dart` | 未保存修改的“保存 / 不保存 / 取消”三操作对话框；点遮罩或系统返回视为取消 |
| `UnsavedChangesGuard` / `EditorExitController` | Widget / Controller | `common_widgets.dart` | 统一拦截编辑页 Header、系统与预测性返回；仅 `onSave` 成功后放行，未修改时不拦截；显式保存成功后用 `EditorExitController.exit()` 走同一受控退出路径，避免同帧旧 dirty 状态拦截程序化返回 |
| `showTextInputDialog` | Dialog 函数 | `sheets.dart` | **统一文本输入**；`allowEmpty`、`keyboardType`；返回 trim 后 `String?` |
| `showOptionSheet<T>` | Sheet 函数 | `sheets.dart` | 动态、较长或需 `sectionOf` 分区的通用单选底部弹窗；2–8 项静态受控单选优先用 `AnchoredMenuChoice<T>`；返回 `T?` |
| `showVeriModalSheet<T>` | Sheet 函数 | `sheets.dart` | 领域弹窗的统一 chrome 入口；页面需要自定义内容时使用它，不得直接调用 `showModalBottomSheet`；支持拖拽把手、滚动控制、安全区、表面色和泛型返回值 |
| `showLedgerBookEditorSheet` | Sheet 函数 | `sheets.dart` | 新建账本统一表单，同时收集名称与本位币，返回命名 record；取消返回 `null` |
| `confirmLegacyLedgerCurrency` | Sheet/Dialog 流程 | `sheets.dart` | 旧单币种账本的一次性确认/重解释流程：选币、展示影响数量、二次确认，并调用 Controller 原子迁移；取消或失败返回 `false` |
| `showMonthlyBudgetOverrideSheet` | Sheet 函数 | `sheets.dart` | 总预算的单期覆盖管理；按自然月/自定义周期显示“本月/本期”，可设置或调整所选期额度，有覆盖时可清除并恢复默认；内部复用 `showOptionSheet` + `showNumberPadSheet` |
| `showMonthPickerSheet` / `showYearPickerSheet` | 选择器封装 | `sheets.dart` | 看板期间栏的期间选择入口，走 `month_picker_dialog` 的月份 / 年份对话框：**选月份只列 1–12 月**（不再要求选到「日」）、**选年份只列年份**（点完不会掉进月份 / 日期），两者都是选完点「确定」回传，取消返回 `null`。`firstDate` 是下界（账本最早的记账日）、`today` 是上界（默认现在），范围外的月份 / 年份由组件自己禁用；调用方传进来的焦点期间若早于下界会被 `_clampDay` 夹回范围内。**不要**再自绘月份 / 年份网格，也不要改用 `showDatePicker`（它强制选日） |
| `runWithLoadingDialog<T>` | Dialog 函数 | `common_widgets.dart` | 不可关闭加载态，任务完成自动关并返回结果 |
| `confirmCleartextIfRisky` | Dialog 函数 | `sheets.dart` | 明文 http 凭证风险确认 |

## 族 9 — 图表（全部必须支持点击气泡，见 `docs/design/ui-guidelines.md`）

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `InteractiveTrendChart` | Widget | `chart_painters.dart` | 可交互折线图；`values, missingIndexes, xLabels, yLabels, glow, tooltipOf`。平滑曲线 + 渐隐填充；默认不画节点圆点，存在缺率断点或有效点不超过 2 个时显示小圆点，缺率插槽画成断点且不可点选。点击固定显示气泡、再点同一点收起、点左右滑动连续查看，手势自带，不切根页面也不锁页面滚动；自带 `Semantics` 摘要；位于可跳转卡片内时拦截点击 |
| `InteractiveBarChart` | Widget | `chart_painters.dart` | 可交互柱状图；单序列传 `values`（颜色默认取主题主色，语义色传 `color`，如支出红 / 收入青），多序列传 `series`（`List<VeriBarSeries>`，同插槽并排成组，如预算/支出双柱）。命中按插槽取最近一根柱子，整片绘图区可点击或拖动，零值柱也能查看；选中在抬手后保持。**柱子圆角按柱高收窄**（不超过柱高的一半，也不超过 4）：fl_chart 会把正柱的像素高度垫到至少「上下圆角半径之和」，半径写死会让矮柱变成固定高度的短杠，归零的柱子会卡一下再消失 |
| `VeriBarSeries` | 值类 | `chart_painters.dart` | 柱状图的一条序列（`values, color`）；配合 `InteractiveBarChart.series` 使用 |
| `VeriDonutChart` | Widget | `chart_painters.dart` | 环形分段图；`segments, center, ringWidth, selectedIndex, onSelected, semanticsLabel, showPercentTitles, onCenterTap`。点击分段回传索引；中心空区回传 `null`，`onCenterTap` 非空时中心改成可点热区（看板资产汇总用它切换「金额 / 占比」）。`showPercentTitles` 打开环内占比文字，低于 5% 的分段不画 |
| `VeriBudgetRing` | Widget | `chart_painters.dart` | 预算/额度进度环；`value, trackColor, progressColor, center, strokeWidth`。中心内容忽略指针事件 |
| `ChartTooltip` / `ChartTooltipLine` | 值类 | `chart_painters.dart` | 气泡数据模型；所有图表的气泡内容都由它生成 |

适配层硬性规则：页面与卡片不得直接 `import 'package:fl_chart/...'`；不得新增自绘数据图表。
纵轴刻度（`_YAxisLabels`）与横向参考线（`_ChartGridLines`）由适配层共同绘制以保证对齐，
`fl_chart` 自带网格恒为关闭（`_noGridData`）。所有数据图只使用
`InteractiveTrendChart`、`InteractiveBarChart`、`VeriDonutChart` 与 `VeriBudgetRing`。

## 族 10 — 纯计算（领域逻辑，无 Flutter 依赖或仅叶子级）

| 模块 | 位置 | 关键函数 |
|---|---|---|
| 日历日算术 | `calendar_days.dart`（经 `ledger_math.dart` re-export） | `calendarDaysBetween` `addCalendarDays` `monthIndexOf`（月份序号 `年 × 12 + 月`，判断「哪个月更早」用它；直接比 `DateTime` 会带上「日」）——**「相隔几天」「往后推 N 天」一律走前两个，禁止裸用 `difference().inDays` / `add(Duration(days:))`**：那是绝对时间，跨夏令时会差一小时→错一天（CI 在 UTC 恒绿，只在欧美时区暴露） |
| 账目数学 | `ledger_math.dart` | `signedAmount` `accountDeltaForEntry` `entryTouchesAccount` `colorForType` `sumByType` `isZeroAmount` `normalizeAmount`（金额按分规整）；`dateOnly` `cumulativeWeekWindowFor` `monthWindowFor` `weekWindowFor` `quarterWindowFor` `quarterOfMonth` `entriesInWindow` `valuesForTypeInWindow` `dayExpenseTotal` `dayBudgetExpenseTotal` `monthlyExpenseValues` `monthlyNetValuesForType`；`remainingRefundableAmount`（剩余可退，含待到账并按原币 minor unit 归一化）；`DateWindow` |
| 金额/时间格式化 | `ledger_math.dart` | `formatAmount` `formatExpenseAmount` `formatIncomeAmount` `formatSignedAmount` `formatCompactAmount` `formatTime`（**金额文本只走这些**，勿内联手拼）。`formatExpenseAmount` 与 `formatIncomeAmount` 对称、**只给绝对值**；符号只出现在混合类型列表（`formatSignedAmount` / `formatSignedUserMoney`）和「负值即信息」的剩余/超出（`formatAmount`）——不要写 `formatExpenseAmount(x.abs())` |
| 全局金额偏好 | `amount_format.dart` | 顶层量 `currencyFractionStyle`（紧凑/货币标准小数位）、`moneyUnitStyle`（符号后置/代码前置）、`hideUnitInSingleCurrency` 与 `activeBookUsesMultipleCurrencies`；**派生闸门 `activeMoneyCodeDisplay`（`none` 即隐藏单位）是唯一判断依据**，`formatUserMoney` 族与 `textCurrencyUnitHidden`（族 5）都读它，界面不要另写判断条件；Controller 单向同步，界面不直接修改顶层状态（`currencyFractionStyle` 落 KV `verifin.currency_fraction_style.v1`，旧的 `verifin.amount_format.v1` 只做一次性读入） |
| 序列/坐标轴 | `series_math.dart` | `monthAxisLabels` `reportAxisLabels` `isoWeekNumber` `accountBalanceSeries` `accountMonthlyBalanceSeries` `accountMonthlyBalanceSeriesBatch` `monthlyNetAssetSeries` `balanceAxisLabels` `bookkeepingDays` `earliestEntryDate`（最早记账日，期间选择范围的下界） |
| 统计分析纯函数（看板排行卡与 AI 账目查询工具共用） | `report_analysis.dart` | `reportSummary` `reportMonthlyComparison` `formatChangeRatio` `reportCategoryStats` `reportCategoryStatsByOwn` `reportCategoryChildStats` `reportTagStats` `reportTrend`；`ReportRange` `ReportSummary` `ReportCategoryStat` `ReportTagStat` `ReportTrend` |
| 交易保存校验反馈 | `entry_save_feedback.dart` | `entrySaveValidationMessage(l10n, code)`——把 `EntryValidationCode` 映射为本地化文案；`invalidAmounts` 使用通用兜底，scope code 提示重新选择分类/标签；交易编辑、交易详情和信用卡还款三个保存入口共用 |
| 首页指标 | `home_metrics.dart` | `computeHomeMetric` `homeMetricLabel` `homeMetricGroups` `formatHomeMetric` `homeMetricColor`；`HomeMetric` `HomeMetricContext` `HomeTrendConfig` |
| 周期记账 | `recurring.dart` | `advanceRecurring` `dueDatesFor` |
| 信用类账户 | `credit_card.dart` | `nextDueDate` `daysUntilDue` `nextStatementDate` `currentBillingCycle` `usedCredit` `availableCredit` `billingCycleExpense`；卡号 `cardLast4Of`（在 `models.dart`） |
| 记账自动识别 | `category_suggest.dart` | `suggestEntry`（推断类型/分类/标签/备注）；`EntrySuggestion`；`lastUsedAccountIdForCategory`（该分类上次用过的账户，记账页在自动识别开启时用它预选账户） |
| 多币种草稿缩放 | `entry_currency_draft.dart` | `scaleDependentCurrencyAmount`——手工/导入/旧数据或固定周期规则改原币金额时保持既有结算比例，并按目标币种规整 |
| 账目数据校验 | `ledger_data_validation.dart` | `validateLedgerEntries` `LedgerDataValidationIssue`——交易聚合、账单导入和备份恢复共用的三层金额/退款/引用校验 |
| 附件存储与备份管线 | `attachments/attachment_store.dart`、`backup/backup_archive.dart`、`backup/legacy_json_stream.dart`、`backup/backup_service.dart`、`backup/backup_storage_*.dart` | `AttachmentStore`——附件字节**唯一入口**（文件存储 + 导入暂存 + 孤儿回收 + 迁移期按需物化；生产 `FileAttachmentStore`、测试 `InMemoryAttachmentStore`），绘制层禁止自行拼附件路径或直接用 `File`；`packBackupArchiveToFile` / `unpackBackupArchiveFile`（流式 zip，附件 store 模式、逐条落盘）；`rewriteLegacyBackupJson`（旧版内嵌 base64 备份的前向事件流重写）。**恢复入口**：`BackupService.chooseBackupFile()`（自带 SAF 选择器，只回传 `PickedBackupFile{uri,name,size}`，不要用 `file_selector`——它会把整份文件读进内存）、`BackupService.stageBackupFile(uri)`（原生流式复制到缓存，返回 `StagedCacheFile{path,byteSize,owned}`，**只有 `owned` 才允许调用方删除**）、`availableBackupStorageBytes`（Android `StatFs` 解包空间预检）。旧库 `data_url` 的读取与回收在仓储层：`loadAttachmentDataUrl`/`attachmentIdsWithLegacyData`/`clearAttachmentDataUrl`、`hasLegacyAttachmentColumn`、`dropLegacyAttachmentData`（迁移完成后去列 + VACUUM），`loadAttachments` **只读元数据列** |
| AI 对话查询工具 | `ai/ledger_query.dart`、`ai/ai_query_tool.dart`、`ai/ai_tool_schema.dart`、`ai/ai_ledger_snapshot.dart` | 通用交易筛选 `queryLedgerEntries`（`LedgerQuery`，有界查询使用 Top-K）；只读工具协议 `AiQueryTool` + 只含不可变 `AiLedgerSnapshot` 的 `AiToolContext`（另带 `currencyDisplay`，**工具层不读 `amount_format` 全局闸门**）+ `AiToolResult` + `AiResultDisplay`（sealed）+ typed Schema + 注册表 `buildAiQueryTools`。`AiToolSchema` 同时生成原生 Schema 与兼容提示词约束，`validateArguments` 统一归一化并回喂字段错误；交易展示 DTO 自带生成时交易/账户/分类/标签快照（**新增分析工具在此登记，并更新 `ai-tools.md`**） |
| AI Agent 引擎 | `ai/ai_agent_engine.dart`、`ai/ai_native_tool_protocol.dart`、`ai/ai_prompt_tool_protocol.dart` | 双协议只读 Agent 状态机（结构化 `AiAgentMessage` / `AiAgentEvent`）；原生 Tool Calls 与兼容标记协议共用工具执行、轮次、重试和资源边界；原生正文逐事件下发，支持 cancellation token、断流保留和有界响应；`AiAgentCompleted` 携带真实工具调用统计，重试原因使用 typed enum；结构化传输入口为 `aiAgentStream` / `aiAgentComplete` |
| AI 聊天会话控制器 | `ai/ai_chat_session_controller.dart`、`ai/ai_streaming_text_buffer.dart` | 页面生命周期内不可变消息列表、账本选择、发送/停止/清空、50ms 流式正文合并、工具步骤、回答来源和能力更新；不访问 `BuildContext`，不持久化聊天 |
| 设计令牌 | `app_theme.dart` | Material 主交互色从 `Theme.of(context).colorScheme.primary` 读取（默认 Veri Royal、系统动态色或用户自定义色）；`veriRoyal` 仅作为默认回退和无主题上下文的绘制 API 默认值；语义色 `veriBlue` `veriIncome` `veriExpense` `veriWarning` 保持独立；圆角 `veriRadiusSm/Md/Lg/Xl` 与 `veriCardRadius`（卡片圆角，`VeriCard` 与卡内自行裁角的场景共用同一取值，不要在调用点另写数字）；`veriHeaderHeight` `veriPageMaxWidth` |

## 族 11 — AI 对话查询 UI

桌面小组件只提供四个固定模板，**模板与指标 1:1**（没有独立指标词表；桌面文案全部来自原生
`strings.xml`）。词表、投影与刷新管线在 `lib/app/widgets/`，原生渲染在 `VeriFinWidget.kt`：
未配置的组件只显示一行「点击进入配置」（点击直接进 `WidgetConfigurationActivity`），
已配置的按实例绑定的账本与外观渲染。应用内「桌面小组件」页与选择器预览都由同一套 Glance 组合
渲染/导出，不维护第二套手绘样式。完整契约、状态机、预览三层与验收见
[home-widgets.md](../dev/home-widgets.md)。

| 名称 | 类型 | 位置 | 用途 |
|---|---|---|---|
| `AiChatPage` | 页面 Widget | `ai_chat_page.dart` | 全屏 AI 财务 Agent 对话页（消息气泡 + 工具步骤 + 单块 Composer）；只持有输入、焦点和滚动状态，消息/流式/取消由 `AiChatSessionController` 管理。Composer 上方为多行输入、下方为操作行，账本选择位于操作行右侧并直接用 `AnchoredMenuChoice` 展开，默认选中全局活动账本，切换不改变全局账本；发送按钮在流式时原位切换为停止；会话只保留页面内存，离开即清空；清空当前对话位于 Header 设置按钮左侧，无对话时保留同宽占位以保证设置按钮位置固定；已配置时 Header 提供 AI 设置入口，未配置时用 `EmptyState` 插画引导配置；`debugTransport` / `debugCompleteTransport` 供测试注入结构化传输 |
| `AiAgentStepView` | Widget | `ai_agent_step_view.dart` | Agent 工具调用与重试的紧凑可折叠步骤卡；只展示本地化参数与结果摘要，不展示协议 JSON / reasoning / 底层异常 |
| `AiResultView` | Widget | `ai_result_view.dart` | 把 `AiResultDisplay` 渲染成统计卡 / 柱状排行 / 折线趋势 / **只读交易列表** / 表格（新增展示类型在此加一支）；只依赖自包含展示 DTO，不读取 Controller；按消息生成时的本位币与单位口径渲染 |
| `AiProviderPreset` / `aiProviderPresets` / `customAiProviderPreset` / `aiProviderPresetFor` / `aiModelListUrlFor` | 值类 / 常量 / 纯函数 | `lib/app/ai/ai_provider_presets.dart` | 8 个内置 OpenAI-compatible 渠道 + 自定义渠道的稳定注册表；Base URL、Logo、模型列表规则和搜索别名集中维护，渠道 ID 不得复用 |
| `aiProviderDescription` / `aiProviderGroupLabel` / `aiProviderMatchesSearch` / `aiProviderGroupOrder` | 纯函数 / 常量 | `lib/app/ai/ai_provider_presentation.dart` | 渠道分组、说明与跨分组搜索的统一入口；用户可见文案全部经 l10n |
| `AiModelInfo` / `fetchAiModels` / `parseAiModelList` | 值类 / API / 纯函数 | `lib/app/ai/ai_model_catalog.dart` | 只读模型发现：精确 URL 优先、版本段推导、同源重定向、响应体与条数上限、`data[].id` / `models[].slug` 解析、稳定错误映射；空 Key 不发 Authorization |
| `showAiProviderSelectionSheet` | Sheet 函数 | `sheets.dart` + `ai_provider_picker.dart` | 稳定渠道选择入口；分组筛选、搜索、宫格 Logo/说明、选中态与无障碍语义；返回渠道 ID，取消返回 `null` |
| `showAiModelSelectionSheet` | Sheet 函数 | `sheets.dart` + `ai_model_picker.dart` | 稳定模型选择入口；按 `ownedBy` 分组（缺失 `owned_by` 时回退模型 ID 的厂商前缀）、支持搜索和懒列表；返回模型 ID，取消返回 `null` |
| `AiProviderLogo` | Widget | `ai_provider_logo.dart` | 渠道 Logo 统一实底托盘；SVG 走 `SvgPicture.asset`，PNG 原比例显示，未知/自定义回退网关图标，不联网加载 |
| `AiSettingsPage` | 页面 Widget | `ai_settings_page.dart` | AI 渠道与模型设置：预设 Base URL 只读、切换渠道清空 Key/模型、API Key 可选、模型远端获取/手动输入、能力检测；连接参数使用可见描边输入框，工具调用协议以只读输入框作为选择入口，收起时只显示当前选项；所有变更先留草稿再统一保存 |

---

## 维护约定

- `app_theme.dart` 维护内容表面令牌与纯函数 `veriContentSurfaceColor(Brightness)`，供 `VeriCard` 和资产封面共用。排版只有一套已评审参数，不再有构建开关或第二套布局分支。

- 新增可复用件 → 归入对应族、加进本表、放对的文件（通用叶子组件→`common_widgets.dart`，跨路由反馈 Host→`feedback.dart`，弹窗 helper→`sheets.dart`，记账相关 widget→`entry_sheets.dart`，纯计算→对应 `*_math`/`*_tree` 模块）。
- **收起单位要连间距一起收**：调用方为「单位：x」单独加的 `SizedBox`／`Padding` 必须与单位同时消失。只让组件自己渲染为空会把那段间距留在版面里，看起来像空了一块。判断条件用 `textCurrencyUnitHidden`。
- **新增任何显示货币的位置**：先判断它是「金额自带单位」（走 `formatUserMoney` 族，已自动跟随偏好）还是「单位单独占位」（走 `currencyUnitSubtitle` / `MoneyUnitLabel`）。不要直接调 `displayCurrencyUnit` 或裸拼 model 的 `currencyCode`；确需单独占位的币种文字时先判空。
- **改货币显示口径要补双向测试**：单币种 + 开关打开断言该处不出现单位（`find.textContaining('单位：')`），多币种账本断言单位仍在，见 `test/single_currency_unit_test.dart`；只测一侧会把收口做成隐藏过度。
- 同一 UI 片段或逻辑在 **≥2 个文件**出现 → 立即抽共享件，变体用参数表达。
- 删除/重命名可复用件 → 同步改本表与所有调用点。
