# 第三方 UI 组件库引入评估与改造计划

状态：**方向已定，待细化执行**（本文只做评估与方案；§0 的布局修复已落地，其余未改动界面代码）
分支：`docs/ui-library-adoption-plan`
评估日期：2026-09-10（用户决策更新：2026-09-10）
工具链：Flutter 3.47.2 / Dart 3.13.2（与 CI 固定版本一致），仅 Android

## 0. 用户决策（2026-09-10）

用户已就本文的关键问题给出明确方向，以下为**已定结论**，后续工作按此执行：

| # | 决策 | 含义 |
| --- | --- | --- |
| A | **玻璃 / 高级材质 / 背景光效是设计败笔，应移除** | 不是"换个更好的玻璃库"，而是**删掉玻璃方向本身**。至少包含：基础磨砂（内容卡片、导航胶囊、快捷按钮、菜单、弹层）、高级材质方向光、导航折射透镜 Shader、全局背景渐变。目标是"高效率的软件"。 |
| B | **不需要考虑无障碍** | 项目不把无障碍作为约束。此前未获用户确认的无障碍改动可以删除或保留，由实现方决定，不作为取舍依据。这条**直接解除**了 Syncfusion 的主要否决理由。 |
| C | **图表库由实现方决策** | 用户授权直接定选型。 |
| D | **可以用组件库优化交互，但不引入高级材质** | 组件库仍可引入（§6 的 `animated_toggle_switch`、§8 的图表库、§10 的 `toastification`），但一律走不透明、扁平、直接的表面。 |

**仍未澄清**：第 4 条诉求中"看板文字位置"的真实含义——用户澄清**不是卡片顺序，而是文字位置**，见 §0.1。

### 0.1 已修复：看板分区标题右侧文字错位

用户澄清：看板各面板标题右侧的数值/文字**没有靠右，停在了卡片中间**。这不是卡片顺序问题（§7 原先判断的 C1 不是用户所指），而是**共享组件 `SectionTitle` 的布局缺陷**。

**根因（已用测试定位）**：`SectionTitle`（`lib/app/common_widgets_scaffold.dart:373`）原实现为 `Row[Expanded(title), Flexible(trailing)]`。两个问题叠加：

1. 调用方的 `Column` 多为 `CrossAxisAlignment.start`，`Row` 拿到的是**松约束**，只收缩到子项自然宽度——`spaceBetween` 一类的主轴对齐也就无处可推。
2. `Flexible` 只给子项**最大宽度**，`Text` 会缩回自己的自然宽度；`textAlign: TextAlign.end` 于是在那个窄盒子内部生效，右边缘并没有落到内容区右侧。

实测：`SectionTitle` 自身宽度 400dp 时，trailing 的右边缘停在 374dp，**差 26dp**；在看板真实卡片里差 **44dp**——正是用户看到的"跑到了中间"。

**修复**：标题按自然宽度靠左，trailing 使用 `Flexible(fit: FlexFit.tight)` **占满剩余槽位**，再靠 `textAlign: end` 贴到槽位右端；外层用 `SizedBox(width: double.infinity)` 保证在松约束下也撑满。

**影响面**：`SectionTitle` 共 16 个调用点，其中 9 处带 `trailing`（看板 5 处、统计分析页 3 处、账户报表等）。**回归测试** `test/reports_section_title_test.dart` 覆盖看板与统计分析页两个页面。

**验证**：`flutter analyze` 无问题；全量 `flutter test` **988 通过 / 16 跳过**。

### 0.2 决策变更带来的方案调整

| 原方案 | 调整后 |
| --- | --- |
| §4 玻璃：三选一（调参 / 换磨砂库 / 换折射库） | **全部作废**——改为 §15 的**玻璃移除计划** |
| §8 图表：因无障碍门禁否决 Syncfusion，选 fl_chart | 无障碍不再是约束（决策 B），两者都可行；仍**建议 `fl_chart`**（MIT、零新增依赖、体积小），除非明确需要 Syncfusion 特有图表类型 |
| §9 导航：保留磨砂、调整 FAB 位置 | 磨砂**移除**，导航改**不透明胶囊**；指针状态机、位置与尺寸、Key 契约**全部保留** |
| §10 短反馈：只换外观 | 维持"适配层"方案，但目标外观为**不透明卡片**，不用 `toastification` 的 `applyBlurEffect` |


## 1. 背景与目标

用户提出 7 项界面改进诉求，核心是对现有自研 UI 层不满意，希望评估能否改用成熟第三方组件库，同时修复近期引入的布局回归。

本文回答三件事：

1. 每个候选库**能不能用**——不是"有没有这个包"，而是"在这个项目的约束下能不能真的落地"。
2. 每个库用上之后，**用户能看到什么变化**。
3. 哪些地方**不能照搬**，需要保留自研或自建包装层，以及原因。

评估依据：pub.dev 官方元数据与源码、`flutter pub add --dry-run` 在本项目的真实求解结果、上游仓库 issue/PR 现状、以及本仓库当前实现的完整审计。

## 2. 结论速览

| # | 诉求 | 候选库 | 落地可行 | 结论 |
| --- | --- | --- | --- | --- |
| 1 | 替换自研玻璃材质 | `liquid_glass_renderer` | ❌ 作废 | 该库在本项目组合上会渲染镜像内容；但**用户已决定移除玻璃方向本身**，故本诉求作废，改见 §15 移除计划。 |
| 2 | 替换入门引导页 | `introduction_screen` | ⚠️ 不建议 | 能用，但省不下多少代码，且要为一屏引导新引入 5 个平台插件依赖；引导页真正的复杂度在业务逻辑，库覆盖不到。建议改为自研重构。 |
| 3 | 统一开关/切换条 | `animated_toggle_switch` | ✅ 可行（需自建包装层） | 动画质量高、可完全贴合设计令牌、零第三方依赖、160/160 分。库本身无语义/键盘支持，需包一层（决策 B 后此项不再是硬约束）。 |
| 4 | 修复看板文字错位 | — | ✅ **已修复** | 真实原因是共享组件 `SectionTitle` 的布局缺陷，不是卡片顺序。已修复并加回归测试。详见 §0.1。 |
| 5 | 替换自研图表 | `fl_chart` | ✅ 可行（已定选型） | 折线/柱状/饼图可替换；**预算圆环必须保持自研**。选型由实现方定为 `fl_chart`。详见 §8。 |
| 5b | 时间图表交互 | `time_chart` | ❌ 完全不可用 | 依赖冲突导致**根本无法安装**；且它没有本项目需要的任何交互 API。 |
| 6 | 替换底部导航 | `bottom_bar_matu` | ❌ 不建议 | 声明只支持 Dart 2（`<3.0.0`）；渲染的是贴边不透明条，无法做浮动形态。**导航保留自研**，只做去玻璃化。 |
| 7 | 替换自研通知 | `toastification` | ✅ 可行（需适配层） | 能替换外观与基础行为，但优先级队列、去重、后台暂停需保留在适配层。外观改为不透明卡片。 |
| **8** | **移除玻璃 / 高级材质 / 背景光效** | — | ✅ **已定为方向** | 用户的最终判断：玻璃是设计败笔。详见 §15 移除计划。 |

一句话总结：**7 个候选库中，2 个可用（3、7），1 个已定（5 选 fl_chart），3 个不建议/不可用（1、2、5b、6）；但真正的重头是第 8 项——移除玻璃，这比引入任何组件库都更接近用户想要的"高效率软件"。**


## 3. 项目当前 UI 层体量（替换的基数）

用于判断"换库到底省不省事"：

| 子系统 | 实现 | 代码量 | 测试 |
| --- | --- | --- | --- |
| 玻璃材质 | `glass_material.dart`(135) + `glass_lighting.dart`(175) + `navigation_glass_lens.dart`(216) + `shaders/navigation_live_lens.frag` | ≈530 行 + 1 个 shader | 6 个专项测试文件 |
| 底部导航 + FAB | `root_navigation.dart` | 726 行（含指针状态机） | `navigation_lens_test` 等 |
| 短反馈 | `feedback.dart` | 892 行 | `feedback_test` |
| 图表 | `chart_painters.dart`(814) + `budget_trend_chart.dart`(363) + 看板内 3 个 painter(≈350) | ≈1530 行 | `chart_semantics_test`、`budget_test`、`budget_ring_test` |
| 引导页 | `onboarding_page.dart` | 394 行 | `onboarding_test` |
| 开关/切换条 | 散落 15+ 处 | — | 分散在各页测试 |

## 4. 诉求 1：玻璃材质 —— `liquid_glass_renderer`

### 4.1 包本身

