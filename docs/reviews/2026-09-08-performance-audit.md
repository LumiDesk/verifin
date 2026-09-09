# Veri Fin 性能审查记录（2026-09-08）

> 审查日期：2026-09-08<br>
> 基线提交：`63f0929`（v1.16.14）<br>
> 审查分支：`talyra42/perf-audit-2026-09-08`<br>
> 审查方式：**只记录问题，不修改产品实现**。等用户确认问题清单后，再按批次修复。<br>
> 触发原因：用户反馈「能感觉到一点卡顿」。

## 1. 结论摘要

> **整改状态（2026-09-08，分支 `talyra42/perf-audit-2026-09-08`）**
>
> | 条目 | 状态 | 提交 |
> | --- | --- | --- |
> | P0-1 首页聚合 | **已修**（余额单遍缓存 + 日历按天分桶；指标合并与 PageView 保活未做，见下） | `6348f91` |
> | P0-2 导航重绘 | **已修**（导航与页面各自成层，指示器改 Transform 平移） | `24a9411` |
> | P0-3 搜索无防抖 | **已修**（220ms 防抖 + 分类子孙集合提级） | `667b7b1` |
> | P1-4 交易保存整表重写 | **已修**（同一事务内行级差分，与 `saveX` 共用机制） | `7d9403a` |
> | P1-5 资产走势 O(A×E) | **已修**（`accountMonthlyBalanceSeriesBatch` 单遍批量） | `7d9403a` |
> | P1-6 备注逐字重算 | **已修**（正则提级 + 300ms 防抖 + 保存前 flush） | `7d9403a` |
> | P1-7 金额键盘弹层模糊 | 未修 | — |
> | P1-8 分页签名重置 | 未修 | — |
> | P1-9 全树广播 / 偏好迁移 | 未修（按字段迁移 `ValueNotifier` 属中期项） | — |
> | P2-10 ~ P2-16 | 未修 | — |
>
> **P0-1 的两个子项未做**：`computeHomeMetric` 的 5 次全表扫描合并、`PageView` 保活。理由：余额与日历两处（占比最大的 O(A×E) 与 31×E）已消除，剩余约 6×E 的单遍求和收益不足一次独立改动的风险；已在此登记，规模变大或再次收到卡顿反馈时再做。

本轮确认 **16 项性能问题**（P0×3、P1×6、P2×7）。它们不是同一个原因，而是三层叠加：

1. **重建范围过大**：`VeriFinScope` 是裸 `InheritedNotifier`，Controller 有 113 处 `notifyListeners()`；页面在 `build` 里读 scope，于是**任何一次通知都会整页重建**，并顺带重跑该页所有 O(n) 聚合。
2. **热路径上的 O(n) / O(A×E) 聚合**：首页、资产页、看板每次重建都重新做全量求和与分类树展开；记账搜索每敲一个字符都重跑「过滤 + 排序 + 分组」。
3. **绘制层缺少隔离**：全仓只有 2 个 `RepaintBoundary`；底部导航的拖动/吸附动画用 `setState` + `Positioned(left:)` 逐帧改布局，会把整屏连同背后的玻璃模糊一起重绘。

其中 **P0-1 / P0-2 / P0-3 对应用户能直接感知的卡顿**：切页回首页、拖动底部导航、在交易列表里打字。

| 等级 | 数量 | 含义 |
| --- | ---: | --- |
| P0 | 3 | 核心交互上用户可见的卡顿 |
| P1 | 6 | 特定页面/操作上的卡顿或长阻塞 |
| P2 | 7 | 浪费可测量，通常在 profile 中才明显 |

### 与既有台账的关系

`docs/dev/known-limitations.md` 已登记两条相关债务：**L1**（余额计算 O(账户数×交易数)，触发阈值 `entries > 5000`）和**全树广播**（`VeriFinScope` 裸 `InheritedNotifier`，约定「新增偏好一律走独立 `ValueNotifier`」）。本轮 P0-1、P1-5、P1-9、P2-10 是这两条债务的**具体落点**——本文件把它们从「已知会痛」细化为「在哪一行、以什么代价、怎么改」。

## 2. 审查范围与证据边界

