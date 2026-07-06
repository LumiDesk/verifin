# 技术决策记录

Veri Fin 关键技术选型与理由。变更相关实现时同步更新本表。功能现状见 `CLAUDE.md` 架构说明，实现明细见 git 历史。

| 决策 | 选择 | 原因 |
|------|------|------|
| SQLite 方案 | `sqflite` + `sqflite_common_ffi`（测试） | 单一 API，无需 build_runner 代码生成，符合仓库「不引入额外工具链」约定；drift 需常驻 codegen |
| i18n 方案 | Flutter 内置 gen-l10n（ARB，zh 为模板语言） | 官方方案零额外依赖；`generate: true` 由 pub get 自动生成 |
| 语言偏好 | `LocalePreference`（跟随系统/zh/en）存 KV `verifin.locale.v1`，设备本地、不进备份、初始化保留；`MaterialApp.locale` 经 `ValueNotifier` 即时切换 | 语言是设备偏好而非账目数据；null locale 交系统解析、非中文回落英文 |
| 无 context 文案 | 小组件/通知/生物弹窗经 `l10nForPreference(LocalePreference)` 用 `lookupAppLocalizations` 解析，失败回落中文 | 这些场景拿不到 BuildContext；按偏好显式解析保持与应用语言一致 |
| 种子数据语言 | 首启动/初始化按当时语言偏好播种（`systemIsEnglish` 由 main 传入）；播种后属用户数据不再切换 | 账本/分类名是数据不是 UI；随语言反复改名会破坏用户编辑 |
| 备份格式 | 未加密备份为 **zip**（`backup.json` + `attachments/<id>` 图片文件），加密备份沿用文本信封 `.json`；导入按 zip 魔数自动识别，旧版纯 JSON/加密备份仍可导入 | 附件以 base64 内嵌 JSON 会让备份随附件急剧膨胀（放大 33% 且每次整份重写），zip 把图片剥离外置；加密走文本信封复用既有加密逻辑；魔数识别保证老备份永远可导入 |
| 偏好类数据 | 保留 KV（SharedPreferences），不迁 SQLite | 小而简单，迁移无收益 |
| SQLite 切换方式 | 开发期直接切换，不做 KV→SQLite 迁移、不留 KV 回退双路径；`LedgerRepository` 抽为接口，`SqliteLedgerRepository` 为生产实现，全新库首启动播种默认数据 | 应用尚无用户，允许不兼容旧数据结构；一次切干净，避免长期维护双路径隐患 |
| 测试仓储 | widget/控制器逻辑测试注入 `InMemoryLedgerRepository`（同步、无真实 I/O），数据层真实 SQLite 用 ffi 单独覆盖 | sqflite 的后台 isolate 与 `testWidgets` 的 fake-async 会死锁；内存实现规避且更快 |
| 备份目录 | Android 走 SAF（`ACTION_OPEN_DOCUMENT_TREE` + 持久化 URI 权限 + `DocumentFile`），桌面走 `file_selector` 目录 + `dart:io` | 分区存储下唯一可长期读写用户可见目录的方式；条件导入 `lib/app/backup/backup_storage_*.dart` |
| 备份加密 | `cryptography`（纯 Dart AES-GCM + PBKDF2-SHA256），口令明文存本机 KV | 加密属非简单需求需成熟库；纯 Dart 全平台无原生依赖；口令保护离开设备的备份文件，本机数据本在应用私有区 |
| CSV 导入范围 | 通用 CSV 走自研 RFC-4180 解析器；支付平台账单按来源单独适配（支付宝/微信/薄荷）；微信 xlsx 用已有 `archive` 解压 + 正则解析 XML（不引入 `excel`/xlsx 依赖） | CSV 覆盖多数表格工具；微信只导出 xlsx，为体验直接在应用内解析而非要求用户转格式，复用 `archive` 与「手写 XML 正则」惯例避免重量级依赖 |
| 账单多编码解码 | 引入纯 Dart `charset` 包（支付宝导出为 GBK、薄荷为 UTF-16LE）；读文件按字节、按平台/BOM 解码 | GBK 无成熟纯手写方案（映射表庞大），属非简单需求；`charset` 纯 Dart 全平台无原生依赖，类比加密引入 `cryptography` |
| 平台优先导入 | 用户先选账单来源再选文件（不靠表头猜测），各来源解析后归一到 Veri Fin 规范列再复用 `buildImportPlan` | 同名列/编码/分隔各平台差异大，显式选来源比自动识别稳；归一化让建账户/分类/错误处理只有一套 |
| 无账户记账 | `LedgerEntry.accountId` 允许为空串（转账 `toAccountId` 可空），表示「无账户」；`ledger_math` 天然按 id 匹配，空 id 不影响任何余额但计入收支；展示用 `accountDisplayName` 避免 `accountById` 回退首个账户 | 支持「只记数字不选账户」的记账习惯，让含「不计资产」记录的账单可干净导入；数学层无需改动，改动集中在展示与记账 UI |
| WebDAV 客户端 | `dart:io HttpClient` 手写 PUT/GET/PROPFIND/MKCOL + Basic Auth，PROPFIND XML 用正则按局部名解析 | 不引入 WebDAV/HTTP 第三方依赖；命名空间前缀不固定用局部名匹配 |
| 多级分类结构 | 邻接表：`Category.parentId`（可空，顶级为 null），非物化路径/嵌套集；同级顺序沿用列表位置（`sort_order`）；子分类类型强制继承父分类 | 记账分类量级小、层级浅，邻接表最简单；改动只加一列一次迁移；树运算集中在 `category_tree.dart` 纯函数（带环检测），便于测试 |
| 分类层级聚合口径 | 看板分类统计（环形/明细）把每笔交易归总到其**顶级祖先**分类；分类预算的「已花」把子分类支出上滚到各级父分类 | 顶级归总符合用户对「大类占比」的预期；预算上滚让父分类预算能约束整棵子树，子分类仍可单独设预算 |
| 标签存储 | 交易与标签多对多，用交易表 `tag_ids` 单列存 JSON 数组，不建关联表；标签全局共享不分账本 | 与现有「整表覆盖式读写」一致，避免引入关联表与联表查询；标签量小、跨账本复用更自然 |
| 图片附件存储 | 压缩 JPEG（最长边 1600、q80）存 data URL，放**独立 `attachments` 表**（非 entries 表）；备份时由 `backup_archive` 把附件字节剥离进 zip 的 `attachments/<id>` | 放 entries 表会让「整表覆盖式」写入把所有图片 base64 反复重写（放大严重）；独立表只在增删图片时重写；备份用 zip 外置附件避免 base64 膨胀 |
| 报销/退款模型 | 退款/报销回款统一记为原支出的 `refundedAmount`（回到原账户、冲抵原交易），不新建收入条目；「待报销」只是标记 | 单字段冲抵最简单，天然满足「回款不计收入」；退款回原账户是最常见场景。代价：跨账户报销暂用近似（记在原账户） |
| 周期记账补记时机 | 打开应用与回前台时 `applyDueRecurring(now)` 一次性补齐所有到期交易，不用后台定时任务/通知 | 本地优先、无服务端；应用不常驻，开屏补记足够且省电；`nextRunDate` 幂等推进保证不重复补记 |
| 记账提醒通知 | `flutter_local_notifications`+`timezone`+`flutter_timezone`；inexact 调度（`inexactAllowWhileIdle`）+`matchDateTimeComponents: time` 每日重复 | 本地通知属平台能力需成熟库；inexact 免 `SCHEDULE_EXACT_ALARM` 特殊权限；配置为设备本地偏好，存 KV、不进 JSON 备份 |
| 桌面小组件 | 原生 `AppWidgetProvider` + `RemoteViews`，数据经现有 `verifin/app` MethodChannel 写入原生 SharedPreferences，不引入 `home_widget` 依赖 | 点击快速记账直接复用已有 `ACTION_QUICK_ENTRY` 机制；数据只是一个「今日支出」字符串，避免为单一小组件引入第三方桥接依赖 |
| 自动记账（通知/屏幕识别） | 曾实现 NLS 通知监听 + AI 解析 + 确认落账（main 提交 `9f1ace8`…`6dca361`），经 revert `0eb3ba5` 撤回，长期搁置 | 真机不可靠：App 被杀即停需前台服务保活、银行「到账」默认漏识别、识别偏慢；且通知监听权限敏感、易随各 App 文案失效、合规风险高。实现仍在 main 历史可捡回；若重启先解决保活+银行覆盖，勿按银行写正则 |
| 金额小数位显示 | 用户偏好「金额是否强制两位小数」存 KV `verifin.amount_format.v1`（设备本地、不进备份、初始化保留）；由 controller 单向同步到顶层可变量 `amount_format.dart` 的 `amountForceTwoDecimals`，金额格式化入口 `formatAmount`（及派生的 expense/income/signed）读它 | 金额格式化是无 BuildContext 的纯函数，且在桌面小组件、本地通知、`series_math` 等拿不到 context 处也被调用，无法经 `VeriFinScope` 注入；用 controller 同步的顶层量做单向广播，零调用点改动即全局生效 |
| 记账自动分类 | 纯函数 `category_suggest.dart` 从用户**本人历史**（同账本同类型）按备注字符二元组 Jaccard 相似度（主）+ 时段习惯 + 金额习惯 + 频次先验加权打分，超阈值且领先次高分才建议；记账页在用户未手动选分类前自动选中并提示，手动选后不再覆盖 | 本地优先、无需模型/网络，规则透明可测；备注是最强信号，习惯项作弱先验；只在有把握时才改选、且随时可覆盖，避免「越猜越乱」。中文无空格分词，字符二元组对短备注已足够稳 |

