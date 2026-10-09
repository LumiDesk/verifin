# 底部导航样式解耦与选择页实施方案

状态：**方案待实施**。本文只描述改造计划，尚未改动任何源码；实施过程中的取舍变化须回写本文。

关联背景：当前根导航是唯一的停靠底栏实现（`root_navigation.dart` + `veri_bottom_bar.dart`），
产品设想是后续提供多种底部导航样式供用户选择，入口放在「我的 → 设置 → 外观」。
本轮先做**解耦 + 设置页入口 + 样式选择页**，新样式的视觉方向另行确认后接入。

参考先例：

- [`docs/dev/theme-color-and-menu-wrap-design.md`](theme-color-and-menu-wrap-design.md)：
  外观类偏好新增一项时，模型/KV/`ValueNotifier`/草稿提交/文档同步的完整清单。
- [`docs/dev/save-interaction-consistency-design.md`](save-interaction-consistency-design.md)：
  设置页草稿语义与「子页只回写父草稿、不绕过父页写 Controller」的规则。

## 一、已确认的产品决策

| 编号 | 决策 | 说明 |
|---|---|---|
| D1 | 选择页保存只**回写设置页草稿** | 用户在样式选择页确认后返回设置页，真正的 KV 写入仍由设置页的统一保存动作完成（方案 A）。不允许子页弹层/子页绕过父页直接调用 Controller，符合 `save-interaction-consistency-design.md` §3.2。 |
| D2 | 导航样式偏好**不进 JSON 备份** | 与语言 `verifin.locale.v1`、数字键盘布局一致：设备本地偏好。导出备份不带该字段；导入他人/旧备份不改动本机导航样式。 |
| D3 | 第一步只做**解耦 + 等价重构** | 用户可见行为零变化，可独立提交与回归；第二步再接选择页与新样式。 |
| D4 | 目的地集合固定为四个 | 样式只改变视觉与呈现方式，不改变首页/资产/看板/我的四个根目的地、不改变转场状态机、不改变返回键与小组件路由语义。 |
| D5 | 记账按钮与底部导航**完全解耦** | 按钮是按钮、导航是导航。样式实现不得在栏内或栏上安排记账按钮，新增样式必须为按钮留出区域；契约不提供「主操作落点」字段。详见第六节。 |

## 二、目标与非目标

### 目标

- 把「根导航视觉实现」从壳层中抽离为可注册的样式，新增样式只需实现一个 `buildBar`。
- 壳层（页面切换状态机、返回键、快捷入口路由、避让与安全区）保持单份实现，不随样式分叉。
- 提供「设置 → 外观 → 导航栏样式」入口与独立的样式选择页，含可交互预览与明确保存。
- 建立每个样式都必须通过的契约测试，避免样式数量增长后规范与测试碎片化。

### 非目标

- 不改变四个根目的地的数量、顺序、图标语义与 l10n 标签。
- 不在本轮引入任何第二种样式的视觉实现（只准备接入点）。
- 不引入模糊/玻璃/折射材质；所有样式继续遵守不透明实色表面规则。
- 不把「条目集合可配置」「Tab 数量可变」纳入本次能力。
- 不把记账按钮纳入导航样式，也不新增按钮造型偏好（见第六节）。

## 三、现状耦合审计

