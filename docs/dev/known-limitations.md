# 已知限制与技术债台账

记录 Veri Fin **已知的架构限制、被有意接受的技术债、以及触发整改的阈值**。与 `tech-decisions.md`（记「已决策」）互补：本文件记「已知会痛、但当前不改或分阶段改」的东西，让隐性认知显性化、可追踪。

新发现的限制请登记到此；某项整改完成后从「整改中」移除或在「已接受」里更新状态。

---

## 已接受的债（定阈值，暂不改）

### 玻璃候选材质的渲染开销

高级材质会采样导航纹理并执行折射，在部分设备上可能增加切页延迟。现提供默认关闭、设备持久化的“高级材质”开关；关闭时不创建透镜组件。此选项不是对高级路径已经流畅的保证。若普通磨砂路径仍能稳定复现卡顿，或准备将候选设计默认发布，应先在 Android 真机采集帧时间，定位额外重建/纹理采样开销后再调整；不得只降低文字清晰度掩盖问题。规则见 [统一设计规范](../design-system.md)。


### L1 · 余额计算 O(账户数 × 交易数) —— 大数据量下重复全量求和
- **现状（写放大部分已解决，2026-07；聚合保存例外更新于 2026-08）**：`SqliteLedgerRepository` 的普通 `saveX` 已改为**行级差分**（`_incrementalReplace`）——交易/账本/账户/分组/分类/标签/周期规则各保留内存行快照，只写变化行，单条记账不再重写整张 `entries` 表。整表覆盖包括：附件表（含大 blob）、预算表（极小）、交易详情为保证本体/退款/附件跨表原子性而使用的 `saveEntryAggregate` 事务，以及导入/恢复走的 `replaceAllLedgerData` 原子整替。**剩余债**在计算侧：余额 `accountBalance` 对全部交易 O(n) 求和，资产页为每账户各算一次即 O(账户数 × 交易数)。
- **影响**：几百到几千笔无感；**到数万笔且账户多时**，资产页/看板每次重建都要 O(A×N) 全量求和，可能出现可感知延迟。
- **为何暂不改**：当前规模零收益，改为「增量维护的余额缓存」有回归风险，属过早优化。写放大这条更痛的已先行解决。
- **触发阈值**：`entries` 行数 > **5000** 且账户数多，或收到「资产/看板卡顿」反馈。届时把余额改为增量缓存或单遍分配（把 O(A×N) 降到 O(N)）。

### L2 · 数据库 schema 只升不降
- **现状**：`AppDatabase._onUpgrade` 只有升级路径，无 downgrade。用户装了高版本再装回低版本，打开库会命中 `DatabaseErrorApp` 兜底页（明确提示「数据可能还在，别清数据」）。
- **为何接受**：Android 正常渠道不会降级安装；写双向迁移成本高、收益低。
- **缓解 / 约定**：已有兜底页保护用户数据不被误删。发版说明里应提示「不支持降级安装」。改 schema 必须升 `schemaVersion` 并在 `_migrations` 注册迁移段（见 `CLAUDE.md` 数据层说明；迁移矩阵测试覆盖从每个历史版本升级）。

### L3 · 退款条目不进通用时间线 —— 跨账户退款的到账账户无独立可见行
- **现状**：退款（`EntryType.refund`）在原支出的「退款」区管理，**不进**交易列表 / 首页 / 账户流水（净额已体现在支出行、带「已退」标记）。退款进的是**到账账户**的余额。当退款退到**与原支付不同的账户**时，那个账户的余额会 + 一笔，但它的交易列表里没有对应的可见行来解释这笔增加。
- **影响**：同账户退款无感（支出行净额已解释）；仅**跨账户退款**时，到账账户会出现「余额变了却找不到对应交易」的轻微困惑。使用频率低。
- **为何暂不改**：把已到账退款渲染成时间线独立行需处理金额显示（退款 `signedAmount=0`）、专用标签、点击跳回原支出、待到账过滤等，改动面不小；当前 per-expense 退款区已提供完整可见性。
- **触发阈值**：收到「跨账户退款账户对不上账」类反馈，或决定做 Simplifi 式时间线退款行。届时：`TransactionTile` 为 refund 分支显示 `+金额` 与「退款」标、`openEntryDetail` 对 refund 跳 `refundOf`、各列表放行**已到账**退款、过滤**待到账**退款。

### L3 · 无远程崩溃/遥测上报（有意）
- **现状**：全局错误经 `runZonedGuarded` + `FlutterError.onError` 只写**本地** `AppLogger`，用户可在「软件日志」页导出分享；无 Sentry/Crashlytics/Firebase。
- **为何接受**：符合「数据自主、隐私优先、本地优先」定位，是刻意取舍，不是缺陷。
- **代价 / 缓解**：开发者无法主动发现线上崩溃，只能等用户反馈。可考虑「崩溃后引导用户导出诊断日志」的纯本地方案弥补盲区，但不引入任何联网遥测。

