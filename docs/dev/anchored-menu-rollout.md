# 锚点菜单页面接入设计

> 状态：已实现并验证。本文定义本轮接入范围与验收标准。

## 目标

把已稳定的 `VeriAnchoredMenuAnchor` / `VeriAnchoredMenuButton` 接入少量高价值页面，替换原生 `PopupMenuButton`、行级动作 Bottom Sheet 和适合就地展开的短枚举，同时保持现有业务流程、草稿保存、危险确认与长列表 Picker 不变。

本轮不追求替换所有 `showOptionSheet`。锚点菜单用于上下文动作和本次明确批准的资产显示设置，不升级为全应用表单选择器。

## 已确认范围

| 编号 | 页面 / 场景 | 当前入口 | 目标 |
|---|---|---|---|
| A1 | 资产页 Header | “资产操作” Bottom Sheet | Header 锚点菜单 |
| A2 | 账本管理行 | 原生 `PopupMenuButton` | 行尾锚点菜单 |
| A3 | 分类管理行 | 点击整行打开动作 Bottom Sheet | 行级两层锚点菜单 |
| A4 | 标签管理行 | 点击整行打开动作 Bottom Sheet | 行级锚点菜单 |
| B1 | 汇率历史行 | 原生单项删除菜单，行主体编辑 | “编辑 / 删除”锚点菜单 |
| B2 | 资产显示设置 | 视图与背景使用多次 Bottom Sheet | 短菜单 + 背景多级菜单 |

## 明确排除

- 交易列表的时间、排序、报销、账户、分类和标签筛选；
- 首页“收支统计”的类型筛选；
- 设置页的主题、语言、金额单位和 FAB 行为；
- AI、备份、个人资料、周期规则等其他短枚举；
- 账户、分类、标签、货币等动态或可搜索长列表 Picker；
- 金额、文本、日期、账单日等输入流程；
- 保存、取消、排序模式和批量选择等持续可见操作；
- 删除、恢复、覆盖数据等最终确认 Dialog。

## 通用交互规则

### 入口与定位

- Header 入口使用 `VeriAnchoredMenuButton`；
- 行级入口使用 `VeriAnchoredMenuAnchor` 包裹整行，菜单以该行作为锚点并靠右避让屏幕；
- 分类和标签普通模式下，点击行主体继续打开动作菜单，同时在行尾显示 `more_vert` 作为明确提示；
- 分类和标签排序模式下禁用菜单，行尾恢复拖动手柄；
- 账本行主体继续切换当前账本，只有行尾按钮打开菜单；
- 汇率行主体继续快捷编辑，只有行尾按钮打开菜单。

### 叶子动作

- 叶子项点击后先完成菜单关闭动画，再执行回调；
- 回调可以继续打开现有 Dialog、Picker、图片选择器或新页面；
- 不复制现有编辑、确认和持久化逻辑，只替换动作入口；
- `BuildContext` 在异步返回后继续使用前必须检查 `mounted` / `context.mounted`。

### 状态与语义

- 当前值使用 `subtitle` 或 `selected` 表达；
- 删除使用 `foregroundColor: veriExpense`，但仍调用原有 `showConfirmDialog(..., destructive: true)`；
- 不可用操作保留必要解释时显示禁用项和副标题，否则直接不构造该项；
- 所有 `id` 使用稳定英文常量，不使用本地化标题、索引或随机值；
- Tooltip、标题、副标题与禁用原因全部来自 `AppLocalizations`；
- 菜单触控高度、Semantics、Hover 和系统返回行为继续由通用组件负责。

## A1：资产页 Header

### 当前行为

`AssetsPage` 右上角 `+` 调用 `_showAssetActions`，Bottom Sheet 提供添加账户、管理分组和显示设置。

### 目标菜单

入口继续使用 `Icons.add`，避免降低“添加账户”的可发现性；Tooltip 继续使用“资产操作”。