**已做（代码级只读审查）**

- `lib/main.dart` 启动编排；Controller 三个 part（`veri_fin_controller.dart` / `_state` / `_ops`）。
- 首页、资产、看板、我的、交易列表、记账页、预算、分类、AI 聊天等页面的 `build` 路径。
- 共享绘制与材质：`chart_painters.dart`、`glass_lighting.dart`、`glass_material.dart`、`navigation_glass_lens.dart`、`root_navigation.dart`。
- 数据层：`ledger_repository.dart`、`app_database.dart`、`currency_math.dart`、`series_math.dart`、`category_tree.dart`、`home_metrics.dart`、`category_suggest.dart`。
- 上述所有行号均已按当前 `HEAD` 源码逐条核对。

**已做（模拟器冒烟，仅作定性参考）**

- 环境：`verifin_menu_api36` AVD（API 36、x86_64、1179×2556@480dpi，即 393×852dp）、宿主机 GPU 加速（RTX 4060）、Impeller/OpenGLES。
- 以 `--flavor diagnostic --dart-define=UNIFIED_DESIGN_PREVIEW=true --dart-define=GLASS_DESIGN_PREVIEW=true` 运行正式入口，完成冷启动、四页切换、快速记账弹层、设置页「高级材质」开/关的走查。

**未做（不能替代，也不能由本文件断言）**

- **真机 profile 帧时间采集**。本轮全程为 **debug 构建**：无 AOT、有断言、JIT 编译，本身就会明显掉帧；模拟器的 GPU 路径也与真机不同。因此本文件的所有代价估算来自**代码机制**，不是模拟器测得的数字。
- 顺带确认：`adb shell dumpsys gfxinfo <package>` 对 Flutter 无效——它报 `Total frames rendered: 0`，因为 Flutter 在自有 surface 上绘制，Android 的 gfxinfo 统计不到。后续基准必须用 DevTools timeline 或 `flutter run --profile`。
- release/R8 下的实际表现、系统字体放大、低端机。
- 结论落地前，P0-2 的「整屏重绘」仍需用 DevTools 的 **Highlight repaints / `debugRepaintRainbowEnabled`** 在真机上确认一次（见 P0-2 的验证方式）。

## 3. P0 —— 核心交互上用户可见的卡顿

### P0-1 · 首页每次重建都重跑 O(A×E) 与约 37×E 的聚合，而它在每次通知和每次切回首页时都会重建

**证据**：`lib/pages/home_page.dart:27-75`

```dart
final controller = VeriFinScope.of(context);                            // 27 → 任意 notify 都整页重建
final accountValuation = controller.accountBalancesInBase(date: now);   // 40 → O(A×E)
final categoryBudgetSnapshots = computeCategoryBudgetSnapshots(...);    // 65 → O(E_month × C)
final recurringMissingByRule = controller.dueRecurringMissingRates(now);// 72
```

叠加两处：

- `lib/app/common_widgets_panels.dart:420-444`（日历面板，默认开启）：**每个日期格**都做一次
  `.where(... day == day)` 全量扫描，约 31 次全表遍历。
- `lib/app/home_metrics.dart:252-258`：每个指标一次全表 `_sum`，默认 5 个指标约 6 次全表遍历。
- `lib/app/veri_fin_controller_ops.dart:4376-4387` 的 `accountBalance` 本身是 O(E)，而
  `lib/app/currency_math.dart:363-391` 对每个账户各调一次 → O(A×E)。

**机制与代价**：一次首页 build ≈ `A×E` + `31×E` + `6×E` + `C×E_month`，并伴随大量闭包迭代与列表分配。A=20、E=5000 时约 30 万次操作，release AOT 下大致 10–30ms。它发生在**每一次通知**，以及**每一次切回首页**：`lib/pages/shell.dart:161-166` 的 `PageView` 默认 `allowImplicitScrolling: false`（`cacheExtent = 0`），离屏页会被卸载，重新进入视口时整页重建——而且是在滑动过程中、页面刚可见的那一帧。

**建议修复**（都符合现有约定，不引入新依赖）：

