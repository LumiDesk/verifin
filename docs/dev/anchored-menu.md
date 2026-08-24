# 锚点菜单组件

`VeriAnchoredMenuAnchor` 是 Veri Fin 的轻量上下文菜单入口。菜单贴近触发控件出现，支持图标、标题、副标题、分割线、选中/禁用状态、任意递归层级，以及从被点击行原位展开的容器变换。

实现位于 `lib/app/common_widgets_menu.dart`，经稳定入口 `lib/app/common_widgets.dart` 导出。页面不要直接导入 part 文件。

## 适用范围

适合：

- 页面右上角的少量更多操作；
- 视图、排序、筛选等短枚举；
- 需要就地展示当前值的轻量设置；
- 最多只有少量选项、无需搜索的递进菜单。

不适合：

- 账户、分类、货币等长列表或可搜索列表；
- 连续输入、复杂表单和完整草稿编辑；
- 删除、覆盖数据等危险确认；
- 需要大段说明或容易超出屏幕的内容。

这些场景继续使用对应 Picker Sheet、普通 Sheet、Dialog 或全屏编辑页。

## 公共 API

### `VeriAnchoredMenuButton`

Header 图标入口的快捷封装。

| 参数 | 类型 | 默认值 | 作用 |
|---|---|---:|---|
| `icon` | `IconData` | 必填 | 触发按钮图标 |
| `tooltip` | `String` | 必填 | Tooltip、弹层语义标签 |
| `entries` | `List<VeriMenuEntry>` | 必填 | 根菜单内容 |
| `width` | `double` | `224` | 根菜单宽度 |
| `submenuWidth` | `double` | `232` | 未单独覆盖时的子菜单宽度 |

### `VeriAnchoredMenuAnchor`

任意触发器入口。`builder` 会获得 `openMenu` 与 `menuOpen`，调用方可据此改变按钮视觉状态。

| 参数 | 类型 | 默认值 | 作用 |
|---|---|---:|---|
| `entries` | `List<VeriMenuEntry>` | 必填 | 根菜单内容 |
| `builder` | `VeriMenuAnchorBuilder` | 必填 | 构造按钮或其他触发控件 |
| `semanticLabel` | `String` | 必填 | 弹层语义标签 |
| `width` | `double` | `224` | 根菜单宽度 |
| `submenuWidth` | `double` | `232` | 默认子菜单宽度 |

### `VeriMenuItem`

叶子操作或递进父项。

| 参数 | 类型 | 默认值 | 作用 |
|---|---|---:|---|
| `id` | `String` | 必填 | 同一菜单树内稳定、唯一的动画标识 |
| `title` | `String` | 必填 | 主标题 |
| `icon` | `IconData?` | `null` | 当前项自己的图标 |
| `subtitle` | `String?` | `null` | 当前值或补充说明 |
| `selected` | `bool` | `false` | 使用主色文字与勾标记 |
| `enabled` | `bool` | `true` | 是否可点击 |
| `foregroundColor` | `Color?` | `null` | 语义颜色，如危险操作红色 |
| `onPressed` | `VoidCallback?` | `null` | 叶子操作回调 |
| `children` | `List<VeriMenuEntry>` | 空列表 | 非空时作为递进父项 |
| `submenuWidth` | `double?` | `null` | 覆盖该项打开的子菜单宽度 |

启用项应提供 `onPressed` 或非空 `children`。父项点击只进入下一级，不执行 `onPressed`。

### `VeriMenuDivider`

用于把相关操作分组。不要连续放置分割线，也不要放在菜单首尾。

## 基础用法

下例中的 `*Label` / `*Tooltip` 变量表示调用方已经通过 `AppLocalizations` 取得的本地化文案。

```dart
VeriHeader(
  title: pageTitle,
  actions: <Widget>[
    VeriAnchoredMenuButton(
      icon: Icons.more_vert_rounded,
      tooltip: moreTooltip,
      width: 220,
      submenuWidth: 208,
      entries: <VeriMenuEntry>[
        VeriMenuItem(
          id: 'view',
          icon: Icons.grid_view_rounded,
          title: viewLabel,
          subtitle: currentViewLabel,
          submenuWidth: 196,
          children: <VeriMenuEntry>[
            VeriMenuItem(
              id: 'view-list',
              title: listViewLabel,
              selected: viewMode == ViewMode.list,
              onPressed: () => setState(() => viewMode = ViewMode.list),
            ),
            VeriMenuItem(
              id: 'view-card',
              icon: Icons.grid_view_rounded,
              title: cardViewLabel,
              selected: viewMode == ViewMode.card,
              onPressed: () => setState(() => viewMode = ViewMode.card),
            ),
          ],
        ),
        const VeriMenuDivider(),
        VeriMenuItem(
          id: 'settings',
          icon: Icons.settings_rounded,
          title: settingsLabel,
          onPressed: openSettings,
        ),
      ],
    ),
  ],
)
```

## 自定义触发器

```dart
VeriAnchoredMenuAnchor(
  semanticLabel: filterLabel,
  width: 204,
  submenuWidth: 196,
  entries: entries,
  builder: (context, openMenu, menuOpen) => OutlinedButton.icon(
    onPressed: openMenu,
    icon: Icon(
      menuOpen ? Icons.close_rounded : Icons.filter_list_rounded,
    ),
    label: Text(filterLabel),
  ),
)
```

