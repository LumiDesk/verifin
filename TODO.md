# Veri Fin 开发路线图

长期功能演进的执行清单。规则：

- 按阶段推进，每完成一项独立功能提交一次并勾选对应条目；阶段整体完成后压缩为摘要，明细见 git 历史。
- 关键技术决策记录在文末「技术决策」，变更需同步更新。
- 每项功能自带测试；影响文档的同步更新 `README.md`、`AGENTS.md`、`docs/`。
- 新增用户可见文案一律进 ARB（zh + en 同步），绝不硬编码中文。

## 已完成阶段（摘要）

- **阶段 0 工程地基**：路线图、i18n 框架（gen-l10n + ARB）、SQLite 存储迁移（账目类只认库，偏好类留 KV）。
- **阶段 1 安全与合规**：隐私政策/用户协议与首启动同意；应用锁（6 位 PIN、3×3 图案、生物解锁，加盐哈希仅存本机）。
- **阶段 2 数据管理中心**：数据管理页、手动/自动备份（本地目录 SAF）、AES-GCM 备份加密、CSV 导入（含钱迹/随手记识别）、WebDAV 备份。
- **阶段 3 记账核心增强**：多级分类、标签系统（管理/筛选/看板统计）、图片附件、转账手续费、报销/退款冲抵（`netAmount`）、周期记账、信用卡账期、批量操作。
- **阶段 4 报表与体验**：统计分析页（范围/维度/趋势/分类排行）、同比·环比、记账提醒本地通知、我的页宫格改版、新用户引导、Android 桌面小组件「今日支出」。
- **阶段 5 维护与清理**：移除 Web 端只留 Android、资产排序入口改善、功能回归审查（约 85 条断言无明确回归）、附件备份改 zip 格式、结构健康评估（结构健康，重构候选见 Backlog）。
- **阶段 6 多语言（2026-07）**：应用内语言切换（跟随系统/简体中文/English，`verifin.locale.v1` 设备本地）；存量文案全部迁 ARB（zh/en 各 716 键对齐）；枚举显示名改 `label(AppLocalizations)`；无 BuildContext 场景（小组件/通知/生物弹窗）经 `l10nForPreference` 解析；种子数据按首启动语言播种。有意保留中文：法律文档正文、银行/品牌图标名、CSV 模板表头与逐行导入错误、无 context 的错误消息（见 Backlog）。真机验证清单：`docs/dev/i18n-verification.md`。

> 已放弃项：数据库迁移「压平成基线」——迁移不影响性能（全新装不跑迁移、老设备每步只跑一次），不做。

## 阶段 7 降低记账割裂感（用户反馈驱动，规划中）

来源：一批真实用户反馈，核心痛点是「坚持不了每次点进去手工记账，很割裂」。诉求高度集中在「自动/半自动记账」。按「价值/成本比」排序，并附每项的决策与约束。

- [x] **7.1 全面屏手势冲突（Bug，先做）**：全面屏手势下退出动画与系统返回手势冲突。先排查复现条件（机型/手势导航模式/涉及的页面转场），再定方案。
- [x] **7.2 支付平台账单导入**：平台优先导入（先选来源再选文件），已支持**支付宝**（GBK CSV，跳过「不计收支」）、**微信**（xlsx，Excel 序列号日期，跳过「中性交易」）、**薄荷记账**（UTF-16 制表符 CSV，支出为负、单边转账），以及通用 CSV（钱迹/随手记/模板）。各平台解析全部基于用户提供的真实导出样例，实测导入笔数与账单汇总一致（支付宝 130、微信 177、薄荷 903，0 报错）。新增 [payment_import.dart](lib/app/backup/payment_import.dart)（编码解码 + 最小 xlsx 读取 + 各平台归一到 Veri Fin 规范列后复用 `buildImportPlan`），入口在数据管理页「导入账单文件」并附各平台「如何导出账单」引导。一羽记账 `.penny` 为加密二进制（熵≈8.0）无法解析，已放弃。**衍生功能：无账户记账**——支持只记一笔金额、不选账户（不计入任何账户余额但计入收支统计），让薄荷等含「不计资产」记录的账单可干净导入，同时手动记账也可选「无账户」。
- [x] **7.3 按日自定义预算**：在月度/分类预算之外新增「按日」预算维度——账本级的每日花销上限（键为 `bookId`，`daily_budgets` 表，schemaVersion 8→9），预算页展示今日已花/剩余进度条，随备份导出导入、删账本/初始化级联清理。当日已花复用 `dayExpenseTotal`。
- [x] **7.4 AI 对话记账**：自然语言 → 结构化交易草稿并自动分类（OpenAI 兼容协议，自带 Key、本地优先）。
  - **设置**：新增 `FabActionMode {manual, ai}` 偏好（`verifin.fab_action.v1`，默认手动），设置页可切换首页「记一笔」按钮行为；其下「AI 记账设置」子页（`AiSettingsPage`）配置请求地址/API Key/模型（`AiSettings`，存 `verifin.ai.v1`，明文本机、不进备份、初始化保留）并测试连通性。
  - **AI 模块** `lib/app/ai/`：`ai_settings.dart` 值类；`ai_client.dart`（facade/io/stub 条件导入，`dart:io HttpClient` POST `{baseUrl}/chat/completions` + `Authorization: Bearer`，带超时，与 WebDAV 同款约定）；`ai_entry_parser.dart` 纯函数——把当前账本分类（按类型）、账户、今天日期喂给模型，要求严格 JSON，解析后**校验所有 id**（未命中降级 + 提示码），产出 `AiEntryDraft`。
  - **确认落账**：FAB 为 AI 模式时弹自然语言输入框（`ai_entry_sheet.dart`，附隐私提示），解析成草稿后 push 到 `EntryDetailPage`（新增 `initialDraft` 预填 + 复核提示条）由用户确认/修改再保存，AI 不直接落账。类型/金额/分类/账户/备注/日期均可被识别。未配置时引导去设置。
  - 已处理：解析容错（代码块/多余文字提取 JSON、金额为字符串/负数、相对日期）、落账前确认、隐私提示、i18n（zh+en）；Android 开启 `usesCleartextTraffic` 支持本地/自建 `http://` 端点（局域网 Ollama / LM Studio 等）。**语音输入有意不做**：主流输入法自带听写（语音转文字），用户可直接对着 AI 输入框说话，无需引入麦克风权限与 STT 依赖。