| 耦合点 | 现状位置 | 处理方式 |
|---|---|---|
| 底栏实现写死在壳层 | `shell.dart` 的 `bottomNavigationBar: VeriRootNavigation(...)` | 改为按当前样式 `buildBar` |
| 内容避让高度写死 | `root_navigation.dart` 的 `VeriRootNavigationBody`（`listBottomPadding: 12`）与 `veriRootPageListPadding` | 避让参数改由样式提供 |
| 是否延伸到栏背后写死 | `shell.dart` 的 `Scaffold.extendBody: false` | 改为读取样式的 `layout.extendBody` |
| 切页弹簧时长写在底栏常量上 | `VeriRootNavigation.switchDuration` ← `VeriBottomBar.switchDuration` | 改为读取当前样式的 `switchDuration` |
| 记账按钮落点写死 | `shell.dart` 的 `Positioned(right: 16, bottom: 16)` | 按钮仍归壳层，但底部偏移改为按样式的底部占用高度推算（见第六节） |
| 测试按几何定位 Tab | `test/support/test_harness.dart` 的 `rootTabCenter`（`main_bottom_nav` 矩形 + 等宽四等分） | 改为按条目 key `main_nav_item_$i` 定位 |
| 测试断言具体类型 | `navigation_settings_test.dart` 四处 `tester.widget<VeriRootNavigation>(...)`；`test/root_navigation_test.dart` 直接构造 `VeriRootNavigation` 并断言 `VeriRootNavigationBody.barHeight` | 改为读取样式无关的锚点组件或壳层状态；改名的同时更新测试脚手架 |
| 规范把停靠特例写成全局规则 | `design-system.md` §导航与输入、`ui-guidelines.md` §根导航、`components.md` 条目 | 拆成「全局不可违反」与「停靠样式专属」两组 |

与样式无关、可原样复用的部分：`_goToTab`、`_animateToTab`、`_finishTabSwitch`、
`_handlePageChanged`、`_trackScrollVelocity`、`PageController` 保活、四个根页面挂载、
`PopScope` 返回处理、`AppCaptureBridge`/`AppWidgetBridge` 路由、`_KeepAlivePage`。

## 四、样式契约

### 4.1 三层拆分

契约只覆盖**已确证存在差异**的维度，避免过度参数化：

1. **条目数据**（已样式无关，保持不变）：`VeriNavigationDestination`。
2. **布局描述**（壳层需要知道的全部信息）：`VeriRootNavigationLayout`。
3. **样式实现**（视觉与动效）：`VeriRootNavigationStyle`。

### 4.2 契约草案

```dart
/// 根导航样式需要知道的全部布局信息。
@immutable
class VeriRootNavigationLayout {
  const VeriRootNavigationLayout({
    required this.extendBody,
    required this.occupiedHeight,
    this.listBottomGap = 12,
  });

  /// 内容是否延伸到导航栏背后。停靠样式为 false；悬浮样式通常为 true。
  final bool extendBody;

  /// 栏本体连同外边距在屏幕底部占用的高度，不含系统安全区。
  /// 停靠样式 = 条目高度；悬浮样式 = 胶囊高度 + 上下外边距。
  final double occupiedHeight;

  /// 列表末项在避让之外额外保留的呼吸空间。
  final double listBottomGap;

  /// 根页面列表末项的底部内边距，由 veriRootPageListPadding 下发。
  double get contentBottomPadding =>
      (extendBody ? occupiedHeight : 0) + listBottomGap;
}

/// 一次渲染所需的纯数据快照，不依赖 Controller，可同时服务真实壳层与选择页预览。
@immutable
class VeriRootNavigationSpec {
  const VeriRootNavigationSpec({
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
    this.keyPrefix = 'main',
  });

  final int currentIndex;
  final List<VeriNavigationDestination> destinations;

  /// 预览场景传 null：条目不可点击，也不会回调。
  final ValueChanged<int>? onSelect;

  /// 稳定 key 前缀。每个样式必须产出 `<prefix>_bottom_nav`、`<prefix>_nav_bar`
  /// 与 `<prefix>_nav_item_<index>`，供测试与无障碍使用。
  final String keyPrefix;

  VeriRootNavigationSpec copyWith({
    int? currentIndex,
    ValueChanged<int>? onSelect,
    bool clearOnSelect = false,
  });
}

abstract interface class VeriRootNavigationStyle {
  const VeriRootNavigationStyle();

  /// 持久化标识，写入 KV；一旦发布不得更名（改名须提供迁移或别名）。
  String get id;

  /// 选择页展示名与说明。
  String label(AppLocalizations l10n);
  String description(AppLocalizations l10n);

  VeriRootNavigationLayout get layout;

  /// 与页面切换动画对齐的时间尺度。无切换动效的样式返回 Duration.zero。
  Duration get switchDuration;

  Widget buildBar(BuildContext context, VeriRootNavigationSpec spec);
}
```