1. 日历面板改为一次遍历产出 `Map<int, double>`，而不是 31 次 `where`。
2. 把 `accountBalancesInBase` + 逐账户 `accountBalance` 的两次遍历合并为**一次遍历 `entries` 累加各账户余额**——这正是 `known-limitations.md:22` 已经写好的整改方向。
3. 把 6 次 `computeHomeMetric` 全表扫描合并为按指标窗口的一次遍历。
4. 可选：给四个根页面加 `AutomaticKeepAliveClientMixin`，或 `PageView(allowImplicitScrolling: true)`（内存换时间，需权衡）。

**验证方式**：在 5000 笔的账本上录一条 Home↔Assets 滑动与一次保存后的通知，看 UI 线程是否出现 >16ms 的 build/layout 帧；补一个 widget 测试，seed 5000 笔后断言首页 build 期间的聚合调用次数。

### P0-2 · 底部导航的拖动/吸附动画逐帧 `setState` + 改布局，且导航附近没有任何 `RepaintBoundary`

**证据**：`lib/app/root_navigation.dart:138-149`

```dart
_indicatorController = AnimationController(vsync: this, duration: _pressMoveDuration)
  ..addListener(() {
    final progress = Curves.easeOutCubic.transform(_indicatorController.value);
    setState(() {
      _displayIndex = lerpDouble(_animationStart, _animationEnd, progress)!;
    });
  });
```

指示器用 `Positioned(left: _displayIndex * slotWidth + 3, ...)` 定位（`lib/app/root_navigation.dart:481`），即**每帧一次布局**，而不是仅重绘。全仓 `RepaintBoundary` 只有两处（`lib/app/app_theme.dart:281`、`lib/app/pages/home_page.dart:397`），导航、页面主体和列表项附近都没有。

**机制与代价**：没有 `RepaintBoundary` 时，导航的一次重绘会向上冒泡到最近的图层边界（根/路由层），于是**整屏连同页面里的玻璃模糊一起重绘**。发布包开启 `GLASS_DESIGN_PREVIEW`，页面里的每个 `VeriCard` 都是 `BackdropFilter`（`lib/app/glass_material.dart:92-107`），背后的模糊要按新的背景像素重算。拖动导航时手指每移动一次都会触发这条链。

**建议修复**：

- 给导航胶囊与 `PageView` 各包一层 `RepaintBoundary`。
- 把 `_displayIndex` 改为通过 `ValueListenableBuilder` / `AnimatedBuilder` 只驱动指示器重绘。
- 指示器定位优先用 `Transform.translate` / `FractionalTranslation`（只重绘、不重布局）替代 `Positioned(left:)`。

**验证方式**：真机上开 `debugRepaintRainbowEnabled` 拖动导航——今天应当整屏闪烁，修完后只应看到导航条；再对比拖动期间 raster 线程耗时。

### P0-3 · 交易列表搜索每敲一个字符就重跑完整管线（无防抖）

**证据**：`lib/pages/transactions_pages.dart:1176-1180` 的 `TextField(onChanged: onChanged)` 直接 `setState` 更新 `_query`，进而使 `_ensureDerived`（`:183-216`）失效并重跑 `_filteredEntries`（`:561-599`）：

```dart
return filtered
    .where((entry) => _matchesSecondaryFilters(entry, controller))
    .where((entry) => normalizedQuery.isEmpty
        ? true
        : _matchesQuery(entry, controller, normalizedQuery))
    .toList();
```

其中 `_matchesSecondaryFilters` 对**每一条**交易都调用 `descendantIds(controller.categories, ...)`（`:616-626`，`lib/app/category_tree.dart:88-99` 走树），`_matchesQuery` 对每条交易构造约 7 个字符串并做两次金额格式化（`:649-666`）。之后还有 `_sortedEntries` + `groupEntriesByDate` + `sumByType` 重跑。

**机制与代价**：每次按键 = O(E × (C + 字符串格式化)) + O(E log E) 排序 + 重新分组，全部在 UI 隔离区；E=5000 时每敲一个字符都是几十毫秒，表现为输入框发涩、掉帧。

**建议修复**：