| id | 图标 | 标题 | 行为 |
|---|---|---|---|
| `asset_add_account` | `Icons.add_card_outlined` | 添加账户 | 打开 `AddAccountPage` |
| `asset_manage_groups` | `Icons.folder_outlined` | 管理分组 | 打开 `AccountGroupsPage` |
| `asset_display_settings` | `Icons.tune_rounded` | 显示设置 | 打开 `AssetDisplaySettingsPage` |

- 根菜单宽度：`208`；
- 无子菜单；
- 删除 `_showAssetActions` 及其魔法字符串；
- 页面关闭状态的公开截图无需变化。

## A2：账本管理行

### 当前行为

点击行主体切换当前账本；行尾原生 `PopupMenuButton` 提供重命名、本位币和删除。

### 目标菜单

| id | 图标 | 标题 / 副标题 | 状态与行为 |
|---|---|---|---|
| `book_rename` | `Icons.drive_file_rename_outline` | 重命名 | 调用现有 `_renameBook` |
| `book_currency` | `Icons.currency_exchange_outlined` | 账本本位币 / 当前币种代码 | 空账本可编辑；已有财务数据时禁用并显示锁定说明；旧账本仍进入确认流程 |
| — | — | 分割线 | — |
| `book_delete` | `Icons.delete_outline` | 删除 / 默认账本不可删除 | 默认账本禁用；其他账本用危险色并调用原确认流程 |

- 根菜单宽度：`216`；
- 行主体切换账本的行为不变；
- 选中账本的勾标记不进入菜单；
- 移除页面内原生 `PopupMenuButton`。

## A3：分类管理行

### 当前行为

普通模式点击分类行打开最多 7 项 Bottom Sheet；展开箭头单独负责树形展开；排序模式显示拖动手柄。

### 目标菜单树

根菜单宽度 `220`，编辑子菜单宽度 `208`。

```text
查看交易
编辑  >
  重命名
  更换图标
  新增子分类
  移动到…       非保护分类
  合并到其他分类 非保护分类
────────
删除分类         非保护分类，危险色
```

推荐图标：

- 查看交易：`Icons.receipt_long_outlined`；
- 编辑父项：`Icons.edit_outlined`；
- 重命名：`Icons.drive_file_rename_outline`；
- 更换图标：`Icons.palette_outlined`；
- 新增子分类：`Icons.create_new_folder_outlined`；
- 移动：`Icons.drive_file_move_outline`；
- 合并：`Icons.merge_type_rounded`；
- 删除：`Icons.delete_outline`。

交互约束：

- 普通模式整行和行尾 `more_vert` 都打开同一个锚点菜单；
- 左侧展开箭头仍只展开/收起，不触发菜单；
- 保护分类不构造移动、合并和删除项，不显示无意义禁用项；
- 目标分类选择继续使用 `showCategoryPickerSheet`；
- 删除继续检查引用、子分类和保护状态并使用原确认流程；
- 排序模式不构造 Anchor，避免与拖动手势冲突。

## A4：标签管理行

### 当前行为

普通模式点击标签行打开重命名、删除 Bottom Sheet；排序模式显示拖动手柄。

### 目标菜单

| id | 图标 | 标题 | 行为 |
|---|---|---|---|
| `tag_rename` | `Icons.drive_file_rename_outline` | 重命名 | 调用现有重命名 Dialog |
| — | — | 分割线 | — |
| `tag_delete` | `Icons.delete_outline` | 删除标签 | 危险色，调用原确认流程 |

- 根菜单宽度：`188`；
- 普通模式整行和行尾 `more_vert` 打开同一菜单；
- 排序模式不构造 Anchor，保持现有拖动；
- 使用量副标题继续显示在列表行，不重复塞入菜单。

## B1：汇率历史行

### 当前行为

点击行主体编辑汇率；行尾原生菜单只有删除一项。

### 目标菜单

| id | 图标 | 标题 | 行为 |
|---|---|---|---|
| `rate_edit` | `Icons.edit_outlined` | 编辑 | 调用现有 `editExchangeRate(existing: rate)` |
| — | — | 分割线 | — |
| `rate_delete` | `Icons.delete_outline` | 删除 | 危险色，调用原确认与持久化流程 |