设计要点：

- `buildBar` 只接收纯数据快照，**不接触 Controller、KV 或 Navigator**；选择页预览因此可以直接复用同一实现，不会出现「预览和真实不一致」。
- `onSelect` 可空，预览即天然不可交互，无需另写 `IgnorePointer` 包层（包裹层仍建议保留，避免误触）。
- 契约不含条目数量、排序或自定义能力，避免变成配置怪物。
- 契约不含记账按钮：按钮与导航栏解耦（第六节），样式只声明自己的底部占用高度，
  由壳层统一推算列表避让与按钮偏移。

### 4.3 注册表与稳定标识

```dart
/// 顺序即选择页展示顺序；第一项为默认样式。
const List<VeriRootNavigationStyle> veriRootNavigationStyles =
    <VeriRootNavigationStyle>[VeriDockedRootNavigationStyle()];

VeriRootNavigationStyle veriRootNavigationStyleFor(String? id) =>
    veriRootNavigationStyles.firstWhere(
      (style) => style.id == id,
      orElse: () => veriRootNavigationStyles.first,
    );
```

样式标识与持久化枚举必须一一对应，用测试锁定（见第八节），
防止「KV 里存的 id 找不到实现」这类静默回退。

### 4.4 文件划分

| 文件 | 职责 |
|---|---|
| `lib/app/root_navigation.dart` | 样式契约、注册表、`VeriRootNavigationBody`、`veriRootPageListPadding`。保持为页面侧稳定入口（首页/资产/看板/我的继续只从这里取 padding）。 |
| `lib/app/root_navigation_docked.dart` | 停靠样式实现：现有 `VeriRootNavigation` 的绘制逻辑整体迁移并改名为 `VeriDockedRootNavigation`（条目 key 增加 `main_nav_item_$i`）。 |
| `lib/app/veri_bottom_bar.dart` | 保持不变，继续只被停靠样式使用（它是停靠样式的条内绘制件，不是通用契约的一部分）。 |
| `lib/pages/navigation_style_settings_page.dart` | 样式选择页（预览列表 + 保存）。 |

改名 `VeriRootNavigation` → `VeriDockedRootNavigation` 属于共享件改名，
必须同步 `docs/dev/components.md` 的组件条目与测试引用。

## 五、壳层改造

1. 样式来源：壳层从 `VeriFinScope.of(context)` 读取 `navigationStylePreference`，
   并通过 `ValueListenableBuilder`/`AnimatedBuilder` 只重建**导航栏与布局参数**，
   不重建整个 `MaterialApp`（避免切样式时重建 `PageController` 所在的子树）。
2. 布局：`Scaffold.extendBody`、`VeriRootNavigationBody` 的避让值、
   `bottomNavigationBar` 全部改为按当前样式取值。
3. 动画：`_kTabSwitchSpring` 由 `static final` 改为按当前样式计算
   （`SpringDescription.withDurationAndBounce(duration: style.switchDuration)`）。
   样式无动效时退化为极短弹簧而非零时长，避免 `SpringSimulation` 的退化参数。
4. 状态保持：切换样式**不得**重置 `_index`、`_programmaticPageTarget` 或 `PageController`；
   实现后必须补「切换样式后仍停在同一 Tab、页面滚动位置不丢」的测试。
5. 记账按钮：与导航栏完全解耦（第六节）。按钮继续由壳层渲染为右下角浮动按钮，
   底部偏移按样式声明的 `occupiedHeight` 推算；样式不得在按钮落点上安排内容。