真实存在，维护者 `whynotmake.it`（已验证发布者），MIT 协议，886 likes，pub 分 150/160。但**全部 31 个已发布版本都是预发布版**（`0.1.1-dev.0` … `0.2.0-dev.4`），**没有任何稳定版**；最后一个版本 `0.2.0-dev.4` 发布于 2025-11-13，距今约 10 个月。README 首行即 `⚠️ EXPERIMENTAL - USE WITH CAUTION`。

### 4.2 致命问题：在本项目的确切组合上渲染错误

上游 **PR #152（未合并）** 的标题是 "stop double-flipping OpenGLES texture Y on Flutter 3.44+"，其复现说明写的正是本项目环境：

> `liquid_glass_renderer: 0.2.0-dev.4` + Flutter 3.47.0，在真实 Android 设备或模拟器上使用 **Impeller OpenGLES** 后端。

Flutter 引擎在 3.47.0 起在引擎层归一化了 OpenGLES 的纹理坐标，而该包的 shader 在 `#ifdef IMPELLER_TARGET_OPENGLES` 下仍自己做一次翻转，于是**双重翻转**。症状：玻璃采样到屏幕的镜像区域——比如底部导航胶囊会把屏幕顶部的内容折射进来。

本项目：Flutter 3.47.2 固定、仅 Android、运行时日志明确 `Using the Impeller rendering backend (OpenGLES)`。**即命中该缺陷，且修复尚未合并。** 兼容性重写 PR #169 被作者自己标记为 "DO NOT MERGE"。

### 4.3 其他风险

- **无稳定版 + API 频繁破坏性变更**：changelog 中多次 BREAKING，`0.2.0-dev.1` 是一次完整渲染管线重写。
- **仅 Impeller**：Skia 后端完全不支持（issue #150 全部 shader 编译失败）。
- **若干未修复的 Android 专项 issue**：#85（Flutter 3.35+ 后文字/圆角锯齿）、#140（Android 12 不工作）、#141（自定义光角导致边缘黑边）、#123（无 Impeller 设备上 `FakeGlass` 不渲染）。
- **性能**：静态形状便宜，**移动中的形状每帧重渲**；形状动画时会有纹理内存尖峰（上游 Flutter bug #138627 导致纹理无法及时释放）；每个混合组上限 16 个形状；文档要求把 glass 层面积控制得尽量小。

### 4.4 一个现场发现

在模拟器上实测当前设置（KV `verifin.advanced_material.v1`）后确认：**高级材质当前是关闭的**。也就是说，你现在看到的"丑"的玻璃，是**基础磨砂路径**（`BackdropFilter` 模糊 + 中性半透明填色），而不是自研的那套方向高光 + 导航透镜。

这一点很重要：如果是对"高级材质"不满意，方向应该是判断要不要开它；如果是对**基础磨砂本身**不满意（更可能，因为它一直开着），那么换库或调参数才有意义。这两个问题的解法完全不同。

### 4.5 结论与替代路径

**不引入 `liquid_glass_renderer`。** 不是因为它不好，而是它当前发布的版本在这个项目的确切技术栈上会直接渲染错误，且修复未发布。

如果目标是"更好看的玻璃效果"，按风险从低到高有三条路：

| 方案 | 说明 | 风险 |
| --- | --- | --- |
| A. 保留现有材质，只重做视觉参数 | 自研层已有完整的规范约束、6 个专项测试和真机验收记录。用户觉得"丑"更可能来自配色/圆角/透明度取值，而非渲染机制。 | 最低 |
| B. 换 `glass_kit` / `blur` | 纯 Dart `BackdropFilter` 方案，无 shader、无 Impeller 依赖，跨平台稳定，MIT。代价是**没有真实折射**，视觉上是"高级磨砂"而非"液态玻璃"。 | 低 |
| C. 换 `liquid_glass_widgets` | shader 方案、支持 Android、2026-09-09 仍在发布、MIT、`flutter >=3.41.0`。是同类里维护最活跃的。 | 中（需真机验证） |

> **需要用户决策**：是否接受"放弃真实折射、改用更稳的磨砂方案"（B），或者愿意为折射效果承担真机验证成本试 C，或者先只调整现有参数（A）。

## 5. 诉求 2：入门引导页 —— `introduction_screen`

### 5.1 包本身

真实存在且健康：`4.0.0`，发布于 2025-08-27，MIT，2963 likes，pub 分 150/160，月下载约 5 万，未被标记 discontinued。实测在本项目工具链上 `pub get` 与 `analyze` 均干净通过。

依赖 `collection`、`dots_indicator`、`flutter_keyboard_visibility_temp_fork`。注意最后一项：这是为解决 `flutter_keyboard_visibility` 长期未维护而由**另一位作者**做的**临时 fork**，包名里就写着 `temp_fork`，且声明了 **Android 原生插件**。当前项目没有任何键盘可见性依赖，引入它会新带进 5 个平台插件包（含 linux/macos/windows 三个本项目用不到的），并且这个 fork 还把三个联邦实现固定在落后 1–2 个大版本的旧版上。

### 5.2 为什么省不下代码

现有引导页 394 行，**真正的复杂度不在页面外壳**：

- 必须嵌在 `PrivacyConsentGate → AppLockGate → OnboardingGate` 之内（`main.dart:325-336`），引导未完成前**不能构建 Shell**。
- 第 2 步不是静态页：要改**空账本本位币**（`changeEmptyLedgerBookBaseCurrency`，仅空账本合法）、提供完整的离线货币选择器。
- 完成时要做三件业务：创建恰好 1 个现金账户（避免"零账户导致记账页永远不可保存"的回归）、按 `zh→CNY / 其他→USD` 预选本位币、设置**默认**月度预算（`setDefaultMonthlyBudget`，不是当期）。
- 结果要写 KV `verifin.onboarding.v1`，且不被"初始化数据"清除、不进备份。

`introduction_screen` 能提供的只有"4 页 PageView + 圆点 + 上一步/下一步/跳过按钮"这一层。为它引入 5 个依赖，换取几百行外壳代码，同时把每页内容塞进 `PageViewModel` 的 `title/body/image` 字符串槽位（本项目需要的是带表单的业务 widget），**净收益为负**。

### 5.3 另外两点实测发现

**（a）它会和你自己的设计系统打架。** 该库内置按钮是硬编码的 `TextButton`（固定 8px 圆角），而 `ButtonStyle.merge` 的优先级会让这个硬编码圆角**盖过本项目的 `textButtonTheme`**——只有颜色还能从主题继承。排版同理：`titleTextStyle` / `bodyTextStyle` 是常量（20 粗体 / 18 常规、居中），**不继承 `Theme.textTheme`**。要贴合本项目外观，就得逐页覆盖文字样式并显式传 `baseBtnStyle`（或干脆用 `overrideNext`/`overrideDone` 换成自己的按钮）。

**（b）你列出的部分参数名不存在。** `controlsBuilder`、`onInit`、`useSafeArea` 在这个包里都没有（实测 grep 计数为 0）。安全区控制是 `safeAreaList: List<bool>` 加 `PageDecoration.safeArea`；程序化翻页要用 `GlobalKey<IntroductionScreenState>`。

不过它有一个真正的逃生舱：`rawPages: List<Widget>` 可以**完全绕过** `PageViewModel`/`PageDecoration`，直接放任意 widget。

### 5.4 建议

**不引入 `introduction_screen`。** 改为在现有 `onboarding_page.dart` 上做视觉重构。

如果你想要的其实只是**那个更好看的页码圆点**，正确的做法是只引入指示器：`smooth_page_indicator`（`3.0.0`，2026-08-21 发布，**pub 分 160/160**，4124 likes，月下载 54 万，`sdk >=3.0.0 <4.0.0`，**无原生插件**），套在现有的 `PageController` 上。这是"只拿走你缺的那一块"的最小代价方案，比引入一个带 3 个依赖树、含原生插件的整屏框架划算得多。

> **需要用户决策**：引导页"丑"具体指哪一部分？（单色图标方块太简陋？配色？排版松散？圆点？）如果主要是圆点，直接换 `smooth_page_indicator` 即可；如果是整体排版，自研重构更可控。

## 6. 诉求 3：开关与切换条统一 —— `animated_toggle_switch`

### 6.1 包本身（评估结论最好的一项）

`0.8.7`，发布于 2026-01-09，发布者 `splashbyte.dev`（已验证），BSD-3，**pub 分 160/160（满分）**，1009 likes，月下载 6.4 万。**唯一依赖是 Flutter SDK 本身**——零第三方传递依赖，`sdk >=2.17 <4.0.0`，在 Flutter 3.47 上干净求解。0 个未关闭 issue。支持 Android 及全平台，标记 wasm-ready。

