# Veri Fin Agent 开发指南

2026-09-05 启动恢复保护：v1.16.0 收到 Android 开启高级材质后持续闪退的真机报告。原生端现强制普通磨砂并隐藏高级材质入口；旧 KV 选择保留，但不能启用高级绘制或加载导航 Shader。仅 Web 保留高级材质实验。尚未取得原生崩溃日志，不能断言具体 GPU/引擎根因；重新开放前必须完成 Android release/R8 真机开启、冷启动、切页与关闭验收。恢复应使用同 applicationId、同签名、更高 versionCode 的 CI 修复包覆盖安装，禁止要求用户清数据。

v1.16.0 发布说明：CI Android 两渠道及 Web 门禁显式带 `--dart-define=UNIFIED_DESIGN_PREVIEW=true --dart-define=GLASS_DESIGN_PREVIEW=true`，保证手机包含已评审外观。高级材质仍默认关闭、由设置保存控制。本地与发布包对照时必须使用相同参数；无参数构建保留旧外观用于回归。

界面调整必读 [统一设计与交互规范](docs/design-system.md)：集中记录已确认布局、两档材质、深浅色光照、设置持久化与验收约定；历史研究稿不得覆盖该规范。候选统一排版现覆盖全部页面；导航静止必须显示实时文字，预算环禁止内外白线。

## 文档作用与工作语言

本文件是仓库内 Agent 与贡献者的执行规范。Veri Fin 是一个以 Android 交付、支持真实应用 Web 开发预览的 Flutter 记账应用：Dart 包名为 `verifin`，Android applicationId 为 `top.talyra42.verifin`。

- 与用户沟通、说明方案和汇报结果时使用中文；代码符号、命令和提交类型保留英文。
- 改动聚焦用户请求，不顺手重构无关代码，不覆盖用户已有修改。
- 开始任务前先确认工作树状态，并按任务领域阅读下方文档；不要把历史规划当成当前实现。
- 判断“当前实现事实”时，若说明文档与实现不一致，以当前源码、测试、Gradle、工作流和发布脚本为准，核实 git 历史后同步修正文档。本文的规范性规则仍必须遵守，已有违规实现不构成可复制的先例。

### 文档阅读路线

- `CLAUDE.md`：当前架构与主要功能总览；内容很全，但细节仍需用代码和配置复核。
- `docs/dev/components.md`：组件、弹窗、格式化与纯函数注册表；写相关代码前必读。
- `docs/ui-guidelines.md`：页面骨架、交互、图表和视觉规范。
- `docs/dev/tech-decisions.md`：数据口径、备份范围和关键技术取舍；个别历史背景可能已被新实现取代，仍需与代码和测试核对。
- `docs/dev/known-limitations.md`：已接受技术债及触发整改的阈值。
- `docs/dev/ai-tools.md`：AI 账目查询工具的注册和维护约定。
- `docs/dev/category-budget-override-design.md`：分类默认预算与单期覆盖的职责、Issue #28 兼容方案和验收范围。
- `docs/dev/multi-currency-design.md`：已落地的多币种、离线汇率、跨币种交易/退款、迁移与验收依据；后续修改须保持三层金额和历史冻结口径。
- `docs/dev/refund-design.md`、`docs/dev/auto-capture-plan.md`、`docs/dev/i18n-verification.md`、`docs/automation.md`：对应领域的设计与验收资料。`refund-design.md` 含历史方案，退款当前行为以源码、测试和 `docs/dev/known-limitations.md` 为准。
- `docs/dev/web-preview.md`：正式应用 Web 预览、浏览器存储与平台能力边界。
- `docs/dev/unified-design-preview.md`：默认关闭的统一设计候选方案；用户确认前不得把 `UNIFIED_DESIGN_PREVIEW` 默认开启或移除旧外观路径。
- `docs/dev/glass-material-preview.md`：用户主动要求的内容磨砂玻璃预览，通过额外的 `GLASS_DESIGN_PREVIEW` 开关试验；不得以材质调整为由改动预算等既有结构。
- 玻璃光效按用户参考图：左上/右下渐隐高光，不用均匀白边；导航允许真实纹理透镜与动态光照，高级材质默认关闭、保存后启用；关闭使用普通磨砂且不创建透镜，深色高光需单独减弱。与旧玻璃文档冲突时以该用户指定方向及最新预览文档为准。
- `docs/dev/liquid-glass-navigation.md`：浮动根导航的材质边界、指针拖动状态机、窄屏适配、真实应用 Web 验证与后续 Shader 取舍；修改根导航或新增类似玻璃控件前必读。
- `docs/dev/feedback-system.md`：根级轻提示 Host 的调用、时长、操作结果、去重、优先级队列与迁移规范；新增或替换短反馈前必读。
- `README.md`、`docs/product.md`、`docs/acceptance-checklist.md`：用于理解产品和验收范围；其中少量历史描述可能落后，必须与当前实现交叉核对。