- 给 `_query` 加 150–250ms 防抖（与 `lib/main.dart:215-220` 的 `_scheduleWidgetRefresh` 同一风格）。
- 把 descendant id 集合提到每条目谓词之外，只算一次。
- 每条交易的可搜索小写串预先算好并缓存，避免每次按键重新格式化金额。

**验证方式**：5000 笔账本上 profile 输入「咖啡」时的掉帧数；补 widget 测试，断言防抖后每敲一个字符不再增加 `TransactionTile` 的重建次数。

## 4. P1 —— 特定页面/操作上的卡顿或长阻塞

### P1-4 · 保存一笔交易会整表重写 `entries`（并重写 `attachments`），且在页面关闭前 await

**证据**：`lib/app/veri_fin_controller_ops.dart:1940` → `lib/data/ledger_repository.dart:282-302`

```dart
await _replaceInTxn(txn, 'entries', entrySnapshot.map(_entryToRow));   // 284
await _replaceInTxn(txn, 'attachments', _indexed(attachmentSnapshot, _attachmentToRow));
...
_seedSnapshot('entries', entrySnapshot.map(_entryToRow));              // 298 → 又映射一遍
```

而 `_replaceInTxn`（`:617-629`）是 `txn.delete(table)` + 批量插入**每一行**。调用方 `lib/pages/entry_detail_page.dart:1693`、`transaction_detail_page.dart:1164`、`credit_repayment_page.dart:330` 都是 await 后再关闭页面。

**机制与代价**：保存 1 笔交易会为全部 E 行分配 `_entryToRow` 映射**两次**（UI 隔离区），并执行 E 条 DELETE+INSERT。`known-limitations.md:19` 明确把 `saveEntryAggregate` 排除在行级差分之外（为跨表原子性）；但行级差分可以在**同一个事务内**完成，原子性不变。E=5000 时这是数百毫秒的 UI 阻塞，用户卡在保存按钮上。

**建议修复**：在事务内复用现有 `_incrementalReplace` 的差分逻辑（对 `_rowSnapshots['entries']` 算出 upsert/delete 集合），并复用已映射的行喂给 `_seedSnapshot`，不要重复映射。

**验证方式**：在 5000 笔的测试里用 `Stopwatch` 包住 `saveEntryAggregateDraftResult`；真机上 profile 点保存。

### P1-5 · 资产页每次 build 做三次 O(A×E) 遍历，折叠/展开分区还会再触发

**证据**：`lib/pages/assets_pages.dart:73-84, 101-111`

```dart
final balances = <Account, double>{ for (final account in accounts) account: controller.accountBalance(account) }; // O(A×E)
final valuation = controller.accountBalancesInBase(accounts: valuedAccounts);                                     // O(A×E) 再来一次
final assetTrendValues = _baseCurrencyAssetTrend(...);                                                             // O(A×E) 第三次
```

`_baseCurrencyAssetTrend`（`:573-599`）对每个账户调 `accountMonthlyBalanceSeries`（`lib/app/series_math.dart:82-108`，每次都是全表遍历）。

**机制与代价**：约 3×A×E；A=20、E=5000 时 30 万次迭代 + 20×12 元素列表分配。切到资产页、以及每次折叠/展开分区都会触发（`toggleAssetSectionCollapsed` 会广播，`veri_fin_controller_ops.dart:1566-1573`）。

**建议修复**：一次遍历 `entries` 同时产出 `Map<accountId,double>` 原生余额与 `Map<accountId,List<double>>` 月度增量，估值与趋势都从这一份数据取；在 Controller 上按 `_entriesView` 的身份缓存，复用 `_invalidateDerivedViews` 的失效点。

**验证方式**：5000 笔下 profile 资产页 build；给数学辅助函数补一个「只遍历一次」的单元测试。

### P1-6 · 在记账页备注框打字会扫描最多 500 笔历史、每条编译 2 个正则，并重建整页

**证据**：`lib/pages/entry_detail_page.dart:139`（`_noteController.addListener(_onNoteChanged)`）→ `:461` `_recomputeSuggestion()` → `:469-486` 调 `suggestEntry(history: controller.entries, …)`；`lib/app/category_suggest.dart:115-144` 遍历最多 `_kMaxHistory = 500`（`:66`）条，且 `:237-254`：