主题自由度：`ToggleStyle` 接受任意 `Color`/`Gradient`/`BorderRadius`，且是 `ThemeExtension`，可以**一次性注册到 `ThemeData.extensions`**，让全项目按设计令牌取值。**库自身不绘制任何阴影/发光**（源码中零 `BoxShadow`），不会有预设样式和扁平设计语言冲突。

### 6.2 必须先知道的两个限制

**（a）你列出的部分参数名不存在。** `activeBgColors`、`inactiveBgColor`、`innerGap`、`selectedIconAlignment`、`loadingBuilder`、`difficulty` 都不在这个包里（前两个属于另一个包 `toggle_switch`，其余在任何包中都搜索不到）。等价能力要通过 `styleBuilder` / `styleList`（对应 `values` 逐项配样式）和 `loadingIconBuilder` 实现。

**（b）没有一等的文字标签支持。** 不存在 `.rollingWithText` 变体（这个名字在这个包里不存在）。文字只能作为 widget 从 `iconBuilder`/`iconList` 返回，**没有自动的选中态文字颜色/透明度动画、没有标签样式 API**，需要自己在 builder 里实现。

### 6.3 无障碍：真实缺口

源码中**零 `Semantics`、零 `Focus`/`FocusableActionDetector`/`Actions`**。没有选中态播报、没有键盘可达性。对"全项目统一控件"来说这是不可接受的回归。

`minTouchTargetSize` 默认 48.0（达标），`active: false` 是真实的禁用态，`inactiveOpacity` 0.6。高度是固定 `double`（默认 50），大字号下可能裁切标签。

### 6.4 当前项目的混乱程度（这是本诉求的真实价值）

审计出**至少 15 个开关类控件、6 种不同的选中指示样式、3 种不同的轨道灰色来源**：

| 控件 | 位置 | 选项数 | 高度 | 圆角 | 选中底色 | 动画 |
| --- | --- | --- | --- | --- | --- | --- |
| `CompactSwitchRow` | `common_widgets_forms.dart:164` | 2 | v8 padding | `veriRadiusSm` | 原生 Switch | 原生 |
| `SwitchListTile` | `import_preview_page.dart:582` | 2 | M3 ~56 | M3 | 原生 | 原生 |
| 裸 `Switch` × 4 | `panel_settings_page.dart:339` 等 | 2 | ×0.82 | 原生 | 原生 | 原生 |
| `SegmentedButton` × 4 | `home_page.dart:967` 等 | 3~4 | M3 ~40 | M3 | M3 默认 | M3 |
| `_EntryTypeSelector` | `entry_detail_page.dart:2016` | 3 | ~44 | `veriRadiusMd` | surface 白胶囊 / 灰轨道 | **无** |
| `_DimensionToggle` | `report_analysis_page.dart:653` | 2 | 36+4 | **999** | 语义色实心 | 160ms |
| `_MiniSegmentedToggle` | `account_detail_page.dart:930` | 2 | ~30 | `veriRadiusSm-2` | surface 白胶囊 | **无** |
| `_RangeChip` | `report_analysis_page.dart:312` | 3 | min36 | **999** | **`veriRoyal` 实心** | 无 |
| `FilterPill` | `common_widgets_display.dart:30` | 菜单 | min36 | **999** | — | InkWell |
| `ChoiceChip` / `FilterChip` | `account_icon_picker.dart:99` / `entry_sheets.dart:817` | N | M3 | M3 | `veriRoyal@0.14` | M3 |
| `CheckboxListTile` | `account_detail_page.dart:604` | 2 | M3 | — | — | M3 |
| `VeriAnchoredChoice` | `common_widgets_menu.dart:54` | 2–8 | 44/52 行 | 面板 24 | `veriRoyal` 文字+勾 | 220/280ms |

顺带发现的令牌违规：`999` 硬编码圆角 4 处；`veriRadiusSm - 2` 对令牌做算术（`account_detail_page.dart:987`）；记账页转账选中色硬编码 `veriRoyal` 而不用 `veriSemantic`（`entry_detail_page.dart:2071`）；**4 个 Material `SegmentedButton` 完全没有自定义主题**，直接吃 M3 默认色。

### 6.5 建议方案

分两类处理，**不要用一个控件硬套所有场景**：

1. **建立 `VeriSegmentedControl<T>` 共享包装层**（新组件，注册到 `components.md`）：
   - 内部用 `animated_toggle_switch` 提供滑动手感；
   - 强制包 `Semantics(selected:, button:, label:)` + `FocusableActionDetector`，补上库缺失的无障碍；
   - 从 `ThemeData.extensions` 读取 `veri*` 令牌，**没有任何调用点能自定义颜色**；
   - 提供一个 `VeriSegmentedControl.text(...)` 变体，内部实现文字标签的选中态动画。
2. **替换范围**：`_EntryTypeSelector`、`_DimensionToggle`、`_MiniSegmentedToggle`、`_RangeChip`、4 个裸 `SegmentedButton` —— 这些语义相同、长相各异，是收益最大的部分。
3. **不替换**：`CompactSwitchRow`（开关行，不是分段控件）、`VeriAnchoredChoice`（菜单式单选，超过 4 项时更合适）、`FilterPill`（菜单触发器而非切换）、`MonthSwitcher`（左右步进器）。

> **需要用户决策**：是否接受"分段控件统一成一个新样式"，以及新样式选哪一种视觉（白胶囊浮在灰轨道上 / 品牌色实心 / 语义色实心）？现在三种都有。

## 7. 诉求 4：看板等页面布局回归

对 `reports_page.dart` 与 `v1.15.17` 基线做了完整 diff、并对可疑提交逐个 `git show` 追溯后，结论是：**近期的统一设计批次并没有把看板"改烂"——真正被改动的是卡片的顺序**。全套测试 986 通过 / 16 跳过，360dp 与 393dp、浅色与深色下看板均无溢出。

### 7.1 已确认缺陷

**C1（最可能就是你说的"位置好像都错了"）——预算执行卡不再是看板第一张卡。**

| 项 | 内容 |
| --- | --- |
| 位置 | `lib/pages/reports_page.dart:305-314`（`_MonthSummaryCard` 的插入点） |
| 当前实现 | 渲染顺序变成 `PageHeader → _MonthSummaryCard → budget_execution → …`。默认面板顺序里 `budget_execution` 本就是第一张（`lib/app/models/preferences.dart:229-236`），于是**看板所有卡片整体下移一张卡的高度**，预算执行卡退成第二张。 |
| 规范要求 | `docs/ui-guidelines.md:191`：「看板预算执行卡放在看板顶部」 |
| 引入提交 | `28bd50f`（2026-09-08，"close the product P1 gaps in navigation, dashboard and data safety"），`git blame` 指向 `reports_page.dart:306` |
| 最小修复 | 二选一：把 `_MonthSummaryCard` 移到第一张面板之后；或——如果新顺序是有意为之（`test/panels_test.dart` 把它当成了既定行为）——更新 `docs/ui-guidelines.md:191` 让规范与实现一致。**需要你拍板**，因为规范文档就是判定标准。 |

这是 `v1.15.17 → HEAD` 之间 `reports_page.dart` **唯一的结构性布局改动**（其余只是 EmptyState 包裹、一处标题改名和颜色/格式调整）。所以这条基本可以确定就是你看到的问题。

**C2——预算圆环画布尺寸，代码 116dp vs 规范 118dp。**

| 项 | 内容 |
| --- | --- |
| 位置 | `lib/pages/home_page.dart:758-760`（`SizedBox(width: 116, height: 116)`） |
| 现状 | 首页预算面板圆环画布是 **116**；预算总览页用的是 **118**（`lib/pages/budget_pages.dart:166-168`）。 |
| 规范要求 | `docs/design-system.md:21` 写「圆环画布 118dp」。但该行描述的是**首页**面板结构（左支出 / 中间剩余及比例 / 右剩余日均 / 底部预算总额），也就是代码里的 116 那个控件。 |
| 来源 | 116 是原始值（`e4e4bf9`，2026-07-03）。是**规范**在 2026-09-09 被 `9d5a3d8` 从 116 改成 118，引用的是 `budget_pages.dart`——很可能给这一行引错了参照文件。 |
| 最小修复 | 二选一：把 `home_page.dart:759-760` 改成 118；或把规范该行改回 116，并单独记录总览页的圆环尺寸。影响只有 2dp，但这是一个**真实存在的文档/代码矛盾**。 |

### 7.2 疑似缺陷（需要实机测量确认）

