# Veri Fin 统一设计与交互规范

2026-09-10 材质方向调整：磨砂玻璃与「高级材质」（方向高光、导航折射透镜、全局背景渐变）经用户判定为设计败笔，已整体移除。卡片、导航、快捷按钮、菜单与弹层一律使用**不透明实色**表面，页面背景为单一纯色。目标是高效率、干净直接的界面，不再引入任何模糊、折射或光效层。CI 固定 Flutter 3.47.2；正式包仍由 CI 构建，须用户明确授权发版，禁止要求清除应用数据。

本文件是后续页面、组件和材质修改的统一入口。以用户已确认的约定为准；研究稿只解释背景，不能用旧实验方案覆盖这里的布局。更新规则时同步本文件、组件注册表及相关测试。

## 生效范围

正式应用仅以 Android 交付，真机调试使用同一套真实页面、Controller、组件和持久化逻辑。独立 diagnostic applicationId 隔离数据；不再维护 Web 预览。

候选外观仍由 `UNIFIED_DESIGN_PREVIEW` 控制。用户于 2026-09-05 授权发布 minor 版本真机体验：从 v1.16.0 开始，CI 的 APK/AAB 编译门禁均显式开启该参数。无参数开发构建暂保留旧路径用于回归；本地复现手机外观须传同样参数。候选方案的共享排版现覆盖全部页面：公共页面骨架、标题、卡片默认使用同一套紧凑参数，独立记账编辑页同步 16dp 页边距；图表、表单和弹层的业务专用占位仍按内容保留。

`UNIFIED_DESIGN_PREVIEW` **只控制布局密度与排版**，不再控制任何材质。`GLASS_DESIGN_PREVIEW` 已随玻璃一并删除；构建命令里不应再出现该参数。

## 已确认的布局

| 项目 | 约定 |
| --- | --- |
| 普通页面页边距 / Header | 横向 16dp / 高度 56dp |
| 公共内容卡片 | 圆角 16dp；内边距横向 14dp、纵向 **12dp**；显式 padding 优先 |
| 概览 | 主金额 32sp；右侧摘要胶囊靠卡片右边，左侧金额区域 Expanded；保留三个有底色的指标方块 |
| 趋势 / 最近交易 | 趋势高度 96dp；首页显示五笔，可进入完整列表；标题无鼠标 hover 底色，保留点击、焦点与导航 |
| 预算 | **保持原始结构**：左支出、中间剩余及比例、右剩余日均、底部预算总额；中央占位 132dp，圆环画布 118dp |
| 我的 | 工具入口保持四列宫格，长文案和大字号不得溢出；不改成列表 |
| 信息密度 | 通过间距和排版优化，不能删除业务指标、原有方块或改变预算结构 |

页面继续使用 `Scaffold > SafeArea > VeriPage` 与 `VeriHeader` / `PageHeader`。默认页面和固定页脚的头部对齐规则见 [页面骨架](ui-guidelines.md)。颜色、字号和圆角使用主题令牌，不在各页复制样式。语义色（收入 / 支出 / 转账 / 提醒）必须经 `veriSemantic(context, veriX)` 取用，无 `BuildContext` 的纯取色函数用 `veriSemanticFor(brightness, veriX)`：浅色底取加深变体（`veri*OnLight`，对比度 ≥ 4.5:1），深色底取原亮色；不要直接使用 `veriIncome` / `veriExpense` / `veriBlue` / `veriWarning` 渲染。

## 字体层级

字号必须保持语义层级。2026-09-05 真机反馈后撤回统一设计对全局字体的放大，恢复 v1.15.17 基线：displayLarge 38、displayMedium 32、displaySmall 26、titleLarge/Medium/Small 17/14/13、bodyLarge/Medium/Small 14/13/12、labelLarge/Medium/Small 12/11/10sp，页面标题 w800。我的宫格标题仍使用 bodyMedium 13sp / w600，副标题使用 labelSmall 10sp / w400；首页主金额和导航标签保留局部明确尺寸（32/12sp），不能为调整单处而放大所有页面字体。字体家族及系统 textScaler 不变。

## 表面材质（2026-09-10 起）

**没有玻璃。** 磨砂玻璃、方向高光、导航折射透镜与全局背景渐变全部移除，不再提供「高级材质」开关。

