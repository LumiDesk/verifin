# 桌面小组件

Veri Fin 提供四个固定模板的 Android 桌面小组件：快速记账（`quick_entry`）、预算进度（`budget`）、
收支趋势（`trend`）、净资产（`net_worth`）。渲染走 `home_widget` 插件的 Jetpack Glance Provider，
桌面进程不需要启动 Flutter。

**模板与指标是 1:1 的**：一个模板恰好展示一个指标、一种呈现方式，因此本项目没有独立的指标词表。
桌面上出现的文字（模板名、指标行、状态行）全部来自
`android/app/src/main/res/values*/strings.xml`，Flutter 只推送数字。

| 模板 key | Provider | 选择器/应用内名称 | 桌面指标行 | 尺寸 | 呈现 |
| --- | --- | --- | --- | --- | --- |
| `quick_entry` | `QuickEntryWidgetProvider` | 快速记账 | 今日支出 | 2×1 | 指标行 + 金额 + 记一笔按钮 |
| `budget` | `BudgetWidgetProvider` | 预算进度 | 剩余预算 | 2×2 | 指标行 + 金额 + 使用率环 |
| `trend` | `TrendWidgetProvider` | 收支趋势 | 近 30 日支出 | 4×2 | 指标行 + 金额 + 30 点曲线 |
| `net_worth` | `NetWorthWidgetProvider` | 净资产 | 净资产 | 2×2 | 指标行 + 金额 + 30 点曲线 |

模板名同时存在于 Android `strings.xml`（选择器要用的原生资源）与 `lib/l10n/app_*.arb`
（应用内宫格与说明），由 `test/widget_string_parity_test.dart` 强制一致；该测试同时保证
原生资源里没有死文案。

## 实现结构

- `lib/app/widgets/widget_catalog.dart`：唯一词表（模板 key、Provider 类名、外观枚举、应用内名称）。
- `lib/app/widgets/widget_projection.dart`：纯函数投影与快照编码、快照结构版本 `widgetSnapshotVersion`。
- `lib/app/widgets/widget_refresh_coordinator.dart`：刷新时机（数据变化防抖、启动/回前台立即推送、切后台冲刷）。
- `lib/app/widgets/widget_service.dart`：投影发布管线（失效信号、三道闸门、串行写入与排程）。
- `lib/app/widgets/widget_instance_config.dart`：实例配置与配置会话（读账本列表、保存并校验）。
- `lib/app/native_widget_preview.dart` + `lib/app/platform_bridge_widget.dart`：应用内预览与通道。
- 原生：`VeriFinWidget.kt`（Store、三态、渲染、图形、Provider）、`WidgetPreviewBridge.kt`
  （预览渲染、实例计数、打开应用）、`WidgetConfigurationActivity.kt`、`QuickWidgetContent.kt`
  （快速记账横条的 RemoteViews 叶子，TextView 自动缩放、保留完整金额）。

启用应用锁时，独立 `WidgetConfigurationActivity` 先读取设备 KV 中的锁配置并显示同一套
PIN/图案验证页，验证前不加载账本列表或真实预览；原生窗口同时设置 `FLAG_SECURE`。配置损坏时
按锁定处理，可通过「打开 Veri Fin」回主应用处理。

配置页的独立引擎**初始化必须有界**：偏好读取 5 秒、语言读取 3 秒超时；读不到偏好时显示一个
可关闭的失败页（fail closed，不绕过应用锁展示账本名称或预览），而不是停在空白窗口。这个引擎的
框架错误写入独立键 `verifin.logs.widget_config.v1`（与主引擎的 `verifin.logs.v1` 分开，避免两个
引擎整表覆盖），主引擎下次启动时合并并去重、清掉该键。「恢复应用」时 `MainActivity` 只在
`savedInstanceState == null` 才登记组件快捷记账/分享/磁贴 Intent，避免重放已经消费过的入口。

## 数据契约（home_widget 共享存储，设备本地、不进备份）

| key | 内容 |
| --- | --- |
| `verifin.widget.snapshots` | `{"version":2,"<bookId>":{"date":"yyyy-MM-dd","quick_entry":{"amount":"…"},"budget":{"amount":"…","usage":0.37},"trend":{"amount":"…","points":[…30 点]},"net_worth":{"amount":"…","points":[…30 点]}}}` |
| `verifin.widget.books` | `[{"id","name"}]`，配置页选择账本用 |
| `verifin.widget.locale` | 应用语言，原生按它解析桌面文案（不与系统语言混用） |
| `verifin.widget.config.<appWidgetId>` | 实例配置 `{"bookId":"…","appearance":"system/light/dark"}` |

