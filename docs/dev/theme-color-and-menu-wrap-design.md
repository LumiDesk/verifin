# 主题色与锚点菜单换行改造方案

状态：**调研完成，等待确认；尚未修改功能代码**。

本方案针对两个需求：

1. 增加主题色设置，支持 Android 系统动态颜色和用户自定义颜色，并让主要交互统一使用用户选择的主题色。
2. 修复 `设置 → 货币单位样式` 锚点菜单在较窄屏幕上出现横向省略号的问题；菜单项有多行内容时正常换行、左对齐，并保持菜单定位和动画正确。

## 一、当前实现基线

### 1. 货币单位样式的调用链

设置页在 [`lib/pages/settings_page.dart`](../../lib/pages/settings_page.dart) 中使用受控的 `VeriAnchoredChoice<MoneyUnitStyle>`：

```dart
VeriAnchoredChoice<MoneyUnitStyle>(
  values: MoneyUnitStyle.values,
  selected: _moneyUnitStyle,
  labelOf: (value) => _moneyUnitStyleLabel(l10n, value),
  iconOf: ...,
  onSelected: (value) => setState(() => _moneyUnitStyle = value),
  builder: (context, openMenu, menuOpen) => SettingsRow(
    title: l10n.moneyUnitStyleLabel,
    trailing: _moneyUnitStyleLabel(l10n, _moneyUnitStyle),
    onTap: openMenu,
  ),
)
```

`VeriAnchoredChoice<T>` 位于 [`lib/app/common_widgets_menu.dart`](../../lib/app/common_widgets_menu.dart)，只是把枚举值转换为 `VeriMenuItem`，底层仍是通用的 `VeriAnchoredMenuAnchor`。该组件还被主题、语言、账户类型、备份频率、交易筛选、周期规则等页面复用。

实际菜单的绘制链为：

```text
VeriAnchoredMenuAnchor
  → showGeneralDialog
  → _VeriAnchoredMenuRoute
  → _VeriMenuPanel
  → _VeriMenuItemRow
```

菜单公共规范记录在 [`docs/dev/anchored-menu.md`](anchored-menu.md)，稳定入口是 [`lib/app/common_widgets.dart`](../../lib/app/common_widgets.dart) 的 part 导出。

### 2. 菜单省略号的直接原因

[`_VeriMenuItemRow`](../../lib/app/common_widgets_menu.dart) 当前对标题和副标题都强制单行：

```dart
Text(
  item.title,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
)
```

副标题也使用相同规则。因而菜单不会换行，只会在可用宽度不足时显示 `…`。

同时，菜单宽度计算 `_veriMenuItemWidth` 使用 `TextPainter` 测量基础 `titleSmall` / `labelMedium`，而真正绘制时又额外使用了 `FontWeight.w700` / `w600`。测量样式和绘制样式不完全一致，窄屏或英文文案下会进一步放大可用宽度不足的问题。

菜单行高度与子菜单展开原点目前由固定的 `_veriMenuEntryExtent` 估算（单行 50、带副标题 58）。一旦允许标题换行，不能只删除 `maxLines`，还必须让高度估算、滚动最大高度、父项原点和祖先菜单栈使用同一套实际文本测量，否则可能出现子菜单展开位置偏移或层间重叠。

当前文档还明确写着“标题应短到无需换行，过长时组件会单行省略”，这条约定需要在实现后同步改为允许受控换行。

## 二、主题色方案

### 1. 用户体验

建议在设置页“外观”分组中增加“主题色”一行，继续遵循设置页现有的草稿保存模式：用户在设置页选择或调整颜色只更新页面草稿，点击统一“保存”后才写入 Controller、KV 和全局主题；取消或返回并选择“不保存”时丢弃草稿。

主题色提供两个模式：

| 模式 | 行为 |
|---|---|
| 跟随系统 | Android 12 及以上使用系统壁纸生成的 Material 动态颜色；系统不提供动态颜色时回退到 Veri Fin 默认蓝色。 |
| 自定义 | 用户选择一个种子颜色，由 Material 3 `ColorScheme.fromSeed` 为浅色和深色模式生成配套颜色。 |

“自由调整”建议使用一个项目内的颜色编辑 Sheet，而不是引入依赖。编辑器包含：

- 当前颜色预览；
- 色相选择；
- 饱和度/明度选择；
- 可选的十六进制颜色输入，用于精确复现颜色；
- 确定、取消两个明确动作。

