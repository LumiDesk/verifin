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
| CSV 导入范围 | 通用 CSV 走自研 RFC-4180 解析器；支付平台账单按来源单独适配（支付宝/微信/薄荷/一木）；微信 xlsx 用已有 `archive` 解压 + 正则解析 XML（不引入 `excel`/xlsx 依赖） | CSV 覆盖多数表格工具；微信只导出 xlsx，为体验直接在应用内解析而非要求用户转格式，复用 `archive` 与「手写 XML 正则」惯例避免重量级依赖 |
| 一木记账 .xls 读取 | 一木只导出老式 BIFF8 二进制 Excel（OLE2 复合文档），pub.dev 无库可读（`excel`/`spreadsheet_decoder` 均只支持 xlsx=zip+XML）；自写最小 OLE2+BIFF8 读取器 `xls_reader.dart`（纯 `dart:typed_data`，含 SST 跨 CONTINUE 拆分、RK/MULRK 数字解码） | 应用本地优先、离线可用，不宜要求用户先转格式或引入原生依赖；沿用仓库「手写二进制/XML 解析」惯例（WebDAV、xlsx），只实现账单所需最小记录集 |
| 账单多编码解码 | 引入纯 Dart `charset` 包（支付宝导出为 GBK、薄荷为 UTF-16LE）；读文件按字节、按平台/BOM 解码 | GBK 无成熟纯手写方案（映射表庞大），属非简单需求；`charset` 纯 Dart 全平台无原生依赖，类比加密引入 `cryptography` |
| 平台优先导入 | 用户先选账单来源再选文件（不靠表头猜测），各来源解析后归一到 Veri Fin 规范列再复用 `buildImportPlan` | 同名列/编码/分隔各平台差异大，显式选来源比自动识别稳；归一化让建账户/分类/错误处理只有一套 |
| 导入预览再落库 | 解析（`controller.parsePlatformImport`，纯解析不落库）与落库（`controller.applyImportEntries`）拆开，中间插入 `ImportPreviewPage`：交易按日期分组（复用 `groupEntriesByDate`/`DateGroupHeader`/`TransactionListCard`）列出，可排除 / 编辑（走 `EntryDetailPage.draft` 草稿模式，返回改后条目而不落库），确认返回 `ImportPreviewResult`，只创建被保留交易实际引用到的新账户/分类。全程零落库副作用（预览/编辑传「现有＋待新建」的合并账户/分类列表，`accountBalance` 对未落库账户天然返回其初始余额） | 直接入账无法纠错，账单常有脏数据/错分类；预览让用户先核对。`EntryDetailPage.draft` 做成通用「编辑一条交易并返回、不持久化」的模式，后续可复用。以后新增导入平台一律走此流程 |
| 导入账户/分类映射 | 预览页的可折叠「导入账户 / 导入分类」区：每个待新建账户/分类可**改名**（改 `newAccounts`/`newCategories` 的 name/label）或**映射到现有条目**（`_accountMapTo`/`_categoryMapTo`: 待新建 id → 现有 id）；展示与确认时 `_resolved` 把交易里对待新建 id 的引用整体替换为映射目标，故一次决定对所有引用它的交易生效 | 一份账单常有很多笔属于同一个「新账户」，逐条改账户太繁；按「来源账户名」整体决策一次到位，比逐条多选/逐条询问「是否也替换其它」更省事。映射走 id 替换，落库层 `applyImportEntries` 天然只创建仍被引用的待新建项 |
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
| 多小组件与添加入口 | 三个小组件（今日支出/本月预算/资产总额）共用 `WidgetData` 读写同一 SharedPreferences，`updateWidgetData` 一次推全部字段并广播刷新各 Provider；两个只读统计型小组件继承 `StatWidgetProvider` 共用 `stat_widget` 布局；应用内展示页经 `requestPinAppWidget`（`pinWidget`，API 26+）一键添加，不支持则回落手动引导 | Android 小组件类型必须编译期静态声明，运行时无法新建；用基类+共享布局摊薄新增成本；`requestPinAppWidget` 是「保存后加到桌面」最接近的系统能力，旧启动器安全回落 |
| 自动记账（通知/屏幕识别） | **定案：永久不做监听类**（NLS/无障碍/短信均不做，见 `docs/dev/auto-capture-plan.md`）。曾实现 NLS 通知监听 + AI 解析 + 确认落账（main 提交 `9f1ace8`…`6dca361`），经 revert `0eb3ba5` 撤回，不再捡回 | 真机不可靠：App 被杀即停需前台服务保活、银行「到账」默认漏识别、识别偏慢；且监听用户消息与「数据自主、本地优先」的产品立场冲突（与钱迹同立场）。替代：截图识账 + 外部意图接口（见下两行） |
| 截图识账 OCR | `google_mlkit_text_recognition`（中文模型）端上离线识别，条件导入两件套 `screenshot_recognizer_*`；按字节识别时落临时文件走 `InputImage.fromFilePath`，识别完即删；识别文本经 `requestCapturedEntryDraft`（专用提示词 + 无数字短路 + 4000 字截断）复用 AI 记账管线 | 图片不出设备契合本地优先（只有识别文本发往用户自配 AI，本地模型则全程不出设备）；ML Kit 是端上中文 OCR 唯一成熟 Flutter 方案，代价是安装包体积增大；直发视觉模型会把 AI 门槛提高到「必须支持视觉」且图片出设备 |
| 分享/外部采集入口 | `ShareReceiverActivity` 无界面跳板接收 `ACTION_SEND`（image/*、text/plain）与显式 `CAPTURE_TEXT` 意图（自动化工具用，`docs/automation.md`），转发回自家任务栈的 MainActivity 后立即 finish；MainActivity 暂存、Flutter 经 `consumeCaptureImage`/`consumeCaptureText` 拉取（仿快速记账 intent 模式）；原生限文本 8000 字、图片 25MB | `ACTION_SEND` 默认把目标 Activity 起在分享方任务栈，直指 MainActivity 会产生第二个 Flutter 引擎（双控制器写同一 SQLite）；跳板转发保持单实例、返回键回分享方。意图接口把「怎么触发」外包给自动化生态（学钱迹），一切入口只产草稿弹确认、绝不静默落账 |
| 金额小数位显示 | 用户偏好「金额是否强制两位小数」存 KV `verifin.amount_format.v1`（设备本地、不进备份、初始化保留）；由 controller 单向同步到顶层可变量 `amount_format.dart` 的 `amountForceTwoDecimals`，金额格式化入口 `formatAmount`（及派生的 expense/income/signed）读它 | 金额格式化是无 BuildContext 的纯函数，且在桌面小组件、本地通知、`series_math` 等拿不到 context 处也被调用，无法经 `VeriFinScope` 注入；用 controller 同步的顶层量做单向广播，零调用点改动即全局生效 |
| 记账自动识别 | 纯函数 `category_suggest.dart` 的 `suggestEntry` 从用户**本人历史**（同账本、含各类型）按金额接近度 + 备注字符二元组相似度 + 时段加权，取最像的几笔投票推断**类型/分类/标签/备注**；单笔支撑须「强匹配」（金额精确复现或备注重合）才敢翻转类型。记账页逐字段只填「用户尚未改过」的项，静默无提示 | 本地优先、无模型/网络、规则透明可测；从「找最像的历史」出发天然覆盖「又输 2.8→带出上次的分类/标签/备注」「0.01 曾记收入→推断收入」等诉求；「强匹配才翻类型」避免仅凭松散金额接近误判；不硬编码「小额=收入」之类常识规则，只信用户自己的历史 |
| 首页概览卡自定义 | 卡片 5 个标量槽（大数字/结余位/3 小卡片）+ 曲线序列 + 标题都可配；指标计算集中在纯函数 `home_metrics.dart`（`computeHomeMetric` + `HomeMetricContext` 快照，21 个指标各带周期口径与展示风格），配置 `HomeTrendConfig` 存 KV `verifin.home_metrics.v1`（设备本地、不进备份、初始化保留），设置页 `home_metrics_settings_page.dart` 即时保存 + 一键复位 | 指标是无 context 纯函数便于单测、复用 `sumByType`/`accountBalance` 口径与资产页一致；配置与 `fab_action` 等同属显示偏好；标题空回落「概览」。走势窗口从「分段 7 天」改为累积展开（`cumulativeWeekWindowFor`，1 号起按 7 天步进到当月），详情页用整月窗口（`monthWindowFor`）配合月份切换 |
| 软件日志 | `AppLogger`（`lib/app/logging/`）环形缓冲最近 200 条存 KV `verifin.logs.v1`（设备本地、不进备份）；`main` 的 `runZonedGuarded`+`FlutterError.onError` 记未捕获错误，`_trackWrite` 的 `catchError` 记落库失败并回调 UI 弹「保存失败」；「我的→数据与工具→软件日志」查看/复制/清空 | 之前落库失败被 `unawaited` 静默吞掉，用户以为已保存、重启却丢；日志给用户反馈问题时的诊断线索；诊断数据属设备本地、不进备份 |

## 备份范围（哪些进 JSON 备份 / 哪些设备本地）

**导出/导入必须与此表保持一致**（`exportDataJson`/`importDataJson`）。改动任一偏好的归属时同步更新这里、`CLAUDE.md`、`README.md`。

**进备份**（随 `exportDataJson` 的 `data` 导出、可跨设备还原）：全部账目数据（账本/交易/账户/分组/分类/标签/附件/周期规则/月度·分类·按日预算）+ 个人资料 + 活动账本 + 主题、触感、资产封面、资产视图模式/折叠/排序、首页面板、看板面板。

**设备本地、不进备份**（换机需重设）：
- **机密凭证**（进明文备份是安全倒退，坚决不备）：应用锁哈希 `app_lock`、备份加密口令 `backup_passphrase`、WebDAV 账号密码 `webdav`、AI `apiKey`（含在 `ai`）。
- **设备专属**：备份目录路径 `backup_settings`、隐私同意 `privacy_consent`、新手引导 `onboarding`、软件日志 `logs`。
- **用户已明确选择维持本地、暂不加入备份**：语言 `locale`、金额小数位 `amount_format`、默认付款账户 `default_account`、FAB 行为 `fab_action`、记账提醒 `reminder`、AI 的 baseUrl/model（`ai`）、首页概览卡配置 `home_metrics`（各槽指标/曲线/标题，设备本地显示偏好、初始化保留）。

