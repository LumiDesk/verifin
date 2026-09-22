# 桌面小组件实现研究

状态：研究记录（2026-09-22），本文件只记录现状、外部资料和待决策方案，不改变运行时代码。

## 已确认的产品要求（2026-09-22）

- 首次添加小组件后直接显示默认组件，不自动打开配置页。
- 用户长按桌面小组件后使用 Android 启动器提供的“编辑 / 重新配置”入口；应用负责提供
  配置 Activity 和保存/刷新逻辑，不自行模拟长按菜单。
- 首版只做基础配置，先收窄为账本、一个主指标和点击动作；背景、图表、辅助指标、金额
  隐藏等延后。
- 今日支出跨天后直接显示 `0`，不显示“打开应用刷新”或其他过期状态。
- 评估方案时优先采用 Android 官方或成熟库的已验证模式；现有代码只作为迁移材料，不能
  因为已经存在就默认保留。

## 当前源码事实

### 实际接入的是固定模板 Provider

正式 `AndroidManifest.xml` 只注册四个 Provider：`QuickEntryWidgetProvider`、
`BudgetWidgetProvider`、`NetWorthWidgetProvider` 和 `TrendWidgetProvider`。四个 Provider
分别引用 `quick_entry_widget_info.xml`、`budget_widget_info.xml`、
`net_worth_widget_info.xml`、`trend_widget_info.xml`。

仓库里还有 `UserWidgetProvider`、`UserWidgetConfigureActivity`、`user_widget_info.xml`、
`WidgetInstanceConfig` 和用户设计/桌面绑定模型。这套实现没有接入正式 Manifest：

- `user_widget_info.xml` 才声明了 `android:configure=".UserWidgetConfigureActivity"` 和
  `android:widgetFeatures="reconfigurable"`；
- 正式 Manifest 没有注册 `UserWidgetProvider` 或 `UserWidgetConfigureActivity`；
- `test/android_manifest_policy_test.dart` 明确要求它们不能注册；
- 四个正式 Provider 的 XML 都没有 `android:configure` 或 `reconfigurable`。

所以当前用户从系统小组件选择器添加四个固定模板时，不会进入自定义页面，也没有
TickTick 类“长按后重新配置”的系统入口。目标要求与 Android 官方的
`configuration_optional|reconfigurable` 模式一致：首次添加跳过配置，长按后由启动器
提供重新配置入口。Android 官方明确说明，`reconfigurable` 会让用户在已放置的小组件上
重新打开配置 Activity，而 `configuration_optional` 可以跳过首次配置。

### 每实例配置目前不会影响固定模板渲染

`WidgetData` 已经有 `readInstanceConfig()`、`writeInstanceConfig()` 和按 `appWidgetId`
清理绑定的代码；`MainActivity` 也有 `updateWidgetConfig` 通道。但实际的
`QuickEntryWidgetProvider.createViews()` 与 `StatWidgetProvider.createViews()` 都直接
构造 `WidgetData.InstanceConfig()`，没有读取 `readInstanceConfig(context, widgetId)`。

这意味着即使通过其他路径写入了实例配置，固定模板仍会读取全局快照和默认值，账本、
主指标、背景、隐藏金额、图表范围和点击动作不会真正按实例生效。配置数据模型、Dart
配置存储和 Kotlin Provider 当前是两套尚未闭合的链路。

`docs/dev/widget-overhaul-plan.md` 把“每个桌面实例拥有配置、统一配置 Activity”写成了
当前产品模型，但源码和 Manifest 尚未达到该状态；按仓库的权威顺序，本记录以源码、测试
和 Manifest 为当前事实，把 overhaul 文档中的内容视为目标方案。

### 预览有三条链路，语义并不完全相同

1. Android 12–14 使用 `previewLayout`，当前四个固定模板的 preview layout 实际是一个
   `ImageView`，显示仓库中的静态 PNG；同时提供 `previewImage` 作为旧系统回退。