颜色编辑器只返回颜色值，不直接写 Controller。非法或透明颜色在输入层归一化/拒绝，持久化只保存不透明 ARGB 值。

系统动态颜色建议优先使用 Flutter 3.47.2 已提供的 `ThemeData(useSystemColors: true)`，不先新增第三方依赖。该参数在当前 Flutter SDK 中会让支持的平台系统颜色覆盖 `ColorScheme` 及主要 Material 按钮主题；Android 12 以下或不支持的平台自然回退。自定义模式使用 `ColorScheme.fromSeed(seedColor: ...)`。

### 2. 数据模型与持久化

新增一个明确的偏好模型，建议放入 [`lib/app/models/preferences.dart`](../../lib/app/models/preferences.dart)：

```dart
enum ThemeColorMode { system, custom }

class ThemeColorPreference {
  const ThemeColorPreference({
    required this.mode,
    required this.customColorValue,
  });

  final ThemeColorMode mode;
  final int customColorValue; // 不透明 ARGB
}
```

实际字段名可以在实现时按现有命名风格确定，但必须提供：

- 稳定的 `fromStorage` / `encode`；
- 缺失、非法和旧版本值的默认回退；
- 不透明颜色校验；
- 颜色值不受当前亮暗主题影响，同一个种子色在浅色/深色下分别生成方案。

Controller 需要新增：

- KV 键，例如 `verifin.theme_color.v1`；
- 内存字段和只读 getter；
- 独立 `ValueNotifier<ThemeColorPreference>`，避免主题色变化扩大所有业务状态的无差别通知；
- `_loadPreferences`、`resetAllData`、导入/导出和恢复路径；
- `saveAppPreferencesDraft` 的主题色参数，保证和设置页其它外观偏好同一批次原子写入。

当前源码的 `exportDataJson` 已导出 `themePreference`，导入也会覆盖它；因此主题色应保持同一套偏好语义，加入备份 JSON 并对旧备份按默认蓝色回退。实现时需要同步 `docs/dev/tech-decisions.md` 的偏好/备份范围说明和备份测试。

### 3. 主题构建入口

当前主题在 [`lib/app/app_theme.dart`](../../lib/app/app_theme.dart) 的 `buildVeriFinTheme(Brightness)` 中构建，`lib/main.dart` 的 `MaterialApp` 同时传入 light/dark 两套主题。当前 `veriRoyal` 被直接写入 `ColorScheme.primary`、按钮、FAB、底栏、Chip、输入框聚焦边框等多个主题字段。

建议把入口扩展为：

```dart
ThemeData buildVeriFinTheme(
  Brightness brightness, {
  ThemeColorPreference colorPreference = ThemeColorPreference.defaultValue,
})
```

构建规则：

1. `system` 模式：保留默认 seed 作为不支持动态色设备的回退，并启用 `useSystemColors: true`。
2. `custom` 模式：以用户颜色作为 `colorSchemeSeed`，不启用系统动态色覆盖。
3. 页面背景、卡片、导航和弹层仍然保持不透明实色；主题色只改变强调色角色，不重新引入玻璃、透明叠层或渐变材质。
4. `onPrimary`、`primaryContainer`、`onPrimaryContainer` 等配套角色由 Material 3 方案生成，并对按钮、选中态和文字进行对比度检查。
5. 收入、支出、转账、提醒等领域语义色继续保持独立的 `veriSemantic` 体系，不因为主题色改变而把支出红色或收入青绿色误染成主题色。

`VeriFinApp` 需要在现有主题/语言 `ValueListenableBuilder` 外或同层监听主题色偏好，并把同一个快照传入 light/dark 两个 `buildVeriFinTheme`。数据库错误页和独立小组件配置入口没有 Controller 时继续使用默认主题；如果产品希望它们也跟随用户主题色，再单独读取共享 KV，不能复制另一套主题逻辑。

### 4. 主题色传播范围

本次不做机械地把所有颜色替换成主题色，而是按颜色职责审查：

#### 应迁移到 `Theme.of(context).colorScheme.primary` 或相关角色的部分

