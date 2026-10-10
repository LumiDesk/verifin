# 分类默认预算与单期覆盖

预算体系分两层：**分类默认预算**（设置一次、之后每个预算周期自动沿用）与**分类单期覆盖**（只影响一个预算键月）。页面职责：`BudgetOverviewPage` 管理所选月份/周期的单期覆盖，`BudgetSettingsPage` 管理默认值、周期起始日与按日上限。

## 数据与优先级

- 键格式：分类默认 `bookId:default:categoryId`，分类单期覆盖 `bookId:yyyy-MM:categoryId`；总预算同样有默认键与 `bookId:yyyy-MM` 覆盖键。
- 读取规则：单期覆盖优先于默认值，都没有则为 0/未设置。

```text
categoryBudget(month, categoryId)
  = 单期覆盖 bookId:yyyy-MM:categoryId
  ?? 分类默认 bookId:default:categoryId
  ?? 0
```

- 「键月」是预算数据的存储月份：自然月周期下等同该月份；自定义周期下代表该期的归属月，实际日期范围由 `budgetWindow(keyMonth)` 决定。
- `setCategoryBudget(..., 0)` 的语义是删除覆盖，不新增「显式 0 覆盖」。

## 不变量

1. 单期覆盖优先于默认分类预算。
2. 修改默认预算不覆盖、删除或重写已有单期覆盖。
3. 清除单期覆盖后立即回落默认值；没有默认值时回落未设置。
4. 多账本按 `bookId` 隔离。
5. 历史/当前/未来月份使用同一套读写规则。
6. 自定义预算周期只改变聚合窗口和用户文案，不改变预算键格式。

## 交互

- 预算总览的分类预算树：点击分类行主体打开该分类、当前所选键月的单期预算动作菜单（`VeriAnchoredMenuAnchor`）；点击有子分类行尾的展开/收起箭头只切换子树。
- 菜单按状态显示「设置」；有覆盖时额外显示「清空预算」（错误色）。取消菜单或数字键盘统一不写数据。
- 金额输入走 `showNumberPadSheet`，初始值为当前有效分类预算；正数写为单期覆盖，输入 0 清除覆盖。
- 设置页的分类行继续编辑分类默认预算。分类行不显示独立预算数字；有子分类时仅在行尾垂直居中显示旋转展开箭头，行主体负责打开对应预算编辑。
- 自然月文案显示「本月」，自定义周期显示「本期」。

## Controller API

- `categoryBudget(month, categoryId)`：按上面规则取有效值。
- `categoryBudgetIsOverride(month, categoryId)`：只检查单期覆盖键是否存在。
- `setCategoryBudget(month, categoryId, amount)`：写入正数覆盖；0 等价清除。
- `clearCategoryBudgetOverride(month, categoryId)`：删除单期覆盖键。
- 保存与清除都必须经 `_persistCategoryBudgets()` 落库并通知监听者；UI 不拼接预算键。

## 数据、备份与兼容

- SQLite `category_budgets` 表已能保存默认键与单期键，不需 schema 变更。
- `categoryBudgets` 原样导出/导入：旧备份导入后单期覆盖立即可编辑，编辑后仍能被旧备份逻辑保存。
- 不把用户真实账目加入仓库 fixture；测试用最小构造数据复现同样的键形态。
- 分类删除、账本删除和初始化数据沿用现有预算清理逻辑；新 API 只操作当前活动账本的单个键。

## 验收

- Controller：只有默认值时不算覆盖；设置单期值后算覆盖并优先；清除后回落默认值或未设置；修改默认值不覆盖已有单期值；按账本隔离；写入后重启 Controller 状态一致；最小备份 round-trip 后仍能识别、修改和清除单期键。
- Widget：总览显示既有单期值；点分类行主体可改、可清除、可恢复默认；设置页改默认值不改同月覆盖；历史月份编辑的是所选键月；自定义周期用「本期」文案且写入正确键月；点父分类箭头只展开不打开预算弹窗；取消不写入。
- 提交前执行 `dart format .`、`flutter analyze`、`flutter test test/budget_test.dart` 与全量 `flutter test`；并在 Android 上手动检查浅色/深色、中文/英文、自然月/自定义周期。