## 产品原则

- **本地优先、数据自主**：无账号、无自有服务端、无广告、无联网遥测。权威账目数据存于用户设备；只有用户主动启用的导出、WebDAV 备份或 AI 功能才会对外传输相应数据，WebDAV 不是账号云同步。
- **隐私优先**：AI 使用用户自己配置的 OpenAI 兼容端点。AI 记账只生成草稿，必须经用户确认后落账；AI 查询工具全部只读，绝不提供写数据能力。
- **不做监听类自动记账**：不注册通知监听、无障碍或短信监听。截图在端上 OCR，原图不上传；分享或 Intent 入口也只能生成待确认草稿。
- **Android 能力必须真实可用**：测试 stub 不能被当作生产实现。本地存储、图片、文件、通知、生物识别、安装包、桌面小组件或系统入口都要核对 Android 权限、持久化、进程重启和生命周期行为。

## 项目结构与数据流

### 目录职责

- `lib/main.dart`：应用入口与根组件，负责初始化 KV、日志、SQLite 和 Controller，并挂接周期补记、备份、提醒、小组件、应用锁及生命周期。
- `lib/pages/`：页面层，按首页、资产、看板、我的、交易、预算、账户、导入、AI、退款、应用锁等功能拆分；共享弹窗入口在 `lib/pages/sheets.dart`。
- `lib/app/`：领域模型、Controller、主题、纯计算、通用组件、备份、AI、提醒、日志及平台适配。
- `lib/app/models/`：领域模型与 JSON 映射；`lib/app/models.dart` 是稳定 barrel 入口。SQLite 行映射集中在 `lib/data/ledger_repository.dart`。
- `lib/app/common_widgets.dart`：通用组件稳定入口，具体实现按 part 拆分。
- `lib/data/`：`AppDatabase`、`LedgerRepository` 与 `SqliteLedgerRepository`。
- `lib/local_storage/`：偏好类 KV 适配，Android 使用 SharedPreferences，测试使用内存 stub。
- `lib/l10n/`：中英文 ARB 与已提交的 gen-l10n 生成文件。
- `android/`：原生桥、Manifest、flavor、小组件、快捷磁贴、分享入口和发布配置。
- `test/`：按领域组织的 widget/单元测试、ffi SQLite 测试、导入 fixtures；共享脚手架在 `test/support/`。

### 状态与持久化

