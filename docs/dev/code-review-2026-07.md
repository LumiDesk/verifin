# 代码结构审查报告（2026-07）

对全仓（lib/ 约 5.6 万行 Dart，不含生成的 l10n）做的一次结构与解耦专项审查。方法：按「状态管理 / 页面层 / 数据层 / 备份导入与 AI / 横切关注点与测试」五个域并行探查，所有写入本报告的结论都经过逐条代码核实，探查中产生的误报已剔除（见附录）。

与 [known-limitations.md](known-limitations.md) 的分工：那边记「已知且有意接受的债」，本报告只列**新发现**的问题，并对个别已登记项补充量化证据。已登记项（余额 O(账户×交易)、schema 只升不降、退款不进时间线、无遥测、偏好剥离缓做、Clock 注入缓做）不重复展开。

## 总体结论

分层方向是健康的：`lib/app`（领域/工具）→ `lib/pages`（UI）单向依赖，零反向引用；条件导入三件套 9 对全部模式统一；CLAUDE.md 承诺的几条核心架构约定（导入 facade、plan_builder 单一真源、AI 四层分层、i18n 全覆盖）经逐一核对**均已兑现**。主要问题集中在三类：**手写重复映射**（模型序列化四处同步）、**跨层重复的小块逻辑**（备份格式判定、parentId 规范化）、**单文件承载不相关职责**（platform_bridge、models.dart）。另有一处工具链层面的硬问题（源文件嵌裸 NUL 字节）建议尽快修。

---

## 一、问题清单

### 高

#### H1 源文件嵌入裸 NUL 字节，文本工具链把整个文件当二进制

`lib/app/veri_fin_controller_state.dart:284` 的分类去重键把 `\u0000` 分隔符**以裸字节形式**写进了源文件（`'${c.type.storageValue}<0x00>${c.parentId ?? ''}<0x00>${c.label}'`）。Dart 编译器接受它，但 `grep`、`file` 等所有按字节嗅探的文本工具都把该文件识别为二进制并**静默跳过**——本次审查中 `grep -rn onPersistError lib/` 就漏掉了这个文件，`file` 输出为 `data`。这意味着任何针对该文件的全仓文本搜索（人肉排查、CI 脚本、外部工具）都会漏检，而且没有任何报错。全仓扫描确认仅此一处（两个 NUL，同一行）。

**修复**：把两个裸字节改写为 `\u0000` 转义，行为完全等价（该键只用于 `_healCategoryData` 内存去重，不落库）。一行改动，建议尽快做。

### 中

#### M1 变更通知无粒度：84 处 `notifyListeners()` 全树广播

`veri_fin_controller_ops.dart` 共 84 处 `notifyListeners()`；`VeriFinScope` 是裸 `InheritedNotifier`（`lib/app/veri_fin_scope.dart`），任一通知使所有依赖它的 widget 全部重建，同时四个派生视图缓存全量失效（`veri_fin_controller_state.dart:53-64`）。改主题、开关触感、添加一张附件，代价都等同于一次记账。

known-limitations.md 已把「偏好剥离独立 notifier」登记为有意缓做，本条不是要求现在做，而是补充两点：① 量化基线（84 个广播点）供日后评估；② 代码里**已有可复制的先例**——主题与语言已经走独立 `ValueNotifier`（`themePreferenceListenable`/`localePreferenceListenable`，state.dart:85-88），后续任何新增偏好可以直接照此模式，不再往全树广播里加。

#### M2 模型序列化四处手写映射，新字段要同步改四个地方

每个持久化模型有四套手写映射：`toJson`/`fromJson`（`models.dart`）+ `_xToRow`/`_xFromRow`（`ledger_repository.dart`）。以 `Account.cardLast4Follows` 为例，同一字段出现在 `models.dart:733`、`755` 与 `ledger_repository.dart:604`、`624`，各自维护默认值与类型转换（bool↔int）。10 个模型 × 4 处映射，加上 CLAUDE.md 要求的样例备份同步，一次加字段要动 5+ 个位置，漏一处即静默丢字段（旧备份导入回落默认值，无报错）。

