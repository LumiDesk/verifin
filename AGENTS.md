# AGENTS.md

- 本项目为 **Flutter + Dart** 的 Android 记账应用（Veri Fin），仅交付 Android；Dart 包名 `verifin`，Android applicationId `top.talyra42.verifin`。
- 包管理器：**pub**（通过 `flutter pub get` / `flutter pub add` 使用）；不引入 npm/yarn/pnpm 等前端工具链。
- 样式方案：Flutter Material 3 + 项目自有设计令牌（`veri*` 颜色、`veriRadius*` 圆角、`VeriPage` / `VeriCard` / `VeriHeader` 页面骨架）；不使用 CSS，业务代码不硬编码颜色、圆角等视觉值，统一走设计令牌与主题。
- UI 组件库：Flutter Material 3 + `fl_chart`、`anchored_menu`、`home_widget`；本地 vendor `third_party/liquid_glass_widgets` 只用于可选的液态玻璃底栏。
- 工具链：Flutter 3.47.2（与 CI 固定版本一致）、Java 17+、Android SDK（含 NDK 与 CMake）；正式 APK/AAB 只由 CI 构建。

本仓库不启用 GitHub Pull Requests，不接受外部 PR。外部反馈只通过 Issue；代码改动由维护者在 Issue 确认范围后直接实施。

## 产品原则

- **本地优先、数据自主**：无账号、无自有服务端、无广告、无联网遥测。权威账目数据存于用户设备；只有用户主动启用的导出、WebDAV 备份或 AI 功能才会对外传输相应数据，WebDAV 不是账号云同步。
- **隐私优先**：AI 使用用户自己配置的 OpenAI 兼容端点。AI 记账只生成草稿，必须经用户确认后落账；AI 查询工具全部只读，绝不提供写数据能力。
- **不做监听类自动记账**：不注册通知监听、无障碍或短信监听。截图在端上 OCR，原图不上传；分享或 Intent 入口也只能生成待确认草稿。
- **Android 能力必须真实可用**：测试 stub 不能被当作生产实现。本地存储、图片、文件、通知、生物识别、安装包、桌面小组件或系统入口都要核对 Android 权限、持久化、进程重启和生命周期行为。

## Project Structure

```text
lib/
├── main.dart                 # 入口：绑定初始化、错误捕获与启动壳挂载；数据初始化在 lib/app/startup/
├── app/                      # 领域模型、Controller、主题、纯计算、通用组件、启动、备份、AI、提醒、日志与平台适配
│   ├── models/               # 领域模型与 JSON 映射；models.dart 是稳定 barrel
│   ├── backup/               # 备份/恢复编解码与账单导入 parser
│   ├── ai/                   # AI 会话、协议轮次与只读查询工具
│   ├── logging/              # AppLogger
│   ├── startup/              # 启动壳、阶段协调、单阶段看门狗与启动早期错误缓冲
│   └── widgets/              # 桌面小组件词表、投影、实例配置与刷新管线
├── pages/                    # 页面层；共享弹窗入口在 pages/sheets.dart
├── data/                     # AppDatabase、LedgerRepository、SqliteLedgerRepository
├── local_storage/            # 偏好类 KV（Android SharedPreferences；测试内存 stub）
├── l10n/                     # 中英文 ARB 与已提交的 gen-l10n 生成文件
└── common_widgets.dart       # 通用组件稳定入口，具体实现按 part 拆分

android/                      # 原生桥、Manifest、flavor、桌面小组件、快捷磁贴、分享入口与发布配置
assets/                       # 品牌、账户图标、AI 渠道 Logo 等包内静态资源
test/                         # 单元/widget/ffi SQLite/迁移/契约测试；共享脚手架 test/support/
integration_test/             # 设备侧冒烟与帧耗时采样（不进 CI）
scripts/                      # Dart 任务脚本（doctor/publish/prune/clean/widget_previews）
docs/                         # 产品、设计、开发文档与测试样例
third_party/                  # 本地 vendor 源码（jdenticon_dart、liquid_glass_widgets）
```

### 状态与数据流