- `amount` 是 Dart 按**该实例所属账本**的单位口径格式化好的字符串（单币种 + 「隐藏单位」时不含单位）；
  无法计算（缺汇率、未设预算）时为缺失占位符 `—`。
- `points` 固定 30 个日历日、以投影当天收尾；有缺失点时整个 `points` 不下发（不画半张图）。
- Dart 的 `widgetSnapshotVersion` 与 Kotlin 的 `SNAPSHOT_VERSION` 必须成对修改，
  由 `test/widget_catalog_test.dart` 强制一致；形状不匹配时组件退回「打开应用同步数据」而不是渲染缺失值。

## 状态机

| 条件 | 表现 | 点击行为 |
| --- | --- | --- |
| 没有实例配置，或配置里的账本已不在 `verifin.widget.books` | 整卡一行「点击进入配置」，**不显示任何金额** | 打开 `WidgetConfigurationActivity`（`ACTION_APPWIDGET_CONFIGURE` + `EXTRA_APPWIDGET_ID` + 带实例 id 的 data） |
| 已配置，但该账本的快照缺失或版本不符 | 一行「打开应用同步数据」 | 打开应用 |
| 已配置且有快照 | 指标行 + 金额 + 环/曲线 | 整卡打开应用（并切到该实例的账本）；快速记账的 `+` 区域进入快速记账 |

「点击进入配置」的动作必须同时满足两点：带 `ACTION_APPWIDGET_CONFIGURE` 与
`EXTRA_APPWIDGET_ID`（home_widget 的 `initiallyLaunchedFromHomeWidgetConfigure` 按这两个值取实例 id），
以及 data 里带实例 id（`Intent` 的 extras 不参与 `filterEquals`，只有 data 不同才能保证每个实例的
`PendingIntent` 互不覆盖）。已配置组件的点击继续沿用 `verifin://widget/<id>/<route>?bookId=…` 路由。

该自定义 URI **只由原生入口解析**：`MainActivity` 与 `WidgetConfigurationActivity` 都显式设置
`flutter_deeplinking_enabled=false`，避免 Flutter 嵌入层把 `/id/route` 再推给没有命名路由的
Navigator。主应用在隐私同意、新手引导或应用锁期间尚未挂载壳层时，磁贴与组件入口保持
pending，等 Shell 的处理器就绪后再由 Dart 消费；不能“发出即清空”。

## 外观与金额口径

- 外观是**实例级**设置：`system`（默认，跟随设备深色模式）/`light`/`dark`。
- 表面色与设计令牌镜像：浅色 `#FFFFFF` + 描边 `#E5E7EB`，深色 `#1A1F27` + 描边 `#30353D`。
- 金额单位按**实例所属账本**判定：单币种账本 + 「单币种隐藏单位」时省略单位，多币种账本照常显示；
  不再读活动账本的全局闸门。

## 刷新管线

- 失效信号（`VeriFinController.onWidgetDataChanged`）只挂在真正影响投影的落库咽喉点：
  交易、账户、账本、汇率、预算、预算周期，以及语言偏好（桌面文案随语言）。
  **不挂在整个 `notifyListeners()` 上**——改主题、折叠分区这类无关变化不再重算。
  `test/widget_projection_signal_test.dart` 逐条走过这些入口，防止新增写入点漏通知。
- **版本号在 `WidgetRefreshCoordinator.schedule()` 内部推进**（`markWidgetDataChanged()`）。
  闸门①按「同一数据版本」跳过重复推送，所以「排一次防抖」与「推进版本」必须成对发生；
  把它放在 `schedule` 里，接线处（`main.dart` 的数据变化与语言监听）只挂 `schedule` 就不会漏。
  历史上版本推进只写在测试里，导致普通数据变化全部在闸门①被静默丢弃、组件只剩冷启动 /
  回前台 / 切后台三次强制推送（表现为「记完账桌面数字不变，除非再打开一次应用」）；
  `test/widget_refresh_wiring_test.dart` 按正式接法守住这条链路。
- 三道闸门，按代价从低到高：①同一数据版本已推送过 → 直接返回；②桌面上没有任何实例
  （数据变更触发时）→ 连投影都不算；③推送内容与上次完全相同 → 不写共享存储、不刷 Provider、不排闹钟。