**方向**：不必引入 freezed/json_serializable 这种全家桶（与「不为简单需求引入工具链」约束冲突），但至少可以：① 把每个模型的 4 处映射**物理放到一起**（拆 models.dart 时按模型分文件，SQLite 行映射挪到模型旁边或加交叉引用注释）；② 在 `repository_test.dart` 加一个「字段往返」测试模式——构造全字段非默认值的实例，JSON 往返 + SQLite 往返后逐字段断言，新字段漏映射立即红。第 ② 条成本低、收益直接，建议先做。

#### M3 备份格式判定与打包逻辑跨三层重复

「zip 还是加密 JSON」的分支逻辑存在于三处：`backup_service.dart:84`（自动备份 prepare）、`veri_fin_controller_ops.dart:1931/1937-1938`（手动导出/导入直接调 `packBackupArchive`/`looksLikeZipBytes`/`unpackBackupArchive`）、`data_management_page.dart:528`（页面自己再判一次 `looksLikeZipBytes` 走解密分支）。同时 `data_management_page.dart:9-16` 直接 import 了 `backup_archive`/`backup_crypto`/`webdav_client` 等实现模块。导入子系统有明确 facade（`transaction_import`/`payment_import`，核实确实被遵守），但**备份子系统没有对应的收口**，controller 和页面各自伸手进实现层。将来改备份格式（比如加新容器格式），至少要动三层。

**方向**：把「字节 → 判格式 → （解密）→ JSON」与「JSON → （加密/打包）→ 字节」两条管线收进 `backup_service.dart` 作为唯一入口，controller 只暴露 `exportDataJson`/`importDataJson`，页面只调 service。

#### M4 数据库迁移是 12 段 if 链，且无跨版本矩阵测试

`app_database.dart` 的 `_onUpgrade` 目前是 12 个顺序敏感的 `if (oldVersion < N)` 块（schemaVersion=13），部分块之间有隐式顺序依赖（v10 去重依赖 v9 结构）。`repository_test.dart` 覆盖了若干条迁移路径，但没有系统的「v1→13、v5→13、v12→13」矩阵。链条会随版本线性变长，是典型的「现在不疼、以后一定疼」。

**方向**：每段迁移抽成 `_migrateVnToVn1` 独立函数、`_onUpgrade` 只剩调度循环；测试侧加一个参数化的迁移矩阵用例（从各历史版本建库→升级→断言 schema 与数据完整）。

#### M5 platform_bridge.dart 单文件承载 6 个互不相关的原生域

`lib/app/platform_bridge.dart`（421 行）混装：快速记账磁贴、分享/外部采集消费、GitHub 更新检查下载、SAF 备份读写、桌面小组件推送与 pin、FLAG_SECURE。这些域之间零代码复用，只是共享一个 MethodChannel 常量。每加一个原生能力该文件继续膨胀，且改任何一个域都在同一文件制造 diff 噪音。

**方向**：按域拆成 3-4 个文件（采集/存储/更新/小组件与安全），共享 channel 常量即可，纯机械搬移。

#### M6 BackupCoordinator 静态耦合整个 VeriFinController

`backup_coordinator.dart:14-28` 的静态方法直接接收 `VeriFinController`，内部读取 `backupSettings`/`webdavConfig`/`exportDataJson()` 等六七个成员。测试只能通过构造完整 controller 进行（现有 `backup_coordinator_test.dart` 即如此），无法对「何时该备份」的决策逻辑做轻量单测；controller 任何相关成员改名都会波及这里。项目里其他服务（notification_scheduler、ai_client）都是窄接口注入，Coordinator 是唯一吃整个 controller 的。

**方向**：改为接收窄参数（settings、webdavConfig、`String Function() exportJson`、logger），或定义一个只含所需成员的接口由 controller 实现。优先级不高（当前可测、行为正确），但新增类似协调器时不要再复制这个模式。

#### M7 导入管道的两个核心组件没有专项单测

