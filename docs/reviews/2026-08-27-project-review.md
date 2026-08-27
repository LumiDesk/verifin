# Veri Fin 项目综合审查记录

> 审查日期：2026-08-27<br>
> 基线提交：`1f1e105`<br>
> 审查分支：`talyra42/code-review-audit-20260827`<br>
> 审查方式：只记录问题，不修改产品实现

## 1. 结论摘要

Veri Fin 的工程基线明显高于一般同体量 Flutter 应用：核心账务口径有专门设计文档，SQLite 迁移、Repository 契约、多币种、退款、备份、导入和主要用户旅程都有测试，生产代码也有清晰的本地优先与只读 AI 边界。本轮 `flutter analyze` 无问题，根项目 881 项测试全部通过。

但审查确认了两项必须优先处理的安全问题，以及若干可能导致数据失真的并发/多币种问题：

1. 发布私钥和对应凭据进入版本库，任何能取得仓库内容的人都可能用正式身份签包。
2. Android Manifest 未关闭或约束系统 Auto Backup，默认可能把 SQLite、SharedPreferences 及其中的账目和机密配置上传到系统云备份，和产品“只有用户主动启用才对外传输”的承诺冲突。
3. SQLite 增量写的行快照没有串行化；快速连续新增、修改、删除时存在落库状态回退或残留的竞态。
4. 交易列表“批量改账户”没有处理多币种金额，切换到不同币种账户时可能直接改变余额含义。
5. 多表删除和部分偏好写入仍是“先改内存、异步写盘”，失败时不能保证原子性或可靠回滚。

严重度统计：

| 等级 | 数量 | 含义 |
| --- | ---: | --- |
| Critical | 2 | 发布身份或隐私承诺可能已失守，应立即确认现状 |
| High | 7 | 可能造成数据错误、备份失效、拒绝服务或供应链风险 |
| Medium | 18 | 可靠性、安全加固、架构可维护性和无障碍问题 |
| Low / 已知风险 | 7 | 影响较窄、已有产品取舍或主要是文档/维护问题 |

### 用户批注后的跟进状态

- CR-01 发布签名材料：用户明确接受现状，本分支不处理、不轮换。
- CR-02 Android Auto Backup：已通过 Manifest 显式禁用，并增加策略测试。
- H-01 SQLite 增量快照竞态：已独立复现并修复；Repository 全部写入口串行化完整差分临界区，新增并发覆盖和失败后继续执行测试。
- H-02 多表破坏性命令：交易/退款/账户/分类/标签/分组删除与分类合并已改为事务成功后才提交 Controller 内存；账户删除还会级联跨账户退款、附件并停用周期规则。
- H-03 多币种批量改账户：已限制为同来源账户币种且存在实际 `accountAmount` 的安全搬移；跨币种、无账户和转入冲突整批拒绝。
- H-04 KV 写入失败：普通异步写会在 `flush` 汇总上报；应用锁和隐私同意改为持久化成功后才更新内存。
- H-05 外部分享图片：已改为分块读取并在累计超过 25 MB 时立即停止。

## 2. 审查范围与证据边界

已审查：

- `lib/main.dart`、Controller 三个 part、SQLite/Repository、模型和主要纯函数。
- 首页、资产、看板、我的、交易、账户、预算、周期、退款、导入、备份、AI、设置及应用锁页面源码。
- Android Manifest、Gradle、MethodChannel、分享入口、更新下载、通知、小组件和 SAF 实现。
- GitHub Actions、发布脚本、依赖状态、组件规范、技术决策、已知限制和验收清单。
- 根项目全部测试和 UI Lab 自身的 analyze/test/build。UI Lab 的结果只说明实验工程可构建，不作为正式产品 UI 证据。

未完成：

- 当前机器没有 Android SDK、模拟器或真机，无法运行正式应用，也无法进行 Android release/R8、通知、OCR、文件、安装更新和系统备份的真机验证。
- 因此本报告的 UI 部分是生产源码、主题、共享组件和正式 widget 测试的一致性审查，不是实际 Android 页面视觉验收。
- 未对用户数据、线上 WebDAV 或真实 AI 端点进行访问或传输。