2. Android 15+ 由 `FixedWidgetPreviewRenderer.publishPickerPreviews()` 调用
   `AppWidgetManager.setWidgetPreview()`，使用 Provider 的 `RemoteViews` 和样本值。
   目前只在 Flutter 调用 `updateWidgetData` 时推送，签名只包含主题和语言。
3. 应用内“桌面小组件”页面通过 MethodChannel 请求 Android 原生 Provider 渲染 PNG，
   这是实际 RemoteViews 的截图，和桌面渲染共用 Provider 入口。

这比单独维护一套 Flutter 卡片可靠，但仍有几个边界：静态 preview PNG 是提交到 APK 的
构建产物，修改布局后必须重新导出；Android 15 生成预览依赖应用至少启动并成功推送过
一次；布局版本没有进入 preview 签名，升级布局但主题/语言不变时可能继续复用旧的系统
生成预览；应用内预览传入的宽高也不等于所有启动器真实格子宽高。

### 跨天刷新已有自愈，但只覆盖全局快照

Flutter 在启动、回前台、账目投影变化后调用 `pushWidgetData()`，把全局金额、预算、
趋势、主题、语言和跨天锚点写入 `verifin_widget` SharedPreferences。原生侧在下一个
本地午夜安排 `AlarmManager.RTC_WAKEUP + setAndAllowWhileIdle`，收到广播后刷新四个
Provider，并在开机或应用更新时重新排程。

当前策略的优点是跨天不必等待 Flutter 冷启动；预算组件能根据周期截止日读取下一期或
整期备用值。今日支出在跨天后当前实际显示的是 `todayStaleAmount`（默认 `—`）和
“打开应用刷新”，而不是归零；Dart/原生都写入了 `today_zero`，但 `todayForToday()`
没有读取这个键，属于“设计了归零值但实现未使用”的明确断点。按已确认要求，跨天逻辑
应直接使用已写入的零值，并把测试断言改成跨天显示 `0`。需要关注的风险是：

- AlarmManager 仍可能因厂商电量策略延迟，`setAndAllowWhileIdle` 不是“绝对准点”；
- 只处理 `BOOT_COMPLETED` / `MY_PACKAGE_REPLACED`，没有看到时区、手动改日期或时区切换
  后的重新排程广播；
- `updatePeriodMillis` 在预算/快速记账上设为 30 分钟，但 Android 对该字段有不低于
  30 分钟的系统限制，不能把它当作分钟级刷新保证；资产/趋势设为 0，只依赖应用推送和
  午夜闹钟；
- Provider 的午夜刷新会重绘当前已放置实例，但它读取的是全局快照。未来接通实例配置
  后，必须确保每个 `appWidgetId` 用自己的账本和筛选快照，而不能继续共用一个当前账本；
- `WidgetData.refresh()` 通过广播触发 Provider，刷新本身是同步的 RemoteViews 更新；如果
  后续加入文件图片或较重计算，不能在 BroadcastReceiver 主线程里做长耗时工作。

## Android 官方方案与 Flutter 生态

### 官方 Views / RemoteViews

Android 官方的传统方案由三个部分组成：`AppWidgetProviderInfo` XML、
`AppWidgetProvider` 和 `RemoteViews` 布局。需要用户设置时使用配置 Activity，并通过
`EXTRA_APPWIDGET_ID` 保存每一个桌面实例的配置。Android 12 起可用
`widgetFeatures="reconfigurable"` 允许用户在已放置的小组件上再次打开配置；如希望首次
添加直接使用默认值，可组合 `configuration_optional|reconfigurable`。

对于预览，官方建议 Android 15+ 使用 `setWidgetPreview` 的生成预览，Android 12–14
使用可缩放 `previewLayout`，Android 11 及更低使用 `previewImage` 回退，并建议同时提供
`previewLayout` 和 `previewImage`。预览最好复用实际布局和中性样本数据。

对于刷新，`updatePeriodMillis` 不会以少于 30 分钟的频率交付；需要其他频率时应使用
用户操作、广播、AlarmManager 或 WorkManager。官方也提醒 BroadcastReceiver 默认约有
10 秒响应窗口，重计算或异步 I/O 应改用 `goAsync` / WorkManager。