- 应用权威状态集中在 `VeriFinController`（`ChangeNotifier`），经 `VeriFinScope`（`InheritedNotifier`）注入；不使用 Provider、Riverpod 或 Bloc。
- Controller 物理拆为 `veri_fin_controller.dart`、`veri_fin_controller_state.dart`、`veri_fin_controller_ops.dart`；`VeriFinController.create()` 是生产异步创建入口。
- UI 只调用 Controller 的公共读取/操作 API，不直接访问 repository、SQLite 或 KV；Controller 内部再经 `_persistX` 等路径持久化。
- 账本、交易、账户、分组、分类、标签、附件、周期规则和预算等核心数据只认 SQLite。Controller 的内存集合是运行时读取源，不存在 KV 回退。
- `LedgerRepository.saveX` 的对外语义是“落库后该表内容等于传入集合”。生产实现把“读取行快照、计算 `_incrementalReplace` 差分、事务写入、更新快照”整体串行化；单次失败不得阻塞后续写。附件表只存元数据，但**所有写路径（含 `replaceAllLedgerData` 整账本重建）都必须保留未迁移行的 `data_url`**，否则会静默丢掉用户还没转换的图片。导入、恢复、重置、删账本及跨表删除走 `replaceAllLedgerData` 原子整替；显式删除命令落库成功后才替换 Controller 内存。
- 冷启动的附件读取只允许取元数据列（`id/entry_id/sort_order/mime_type/byte_size`），**不得整列取回 `data_url`**：旧库里它可能内嵌几十~上百 MB base64，整列读回即 OOM；旧字节只经 `loadAttachmentDataUrl(id)` 逐条读，迁移完成后由 `dropLegacyAttachmentData()` 去列并 VACUUM。
- 主题、语言、触感、面板配置、备份设置、AI 配置等偏好类小数据走 `LocalKeyValueStore`。新增偏好优先参考主题/语言的独立 `ValueNotifier`，避免继续扩大全树 `notifyListeners()`。
- 只维护 Android；保留生产原生实现与测试注入/stub 边界，禁止重新引入浏览器适配。真实存储、图片、文件能力不得落到测试 stub。

## 文档地图

判断“当前实现事实”时按以下顺序取信，冲突时前者覆盖后者：

1. **源码、测试、Gradle、CI 工作流与发布脚本**——唯一事实来源。
2. `AGENTS.md`——执行规范：改动流程与必须遵守的规则。
3. `docs/design/design-system.md`、`docs/design/ui-guidelines.md`、`docs/design/components.md`——界面、交互与组件规范。
4. `docs/dev/tech-decisions.md`、`docs/dev/known-limitations.md`——已决策取舍与已接受限制。

文档按职能分目录：

- `docs/dev/architecture.md`：架构、源码导航与分层；`CLAUDE.md` 只链接 `AGENTS.md`，不维护第二份规范。
- `docs/design/design-system.md`：统一排版、表面材质、设置持久化与验收约定；界面调整必读。
- `docs/design/components.md`：组件、弹窗、格式化与纯函数注册表；写任何 Widget、弹窗、对话框、格式化或计算前先查。
- `docs/design/ui-guidelines.md`：页面骨架、交互、图表和视觉规范；新增根导航样式前先读「根导航」小节及其契约测试清单。
- `docs/dev/tech-decisions.md`：数据口径、备份范围和关键技术取舍；判断当前实现仍以源码、测试与工作流为准。
- `docs/dev/known-limitations.md`：已接受的限制、技术债及触发整改的阈值。
- `docs/dev/android-development.md`：工具链检测与安装、真机调试、日志、隔离验收及测试应用清理。
- 领域文档：`docs/dev/attachment-storage-and-backup.md`、`docs/dev/refund.md`、`docs/dev/multi-currency.md`、`docs/dev/entry-save-validation.md`、`docs/dev/category-budget-override.md`、`docs/dev/ai-tools.md`、`docs/dev/ai-provider-presets.md`、`docs/dev/auto-capture.md`、`docs/dev/i18n-verification.md`、`docs/dev/feedback-system.md`、`docs/dev/home-widgets.md`、`docs/dev/anchored-menu.md`、`docs/dev/account-icon-assets.md`。
- 产品与样例：`docs/product/product.md`、`docs/product/acceptance-checklist.md`、`docs/product/automation.md`、`docs/fixtures/`、`docs/screenshots/`；仓库级说明见 `README.md`、`CONTRIBUTING.md`、`CHANGELOG.md`。维护约定与已确认的 Code Review 取舍见 `CONTRIBUTING.md`。

**不保留过程记录。** `docs/` 只陈述**当前状态**：规范、口径、契约、验收清单、样例数据。方案草稿、实施计划、评审记录、决策过程、迁移中间态一律不进仓库——完成时把仍然有效的结论并入对应规范（界面交互进 `docs/design/`，技术取舍进 `docs/dev/tech-decisions.md`，领域口径进 `docs/dev/`），其余删除。`docs/dev/tech-decisions.md` 的「UI 组件库选型」等行就是被否决库的唯一记录，不要另建选型或规划文档。

- 与用户沟通、说明方案和汇报结果时使用中文；代码符号、命令和提交类型保留英文。
- 改动聚焦用户请求，不顺手重构无关代码，不覆盖用户已有修改；开始任务前先确认工作树状态。
- 判断文档与实现不一致时，以源码、测试、Gradle、工作流和发布脚本为准，核实 git 历史后同步修正文档；本文的规范性规则仍必须遵守，已有违规实现不构成可复制的先例。
- **文档与提交的配置不得包含个人机器信息**：本机绝对路径、用户名、设备序列号、SDK/JDK 安装路径和环境变量值都不入库；需要举例时用 `<flutter-sdk>`、`<android-sdk>`、`<device-id>` 等占位符。`android/local.properties` 由 Flutter 维护且不提交。

## Coding Style

### Dart 与依赖