**S1——图表轴标签会跟随系统字号放大，但图表内边距和高度是固定的。**

| 项 | 内容 |
| --- | --- |
| 位置 | `lib/app/chart_painters.dart:31-61`（`trendChartRect`/`barChartRect` 固定内边距 30/22/8）与 `:781-815`（`_drawLabels` 现在接收 `textScaler`）；高度见 `home_page.dart:552`(96)、`reports_page.dart:161`(138)/`:209`(146)。 |
| 问题 | `1d58dbc`（2026-09-09）让画布文字跟随 `MediaQuery.textScalerOf`，但**预留的内边距和图表高度没有跟着变**。X 轴标签在 `chartRect.bottom + 6` 绘制、Y 轴标签在 `chartRect.left - width - 6` 绘制；字号放大到约 1.3–1.5× 时，X 标签会越出固定画布，Y 标签起点会变成负坐标。 |
| 为何没被发现 | 1.0× 下完全正常，所以 analyze 和现有测试都过；`test/design_consistency_test.dart` 只在 1.5× 下测了"我的"宫格，**图表没有大字号覆盖**。而 `design-system.md:75` 要求 360dp + 大字号都要测。 |
| 建议 | **先别改。** 在 1.5× 下渲染一次确认再说。修复方向是让内边距由实测的缩放后标签尺寸推导，或让图表高度随字号缩放。 |

### 7.3 我核查过、但确认符合规范的部分（不要"顺手修"）

审计特意验证了一批看起来可疑、实则正确的实现，避免误改：

- `VeriCard` 默认内边距 `symmetric(horizontal: 14, vertical: 12)` 与圆角 16（`common_widgets_scaffold.dart:53-57`、`app_theme.dart:29-31`）——与规范 `design-system.md:18` 完全一致。
- 页面边距与头部：`VeriPage` 2dp + 列表 14dp = 16dp，`veriCompactHeaderHeight = 56`——符合规范。
- `veriRootPageListPadding` 确实能避开浮动导航（`test/home_density_test.dart:49-52` 断言最后一笔交易在导航胶囊之上，且该测试通过）。
- 字体层级 `app_theme.dart:232-301` 与规范基线逐项一致，无偏离。
- `_MonthSummaryCard` 的 10/16 内边距虽然与卡片默认值不同，但属于规范允许的"显式 padding 优先"，且与 `transactions_pages.dart:502-506` 既有的三指标摘要卡完全一致（自 2026-07-12 起就在）。是复用，不是回归。
- `_BudgetExecutionCard` 的 `fromLTRB(13,12,13,13)` 是全项目预算卡约定（自 2026-07-03 起）。
- `_CategoryStatTile` / `_TagStatTile` 的 `vertical: 8` 是卡片**内部**列表项，不是卡片本身。
- 分类环形图 `ringSize: 126 : 156` 是原始值，符合"圆环尺寸保持克制"。

**结论**：真正需要修的是 **C1**（一条，且需要你先在"移动卡片"和"改规范"之间选一个），**C2** 是 2dp 的文档矛盾，**S1** 要先测量。

### 7.4 我在模拟器上观察到的、但审计判定为"规范如此"的现象

前面提过的两点，经核查**不是缺陷**，记录在此以免误改：

1. **分类明细的进度条颜色偏重。** `reports_page.dart:1031` 用 `veriSemantic(context, veriExpense)` 作填充色，而同一页环形图用 `veriRoyal`（`:807`）——**同一分类在两个面板里确实是两个颜色**。但两者都是通过 `veriSemantic` 取用的语义色，符合规范；这是**观感问题，不是违规**。是否统一属于设计口味，不是 bug 修复。如果要改，应该同时调整规范里对这两个面板的配色约定。
2. **滚动中段卡片从导航下方穿过。** 这是 `extendBody: true` + 内容延伸到导航背后的**设计意图**（`design-system.md:61`），且列表末项的避让有测试保证。观感问题同样属于设计取舍。

## 8. 诉求 5：图表 —— `syncfusion_flutter_charts` / `time_chart` / `fl_chart`

### 8.1 `time_chart`：完全不可用

**两个独立的致命问题，任一条都足以否决。**

1. **装不上。** 本项目的真实求解结果：
   > Because `time_chart >=0.5.4` depends on `intl ^0.18.0` and every version of `flutter_localizations` from sdk depends on `intl ^0.20.3`, `flutter_localizations` from sdk is incompatible with `time_chart`. … version solving failed.

   同时还报 `The lower bound of "sdk: '>=2.1.0 <3.0.0'" must be 2.12.0 or higher to enable null safety`。
2. **API 完全不是描述的样子。** 它的真实 API 只有一个 `TimeChart` widget，接收 `List<DateTimeRange>`（起止区间），**没有 y 值序列**、**没有任何回调**、**没有拖动刷选**、**没有缩放平移**、**没有值轴配置**。你描述的 `TimeChartSeries`/`TimeChartData`/`TimeChartBehaviourOptions` 等类**在这个包里不存在**。

其他：最后发布于 2023-11-27（约 34 个月前），pub 分 50/160，仅 93 次月下载，9 个未关闭 issue 里就有 intl 版本冲突报告。

**结论：不引入。** 你要的"时间图表可以拖动查看"，需要换别的库实现（见 8.3）。

### 8.2 `syncfusion_flutter_charts`：能力最全，但有两个必须先接受的代价

`34.2.7`，2026-09-08 发布（2 天前），维护节奏约每周一版，并明确跟踪"Flutter SDK 3.47"。`sdk ^3.7.0`、`flutter >=3.35.1`，本项目满足。会引入 `syncfusion_flutter_core`。

能力上它确实是最完整的一站式方案：

- **拖动刷选（Trackball）**：`TrackballBehavior` 原生支持按下/拖动显示十字准线与数值提示——这正是当前自研图表缺的。
- **缩放平移**：`ZoomPanBehavior(enablePanning:, enablePinching:)` 原生支持。
- 33 种序列类型，覆盖折线、样条、面积、柱状、堆叠、饼图/环形、散点、K线、瀑布、漏斗、径向条、直方图等全部需要的类型，外加 12 种技术指标与趋势线。
- **纯 Dart，无原生代码。** 实测解包确认只含 `lib/`，没有 `android/`、没有 `.aar`、没有 `.so`。因此**现有的 R8 `isMinifyEnabled` + `isShrinkResources` 配置不受影响，不需要新增 keep 规则**。体积增长落在 `libapp.so`（AOT），估计每个 ABI 约 1–3 MB。

**代价一：商业授权。**

包内 `LICENSE` 原文：

> To be qualified for the Syncfusion® Community License Program you must have a gross revenue of **less than one (1) million U.S. dollars ($1,000,000.00 USD) per year** and have **less than five (5) developers** in your organization. … **Under no circumstances can you use this product without (1) either a Community License or a commercial license.**

有一个容易误判的点：**从 v18.3.0 起运行时不再需要注册授权密钥**。实测在 `syncfusion_flutter_charts` 与 `syncfusion_flutter_core` 的完整源码里 grep `registerLicense` / `licenseKey` / `trial` —— **零命中**。没有校验代码、没有水印、没有横幅、不会报错。

但这**不等于可以免费使用**：授权义务仍然存在，只是没有任何技术手段拦住你。这意味着"不小心就无授权发布了"是真实风险。判断标准很明确：

| 情况 | 需要的授权 |
| --- | --- |
| 年营收 < 100 万美元 **且** 开发者 < 5 人 | Community License（免费，需注册，代码里不用填密钥） |
| 任一条超出 | 商业授权（按开发者/年计费） |

**代价二：无障碍倒退（对本案是硬伤）。**

Syncfusion 图表**没有内置的逐数据点无障碍语义**——整个库里唯一的 semantics 命中是 tooltip 上的 `alwaysIncludeSemantics`（默认 false）。

而本项目**有测试强制要求这一点**：`test/chart_semantics_test.dart` 断言图表会产出"3 个数据点"这类语义标签，`chart_hit_test.dart`、`budget_ring_test.dart` 同样覆盖。换用 Syncfusion 会**直接让这些测试失败**，并且**移除屏幕阅读器支持**——除非为每个图表自己包一层 `Semantics` 并重建 tooltip 的文本通道。`AGENTS.md:140` 要求图表必须支持点按或滑动查看数据，无障碍属于已交付能力，不是可选项。

**代价三：本体不读主题。** 颜色与字体**不会**从 `Theme.of(context)` 自动读取，必须显式传入或经 `SfTheme(data: SfThemeData(chartThemeData: SfChartThemeData(...)))` 全局配置。对一个有完整设计令牌体系的项目，这意味着深/浅色切换要额外接线，不是免费获得。