- 根菜单宽度：`188`；
- 行主体继续快捷编辑；
- 新增通用本地化键 `commonEdit`（中文“编辑”、英文“Edit”），供分类编辑父项和汇率菜单共用；
- 移除页面内原生 `PopupMenuButton`。

## B2：资产显示设置

该页面使用草稿 + 右上角保存。所有菜单选择只修改页面草稿，不直接写 Controller/KV。

### 账户分区方式

`SelectField` 使用 `VeriAnchoredMenuAnchor`，根宽度 `184`。

| id | 图标 | 标题 | 状态 |
|---|---|---|---|
| `asset_view_group` | `Icons.folder_outlined` | 分组视图 | 当前值显示勾 |
| `asset_view_type` | `Icons.account_balance_wallet_outlined` | 类型视图 | 当前值显示勾 |

选择后更新 `_viewMode`、清空临时折叠状态，保存语义不变。

### 资产卡片背景

`SettingsRow` 使用多级锚点菜单，根宽度 `216`，在线预设子菜单宽度按最长本地化标题取 `208–220`。

```text
使用线上图片  >
  预设 1
  预设 2
  …
输入图片链接
选择本地图片
────────
清除背景图片
```

行为：

- 在线预设子菜单标记当前 `_coverUrl` 对应项；
- 自定义 URL 叶子在菜单关闭后打开现有文本输入 Dialog；
- 本地图片叶子在菜单关闭后调用图片选择与裁剪页；
- 当前无背景时“清除”禁用；有背景时使用危险色但不要求二次确认，因为它只修改未保存草稿；
- 返回或取消菜单不得改变草稿；
- 页面最终保存、未保存拦截、图片裁剪和 URL 校验流程不变。

## 代码结构

### 页面内菜单构造

菜单项依赖当前实体、保护状态、草稿和 l10n，不做全局配置表。每个页面使用窄私有 getter/helper 构造 `List<VeriMenuEntry>`，例如：

```dart
List<VeriMenuEntry> _bookMenuEntries(
  BuildContext context,
  LedgerBook book,
) => <VeriMenuEntry>[...];
```

禁止新增字符串命令分发。每个 `VeriMenuItem` 直接绑定具体回调；需要等待的私有方法由闭包调用并使用 `unawaited(...)` 或明确的异步包装处理错误。

### 旧入口清理

完成全部迁移后：

- `lib/pages/` 不再出现 `PopupMenuButton`；
- 若 `HeaderPopupAction<T>` 仍无调用方，则删除该旧封装并同步 `docs/dev/components.md`；
- 删除 `_showAssetActions`、`_showCategoryActions`、`_showTagActions` 等只为返回命令字符串的 helper；
- 保留 `showOptionSheet` 及本轮排除页面的全部调用。

## 国际化

优先复用现有 ARB：

- `accountAdd`、`groupManage`、`assetDisplaySettingsTitle`；
- `commonRename`、`ledgerBaseCurrency`、`commonDelete`；
- `viewCategoryEntries`、`changeIcon`、`addSubCategory`、`moveTo`、`mergeCategory`、`deleteCategory`；
- `deleteTag`；
- `coverUseOnline`、`coverEnterUrl`、`coverPickLocal`、`coverClear`。

新增：

- `commonEdit`：`编辑` / `Edit`。
- `ledgerCurrencyLockedShort`：账本本位币菜单禁用态的短说明。

如果账本本位币禁用态还缺少可直接放进副标题的短文案，再新增专用中英文键；不要复用过长的 SnackBar 文案导致菜单宽度失控。

## 可访问性

- Header、行尾和整行入口必须有清晰 Tooltip/Semantics；
- 分类/标签的 `more_vert` 只是明确操作提示，不能抢走展开箭头或拖动手柄的语义；
- 禁用账本删除和本位币操作要暴露 disabled 状态及原因；
- 删除项仅靠红色不够，必须同时保留删除图标与明确标题；
- 所有菜单项保持 44px 以上触控高度；
- TalkBack 顺序为标题、副标题、状态、可进入下一级提示；
- 硬件返回先退子菜单一级，根层才关闭。