`xls_reader.dart`（439 行，手写 OLE2+BIFF8 二进制解析器，pub 上无替代库）与 `plan_builder.dart`（全部导入平台共享的落库计划生成器：账户/分类层级/标签构建、退款钳制、Tally 余额回推）都只经 `payment_import_test.dart`/`transaction_import_test.dart` 从 facade 间接覆盖，`test/` 71 个文件中没有它们的专项测试。二进制解析器的边界分支（SST 跨 CONTINUE 记录、MULRK 等）从 facade 层很难精确命中；plan_builder 是「漂移即全平台坏」的单点。鉴于导入历来是 bug 温床（issue #10、#11 都在这条管道上），这两处值得直接测。

### 低

#### L1 demo_data.dart 名不副实

`lib/app/demo_data.dart`（606 行）除播种数据外还承载生产核心纯函数：`iconForCode`、`iconLabelForCode`、`accountDisplayName`、`accountById`。CLAUDE.md 甚至专门提醒「展示层须用 `accountDisplayName`（demo_data.dart）」——关键函数住在一个叫 demo 的文件里，新人会低估其地位。建议把图标映射与账户助手拆出（如 `icon_catalog.dart`、`account_display.dart`），demo_data 只留种子数据。

#### L2 LedgerRepository 宽接口 + 双实现无契约测试

接口按 11 张表铺开 26 个 `load/save` 方法（`ledger_repository.dart:42`），每加一张表要在 `SqliteLedgerRepository` 与 `InMemoryLedgerRepository` 各改一遍，且两实现的行为一致性没有共享的契约测试约束（差分写行为只在 SQLite 侧测过）。接口形状本身与「saveX=整表语义」的设计自洽，不建议动；建议补一个两实现共跑的 contract test（同一组 save/load/replace 断言，参数化跑两遍）。

#### L3 弹窗组件类公开，包装约定靠自觉

`app/entry_sheets.dart` 的 `NumberPadSheet`/`CategoryPickerSheet`/`TagSelectorSheet` 是公开类，规范入口是 `pages/sheets.dart` 的 `show*Sheet` 包装。核实结果：当前**所有调用点都走了包装**（三个类只在 sheets.dart 出现），约定被遵守，但没有机制防绕过。低成本改进：组件类加 `@visibleForTesting` 或文档注释标注「勿直接实例化，走 showXSheet」。

#### L4 main.dart 生命周期挂钩存在隐式顺序依赖

`main.dart:186-209` 的 initState 挂 8 件事，`didChangeAppLifecycleState` 回前台再做 3 件（`main.dart:235-237`）。其中 `applyDueRecurring` 必须先于 `pushWidgetData`（否则小组件推的是补记前的旧数据），该顺序只靠代码行序维持、无注释说明。建议在 resumed 分支加一句顺序约束注释；若挂钩继续增多，再考虑拆「注册回调」与「一次性对齐」两个阶段。

#### L5 `Category.parentId` 空串规范化逻辑重复两处

`models.dart:1081-1089`（fromJson）与 `ledger_repository.dart:656-666`（fromRow）各写了一遍「空串归一为 null」。建议抽 `normalizeParentId` 静态助手，或在构造函数统一规范化。属 M2 四处映射问题的具体案例。

#### L6 KV 键常量大部分集中、少数散在

25 个 `verifin.*.v1` 键集中在 `veri_fin_controller.dart:50-74`（好），但 `app_logger.dart` 与 `app_lock.dart` 各自持有自己的键。初始化清除/备份豁免清单依赖「知道所有键在哪」，建议收拢到一个 `preference_keys.dart` 或至少在 controller 键表处注释指向另外两处。

#### L7 「新增导入平台 = 注册表加一行」实际是三处

`payment_import.dart` 的注册表模式本身干净，但新增平台实际要同步：`ImportPlatform` 枚举、`parsePlatformBytes` 的 case、parser 文件。Dart 的 switch 穷举检查（配合 `flutter_lints`）能在漏 case 时报警，风险可控；建议把 CLAUDE.md 的表述改准确（「枚举+注册 case+parser 文件」三处），避免误导。