### `home_widget` / `home_widget` 示例

`home_widget` 是 Flutter 与 Android/iOS 小组件之间的数据和点击桥接库，示例使用
WorkManager 做后台更新，也支持把 Flutter Widget 渲染成图片。它在 0.9.1 增加了 Android
可配置小组件支持，API 也提供了按实例查询和结束配置流程的接口；这是值得做一个最小
Spike 的成熟候选，而不是凭空复制一套桥接代码。但它仍不会替代 Android 的 Provider XML、
配置 Activity、RemoteViews/Glance 约束，也不会自动决定首屏跳过配置、长按重新配置、跨天
归零等产品行为。

`app_widget` 等 Flutter 库尝试把 Provider、更新和配置更多地包到 Dart API 中，但仍依赖
Android 原生小组件生命周期；需要逐项核对 Android 版本、R8、配置 Activity 和预览支持，
不能把库的示例当作本项目的交付设计。

### Jetpack Glance

Glance 是 Android 官方的 Compose 风格小组件层，仍然生成 App Widget/RemoteViews，能
简化 Kotlin 布局与配置代码，但会引入新的 Android UI 技术栈。它不解决 Flutter Controller
在进程外不可用的问题：桌面刷新仍需要一个原生可读的数据快照或后台同步协议。当前项目
已经有原生 RemoteViews、原生测试和预览导出链路，迁移 Glance 应视为独立重构，不应作为
修复跨天或配置失效的前置条件。

## TickTick 类“添加后配置”的可行模型

这是 Android 平台原生能力，不需要特殊组件库：

1. 每个模板 Provider 的 `appwidget-provider` 声明同一个或按模板分流的配置 Activity；
2. Activity 读取 `EXTRA_APPWIDGET_ID`，显示账本、指标、日期范围、背景、金额隐私和点击
   动作等选项；
3. 保存时按 `appWidgetId` 写入设备原生存储，调用对应 Provider 更新该实例，并返回带有
   `EXTRA_APPWIDGET_ID` 的 `RESULT_OK`；取消保持 `RESULT_CANCELED`；
4. Android 12+ 加 `reconfigurable`，桌面长按后由系统提供“重新配置”；
5. Provider 每次渲染都按 `appWidgetId` 读取配置；删除实例时清理配置；必要时处理尺寸
   变化和不同启动器的 options。

当前源码已经有配置 Activity 的雏形，但它绑定在未注册的 `user_widget_info.xml`，且正式
四个 Provider 不读实例配置。建议先统一产品模型：是“四个固定模板，每个实例可配置”，
还是“一个通用可配置 Provider + 模板配置”。前者更符合现有选择器和测试，迁移范围也更
可控；后者能提供更自由的 TickTick 式自定义，但会扩大 Provider、预览、尺寸和旧配置兼容
的复杂度。

### “编辑”由谁触发

长按手势、菜单和“重新配置”按钮由 Launcher/Android 系统处理，应用不需要监听长按或
自己画编辑菜单。应用只需要在 Provider XML 声明配置 Activity，并在 Android 12+ 声明
`reconfigurable`；系统随后会用对应的 `appWidgetId` 启动配置 Activity。Android 11 及更低
版本会忽略这个重新配置能力，若要覆盖这些系统仍需提供小组件点击进入应用设置的后备路径。

用户希望的“上方预览、下方配置项”可以落在这个配置 Activity 内：上方使用同一个
RemoteViews/中性数据渲染预览，下方先放基础的账本、主指标和点击动作。配置 Activity
保存后按 `appWidgetId` 写入并刷新实例，返回带 ID 的 `RESULT_OK`；取消则保持
`RESULT_CANCELED`。现有 `UserWidgetConfigureActivity` 用原生 `ScrollView` 拼出了一版
控件，但未注册、文案未走 l10n、字段超出首版范围，不能直接视为可交付实现。

## 建议的后续阶段（待讨论）

### 阶段 A：先修复事实链路