- 遵循 Dart 默认格式和 `analysis_options.yaml` 的 `flutter_lints` 及额外正确性 lint；使用两个空格缩进。
- 文件用 `snake_case.dart`，类/枚举/Widget 用 `UpperCamelCase`，变量与方法用 `lowerCamelCase`，私有成员加 `_`。
- 正确处理 Future；不要为了绕过 `unawaited_futures` 随意丢弃异步操作。确需后台执行时使用明确的 `unawaited(...)` 并保证错误被记录和反馈。
- 不滥用 `dynamic`；能用具体类型、密封类或模式匹配表达的状态不要退化成动态类型。
- 不使用 `print` / `debugPrint` 作为生产日志，不写无注释的 lint ignore。
- 不为简单需求引入额外依赖或工具链。新增依赖前评估 APK 体积、Android/R8、隐私、维护成本和已有纯 Dart 实现。
- 不重写 Flutter 生成的平台工程文件，除非任务明确要求；修改 `android/` 时只动与需求直接相关的原生实现或配置。

### 组件与设计令牌

- 写任何 Widget、弹窗、对话框、格式化或计算前，先查 `docs/design/components.md`。命中现成件就复用或参数化扩展，不复制脚手架、不新建同构变体。
- 同一 UI 片段或逻辑在两个及以上文件出现时，抽为共享件：通用组件放 `common_widgets.dart`，弹窗 helper 放 `sheets.dart`，记账组件放 `entry_sheets.dart`，纯计算放对应 `*_math` / `*_tree` / 领域模块。新增、重命名或删除可复用件时同步组件清单。
- 标准页面骨架使用 `Scaffold > SafeArea > VeriPage`，列表页面外层 `ListView` 采用统一头部 padding，并使用 `VeriHeader` / `PageHeader`；固定页脚页面单独给头部相同 padding。细节以 `docs/design/ui-guidelines.md` 为准。
- 分类图标只用 `CategoryIconBox` / `CategoryGlyph`，账户图标只用 `AccountIconBox`。渲染点禁止直接调用 `iconForCode`，否则 emoji 分类会回退钱包图标。
- Row 内“居中列 label + value [+ detail]”的标准指标块使用 `SummaryMetric`。明显不同的卡片/排行可保留局部组件，不把一个组件过度参数化成配置怪物。
- 图表优先复用 `InteractiveTrendChart` / `InteractiveBarChart`，必须支持点按或滑动查看数据；位于可跳转卡片内时，图表区域要拦截点击，避免误触卡片跳转。
- 应用内短反馈只用 `VeriFeedbackHost.of(context)` / 根级 `VeriFeedbackController`，不得新增旧式 Material 横条提示或 Android Toast。破坏性确认、字段校验、阻塞进度和系统通知不迁入轻提示；完整规则见 `docs/dev/feedback-system.md`。
- 根导航的当前约定见 `docs/design/components.md` 的 `VeriRootNavigationStyle`、`VeriDockedRootNavigationStyle` 与 `VeriLiquidGlassRootNavigationStyle` 条目（默认停靠样式 + 可选液态玻璃样式，样式选择页见 `NavigationStyleSettingsPage`），底栏绘制组件见 `VeriBottomBar` 条目；新增样式前先读 `docs/design/ui-guidelines.md` 的「根导航」小节与其硬约束、契约测试清单。
- 材质：卡片、导航、快捷按钮、菜单与弹层一律使用**不透明实色**表面，页面背景为单一纯色。唯一例外是底部导航的**可选液态玻璃样式**：应用侧只允许在 `root_navigation_liquid_glass.dart` 中适配本地 vendor 的 `third_party/liquid_glass_widgets`（`GlassTabBar.bottom`），`main.dart` 只负责库初始化和主题亮度桥接；第三方玻璃代码不得扩散到卡片、菜单、弹层或页面背景。其余位置禁止背景模糊、折射、片元着色器滤镜或整屏渐变。
- 发布包外观：已评审的统一排版（16dp 有效页边距、56dp Header、16dp 卡片圆角、14/12 卡片内边距）是当前**唯一**外观，本地构建与发布包一致。统一排版覆盖全部页面；导航静止必须显示实时文字，预算环禁止内外白线。
- 颜色使用 `veri*` 常量，圆角使用 `veriRadius*`，主色为 `veriRoyal`（`#346edb`）。禁止裸写 `Color(0x...)` 或魔法圆角；确有局部特例时写明原因。语义色（收入 / 支出 / 转账 / 提醒）必须经 `veriSemantic(context, veriX)` 取用（无 `BuildContext` 的纯函数用 `veriSemanticFor(brightness, veriX)`），不要直接渲染亮色常量，否则浅色主题对比度不达 AA。
- 金额颜色只用 `colorForType` / `accountBalanceColor`；金额文本只用 `formatAmount` / `formatSignedAmount` / `formatCompactAmount` 等现有 helper。金额为零必须是中性色 `0`，不能显示 `-0`。
- 日期和月份使用 l10n 的 `dateMonthDay` / `yearMonth` 等格式，不能手拼用户可见日期字符串。
- **日历日算术禁止裸用绝对时长**：相隔天数用 `calendarDaysBetween`，推前/推后 N 天用 `addCalendarDays`。不要用 `difference().inDays` 或 `add(Duration(days: n))` 表达日历日；夏令时地区一天可能是 23/25 小时，这类 bug 在 UTC/中国时区 CI 中不会显现。秒、小时等真实时间间隔仍使用 `Duration`。