- 应用权威状态集中在 `VeriFinController`（`ChangeNotifier`），经 `VeriFinScope`（`InheritedNotifier`）注入；不使用 Provider、Riverpod 或 Bloc。
- Controller 物理拆为 `veri_fin_controller.dart`、`veri_fin_controller_state.dart`、`veri_fin_controller_ops.dart`。`VeriFinController.create()` 是生产异步创建入口。
- UI 只调用 Controller 的公共读取/操作 API，不直接访问 repository、SQLite 或 KV；Controller 内部再经 `_persistX` 等路径持久化。
- 账本、交易、账户、分组、分类、标签、附件、周期规则和预算等核心数据只认 SQLite。Controller 的内存集合是运行时读取源，不存在 KV 回退。
- `LedgerRepository.saveX` 的对外语义是“落库后该表内容等于传入集合”。生产实现把“读取行快照、计算 `_incrementalReplace` 差分、事务写入、更新快照”整体串行化；单次失败不得阻塞后续写。附件大 blob 与小型预算表仍可整表覆盖；导入、恢复、重置、删账本及跨表删除走 `replaceAllLedgerData` 原子整替，显式删除命令落库成功后才替换 Controller 内存。
- 主题、语言、触感、面板配置、备份设置、AI 配置等偏好类小数据走 `LocalKeyValueStore`。新增偏好优先参考主题/语言的独立 `ValueNotifier`，避免继续扩大全树 `notifyListeners()`。
- Android/Web/测试差异统一采用条件导出；Web 使用 `dart.library.js_interop`，跨平台插件实现共用文件。真实存储、图片、文件能力不得落到测试 stub；Web 明确不支持的系统/网络能力须标注边界。

### 领域不变量

- 多账本数据按 `bookId` 隔离；切换账本不能泄漏账户、交易、预算或排序偏好。
- 分类是邻接表树。创建路径须按 `normalizedCategoryLabel` 查重复用；不得绕过唯一约束。未知或悬空分类不能回退列表首项，载入/导入后的自愈约定见 `docs/dev/tech-decisions.md`。
- `LedgerEntry.accountId == ''` 表示“无账户”。展示名称用 `accountDisplayName`；不要用会回退首账户的 `accountById` 解释空 id。
- 账户能力只通过 `supportsCardLast4`、`supportsCredit` 判断，禁止散落硬编码账户类型。`cardLast4Follows` 是持久化字段，不能从卡号和后四位反推用户选择。
- 转账不计入收支，手续费由转出账户承担；转账分类不得留空。
- 退款是关联原支出的独立条目；只有已到账退款影响余额和净额，原支出的 `refundedBaseAmount` 是已到账退款 `baseAmount` 之和的派生缓存。修改退款逻辑前必须阅读 `docs/dev/refund-design.md` 和 `docs/dev/multi-currency-design.md` 并以当前代码/测试为准。
- 自定义预算周期只改变预算体系口径，统计报表仍按自然月。默认预算使用哨兵键，单月覆盖优先于默认值。

## 开发、测试与预览命令

```bash
flutter pub get
flutter run -d <android-device-id> --flavor github
flutter analyze
flutter test
flutter test test/entries_test.dart
flutter test --plain-name "关键字"
dart format .
```

电脑端直接运行正式应用的 Web 开发预览（同一 `lib/main.dart`、Controller 和仓储）：

```bash
flutter pub get
flutter run -d chrome --web-port 7357
flutter build web --no-web-resources-cdn
```

Web 的 SQLite WASM 文件系统持久化到 IndexedDB，偏好通过 SharedPreferences
存入浏览器 localStorage。固定 origin/端口并只使用一个标签页编辑；浏览器数据与
Android 独立。平台能力范围、资源更新与验收见 `docs/dev/web-preview.md`。
不要再创建独立的演示 UI 工程或复制正式页面；设计评审直接使用真实应用。
Web 与 Android 保持相同的页面展示，不插入 Web 开发说明横幅或卡片；平台限制写入开发文档，在实际触发不支持的操作时反馈。
视觉迭代保留用户指定的首页预算圆环及支出、剩余日均等指标、概览指标方块和“我的”四列宫格，优先调整尺寸与间距；未经新的明确要求，不再移除或替换这些结构。
浏览器 UI 验证先设置标准手机逻辑视口，默认使用 iPhone 15 的 393 × 852；
截图和交互检查保持同一尺寸，另按需要补窄屏验证。这不是 iOS 平台支持声明。