- 根底部导航选中图标、选中文字和切换扫过动效：`root_navigation.dart`、`veri_bottom_bar.dart`；
- 快捷记账按钮、主要 FilledButton、输入框聚焦边框；
- `VeriAnchoredMenu` 的选中标题、选中勾、选中/聚焦背景；
- SettingsRow、选择器、列表选中态、页面入口和操作性图标；
- 主题色背景上的前景文字或图标统一使用 `onPrimary`；
- 以 `veriRoyal` 表示品牌/主操作的图表线、进度环和绘制组件。

#### 继续使用固定/语义色的部分

- 收入、支出、转账、提醒、错误和成功等业务语义色；
- 账户品牌 SVG 和通用账户图标中已有的领域色；
- 需要区分数据序列的图表辅助色；
- 黑色图片裁剪遮罩、白色删除图标等与主题无关的系统控件颜色；
- 页面画布和卡片表面令牌，除非后续另有设计确认。

#### 重点审查清单

当前 `veriRoyal` 在多个页面和公共组件中直接出现，尤其包括：

- `common_widgets_*`、`common_widgets_menu.dart`、`root_navigation.dart`、`veri_bottom_bar.dart`；
- `shell.dart`、`sheets.dart`、`entry_sheets.dart`；
- 首页、预算、报表、资产、账户、导入、退款、应用锁和 AI 页面；
- `chart_painters.dart`、`ledger_math.dart`、`feedback.dart` 等无直接 BuildContext 的绘制/取色路径。

实现时逐个判断调用点：有 `BuildContext` 的 Widget 读取 `colorScheme`；CustomPainter/纯函数通过参数接收 `primary` 或对应角色；不能在纯函数里新增全局可变“当前主题色”，也不能把语义色参数误替换成主色。

同时审查少量组件默认参数（如 `VeriIconBox`、`CategoryIconBox`、`VeriBottomBar`）和 `const Icon(color: veriRoyal)`，避免默认值仍然把一部分页面锁死为蓝色。保留默认值的公共 API 时，应用调用点必须显式传入当前主题角色，并用测试锁定动态主题下的颜色。

### 5. 主题色测试与验收

至少补充：

- 模型/存储：默认值、非法值、ARGB 往返、冷启动读取、重置；
- Controller：设置页保存前不改变 Controller，保存后更新 Controller 和 `ValueNotifier`，重启后保持；
- 主题构建：默认蓝色、自定义种子色、浅色/深色的 `primary` 和 `onPrimary`，系统模式启用回退路径；
- Widget：底栏选中文字、菜单选中标题/勾、FAB、主按钮和输入框焦点边框随主题色变化；收入/支出/错误语义色不随主题色误变；
- 备份：新字段导出/导入，旧备份缺字段仍能恢复默认；
- Android：API 36 模拟器修改系统壁纸/系统颜色后重启应用，验证系统模式实际变化；无动态色支持的环境验证固定回退；
- 浅色、深色、393×852、360dp、大字号和高对比度场景。

## 三、锚点菜单换行修复方案

### 1. 修复目标

- 菜单标题和副标题不再因为正常宽度不足显示省略号；
- 文案可以自然换成两行或多行，文本保持左对齐；
- 仍保留图标列、右侧勾/箭头、44px/52px 最小触控高度；
- 根菜单和递进菜单都不越出屏幕，外部点击、系统返回和已有动画语义不变；
- 祖先菜单栈的展开原点、缩放和压暗效果不因换行而错位。

### 2. 组件内部改造

改动集中在 [`lib/app/common_widgets_menu.dart`](../../lib/app/common_widgets_menu.dart)：

1. `_VeriMenuItemRow` 的标题和副标题移除 `maxLines: 1` 与 `TextOverflow.ellipsis`，使用自然换行和左对齐；对于极端的超长不可断词，使用不显示省略号的裁剪策略，不能恢复横向 `…`。
2. `_veriMenuItemWidth` 用与实际绘制相同的文字样式（包括粗细、字号、文本缩放）测量单行理想宽度；理想宽度仍受屏幕左右安全边距约束。
3. 菜单宽度被屏幕约束后，用同一个实际内容宽度计算标题/副标题的换行高度。菜单行高度、`_veriMenuEntryExtent`、`_veriMenuPanelExtent`、父项展开原点和祖先层的累计高度必须共享这套测量结果。
4. 文本区继续放在 `Expanded` 中，尾部图标保留固定宽度；多行文本不挤压勾选图标，图标和文字垂直居中，文字列自身保持左对齐。
5. 保留单行菜单的现有宽度、圆角、面板材质、触控高度和动画时长；只有发生换行时增加行高。
6. 不在 `settings_page.dart` 为货币单位样式单独复制一套菜单。该修复必须覆盖所有 `VeriAnchoredChoice` 和 `VeriAnchoredMenuAnchor` 调用点。