**已知问题**：上游 issue **#2394 "Charts regression in Flutter 3.32.6+: `disposed RenderObject was mutated`"**——Flutter 3.32.6+（含本项目的 3.47）在该范围内。采用前必须针对 34.2.7 实测确认。

### 8.3 `fl_chart`：无授权负担，且不存在上述无障碍缺口

`1.2.0`（2026-03-13），**MIT**，纯 Dart，`sdk >=3.6.2`、`flutter >=3.27.4`，本项目满足。依赖仅 `equatable`、`vector_math`，体积远小于 Syncfusion。pub 分 150/160，likes 7192，**月下载 175 万**（本项目现有依赖量级的生态位）。

- **拖动刷选**：`LineTouchData` + `LineTouchTooltipData` 原生支持，工具提示跟随手指——同样解决"时间图表不能拖动"的问题。
- **缩放平移**：`FlTransformationConfig` 提供，**不需要**像早先判断的那样完全手写。
- **覆盖你的四类需求全部**：折线趋势 + 触摸提示、环形/进度环（`PieChart` + `centerSpaceRadius`）、横向柱状、饼图/环形。缺的是 K线/瀑布/漏斗/仪表盘——本项目不需要。
- **MIT 授权，无密钥，无营收门槛。**

### 8.4 结论调整：本项目应选 `fl_chart`

在拿到 Syncfusion 的授权条款与无障碍实测之前，两者的取舍看起来只是"能力 vs 成本"。现在有一条**决定性理由**：

> Syncfusion 会破坏 `test/chart_semantics_test.dart` 所强制的无障碍契约，而 `fl_chart` 不会引入这个缺口。

对一个已建立无障碍测试门禁的项目，为图表库放弃这条不划算——尤其是 `fl_chart` 在"拖动刷选"这个核心诉求上**同样满足**，缩放平移也有现成配置，而这正是你想换图表的原始动机。

**Syncfusion 只在一种情况下值得考虑**：确实需要它特有的瀑布图、漏斗图、技术指标、径向仪表盘等，**并且**确认符合 Community License 条件、**并且**愿意为每个图表补写 `Semantics` 包装层。以本项目当前的图表需求（趋势/柱状/环形/预算环）看，这些特有类型都用不上。

> **给用户的建议**：选 `fl_chart`。除非你对 Syncfusion 的某个特有图表类型有明确需求。


### 8.5 本项目图表的替换边界（关键）

替换不是全有全无。审计后按"可替换度"分三层：

**可直接替换（纯数据入参，自包含）：**

| 图表 | 定义 | 调用点 | 数据源 |
| --- | --- | --- | --- |
| `InteractiveTrendChart` | `chart_painters.dart:532` | 8 处：`home_page.dart:556,1042`、`report_analysis_page.dart:752`、`reports_page.dart:162`、`assets_pages.dart:356`、`account_detail_page.dart:202,1094`、`ai_result_view.dart:232` | `valuesForTypeInWindow`、`accountMonthlyBalanceSeries`、`reportTrend`、余额序列等 |
| `InteractiveBarChart` | `chart_painters.dart:639` | 2 处：`reports_page.dart:210`、`ai_result_view.dart:150` | `monthlyExpenseValues`、AI 排行 |
| 看板分类环形图 + 引线 | `reports_page.dart:620-974` | 1 处：`reports_page.dart:110` | `_categoryStats` |

**必须保留自研（规范强制）：**

- **预算圆环 `BudgetRingPainter`**（`chart_painters.dart:475`）。`docs/design-system.md:43` 明确"恢复原常规 SweepGradient 进度环…不再保留 glass/advanced 绘制分支"，且"预算环禁止内外白线"（`design-system.md:7`）。有 `test/budget_ring_test.dart` 做像素级接缝回归。通用进度环组件无法满足这个渐变接缝契约。**保持自研。**

**需要单独处理：**

- **预算趋势组合图 `_BudgetTrendPainter`**（`budget_trend_chart.dart:185`，178 行）：柱状（支出）+ 折线（预算）双序列组合。需要组合图能力或保留自研。审计发现两个既有缺陷：工具提示未传 `textScaler`（`budget_trend_chart.dart:309-314`，其他图表都传了）导致不跟随系统字号；`shouldRepaint` 用 `listEquals` 比较 `months`，但 `BudgetMonthSnapshot` **没有 `operator==`**，实际按引用比较。

**替换必须保留的横切契约（写成验收项）：**

1. 所有颜色经 `veri*` 令牌与 `veriSemantic(context, veriX)` / `veriSemanticFor(brightness, veriX)`；painter 无 `Theme`，颜色由调用方显式传入。
2. 轴标签与数值格式必须保持现状：`reportAxisLabels` / `balanceAxisLabels` / `_formatAxisAmount`（≥10000 用"万"）、`monthAxisLabels`（手拼 `M.D`）、`AppLocalizations` 的 `dateMonthDay`/`yearMonth`/`monthNumber`，以及 `formatExpenseAmount` 等金额 helper。
3. **"点按或滑动查看数据"是硬要求**（`AGENTS.md:140`、`ui-guidelines.md`）：图表必须可选中数据点并显示提示，且**位于可跳转卡片内时必须拦截点击**，避免误触卡片跳转。现阶段由 `HitTestBehavior.opaque` + 内部 `GestureDetector` + `Semantics` 摘要实现，有 `chart_semantics_test.dart` 覆盖。
4. `textScaler` 必须从 `MediaQuery.textScalerOf(context)` 传入画布文本（现有环形图和预算趋势图**未传**，是既有缺陷）。
5. 固定高度清单（96/112/132/138/146/148/150/156/172/180）按 360–440dp 宽度设计，替换时不能撑破布局。

### 8.6 建议

**选 `fl_chart`，分阶段按图表类型替换，不做一次性全量替换：**

- 阶段一：`InteractiveTrendChart` + `InteractiveBarChart`（收益最大：8+2 个调用点，能顺手拿到拖动刷选与缩放平移，正好解决"时间图表交互不合理"）。
- 阶段二：看板分类环形图 + 预算趋势组合图。
- **预算圆环保持自研，不替换**（SweepGradient 接缝契约 + 像素级测试）。
- 每个替换点都必须补上 `Semantics` 摘要，保证 `chart_semantics_test.dart` 继续通过。

> **需要用户决策**：是否认可选 `fl_chart`（MIT、无授权门槛、无无障碍缺口）？如果坚持 Syncfusion，需要先确认是否符合 Community License 条件，并接受为每个图表补写无障碍层的额外工作。

## 9. 诉求 6：底部导航 —— `bottom_bar_matu`

### 9.1 三个阻断性问题

**（a）SDK 声明只支持 Dart 2。** 包的真实 pubspec：
```yaml
environment:
  sdk: ">=2.17.6 <3.0.0"
  flutter: ">=1.17.0"
```
本项目 Dart 3.13.2，**超出声明上界**。实测 `flutter pub add --dry-run` 仍能解出 `1.5.0`（pub 的宽松路径 + 该包被标记 `is:dart3-compatible`），所以这不是一个当场就会失败的问题——但它是一个**语义上不受支持的依赖状态**，且维护者从未为上界松绑发过版本。

**（b）它做不出你要的形态。** 该库的渲染核心（`BottomBarBubble.build`）就是一个：
```dart
Container(
  color: widget.backgroundColor,   // 不透明填充
  height: widget.height,           // 硬编码高度
  child: Stack(...),
)
```
**贴边、全宽、不透明、高度固定**。没有 `margin`、没有圆角、没有 `BackdropFilter`、没有让导航从屏幕边缘内缩的能力，也没有居中缺口或 FAB 插槽。

而本项目规范里有三条**硬性要求**（`design-system.md:59-61`、`liquid-glass-navigation.md:67`）：

| 硬性要求 | 出处 | `bottom_bar_matu` 能否满足 |
| --- | --- | --- |
| 浮动胶囊，导航左右及底部各留 24dp | `design-system.md:61` | ❌ 只能贴边全宽 |
| 内容延伸到导航背后，不加整宽底栏底色 | `design-system.md:61` | ❌ 不透明全宽条 |
| 首页才显示快捷记账按钮，其他页胶囊居中 | `design-system.md:59` | ❌ 无此形态 |

**（c）它是个休眠包。** 发布者**未验证**，最后发布 2024-05-10（约 2 年前），月下载仅 **148 次**，pub 分 140/160，5 个未关闭 issue。历史上已经因为 Flutter 升级出过一次 bug（`1.2.3` 修 "when update to Flutter version 3.3.9 and above"）。没有 discontinued 标记，所以 pub 不会警告你。