## 六、记账按钮与底部导航的关系（已确认解耦）

**决策（D5）：记账按钮与底部导航栏完全分开。** 按钮是按钮，导航是导航；样式实现不得在栏内
或栏上安排记账按钮，后续新增样式也必须避开按钮区域、不占用其落点。这条边界同时排除了
「底部凸起/内嵌按钮」这一类会与记账按钮抢占同一区域的样式设计。

因此样式契约里**不提供**「主操作落点」字段：按钮始终由壳层渲染为右下角浮动按钮，
样式只声明自己的几何事实，壳层据此推算两处偏移，从而在「按钮与导航解耦」的前提下
仍然不会互相遮挡。

### 6.1 壳层如何避免与样式重叠

| 壳层用途 | 计算方式 |
|---|---|
| 根页面列表避让（`veriRootPageListPadding`） | `(extendBody ? occupiedHeight : 0) + listBottomGap` |
| 记账按钮底部偏移 | `(extendBody ? occupiedHeight : 0) + 16` |

- **停靠样式**：`extendBody = false`，`Scaffold` 已为栏让位，按钮维持现在的 `bottom: 16`，
  行为与观感零变化。
- **悬浮样式（未来）**：`extendBody = true`，内容延伸到栏背后，按钮被抬到栏上方，
  不会压在胶囊或浮层上。

保持不变、且样式无法触及的按钮语义：

- 点击按 `FabActionMode` 决定手动记账或 AI，长按走 AI；
- 仅首页显示，进出带缩放淡入；
- 圆角方形 + `colorScheme.primary` + `add_rounded` + tooltip；
- 样式实现不接收按钮回调，也不持有 Controller。

### 6.2 记账按钮自身造型

「按钮长什么样」属于独立的外观项，与导航样式正交，两者互不影响。本轮**不做**造型偏好，
按钮维持现状；若后续要做（圆形、纯图标、长条等），按新的外观设置项单独设计，
不放进导航样式契约，也不要求更换导航样式。

### 6.3 已排除的方案

- 按钮嵌进导航栏（栏内居中、栏上凸起或缺口）：与 D5 冲突，不再考虑；
- 按钮造型随导航样式变化：会让「换按钮形状」被迫换整条导航，把两个独立偏好绑在一起；
- 样式声明按钮落点、按钮造型另设偏好（本方案早期草案 S2）：虽然技术上可行，
  但与 D5 的「按钮不进导航栏区域」相比多一层无收益的抽象，已废弃。

## 七、设置页入口与样式选择页

### 7.1 设置页改动（方案 A）

- 「外观」分组的 `VeriCard` 内新增一行（位于主题色之后）：

```dart
SettingsRow(
  icon: Icons.space_dashboard_outlined,
  title: l10n.navigationStyleLabel,
  trailing: _navStyle.label(l10n),
  trailingIcon: Icons.chevron_right,
  onTap: _pickNavigationStyle,
)
```

- 页面状态新增 `_initialNavStyle` / `_navStyle` 两个字段，并同步三处：
  `_isDirty`、`_save()`（经 `saveAppPreferencesDraft` 新参数）、`_saveAndExit()` 的基线更新。
- `_pickNavigationStyle` 使用 `Navigator.push<NavigationStylePreference>` 等待返回值；
  返回非空时只更新页面草稿，不写 Controller。
- 可选改进（需用户确认后再做）：设置页现有 12 个字段的草稿比较散落在三处，容易漏改。
  可将其收敛为一个页面级草稿对象。该重构与本次需求无关，默认不做。

### 7.2 样式选择页

`NavigationStyleSettingsPage`，页面遵循全屏编辑页规范：

- `Scaffold > SafeArea > VeriPage`，`VeriHeader(showBack: true)` +
  `SaveHeaderAction`；`UnsavedChangesGuard(isDirty, onSave, popResult: () => _draft, exitController)`，
  保存动作经 `_exitController.exit(result: () => _draft)` 回传选中值。
