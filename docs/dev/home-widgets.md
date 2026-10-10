# 桌面小组件

Veri Fin 提供四个固定模板的 Android 桌面小组件：快速记账（`quickEntry`）、预算进度（`budget`）、收支趋势（`trend`）、净资产（`netWorth`）。渲染走 `home_widget` 插件的 Jetpack Glance Provider，桌面进程不需要启动 Flutter。

## 实现结构

- 四个 Glance Provider（`QuickEntryWidgetProvider` / `BudgetWidgetProvider` / `TrendWidgetProvider` / `NetWorthWidgetProvider`）都是 `HomeWidgetGlanceWidgetReceiver`，共用同一个原生配置 Activity。
- Flutter 侧只发布投影：`lib/app/home_widget_service.dart` 的 `pushWidgetData` 为每个账本生成一份快照（`date`、`currency` 与四个指标），经 `HomeWidget.saveWidgetData` 写入插件共享存储，再用 `HomeWidget.updateWidget` 刷新四个 Provider。
- 指标计算集中在 `lib/app/widget_presentation.dart` 的 `buildWidgetPresentation`（纯函数，输入 `WidgetLedgerSnapshot`）。指标词表（`WidgetTemplate` / `WidgetMetric` / `WidgetChartMetric` / `WidgetDateRange`）定义在 `lib/app/widget_config.dart`。
- 每个桌面实例的配置（账本 `bookId` + 主指标 `metric`）按 Android `appWidgetId` 保存在 home_widget 共享存储；配置页保存经 `WidgetConfigurationSession.save`，只接受账本列表内的账本与基础指标集合内的指标。
- 应用内「桌面小组件」页通过 MethodChannel `renderWidgetPreview` 请求同一套 Glance 组合渲染的像素，不维护第二套手绘卡片。

## 交互行为

- 首次添加到桌面直接使用默认配置，不自动打开配置页；Provider XML 使用 `configuration_optional|reconfigurable`，长按菜单与「重新配置」由 Android Launcher 提供，应用不监听长按。
- 重新配置页由独立 `WidgetConfigurationActivity` 启动 Flutter 的 `configureMain` entrypoint：上方显示当前实例的原生预览，下方选择账本与主指标。
- 快速记账横条的数值/标签区域只打开应用，加号区域才进入快速记账；内容使用原生 `TextView` 自动缩放并保持金额完整，不用省略号。
- 其余模板整卡点击通过 `widgetAction` 打开应用。

## 刷新与自愈

- Flutter 每次投影刷新时用 `HomeWidget.scheduleWidgetUpdates` 重新安排下一次本地午夜；插件的 `HomeWidgetScheduledUpdateReceiver` 负责闹钟、开机和应用更新后的重排，时区变化在下一次前台刷新时重新计算。
- Glance 渲染器按快照日期自愈：今日支出在跨天后直接渲染为 `0`，不显示“打开应用刷新”。
- 账目、预算、汇率、账户和账本变化后由 Flutter 重新发布投影并刷新所有 Provider。

## 预览

- Android 15+ 的系统选择器预览使用 Glance 的 `providePreview` 与 home_widget 的预览更新机制。
- Android 12–14 使用各 Provider XML 的中性 `previewLayout`；旧 Launcher 使用由同一套 Glance 组合导出的 `previewImage`。
- 预览不读取用户账目，避免系统选择器缓存敏感数据；桌面与系统选择器预览的权威渲染结果只能在 Android 设备或模拟器上验证。

## 备份边界

小组件实例配置只存在设备原生共享存储中（按 `appWidgetId`），**不属于备份范围**；导出/导入不会创建或修改桌面实例。恢复账本后，已有实例在下一次刷新时按自己的设备本地配置读取数据；删除实例时原生 Receiver 清理对应配置。

## 验收

1. API 31：选择器预览、首次添加、长按重新配置、配置取消与保存。
2. API 35：生成预览、主题切换、语言切换和预览更新。
3. 强停 Flutter 应用后桌面仍能显示快照；跨天后今日支出显示 `0`。
4. 两个实例选择不同账本时互不串数据；删除实例后配置被清理。
5. 运行 `WidgetGlanceInstrumentationTest`，确认四个 Provider 和配置 Activity 可以加载。