#### L8 派生视图缓存失效是手工清单

`_invalidateDerivedViews`（state.dart:53-58）逐字段置空四个缓存视图，机制上以 `notifyListeners` 覆盖为唯一失效点（集中、正确），但**新增派生视图时要记得往这个函数加一行**，漏加即返回过期数据且无测试兜底。建议在字段声明处加注释「新增视图必须同步 _invalidateDerivedViews」，或将四个字段收进一个可整体置 null 的小结构。

---

## 二、核实为守住的约定（无需整改）

以下各项是本次专门核查过、结论为「干净」的，列出来供后续审查对照：

- **分层方向**：`lib/app` → `lib/pages` 零反向 import（grep 全仓核实）。页面层内部约 50 条互引边，以「入口页 → 子页」导航型单向引用为主，`sheets.dart`（19 个页面引用）与 `entry_detail_page.dart`（5）是预期中的汇聚点，未见环。
- **业务逻辑下沉**：抽查 home/reports/entry_detail/import_preview 等页面，聚合计算均调用 `ledger_math`/`home_metrics`/`category_suggest` 等纯函数层，页面只做 UI 状态与渲染。
- **条件导入三件套**：9 对 `stub + if (dart.library.io)` 全部模式一致，无走样。
- **导入 facade 与 plan_builder 单一真源**：外部（含页面与 controller）只 import `transaction_import`/`payment_import` 两个 facade，无绕过；各平台 parser 均产出 `RawImportRecord` 交 `plan_builder`，无平台私自复制金额/分类/标签解析逻辑；Tally 专用分支收敛在 `_applyTallyAssets` 一处（文档已承认）。
- **AI 子系统分层**：client（传输）/ ai_query_tool（协议+只读工具）/ ai_chat_engine（纯 Dart 可注入 transport）/ UI 四层边界清晰；注册表 5 个工具与 `docs/dev/ai-tools.md` 登记一致；工具确认全部只读。
- **i18n**：页面层抽查未发现豁免清单之外的硬编码中文。
- **全局可变状态**：顶层可变全局量全仓仅 `amountForceTwoDecimals` 一个（CLAUDE.md 已声明的设计，写入点收束于 controller）。
- **依赖清单**：pubspec 生产依赖逐个核对均有明确用途，无冗余。
- **数据层基础质量**：`_incrementalReplace` 差分写有针对性测试（未改行不重写/改动行才写/删除行才删）；`replaceAllLedgerData` 11 表同事务原子整替；SQLite 写失败有完整错误链路（`_trackWrite` → 日志 + `onPersistError` UI 回调）；KV 写有后台 flush 兜底（`local_storage_io.dart:52`）。KV 写错误被静默吞掉（`local_storage_io.dart:44`）是偏好类数据的有意取舍，内存副本保证会话内一致。
- **数据自愈**：`_healCategoryData`/`_migrateLegacyRefunds`/`_syncRefundCache` 幂等、在载入与导入两个入口统一触发。

## 三、审查中剔除的误报

探查阶段曾报告、经核实**不成立**的两条，记录在此防止将来重复上报：

1. 「删账户未清默认账户引用」——不实，`_clearDefaultAccountRef` 在两条删除路径都有调用（`veri_fin_controller_ops.dart:1360、1377`），且 getter 侧还有懒校验兜底。
2. 「页面绕过包装直接实例化弹窗组件」——不实，`CategoryPickerSheet` 等三个组件类全仓只在 `pages/sheets.dart` 的包装函数内出现。

## 四、优先级建议

