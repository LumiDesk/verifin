# Veri Fin 开发路线图

长期功能演进的执行清单。规则：

- 按阶段推进，每完成一项独立功能提交一次并勾选对应条目。
- 顺序按依赖关系排列，安全合规类可与存储迁移穿插进行。
- 关键技术决策记录在文末「技术决策」，变更需同步更新。
- 每项功能自带测试；影响文档的同步更新 `README.md`、`AGENTS.md`、`docs/`。
- 新增用户可见文案一律进 ARB（见 0.2），存量文案随功能改动逐步迁移。

## 阶段 0：工程地基

- [x] 0.1 制定路线图（本文件）
- [x] 0.2 国际化框架：flutter gen-l10n + ARB（zh 模板 + en），已接管底部导航/快速记账/退出提示文案；新增文案一律进 ARB，存量逐步迁移；语言暂固定中文，语言切换设置留待后续
- [x] 0.3 SQLite 存储迁移（分步，期间保持功能可用）：
  - [x] 0.3.1 引入 sqflite 系依赖，搭建 `lib/data/` 数据库层（schema、迁移器、平台工厂：Android/iOS 原生、测试 ffi、Web wasm）
  - [x] 0.3.2 交易迁移：首启动从 KV 导入历史数据，读写切换到 SQLite
  - [x] 0.3.3 账户 / 账户分组 / 账本迁移
  - [x] 0.3.4 分类 / 月度预算 / 分类预算迁移
  - [x] 0.3.5 备份导入导出适配新引擎（对外格式仍为 JSON），清理 KV 中已迁移数据；偏好类小数据（主题、触感、面板配置等）保留在 KV

## 阶段 1：安全与合规

- [x] 1.1 隐私政策与用户协议：政策文案（`lib/app/legal_content.dart`）、首次启动同意弹窗（不同意则 `SystemNavigator.pop()` 退出应用，同意后持久化 `verifin.privacy_consent.v1`，初始化数据不清除同意标记）、设置页可再次查看《隐私政策》《用户协议》
- [ ] 1.2 应用锁（分步）：
  - [x] 1.2.1 数字 PIN 密码（设置、验证、修改、关闭；启动与回前台时校验）：6 位 PIN，加盐 SHA-256（`crypto`）存 `verifin.app_lock.v1`，绝不存明文；`AppLockGate` 放在 `MaterialApp.builder` 覆盖根 Navigator，冷启动与回前台（`paused/hidden`→`resumed`）锁定；设置页「应用锁」入口开关/修改；初始化数据不清除锁配置，忘记密码只能初始化后重设
  - [x] 1.2.2 图案密码：3×3 连线图案（`PatternInputView` 自绘 + 手势），点序列（如 `0-1-2-4-8`）复用同一加盐哈希与 `AppLockConfig`（`kind=pattern`）；设置页开启/修改时可在数字密码与图案间选择，锁屏、设置、验证页按 `kind` 复用 `buildAppLockInput`
  - [x] 1.2.3 生物解锁（系统生物识别，`local_auth`，作为 PIN/图案之上的快捷解锁）：`lib/app/biometric_auth*.dart` 条件导入（web=stub、io=local_auth，非移动平台一律不可用）；只调用系统能力、不保存任何生物特征数据，系统生物信息变化后需重新验证；开关在应用锁设置页（仅设备可用时显示），锁屏出现即自动发起一次验证并提供手动按钮；Android 端 `FlutterFragmentActivity` + `USE_BIOMETRIC` + `minSdk≥23`。注：`local_auth` 在 Android 无法严格排除人脸，故用户文案统一为「生物解锁」（`biometricOnly:true`，实际以设备指纹/人脸为准）

## 阶段 2：数据管理中心