- Android 运行/构建仍必须显式使用 `--flavor github`；验证 Play 时使用 `--flavor play --dart-define=SELF_UPDATE=false`。浏览器预览不能替代 Android 原生能力、生命周期和性能验收。
- 提交前执行 `dart format .`、`flutter analyze` 和 `flutter test`。只改文档时至少做 diff/链接/路径校验，可不运行 Flutter 测试，但要在汇报中说明。
- 不把本地 `flutter build apk` 当成交付依据；正式 APK/AAB 由 GitHub Actions 构建。

### CI 与发布

- `.github/workflows/ci.yml` 在每个 PR 和每次 push 到 `main` 时执行格式检查、analyze、全量测试和 `github` flavor Android debug APK 编译门禁；该 APK 只用于提前发现 Kotlin/Manifest/原生桥编译错误，不作为交付物。
- `.github/workflows/flutter.yml` 只在推送 `vX.Y.Z` 标签时触发发布构建：
  - GitHub 自分发：arm64-v8a APK，`--flavor github`。
  - Google Play：AAB，`--flavor play --dart-define=SELF_UPDATE=false`。
- 两种 release 都开启 R8 代码压缩与资源裁剪。新增依赖若使用反射，必须同步检查 `android/app/proguard-rules.pro`；OCR、通知等问题可能只在 release/R8 下暴露。
- `play` flavor 移除 `REQUEST_INSTALL_PACKAGES` 和 `USE_EXACT_ALARM`，保留可申请的 `SCHEDULE_EXACT_ALARM` 并在无授权时回退；自更新入口通过 `kSelfUpdateEnabled` 隐藏。渠道差异放在 flavor Manifest 或构建开关中表达。
- CI 创建 GitHub **预发布**且不标记 Latest；真机验收通过后再由维护者手动提升为正式版。
- Release 使用项目内稳定 keystore；不要替换、重生成或泄露签名材料。

**发版必须得到用户明确授权。** 打标签会推送远端并触发 CI，不能自行执行。实际顺序如下：

1. 确定版本号与日期，把 `CHANGELOG.md` 顶部 `## [Unreleased]` 提升为本次版本，并在其上新建空的 `## [Unreleased]`。
2. 先提交 CHANGELOG 变更，确认当前分支是 `main` 且工作树完全干净。
3. 发布脚本参数可取 `patch`、`minor`、`major` 或显式版本号（如 `1.2.3`）。macOS/Linux 示例：`scripts/publish.sh patch`；Windows 示例：`./scripts/publish.ps1 patch`。两份脚本逻辑必须同步维护。
4. 脚本会更新 `pubspec.yaml` 与 `lib/app/app_version.dart`，执行格式化、依赖安装、analyze、test，创建 `chore: release vX.Y.Z` 提交、标签并推送。
5. 下载 CI 生成的预发布 APK 真机验收；通过后再手动设为正式版和 Latest。

## 代码风格与工程约定

### Dart 与依赖

- 遵循 Dart 默认格式和 `analysis_options.yaml` 的 `flutter_lints` 及额外正确性 lint；使用两个空格缩进。
- 文件用 `snake_case.dart`，类/枚举/Widget 用 `UpperCamelCase`，变量与方法用 `lowerCamelCase`，私有成员加 `_`。
- 正确处理 Future；不要为了绕过 `unawaited_futures` 随意丢弃异步操作。确需后台执行时使用明确的 `unawaited(...)` 并保证错误被记录和反馈。
- 不使用 `print` / `debugPrint` 作为生产日志，不写无注释的 lint ignore。
- 不为简单需求引入额外依赖或工具链。新增依赖前评估 APK 体积、Android/R8、隐私、维护成本和已有纯 Dart 实现。
- 不重写 Flutter 生成的平台工程文件，除非任务明确要求；修改 `android/` 时只动与需求直接相关的原生实现或配置。