## 3. 已确认的优点

### 3.1 数据与领域设计

- 核心账目只认 SQLite，KV 与账目数据职责分开，没有隐式 KV 回退。
- 多币种采用原币、账户实扣/实入、本位币冻结三层金额；历史交易不会随汇率更新重算。
- 退款是关联条目，交易本体、退款和附件支持聚合原子保存。
- 导入预览零落库，确认后才写入；恢复和整库替换走多表事务。
- 分类有唯一索引、创建查重和载入自愈三道防线。
- Repository 有内存与 SQLite 共用的契约测试，数据库有迁移矩阵和四向模型往返测试。

### 3.2 工程与测试

- `flutter analyze` 无问题；根项目 881 项测试全部通过。
- 93 个测试文件覆盖 Controller、SQLite、备份、导入、多币种、退款、AI、页面交互和关键旅程。
- Android GitHub/Play flavor、权限差异、R8 和发布预发布流程均有明确文档。
- 用户可见保存失败已有根级反馈；编辑页的新 API 多数采用“落库成功后再提交内存”的模式。

### 3.3 正式 UI 代码的一致性

- 四个根页面统一使用 `VeriPage + PageHeader`，普通全屏页大多使用 `Scaffold > SafeArea > VeriPage > VeriHeader`。
- 分类、账户、金额、页面 Header、卡片、弹窗和轻提示已有共享入口，不是各页面完全自由发挥。
- 金额颜色、日期、多币种单位、日历日运算和快速记账交互均有专门规范与测试。
- 根导航、快速记账和反馈组件具有明确的状态机和专项测试。

## 4. Critical

### CR-01 · 正式发布签名私钥和凭据进入版本库

证据：

- `android/app/verifin-release.jks` 是 Git 跟踪文件。
- `android/app/build.gradle.kts:35-40` 直接配置 keystore 文件、别名和明文口令。
- `README.md` 还把“项目内稳定 keystore”作为发布说明。

影响：

- 能取得仓库内容的人可尝试以 Veri Fin 正式身份签名 APK。
- 对 GitHub 自分发版本，恶意包可能覆盖安装到已有用户设备；应用签名所代表的作者身份和用户信任失效。
- 删除当前文件不能消除历史泄露；必须按“密钥已经泄露”评估。
- Play 版影响取决于是否启用 Play App Signing、仓库中的密钥是应用签名密钥还是仅上传密钥，需在 Play Console 核实。

建议方向：

1. 立即确认仓库可见范围、历史访问者、Play App Signing 状态和线上包证书。
2. 制定 GitHub 自分发与 Play 两条渠道的密钥迁移方案，再移除历史中的私钥和凭据。
3. CI 改用受保护的 secret/环境注入签名材料；Play 使用独立上传密钥。
4. 不要直接生成新密钥替换，否则既有安装包将无法覆盖升级。