- [x] 2.1 数据管理页：我的页新增「数据管理」入口（`DataManagementPage`），迁移现有「导出 / 导入 / 初始化数据」到该页；设置页仅保留主题/触感/应用锁/检查更新/法律文档
- [x] 2.2 手动备份：选择备份目录（Android SAF / 桌面目录，`lib/app/backup/backup_storage_*.dart`），「立即备份」写入该目录（`verifin-backup-<时间>.json`，与自动备份 `verifin-auto-` 前缀区分），展示上次备份时间，可清除目录
- [x] 2.3 自动备份：频率可选（每次打开应用 / 每次记账后 / 每 N 小时），保留最近 N 份（超出自动清理），`BackupCoordinator` 在打开/回前台/记账后触发，失败静默
- [x] 2.4 备份加密：可选 AES-GCM+PBKDF2 密钥（`backup_crypto.dart`），导出/备份加密、导入自动解密（已存密钥先试、失败手动输入），可清除重设
- [x] 2.5 CSV 导入：模板下载 + CSV 解析（`transaction_import.dart`），名称自动建账户/分类，逐行错误反馈；Excel 经「另存为 CSV」导入
- [x] 2.6 从其他记账软件导入：表头别名 + 来源识别（钱迹/随手记），复用 CSV 导入流程，结果提示识别来源
- [x] 2.7 WebDAV 备份：配置地址/账号（可测试连接，`webdav_client_*.dart`），手动上传 + 从列表恢复 + 自动上传（随自动备份触发，遵循加密设置）；Web 因跨域不支持

## 阶段 3：记账核心增强（依赖 0.3）

- [x] 3.1 多级分类：分类支持任意层级树形结构（`Category.parentId`，DB v2 迁移加 `parent_id` 列），树形纯函数在 `lib/app/category_tree.dart`；分类管理页树形展示（展开/收起、新增子分类、移动到、同级重排），记账分类选择弹窗按层级缩进+可展开；统计按层级聚合（看板分类环形/明细归总到顶级分类，分类预算含子分类支出）；删除父分类前须先处理子分类，删除分类同时清理其分类预算
- [x] 3.2 标签系统：`Tag` 模型 + 交易 `tagIds`（多对多，SQLite `entries.tag_ids` 存 JSON 数组，DB v3 迁移新增 `tags` 表；标签全局不分账本），删除标签会清理所有交易的引用
  - [x] 3.2.1 标签管理与记账时多选标签：我的页「标签管理」入口（增删改+拖动排序），记账表单标签行打开多选弹窗（`TagSelectorSheet`，FilterChip 多选 + 即时新建标签）
  - [x] 3.2.2 交易列表按标签筛选：标签筛选胶囊（有标签时才显示），与账户/分类/搜索/时间组合；关键词搜索也命中标签名
  - [x] 3.2.3 看板标签统计：新增 `tag_stats` 面板（`reportPanelSpecs`），按标签汇总本月支出金额与占比（多标签交易分别计入各标签，占比以本月总支出为分母）
- [x] 3.3 图片附件：记账时拍照或从相册选择（`attachment_picker_*` 条件导入 image_picker，压缩为 JPEG data URL），交易新增/详情页均可加图、缩略图查看、全屏浏览、删除；存于独立 `attachments` 表（DB v4，按 `entry_id` 关联，落在应用私有 SQLite），删除交易/账户/账本级联清理附件；随 JSON 备份导出导入。Android 相机/相册已真机验证（2026-07）
- [x] 3.4 转账手续费：`LedgerEntry.fee`（DB v5 加 `fee` 列），转账记账时可填手续费；由转出账户承担——转出余额扣除「金额+手续费」、转入只加金额（`accountDeltaForEntry`）；转账本就不计收支统计，手续费仅体现在余额/净资产
- [x] 3.5 报销 / 退款：支出可「标记待报销」（`reimbursable`，交易行显示徽标、交易列表可按待报销筛选）；退款/报销回款以 `refundedAmount` 冲抵原交易——回到原账户、按「金额−已冲抵」的净额计入余额与所有统计（收支/分类/标签/预算/趋势，集中在 `LedgerEntry.netAmount` 与 `ledger_math`）；DB v6 加 `reimbursable`/`refunded_amount` 列。回款不产生独立收入条目，故天然「不计收支」为收入
- [x] 3.6 周期记账：`RecurringRule`（每天/周/月/年，DB v7 新增 `recurring_rules` 表），我的页「周期记账」入口可增删改、启停；打开应用与回前台时 `applyDueRecurring` 按频率补齐从 `nextRunDate` 到今天的交易并推进（月/年推进遇短月收敛到月末，带循环保护）；规则随账本删除级联清理，随 JSON 备份导入导出
- [x] 3.7 信用卡账期：`Account.statementDay`/`dueDay`（可选，每月 1–28，DB v8 加两列），仅信用卡账户在账户详情页可设置/清除（花呗类用户可不设置）；设了还款日后账户详情顶部展示还款提醒条（下一个还款日+剩余天数，≤3 天标红），推日逻辑纯函数 `lib/app/credit_card.dart`；随备份导入导出
- [x] 3.8 批量操作：交易列表进入多选（右上角「多选」或长按行），行首勾选圈+命中高亮，底部操作栏提供全选/改分类/改账户/删除；批量删除级联清理附件，批量改分类只改与目标分类同类型的交易（跳过并提示改动数），批量改账户设置转出账户（`deleteEntries`/`setEntriesCategory`/`setEntriesAccount`）