### 3. 测试与文档同步

在 `test/anchored_menu_test.dart` 增加回归断言：

- 360dp 宽度下英文 `Symbol after (100 $)` 不出现 `…`；
- 标题换行后存在两行 `Text` 布局，文本左边缘保持一致；
- 带图标、选中勾、无图标和带副标题的项均不发生水平溢出；
- 菜单高度、滚动和点击命中区域正确；
- 换行项作为递进父项时，子菜单仍从该行实际底部展开；
- 393×852、360dp、大字号和中英文都通过；
- 多级祖先层测试继续通过，避免只修当前层而破坏累计原点。

同步修改 [`docs/dev/anchored-menu.md`](anchored-menu.md)：

- 删除“标题应短到无需换行、过长时单行省略”的限制；
- 记录菜单在宽度约束下自然换行，宽度和行高按实际文本测量；
- 更新视觉令牌和测试清单。

## 四、预计修改范围

主题色主线：

- `lib/app/models/preferences.dart` 或新增主题偏好模型文件；
- `lib/app/app_theme.dart`；
- `lib/app/veri_fin_controller.dart`、`veri_fin_controller_state.dart`、`veri_fin_controller_ops.dart`；
- `lib/main.dart`、必要时 `widget_configuration_page.dart`；
- `lib/pages/settings_page.dart` 和新的颜色编辑 Sheet/组件；
- `lib/app/common_widgets_*`、`root_navigation.dart`、`veri_bottom_bar.dart`、`chart_painters.dart` 及实际使用主题主色的页面调用点；
- `lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb` 及生成文件；
- Controller、主题、备份、导航和相关页面测试；
- `docs/design-system.md`、`docs/dev/components.md`、`docs/dev/tech-decisions.md`、`CHANGELOG.md`。

菜单主线：

- `lib/app/common_widgets_menu.dart`；
- `test/anchored_menu_test.dart` 及必要的页面设置测试；
- `docs/dev/anchored-menu.md`、组件注册表中有关菜单的说明。

两条主线应分开提交，先完成菜单换行回归，再完成主题色传播，便于定位视觉回归；如果你希望一次性合并发布，也可以在同一分支中按两个独立提交完成。

## 五、验收标准

### 主题色

- 设置页可以在“跟随系统”和“自定义”之间切换；自定义颜色可调整并保存。
- 应用重启、切换浅色/深色主题后设置仍然有效；旧版本/旧备份缺少字段时回退到当前 Veri Royal 默认色。
- Android 12+ 系统动态色可驱动 Material 主色；不支持动态色时无异常且有固定回退。
- 底部导航选中图标和文字、菜单选中项、勾选图标、FAB、主按钮、焦点边框等主要交互使用当前主题色。
- 收入/支出/转账/提醒/错误等语义颜色不被主题色覆盖；品牌账户图标和不透明表面规则不变。
- 不出现仍锁定旧 `veriRoyal` 的主要交互点，不引入新的裸 `Color(0x...)` 或透明/玻璃材质。
- 浅色和深色下主色与前景色满足可读性要求，且大字号和窄屏没有布局回归。

### 锚点菜单

- 货币单位样式菜单在当前截图所示设备尺寸及 360dp 宽度下不再出现横向省略号。
- 多行标题/副标题自然换行且左对齐，选中勾和图标仍在正确位置。
- 菜单不会越出左右边缘，不会因换行造成子菜单原点、祖先卡片栈或返回动画错位。
- 所有复用该组件的页面和现有菜单行为测试通过。

## 六、需要你先确认的两点

1. **自定义主题色编辑器**：是否接受“色相 + 饱和度/明度 + HEX 输入”的自由颜色编辑方式？这是无需引入第三方依赖、又能满足精确调色的方案。
2. **主题色的备份语义**：当前源码会把 `themePreference` 放进导出/导入 JSON。是否按同一规则让主题色也随备份恢复？本方案建议保持一致；语言、应用锁、AI 密钥等仍不进入备份。

收到确认后，再按本文进入实现阶段；在确认前不修改业务代码、不新增依赖、不运行发布流程。