### 组件化与复用

- 写任何 Widget、弹窗、对话框、格式化或计算前，先查 `docs/dev/components.md`。命中现成件就复用或参数化扩展，不复制脚手架、不新建同构变体。
- 同一 UI 片段或逻辑在两个及以上文件出现时，抽为共享件：通用组件放 `common_widgets.dart`，弹窗 helper 放 `sheets.dart`，记账组件放 `entry_sheets.dart`，纯计算放对应 `*_math` / `*_tree` /领域模块。新增、重命名或删除可复用件时同步组件清单。
- 标准页面骨架使用 `Scaffold > SafeArea > VeriPage`，列表页面外层 `ListView` 采用统一头部 padding，并使用 `VeriHeader` / `PageHeader`；固定页脚页面单独给头部相同 padding。细节以 `docs/ui-guidelines.md` 为准。
- 分类图标只用 `CategoryIconBox` / `CategoryGlyph`，账户图标只用 `AccountIconBox`。渲染点禁止直接调用 `iconForCode`，否则 emoji 分类会回退钱包图标。
- Row 内“居中列 label + value [+ detail]”的标准指标块使用 `SummaryMetric`。明显不同的卡片/排行可保留局部组件，不把一个组件过度参数化成配置怪物。
- 图表优先复用 `InteractiveTrendChart` / `InteractiveBarChart`，必须支持点按或滑动查看数据；位于可跳转卡片内时，图表区域要拦截点击，避免误触卡片跳转。
- 应用内短反馈只用 `VeriFeedbackHost.of(context)` / 根级 `VeriFeedbackController`，不得新增旧式 Material 横条提示或 Android Toast。破坏性确认、字段校验、阻塞进度和系统通知不迁入轻提示；完整规则见 `docs/dev/feedback-system.md`。

### 弹窗与输入

- 页面不得裸写 `showModalBottomSheet`；由顶层 `show<名>Sheet` helper 统一封装 chrome。确认框用 `showConfirmDialog`，文本输入用 `showTextInputDialog`；2–8 项静态受控单选用 `VeriAnchoredChoice<T>`，动态、较长或需分区的简单单选用 `showOptionSheet`；金额用数字键盘，分类/账户用各自选择器。
- 禁止复制内联两按钮 `AlertDialog`。破坏性确认使用 `showConfirmDialog(..., destructive: true)`。
- 取消/未选统一返回 `null`；“全部”“顶级”“无账户”等特殊选项使用集中定义、带注释的命名哨兵，不在调用点散写魔法字符串或 id。
- 新增 helper 必须把 `BuildContext` 设计为具名 `context:`；改造既有 helper 时若迁移签名，必须同步全部调用点。不要声称现有 helper 已全部完成统一。
- 触感偏好由 helper 内部从 `VeriFinScope` 获取，调用方不重复传递。

### 设计令牌、金额与日期

- 颜色使用 `veri*` 常量，圆角使用 `veriRadius*`，主色为 `veriRoyal`（`#346edb`）。禁止裸写 `Color(0x...)` 或魔法圆角；确有局部特例时写明原因。
- 金额颜色只用 `colorForType` / `accountBalanceColor`；金额文本只用 `formatAmount` / `formatSignedAmount` / `formatCompactAmount` 等现有 helper。金额为零必须是中性色 `0`，不能显示 `-0`。
- 日期和月份使用 l10n 的 `dateMonthDay` / `yearMonth` 等格式，不能手拼用户可见日期字符串。
- **日历日算术禁止裸用绝对时长**：相隔天数用 `calendarDaysBetween`，推前/推后 N 天用 `addCalendarDays`。不要用 `difference().inDays` 或 `add(Duration(days: n))` 表达日历日；夏令时地区一天可能是 23/25 小时，这类 bug 在 UTC/中国时区 CI 中不会显现。秒、小时等真实时间间隔仍使用 `Duration`。

### 异步、错误与日志