## 阶段 4：报表与体验

- [x] 4.1 报表增强：看板右上角「统计分析」入口进入 `ReportAnalysisPage`；时间范围可选本月 / 本年 / 自定义（`showDateRangePicker`），维度可选支出 / 收入；展示收支概览、趋势曲线（短范围按天、整年/跨多月按月，`ReportTrend`）、分类排行（按顶级分类聚合净额）；纯函数在 `lib/app/report_analysis.dart`（`ReportRange`/`reportSummary`/`reportCategoryStats`/`reportTrend`）
- [x] 4.2 同比 / 环比分析：统计分析页在「本月」范围下展示「同比 · 环比」卡，收入 / 支出 / 结余分别对上月（环比）与去年同月（同比）算变化率；纯函数 `reportMonthlyComparison`/`changeRatio`/`formatChangeRatio`（`report_analysis.dart`），基准为 0 时显示「—」，颜色按「上升是否为好」区分（收入/结余升为绿、支出升为红）
- [x] 4.3 记账提醒：设置页「记账提醒」入口（`ReminderSettingsPage`）开关每日提醒并选提醒时刻；本地通知走 `flutter_local_notifications` + `timezone`（`lib/app/reminder/notification_scheduler_*.dart` 条件导入，io=真实、web/测试=stub），每日在设定时刻发一条通知（inexact 调度免精确闹钟权限，`matchDateTimeComponents: time` 每日重复）；配置存 KV（`verifin.reminder.v1`，`ReminderSettings`，设备本地不进 JSON 备份），`main.dart` 开屏与配置变化时 `apply` 重排；Android 加 `POST_NOTIFICATIONS`/`RECEIVE_BOOT_COMPLETED` 权限、插件接收器与 core library desugaring。已真机验证（2026-07）
- [x] 4.4 我的页改版：功能入口由竖排列表改为宫格（`_FeatureGridCard`/`_FeatureTile`，4 列图标磁贴），分「记账管理」（账本/分类管理/标签管理/周期记账）与「数据与工具」（统计分析/记账提醒/数据管理）两组，磁贴带状态副标题；头部齿轮仍进设置，新增「统计分析」「记账提醒」入口
- [x] 4.5 新用户引导：首启动（同意隐私政策后）弹出 `OnboardingPage`（4 步 PageView：欢迎 / 建首个账户 / 设本月预算 / 完成），账户与预算均可选可跳过，完成或跳过写入 `verifin.onboarding.v1`（只出现一次，初始化数据不清除）；`shell.dart` 在同意后 `_maybeShowOnboarding` 触发，测试脚手架默认预置该标记跳过。**后续新增重要功能需回顾 `_DoneStep` 引导文案是否同步**
- [x] 4.6 Android 桌面小组件：`QuickEntryWidgetProvider`（`AppWidgetProvider`）展示「今日支出」并提供「记一笔」按钮（复用 `MainActivity.ACTION_QUICK_ENTRY` 快速记账，点主体打开应用）；数据由 Flutter 侧 `pushTodayExpenseToWidget`（`home_widget_service.dart`，纯函数 `dayExpenseTotal`）经 MethodChannel `updateTodayExpenseWidget` 写入原生 SharedPreferences 并刷新，在开屏/回前台/记账后触发；品牌蓝渐变背景（`res/layout/quick_entry_widget.xml` + drawable + `xml/quick_entry_widget_info.xml` + Manifest receiver）。真机添加与刷新已验证（2026-07）

