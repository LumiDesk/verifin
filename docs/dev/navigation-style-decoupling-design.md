# 底部导航样式契约

根导航把「视觉实现」抽成可注册的**样式**：新增样式只需实现一个 `buildBar`，壳层（页面切换状态机、返回键、快捷入口路由、安全区与避让）保持单份实现。当前注册两个样式——默认的**停靠底栏**和可选的**液态玻璃**。本文件是新增或替换样式前必读的契约。

## 三层拆分

契约只覆盖**已确证存在差异**的维度，避免过度参数化：

1. **条目数据**（样式无关）：`VeriNavigationDestination`，唯一定义在 `veriRootNavigationDestinations`（首页/资产/看板/我的）。
2. **布局描述**（壳层需要知道的全部信息）：`VeriRootNavigationLayout`——`extendBody`、`occupiedHeight`、`listBottomGap`，避让高度由 `contentBottomPadding` 统一推导。
3. **样式实现**（视觉与动效）：`VeriRootNavigationStyle`，实现 `id` / `label` / `description` / `layout` / `switchDuration` / `buildBar`。

`buildBar` 只接收纯数据快照 `VeriRootNavigationSpec`（当前下标、目的地、可空 `onSelect`、`keyPrefix`），**不接触 Controller / KV / Navigator**；样式选择页的预览因此直接复用同一实现（预览把 `onSelect` 置空）。壳层经 `VeriRootNavigationHost` 渲染，测试从这里读 `spec`。

## 注册表与持久化

- 注册表 `veriRootNavigationStyles` 的顺序即样式选择页展示顺序，第一项为默认样式；`veriRootNavigationStyleFor` 对缺失/未知标识一律回退默认样式。
- 偏好枚举 `NavigationStylePreference` 的枚举名即样式标识，存 KV `verifin.nav_style.v1`；设备本地、不进备份、初始化账目时保留、`resetAllData` 恢复默认。新增样式须同时加枚举值与注册项（测试断言两者一一对应）。
- 设置 → 外观 → 导航栏样式进入选择页；点选只改设置页草稿，设置页保存后才落盘。

## 全局硬约束（所有样式必须满足）

- 四个根目的地、切页状态机、返回键与小组件路由完全一致，不随样式变化。
- 停靠样式用不透明实色；液态玻璃是唯一允许模糊/折射的样式，且实现不得外溢到卡片、菜单、弹层或页面背景。
- 选中态取 `colorScheme.primary`；尊重系统安全区下限；用 `Semantics(selected:)` 向读屏软件报告选中态。
- 每个样式必须产出稳定 key：`<前缀>_bottom_nav`、`<前缀>_nav_bar`、`<前缀>_nav_item_<下标>`；测试与无障碍按 key 定位，不依赖几何。
- 切页动画被用户交互打断时按页面实际落点对齐底栏，不能停留在点击时的目标页。
- **记账按钮与导航栏无关**：它由 `shell.dart` 放在右下角浮动（首页才显示），样式不参与、也不得占用其区域；内容延伸到栏背后时，Shell 按样式声明的 `occupiedHeight` 把按钮抬到栏上方。

## 文件划分

| 文件 | 职责 |
| --- | --- |
| `lib/app/root_navigation.dart` | 样式契约、`VeriRootNavigationBody`、`veriRootPageListPadding`；页面侧稳定入口 |
| `lib/app/root_navigation_styles.dart` | 样式注册表与查表函数 |
| `lib/app/root_navigation_docked.dart` | 停靠样式实现 |
| `lib/app/root_navigation_liquid_glass.dart` | 液态玻璃样式实现 |
| `lib/app/veri_bottom_bar.dart` | 停靠样式的条内绘制件 |
| `lib/app/liquid_glass_surface.dart`、`liquid_glass_lens.dart`、`liquid_glass_material.dart`、`shaders/liquid_glass_lens.frag` | 液态玻璃面板、透镜与着色器（只被该样式引用） |
| `lib/pages/navigation_style_settings_page.dart` | 样式选择页 |

## 测试矩阵

- **契约与注册表**：`NavigationStylePreference` 的每个 id 都在注册表找到实现；未知/空 id 回退默认；每个样式通过契约测试（非玻璃样式不出现 `BackdropFilter`，液态玻璃覆盖无着色器降级；条目稳定 key 与 `Semantics(selected:)`；360dp 与 393×852 不溢出；避让值与实际占用高度自洽）。
- **持久化**：默认值、保存后落 KV、冷启动读取、非法值回退；保存前不改 Controller、取消不改动、改回原值后不弹未保存提示；`resetAllData` 后恢复默认；导入备份不改动本机样式。
- **壳层与状态**：切换样式后当前 Tab、页面滚动位置与 `PageController` 状态不丢；`extendBody`、避让 padding、切页弹簧时长随样式变化；记账按钮在任一样式下不与导航栏重叠且仍只在首页显示；四目的地、返回键、小组件路由、快捷入口行为不变。
- **设置页与选择页**：设置页选择后返回时「外观」行显示新样式名但 Controller/KV 未变；保存后才落 KV；选择页预览渲染真实标签与表面色、整块 `IgnorePointer`，点预览等于选中该样式；未修改返回不弹提示，修改后返回弹保存/不保存/取消。

提交前执行 `dart format .`、`flutter analyze`、`flutter test`；真机确认底栏安全区与流畅度。