### 弹窗与输入

- 页面不得裸写 `showModalBottomSheet`；由顶层 `show<名>Sheet` helper 统一封装 chrome。确认框用 `showConfirmDialog`，文本输入用 `showTextInputDialog`；2–8 项静态受控单选用外部库的 `AnchoredMenuChoice<T>`，动态、较长或需分区的简单单选用 `showOptionSheet`；金额用数字键盘，分类/账户用各自选择器。
- 禁止复制内联两按钮 `AlertDialog`。破坏性确认使用 `showConfirmDialog(..., destructive: true)`。
- 取消/未选统一返回 `null`；“全部”“顶级”“无账户”等特殊选项使用集中定义、带注释的命名哨兵，不在调用点散写魔法字符串或 id。
- 新增 helper 必须把 `BuildContext` 设计为具名 `context:`；改造既有 helper 时若迁移签名，必须同步全部调用点。不要声称现有 helper 已全部完成统一。
- 触感偏好由 helper 内部从 `VeriFinScope` 获取，调用方不重复传递。

### 国际化

- 新增用户可见文案必须同时写入 `lib/l10n/app_zh.arb`（模板）和 `app_en.arb`，经 `AppLocalizations.of(context)` 使用；不要手改生成的 `app_localizations*.dart`。
- 枚举显示名使用 `label(AppLocalizations)`；无 `BuildContext` 场景使用 `l10nForPreference`，随当前语言偏好解析。
- 日期/时间选择器与系统集成文案应随当前 app locale，不得硬编码只支持中文。
- 既定豁免仅包括法律正文、银行/品牌专名、CSV 固定表头与逐行导入错误、少量无 context 的网络/桥接错误；新增豁免前先确认确实无法本地化。
- 种子账本/分类按首启动语言生成，写入后属于用户数据；切换语言不得自动重命名。

### 异步、错误与日志

- 任何 `await` 后再次使用 `BuildContext` 前，先检查 `if (!mounted) return;` 或 `if (!context.mounted) return;`。
- 捕获异常后只有两种合格处理：使用 `AppLogger` 记录并给用户可见反馈；或明确注释这是可接受的降级及静默原因。禁止空 `catch (_) {}`。
- backup、import、AI、WebDAV、数据库、平台桥等易错路径必须记录隐私友好的结构化日志；不得把 API Key、口令、完整账目或敏感原文写进日志。
- 持久化失败不能只记录后继续假装成功；要让用户知道保存失败，并保持内存/磁盘状态可解释。

### 数据、备份与导入

- 修改 SQLite 表结构必须同时：提升 `AppDatabase.schemaVersion`；同步 `_schemaCurrent`；在 `_migrations` 注册“升到 vN”的新迁移段，禁止回改已发布的历史迁移；更新 `test/migration_matrix_test.dart`，确保每个历史版本都能升级到当前结构。
- 模型新增/改字段时同步检查 `toJson`、`fromJson`、`toRow`、`fromRow` 四向映射，并更新 `test/model_roundtrip_test.dart`。
- 修改 `LedgerRepository` 契约或 save 语义时，让 `test/repository_contract_test.dart` 对内存与 SQLite 两种实现的同一套断言都通过。
- 新增本地数据必须明确并测试：默认值、持久化、冷启动读取、删除实体时清引用、初始化语义、导出/导入及旧备份兼容。
- `BackupService` 是字节格式编解码唯一入口；Controller 只接收/产出明文 JSON。未加密备份为 zip（`backup.json` + 独立附件），新版加密备份为流式加密容器（`.verifin`，密文里是同一个 zip），旧版 JSON 信封仍可读取导入；不要在 UI/Controller 复制格式判定。
- 哪些数据进备份、哪些仅设备本地，必须以当前 `exportDataJson` / `importDataJson`、备份测试和实际字段共同核验，并同步维护 `docs/dev/tech-decisions.md` 的“备份范围”表。应用锁、备份口令、WebDAV 凭证、AI Key 等机密不得进入备份。
- 改备份字段时同步 `exportDataJson` / `importDataJson`、初始化逻辑、旧备份兼容和 `docs/fixtures/sample-backup.json`，并让测试真实导入样例备份。
- 恢复外部备份文件必须用应用自带的 SAF 选择器（原生 `pickBackupFile` / `BackupService.chooseBackupFile`），**不要用 `file_selector` 读备份**：它会把整份文件读进内存、经平台通道整包传一份、再复制一份到缓存，GB 级必然 OOM；而且它返回的是普通文件路径，不是 `content://` URI。只删除本应用为本次导入新建的临时副本（`StagedCacheFile.owned`）。
- 第三方账单各自使用独立 parser，统一产出强类型 `RawImportRecord`；共享领域逻辑只放 `plan_builder.dart`。新增平台要同步枚举、注册表、parser、fixtures 和测试。
- 文件解析后不得直接落库，必须进入导入预览；预览/编辑全程零落库副作用，确认后才由 Controller 创建实际被引用的账户、分类、标签和交易。
- 不凭空编造第三方格式；解析规则必须来自真实样例，并覆盖编码、日期、金额符号、退款和账户余额等边界。