## 阶段 5：维护与清理（1.3 后）

按顺序推进，每项一个独立提交，完成一项勾一项。

- [x] 5.1 **移除 Web 端，只保留 Android**（一个提交）
  - 删 `web/` 整个目录（含浏览器版 SQLite 的 `sqlite3.wasm`、`sqflite_sw.js`，Android 打包不用）
  - 删 6 个 `_web.dart`：`local_storage_web` / `data/database_factory_web` / `avatar_picker_web` / `data_file_port_web` / `backup/backup_storage_web` / `backup/webdav_client_web`
  - 改 7 个条件导出入口，各删 `if (dart.library.html) ...` 一行：`local_storage.dart` / `data/database_factory.dart` / `avatar_picker.dart` / `data_file_port.dart` / `backup/backup_storage.dart` / `backup/webdav_client.dart` / `attachment_picker.dart`；`_stub.dart` 保留不动
  - 依赖清单只删一行 `sqflite_common_ffi_web`（**勿动** `sqflite_common_ffi` 测试用、`sqflite_common` Android 用）
  - 改 CI `.github/workflows/flutter.yml`：删「构建 Web」「上传 Web 产物」两步、job 名去掉「Web Build」（`android` 的 `needs: checks` 保留）
  - `flutter analyze` + `flutter test` 全绿
  - 同步文档：README / AGENTS / CLAUDE / docs 里所有 `flutter run -d chrome`、`flutter build web`、「Web 端不支持 WebDAV/通知」「三端适配」等措辞改为只讲 Android；本地预览改真机/发版
- [x] 5.2 **确认 5.1 Web 清理干净**：全仓搜 `dart.library.html` / `_web.dart` / `sqflite_common_ffi_web` / `build web` 无残留（含源码注释）
- [x] 5.3 **资产页【排序】按钮消失排查与改善**：确认原因是「分区 <2 时按钮按设计隐藏」（非 bug）；已把「排序分组」入口移入常驻的「资产操作」菜单，<2 分区点按提示原因，≥2 进入排序模式，避免按钮无声消失；附测试
- [x] 5.4 **功能回归系统审查**：完成，报告见 `docs/dev/regression-audit.md`。六区域并行核查约 85 条断言，**未发现明确回归**。记录的 3 处灰色地带：①交易分类筛选下钻子分类 → **已做**（含缩进选择弹窗+测试）；②导入非本应用 JSON 静默覆盖 → **已做**（导入前校验+测试）；③首页剩余额度超支夹 0 显示 → 待定（是否改为显示负数与预算页统一）
- [x] 5.5 **附件备份改压缩包格式**：
  - 核心：`backup_archive.dart` 纯函数（附件字节从 JSON 剥离、与 `backup.json` 打进 zip，解包拼回 `dataUrl`）；含往返/体积/兼容测试。
  - 管线：手动/自动备份、导出、WebDAV 上传的未加密路径默认产出 zip；加密备份沿用文本信封 `.json`。导入/本地恢复/WebDAV 恢复按字节读入、zip 魔数识别，完全兼容旧版纯 JSON/加密备份。`BackupService.prepare` 集中格式决策，`profile_pages` 共用 `_importBackupBytes`。
  - 原生：Android 新增 `writeBackupBytes`/`readBackupBytes`/`saveBytesToDownloads`（MethodChannel 传字节），备份列表纳入 `.zip`。桌面 dart:io 路径有端到端测试（写 zip→读回→导入，附件还原）；Android 原生 SAF/下载读写与恢复已真机验证（2026-07）。
- [x] 5.6 **深层结构审查**：评估完成，报告见 `docs/dev/structure-review.md`。结论：结构总体健康、目录划分清晰、无结构性隐患；重构候选（part 拆 controller、抽通用确认弹窗、拆 profile_pages）均属风格/大改动面，按「只改明确的」原则**留待你决定**后再逐项做

> 已放弃项：数据库迁移「压平成基线」——迁移不影响性能（全新装不跑迁移、老设备每步只跑一次），不做。

## 阶段 6：多语言（进行中）