- 冷启动与回前台强制推一次，保证用户之后新添加的实例第一次渲染就能读到数据。
- 进入后台（`paused` / `hidden`）时立即取消 250ms 防抖，先刷盘挂起写入，再强制检查一次投影；
  不依赖后台计时器在进程被缓存前恰好执行。即使桌面上暂时没有实例，这一步也准备最新快照，
  供之后新增的组件直接读取；内容指纹不变时仍不重复写入。多次刷新进入同一串行队列，且在
  推送开始时捕获数据版本，避免较旧的 payload 覆盖较新的快照。
- **退出应用前同步冲刷**：根壳层连按返回退出时，`SystemNavigator.pop()` 会 finish Activity、
  Flutter 引擎随之下线，挂在 `hidden` / `paused` 上的异步冲刷会被直接掐断。因此 Shell 在
  关闭前经 `WidgetRefreshScope` 等一次 `WidgetRefreshCoordinator.flush()`（600ms 超时兜底，
  超时仍退出，未完成的发布由下次冷启动补推）。`test/widget_exit_flush_test.dart` 断言
  「冲刷完成前不关闭 Activity」与超时路径。
- 投影是纯函数：一次遍历得到逐日支出与账户余额增量，净资产曲线按「期初余额 + 逐日前缀和」推进，
  复杂度 `O(交易数 + 账户数 × 天数)`。`test/widget_projection_perf_test.dart`
  以 20 账户 × 5000 笔数据约束四模板合计投影时间不超过 40 ms。
- 跨天：Flutter 每次推送用 `HomeWidget.scheduleWidgetUpdates` 重新安排下一次本地午夜，
  插件的 Receiver 负责闹钟、开机与应用更新后的重排；原生渲染按快照日期把「今日支出」直接归零。

## 预览（三层，同一套 Glance 组合）

| 层 | 适用 | 实现 |
| --- | --- | --- |
| 生成预览 | API 35+ | `providePreview`（样例态，不读用户账目）；指纹 = 应用版本 + 模板 + 深浅色 + 语言，随发版自动失效，不再手写版本号 |
| 选择器预览 | API 31–34 | 四个模板各自的 `previewLayout`（`res/layout/widget_picker_preview_<template>.xml`，内容就是预览 PNG），配 `-night` / `-en` 变体 |
| 旧启动器 | API <31 | `previewImage` PNG（同样的变体） |

- 16 张预览 PNG（4 模板 × 浅/深 × 中/英）由**真机渲染器**产出：
  `dart run scripts/widget_previews.dart`（需要一台已授权设备）。改组件视觉后必须重跑，
  PNG 是构建产物，见 [known-limitations.md](known-limitations.md) L10。
- 样例态金额显示 `0`（不虚构用户金额），曲线/环也用零值，因此预览与真机同构、不含任何用户数据。
- 应用内「我的 → 桌面小组件」页通过通道 `renderWidgetPreview` 请求同一套 Glance 组合渲染的像素，
  页面保持只读（添加、长按重新配置、删除都由 Android Launcher 负责）。

## 备份边界

小组件实例配置只存在设备原生共享存储中（按 `appWidgetId`），**不属于备份范围**；导出/导入不会创建或
修改桌面实例。恢复账本后，已有实例在下一次刷新时按自己的设备本地配置读取数据；删除实例时原生
Receiver 清理对应配置。

## 验收

1. API 31：选择器四张预览互不相同、深浅色正确；添加（不配置）→ 桌面显示「点击进入配置」→
   点击进配置页 → 选账本 + 选外观（预览同步切换）→ 保存 → 组件立即显示真实数据。
2. API 35+：生成预览随语言、深浅色与版本变化更新。
3. 强停 Flutter 应用后桌面仍显示快照；跨天后今日支出显示 `0`。
4. 两个实例选择不同账本/不同外观互不串数据；删除实例后配置被清理；配置里的账本被删除时组件回到
   「点击进入配置」。
5. 桌面无实例时改账目：不产生 Provider 刷新与闹钟重排（`test/widget_service_test.dart` 的闸门用例）。
6. 运行 `dart run scripts/widget_previews.dart`：仪器测试全绿并重导出 16 张预览图。
7. 强停后从磁贴记账并立即离开：小组件在离开应用前完成刷新，不依赖下次回前台补推。两条退出路径都要验：
   按 Home（切后台冲刷）与连按返回退出（`SystemNavigator.pop`，退出前同步冲刷）。
8. 冷启动与运行中点击已配置组件、进入未配置组件的配置页、重新配置组件：均正常打开目标页面，
   日志不出现 `onUnknownRoute` / `Null check operator used on a null value`。