### AI 与 Android

- AI 记账与截图/分享识账只产 `EntryDetailPage` 草稿，不得静默写账。截图原图留在设备，OCR 临时文件识别后删除；只有识别文本会发送到用户配置的端点。
- AI 查询工具输入 `AiToolContext` 快照，保持只读纯函数，不访问 Controller。新增工具要在 `buildAiQueryTools()` 注册，覆盖正常与非法参数测试，并同步 `docs/dev/ai-tools.md`。
- 新增原生能力放入 `platform_bridge.dart` 已有领域 Bridge，统一由单一 MethodChannel 处理器分发，不另挂互相覆盖的 handler。
- 通知、小组件、SAF、分享 Activity、应用更新等必须验证冷启动、前后台切换、进程被杀、重启/升级、Android 权限和 Doze 行为。涉及反射或 ML Kit 时必须验证 release/R8 构建；debug 正常不能替代。
- data URL 图片使用内存图片渲染，不使用 `Image.network`。
- Android 明确禁用系统 Auto Backup；外部分享图片必须分块读取并在累计超过 25 MB 时立即停止，禁止先完整 `readBytes()` 再检查大小。

### 测试

- 测试文件放在 `test/` 并以 `_test.dart` 结尾，按领域归类；优先复用 `test/support/test_harness.dart` 的 `makeController`、`pumpApp`、`zhMaterialApp` 和内存仓储。
- Widget 测试覆盖用户可见行为：渲染、点击、导航、表单校验、空态、错误反馈和持久化结果；纯计算覆盖边界、空输入、时区/日期和非法参数。
- SQLite 相关改动要运行 repository、controller persistence、migration matrix、model roundtrip 和 repository contract 测试；不要只依赖内存仓储。
- 修复 bug 必须补能在修复前失败的回归测试。导入 parser 使用真实 fixture，避免只测手工构造的理想输入。
- 功能改动完成后至少运行 `flutter analyze` 和 `flutter test`。Android/OCR/通知/文件/权限/R8 改动还要说明所需的 CI release APK 真机验收项。

## Build Commands

```bash
flutter pub get
flutter run -d <device-id> --flavor diagnostic
flutter build apk --debug --flavor diagnostic
dart run scripts/doctor.dart --devices
dart format .
flutter analyze
flutter test
flutter test test/entries_test.dart
flutter test --plain-name "关键字"
flutter test integration_test/ -d <device-id> --flavor diagnostic
dart run scripts/widget_previews.dart
```

### 日常开发

- 日常调试使用独立 `diagnostic` flavor 运行正式入口做 hot reload，避免覆盖用户账目；`diagnostic` 使用独立 applicationId 与正式数据隔离，可以运行 `lib/main.dart` 或最小绘制入口，但**不是交付物**。
- 验证 GitHub 渠道、自更新或正式包外观时使用 `--flavor github`；验证 Play 渠道时使用 `--flavor play --dart-define=SELF_UPDATE=false`。所有构建都显式带 flavor。桌面 widget 测试不能替代 Android 原生能力、生命周期和性能验收。
- 不再维护 Web 预览、WASM 或浏览器测试；不要创建独立演示 UI。布局测试保留 393×852 与窄屏尺寸；视觉迭代保留首页预算圆环、支出/剩余日均、概览指标方块和“我的”四列宫格。
- 手机开发前先按 `docs/dev/android-development.md` 检测 Flutter（与 CI 固定版本一致）、Java、Android SDK、adb 与 `local.properties`。缺工具时优先复用已安装版本；**需要安装或升级会改动现有 SDK/JDK/PATH 的，先说明影响并取得用户同意**，安装后复检。权限、下载或手机授权实际受阻时才请求用户处理。
- **Android 构建的 NDK/CMake 前置**：Flutter 3.47 的 Gradle 插件会强制使用 NDK `28.2.13676358`；AGP 9 默认使用 CMake `3.22.1`。构建前确认 `<android-sdk>/ndk/28.2.13676358/source.properties` 与 `<android-sdk>/cmake/3.22.1/bin/cmake.exe` 存在。`cmdline-tools` 23 已弃用 `sdkmanager`，不要依赖 Flutter 的自动 NDK 安装；用 Android Studio SDK Manager 或 `android sdk install` 安装。
- 提交前执行 `dart format .`、`flutter analyze` 和 `flutter test`。只改文档时至少做 `git diff --check`、链接和路径校验，可不运行 Flutter 测试，但要在汇报中说明。
- 不把本地 `flutter build apk` 当成交付依据；正式 APK/AAB 由 GitHub Actions 构建。

### CI 与发版

