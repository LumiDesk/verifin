# 小组件预览与桌面一致性

VeriFin 使用 `home_widget` 的 Jetpack Glance Provider。Glance 的 `providePreview` 是
Android 15+ 系统选择器的预览入口；Android 12–14 使用各 Provider XML 的中性
`previewLayout`；旧 Launcher 使用由同一套 Glance 组合导出的 `previewImage`。预览不读取
用户账目，避免系统选择器缓存敏感数据。

应用内“桌面小组件”页直接通过 MethodChannel 请求同一套 Glance 组合渲染的像素，不维护
第二套手绘卡片。实际桌面和系统
选择器预览由 Glance/Launcher 渲染，验证必须在 Android 设备或模拟器上完成。

## 验收

1. API 31：选择器预览、首次添加、长按重新配置、配置取消和保存。
2. API 35：生成预览、主题切换、语言切换和预览更新频率限制。
3. 强停 Flutter 应用后桌面仍能显示快照；跨天后今日支出显示 `0`。
4. 两个实例选择不同账本时互不串数据；删除实例后配置被清理。
5. 运行 `WidgetGlanceInstrumentationTest`，确认四个 Provider 和配置 Activity 可以加载。
