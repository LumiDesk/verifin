# 固定小组件与预览一致性

界面渲染只有一个入口：QuickEntryWidgetProvider / StatWidgetProvider 的 `createViews`。
桌面实例经 `updateAppWidget` 使用这些 RemoteViews；应用内 WidgetGalleryPage 经
`renderWidgetPreview` 把相同 RemoteViews 在 Android 中测量和绘制为 PNG，不再另写 Flutter 卡片。

- 快速记账可见卡片高 72dp，加号可见 40dp、触控区域 48dp。
- 预算、资产默认 2×2；趋势默认 4×2。展示宽度受启动器网格影响，内部使用相同 14dp 边距与字体规则。
- 表面复用应用的实色方向；语言和明暗偏好随 Flutter 快照推送。
- `@android:id/background` + `clipToOutline` 明确背景和自己的 16dp 圆角，避免 Launcher 再裁切一层圆角、丢失描边。
- 预算环与金额使用同一个周期；跨期同步使用下一期比例。资产曲线使用净资产历史，缺率时整条不画，绝不替换为支出曲线。
- Android 15+ `setWidgetPreview` 使用同样的 RemoteViews 和中性样本，仅在布局/语言/主题变化时推送；受系统频率限制时使用 PNG fallback。
- 旧版启动器使用 `previewLayout` / `previewImage`，图片必须由原生渲染测试导出，不能用独立绘图脚本拼一个相似样式。样本是 0 金额与 0% 环，不含设备账目。

## 原生验收与导出

使用 Android 开发文档中的工具链与 diagnostic flavor；不安装到正式包。

```powershell
flutter build apk --debug --flavor diagnostic --dart-define=UNIFIED_DESIGN_PREVIEW=true
Push-Location android
./gradlew.bat :app:assembleDiagnosticDebugAndroidTest
Pop-Location
adb -s <device> install -r build/app/outputs/flutter-apk/app-diagnostic-debug.apk
adb -s <device> install -r build/app/outputs/apk/androidTest/diagnostic/debug/app-diagnostic-debug-androidTest.apk
./scripts/export-widget-previews.ps1 -Device <device>
```

FixedWidgetRenderingTest 使用 Android Instrumentation，不增加发布包依赖；测试 Context 把所有
SharedPreferences 重定向到测试文件，不修改现有账目或小组件偏好。导出后重建 APK 才包含新 PNG。

验收必须真实把组件放入启动器桌面，点击加号进入记账，并比较同设备的应用内预览与桌面截图。
只看到选择器或通过 Flutter widget 测试不等于已验证桌面外观。截图与日志保存在被忽略的 build/。