- `.github/workflows/ci.yml` 在每次 push 到 `main` 时执行格式检查、analyze、全量测试和 `github` flavor Android debug APK 编译门禁；该 APK 只用于提前发现 Kotlin/Manifest/原生桥编译错误，不作为交付物。
- `.github/workflows/flutter.yml` 只在推送 `vX.Y.Z` 标签时触发发布构建：
  - GitHub 自分发：arm64-v8a APK，`--flavor github --split-per-abi`；必须保持 `force-version-code-ignoring-abi=true`，否则 ABI 版本号偏移会破坏 GitHub / Play 渠道间的覆盖升级。
  - Google Play：AAB，`--flavor play --dart-define=SELF_UPDATE=false`。
- 两种 release 都开启 R8 代码压缩与资源裁剪。新增依赖若使用反射，必须同步检查 `android/app/proguard-rules.pro`；OCR、通知等问题可能只在 release/R8 下暴露。
- `play` flavor 移除 `REQUEST_INSTALL_PACKAGES` 和 `USE_EXACT_ALARM`，保留可申请的 `SCHEDULE_EXACT_ALARM` 并在无授权时回退；自更新入口通过 `kSelfUpdateEnabled` 隐藏。渠道差异放在 flavor Manifest 或构建开关中表达。
- CI 创建 GitHub **预发布**且不标记 Latest；真机验收通过后再由维护者手动提升为正式版。Release 使用项目内稳定 keystore；不要替换、重生成或泄露签名材料。

**发版必须得到用户明确授权。** 打标签会推送远端并触发 CI，不能自行执行。实际顺序如下：

1. 先跑 `dart run scripts/doctor.dart` 确认环境（Flutter 版本必须等于 CI 固定版本、Android SDK/JDK 可用、工作树干净）。
2. 确定版本号与日期，把 `CHANGELOG.md` 顶部 `## [Unreleased]` 提升为本次版本，并在其上新建空的 `## [Unreleased]`。`CHANGELOG.md` 只保留未发布改动与最近一个次版本线；更早版本的**源码归档以 git 标签为准**，不再回填。
3. 提交 CHANGELOG 变更，确认当前分支是 `main` 且工作树完全干净。
4. 运行发布脚本，参数可取 `patch`、`minor`、`major` 或显式版本号（如 `1.2.3`）：`dart run scripts/publish.dart patch`。脚本会再次校验「本机 Flutter 版本 == CI 固定版本」，不一致直接失败（analyzer 的 lint 集合随版本变化，本地绿不代表 CI 绿）；`--dry-run` 只打印将要执行的步骤。
5. 脚本更新 `pubspec.yaml` 与 `lib/app/app_version.dart`，执行格式化、依赖安装、analyze、test，创建 `chore: release vX.Y.Z` 提交、标签并推送；推送标签触发 CI 构建 APK/AAB 并创建 GitHub **预发布**（不标记 Latest）。
6. 下载 CI 生成的预发布 APK 真机验收；通过后在 GitHub 上把该 Release **提升为正式版并标记 Latest**（`prerelease` 去掉）。
7. 清理没被提升的预发布（见下）。

**Release 标题与说明（规范）：**

- **标题固定等于标签名**：`vX.Y.Z`，不加中文摘要等后缀。CI 建预发布时使用标签名，提升为正式版时不再改标题。
- **说明正文由 `CHANGELOG.md` 的对应版本段落自动生成**，模板在 `.github/workflows/flutter.yml` 的 `Compose release notes` 步骤里，只补固定文案：预发布时期的验收提示、「直接覆盖安装 + 更新前先备份」提示。
- **不写安装包自身的说明**：架构 / ABI / 体积 / 机型限制属于构建与分发口径，只记在 `README.md` 与 `docs/dev/tech-decisions.md`，不进 Release 说明。
- 提升为正式版：`gh release edit vX.Y.Z --prerelease=false --latest`（不动 git 标签与附件），完成后回读 `gh release view` / `gh release list` 确认 `isPrerelease=false` 且 Latest 已指向它。

### 版本归档与预发布清理

- GitHub Releases 只保留**正式版**（推荐 Latest 指向最新正式版）；预发布只是「待真机验收」的临时状态，验收通过就应该提升为正式版，而不是长期留存。
- **git 标签是版本源码的唯一归档**：即使清掉了某个预发布的 Release 页面，也不要删除它的标签——发布脚本会拒绝复用已存在的标签，标签也是旧版本唯一的源码定位方式。Release 页面可以删，标签不要删。
- 清理命令：`dart run scripts/prune_prereleases.dart --dry-run` 先核对列表，再去掉 `--dry-run` 执行（默认保留 git 标签）。只有在确认某个标签确实不再需要时才加 `--cleanup-tag`。

### 脚本

