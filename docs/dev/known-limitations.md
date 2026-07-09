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

### L3 · 无远程崩溃/遥测上报（有意）
- **现状**：全局错误经 `runZonedGuarded` + `FlutterError.onError` 只写**本地** `AppLogger`，用户可在「软件日志」页导出分享；无 Sentry/Crashlytics/Firebase。
- **为何接受**：符合「数据自主、隐私优先、本地优先」定位，是刻意取舍，不是缺陷。
- **代价 / 缓解**：开发者无法主动发现线上崩溃，只能等用户反馈。可考虑「崩溃后引导用户导出诊断日志」的纯本地方案弥补盲区，但不引入任何联网遥测。

---

## 整改中（本轮工程化加固逐步落实）

以下为已识别、正在分批整改的工程化债；完成后从本节移除。

- **单 Controller 过载**：`VeriFinController` 约 2600 行、~30 领域，待用 `part`/mixin 物理拆分；偏好类 KV 待中期剥为独立 notifier。
- **超大页面文件**：`profile_pages` / `budget_pages` / `transactions_pages` / `data_management_page` 待按子页拆分。
- **时间/ID 硬编码 `DateTime.now()`**：ID 依赖 `microsecondsSinceEpoch`，理论有碰撞窗口（`addAttachment` 已加序号缓解），待注入 `Clock` + 稳健 ID。
- **CI 仅 tag 触发**：普通 push / PR 不跑 analyze+test，待加质量门禁。
- **依赖滞后**：`local_auth` 栈落后一个大版本，待升级。

整改进度不在本文件逐条勾选；以 git 历史与 `CHANGELOG.md` 为准。