- 列表每个样式一张 `VeriCard`：
  - 上半为预览：固定高度容器 + `MediaQuery.removePadding(removeBottom: true)`（预览不需要系统手势条留白）
    + `IgnorePointer(child: style.buildBar(context, spec.copyWith(onSelect: null)))`，
    预览使用真实 l10n 标签与真实表面色。
  - 下半为名称 + 说明 + 选中标记（`Icons.check_circle`，颜色取 `colorScheme.primary`）。
  - 整卡可点，点选只更新页面草稿。
- 预览不得引入模糊/玻璃；卡片与预览容器保持不透明实色。
- 窄屏（360dp）与大字号下预览不得溢出：预览容器按 `LayoutBuilder` 约束宽度，
  条目文案沿用底栏的省略策略。

## 八、持久化

| 项 | 内容 |
|---|---|
| 模型 | `lib/app/models/preferences.dart` 新增 `enum NavigationStylePreference { docked }`，含 `id`、`label(AppLocalizations)`、`fromStorage`（未知值回退 `docked`） |
| KV 键 | `verifin.nav_style.v1`（加入 `veri_fin_controller.dart` 顶部的键表） |
| Controller | 内存字段 + 只读 getter + `ValueNotifier<NavigationStylePreference> navigationStyleListenable` |
| 加载 | `_loadPreferences()` 读取并解析 |
| 提交 | `saveAppPreferencesDraft(...)` 增加 `navigationStylePreference` 参数，与其它外观偏好同一批次原子写入 |
| 重置 | `resetAllData()` 删除该键、恢复 `docked`、更新 notifier（与主题、触感一致） |
| 备份 | **不进** `exportDataJson` / `importDataJson`；导入备份不改动本机样式（D2） |
| 初始化数据 | 与语言一致：账目初始化不改动导航样式 |

注意：`themePreference`、`hapticsEnabled`、`assetAccountViewMode` 等外观偏好目前在备份 JSON 内，
导航样式选择「不进备份」属于有意偏离，理由是它没有任何数据语义、纯设备呈现偏好，
与语言/数字键盘布局同类。实施时必须在 `docs/dev/tech-decisions.md` 的偏好与备份范围表里写明。

## 九、测试矩阵

### 契约与注册表

- `NavigationStylePreference` 的每个 `id` 都能在注册表找到实现（防持久化标识漂移）；
- 未知/空 id 回退默认样式；
- 每个样式都必须通过的契约测试（对注册表逐项参数化）：
  - 不出现 `BackdropFilter`；
  - 条目带稳定 key `<prefix>_nav_item_<i>`，且 TalkBack 能读到选中态（`Semantics(selected:)`）；
  - 360dp 与 393×852 下不溢出、不吃掉系统安全区下限；
  - `layout` 的避让值与实际占用高度自洽（列表末项不被遮挡）。

### 持久化

- 默认值、保存后落 KV、冷启动读取、非法值回退；
- 保存前不改变 Controller（草稿语义）、取消不改动、改回原值后不弹未保存提示；
- `resetAllData()` 后恢复默认样式；
- 导入旧备份/他人备份不会改动本机样式。

### 壳层与状态

- 切换样式后当前 Tab、页面滚动位置、`PageController` 状态不丢；
- `extendBody`、避让 padding、切页弹簧时长随样式变化；
- 记账按钮在任一样式下都不与导航栏重叠，且仍只在首页显示、点击与长按语义不变；
- 四目的地、返回键、小组件路由、快捷入口行为在任一样式下不变；
- 中断切页后底栏仍按实际落点对齐（现有回归用例改为样式无关定位后继续通过）。

### 设置页与选择页

