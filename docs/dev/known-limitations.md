# 已知限制与技术债台账

记录 Veri Fin **已知的架构限制、被有意接受的技术债、以及触发整改的阈值**。与 `tech-decisions.md`（记「已决策」）互补：本文件记「已知会痛、但当前不改或分阶段改」的东西，让隐性认知显性化、可追踪。

新发现的限制请登记到此；某项整改完成后从「整改中」移除或在「已接受」里更新状态。

---

## 已接受的债（定阈值，暂不改）

### L1 · 账目数据整表覆盖写入 —— 写放大随总量线性增长
- **现状**：`SqliteLedgerRepository` 每次保存执行「删全表 + 全量重插」（`_replaceInTxn`）。即每记一笔账都把整张 `entries` 表重写一遍；余额计算 `accountBalance` 对全部交易 O(n) 求和，资产页为每账户各算一次即 O(账户数 × 交易数)。
- **影响**：几百到几千笔无感；**到数万笔时**，每次记账/编辑/自动备份都要序列化重写数万行，会出现可感知延迟。
- **为何暂不改**：当前规模零收益，改为「增量写入 + 增量维护的余额缓存」改动面大、有回归风险，属过早优化。附件已独立表按需读，主要压力在 `entries`。
- **触发阈值**：`entries` 行数 > **5000**，或收到「记账保存卡顿」反馈。届时启动：`add/update/deleteEntry` 走单行 `insert/update/delete`（表已有主键 `id`），`saveEntries` 整表语义仅保留给导入/恢复；余额改为增量缓存或单遍分配（把 O(A×N) 降到 O(N)）。

### L2 · 数据库 schema 只升不降
- **现状**：`AppDatabase._onUpgrade` 只有升级路径，无 downgrade。用户装了高版本再装回低版本，打开库会命中 `DatabaseErrorApp` 兜底页（明确提示「数据可能还在，别清数据」）。
- **为何接受**：Android 正常渠道不会降级安装；写双向迁移成本高、收益低。
- **缓解 / 约定**：已有兜底页保护用户数据不被误删。发版说明里应提示「不支持降级安装」。改 schema 必须升 `schemaVersion` 并写 `_onUpgrade` 分支（见 `CLAUDE.md` 数据层说明）。

### L3 · 退款条目不进通用时间线 —— 跨账户退款的到账账户无独立可见行
- **现状**：退款（`EntryType.refund`）在原支出的「退款」区管理，**不进**交易列表 / 首页 / 账户流水（净额已体现在支出行、带「已退」标记）。退款进的是**到账账户**的余额。当退款退到**与原支付不同的账户**时，那个账户的余额会 + 一笔，但它的交易列表里没有对应的可见行来解释这笔增加。
- **影响**：同账户退款无感（支出行净额已解释）；仅**跨账户退款**时，到账账户会出现「余额变了却找不到对应交易」的轻微困惑。使用频率低。
- **为何暂不改**：把已到账退款渲染成时间线独立行需处理金额显示（退款 `signedAmount=0`）、专用标签、点击跳回原支出、待到账过滤等，改动面不小；当前 per-expense 退款区已提供完整可见性。
- **触发阈值**：收到「跨账户退款账户对不上账」类反馈，或决定做 Simplifi 式时间线退款行。届时：`TransactionTile` 为 refund 分支显示 `+金额` 与「退款」标、`openEntryDetail` 对 refund 跳 `refundOf`、各列表放行**已到账**退款、过滤**待到账**退款。

### L3 · 无远程崩溃/遥测上报（有意）
- **现状**：全局错误经 `runZonedGuarded` + `FlutterError.onError` 只写**本地** `AppLogger`，用户可在「软件日志」页导出分享；无 Sentry/Crashlytics/Firebase。
- **为何接受**：符合「数据自主、隐私优先、本地优先」定位，是刻意取舍，不是缺陷。
- **代价 / 缓解**：开发者无法主动发现线上崩溃，只能等用户反馈。可考虑「崩溃后引导用户导出诊断日志」的纯本地方案弥补盲区，但不引入任何联网遥测。

---

## 整改中（本轮工程化加固逐步落实）

以下为已识别、正在分批整改的工程化债；完成后从本节移除。

- （已完成，2026-07）**单 Controller 过载**：`VeriFinController` 已用 mixin 物理拆分为
  `veri_fin_controller.dart`（瘦身后的类：构造/`create`/`dispose`/注入字段）、
  `veri_fin_controller_state.dart`（`_ControllerState` mixin：全部内存字段 + KV/SQLite 载入落库 + 基础 hub 方法）、
  `veri_fin_controller_ops.dart`（`_ControllerOps mixin on ChangeNotifier, _ControllerState`：全部领域操作）。
  单一 ops mixin 规避跨领域符号解析问题；偏好键、`_panelsKeyFor`、`_compareEntriesLatestFirst` 降为库级私有以便各 part 共享。
- （已完成，2026-07）**超大页面文件**：`profile_pages` 拆为 settings/category/tag/profile-info/ledger-books 等独立库 + barrel 导出；
  `budget_pages` / `assets_pages` / `data_management_page` 用 `part` 拆出趋势图/支撑件/快照计算/对话框/子页；
  `transactions_pages` 抽出 `transaction_detail_page`。均纯机械拆分、零行为变化，`flutter analyze` 与全量测试通过。

拆分方式备忘（供后续参考）：**独立页面**（无共享私有符号、可能被外部引用）→ 独立库 + `export` barrel，调用点 import 不变；
**共享私有 widget/字段的同域代码** → `part`（同库、私有可见、import 只在主文件声明一次）；
**单个超大有状态类** → mixin（`on ChangeNotifier` 可干净调用 `notifyListeners()`，`on 基础State mixin` 可访问其字段），
extension 不行——其调用 `notifyListeners()` 会触发 `invalid_use_of_protected_member`。

整改进度不在本文件逐条勾选；以 git 历史与 `CHANGELOG.md` 为准。

### 有意缓做（评估后判定：高风险 / 低当前收益）

- **偏好类 KV 剥离为独立 notifier**：可修掉「偏好改动触发全树重建」的性能问题，但需把 ~15 个偏好字段搬出 controller、新建独立 scope，**每个读取点都要改**，漏一个即运行时错误；而该性能问题属「规模变大才疼」。判定为中期项，规模/团队变大或出现掉帧后再单独做。
- **`Clock` 依赖注入**：ID 碰撞隐患已通过统一的 `_generateId`（微秒时间戳 + 单调序号）根治；批量/幂等路径（导入计数器、周期规则确定性 id）本就安全。剩余的「时间可控测试」需求已由 `applyDueRecurring(now)` 这类传参覆盖，全量注入 Clock 收益有限，暂缓。