- `scripts/` 下的任务脚本一律用 **Dart** 实现（`dart run scripts/<name>.dart`），不再维护 `.sh` / `.ps1` 双份：Dart 是本项目必然存在的运行时，跨平台只有一份实现，且 `dart format` 与 `flutter analyze` 会把脚本一起纳入质量门禁。
- 纯逻辑放 `scripts/src/`（可被 `test/` 直接单测，如 `test/scripts_version_test.dart`），入口脚本只做编排；脚本依赖只加 `dev_dependencies`，不得影响 APK。
- 现有脚本：`doctor.dart`（环境自检：Flutter 版本对齐 CI、Android SDK/JDK/adb/gh、工作树）、`publish.dart`（发版）、`prune_prereleases.dart`（清理预发布）、`clean.dart`（清理构建产物）、`widget_previews.dart`（在设备上重导出桌面组件的选择器预览 PNG，改组件视觉后必须重跑）。

## 领域约束

- 多账本数据按 `bookId` 隔离；切换账本不能泄漏账户、交易、分类、标签、预算或排序偏好。**分类与标签是账本内数据**（跟着账本走，不是「跟着应用」）：新建账本播种一份内置默认分类，各账本的分类/标签互不共享，改名、换图标、移动、合并、删除、排序与笔数统计都只作用于当前账本。只有软件设置与用户偏好（主题、语言、导航样式、触感、数字键盘布局、AI 配置、提醒、应用锁）才是设备级数据。**读取口（`categories` / `tags` / `categoriesForType` / `tagById` 等）只返回当前账本，而落库语义是整表覆盖——写入路径必须用私有的全量列表（`_persistCategories`、`saveCategoryOrderDraft` 等），绝不能把过滤后的列表回传当作「整表保存」**，否则会静默删掉其它账本的分类/标签。交易与退款只允许引用本账本里**已存在**的分类与标签（写入守卫 `EntryValidationCode.categoryOutOfScope` / `tagOutOfScope`）；载入与导入自愈（`_healCategoryData` / `_healTagData`）会摘掉悬空或跨账本的标签引用，跨账本读取一律显式走 `categoriesForBook` / `tagsForBook`。
- 分类是邻接表树，**id 一律随机生成、不承载语义**：需要识别「某条分类是什么」的地方一律比较 `Category.key`（默认分类/系统分类/「未分类」兜底，见 `lib/app/models/category_keys.dart`），不要解析或硬编码 id。创建路径须按 `normalizedCategoryLabel` 在**同一账本内**查重复用；不得绕过唯一约束。未知或悬空分类不能回退列表首项，载入/导入后的自愈约定见 `docs/dev/tech-decisions.md`。
- `LedgerEntry.accountId == ''` 表示“无账户”。展示名称用 `accountDisplayName`；不要用会回退首账户的 `accountById` 解释空 id。
- 账户能力只通过 `supportsCardLast4`、`supportsCredit` 判断，禁止散落硬编码账户类型。`cardLast4Follows` 是持久化字段，不能从卡号和后四位反推用户选择。
- 转账不计入收支，手续费由转出账户承担；转账分类不得留空。
- 退款是关联原支出的独立条目；只有已到账退款影响余额和净额，原支出的 `refundedBaseAmount` 是已到账退款 `baseAmount` 之和的派生缓存。修改退款逻辑前必须阅读 `docs/dev/refund.md` 和 `docs/dev/multi-currency.md` 并以当前代码/测试为准。
- 自定义预算周期只改变预算体系口径，统计报表仍按自然月。默认预算使用哨兵键，单月覆盖优先于默认值。
- 「不计入预算」标记（借款、垫付等）只脱离**预算**口径。预算取数一律走 `ledger_math.dart` 的 `budgetExpenseTotal` / `countsTowardBudget`（预算总览、首页与看板预算卡、按日预算、预算趋势、桌面小组件预算、AI `budgetStatus`）；收支统计、账户余额、报表与分类统计仍走 `sumByType` / `signedAmount`，**不读该标记**。新增预算取数不要在调用点手写过滤条件。

## Never 规则