存量硬编码中文全部迁入 ARB（zh + en），并提供应用内语言切换。分模块推进，每模块一个提交。

- [x] 6.1 语言切换基础设施：`LocalePreference`（跟随系统 / 简体中文 / English）存 KV（`verifin.locale.v1`，设备本地、不进备份、初始化保留），设置页「语言」入口即时切换，`main.dart` 经 `localePreferenceListenable` 驱动 `MaterialApp.locale`（null=跟随系统，回落中文）；测试脚手架预置中文保住存量中文断言，语言切换本身有独立测试
- [ ] 6.2 壳层与通用组件（shell / common_widgets / sheets）
- [ ] 6.3 模型显示名与控制器消息（models / veri_fin_controller / demo_data / account_icon_assets）
- [ ] 6.4 首页与记账表单（home_page / entry_sheets）
- [ ] 6.5 资产页（assets_pages）
- [ ] 6.6 交易列表与详情（transactions_pages / entry_detail_page / attachments_editor）
- [ ] 6.7 预算页（budget_pages）
- [ ] 6.8 看板与统计分析（reports_page / report_analysis* / chart_painters / series_math / panel_settings_page）
- [ ] 6.9 我的页与设置（profile_pages / legal_pages / recurring_page / reminder_settings_page / onboarding_page）
- [ ] 6.10 应用锁与隐私同意（app_lock_page / app_lock_gate / privacy_consent_gate / biometric）
- [ ] 6.11 备份子系统用户可见消息（backup/* / data_file_port / transaction_import）
- [ ] 6.12 全量核查无残留硬编码中文，analyze + test 全绿，真机验证清单见 `docs/dev/i18n-verification.md`

## Backlog（暂不排期）

- 借贷管理（借入/借出、应收应付、分期）
- 语音记账 / 小票 OCR
- 自动记账（读取支付/短信通知，合规风险高）
- iOS 构建与发布（暂无开发者账号）

## 技术决策

| 决策 | 选择 | 原因 |
|------|------|------|
| SQLite 方案 | `sqflite` + `sqflite_common_ffi`（测试）+ `sqflite_common_ffi_web`（Web） | 单一 API 覆盖三端，无需 build_runner 代码生成，符合仓库「不引入额外工具链」约定；drift 需常驻 codegen |
| i18n 方案 | Flutter 内置 gen-l10n（ARB，zh 为模板语言） | 官方方案零额外依赖；`generate: true` 由 pub get 自动生成 |
| 备份格式 | 未加密备份为 **zip**（`backup.json` + `attachments/<id>` 图片文件），加密备份沿用文本信封 `.json`；导入按 zip 魔数自动识别，旧版纯 JSON/加密备份仍可导入 | 附件以 base64 内嵌 JSON 会让备份随附件急剧膨胀（放大 33% 且每次整份重写），zip 把图片剥离外置；加密走文本信封复用既有加密逻辑、降低二进制加密复杂度；魔数识别保证老备份永远可导入 |
| 偏好类数据 | 保留 KV（SharedPreferences），不迁 SQLite | 小而简单，迁移无收益 |
| SQLite 切换方式 | 开发期直接切换，不做 KV→SQLite 迁移、不留 KV 回退双路径；`LedgerRepository` 抽为接口，`SqliteLedgerRepository` 为生产实现，全新库首启动播种默认数据 | 应用尚无用户，允许不兼容旧数据结构；一次切干净，避免长期维护双路径隐患（大数据量下迁移也更可靠） |
| 测试仓储 | widget/控制器逻辑测试注入 `InMemoryLedgerRepository`（同步、无真实 I/O），数据层真实 SQLite 用 ffi 单独覆盖 | sqflite 的后台 isolate 与 `testWidgets` 的 fake-async 会死锁；内存实现规避且更快 |
| 备份目录 | Android 走 SAF（`ACTION_OPEN_DOCUMENT_TREE` + 持久化 URI 权限 + `DocumentFile`），桌面走 `file_selector` 目录 + `dart:io`，Web 无持久目录仍走下载 | 分区存储下唯一可长期读写用户可见目录的方式；条件导入 `lib/app/backup/backup_storage_*.dart` |
| 备份加密 | `cryptography`（纯 Dart AES-GCM + PBKDF2-SHA256），口令明文存本机 KV | 加密属非简单需求需成熟库；纯 Dart 全平台无原生依赖；口令保护离开设备的备份文件，本机数据本在应用私有区 |
| CSV 导入范围 | 只做 CSV 解析（自研 RFC-4180 解析器），Excel 经「另存为 CSV」；不引入 `excel`/xlsx 依赖 | CSV 覆盖所有表格工具，避免重量级 xlsx 解析依赖；纯函数便于测试 |
| WebDAV 客户端 | `dart:io HttpClient` 手写 PUT/GET/PROPFIND/MKCOL + Basic Auth，PROPFIND XML 用正则按局部名解析；Web stub | 不引入 WebDAV/HTTP 第三方依赖；命名空间前缀不固定用局部名匹配；Web 端浏览器跨域限制无法直连 WebDAV |
| 多级分类结构 | 邻接表：`Category.parentId`（可空，顶级为 null），非物化路径/嵌套集；同级顺序沿用列表位置（`sort_order`）；子分类类型强制继承父分类 | 记账分类量级小、层级浅，邻接表最简单；改动只加一列一次迁移；树运算集中在 `category_tree.dart` 纯函数（带环检测），便于测试 |
| 分类层级聚合口径 | 看板分类统计（环形/明细）把每笔交易归总到其**顶级祖先**分类；分类预算的「已花」把子分类支出上滚到各级父分类 | 顶级归总符合用户对「大类占比」的预期；预算上滚让父分类预算能约束整棵子树，子分类仍可单独设预算 |
| 标签存储 | 交易与标签多对多，用交易表 `tag_ids` 单列存 JSON 数组，不建关联表；标签全局共享不分账本 | 与现有「整表覆盖式读写」一致，避免引入关联表与联表查询；标签量小、跨账本复用更自然 |
| 图片附件存储 | 压缩 JPEG（最长边 1600、q80）存 data URL，放**独立 `attachments` 表**（非 entries 表）；备份时由 `backup_archive` 把附件字节剥离进 zip 的 `attachments/<id>` | 放 entries 表会让「整表覆盖式」写入把所有图片 base64 反复重写（放大严重）；独立表只在增删图片时重写。data URL 落在应用私有 SQLite 内，移动端已有内存图片渲染能力，无需额外文件生命周期管理；备份用 zip 外置附件避免 base64 膨胀 |
| 报销/退款模型 | 退款/报销回款统一记为原支出的 `refundedAmount`（回到原账户、冲抵原交易），不新建收入条目；「待报销」只是标记 | 单字段冲抵最简单，天然满足「回款不计收入」；退款回原账户是最常见场景。代价：跨账户报销（回款到另一账户）暂用近似（记在原账户），后续如需精确可再引入关联结算条目 |
| 周期记账补记时机 | 打开应用与回前台时 `applyDueRecurring(now)` 一次性补齐所有到期交易，不用后台定时任务/通知 | 本地优先、无服务端；应用不常驻，开屏补记足够且省电；补记逻辑纯函数（`dueDatesFor`/`advanceRecurring`）便于测试；`nextRunDate` 幂等推进保证不重复补记 |
| 记账提醒通知 | `flutter_local_notifications`+`timezone`+`flutter_timezone`；inexact 调度（`inexactAllowWhileIdle`）+`matchDateTimeComponents: time` 每日重复 | 本地通知属平台能力非简单需求，需成熟库；inexact 免 `SCHEDULE_EXACT_ALARM` 特殊权限，提醒场景对精确到分钟无强需求；`timezone` 保证 zonedSchedule 按本地时区触发。配置为设备本地偏好，存 KV、不进 JSON 备份 |
| 桌面小组件 | 原生 `AppWidgetProvider` + `RemoteViews`，数据经现有 `verifin/app` MethodChannel 写入原生 SharedPreferences，不引入 `home_widget` 依赖 | 点击快速记账可直接复用已有 `ACTION_QUICK_ENTRY` intent 与 `QuickEntryTileService` 同款机制；数据只是一个「今日支出」字符串，MethodChannel + SharedPreferences 足够，避免为单一小组件引入第三方桥接依赖 |