```dart
final cleaned = raw.toLowerCase()
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll(RegExp(r'[\p{P}\p{S}]', unicode: true), '');   // 每条交易构造 2 个 RegExp
```

命中建议后 `setState` 重建整页（`:490-507`），而该页 `build` 里还有 2–3 次 O(E) 的 `accountBalance`（`:731-750`）。

**机制与代价**：每次按键最多 1000 次 `RegExp` 构造 + 500 次小写/替换字符串分配 + 一大棵子树重建 + 2–3 次 O(E) 余额计算。用户感知为备注输入发涩。

**建议修复**：把两个正则提为顶层 `final`（或缓存在字段里）；每条交易的 note 分词结果按 entry id 缓存、交易变更时失效；`_recomputeSuggestion` 加短防抖；把已知账户余额传进 build，不要重复计算。

**验证方式**：用 500 条历史 + 非空 note 的 `suggestEntry` 微基准测试；widget 测试敲 10 个字符并统计 `EntryDetailPage` 的 build 次数。

### P1-7 · 所有底部弹层（含金额数字键盘）都是 `BackdropFilter` 表面，每次按键重绘整块模糊

**证据**：`lib/pages/sheets.dart:21-65` 的弹层统一包 `VeriGlassSurface(grouped: false, ...)`；`lib/app/glass_material.dart:100-107` 走**非分组**的 `BackdropFilter(blur(sigmaX: 16, sigmaY: 16))`。`showNumberPadSheet`（`lib/pages/sheets.dart:706-739`）走同一条路径，而数字键盘每次按键都 `setState`（`lib/app/entry_sheets.dart:64`），并且 build 里读的是整个 `MediaQuery`（`entry_sheets.dart:77`、`sheets.dart:1294`）。

**机制与代价**：每次按键都让整块弹层区域的背景模糊重算，且 `MediaQuery.of` 的全量读取会在键盘 inset 变化时再触发一次重建。这正是「在金额键盘上打字」的热路径，代价随弹层面积线性增长。

**建议修复**：金额键盘弹层改用平面表面（`backgroundColor` + `Material` 形状），或至少给键盘网格与显示行各加 `RepaintBoundary`，让按键不使模糊层失效；把 `MediaQuery.of` 收窄为 `MediaQuery.viewInsetsOf`。

**验证方式**：按 10 次数字键时对比 raster 线程耗时；开 "Highlight repaints" 看弹层。

### P1-8 · 任何与列表无关的通知都会把交易列表打回前 30 条并跳回顶部

**证据**：`lib/pages/transactions_pages.dart:202-215`

```dart
if (_deriveSignature != null && listEquals(_deriveSignature, signature)) return;
_deriveSignature = signature;
...
_visibleCount = _pageBatchSize;      // 30
```

signature 的首项是 `controller.entries`（`:185`），而 `_invalidateDerivedViews()`（`veri_fin_controller_state.dart:61-67`）在每次通知时都丢弃缓存视图，于是每次都能拿到新的列表实例、signature 永远不同。任何通知（例如回前台时的 `applyDueRecurring`，`lib/main.dart:246-250`，或在别处写偏好）都会把列表截回 30 条并夹紧滚动位置。

**机制与代价**：已经翻到很深位置的用户被弹回前 30 条，同时重跑 O(E log E) 的派生与分组。

**建议修复**：把 signature 拆成「筛选签名」（变化时才重置分页）与「数据签名」（变化时只重算、保留 `_visibleCount`）。

**验证方式**：widget 测试——滚到第 3 页后调用 `controller.setHapticsEnabled(...)`，断言可见条数不变。

### P1-9 · 全树广播：页面在 `build` 里读 `VeriFinScope.of(context)`

**证据**：`lib/app/veri_fin_scope.dart:12-16`；在 `build` 中注册依赖的包括 `lib/pages/home_page.dart:27`、`reports_page.dart:27`、`assets_pages.dart:72`、`profile_pages.dart:40-41`、`transactions_pages.dart:250`、`budget_pages.dart:60`、`account_detail_page.dart:72`、`entry_detail_page.dart:546`、`transaction_detail_page.dart:109`、`home_page.dart:687`。