调用方不得自行再包 `showMenu`、`OverlayEntry` 或 `showGeneralDialog`。定位、遮罩、返回和关闭由组件统一负责。

## 多级菜单

`children` 可以递归嵌套。组件没有写死二级上限；但产品设计上应保持路径可理解，通常不超过四级。

```dart
VeriMenuItem(
  id: 'workspace',
  icon: Icons.workspaces_rounded,
  title: workspaceLabel,
  children: <VeriMenuEntry>[
    VeriMenuItem(
      id: 'layout',
      title: layoutLabel,
      children: <VeriMenuEntry>[
        VeriMenuItem(
          id: 'card-style',
          title: cardStyleLabel,
          children: <VeriMenuEntry>[
            VeriMenuItem(
              id: 'compact-card',
              title: compactCardLabel,
              onPressed: selectCompactCard,
            ),
          ],
        ),
      ],
    ),
  ],
)
```

每一级父项的 `id` 必须稳定。不要用本地化标题、列表索引或运行时随机值充当 id。

## 宽度规则

解析优先级：

1. 当前父项的 `VeriMenuItem.submenuWidth`；
2. Anchor/Button 的 `submenuWidth`；
3. 组件默认值 `232`。

根菜单只读取 Anchor/Button 的 `width`。所有宽度都会按弹层当前实际布局约束限制在屏幕可用范围内，安全下限为 `168`；窗口尺寸变化后不得继续使用旧 `MediaQuery` 尺寸把菜单定位到屏幕外。

宽度以最短的不换行标题为依据，不应为了和其他页面相同而强行拉宽。标题与右侧箭头之间只保留必要弹性空间。

## 图标与对齐

图标占位按菜单项自身决定：

- 当前项有 `icon` 才预留图标列；
- 纯文本项直接从面板内容边距开始；
- 同组标题或其他项有图标，不会让纯文本项缩进；
- 标准 Material 图标直接传 `IconData`；分类和账户等领域图标仍应走领域组件，不要把领域模型塞进菜单模型。

## 状态所有权

菜单是受控展示组件：

- `selected`、`subtitle`、`enabled` 由页面状态决定；
- 叶子项选中后，菜单先完成关闭动画，再调用 `onPressed`；
- 回调修改状态后，页面重建新的 `entries`；
- 菜单自身不读取 Controller，也不持久化业务值。

## 动画与层级不变量

以下行为属于组件设计语言，修改时必须保留：

- 子菜单从被点击行的累计实际位置展开；
- 被点击行连续变为子菜单 Header，返回时反向收回；
- 展开时宽度、高度、圆角和选项显隐共同过渡；
- 完整祖先卡片栈始终保留，不能只绘制最近父层；
- 每远离当前层一级，祖先卡片约缩小 3%，最低 88%；
- 祖先表面逐级向黑色混合，保持完全不透明；
- Android/系统返回只退一级，根层才关闭菜单；
- 点击菜单外部关闭整棵菜单；
- 根弹层打开/关闭使用平滑淡入与轻微缩放。

子菜单前进时长为 280ms，返回为 260ms，根弹层过渡为 240ms。不要在页面调用点覆写动画。

## 视觉令牌

| 项目 | 当前规则 |
|---|---|
| 根菜单默认宽度 | `224` |
| 子菜单默认宽度 | `232` |
| 最小安全宽度 | `168` |
| 单行项最小高度 | `44` |
| 带副标题项最小高度 | `52` |
| 面板圆角 | `veriRadiusXl`（24） |
| Hover 圆角 | `veriRadiusLg`（12） |
| Hover 外边距 | 水平 8、垂直 3 |
| 项目内容内边距 | 水平 12、垂直 6 |
| 标题 | `titleSmall`（13px） |
| 副标题 | `labelMedium`（11px） |
| 选中颜色 | `veriRoyal` |

## 可访问性与国际化

- `semanticLabel` 和按钮 `tooltip` 必须使用本地化文案；
- 菜单项标题、副标题由调用方通过 `AppLocalizations` 提供；
- 禁用与选中状态会写入 Semantics；
- 单行项保持至少 44px 触控高度；
- 标题应短到无需换行，过长时组件会单行省略；
- 不在组件内部硬编码业务文案。

## 测试要求

通用行为集中在 `test/anchored_menu_test.dart`，目前覆盖：

- 图标、标题、副标题、分割线和选中样式；
- 宽度、边距、触控高度和圆角 Hover；
- 纯文本项不继承其他项的图标占位；
- 子菜单从点击行原位展开；
- 根、默认子菜单和单项子菜单宽度覆盖；
- 点击外部关闭、叶子回调和系统返回；
- 窗口尺寸改变时按弹层实际约束定位，菜单不越出左右边缘；
- 四级路径、逐级返回和累计展开原点；
- 四级状态保留四张卡片，祖先缩放按深度递增。

修复交互或视觉缺陷时，必须补能在修复前失败的断言。页面接入还应覆盖该页面的业务回调和状态更新。

## 维护检查清单

- 新增菜单前是否确认它比 Sheet/Dialog 更合适？
- id 是否稳定且在树内唯一？
- 用户可见文案是否已完成中英文 ARB？
- 纯文本和图标项是否各自对齐？
- 宽度是否只够内容使用，没有留下大段空白？
- 深层菜单是否保留全部祖先层并可逐级返回？
- 叶子回调是否只更新页面状态或执行明确操作？
- 是否运行 `flutter analyze` 和相关 Widget 测试？