| 优先级 | 项 | 工作量 | 说明 |
|---|---|---|---|
| P0 | H1 裸 NUL 字节改 `\u0000` | 一行 | 工具链静默漏检，改动零风险 |
| P1 | M2-② 字段往返测试 | 小 | 用测试兜住四处映射漂移，先于任何拆分做 |
| P1 | M7 xls_reader / plan_builder 专项单测 | 中 | 导入是历史 bug 高发区 |
| P2 | M3 备份管线收口到 backup_service | 中 | 下次动备份格式时顺手做 |
| P2 | M4 迁移函数化 + 矩阵测试 | 中 | 下次升 schemaVersion 时顺手做 |
| P2 | M5 platform_bridge 按域拆分 | 小 | 纯机械搬移，下次加原生能力时做 |
| P3 | L1/L5/L6/L8 等低项 | 各≤1h | 顺手清理，不必专门排期 |
| 记录 | M1 广播粒度、M6 Coordinator 耦合、L2 契约测试 | — | 建议登记进 known-limitations.md 观察，暂不动 |

## 五、与 known-limitations.md 的衔接

建议把以下三条登记为「已接受的债」（含触发阈值），使其显性化：

- **M1**：84 处全树广播（阈值：出现可感知掉帧，或偏好项继续增多时按主题/语言先例拆 ValueNotifier）。
- **M6**：BackupCoordinator 吃整个 controller（阈值：新增第二个类似协调器，或备份决策逻辑需要独立测试时）。
- **L2**：双仓储实现无契约测试（阈值：InMemory 与 Sqlite 行为首次出现分歧 bug 时补齐）。

---

## 整改记录（2026-07-12）

经维护者批准，除 M1/M6 外全部落实（各项独立提交，`flutter analyze` 与全量测试通过）：

| 项 | 处置 | 落点 |
|---|---|---|
| H1 裸 NUL 字节 | ✅ 已修 | state.dart 改 `\u0000` 转义，全仓恢复可 grep |
| M2② 字段往返测试 | ✅ 已加 | `test/model_roundtrip_test.dart`（JSON+SQLite 双往返，加字段必改夹具） |
| M2① models 拆分 | ✅ 已拆 | `lib/app/models/` 六个域文件，`models.dart` 为 barrel、导入路径不变 |
| M3 备份管线收口 | ✅ 已收 | `BackupService.decodeBackupBytes`/`decryptEnvelope` 唯一编解码入口；controller 删去 `importBackupBytes`/`exportBackupArchiveBytes`、只认明文 JSON；页面不再直引 archive/crypto |
| M4 迁移函数化 | ✅ 已改 | `_migrations` 按版本注册表（缺段升级即抛错）+ `test/migration_matrix_test.dart`（v1..v12 每版本起步升级、与全新库结构比对） |
| M5 platform_bridge 拆分 | ✅ 已拆 | 采集/更新/小组件/存储/安全五个 Bridge 类（part），入站分发保持单点 |
| M7 专项单测 | ✅ 已加 | `test/xls_reader_test.dart`、`test/plan_builder_test.dart` |
| L1 demo_data 名不副实 | ✅ 已拆 | `icon_catalog.dart`（图标映射）+ `model_lookup.dart`（查询回退），demo_data 只留种子 |
| L2 契约测试 | ✅ 已加 | `test/repository_contract_test.dart`（双实现共跑，含整替后差分基线） |
| L3/L4/L8 | ✅ 注释加固 | 弹窗组件标注包装入口；main.dart 回前台顺序约束；派生视图同步提醒 |
| L5 parentId 规范化 | ✅ 已收拢 | `Category.normalizeParentId`，JSON/SQLite 两条反序列化共用 |
| L6 键收拢 | ✅ 注释指路 | controller 键表注明仅 `verifin.logs.v1`（app_logger）在表外 |
| L7 文档措辞 | ✅ 已改 | CLAUDE.md「新增导入平台」改为枚举+注册 case+parser 三处 |
| 大文件（追加） | ✅ 已拆 | `common_widgets` 按域拆五个 part。`veri_fin_controller_ops` 单一 mixin 与页面文件**有意不动**（known-limitations 已记录其为规避符号解析问题的既定决策 / 上一轮已拆过） |
| M1 全树广播 | 📌 登记 | known-limitations「有意缓做」增补量化基线与「新偏好走 ValueNotifier」约定 |
| M6 Coordinator 耦合 | 📌 登记 | known-limitations「有意缓做」新增条目与触发阈值 |