- 设置页选择后返回，「外观」行 trailing 显示新样式名，但 Controller/KV 未变；
- 设置页保存后才落 KV；不保存退出则丢弃；
- 选择页预览不可点击、无模糊；
- 选择页未修改直接返回不弹提示；修改后返回弹出保存/不保存/取消，三者行为符合 Guard 规范。

### 命令

提交前执行 `dart format .`、`flutter analyze`、`flutter test`。
本机当前工具链为 Flutter 3.44.8 / Dart 3.12.2，而 CI 固定 Flutter 3.47.2；
最终回归以 CI 版本为准，真机确认底栏安全区与流畅度。

## 十、分阶段实施

| 阶段 | 内容 | 交付与验证 |
|---|---|---|
| 阶段 1 | 契约 + 注册表 + 停靠样式登记 + 壳层按样式取布局/时长 + 测试改为样式无关定位 | **用户可见行为零变化**；`flutter analyze`、全量 `flutter test` 通过；独立提交 |
| 阶段 2 | `NavigationStylePreference` 持久化 + 设置页入口 + 样式选择页（此时只有停靠样式可选） | 选择页流程可用、草稿语义正确；独立提交 |
| 阶段 3 | 第二种样式视觉方向确认后实现 `buildBar`，并补该样式的契约测试 | 需用户先确认视觉方案 |

阶段 1 与阶段 2 是本次授权范围；阶段 3 另行确认。记账按钮造型偏好不在本轮范围（见 6.2）。

## 十一、文档同步清单（随实现提交）

- `AGENTS.md`：根导航相关表述（现写作「停靠底栏」）改为「默认停靠样式 + 可注册样式」，
  并保留材质与安全区硬约束。
- `docs/design-system.md`：§导航与输入拆分为「全局不可违反」与「样式专属」；
  更新表面材质表行与设置分组一行（外观组新增导航样式）。
- `docs/ui-guidelines.md`：§根导航说明样式契约、避让来源与选择页入口。
- `docs/dev/components.md`：新增 `VeriRootNavigationStyle` / `VeriRootNavigationLayout` /
  `VeriRootNavigationSpec` / 选择页条目；改写 `VeriRootNavigation` 条目为 `VeriDockedRootNavigation`。
- `docs/dev/tech-decisions.md`：偏好与备份范围表写明导航样式为设备本地、不进备份。
- `docs/product.md`：「底部导航固定为四个 Tab」补充「样式可选、目的地固定」。
- `docs/acceptance-checklist.md`：新增导航样式选择与切换验收项。
- `CHANGELOG.md`：用户可见（设置入口与新样式能力）时写入 `## [Unreleased]`。

## 十二、风险与反方意见

- **过度设计风险**：当前只有一种样式，抽象可能覆盖不到真实差异。缓解：接口只覆盖已确证的
  三类差异（底部占用与避让、`extendBody`、动画时长），且阶段 1 零行为变化、可低成本回滚。
  若阶段 3 落地时发现接口缺项，属于正常迭代，不应反向把接口设计成「支持一切未来可能」。
- **规范碎片化风险**：样式变多后，测试与文档容易各写一套。缓解：把全局硬约束
  （不透明实色、无模糊、`colorScheme.primary` 选中态、安全区下限、TalkBack 选中语义、
  稳定条目 key）做成对全部样式参数化的契约测试。
- **设计目标稀释风险**：多样式可能让界面失去「高效率、干净直接」的一致性。
  建议把样式数量控制在同一设计语言的 2–3 个变体内，不做外观插件市场。
- **状态回归风险**：换样式时若重建了 `PageController` 或壳层 State，会丢失当前 Tab。
  缓解：样式监听只包裹导航栏与布局参数，并补状态保持测试。

## 十三、待确认

1. 阶段 2 中样式选择页的名称与 l10n 中文/英文文案定稿。
2. 是否允许本方案把「设置页草稿字段收敛」列为可选后续项（默认不做）。
3. 第二种样式的视觉方向（阶段 3 的输入）。
