# Issue #28 · 分类单期预算可编辑性设计与开发计划

> 状态：**已实现，自动化验证通过（2026-08-06）**
>
> 对应 Issue：[#28「关于预算页面」](https://github.com/LumiDesk/verifin/issues/28)
>
> 调研基线：`main` @ `ad1b660`，应用版本 `1.11.5+89`

## 1. 结论速览

Issue #28 确认存在。它不是预算数据丢失或数据库迁移失败，而是 v1.11.1 引入
“默认预算 + 单期覆盖”后，**分类单期预算的 UI 管理入口被移除**：

- 旧数据仍以 `bookId:yyyy-MM:categoryId` 存在，并继续优先参与计算，所以页面仍显示原金额；
- `BudgetSettingsPage` 只编辑 `bookId:default:categoryId` 对应的分类默认预算；
- `BudgetOverviewPage` 的分类预算树被改为只读，没有入口修改或清除旧的单期覆盖；
- 因为单期覆盖优先于默认值，用户即使修改分类默认预算，原月份仍会显示旧金额。

本方案恢复分类单期预算的完整管理闭环，同时保持“总览管理单期、设置页管理默认值”
这一信息架构不变。

## 2. 现状与根因

### 2.1 Issue 附件事实

Issue 附件的 `categoryBudgets` 中有两项：

| 存储键 | 金额 | 分类 | 语义 |
|---|---:|---|---|
| `default:2026-07:category_1784043273027762_2` | 800 | 食材 | 2026-07 单期覆盖 |
| `default:2026-07:entertainment` | 250 | 娱乐 | 2026-07 单期覆盖 |

附件中没有这两个分类的 `default:default:<categoryId>` 键，因此它们不是“分类默认预算”。
数据结构完整，不需要修复或重建。

### 2.2 当前领域语义

Controller 当前读取规则为：

```text
categoryBudget(month, categoryId)
  = 单期覆盖 bookId:yyyy-MM:categoryId
  ?? 分类默认 bookId:default:categoryId
  ?? 0
```

`setCategoryBudget(month, categoryId, amount)` 仍然存在，SQLite 表、repository、备份导入/导出
也仍然支持这种键。缺失的是 UI，而不是底层能力。

### 2.3 回归来源

v1.11.0 的分类预算行可点击，点击后调用 `_editCategoryBudget`，最终执行
`setCategoryBudget(_month, category.id, amount)`。

v1.11.1 的 `1e14bd0` 把预算页拆成：

- `BudgetOverviewPage`：只读总览；
- `BudgetSettingsPage`：默认月预算、每日上限、周期起始日、分类默认预算。

总预算同时获得了 `showMonthlyBudgetOverrideSheet`，可以管理单期覆盖；分类预算没有获得对等入口，
旧的 `_editCategoryBudget` 又被删除，因此形成回归。

### 2.4 当前测试缺口

现有测试覆盖了：

- 分类默认预算可跨月沿用；
- 分类单期覆盖优先于默认值；
- 默认值和覆盖值可持久化、可备份往返；
- 设置页可以修改分类默认预算。

但没有覆盖“从预算总览修改或清除分类单期覆盖”的 Widget 流程，因此页面入口被移除时测试仍然通过。

## 3. 术语与不变量

### 3.1 术语

- **默认分类预算**：设置一次，之后每个预算周期自动沿用；键为
  `bookId:default:categoryId`。
- **分类单期覆盖**：只影响一个预算键月；键为
  `bookId:yyyy-MM:categoryId`。
- **键月**：预算数据的存储月份。自然月周期下等同该月份；自定义周期下代表该期的归属月，
  实际日期范围由 `budgetWindow(keyMonth)` 决定。

### 3.2 必须保持的不变量

1. 单期覆盖优先于默认分类预算。
2. 修改默认预算不得覆盖、删除或重写已有单期覆盖。
3. 清除单期覆盖后，立即回落到默认值；没有默认值时回落为未设置。
4. 多账本继续按 `bookId` 隔离。
5. 历史月份、当前月份、未来月份使用同一套读写规则。
6. 自定义预算周期只改变聚合窗口和用户文案，不改变预算键格式。
7. 现有备份和 SQLite 数据不迁移、不重解释、不静默丢弃。

## 4. 目标与非目标

### 4.1 本轮目标

1. 用户可以在预算总览中修改任意分类的当前所选月份/周期预算。
2. 用户可以清除分类单期覆盖，恢复沿用分类默认预算。
3. Issue #28 附件所代表的旧数据无需重新导入即可管理。
4. 总预算和分类预算的单期覆盖交互保持一致。
5. 自然月显示“本月”，自定义周期显示“本期”，避免口径混淆。
6. 补齐 Controller、Widget、持久化和备份兼容回归测试。

### 4.2 本轮非目标

- 不改变预算表结构或 `AppDatabase.schemaVersion`。
- 不把历史分类单期预算自动转换为默认预算。
- 不重做预算页面视觉结构、趋势图、历史卡片或排序算法。
- 不改变分类预算按父子分类聚合花销的口径。
- 不新增“复制上期预算”“批量设置分类预算”等扩展功能。
- 不引入显式的“本期预算为 0”覆盖：沿用既有语义，输入 0 等价于清除单期覆盖。

最后一条是兼容性选择。当前 `setCategoryBudget(..., 0)` 的契约就是删除覆盖；若以后需要
“有默认预算，但某一期明确停用该分类预算”，应单独设计零值覆盖及其状态展示，不夹带在本修复中。

## 5. 用户交互设计

### 5.1 入口

入口放在 `BudgetOverviewPage` 的分类预算树：

- 点击分类行主体：打开该分类、当前所选键月的单期预算动作弹窗；
- 点击父分类左侧展开/收起箭头：只切换子树，不打开编辑弹窗；
- 设置页的分类行行为不变：继续编辑分类默认预算；
- 历史页进入某个月份总览后，也通过同一入口编辑该历史月份。

分类行已有 `onTap` 和尾部 chevron 视觉能力，不新增同构行组件。总览页为分类行传入
`onTap` 后，未设置预算的行显示“设置”，已设置的行显示金额与可进入箭头。

### 5.2 动作弹窗

新增领域 helper：

```dart
showCategoryBudgetOverrideSheet({
  required BuildContext context,
  required DateTime month,
  required Category category,
})
```

弹窗标题应同时说明分类和目标周期，例如：

- 自然月：`食材 · 2026年7月`
- 自定义周期：`食材 · 7月22日 至 8月21日`

动作按状态变化：

| 当前状态 | 显示动作 | 结果 |
|---|---|---|
| 无单期覆盖 | 单独设置本月/本期额度 | 打开数字键盘，写入单期覆盖 |
| 有单期覆盖 | 调整本月/本期额度 | 打开数字键盘，更新单期覆盖 |
| 有单期覆盖且有默认值 | 恢复默认（沿用 X） | 删除单期覆盖，立即显示默认值 |
| 有单期覆盖且无默认值 | 清除本月/本期单独设置 | 删除单期覆盖，回到未设置 |

取消动作弹窗或数字键盘统一返回 `null`，不得写数据。

### 5.3 金额输入

- 继续使用 `showNumberPadSheet`，不使用系统文本框；
- 初始金额为当前有效分类预算，方便直接修改 Issue #28 中的 800/250；
- 正数保存为单期覆盖；
- 输入 0 调用清除覆盖语义；
- 保存后依赖 Controller 通知立即刷新总览、首页预算提醒与看板摘要。

### 5.4 默认预算与单期覆盖的关系

预算设置页继续只管理默认预算，避免两个页面职责再次混淆：

```text
预算总览 → 当前选择的月份/周期
预算设置 → 所有月份自动沿用的默认值
```

如果用户在设置页把“食材默认预算”改为 600，而 2026-07 仍有 800 的单期覆盖：

- 2026-07 继续显示 800；
- 其他无覆盖月份显示 600；
- 用户回到 2026-07，在分类行弹窗中选择“恢复默认”，才会显示 600。

## 6. 组件与代码设计

### 6.1 Controller API

在 `VeriFinController` 增加与总预算对称的 API：

```dart
bool categoryBudgetIsOverride(DateTime month, String categoryId)

void clearCategoryBudgetOverride(DateTime month, String categoryId)
```

职责：

- `categoryBudgetIsOverride` 只检查 `bookId:yyyy-MM:categoryId` 是否存在；
- `clearCategoryBudgetOverride` 只删除该键，持久化 `_categoryBudgets` 并通知监听者；
- `setCategoryBudget` 继续负责设置正数覆盖，并保留 0=清除的兼容语义；
- 不暴露 repository，不让 UI 拼接预算键。

### 6.2 Sheet helper 收口

当前 `showMonthlyBudgetOverrideSheet` 在预算页面 part 中直接封装
`showModalBottomSheet`。实现本需求时将它和新的分类 helper 一并移入 `lib/pages/sheets.dart`：

- 对外提供类型明确的 `showMonthlyBudgetOverrideSheet` 与
  `showCategoryBudgetOverrideSheet`；
- 两者复用一个私有动作流程，避免两套状态判断、文案和数字键盘逻辑漂移；
- 动作菜单复用 `showOptionSheet(..., showSelectedMarker: false)`；
- 金额继续复用 `showNumberPadSheet`；
- `BuildContext` 按仓库新 helper 规范使用具名 `context:`；
- helper 内部读取 `VeriFinScope`，调用方不传 Controller；
- 删除页面内裸写的 `showModalBottomSheet`。

新增/迁移 helper 后同步更新 `docs/dev/components.md`。

### 6.3 预算总览接线

在 `_buildCategoryBudgetTree` 创建 `_CategoryBudgetRow` 时增加：

```dart
onTap: () => showCategoryBudgetOverrideSheet(
  context: context,
  month: _month,
  category: category,
),
```

父分类的 `onToggle` 保持独立。需要 Widget 测试锁定“点箭头只展开，点行主体才编辑”，
避免嵌套点击区域互相触发。

### 6.4 分类预算行

复用现有 `_CategoryBudgetRow`，仅更新其注释与总览调用方式：

- `onTap == null` 仍表示纯展示场景；
- 总览页与设置页都可点击，但分别编辑单期覆盖和默认预算；
- 不新增另一套 `_EditableCategoryBudgetRow`；
- 不改变分类图标、金额颜色、进度条或父子缩进。

### 6.5 国际化

新增或参数化本月/本期动作文案，至少覆盖：

- 单独设置本月额度 / 单独设置本期额度；
- 调整本月额度 / 调整本期额度；
- 清除本月单独设置 / 清除本期单独设置；
- 分类 + 月份/周期范围的弹窗标题。

同时修正现有总预算单期弹窗在自定义预算周期下仍写“本月”的问题，让两种入口口径一致。

文案同时写入 `app_zh.arb` 与 `app_en.arb`，不手改 gen-l10n 生成文件。

## 7. 数据、备份与兼容性

### 7.1 SQLite

不变更表结构，不提升 `schemaVersion`。现有 `category_budgets` 表已经能保存默认键和单期键。

### 7.2 备份

不改变备份版本和 JSON 字段。`categoryBudgets` 原样导出/导入即可：

- 老备份导入后，单期覆盖立即可编辑；
- 新版本编辑后的值仍能被旧有备份逻辑保存；
- 不把 Issue 附件加入仓库测试 fixture，避免提交真实用户账目；测试使用最小构造数据复现同样键形态。

### 7.3 冷启动与持久化

覆盖值修改和清除都必须经 `_persistCategoryBudgets()` 落库。测试需等待挂起写入后重新创建
Controller，确认冷启动读取一致，不能只断言当前内存状态。

### 7.4 删除与账本隔离

继续沿用现有分类删除、账本删除和初始化数据的预算清理逻辑。本轮新增 API 必须只操作当前活动账本
对应的单个键，不能影响其他账本、月份或分类。

## 8. 测试计划

### 8.1 Controller 单元测试

在 `test/budget_test.dart` 补充：

1. 只有默认值时，`categoryBudgetIsOverride == false`。
2. 设置单期值后，`categoryBudgetIsOverride == true`，且单期值优先。
3. 清除覆盖后回落默认值。
4. 没有默认值时清除覆盖，结果为 0/未设置。
5. 修改默认值不覆盖已有单期值。
6. 覆盖值和清除操作按账本隔离。
7. 写入后重启 Controller，状态保持一致。
8. 最小备份 round-trip 后仍能识别、修改和清除旧式单期键。

### 8.2 Widget 回归测试

构造与 Issue #28 等价的最小状态：2026-07“食材”单期预算 800，“娱乐”250。

覆盖以下流程：

1. 总览页仍显示 800/250。
2. 点击“食材”行打开单期预算动作弹窗。
3. 把 800 改为 900 后，行内立即显示 900，默认预算保持不变。
4. 有默认值时选择“恢复默认”，行内显示默认值。
5. 无默认值时选择“清除”，行内回到未设置。
6. 在设置页修改默认预算，不会改变同月已有覆盖。
7. 切换到历史月份后，编辑的是所选历史键月，不是当前系统月份。
8. 自定义预算周期使用“本期”和日期范围文案，写入的仍是正确键月。
9. 点击父分类展开箭头只展开/折叠，不打开预算弹窗；点击行主体才打开。
10. 取消动作弹窗或数字键盘不产生写入。

### 8.3 现有回归范围

至少运行：

```bash
dart format .
flutter analyze
flutter test test/budget_test.dart
flutter test
```

这是 Flutter UI 与本地数据逻辑改动，不涉及 Android 原生桥、权限或 R8，无需为本修复单独做
release/R8 专项；仍应在 Android 模拟器或真机手动检查浅色/深色、中文/英文、自然月/自定义周期。

## 9. 文档与 CHANGELOG 同步

实现时同步更新：

- `docs/dev/components.md`：登记迁移后的总预算/分类预算覆盖 sheet helper；
- `docs/ui-guidelines.md`：分类预算树在总览页可点按管理单期覆盖，不再描述为完全只读；
- `docs/product.md`：预算能力明确包含分类默认预算与分类单期覆盖；
- `docs/acceptance-checklist.md`：加入分类单期编辑、清除和默认回落验收项；
- `CHANGELOG.md`：在 `Unreleased / 修复` 记录 Issue #28；
- 本文：实现完成后把状态改为“已实现”，记录最终提交和与方案的差异。

预计不需要修改 `README.md`、`CLAUDE.md`、`tech-decisions.md`：本轮恢复的是已经存在的数据语义，
没有改变架构、存储范围或关键技术取舍。实现审查时仍需再次确认。

## 10. 分步实施顺序

### 阶段 1：领域 API 与单元测试

- 增加 `categoryBudgetIsOverride`、`clearCategoryBudgetOverride`；
- 补默认/覆盖/清除/账本隔离/冷启动测试；
- 不动 UI，先锁定数据语义。

### 阶段 2：统一覆盖弹窗

- 把总预算覆盖 helper 收口到 `sheets.dart`；
- 增加分类预算覆盖 helper；
- 补中英文和本月/本期文案；
- 更新组件注册表。

### 阶段 3：总览页接线与 Widget 回归

- 分类行主体接入单期覆盖 helper；
- 保持父分类折叠手势独立；
- 覆盖 Issue #28 最小复现、编辑、清除、历史月份、自定义周期测试。

### 阶段 4：全量验证与文档收尾

- 更新产品、UI、验收清单和 CHANGELOG；
- 执行 format、analyze、针对性测试和全量测试；
- 手动检查 Android 页面交互；
- 对照本文验收标准复核，不在本轮顺手扩展其它预算能力。

## 11. 完成标准

- [x] Issue #28 中已有的 800/250 单期预算可直接修改。
- [x] 已有覆盖可清除，并正确回落默认值或未设置。
- [x] 默认预算与单期覆盖互不误改，优先级稳定。
- [x] 历史月份和自定义预算周期操作正确。
- [x] 多账本、冷启动、备份往返保持正确。
- [x] 父分类展开手势与行编辑手势不冲突。
- [x] 中文、英文、本月、本期文案准确。
- [x] 无数据库 schema 或备份格式变更。
- [x] `flutter analyze`、针对性测试和全量测试通过。
- [x] 相关文档与 `CHANGELOG.md` 已同步。

## 12. 确认与实现记录

用户于 2026-08-06 确认按本文执行，以下三项均按原方案实现：

1. **交互**：在预算总览中点击分类行主体，管理当前所选月份/周期的分类单期预算；左侧箭头仍只负责展开子分类。
2. **零值语义**：保持旧行为，输入 0/选择清除都表示删除单期覆盖并回落默认值，不新增“显式 0 覆盖”。
3. **兼容策略**：不自动把旧的月度分类预算迁成默认预算，所有旧值原样保留，由用户按需修改或恢复默认。

实现与本文无功能性偏差。总预算与分类预算覆盖 helper 已收口到 `sheets.dart`，并额外修正
自定义预算周期下总预算状态标签和覆盖弹窗仍显示“本月”的旧文案问题。最终提交信息以
Git 历史为准。

自动化验证：

```text
dart format .                         通过（244 files，0 changed）
flutter analyze                       通过（No issues found）
flutter test test/budget_test.dart    通过（24 tests）
flutter test                          通过（705 tests）
```