另外，你列出的 API 名（`BottomBarMatu`、`BottomBarType`、`fiveToFour`/`fourToThree` 等动效类型、`itemStyle`、`labelVisible`、`animationDuration`）**在这个包里都不存在**。真实导出的只有三个 widget 类：`BottomBarBubble`、`BottomBarDoubleBullet`、`BottomBarLabelSlide`，加一个 `BottomBarItem`。"类型"是靠换 widget 类选的，不是枚举；动画时长（300–500ms）全部硬编码。

顺带澄清它唯一真正的长板：它可以给每个 item 传 `iconBuilder: (Color color) => Widget` 做自定义图标，且支持 4 个中文标签（实测编译通过）。但这些都是次要的。

### 9.2 自研导航的价值恰恰在这些约束里

现有 `root_navigation.dart`（726 行）不只是"画个底栏"，它实现了：

- **连续指针状态机**：2dp 起步阈值、按住追随、松手 240ms 吸附、取消回到原目的地、跨页只认最终目的地（`_programmaticPageTarget` 解决 `animateToPage` 途经页覆盖状态的问题）。
- 用 `Listener` 而非 `GestureDetector.onHorizontalDrag`，正是为了避开拖动手势阈值造成的"起步卡一下"（`ui-guidelines.md` 明确记录了这个坑）。
- 从 `AnimatedScale` 按压 94%、到 `Transform.translate` 驱动滑块（避免每帧 relayout）、到 `_suppressNextDestinationTap` 解决原始指针与内层 `InkWell` 重复触发。

换掉它等于把规范里已经验收过的交互全部重做，而且新库做不到浮动形态。

### 9.3 建议

**不引入 `bottom_bar_matu`。**

你提到的两个真实诉求可以分开处理，都不需要换库：

1. **"磨砂玻璃底部导航不一定对"** —— 这是材质决策，不是导航组件决策。现有代码已有两档材质（`design-system.md:35-39`），把导航从"高级材质路径"切回"普通磨砂/中性实色"是**改一个分支判断**的事，不需要换组件。
2. **"记账 FAB 或许应该放在上面"** —— 也是定位调整，不是组件替换。现在是 `Positioned(right:0)` 与胶囊同一行（`root_navigation.dart:335`），改成上浮、或改成其他位置，都在现有代码内改。

> **需要用户决策**：导航你想要的方向是哪个——(a) 关掉磨砂，改成中性实色胶囊；(b) 保留磨砂但不用高级透镜；(c) 调整 FAB 位置（上浮？居中缺口？右上加号？）？

### 9.4 如果确实想减少自研代码，可选的替代

调研过的动画底栏库里，**没有任何一个**能开箱复现"内缩 + 半透明胶囊 + 拖动选择 + 独立记账按钮"这个组合。退而求其次：

| 包 | 最新版 | 发布 | 形态 | 备注 |
| --- | --- | --- | --- | --- |
| `animated_bottom_navigation_bar` | 1.4.1 | **2026-08-04** | 贴边 + **居中缺口 FAB** | 维护活跃；如果你要的是"凹槽 + 中间按钮"，这是唯一合适且活跃的 |
| `google_nav_bar` | 5.0.7 | 2024-10-28 | 全宽，但主题自由度极高 | 动画质感好，容易自己包成胶囊 |
| `motion_tab_bar` | 2.0.4 | 2024-01-04 | **浮动圆角带阴影** | 最接近"浮动胶囊"，但只支持点击、无半透明 |
| Material 3 `NavigationBar`（SDK 内置） | — | — | 全宽不透明 | 零依赖；套 `Container(margin) + ClipRRect + BackdropFilter` 可做成胶囊 |

**注意**：这几条路都还是"你在外面自己写玻璃胶囊"，只是把 item 布局交给库。**与保留现有 `root_navigation.dart` 相比，净收益有限**，因为现有实现里真正值钱的是那套指针状态机和跨页目标锁定，而那些恰恰是任何库都不会提供的。

## 10. 诉求 7：短反馈 —— `toastification`

### 10.1 包本身

`3.2.0`，`sdk >=3.0.0`、`flutter >=3.38.0`（本项目 3.47.2 满足），发布者已验证，活跃维护。会引入 `equatable`、`uuid`、`pausable_timer`，并自带一个图标字体 `Toastification_icons.ttf`（少量体积）。

### 10.2 能力对照

| 现有规范硬要求 | 出处 | `toastification` 覆盖情况 |
| --- | --- | --- |
| 常驻态（无时长） | `feedback-system.md:98-103` | ✅ `autoCloseDuration: null` |
| 最多同时 4 条、最新在底部 | `feedback-system.md:129` | ⚠️ 需确认可配置数量与堆叠方向 |
| 优先级队列（默认上限 16，溢出丢最低优先级） | `feedback-system.md:130-131` | ⚠️ 需自建（库有队列但无优先级语义） |
| 去重（按调用方 `dedupeKey`，显示 `×N`，重启计时） | `feedback-system.md:135-149` | ❌ 需自建包装层 |
| 后台暂停、回前台从原进度继续 | `feedback-system.md:33-34` | ⚠️ 库有 pause 能力，需确认后台生命周期 |
| 宽度自适应（按文本测量，最大 360dp） | `feedback-system.md:36-39` | ⚠️ 部分（库是固定宽度模式） |
| 始终显示关闭按钮、最多一个操作按钮 | `feedback-system.md:105,156` | ✅ |
| 根级单一 Host、跨 Tab 与 push/pop 存活 | `feedback-system.md:24-32` | ✅ `ToastificationWrapper` |
| 避让浮动导航（系统安全区之上 100dp） | `feedback-system.md:33-34` | ✅ 可配 `margin` |

当前自研实现 892 行，另有 `+N` 待处理计数、`Semantics(liveRegion:true)` 朗读、错误态 6 行（普通 3 行）等文档未记录的行为。约 **40 处调用点**，主要形态是 `unawaited(VeriFeedbackHost.of(context).showMessage(...))`。

### 10.3 实测出的三个硬缺口

调研直接读了 `toastification 3.2.0` 的源码，有三处**不是配置问题、是能力缺失**：

1. **优先级队列：没有。** 它是每个对齐位置一条 FIFO 列表，插入到 index 0，超过 `maxToastLimit`（默认 10）时丢弃**最旧的**。没有优先级概念，也没有按优先级拒绝。本项目 `VeriFeedbackPriority` 的语义无法映射，只能在适配层自己拦。
2. **去重：没有。** 唯一的守卫是 `if (notifications.contains(item)) return;`——**同一个对象实例**的判等，不是按 key 的内容判等。现有 `dedupeKey` + `×N` 计数聚合没有任何对应物。
3. **后台暂停：没有。** 整个包里**不存在** `WidgetsBindingObserver` / `didChangeAppLifecycleState` / `AppLifecycleListener`。只有 `pauseOnHover`（鼠标）。要恢复现有行为，得自己挂 `AppLifecycleListener` + 维护自己创建过的 item 注册表逐个 `pause()`/`start()`——而库没有"暂停全部"的公开 API。

另外两点：

- **深色模式不跟随应用主题。** 样式里硬编码 `surfaceLight: Colors.white` / `surfaceDark: Colors.black`，而且 `brightness` 参数是**死代码**（声明并传递了，但从未被读取）。不显式传色的话，深色主题下会得到**白底黑字的卡片**。
- **操作按钮只能靠 `showCustom`。** `show()` 没有 `actionLabel` 参数；要么用 `showCustom` 自己画整张卡片，要么用 `ToastCloseButton(buttonBuilder:)` 顶替关闭按钮。

还有一处文档陷阱：README 示例里的 `ToastificationConfig(margin: ...)` **编译不过**，3.2.0 的字段叫 `marginBuilder`。

### 10.4 建议：适配层，而不是替换

**引入 `toastification`，但保留现有接口，只替换渲染层。**

```
调用方（约 40 处，零改动）
        ↓  VeriFeedbackHost.of(context).showMessage(...)
VeriFeedbackController / VeriFeedbackRequest   ← 接口与行为契约完全不动
        ↓  优先级队列、去重、×N、后台暂停、Future 结果 —— 仍由现有逻辑承担
   ┌────┴────┐
   │ 渲染层  │  ← 换成 toastification 的卡片样式
   └─────────┘
```

这样约 40 个调用点**一行都不用改**（它们依赖的是 `VeriFeedbackController` / `VeriFeedbackRequest` / `VeriFeedbackResult`），视觉换成成熟库的样式，而规范里的硬要求全部保住。`showCustom(builder:)` 是承接"消息 + 操作按钮 + 关闭 + 进度条"这张卡片的入口。