**机制与代价**：113 处 `notifyListeners()` 中的任何一处都会让整页失效，并连带上面那些 O(n) 工作。`known-limitations.md:81-82` 已确认此债，并约定「新增偏好一律照 `themePreferenceListenable` / `localePreferenceListenable` 的独立 `ValueNotifier` 先例做」。

**建议修复**：沿用已有先例（`lib/app/veri_fin_controller.dart:125-134` 的 `advancedMaterialListenable`、`aiCapabilityListenable` 等），把高频偏好（资产视图模式、折叠分区、面板配置、触感、记账动作、首页趋势配置）迁到 `ValueNotifier`，只包住消费该值的控件。**不要一次性抽全部 15 个字段**，按字段迁移是低风险路径。

**验证方式**：给 `HomePage` 加重建计数器，断言切换触感开关不再重建首页。

## 5. P2 —— 浪费可测量，通常在 profile 中才明显

| # | 问题 | 关键证据 | 建议 |
| --- | --- | --- | --- |
| P2-10 | `notifyListeners()` 自身先做一次 O(E) 扫描 | `veri_fin_controller_state.dart:69-75` → `:243-262` 的 `activeBookUsesMultipleCurrencies`：单币种时 `_entries.any(...)` 必须扫完全部交易才返回 false，且每次通知都算、无缓存 | 折进同一套派生视图缓存，惰性算一次、在 `_invalidateDerivedViews` 里清 |
| P2-11 | 3 个 `CustomPainter` 用身份比较列表 → 每次父级重建都重绘 | `reports_page.dart:798-802`、`:870-874`、`budget_trend_chart.dart:333-339` 的 `oldDelegate.segments != segments` | 改用 `listEquals`（`chart_painters.dart:325-336` 已有正确写法） |
| P2-12 | `computeCategoryBudgetSnapshots` 为每条支出交易建一次分类索引 | `budget_snapshots.dart:146-162` → `category_tree.dart:46-58` → `:21-23`（`categoryIndex` 每次调用都新建整张 map） | 索引只建一次并传进去，或按 categories 列表身份预计算祖先链 |
| P2-13 | 预算页月份快照 = 6 次全表扫描 | `budget_pages.dart:115-119` → `budget_snapshots.dart:114-132` 的 `List.generate(6, … entriesInWindow(...))` | 一次遍历按月份窗口分桶 |
| P2-14 | 冷启动在首帧前串行 5 个 await | `main.dart:33-72`：KV → 打开库 → `VeriFinController.create`（载入全部表、排序、最多 8 轮分类自愈）→ `applyDueRecurring` → `runApp` | 先 `runApp` 一个轻量启动门（`AppLockGate`/`PrivacyConsentGate` 已有同款模式），数据在其后加载；至少把 `applyDueRecurring` 挪到首帧之后 |
| P2-15 | 高级材质的 painter 每次 paint 都大量分配 | `glass_lighting.dart:37-115` 每次 paint 分配 `Path`、`computeMetrics()`、最多 1024 元素的列表和两个 `ui.Vertices`；`navigation_glass_lens.dart:73-197` 在按住期间每帧重跑 | 按 (size, radius, 量化后的运动量) 缓存顶点与列表；透镜用 `ValueListenable`/`AnimatedBuilder` 驱动，避免带动导航其它控件重建 |
| P2-16 | 表单页逐键 `setState`；交易列表逐条滚动通知 `setState` | `profile_info_page.dart:45-48, 230-234`（4 个 controller）、`add_account_page.dart:30-34`（5 个）、`transactions_pages.dart:235-240`（每次 `ScrollNotification`，含 fling 的每一帧） | 把「脏标记」显示隔离到 `ValueListenableBuilder`；`_onScroll` 只在 `_visibleCount` 真正变化时 `setState` |

**关于 P2-14 的一个实测数字（非代表性，仅作方向参考）**：在模拟器上对已安装的 **debug** 包做 `am start -W` 冷启动，`TotalTime` 约 **3.5s**（两次分别为 3561ms / 3633ms）。debug 构建的 JIT 与断言会显著放大这个数字，release 下应远小于此，所以它不能当作缺陷证据；但它说明「首帧之前有 5 个串行 await」这条路径确实存在可观测的等待，值得在修复阶段用 `--profile` 重新量一次。

