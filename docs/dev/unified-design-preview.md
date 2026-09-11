# 统一设计预览参数

统一设计预览使用正式 Android 页面、Controller、SQLite 仓储和共享组件，不创建第二套页面或演示数据层。

## 当前语义

`UNIFIED_DESIGN_PREVIEW` 只控制布局密度与排版：

- 页面横向边距、Header 高度和卡片圆角；
- 卡片内边距、首页指标布局和图表高度；
- 记账页及其他页面的紧凑排版。

材质不由该参数控制。当前所有构建都使用不透明实色表面；玻璃、背景模糊、折射和全局渐变已经移除。

无参数构建保留旧布局路径，用于回归对照。CI 的 Android debug、APK 和 AAB 构建显式开启该参数，保证发布包使用已评审布局。

## 本地 Android 验证

使用独立 diagnostic flavor，避免碰到正式应用的数据：

```powershell
flutter run -d <android-device-id> --flavor diagnostic --dart-define=UNIFIED_DESIGN_PREVIEW=true
```

固定 Flutter 版本为 3.47.2。布局测试使用 393×852，并补充 360dp、浅色/深色和大字号场景；真实 Android 安全区、键盘、触控和 release/R8 行为仍需设备验收。

## 当前验收重点

- 首页预算圆环、收支/剩余日均、概览指标方块和最近交易；
- 资产、看板和“我的”四列宫格的紧凑布局；
- 四页停靠底栏、系统导航区和快速记账按钮；
- 菜单、弹层、记账保存、空态和错误反馈；
- 单币种隐藏单位与多币种金额显示。

完整页面规则见 [统一设计规范](../design-system.md)，通用组件见 [组件目录](components.md)。