- Never 在 UI 里直接访问 repository、SQLite 或 KV；只通过 Controller 的公共 API。
- Never 把账本、交易、账户、分类、标签、预算等账目数据存进 KV；KV 只放偏好。
- Never 把按当前账本过滤后的分类/标签列表当作“整表保存”回传，否则会删掉其它账本的数据。
- Never 用分类 id 表达语义、解析 id 或回退列表首项；需要识别分类时比较 `Category.key`。
- Never 用 `accountById` 解释空 `accountId`；展示用 `accountDisplayName`，能力判断用 `supportsCardLast4` / `supportsCredit`。
- Never 让转账计入收支、让手续费脱离转出账户，或把转账分类留空。
- Never 让未到账退款影响余额/净额；`refundedBaseAmount` 只能从已到账退款派生。
- Never 在预算取数处手写过滤条件；统一用 `budgetExpenseTotal` / `countsTowardBudget`，统计口径不要读 `excludedFromBudget`。
- Never 修改 SQLite 结构却不升 `schemaVersion`、不写新迁移段、不改迁移矩阵；Never 回改已发布的历史迁移。
- Never 整列读取 `data_url`，或在任何整表写入中丢掉未迁移行的 `data_url`。
- Never 把应用锁、备份口令、WebDAV 凭证、AI Key 或完整账目写进备份/日志；签名材料是已确认的仓库例外，不要替换或额外扩散。
- Never 用 `file_selector` 读备份；恢复必须走自带 SAF 选择器，且只删本应用创建的暂存副本。
- Never 让导入在预览确认前落库；Never 凭空编造第三方账单格式，parser 必须基于真实样例。
- Never 复制内联弹窗/确认框脚手架，或裸写 `showModalBottomSheet`；用 `sheets.dart` / `entry_sheets.dart` 的 helper。
- Never 硬编码 `Color(0x...)`、魔法圆角或语义色常量；用 `veri*` 令牌和 `veriSemantic` / `veriSemanticFor`。
- Never 手拼金额或用户可见日期；用现有格式化 helper。Never 用 `difference().inDays` / `add(Duration(days: n))` 表达日历日。
- Never 在渲染路径执行 I/O、解析、全量排序/过滤或创建大对象；Never 给可重排/可删除列表用 index 当 key。
- Never 用 `print` / `debugPrint` 作为生产日志，Never 空 `catch (_) {}`；`await` 后使用 `BuildContext` 前必须有 mounted 守卫。
- Never 手改生成的 `app_localizations*.dart`；文案改动只写 ARB。
- Never 对 data URL 图片使用 `Image.network`；Never 先完整 `readBytes()` 再检查分享图片大小（>25 MB 必须立即停止）。
- Never 注册通知监听、无障碍或短信监听；Never 让 AI 静默写账或给查询工具写数据能力。
- Never 把测试 stub/内存仓储当作生产实现；真实存储、图片、文件能力必须在 Android 上落地。
- Never 手改 `pubspec.lock`，Never 为简单需求随意引入依赖或工具链；依赖变更用 `flutter pub get/add`。
- Never 修改 `build/`、`.dart_tool/`、`.flutter-plugins-dependencies` 或 Flutter 生成文件；它们由工具重建。
- Never 在提交的文档/配置里写本机绝对路径、用户名、设备序列号、SDK/JDK 路径或环境变量值；用 `<flutter-sdk>`、`<android-sdk>`、`<device-id>` 等占位符。
- Never 在 `docs/` 保留方案草稿、实施计划、评审记录或迁移中间态；只写当前状态。
- Never 未经用户明确授权 push、打标签或发版；Never 替换/重生成签名材料。
- Never 在提交信息或代码里添加 `Generated by`、`Co-authored-by` 等 AI/Codex 署名。

## Commit 规范

- 格式：`type: summary`（如 `feat: add login screen`、`fix: correct counter test`）；必要时可用 `type(scope): summary`，但以简短明确为准。
- 类型：`feat` / `fix` / `docs` / `style` / `refactor` / `test` / `chore`。
- 提交信息只写做了什么，不写 `Generated by`、`Co-authored-by` 等 AI/Codex 署名。
- 完成相对独立的功能并通过相应验证后及时提交；不把多个已完成功能长期堆在工作区，不覆盖用户已有修改。
- 不自行推送或发版。交付说明应包含变更、动机、测试结果、关联 Issue；UI 改动附截图或录屏。
- 代码、功能、配置或流程变更必须在**同一提交**中校准 `README.md`、`AGENTS.md`、`CLAUDE.md` 与 `docs/`：
  - 新增/改名共享组件更新 `docs/design/components.md`；
  - 改变关键取舍更新 `docs/dev/tech-decisions.md`；
  - 新增/调整已接受限制更新 `docs/dev/known-limitations.md`；
  - AI 查询工具更新 `docs/dev/ai-tools.md`；AI 渠道/模型发现更新 `docs/dev/ai-provider-presets.md`。
- 用户可见的新功能、交互变化、修复、隐私或安全变化写入 `CHANGELOG.md` 顶部 `## [Unreleased]`；纯内部重构、测试或文档改动不写 CHANGELOG。
- UI 变化影响公开截图时检查 `docs/screenshots/`；功能完成标准变化时检查 `docs/product/acceptance-checklist.md`。
- `README.md`、`AGENTS.md`、`CLAUDE.md`、`CONTRIBUTING.md`、`CHANGELOG.md`、`docs/` 与 `.github/` 下的模板/工作流由维护者维护；外部贡献只通过 Issue，不接受外部代码补丁。外部贡献不得借需求讨论修改治理或技术决策文档。

## 完成前检查

- 改动是否严格落在用户请求范围，且未覆盖无关工作树修改？
- 是否先查了对应组件、技术决策和领域文档，并复用了现有入口？
- 状态、SQLite/KV、备份/初始化、Android 真实现和进程重启语义是否一致？
- 新文案是否完成中英文 ARB；新 UI 是否符合页面骨架、设计令牌、弹窗和图标规范？
- 异常是否有 AppLogger 记录与用户反馈，异步 context 是否有 mounted 守卫？
- 是否补了针对性测试，并执行了与风险相称的 format/analyze/test/真机验证？
- 维护者/Agent 是否同步文档与 `CHANGELOG.md`（若用户可见），并在汇报中列出已运行和未运行的验证？
- 提交内容是否不含本机路径、用户名、设备序列号或环境变量值？