依据：[Android 官方应用签名文档](https://developer.android.com/studio/publish/app-signing)明确要求应用签名私钥必须保密，泄露后第三方可以签发恶意替代包。

### CR-02 · Android 系统 Auto Backup 可能自动上传账目与机密配置

证据：

- `android/app/src/main/AndroidManifest.xml:24` 的 `<application>` 没有设置 `android:allowBackup`、`android:fullBackupContent` 或 `android:dataExtractionRules`。
- Android 对目标 API 23+ 的应用默认启用 Auto Backup。
- SQLite 保存完整账目、账户和卡号；SharedPreferences 保存 AI Key、WebDAV 密码、备份口令、应用锁哈希、日志和 AI 聊天历史。
- 产品文档声称只有用户主动启用导出、WebDAV 或 AI 时数据才会发送到用户选择的目标。

影响：

- 用户未主动启用 Veri Fin 备份时，系统仍可能把应用私有数据上传到 Google Drive 或参与设备迁移。
- “不进本应用 JSON 备份”并不等于“不进 Android 系统备份”；当前备份范围文档遗漏了系统层渠道。
- 机密凭据可能和账目数据一起离开设备，直接违反本地优先和数据自主承诺。

建议方向：

1. 优先评估 `android:allowBackup="false"`，并为 Android 12+ 明确配置 `data-extraction-rules`。
2. 决定是否允许设备到设备迁移；如允许，应显式排除凭据、日志、聊天历史和应用锁材料。
3. 补 Android 真机/模拟器的 backup/restore 测试和隐私文档。
4. 即使关闭系统备份，仍应把机密从普通 SharedPreferences 迁移到 Keystore 保护的存储。

依据：[Android Auto Backup 官方文档](https://developer.android.com/identity/data/autobackup)说明默认值为 `true`，默认范围包含 SharedPreferences 等应用私有数据，并建议敏感应用显式关闭或配置备份。

## 5. High

### H-01 · SQLite 增量行快照存在并发写竞态

证据：

- `veri_fin_controller_state.dart:730-739` 的 `_trackWrite` 接收已经开始执行的 Future，只记录“最后一个 Future”，没有把写任务串成队列。
- `ledger_repository.dart:471-508` 的 `_incrementalReplace` 在事务前读取 `_rowSnapshots`，事务完成后才更新快照。

可复现场景（代码层推导）：

1. 快速新增交易 A：第一次保存基于旧快照计算“插入 A”，随后等待事务。
2. 第一次完成前立即删除 A：第二次保存仍看到旧快照，认为“空列表没有变化”，提前返回。
3. 第一次事务之后仍把 A 写入数据库，而 Controller 内存已经没有 A。
4. `_pendingWrite` 可能指向已提前完成的第二次 Future，`flushPendingWrites()` 也未必等待第一次写入。

影响：快速操作、批量操作或生命周期切后台时可能出现重启后交易复活、更新回退或内存/数据库不一致。

建议方向：Controller 或 Repository 必须拥有真正串行的写队列；每次任务在队列中读取最新快照并执行，不能只依赖 sqflite 自身串行连接。

### H-02 · 多表破坏性命令没有统一事务，且 UI 会先报告成功

证据示例：

- `deleteAccountAndRelatedEntries` 分别保存周期规则、交易、附件、账户排序和账户。
- `deleteEntries` 分别保存交易与附件。
- 标签删除、分类合并等路径也会分别调用多个 `_persistX`。
- 这些 API 多数先修改内存、立即返回计数或 `void`，再异步落库。

影响：任一写入失败或进程在中途终止，都可能产生孤儿附件、悬空引用、规则与账户状态不同步；UI 已退出页面或提示成功，无法可靠回滚。

建议方向：所有跨表命令构造 next snapshot，调用 Repository 的单事务命令，成功后再替换 Controller 内存；不要让 `replaceAllLedgerData` 只服务导入、恢复和删账本。

### H-03 · “批量改账户”会破坏多币种三层金额

证据：

- `veri_fin_controller_ops.dart:2770-2788` 仅执行 `entry.copyWith(accountId: accountId)`。
- UI 在 `transactions_pages.dart:924-949` 向用户展示所有活动账户，没有限制目标账户币种。
- 测试 `batch_operations_test.dart:68-77` 只断言 ID 被替换，没有覆盖跨币账户、`accountAmount`、`baseAmount` 或转账手续费。

影响：把 USD 账户交易批量移到 CNY/JPY 等账户后，旧 `accountAmount` 会被按新账户币种解释；账户余额、资产估值和历史数据都会失真。转账还涉及转出金额和手续费币种，风险更高。

建议方向：同币种才允许直接批量替换；跨币种必须逐笔提供结算金额/汇率并重新校验三层金额，或明确禁止批量执行。

### H-04 · 普通 KV 写入吞掉失败，关键设置可“看起来保存成功”

证据：

- `local_storage_io.dart:67-70` 对 SharedPreferences Future 使用 `catchError((_) {})`，`flush()` 也只能等待已经被转换为成功的 Future。
- 应用锁、隐私同意、AI 配置、备份口令、WebDAV、主题和提醒等多条旧 API 仍调用普通 `write/delete`，不是 `writeAndFlush/deleteAndFlush`。

影响：设置在当前内存中生效，但系统写盘失败后重启丢失；应用锁尤其可能在用户以为开启后实际没有持久化。失败没有日志，也不会触发根级保存失败提示。

建议方向：关键配置只允许可等待、可失败的 durable API；普通 fire-and-forget 写入也必须保留错误并让 `flush()` 真实传播结果。

### H-05 · 分享图片的 25 MB 限制在完整读入之后才检查

证据：`MainActivity.kt:176-177` 先对外部 `content://` 流执行 `readBytes()`，之后才判断是否超过 `MAX_CAPTURE_IMAGE_BYTES`。

影响：恶意或异常 ContentProvider 可以返回超大甚至持续增长的数据流，在命中 25 MB 检查前耗尽应用内存，导致 OOM/崩溃。`ShareReceiverActivity` 是 exported 组件，输入属于不可信边界。

建议方向：使用带累计计数的分块读取，在超过上限时立即停止；同时验证 MIME、URI scheme、实际图片解码边界和并发任务数。

### H-06 · 自动备份准备阶段的异常被完全静默吞掉

证据：`backup_coordinator.dart:91-92` 的外层 `catch (_) {}` 没有日志、用户反馈或失败状态；只对内部本地写入和 WebDAV 上传做了日志。

影响：JSON 导出、附件打包、加密或其他未预期异常会让自动备份长期不执行，用户只能从“上次备份时间不更新”间接发现。备份是本地优先应用的数据安全网，静默失败风险高。

建议方向：外层异常必须写隐私友好日志，并在下次进入数据管理页或连续失败达到阈值时展示明确状态。

### H-07 · 发布工作流的供应链权限过宽且 Actions 未固定 SHA

证据：

- `.github/workflows/flutter.yml:8-9` 在工作流顶层授予 `contents: write`，检查、构建和发布三个 job 都继承。
- `subosito/flutter-action@v2`、`softprops/action-gh-release@v2` 等第三方 Action 使用可移动 tag，没有固定完整 commit SHA。

影响：任一上游 Action tag 被劫持时，可接触写权限并篡改 Release 或仓库内容。当前工作流还负责分发正式签名制品，风险高于普通 CI。

建议方向：默认 `contents: read`，只给 release job 最小 `contents: write`；所有 Action 固定经审核的完整 SHA，并配 Dependabot/Renovate 更新。

依据：[GitHub Actions 安全加固文档](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions)指出完整 commit SHA 是 Action 不可变引用的唯一方式。

## 6. Medium

### M-01 · 测试通知无论是否发送成功都提示成功

- `NotificationScheduler.showTest()` 返回 `Future<void>`，内部在 `notification_scheduler_io.dart:178-192` 吞掉所有错误。
- `reminder_settings_page.dart:142-150` 忽略权限返回值，并始终显示“已发送测试通知”。

结果：用户在权限拒绝、插件异常或系统渠道失败时仍被告知成功，失去“测试通知用于诊断”的产品价值。

### M-02 · 全局允许明文网络，凭据可能被截获或篡改

- Manifest `android:usesCleartextTraffic="true"` 对整个应用生效。
- AI Bearer Key、WebDAV Basic Auth 和账目摘要允许通过 HTTP 发送；目前只在配置公网 HTTP 时警告，不阻断。
- `localhost`、RFC1918、link-local 和 `.local` 被视为相对可信，但局域网仍可能遭受 ARP/DNS 中间人攻击。

建议：默认强制 HTTPS；如必须支持本地 HTTP，要求单独显式开启并持续显示风险，避免把全局明文能力作为默认应用策略。依据：[Android 明文通信风险说明](https://developer.android.com/privacy-and-security/risks/cleartext-communications)。

### M-03 · AI/WebDAV/备份口令和聊天历史明文存 SharedPreferences

当前文档明确接受这一信任边界，但 AI Key、WebDAV 密码、备份口令、完整聊天和结果卡片均是高敏感数据。普通应用沙箱能防其他普通 App，却不能抵御系统备份、root、调试备份或本机取证。

建议：用 Android Keystore 生成不可导出的主密钥，加密这些 KV；认证类解密可按产品需要绑定生物/设备解锁。依据：[Android Keystore 官方文档](https://developer.android.com/privacy-and-security/keystore)。

### M-04 · 应用锁使用一次 SHA-256，且配置损坏时 fail-open

- 6 位 PIN/3×3 图案只做加盐 SHA-256；离线取得哈希后枚举空间很小。
- 没有失败次数节流或逐步延迟。
- `_loadAppLock()` 解析失败时删除配置并退回 `none`，属于 fail-open。

产品文档把威胁模型限定为“防顺手偷看”，因此不是密码库级漏洞；但“应用锁”文案可能让用户高估其保护能力。建议至少采用慢 KDF、尝试节流，并对损坏配置提供安全恢复页而不是静默解锁。依据：[OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)。

### M-05 · 备份/账单导入没有输入大小、解压总量和条目数量上限

- `backup_archive.dart:58` 直接 `ZipDecoder().decodeBytes(zipBytes)`。
- 多个文件选择入口直接 `readAsBytes()`。
- xlsx/Tally 等压缩格式也在内存中一次性解码。

影响：用户误选或攻击者提供 zip bomb/超大文件时可能耗尽内存或长时间卡死。建议统一 `ImportLimits`：原始文件大小、压缩后总量、单条目大小、条目数、JSON 深度和附件总量均设上限。

### M-06 · 加密备份信封的 KDF 参数未设可信范围

`backup_crypto.dart:105` 直接采用文件中的 `iter`。恶意文件可把迭代数设为极大值，使导入长时间占用 CPU；salt、nonce、cipher 和 MAC 解码也没有大小/长度前置校验。

建议：先验证 `app/kdf/enc`、迭代上下限、salt/nonce/MAC 固定长度和密文最大值，再执行 KDF。

### M-07 · 备份 PBKDF2 工作因子低于当前通用指导值

当前 `PBKDF2-HMAC-SHA256` 为 120,000 次；OWASP 当前通用建议为 600,000 次。移动设备需以“正常设备小于约 1 秒”为目标实测，不能机械照搬，但应有版本化升级计划。旧文件可按信封中的旧迭代数继续解密，新文件使用新参数。

### M-08 · 顶层 Zone 的异步错误没有进入 AppLogger

`main.dart:29-74` 创建 logger 后，`runZonedGuarded` 的 error handler 仍只执行 `debugPrint`。注释认为 logger 可能尚未创建，但绝大多数运行期未捕获 Future 错误发生在 logger 已创建之后。

结果：生产环境最需要记录的异步错误没有出现在“软件日志”，而 `debugPrint` 也违反仓库生产日志约定。

### M-09 · Controller 仍是超大单体，领域边界主要靠注释维持

- `veri_fin_controller_ops.dart` 约 3,800 行，`state.dart` 约 800 行。
- 同一对象负责账务、账户、分类、预算、备份设置、AI、应用锁、UI 偏好和导入。
- `InheritedNotifier` 的广域 `notifyListeners()` 使无关状态可能触发整页重建。

建议：不必更换状态管理框架，先按领域抽出纯 command/service 和不可变 snapshot；Controller 保持编排与注入入口。优先拆交易聚合、账户命令、预算和设备偏好。

### M-10 · 新建与编辑交易有大量重复实现

- `entry_detail_page.dart` 约 2,000 行。
- `transaction_detail_page.dart` 约 1,200 行。
- 两处重复维护类型切换、账户、汇率、三层金额、退款、附件、校验和未保存退出。

近期多币种修复经常需要同时修改两页，已经证明存在漂移成本。建议建立共享 `EntryDraft`/编辑协调器和可复用表单区块，页面只保留“快速记账布局”和“完整编辑布局”的差异。

### M-11 · Android MainActivity 集成过多领域

`MainActivity.kt` 约 1,250 行，同时处理更新、下载、安装、SAF、Downloads、分享/OCR 输入、小组件、快捷磁贴、安全 Flag 和 MethodChannel。

仓库要求单一 MethodChannel handler 是正确的，但不代表所有实现必须留在 Activity。建议保留一个 dispatcher，把 Update、Storage、Capture、Widget 拆为内部协作类，降低安全审查和生命周期维护难度。

### M-12 · 安全的新 Draft API 与旧的直接 mutator 长期并存

Controller 同时暴露：

- 落库成功后才改内存的 `saveEntryAggregateDraftResult`、`saveAccountDraft` 等。
- 先改内存再异步保存的 `addEntry`、`updateEntry`、`addRefund`、`updateAccount`、`setEntriesAccount` 等。

后者可绕过集中三层金额校验，也让调用方难以知道成功语义。建议把旧 API 限制为测试/内部迁移，生产页面只用返回结构化结果的 command API。

### M-13 · 首次数据库播种不是单事务

`_loadFromRepository()` 在空库时依次保存账本、账户、分组和分类。进程终止或中途失败可能留下“有账本但缺账户/分类”的半初始化库，下一次启动又会进入非空库分支。

建议：首次播种也使用 `replaceAllLedgerData` 单事务；自愈新增默认账本/分类时应等待落库或明确记录失败。

### M-14 · 未知账户 ID 会冒名成第一个真实账户

`model_lookup.dart:44-60` 的 `accountById` 在账户列表非空、ID 不存在时返回 `accounts.first`，只有列表为空才返回“已删除账户”。交易展示和搜索的部分路径会因此把悬空账户显示成用户第一个账户。

影响：虽不改变余额数学，但会误导用户、搜索和交易详情；还与函数注释中的“已删除账户占位”不一致。应对未知 ID 始终返回带原 ID 的占位；空 ID 仍使用显式“无账户”路径。

### M-15 · 全局紧凑密度把多个正式控件压到 Android 推荐触控尺寸以下

- `app_theme.dart:42` 使用 `VisualDensity.compact`。
- IconButton 最小 40×40，FilledButton 44×44，TextButton 36×34 且 `shrinkWrap`。
- 快速记账胶囊存在 31dp 固定高度。

Android/Flutter 推荐 Android 可点击语义节点至少 48×48。当前策略有利于信息密度，但对手指精度、老人和无障碍用户不友好。可保持视觉尺寸紧凑，但扩大透明命中区域。依据：[Flutter Accessibility Guideline API](https://docs.flutter.dev/ui/accessibility/accessibility-testing)和 [Android 48dp 指南](https://developer.android.com/guide/topics/ui/accessibility/views/apps-views)。

### M-16 · 次要文字和图表刻度存在系统性低对比风险

- 全局 `labelSmall` 只有 10sp。
- Header 副标题、图表说明、预算和交易辅助信息大量使用 `onSurface` 的 0.42-0.48 alpha。
- 图表轴文字为 10sp，部分颜色还继续降低 alpha。

这些组合在浅色背景上很可能低于普通小字 4.5:1 的参考值；深色模式也需按实际合成色测量。建议建立 `textMuted/textSubtle/textDisabled` 语义 token，并用 Flutter `textContrastGuideline` 自动检查，而不是各处手写 alpha。

### M-17 · 交互图表缺少数据语义和非手势操作

`InteractiveTrendChart`、`InteractiveBarChart`、预算图和分类圆环主要由 `GestureDetector + CustomPaint` 实现。画布里的日期、数值和当前选中点没有 `semanticsBuilder` 或等价的可访问列表，也没有键盘/辅助动作选择上一个、下一个数据点。

视觉用户可以点按/滑动看气泡，TalkBack 用户可能只得到一个没有数据描述的手势节点。建议给整图摘要、每个点/柱的 label/value、增减选中动作，并提供可展开的数据表替代。

### M-18 · 外部文本采集入口可被其他 App 触发并消耗用户 AI 额度

`ShareReceiverActivity` exported，公开的 `ACTION_CAPTURE_TEXT` 是为 Tasker 设计；任何本机 App 都可尝试启动该流程。只要 AI 已配置，文本会在落账确认之前发送到用户端点，没有来源授权、节流或单任务互斥。

影响受 Android 后台启动限制和前台可见性约束，但恶意 App 仍可能反复拉起页面、制造并发解析或消耗 API 额度。建议为自动化入口提供用户可关闭开关、频率限制和可选签名级权限；分享入口与自动化入口分开建模。

## 7. Low / 已知风险

### L-01 · 金额使用 `double` / SQLite `REAL`

已在 `known-limitations.md` 接受。当前通过货币精度规整和容差降低风险，但累计误差、超大金额和严格会计场景仍不是整数 minor-unit 模型。达到整改阈值后应整体迁移，不能局部混用。

### L-02 · 余额与部分聚合仍会重复扫描全部交易

已记录为 O(账户数×交易数) 技术债。当前数据量下可接受，但广域 `notifyListeners()` 会放大重复计算。建议先加性能基准和阈值监控，再决定索引/缓存方案。

### L-03 · 删除占位文案硬编码中文

`model_lookup.dart` 的“已删除分类/已删除账户”会在损坏数据或悬空引用状态进入用户界面，英文模式仍显示中文。应把占位对象与用户可见 label 分开，由展示层本地化。

### L-04 · 截图识账未知异常直接显示 `$error`

`capture_entry.dart` 对未分类异常使用 `errorText = '$error'`，可能把插件、路径或网络内部信息直接暴露给用户；与 AI 页面“不展示底层异常”的既定规范不一致。应记录完整错误，界面只显示稳定本地化错误码。

### L-05 · 图片读取权限可能超过选择器实际需要

Manifest 声明 `READ_MEDIA_IMAGES` 和旧版 `READ_EXTERNAL_STORAGE`。当前图片入口主要通过系统 picker/URI grant，需真机核实是否仍需广域媒体权限；如不需要，应移除以缩小隐私与商店申报范围。

### L-06 · 默认未加密备份包含完整账目、附件和可选完整卡号

这是当前明确产品设计，不是实现偏差，但风险提示应足够醒目。建议在首次导出未加密备份、启用 WebDAV 自动上传时说明备份内容，并引导设置高强度口令；不要把“备份可加密”误解为默认已加密。

### L-07 · 文档存在 CI 触发口径矛盾

`docs/acceptance-checklist.md:36` 正确说明 PR/main 运行质量 CI、tag 运行发布；同文件 `:116` 又写“普通提交和 main 推送不应触发 GitHub Actions”。源码事实以 workflow 为准，应把后者改成“不触发发布构建/Release”。

## 8. 正式 UI 源码审查

### 8.1 一致性判断

从生产代码看，项目已经有统一设计语言，不需要推倒重做：

- 根页面、普通子页、卡片、Header、金额、账户/分类图标和轻提示都有共享实现。
- 主色、收支色、背景层级和圆角尺度整体稳定。
- 特殊页面的偏离多数有合理原因：快速记账强调单手操作；应用锁和 onboarding 需要沉浸式布局；导入预览有固定底部确认区。

目前最大的视觉风险不是“每页完全不同”，而是共享主题本身过度追求紧凑，以及局部页面仍在绕开 token。正式 Android 实际效果仍必须补真机证据。

### 8.2 最值得优先优化的方向

1. **先修可读性和触控，不先换风格**：提升次要文字对比，保证 48dp 命中区域，验证系统字体放大。
2. **建立语义颜色层级**：用 `textPrimary/textSecondary/textTertiary/divider/surfaceRaised` 代替几十处 `onSurface.withValues(alpha: ...)`。
3. **收敛局部裸色和魔法圆角**：AI 对话、图表、日志、快速记账键盘等仍有直接 `Color(0x...)` 和 13/18/24/99/999 圆角，长期会产生“差一点但说不清”的不统一。
4. **把密集页面按任务分组**：交易详情、账户详情、数据管理、周期记账和导入预览是最高密度区域；优先做渐进展开、区块标题和主次操作收敛。
5. **统一新建/编辑交易的视觉组件**：共享同一表单区块后，字段间距、错误态、账户/币种显示和退款区就不会两套页面各自漂移。
6. **给图表提供无障碍与表格替代**：这既提升可访问性，也让数据表达更可靠。
7. **建立真实 Android 视觉基线**：在 360/390/440dp、浅色/深色、中文/英文、1.0/1.3/2.0 字体缩放下截取生产页面，至少覆盖四个根页、快速记账、交易编辑、账户、预算、统计、数据管理和应用锁。

### 8.3 当前无法确认的视觉问题

- 真机状态栏、导航栏、IME、预测性返回和刘海安全区。
- Android 字体回退后中文的字重、行高和截断。
- 动画、拖动玻璃导航、图表点按、长列表滚动的实际流畅度。
- OLED 深色模式对比、不同系统字体缩放和 TalkBack 阅读顺序。
- release/R8 下 OCR、图片、通知和原生弹窗带来的完整体验。

UI Lab 仅用于调试部分组件，不能作为上述结论的视觉证据，本报告没有引用 UI Lab 截图。

## 9. 测试与质量缺口

建议补充但本轮不实施：

- 增量 Repository 的快速“新增→删除”“新增→连续修改”并发回归测试。
- 跨币种批量改账户测试，覆盖普通交易、转账、手续费和退款。
- 多表命令故障注入测试：第 N 张表失败时 DB 与内存都保持原状态。
- SharedPreferences 写失败、应用锁启用失败和隐私同意写失败测试。
- Android Auto Backup 排除规则测试。
- exported capture 的超大/无限流、非法 URI、并发 Intent 和速率限制测试。
- 备份 zip bomb、最大 JSON、极端 KDF `iter`、附件数量与总量测试。
- `androidTapTargetGuideline`、`labeledTapTargetGuideline`、`textContrastGuideline` 自动化测试。
- 生产 Android 截图回归和 TalkBack/Accessibility Scanner 真机检查。
- Release 工作流最小权限、固定 SHA 和制品签名证书校验。

## 10. 建议处理顺序

### 阶段 A：先确认是否已经暴露

1. 签名私钥/Play App Signing 状态。
2. Android Auto Backup 实际行为和线上隐私影响。
3. GitHub 仓库可见性、历史访问和 Release 权限。

### 阶段 B：修数据正确性

1. 串行化增量写和快照。
2. 跨表命令事务化。
3. 禁止或正确实现跨币种批量改账户。
4. 统一 durable Controller API。

### 阶段 C：安全与可靠性加固

1. Keystore 保护本机机密。
2. 限制导入、解压、OCR 输入和 KDF 参数。
3. 收紧明文网络、外部 Intent、CI 权限和 Action 引用。
4. 修复自动备份、通知和顶层日志的静默失败。

### 阶段 D：正式 Android UI 优化

1. 建立真机截图与无障碍基线。
2. 先处理触控尺寸、对比和图表语义。
3. 再统一 token、密集页面层级和交易表单复用。

## 11. 本轮验证记录

- `flutter analyze`：通过，无问题。
- 初次审查 `flutter test`：881 项通过；用户批注后的修复全测：889 项全部通过。
- `tool/ui_lab/flutter analyze`：通过。
- `tool/ui_lab/flutter test`：通过，23 项测试全部成功。
- `tool/ui_lab/flutter build web`：通过；仅证明实验工程可构建，不代表正式 Android UI。
- `flutter pub outdated --json`：当前已解析版本未报告 Pub 安全公告；有常规可升级依赖，不等同于必须立即升级。
- Android SDK/模拟器/真机：不可用，因此未运行正式应用、APK/AAB、R8 或平台能力验收。

初次审查只新增本记录；用户批注后，同一分支继续修复了上方“跟进状态”列出的持久化、多币种、Android 备份和外部输入问题，并同步测试、文档与 CHANGELOG。发布状态未改变。