| 对象 | 约定 |
| --- | --- |
| 内容卡片 | `veriContentSurfaceColor(brightness)` 实色 + 圆角 + 细描边；深色 `veriPreviewSurfaceDark`，浅色 `veriSurfaceLight` |
| 页面背景 | `scaffoldBackgroundColor` 取画布纯色（`veriPreviewCanvasLight` / `veriPreviewCanvasDark`），不用渐变 |
| 底部导航胶囊 | 不透明表面色 + 单描边 + 阴影；浮动位置、尺寸与指针状态机不变 |
| 快捷记账按钮 | 不透明圆形表面 + `veriRoyal` 加号 |
| 菜单 / 弹层 | 实色面板（`veriSurfaceLight` / `veriSurfaceAltDark`）+ 圆角描边；进出为淡入淡出 + 0.96→1 缩放 |
| 预算圆环 | 保持原常规 SweepGradient 进度环，颜色、比例与无接缝处理不变 |

**禁止**新增 `BackdropFilter`、`ImageFilter.blur`、片元着色器滤镜或整屏渐变背景来「做材质」。需要区分层次时用表面色差、描边和阴影，不靠透明度堆叠。

页面必须各自拥有不透明背景，`colorScheme.surface` 保持不透明（`test/material_stability_test.dart` 强制）。深色输入框默认无白色描边，以柔和填色区分；聚焦用品牌蓝细边，错误用错误色。

菜单进出为 220ms 对称缓入缓出，缩放仅 0.96–1；系统减少动态效果开启时直接切换。

设置分组：外观（主题）、金额显示（两位小数、单位样式、单币种隐藏单位）、通用（语言、触感、应用锁）、记账（记一笔动作、默认账户、自动识别、AI 设置）、关于。各组仍共用页面草稿与保存操作，分组不能变成即时写入。

## 导航与输入

- 四个根目的地使用同一条**停靠底栏**：整宽、不透明、贴底，条目由自有的 `VeriBottomBar` 绘制（抄写自 `bottom_bar_matu` 并修复其动画缺陷，依赖已移除）；首页才显示右下角浮动的记账按钮。选中项用中性强调，不给整条导航染品牌蓝。
- 底栏**只响应点击**，不再有拖动切页与自绘滑块。点击后底栏动画与页面过渡必须**同时起步、同时结束**（`VeriRootNavigation.switchDuration` 与切页时长取同一值）；跨页动画只认最终目的地。
- 底栏表面色一直铺到屏幕最底（含系统导航条背后），不留分块；条目内容用 `SafeArea(minimum: 12, maintainBottomViewPadding: true)` 取 `max(系统留白, 12)` 让开，既不在手势提示线关闭时贴边，也不在键盘弹起时跳动。`Scaffold` 不启用 `extendBody`，列表末项只需少量留白。
- 最近交易等分区标题的 hover、按压 highlight 和 splash 均不绘制横条，保留点击与键盘焦点。动效尊重系统减少动画设置。
- 单选、确认框、输入和底部弹窗复用公共入口；金额使用数字键盘。保存失败要保留草稿并反馈，不能误报成功。短反馈统一用根级 Feedback Host。

## 偏好与开发边界

外观偏好（主题、语言等）走设备 KV，全局不分账本、不进账目备份，恢复备份与初始化账目都保留当前设备选择。偏好改动须由 Controller 完成落盘后，再更新对应的独立 `ValueNotifier`；绘制组件不直接访问 Controller/KV。

账目仍以 Android 本机 SQLite 为权威；本地优先、AI 只生成待确认草稿、Android 原生能力必须真实可用。完整工程和业务不变量仍以 [AGENTS.md](../AGENTS.md) 与 [技术决策](dev/tech-decisions.md) 为准。

## 修改与验收

先查 [组件注册表](dev/components.md)，复用后再扩展。新增可见文案完成中英文 l10n；不为材质调整改动金额、预算或退款口径。按独立功能提交，不积压工作区，不擅自推送或发版。

widget 布局测试使用 **393×852**，补充 360dp、大字号、浅/深色和高对比度测试。实际检查保存/取消/冷启动、导航点击/拖动/取消、菜单、键盘和滚动末项。运行 format、analyze、相关测试与全量测试。Android 手势、系统安全区及真实流畅度仍需真机验证，桌面截图不替代它。

## 详细资料

- [页面、图表与骨架](ui-guidelines.md)
- [公共组件目录](dev/components.md)
- [根导航状态机](dev/liquid-glass-navigation.md)
- [统一设计候选记录](dev/unified-design-preview.md) / [密度研究](dev/design-density-research.md)
- [短反馈系统](dev/feedback-system.md)
- [Android 开发与工具链](dev/android-development.md)
- [架构、数据与备份取舍](dev/tech-decisions.md) / [已接受限制](dev/known-limitations.md)