### L4 · 汇率完全离线，不做行情与汇兑损益
- **现状**：只支持 ISO 4217 法定货币；汇率由用户按日手工维护或从导入文件带入，应用不联网下载、不后台刷新。跨币转账保存两端实际金额，但不计算外汇持仓成本、已实现/未实现汇兑损益。
- **影响**：频繁跨境消费的用户需要自行补汇率；资产估值可能使用较旧的最近历史汇率，超过 30 个日历日会提示可能过期。缺率时总资产/走势不展示部分和。
- **为何接受**：这是「本地优先、无自有服务端」的明确产品边界；联网行情会引入第三方依赖、隐私披露、可用性和长期维护成本，汇兑损益则需要远超个人记账首版的持仓批次模型。
- **触发阈值**：只有用户明确要求且能提供可审计的数据源/隐私方案时，才单独设计可选联网汇率；不能把网络请求偷偷塞进现有离线汇率入口。

### L5 · 多币种金额仍使用 `double` / SQLite `REAL`
- **现状**：金额在领域边界按各币种 minor unit 归一，汇率保留更高精度，但底层仍沿用 `double` 和 SQLite `REAL`，未全量迁移为整数 minor units 或十进制定点数。
- **影响**：大量运算内部可能出现二进制浮点尾差；当前由币种感知舍入、容差比较和零值归一消除用户可见误差。
- **为何接受**：同一版本同时做多币种语义和全库整数迁移会显著放大迁移/备份风险；现有测试已覆盖 JPY/CNY/KWD 舍入和跨币换算边界。
- **触发阈值**：出现无法由 minor-unit 边界归一解决的真实对账问题，或需要高精度会计/证券能力时，另立 schema 迁移设计，禁止局部混用两套存储单位。

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
- （已完成，2026-07）**结构审查整改轮**（问题清单与整改记录见 `docs/dev/code-review-2026-07.md`）：
  源文件裸 NUL 字节修复；新增模型字段往返 / 仓储双实现契约 / 全版本迁移矩阵 / xls_reader·plan_builder 专项四组测试；
  数据库迁移改按版本注册表（缺段升级即抛错）；备份字节编解码收口 `BackupService.decodeBackupBytes`/`decryptEnvelope`（controller 只认明文 JSON）；
  `platform_bridge` 按域拆五个 Bridge 类；`models.dart` 按域拆 `models/` 六文件（barrel 兼容）；`common_widgets` 按域拆六个 part；
  `demo_data` 拆出 `icon_catalog`/`model_lookup`；`Category.normalizeParentId` 收拢两处反序列化重复。

拆分方式备忘（供后续参考）：**独立页面**（无共享私有符号、可能被外部引用）→ 独立库 + `export` barrel，调用点 import 不变；
**共享私有 widget/字段的同域代码** → `part`（同库、私有可见、import 只在主文件声明一次）；
**单个超大有状态类** → mixin（`on ChangeNotifier` 可干净调用 `notifyListeners()`，`on 基础State mixin` 可访问其字段），
extension 不行——其调用 `notifyListeners()` 会触发 `invalid_use_of_protected_member`。

整改进度不在本文件逐条勾选；以 git 历史与 `CHANGELOG.md` 为准。

### 有意缓做（评估后判定：高风险 / 低当前收益）

- **偏好类 KV 剥离为独立 notifier**：可修掉「偏好改动触发全树重建」的性能问题，但需把 ~15 个偏好字段搬出 controller、新建独立 scope，**每个读取点都要改**，漏一个即运行时错误；而该性能问题属「规模变大才疼」。判定为中期项，规模/团队变大或出现掉帧后再单独做。
  量化基线（2026-07 审查 M1）：controller 共 84 处 `notifyListeners()`，`VeriFinScope` 为裸 `InheritedNotifier`，任一通知全树重建 + 四个派生视图缓存全失效。**约定：新增偏好一律照主题/语言的独立 `ValueNotifier` 先例做**（`themePreferenceListenable`/`localePreferenceListenable`），不再往全树广播里加。
- **BackupCoordinator 窄接口化**（2026-07 审查 M6）：其静态方法直接接收整个 `VeriFinController`、读六七个成员，是全项目唯一「吃整个 controller」的服务（notification_scheduler、ai_client 都是窄注入）。当前可测（`backup_coordinator_test.dart`）、行为正确，改注入面收益有限，暂不动。触发阈值：新增第二个类似协调器、或备份决策逻辑需要独立轻量单测时，改为窄参数注入（settings、webdavConfig、`exportJson` 回调、logger）。**勿再复制此模式。**
- **`Clock` 依赖注入**：ID 碰撞隐患已通过统一的 `_generateId`（微秒时间戳 + 单调序号）根治；批量/幂等路径（导入计数器、周期规则确定性 id）本就安全。剩余的「时间可控测试」需求已由 `applyDueRecurring(now)` 这类传参覆盖，全量注入 Clock 收益有限，暂缓。

### Web 开发预览边界

Web 直接运行真实页面和 SQLite 仓储；当前定位是开发预览。AI 网络请求、WebDAV、
目录自动备份、OCR、系统通知、生物识别、FLAG_SECURE、桌面小组件和 APK 安装不支持。
数据按 origin 隔离，仅支持单标签页编辑（Controller 内存状态尚无跨标签失效广播）；
清理站点数据/隐私模式/浏览器存储回收可能丢失本地预览数据。触发公开 Web 交付或
多人/多标签需求时，必须补存储持久化权限、跨标签协调、浏览器兼容和平台功能验收。
当前验收与替代操作见 [web-preview.md](web-preview.md)。