## 测试计划

### 通用组件

- 保持现有四级路径、完整祖先栈、宽度、对齐、Hover 和 Semantics 测试。

### 页面级 Widget 测试

| 页面 | 必测行为 |
|---|---|
| 资产页 | 打开菜单；三项齐全；分别进入添加账户、分组、显示设置 |
| 账本管理 | 行主体切换账本；菜单重命名；空账本本位币；有数据时禁用；默认账本删除禁用；普通账本删除确认 |
| 分类管理 | 普通/保护分类菜单差异；编辑子菜单；查看交易；新增子分类；移动/合并继续打开分类 Picker；删除确认；排序模式无菜单 |
| 标签管理 | 重命名；删除确认；排序模式无菜单 |
| 汇率历史 | 行主体与菜单“编辑”都进入编辑流程；删除取消/确认/失败反馈 |
| 资产显示设置 | 两种视图草稿；在线预设子菜单；自定义 URL；本地图片取消；清除；返回时未保存拦截；保存后持久化 |

页面测试使用现有 `test/support/test_harness.dart`，不依赖外部 Web 预览项目。

### 回归与静态检查

- `rg "PopupMenuButton" lib/pages` 结果应为空；
- 本轮排除页面的 `showOptionSheet` 调用保持存在；
- 运行 `dart format .`、`flutter analyze`、`flutter test`；
- 资产显示设置和页面跳转在 Android 真机验证；
- 深色/浅色、中文/英文各走一遍关键菜单。

## Android 真机验收

1. Header 菜单不被状态栏、屏幕右边缘裁切；
2. 列表首行、中间行、底部行菜单均能正确避让；
3. 分类编辑子菜单从“编辑”行原位展开并逐级返回；
4. 多层祖先卡片保持缩放/压暗层级，不遮挡当前项；
5. 点击外部关闭，系统返回先退一级；
6. TalkBack 能读出 Tooltip、标题、副标题、选中/禁用状态；
7. 图片选择、裁剪、文本输入和确认 Dialog 在菜单关闭后正常出现；
8. 草稿未保存时返回仍触发统一三操作确认；
9. 进程重启后只恢复已保存的资产显示设置。

## 文档与 CHANGELOG

实现完成时同步：

- `docs/dev/components.md`：删除旧 `HeaderPopupAction` 时同步；
- `docs/ui-guidelines.md`：保持入口范围与排除项一致；
- `CLAUDE.md`：如组件结构或调用约定改变则更新；
- `CHANGELOG.md` 的 `Unreleased / 优化`：记录资产与管理页面操作菜单改为就地展开；
- 检查 `docs/screenshots/assets.jpg`。若关闭状态的 Header 图标保持不变，可不更新公开截图；如实现中改变图标则必须替换。

## 实施顺序与提交边界

文档批准后按以下顺序开发：

1. `feat: use anchored menus for management actions`
   - 账本、分类、标签、汇率历史及页面级测试；
2. `feat: use anchored menus for asset controls`
   - 资产页、资产显示设置及页面级测试；
3. `docs: document anchored menu rollout`
   - CHANGELOG、组件清单、UI/开发文档收尾。

每个提交必须独立通过 analyze 与相关测试；最终运行全量测试。未经文档确认，不执行上述实现提交。

## 验收标准

- 仅改造本文 6 个已批准场景；
- 无页面直接使用 `PopupMenuButton`；
- 不把本轮排除的 Bottom Sheet 迁移成锚点菜单；
- 分类与资产背景展示至少一个真实二级菜单；
- 所有危险操作仍有确认；
- 表单草稿与保存边界不变；
- 深浅色、中英文和系统返回均通过；
- `flutter analyze` 与全量 `flutter test` 通过；
- 文档与 CHANGELOG 同步完成。