- 任何 `await` 后再次使用 `BuildContext` 前，先检查 `if (!mounted) return;` 或 `if (!context.mounted) return;`。
- 捕获异常后只有两种合格处理：使用 `AppLogger` 记录并给用户可见反馈；或明确注释这是可接受的降级及静默原因。禁止空 `catch (_) {}`。
- backup、import、AI、WebDAV、数据库、平台桥等易错路径必须记录隐私友好的结构化日志；不得把 API Key、口令、完整账目或敏感原文写进日志。
- 持久化失败不能只记录后继续假装成功；要让用户知道保存失败，并保持内存/磁盘状态可解释。

### 国际化

- 新增用户可见文案必须同时写入 `lib/l10n/app_zh.arb`（模板）和 `app_en.arb`，经 `AppLocalizations.of(context)` 使用；不要手改生成的 `app_localizations*.dart`。
- 枚举显示名使用 `label(AppLocalizations)`；无 `BuildContext` 场景使用 `l10nForPreference`，随当前语言偏好解析。
- 日期/时间选择器与系统集成文案应随当前 app locale，不得硬编码只支持中文。
- 既定豁免仅包括法律正文、银行/品牌专名、CSV 固定表头与逐行导入错误、少量无 context 的网络/桥接错误；新增豁免前先确认确实无法本地化。
- 种子账本/分类按首启动语言生成，写入后属于用户数据；切换语言不得自动重命名。

## 数据、备份与平台改动

### 数据结构变更

- 修改 SQLite 表结构必须同时：
  1. 提升 `AppDatabase.schemaVersion`；
  2. 同步 `_schemaCurrent`；
  3. 在 `_migrations` 注册“升到 vN”的新迁移段，禁止回改已发布的历史迁移；
  4. 更新 `test/migration_matrix_test.dart`，确保每个历史版本都能升级到当前结构。
- 模型新增/改字段时同步检查 `toJson`、`fromJson`、`toRow`、`fromRow` 四向映射，并更新 `test/model_roundtrip_test.dart`。
- 修改 `LedgerRepository` 契约或 save 语义时，让 `test/repository_contract_test.dart` 对内存与 SQLite 两种实现的同一套断言都通过。
- 新增本地数据必须明确并测试：默认值、持久化、冷启动读取、删除实体时清引用、初始化语义、导出/导入及旧备份兼容。

### 备份与导入

- `BackupService` 是字节格式编解码唯一入口；Controller 只接收/产出明文 JSON。未加密备份为 zip（`backup.json` + 独立附件），加密备份为 JSON 信封；不要在 UI/Controller 复制格式判定。
- 哪些数据进备份、哪些仅设备本地，必须以当前 `exportDataJson` / `importDataJson`、备份测试和实际字段共同核验，并同步维护 `docs/dev/tech-decisions.md` 的“备份范围”表。应用锁、备份口令、WebDAV 凭证、AI Key 等机密不得进入备份。
- 改备份字段时同步 `exportDataJson` / `importDataJson`、初始化逻辑、旧备份兼容和 `docs/dev/verifin-sample-backup.json`，并让测试真实导入样例备份。
- 第三方账单各自使用独立 parser，统一产出强类型 `RawImportRecord`；共享领域逻辑只放 `plan_builder.dart`。新增平台要同步枚举、注册表、parser、fixtures 和测试。
- 文件解析后不得直接落库，必须进入导入预览；预览/编辑全程零落库副作用，确认后才由 Controller 创建实际被引用的账户、分类、标签和交易。
- 不凭空编造第三方格式；解析规则必须来自真实样例，并覆盖编码、日期、金额符号、退款和账户余额等边界。

### AI 与 Android 集成