## 6. 已核查、未发现问题的区域- **图表 painter**：`chart_painters.dart` 的 `TrendLinePainter:325-336`、`BarChartPainter:435-443`、`BudgetRingPainter:493-497` 都用了 `listEquals`/值比较；tooltip 只在显示时分配。
- **列表虚拟化**：交易主列表是 `SliverList.builder` + 有界分页（`transactions_pages.dart:510-551`）；全部 17 处 `shrinkWrap: true` + `NeverScrollableScrollPhysics` 都处在有界上下文（弹层里的 `Flexible` 或固定尺寸网格）中，没有对无界数据使用 `ListView(children:[...])`。
- **数据库索引**：`entries(book_id)`、`entries(occurred_at)`、`attachments(entry_id)`、`exchange_rates(book_id,currency_code,effective_date)`、`account_groups(book_id)` 齐备（`app_database.dart:473-527,592`），迁移按版本注册表并有矩阵测试。
- **写路径**：账本/账户/分组/分类/标签/周期规则/汇率的 `saveX` 走 `_incrementalReplace` 行级差分（`ledger_repository.dart:551-589`），写入串行化。**交易详情的整表重写是唯一的例外**（见 P1-4）。
- **AI 聊天**：`setAiChatHistory` 有意不通知（`veri_fin_controller_ops.dart:1331-1340`）；消息列表用 `ListView.builder`（`ai_chat_page.dart:454`）。
- **图片**：`image_sources.dart:27-44` 缓存 data URL 的 provider，头像/封面不会每次 build 重新解码。
- **轻提示**：逐帧动画被 `AnimatedBuilder` 限制在进度条上（`feedback.dart:710-728`）。
- **滚动列表内无 `Opacity` / `IntrinsicHeight` / `IntrinsicWidth` / `AspectRatio`**（仅 `import_preview_page.dart:684` 与 `image_cropper.dart:122`，都有界）。
- **`MediaQuery` 读取大多是收窄的**（`sizeOf`/`viewInsetsOf`/`highContrastOf`）；只有 P1-7 提到的两处弹层是全量读取。
- **热路径上没有账目数据的同步 JSON 编解码**：`exportDataJson` / `importDataJson` 都是用户主动触发的批量操作。
- **测试现状**：没有任何重建计数或帧时间测试；唯一与性能相关的记录是 `known-limitations.md`。`lib/` 中没有性能相关的 TODO/FIXME。

## 7. 建议的修复批次（等确认后执行）

1. **第一批（P0，改动集中、收益最大）**：P0-2 加 `RepaintBoundary` + 指示器改绘制驱动；P0-3 搜索防抖 + 提取 descendant 集合；P0-1 首页聚合合并为单遍 + `PageView` 保活。
2. **第二批（P1 数据层）**：P1-4 交易保存改事务内差分；P1-5 资产页合并为单遍 + 缓存；P1-6 正则预编译 + 分词缓存 + 防抖。
3. **第三批（P1 绘制与重建）**：P1-7 金额键盘弹层去模糊/加边界；P1-8 分页签名拆分；P1-9 按字段迁 `ValueNotifier`（分批，一次一个偏好）。
4. **第四批（P2 随手改）**：P2-11 的 `listEquals`、P2-10 的缓存、P2-12/P2-13 的单遍化属于低风险顺手项。

每批都要：`dart format .` → `flutter analyze` → `flutter test`；涉及 UI 的补 393×852 / 360dp 布局测试；P0/P1 修复后按各条「验证方式」在真机上复测一次。

## 8. 未完成的验证（需在修复阶段补齐）

- 真机 profile 帧时间基线（修复前/后各一次），以及 release/R8 下的复测。
- `debugRepaintRainbowEnabled` 对 P0-2 的实测确认。
- 5000 笔量级的账本尚未构造；建议在修复时用 `docs/dev/verifin-sample-backup.json` 或脚本生成大数据集做基准。