- [ ] **7.5 自动记账（呼声最高）**：**方案已定，待真实样例开工**，完整方案见 [docs/dev/7.5-auto-capture-assessment.md](docs/dev/7.5-auto-capture-assessment.md)。要点：① 本应用不上架 Google Play（只经 GitHub Releases 分发），Play 政策审核风险不成立，剩余约束是用户信任 / 版面文案脆弱性 / 微信支付宝 ToS；② **双通道纯 opt-in**——入口「我的/设置 → 自动记账」独立页，**默认全关**，页内选监听方式；调研结论：半自动是行业共识（没人自动落账）、NLS 与无障碍分工互补（支付宝/银行通知带金额靠 NLS，微信通知不带金额需无障碍读支付成功页）、最大工程坑是国产 ROM 保活（需前台服务+常驻通知+电池白名单/自启动引导）、连钱迹都长期拒做（「监控屏幕太激进」）；③ 红线：一律产 `AiEntryDraft` 交 `EntryDetailPage(initialDraft:)` 确认、**绝不自动落账**，无障碍只读不操作、`packageNames` 严格限定；④ **解析改用 AI（必需），不写按银行/App 正则**——原生只捕获原始文本入队，开屏 drain 时批量喂 AI（复用 7.4，加 `isTransaction` 过滤噪音）；自动记账开关以「已配 AI」为硬门槛，主推本地 Ollama/LM Studio（文本不出设备），云端 Key 按量计费需告知，AI 失败存「待解析」草稿兜底；⑤ **砍掉截屏方案**（有这两条不需要）。开工前置：收集支付宝/银行真实通知与微信支付成功页节点文本样例，用于打磨 AI 提示词与测试（禁编造格式）。短期仍用 7.2 导入 + 7.4 AI 组合覆盖大部分「自动」体验。
  - **7.5a** NLS 通知监听（`NotificationListenerService` + 包名白名单 + AI 批量解析 + `pending_captures` 表 + 复用 `initialDraft` 确认），成本低、不用吓人权限，先做
  - **7.5b** 无障碍补微信（`AccessibilityService` 读支付成功页 + 前台服务常驻通知保活 + 各 ROM 保活引导），opt-in、后做
- [ ] **7.6 Obsidian / Markdown 联动（最不着急）**：把数据导出为 Markdown / 写入 vault，在 Obsidian 内查看记录。契合「数据自主」，但受众偏小众，优先级最低。

> 规划思路：7.1/7.2/7.3 是「快赢」（成本低、合规、命中高频痛点），优先推进；7.4 是差异化亮点；7.5 是最高呼声但需谨慎评估；7.6 长期特色。整体方向仍需继续打磨——「怎么把这个软件做得更好」是后续持续思考的主题。

## Backlog（暂不排期）

- 错误消息本地化收尾：WebDAV 连接/恢复失败、平台桥接（检查更新下载、SAF 读写）与备份加解密的异常消息目前为中文（无 BuildContext 场景），如需彻底英文化可改为错误码 + UI 侧 l10n 映射
- 结构重构候选（5.6 评估结论：结构健康，非必须）：part 拆分 `veri_fin_controller`、抽通用确认弹窗、拆分 `profile_pages`
- 截屏记账磁贴 / MediaProjection OCR（7.5 已改双通道 NLS + 无障碍方案，截屏方案不做——有这两条即可覆盖，见 [docs/dev/7.5-auto-capture-assessment.md](docs/dev/7.5-auto-capture-assessment.md)）
- 借贷管理（借入/借出、应收应付、分期）
- 小票 OCR（语音/自然语言记账已归入阶段 7.4 AI 对话记账）
- iOS 构建与发布（暂无开发者账号）

> 注：原「语音记账」「自动记账（读取支付/短信通知）」两条已升级为阶段 7.4 / 7.5 正式规划项。

## 技术决策

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