- AI 记账与截图/分享识账只产 `EntryDetailPage` 草稿，不得静默写账。截图原图留在设备，OCR 临时文件识别后删除；只有识别文本会发送到用户配置的端点。
- AI 查询工具输入 `AiToolContext` 快照，保持只读纯函数，不访问 Controller。新增工具要在 `buildAiQueryTools()` 注册，覆盖正常与非法参数测试，并同步 `docs/dev/ai-tools.md`。
- 新增原生能力放入 `platform_bridge.dart` 已有领域 Bridge，统一由单一 MethodChannel 处理器分发，不另挂互相覆盖的 handler。
- 通知、小组件、SAF、分享 Activity、应用更新等必须验证冷启动、前后台切换、进程被杀、重启/升级、Android 权限和 Doze 行为。涉及反射或 ML Kit 时必须验证 release/R8 构建；debug 正常不能替代。
- data URL 图片使用内存图片渲染，不使用 `Image.network`。
- Android 明确禁用系统 Auto Backup；外部分享图片必须分块读取并在累计超过 25 MB 时立即停止，禁止先完整 `readBytes()` 再检查大小。

## 测试规范

- 测试文件放在 `test/` 并以 `_test.dart` 结尾，按领域归类；优先复用 `test/support/test_harness.dart` 的 `makeController`、`pumpApp`、`zhMaterialApp` 和内存仓储。
- Widget 测试覆盖用户可见行为：渲染、点击、导航、表单校验、空态、错误反馈和持久化结果；纯计算覆盖边界、空输入、时区/日期和非法参数。
- SQLite 相关改动要运行 repository、controller persistence、migration matrix、model roundtrip 和 repository contract 测试；不要只依赖内存仓储。
- 修复 bug 必须补能在修复前失败的回归测试。导入 parser 使用真实 fixture，避免只测手工构造的理想输入。
- 功能改动完成后至少运行 `flutter analyze` 和 `flutter test`。Android/OCR/通知/文件/权限/R8 改动还要说明所需的 CI release APK 真机验收项。

## 文档、CHANGELOG 与交付

- 每次修改代码、功能、配置或流程，都检查 `README.md`、`AGENTS.md`、`CLAUDE.md` 和 `docs/` 是否需要同步；影响命令、架构、交付、配置、数据口径或用户行为时，必须在同一次变更中更新相关文档。
- 新增/改名共享组件更新 `docs/dev/components.md`；改变关键取舍更新 `docs/dev/tech-decisions.md`；新增已接受限制或调整阈值更新 `docs/dev/known-limitations.md`；AI 查询工具更新 `docs/dev/ai-tools.md`。
- 用户可见的新功能、交互变化、修复、隐私或安全变化要写入 `CHANGELOG.md` 顶部 `## [Unreleased]` 的对应小节。纯内部重构、测试或文档改动不写 CHANGELOG。
- UI 变化影响公开截图时检查 `docs/screenshots/`；功能完成标准变化时检查验收清单。
- 提交信息使用简短明确的 `type: summary`，如 `feat: add login screen`、`fix: correct counter test`。提交中不得出现 `Generated by`、`Co-authored-by` 等任何 AI/Codex 署名。
- 完成相对独立的功能并通过相应验证后及时提交，避免把多个已完成功能长期堆在工作区；不自行推送或发版。PR 说明变更、动机、测试结果、关联 issue，UI 改动附截图或录屏。

## 完成前检查清单

- 改动是否严格落在用户请求范围，且未覆盖无关工作树修改？
- 是否先查了对应组件、技术决策和领域文档，并复用了现有入口？
- 状态、SQLite/KV、备份/初始化、Android 真实现和进程重启语义是否一致？
- 新文案是否完成中英文 ARB；新 UI 是否符合页面骨架、设计令牌、弹窗和图标规范？
- 异常是否有 AppLogger 记录与用户反馈，异步 context 是否有 mounted 守卫？
- 是否补了针对性测试，并执行了与风险相称的 format/analyze/test/真机验证？
- 是否同步文档与 `CHANGELOG.md`（若用户可见）并在汇报中列出已运行和未运行的验证？