- 明确四个固定模板是否正式支持实例配置；若支持，注册配置 Activity 和
  `reconfigurable`，并让 Provider 真正读取 `readInstanceConfig(widgetId)`。
- 删除或隔离未接入的用户设计 Provider 代码，避免两套模型继续漂移；Dart 的
  `WidgetConfigStore` 与原生 `WidgetData` 选一个权威实例配置格式。
- 把配置保存、取消、删除、冷启动、多个实例不同账本和长按重新配置加入 Android
  instrumentation / widget contract 测试。

### 阶段 B：收口预览

- 保留“实际 Provider 生成 PNG”的思路，增加布局/资源版本到生成预览签名；在应用启动、
  主题/语言变化、布局版本变化时按 Android 15 频率限制推送。
- `previewLayout` 尽量直接引用中性样本的实际布局；如果动态列表或尺寸无法直接复用，
  明确记录为什么使用静态 fallback，并让导出脚本成为可重复的构建步骤。
- 以真实 API 31/35 启动器验证选择器预览、添加后的首屏和重新配置后的桌面截图，不把
  Flutter 应用内预览当作原生验收替代品。

### 阶段 C：收口时间与数据刷新

- 保留“Flutter 产生账本快照、原生 Provider 只渲染”的边界；每个实例快照按账本和筛选
  维度保存，并在一次写入中更新数据版本/生成时间。
- 午夜刷新继续作为低频边界触发，同时监听开机、应用更新、时区/时间变化并幂等重排；
  展示逻辑保留日期锚点自愈，即使闹钟延迟也不显示已知错误的“今日/本期”数值。
- 对需要分钟级或网络数据的功能单独评估 WorkManager；不要依赖 `updatePeriodMillis`
  承诺精确时间。

### 阶段 D：再评估技术栈

基于目前的产品要求，不建议直接把“已经有 RemoteViews”当成继续使用的理由，也不建议一
开始就全量迁移 Glance。先做两个可验证的对照 Spike：

1. **官方原生 RemoteViews**：四个模板共用一个配置 Activity，使用
   `configuration_optional|reconfigurable`，每实例只保存账本、主指标和点击动作。
2. **`home_widget` 最小集成**：只验证同样的配置 Activity、按实例更新、Android 15 预览、
   冷启动点击和后台/跨天刷新，不先迁移全部 UI。

两者用同一份验收表比较：首次添加不弹配置、长按能重新配置、两个实例互不串账本、配置页
顶部预览与桌面一致、跨天显示 `0`、Android 12/15 预览正确、R8 构建通过、无 Flutter
进程时也能渲染。若 `home_widget` 只减少桥接代码而不能减少这些原生工作，就保留官方
RemoteViews；如果它能稳定覆盖实例配置和刷新生命周期，再考虑采用它。

## 待和产品一起确认的问题

1. 四个固定模板是否都采用同一个基础配置页，只根据模板改变默认主指标？
2. 基础配置中的点击动作是否只保留“打开应用”和“快速记账”两个选项？
3. 两个 Spike 是否都使用中性预览样本，避免系统选择器缓存真实账目？

## 外部资料

- Android 基础小组件：[developer.android.com/develop/ui/views/appwidgets](https://developer.android.com/develop/ui/views/appwidgets)
- Android 配置 Activity：[Enable users to configure app widgets](https://developer.android.com/develop/ui/views/appwidgets/configuration)
- Android 预览：[Add previews to your widget picker](https://developer.android.com/develop/ui/views/appwidgets/previews)
- Android 更新策略：[Create an advanced widget](https://developer.android.com/develop/ui/views/appwidgets/advanced)
- Android 12+ 配置 / Glance：[Enable users to configure app widgets](https://developer.android.com/develop/ui/compose/glance/configuration)
- Flutter `home_widget` 示例：[pub.dev/packages/home_widget/example](https://pub.dev/packages/home_widget/example)
- Flutter `home_widget` API：[HomeWidget class API](https://pub.dev/documentation/home_widget/latest/home_widget/HomeWidget-class.html)
