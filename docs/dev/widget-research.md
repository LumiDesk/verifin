# 桌面小组件实现记录

状态：已落地（2026-09-22）。小组件使用成熟的 `home_widget` Android/Glance 路线；旧的
自定义 RemoteViews、全局 `WidgetData`、自定义午夜 Receiver、用户设计 Provider 和手工
拼接预览链路已移除。旧系统需要的 `previewImage` 现在由 Glance instrumentation 从同一
套原生组合渲染后导出，作为 Android 11 及以下/旧 Launcher 的回退。

## 已确认行为

- 首次添加直接显示默认组件，不自动打开配置页。
- Android Launcher 负责长按菜单和“重新配置”。Provider XML 使用
  `configuration_optional|reconfigurable`；应用不监听长按。
- 重新配置页由独立 `WidgetConfigurationActivity` 启动 Flutter 的 `configureMain` entrypoint，
  页面上方显示预览，下方先提供账本和主指标两个基础选项。
- 配置按 Android `appWidgetId` 保存到 `home_widget` 的共享存储；删除实例时原生 Receiver
  清理对应配置。
- 今日支出跨天时，Glance 渲染器根据快照日期直接显示 `0`，不显示“打开应用刷新”。

## 当前技术路线

Flutter Controller 只生成投影：每个账本的今日支出、预算剩余、净资产和本期支出，以及账本
列表、当前账本、语言和日期。投影通过 `HomeWidget.saveWidgetData` 写入插件共享存储，随后
用 `HomeWidget.updateWidget` 更新四个固定 Provider。

四个 Provider 都是 `HomeWidgetGlanceWidgetReceiver`，渲染由 Jetpack Glance 完成；桌面进程不
需要启动 Flutter。每个实例从 `GlanceId` 反查 `appWidgetId`，读取自己的账本和主指标配置。
插件的 `HomeWidgetScheduledUpdateReceiver` 负责定时刷新、开机和应用更新后的重排；Flutter
每次投影刷新时重新安排下一次本地午夜，时区变化可在下一次前台刷新时重新计算。

Android 15+ 的系统预览使用 Glance 的 `providePreview` 和 home_widget 的预览更新机制；
Android 12–14 使用新的中性 `previewLayout`，不再依赖设备账目或提交的旧 PNG。应用内页面只
展示模板指南，系统选择器是桌面预览的权威来源。

## 清理结果

已删除旧的 `WidgetData.kt`、`WidgetRefreshReceiver.kt`、`FixedWidgetPreviewRenderer.kt`、
`WidgetChartRenderer.kt`、三个旧 Provider 文件、`UserWidgetProvider.kt`、旧布局、旧用户设计
存储和自定义 MethodChannel 数据协议。`WidgetConfigStore` 不再保存
`appWidgetId`；设备实例配置完全由 home_widget/原生小组件流程管理。

## 验证范围

- `flutter analyze --no-pub` 通过。
- `flutter test --no-pub` 全量通过（1055 项，5 项按现有配置跳过）。
- `:app:compileGithubDebugKotlin` 通过；编译包含 Glance、home_widget 和独立配置 Activity。
- Android instrumentation smoke test 检查四个 Glance Provider 和配置 Activity 可以加载。

## 外部方案依据

- Android 配置 Activity 与 `configuration_optional|reconfigurable`：[官方配置文档](https://developer.android.com/develop/ui/compose/glance/configuration)
- Android 小组件基础生命周期：[官方 App Widgets 文档](https://developer.android.com/develop/ui/views/appwidgets)
- Android 预览规则：[官方预览文档](https://developer.android.com/develop/ui/views/appwidgets/previews)
- home_widget Android Glance 配置：[官方插件文档](https://docs.page/ABausG/home_widget/setup/android)
- home_widget 独立 Flutter 配置 Activity：[配置小组件文档](https://docs.page/ABausG/home_widget/features/configurable-widgets)
- home_widget 版本与配置支持：[更新记录](https://pub.dev/packages/home_widget/changelog)