**风险点**：`toastification` 会自己往最近的 `Navigator` 的 `Overlay` 里插一个 `OverlayEntry`。现有 Host 是 `MaterialApp.builder` 内、`Navigator` 之外的普通 `Stack + Positioned`（`main.dart:321-337`），结构上不冲突，但**两套叠加层的 z 序会变成插入顺序依赖**。结论：**要么换、要么不换，不要两套并行**。

> **需要用户决策**：这次的目标是**只换外观**（上面的适配层方案成立，规范文档不动），还是**连行为一起简化**（接受失去优先级/去重/后台暂停，同步改 `docs/dev/feedback-system.md`）？

我的建议是**只换外观**。现有 892 行里真正有价值的是队列语义，而不是卡片长什么样；而那些语义正是库缺失的部分。

## 11. 实施顺序建议

按"收益/风险比"排序，每步独立可验收、可回退：

| 阶段 | 内容 | 风险 | 依赖 |
| --- | --- | --- | --- |
| 0 | **修复看板布局**（C1 卡片顺序；C2 二选一；S1 先测量） | 低 | C1 需先选"移卡片"还是"改规范" |
| 1 | **统一分段控件**（新建 `VeriSegmentedControl`） | 低-中 | 无（`animated_toggle_switch` 零依赖） |
| 2 | **短反馈换外观**（适配层） | 中 | 需先确认覆盖范围 |
| 3 | **图表分阶段替换**（建议 `fl_chart`） | 中 | 需先确认图表库选型 |
| 4 | **玻璃材质决策**（调整参数 / 换 B 或 C / 维持） | 低-高 | 需用户选定方向 |
| 5 | **导航与 FAB 调整**（材质或位置） | 低-中 | 需用户选定方向 |
| 6 | **引导页视觉重构**（自研，不换库） | 低 | 需用户说明"丑"在哪 |

阶段 0 的实际改动很小（把一张卡换个位置 + 一处 2dp 对齐），阶段 1 不阻塞在任何决策上，两者都可以立刻开始。

**S1 的测量方法**（不改代码就能确认）：把模拟器系统字号调到 1.5×，打开看板与首页趋势，观察 X 轴标签是否越出卡片、Y 轴标签是否被裁。

```powershell
adb shell settings put system font_scale 1.5   # 复现
adb shell settings put system font_scale 1.0   # 复原（务必还原）
```

## 12. 待用户决策清单

### 已由用户决定（2026-09-10）

| # | 决策点 | 结论 |
| --- | --- | --- |
| 1 | 玻璃方向 | **移除玻璃方向本身**（不是换库），见 §15 |
| 2 | 无障碍 | **不作为约束**，见 §15.8 |
| 3 | 图表库 | **由实现方决定** → 定为 `fl_chart` |
| 4 | 看板文字错位 | 用户澄清为"文字位置"，**已定位并修复**，见 §0.1 |

### 仍待确认

| # | 决策点 | 选项 | 影响 |
| --- | --- | --- | --- |
| 1 | **短反馈目标** | A) 只换外观、保留全部行为契约 B) 连行为一起简化（需同步改 `docs/dev/feedback-system.md`） | 决定 §10 的范围与是否动规范文档 |
| 2 | **分段控件视觉** | A) 白胶囊浮在灰轨道 B) 品牌色实心 C) 语义色实心 | 决定 §6 统一后的样式 |
| 3 | **分段控件替换范围** | 是否同意 §6.5 的划分（替换 8 处，保留 `CompactSwitchRow`/`VeriAnchoredChoice`/`FilterPill`/`MonthSwitcher`） | 决定 §6 的改动面 |
| 4 | **导航 FAB 位置** | 磨砂已定移除；FAB 放哪（保持右侧 / 上浮 / 居中缺口） | 决定 §9 的形态调整 |
| 5 | **引导页"丑"在哪** | 圆点 / 图标方块 / 配色 / 排版 | 决定是换 `smooth_page_indicator` 还是整体重构 |
| 6 | **看板卡片顺序**（次要） | A) 把新增的月度摘要卡移到预算执行卡之后 B) 保留现状、改 `docs/ui-guidelines.md:191` | 与用户原始诉求无关，但规范与实现目前不一致 |
| 7 | **玻璃移除的执行方式** | A) 我先做 §15.5 的**步骤 1**（去掉 CI 的玻璃参数，你立刻看到无玻璃的包）再逐步推进 B) 一次性完成全部 5 步再交付 | 决定交付节奏 |

## 13. 附：实测数据

## 13. 附：实测数据

以下均为在本仓库真实执行 `flutter pub add --dry-run` 的结果（Flutter 3.47.2 / Dart 3.13.2），非引用文档：

| 候选包 | 解析到的版本 | 新增的直接依赖 | 结论 |
| --- | --- | --- | --- |
| `liquid_glass_renderer` | `0.2.0-dev.4` | `flutter_shaders`、`motor` | 可解析，但运行时命中 Y 翻转缺陷 |
| `introduction_screen` | `4.0.0` | `dots_indicator`、`flutter_keyboard_visibility_temp_fork`（含 5 个子包，其一为 Android 原生插件） | 可解析，不建议 |
| `animated_toggle_switch` | `0.8.7` | **无**（仅 Flutter SDK） | 可解析，推荐 |
| `syncfusion_flutter_charts` | `34.2.7` | `syncfusion_flutter_core` | 可解析；但有授权义务与无障碍缺口，不推荐 |
| `fl_chart` | `1.2.0` | **无**（仅 Flutter SDK 已验证依赖，无新增直接依赖） | 可解析，**推荐** |
| `time_chart` | — | — | ❌ **解析失败**：`intl ^0.18.0` 与 `flutter_localizations` 的 `intl ^0.20.3` 冲突 |
| `bottom_bar_matu` | `1.5.0` | **无**（仅 Flutter SDK） | 可解析（pub 宽松处理 `sdk <3.0.0`），但形态不匹配 |
| `toastification` | `3.2.0` | `fixnum`、`pausable_timer`、`uuid` | 可解析，可行（需适配层） |

参考体量（供判断替换收益）：

| 项目 | 当前值 |
| --- | --- |
| 直接依赖数 | 30 |
| Dart 源码文件 | 190 |
| 测试文件 | 114 |
| diagnostic debug APK | 110.5 MB（debug，非交付基线） |
| 短反馈调用点 | 约 40 处 |
| 图表调用点 | 14 处（趋势 8 + 柱状 2 + 环形 1 + 预算趋势 2 + 预算环 2） |

## 14. 调研来源

- `liquid_glass_renderer`：<https://pub.dev/packages/liquid_glass_renderer>、上游仓库 <https://github.com/whynotmake-it/flutter_liquid_glass>（关键 PR #152、#169、#157；相关 issue #85、#123、#140、#141、#150）
- `introduction_screen`：<https://pub.dev/packages/introduction_screen>、<https://github.com/Pyozer/introduction_screen>；替代项 <https://pub.dev/packages/smooth_page_indicator>
- `animated_toggle_switch`：<https://pub.dev/packages/animated_toggle_switch>、<https://github.com/splashbyte/animated_toggle_switch>
- `syncfusion_flutter_charts`：<https://pub.dev/packages/syncfusion_flutter_charts>；替代项 <https://pub.dev/packages/fl_chart>
- `time_chart`：<https://pub.dev/packages/time_chart>、<https://github.com/jja08111/time_chart>
- `bottom_bar_matu`：<https://pub.dev/packages/bottom_bar_matu>、<https://github.com/tuannvm2109/bottom_bar_matu>；替代项 <https://pub.dev/packages/animated_bottom_navigation_bar>
- `toastification`：<https://pub.dev/packages/toastification>、<https://github.com/payam-zahedi/toastification>



## 15. 玻璃移除计划（决策 A）

### 15.1 最容易漏的一点

玻璃由**两层开关**叠加，且**底部导航与快捷按钮的模糊根本不看任何开关**：

| 层 | 门控 | 说明 |
| --- | --- | --- |
| 基础磨砂 | `veriGlassDesignPreview`（= `UNIFIED_DESIGN_PREVIEW && GLASS_DESIGN_PREVIEW`） | 内容卡片、菜单、弹层、导航高级分支 |
| 高级材质 | 上述 **且** KV `verifin.advanced_material.v1` **且** Android | 仅方向光与折射透镜 |
| **无门控** | 无 | **导航回退分支的 `BackdropFilter(blur 10)`（`root_navigation.dart:445`）与快捷按钮的 `BackdropFilter(blur 10)`（`:592`）** |

结论：**只关「高级材质」开关没用**，只删导航高级分支同样没用——回退分支和快捷按钮仍会磨砂。这也解释了用户看到的"丑玻璃"：那是基础磨砂层，在默认构建里一直开着。

### 15.2 逐项处置

| 对象 | 位置 | 处置 | 替换为 |
| --- | --- | --- | --- |
| `VeriGlassSurface` | `glass_material.dart:38-135` | 删类 | 见 15.3 |
| `VeriGlassBackdrop` | `app_theme.dart:307-339` | 删 | 平面画布色 `veriPreviewCanvasLight/Dark` |
| 导航胶囊高级分支 | `root_navigation.dart:369-431` | 删整段 | — |
| 导航胶囊回退分支 | `root_navigation.dart:432-549` | **保留并去玻璃** | 不透明表面 + 轻阴影 |
| `VeriNavigationGlassLens` + shader | `navigation_glass_lens.dart`、`shaders/navigation_live_lens.frag` | 删文件 + `pubspec.yaml:96-97` 声明 | — |
| `glass_lighting.dart` | 整文件 | 删 | — |
| 快捷按钮玻璃 | `root_navigation.dart:592-593` | 去模糊 | 实心圆（`veriSurfaceLight/Dark` + `veriRoyal` 图标） |
| 菜单面板 | `common_widgets_menu.dart:698` | 去 `VeriGlassSurface` 包裹 | 已有的实色 `baseSurface`（`:646-650`） |
| 底部弹窗 | `sheets.dart:34-38` | 去 `VeriGlassSurface` | 默认实色 `backgroundColor`，保留顶部圆角 |
| `BackdropGroup` | `common_widgets_scaffold.dart:38` | 删 | — |
| 输入框玻璃填色 | `app_theme.dart:193-194` | 删分支 | 已有的实色分支（`:195-199`） |
| 设置项「高级材质」 | `settings_page.dart:134-151` | 删 | — |
| KV `verifin.advanced_material.v1` | controller 5 处 | 删 | 残留孤立键无害，无需迁移 |
| `veriGlassCanvas*` 4 令牌 | `app_theme.dart:9-12` | 删 | — |
| `veriGlassTint` | `app_theme.dart:14-23` | 删 | — |
| `veriContentSurfaceColor` | `app_theme.dart:34-37` | **保留** | 它就是要用的实体色 |

### 15.3 `VeriGlassSurface`：删类，而不是保空壳

关键事实：**111 处 `VeriCard(` 调用点从不直接接触 `VeriGlassSurface`**。`VeriCard` 本身已经有一条完整的不透明分支（`common_widgets_scaffold.dart:92-146`，用 `veriContentSurfaceColor` + 边框 + 阴影），玻璃分支只是它前面的 `if (veriGlassDesignPreview) { ... }`。

因此：**删掉 `VeriCard` 的玻璃分支、保留不透明分支，111 个调用点一行不改。**

真正的 `VeriGlassSurface` 直接调用只有 4 处，各自装饰不同，逐一换成显式不透明容器即可（资产卡、菜单面板、底部弹窗、导航胶囊）。把 `grouped`/`reveal` 变成死参数保留空壳，与 AGENTS「不新建同构变体」相冲突。

### 15.4 两个 dart-define 的处置

- **`GLASS_DESIGN_PREVIEW`：删除。** 连同 `veriGlassDesignPreview` 及其全部使用点。
- **`UNIFIED_DESIGN_PREVIEW`：保留。** 它主要控制**布局密度**，与本诉求无关，且是用户已评审过的紧凑排版。

精确切分 `veriUnifiedDesignPreview`：

- **保留（布局）**：`veriCardRadius`/`veriRadiusMd`/`veriRadiusLg`/`veriHeaderHeight`；`VeriPage` 内边距与背景；`VeriCard` 的 `compact` 与默认内边距；`VeriHeader` 的 `compact` 与副标题透明度；各页面的间距、字号（含导航标签 12/10sp）；`colorScheme.surface = canvas`。
- **移除（材质）**：仅 `app_theme.dart:114-115` 的 `scaffoldBackgroundColor` 玻璃透明分支（改为直接取 canvas），以及 `:193-194` 的输入框玻璃填色分支。

### 15.5 提交顺序（每步独立可编译、可过测试）

| 步骤 | 内容 | 效果 |
| --- | --- | --- |
| 1 | 从两个 CI workflow 与文档命令去掉 `--dart-define=GLASS_DESIGN_PREVIEW=true` | `veriGlassDesignPreview=false`，玻璃代码休眠、相关测试自动 skip。**用户立刻看到不带玻璃的包**（导航回退分支与快捷按钮仍磨砂，留给步骤 2） |
| 2 | 导航回退分支去玻璃、删高级分支；FAB 去模糊；删透镜文件 + `.frag` + pubspec 声明 + 相关测试 | 底部导航与快捷按钮变不透明 |
| 3 | 删 `VeriCard` 玻璃分支；改资产卡/菜单/弹窗；删 `glass_material.dart` 与 `glass_lighting.dart` | 内容表面全部实色 |
| 4 | `scaffoldBackgroundColor` 改取 canvas；删 `VeriGlassBackdrop`/`VeriPageTransitionsBuilder`/`BackdropGroup`/`veriGlassTint`/`veriGlassCanvas*` | 背景不再有渐变光效 |
| 5 | 删设置项、KV、l10n、controller 引用；补文档与 CHANGELOG | 入口与数据层清理完毕 |

### 15.6 粗心移除会立刻失败的点

1. **回退分支与快捷按钮是无门控磨砂**（`root_navigation.dart:445,592`）——只删高级分支等于没删。
2. **pubspec 的 shader 声明与 `.frag` 文件必须成对删**（`pubspec.yaml:96-97`）；只删一个会**构建失败**。
3. **`_loadPreferences` 读取 KV**（`veri_fin_controller_state.dart:201`）——删常量必须同删读取点，否则**编译错误**。
4. **`saveAppPreferencesDraft` 的参数**：`settings_page.dart:558` 与 `advanced_material_test.dart` 两处调用方必须同步改。
5. **CI 的测试文件列表**（`ci.yml:51`、`flutter.yml:71`）引用了将被删的测试文件，不改会导致 **CI 直接失败**。
6. **`integration_test/menu_animation_test.dart` 引用 `glass_reveal_pixels_test.dart`**——删后者会连带编译失败。
7. **导航 Key 契约**：`quick_entry_fab`、`main_nav_capsule`、`main_tab_*` 被 20+ 测试与 `shell.dart` 依赖，改装饰时必须保留 Key 与命中区域。
8. **主题 surface 必须保持不透明**（`material_stability_test` 强制断言 `colorScheme.surface.a == 1`）。

### 15.7 涉及删除/改写的测试与文档

**测试**：删 `glass_material_test`、`glass_lighting_test`、`glass_reveal_pixels_test`、`navigation_lens_test`、`advanced_material_test`、`integration_test/glass_navigation_test`；改写 `material_stability_test`（保留不透明与字号断言，删 `veriGlassTint`/路由背景部分）、`anchored_menu_test`（断言实色面板）、`root_navigation_test`（no-gradient 断言）、`integration_test/menu_animation_test`。

**文档**：`design-system.md`（删「两档材质」整节）、`glass-material-preview.md`（改为已移除存根）、`liquid-glass-navigation.md`（保留指针状态机各节、删玻璃材质节）、`unified-design-preview.md`、`known-limitations.md`（删玻璃渲染开销条目）、`components.md`、`tech-decisions.md`、`android-glass-investigation.md`（标为历史）、`ui-guidelines.md`、`acceptance-checklist.md`、`architecture.md`、`README.md`、`AGENTS.md`、`CHANGELOG.md`。

### 15.8 无障碍代码的处置（决策 B）

用户明确不需要无障碍，且此前的无障碍改动未经用户确认。**建议：顺手清理，但不作为独立工作项。**

- 直接服务于图表/组件的 `Semantics` 包装（如 `chart_painters.dart` 的语义摘要、`common_widgets_scaffold.dart` 的 `Semantics(button:)`）——**保留**，它们零成本且不影响视觉；删除反而要额外改动和测试调整。
- `test/chart_semantics_test.dart`——**保留**，它锁的是"图表能播报数据"，删除没有收益。
- `feedback.dart` 的 `Semantics(liveRegion: true)`——保留。

理由：无障碍代码在此项目中不是"丑"或"慢"的来源，也几乎没有维护成本；删除它是纯粹的返工。真正的取舍点（Syncfusion 的图表无障碍缺口）已经因决策 B 而不再是障碍，所以**不需要为了绕开它而改动任何东西**。
