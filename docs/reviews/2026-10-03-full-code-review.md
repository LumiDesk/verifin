# Veri Fin 全面 Code Review（2026-10-03）

> 本轮只做调研与记录，不修改产品代码。
> 基线：`main` / `d285c46`，工作树在审查前后均保持干净。
> 审查对象：Flutter/Dart、Android 原生桥与 Manifest、桌面小组件、备份/WebDAV/导入、统计/预算、AI、页面与共享组件、测试和 CI。

## 结论先说

项目的业务模型和测试基础明显成熟：SQLite 权威存储、迁移矩阵、仓储契约、多币种三层金额、退款关联模型、导入预览、AI 只读/待确认边界，以及统一页面组件都已经形成体系。源码静态质量较好，默认分析和全量测试均通过。

本轮仍发现 **2 个应在任何正式发布前处理的阻断项**，以及 **8 个高优先级问题、5 个中优先级问题**。最重要的不是页面缺功能，而是发布供应链、远端备份输入边界、加密文件防御和 Android 真机验证尚未达到“可放心交付”的程度。

维护者在 2026-10-03 明确接受 P0-1（签名材料入库）与 P0-2（GitHub Actions 信任边界）作为产品/供应链取舍；它们已记录在 [AGENTS.md](../../AGENTS.md)，后续审查默认跳过。这份报告保留原始发现，便于追溯决策背景。

## 验证基线与证据边界

- `flutter analyze`：通过，未发现分析问题。
- `flutter test`：通过，**1064 passed、5 skipped**。5 个跳过项是依赖 `UNIFIED_DESIGN_PREVIEW` 的专项测试；CI 的 release/design job 会显式开启该参数。
- ARB 键集：中文 1441、英文 1441，缺失键为 0。
- 页面源码：`lib/pages` 共 52 个 Dart 文件；测试目录共 118 个测试文件。
- Android debug 构建已尝试：`flutter build apk --debug --flavor github --dart-define=UNIFIED_DESIGN_PREVIEW=true`，当前机器 Gradle 因 `Unable to establish loopback connection` 失败；不能据此判断 Android 源码一定能或不能编译。
- 当前环境无 Android 真机/模拟器，因此没有完成本轮正式 APK/R8、通知、OCR、SAF、桌面启动器和安装更新的实际验证，也没有把历史截图当作本轮视觉证据。
- 未访问用户的真实 WebDAV、AI 端点或账目数据。

## 阻断项（P0）

### P0-1 · 正式签名私钥和口令仍在 Git 仓库

证据：

- `android/app/verifin-release.jks` 仍是 Git 跟踪文件，当前文件存在。
- [android/app/build.gradle.kts:38-44](../../android/app/build.gradle.kts#L38) 直接引用 keystore，并把 `storePassword`、`keyPassword` 写成明文。
- 发布工作流用该配置同时构建 GitHub APK 与 Play AAB。

影响：

- 任意能读取仓库或历史提交的人都可以尝试签发带有 Veri Fin 正式身份的 APK。
- 自分发 APK 可借助相同签名覆盖安装，用户难以区分恶意包与官方包。
- 删除当前文件不能消除 Git 历史中的泄露；Play App Signing 与 GitHub 分发证书还需要单独核对。

建议：

1. 立即确认仓库所有权、历史可见范围、当前线上 APK 证书指纹和 Play App Signing 状态。
2. 按“签名材料已泄露”制定迁移计划，保留既有用户可覆盖升级的路径。
3. GitHub Actions 改为受保护 Secret/签名服务注入，仓库不再存私钥和明文口令。
4. 历史提交做密钥清理，并在轮换完成后验证旧安装包升级链。

### P0-2 · CI 发布作业的写权限和第三方 Action 信任边界过宽

证据：

- [.github/workflows/flutter.yml:8-9](../../.github/workflows/flutter.yml#L8) 在工作流顶层给所有 job `contents: write`。
- `actions/checkout@v4`、`subosito/flutter-action@v2`、`actions/upload-artifact@v4`、`softprops/action-gh-release@v2` 都使用可移动 tag，没有固定完整 commit SHA。
- 同一个发布流程负责生成签名制品并创建 Release。

影响：

- 检查或构建 job 一旦被上游 Action 劫持，也拥有写 Release/仓库内容的能力。
- 发布签名材料与过宽权限叠加后，供应链风险高于普通 CI。

建议：

- 默认 `contents: read`，只给最终 release job 最小的 `contents: write`。
- 对第三方 Action 固定审核过的完整 SHA，使用 Dependabot/Renovate 提交升级。
- 将签名步骤、Release 创建步骤与普通检查彻底隔离。

## 高优先级问题（P1）

### P1-1 · WebDAV 恢复没有响应体大小上限

证据：

- [lib/app/backup/webdav_client_io.dart:223-241](../../lib/app/backup/webdav_client_io.dart#L223) 的 `webdavDownload` 使用 `BytesBuilder` 持续收集响应，没有最大字节数检查。
- 本地 SAF/文件路径读取有 256 MB 上限，但 WebDAV 路径没有同等限制。

影响：

- 服务器返回异常大文件时，恢复流程会把完整响应装入内存，可能导致 OOM 或长时间卡死。
- WebDAV 是用户自配地址，恶意或被攻破的服务端可以主动返回超大内容。

建议：

- 在流读取层统一复用 `maxBackupArchiveBytes`，按累计字节立即中止。
- 同时限制 PROPFIND 响应长度、远端文件数和单个文件元数据。
- 在 UI 中把“远端文件过大”与“格式错误”分开提示。

### P1-2 · ZIP 解压限制检查得太晚，不能可靠防 zip bomb

证据：

- [lib/app/backup/backup_archive.dart:64-80](../../lib/app/backup/backup_archive.dart#L64) 先调用 `ZipDecoder().decodeBytes`，之后才读取 `file.content` 并累计检查解压大小。
- 当前单条目可在触发累计检查之前先被解压并分配；总上限 512 MB 对移动端也偏高。

影响：

- 高压缩比、超大单条目或大量条目仍可能在检查前消耗大量内存和 CPU。
- 远端恢复、文件导入和自动备份回读共用该解包入口，风险面较广。

建议：

- 读取 ZIP central directory 后先校验条目数、每项压缩/解压大小和总大小，再允许读取内容。
- 对单附件、`backup.json`、附件总数和 JSON 字节数分别设上限。
- 增加恶意 ZIP/超大单条目的回归测试；不要只测试正常往返。

### P1-3 · 加密备份信封接受不受限的 KDF 参数

证据：

- [lib/app/backup/backup_crypto.dart:98-108](../../lib/app/backup/backup_crypto.dart#L98) 直接使用文件中的 `salt`、`nonce`、`cipher`、`mac` 和 `iter`，没有长度和范围校验。
- `iter` 可以被构造为极大值，导入时会长时间执行 PBKDF2；大字段也会先 Base64 解码并占用内存。

影响：

- 恶意备份可造成 CPU 拒绝服务，尤其是在自动尝试已保存口令的路径。
- 格式损坏与资源耗尽共用同一错误通道，用户只能看到“解密失败”。

建议：

- 对版本、KDF 名称、迭代数上下限、salt/nonce/MAC 固定长度、密文总长度做前置验证。
- 新文件使用版本化 KDF 参数；旧文件只在合法范围内兼容。
- 为超限/非法信封增加明确测试。

### P1-4 · Android 全局允许明文网络，风险控制只靠保存前提示

证据：

- [android/app/src/main/AndroidManifest.xml:24-30](../../android/app/src/main/AndroidManifest.xml#L24) 设置 `android:usesCleartextTraffic="true"`。
- AI Bearer Key、WebDAV Basic Auth 和账目摘要都可能经 HTTP 发送。
- [lib/app/net_security.dart](../../lib/app/net_security.dart) 只对公网 HTTP 做风险提示，用户确认后仍可保存。

影响：

- 任意网络请求默认都可走明文；应用的安全基线由用户是否理解提示决定。
- 局域网“相对可信”不能防止同网段窃听、ARP/DNS 劫持或错误配置。

建议：

- 默认只允许 HTTPS；如果必须支持本机/内网 HTTP，做成窄范围、可解释的显式例外。
- 把 HTTP 风险持久化显示在端点设置和上传/问答入口，而不是只在首次保存时提醒。
- 为 AI、WebDAV 分别测试重定向、证书错误和明文拒绝行为。

### P1-5 · 通知测试失败时仍向用户报告“已发送”

证据：

- [lib/app/reminder/notification_scheduler_io.dart:176-192](../../lib/app/reminder/notification_scheduler_io.dart#L176) 的 `showTest` 返回 `Future<void>，捕获异常后静默结束。
- [lib/pages/reminder_settings_page.dart:138-165](../../lib/pages/reminder_settings_page.dart#L138) 只等待该 Future，随后无条件显示成功轻提示。

影响：

- 权限、通知渠道或插件失败时，用户会被告知测试成功，无法判断提醒是否真的可用。
- 这是设置页最重要的诊断按钮，却不能区分“已提交系统”与“系统拒绝”。

建议：

- 让 `showTest` 返回明确结果（发送成功 / 权限拒绝 / 插件异常），失败记录结构化日志并显示错误。
- 真机覆盖 Android 13 通知权限、Android 12 精确闹钟、锁屏、国产 ROM 后台限制。

### P1-6 · 机密配置仍以明文存 SharedPreferences

证据：

- [lib/app/ai/ai_settings.dart:21-24](../../lib/app/ai/ai_settings.dart#L21) 明确说明 API Key 明文存本机。
- Controller 同样把 WebDAV 密码和备份口令写入 KV；该数据不进应用内 JSON 备份，但仍属于普通应用沙箱文件。

影响：

- root、调试备份、取证或未来误开系统迁移时可直接读取凭据。
- 应用锁和备份密钥的保护强度与“本地优先”承诺不匹配。

建议：

- 使用 Android Keystore 保护本机主密钥，再加密 AI Key、WebDAV 密码、备份口令。
- 把凭据存储与普通 UI 偏好分离，失败时保留草稿并给出可理解反馈。

### P1-7 · 应用锁使用单次 SHA-256，且没有尝试节流

证据：

- [lib/app/app_lock.dart:129-132](../../lib/app/app_lock.dart#L129) 仅计算加盐 SHA-256。
- 锁屏验证路径没有失败次数、退避或冷却。

影响：

- 6 位 PIN/短图案的离线枚举成本很低；本地取证或调试备份场景下容易被暴力尝试。
- 当前文档把威胁模型限定为防顺手查看，因此这不是“数据加密锁”，但用户容易高估保护能力。

建议：

- 至少使用慢 KDF（并版本化）、失败退避和重启后的尝试限制。
- UI 明确说明应用锁的保护边界，不把它表述成设备级加密。

### P1-8 · 自动备份“最后成功时间”不能表达部分失败

证据：

- [lib/app/backup/backup_coordinator.dart:88-93](../../lib/app/backup/backup_coordinator.dart#L88) 只要本地或 WebDAV 任一成功就调用 `recordBackupTime`。
- 另一目标失败只写日志，没有在数据管理页呈现“本地成功 / WebDAV 失败”等状态。

影响：

- 用户开启双目标备份时，时间戳更新可能让人误以为两处都成功。
- WebDAV 长期失效只能通过软件日志或远端缺文件发现。

建议：

- 记录每个目标的最近成功/失败时间和错误类别。
- 数据管理页显示目标级状态；自动备份失败达到阈值时给一次高优先级轻提示。

## 中优先级问题（P2）

### P2-1 · 页面直接调用 `showModalBottomSheet`，绕过统一弹层 chrome

组件规范要求页面统一经 `sheets.dart` helper 打开弹层，但当前仍有多个直调用点，例如：

- `lib/pages/account_icon_picker.dart:35`
- `lib/pages/ai_entry_sheet.dart:21`
- `lib/pages/app_lock_page.dart:948`
- `lib/pages/data_management_page.dart:901,1188`
- `lib/pages/home_metrics_settings_page.dart:71`
- `lib/pages/import_preview_page.dart:349,401,456`
- `lib/pages/refund_editor.dart:247`
- `lib/pages/report_analysis_page.dart:183`

影响是弹层的背景色、圆角、拖拽把手、安全区、动效和返回行为可能逐步漂移；这也使统一设计规范难以通过单点修复维护。

建议把各领域入口改成 helper，或在 `sheets.dart` 增加明确的领域 helper，保留业务 widget 在页面文件中。

### P2-2 · 仍有低于 44 dp 的共享触控目标

证据：

- `FilterPill` [lib/app/common_widgets_display.dart:53](../../lib/app/common_widgets_display.dart#L53) 的最小高度为 36。
- `VeriSectionAction` [lib/app/common_widgets_display.dart:415-418](../../lib/app/common_widgets_display.dart#L415) 固定为 32×32。
- 这些控件用于筛选、分区标题和卡片内操作，视觉紧凑但对老人、单手和 TalkBack 用户不友好。

建议保持视觉尺寸不变，外层提供至少 44×44 的透明命中盒；为共享组件补尺寸断言和大字号测试。

### P2-3 · 桌面小组件的图表图片没有内容描述

证据：

- [android/app/src/main/kotlin/top/talyra42/verifin/VeriFinWidget.kt:144-151](../../android/app/src/main/kotlin/top/talyra42/verifin/VeriFinWidget.kt#L144) 的预算环和净资产 sparkline 都传入 `null` content description。
- `strings.xml` 已有 `widget_chart_content_description`、`widget_budget_ring_content_description`，但没有被使用。

影响：

- TalkBack 只能读金额/标题，无法知道图形代表预算使用率或趋势。
- 小组件本身是 Android 原生可达性入口，Flutter 页面里的图表语义不能替代它。

### P2-4 · 依赖解析在不同 Flutter SDK 间不稳定

证据：

- [pubspec.yaml:21-30](../../pubspec.yaml#L21) 允许 SDK `^3.12.2`，而 `intl: any` 直接交给 Flutter localization 约束。
- 本轮用本地 Flutter 3.44.8 执行 `flutter pub get` 时，`pubspec.lock` 从 intl 0.20.3 等版本改写为较旧版本；已恢复该工具改动。
- CI 固定 Flutter 3.47.2。

影响：

- 不同 SDK/缓存可能生成不同锁文件，开发机与 CI 的测试依赖不完全一致。
- 依赖升级或回退会改变生成的 l10n/测试行为，增加复现成本。

建议：

- 明确支持的 Flutter/Dart 范围，并让开发环境、CI、文档使用同一 SDK。
- 对 `intl` 使用与 Flutter 版本一致的明确约束；将锁文件变更纳入依赖升级流程，而不是由日常 `pub get` 隐式产生。

### P2-5 · 测试覆盖了业务逻辑，但未覆盖发布安全和恶意输入边界

当前已有 118 个测试文件，覆盖面很广；仍缺少：

- keystore 不入库、CI 权限最小化和 Action SHA 固定的策略检查；
- WebDAV 下载上限、超大/恶意 ZIP、超大 JSON；
- KDF 参数越界、异常长度 Base64；
- 通知发送失败时不显示成功；
- Android release/R8、系统备份、通知、OCR、分享 URI、安装更新的真机回归。

建议把这些列为“发布前门禁/真机验收项”，而不是继续增加普通 widget 测试数量。

## 页面、面板、统计与功能逐域走查

| 领域 | 当前判断 | 主要证据与剩余关注 |
|---|---|---|
| 根导航 / Shell | 通过，结构清晰 | 四个根页由 `VeriFinShell` 保活，底栏与 PageView 状态机有专项测试；需要真机验证手势、系统导航条和动画帧时间。 |
| 首页 / 快速记账 | 通过，功能完整 | 快速记账、无账户、分类建议、金额键盘、预算环、日历、趋势和最近交易均有测试；需真机验证键盘、软键盘、滚动末项和大字号。 |
| 资产 / 账户 / 信用 | 通过，模型完整 | 账户分区、排序、隐藏账户、信用额度、还款、缺汇率入口均有实现；资产背景预设依赖远端图片，离线/图片失效时的回退视觉需要真机复核。 |
| 看板 / 面板 | 通过，近期修复较完整 | 本月收入/支出/结余摘要、预算执行卡、分类/标签/趋势面板、空态和面板排序已覆盖；仍需确认用户关闭所有面板时页面信息层级不会显得空洞。 |
| 统计分析 | 通过，交互齐全 | 月/年/自定义范围、分类下钻、查看交易、趋势和排行已有测试；需补真机图表触控、TalkBack 和 1.5× 字号。 |
| 交易列表 / 详情 | 通过，主路径完整 | 搜索、时间/账户/分类/标签/报销/预算筛选、多选、批量操作、FAB、退款入口均可达；批量跨币种限制需继续保持回归测试。 |
| 预算 / 周期记账 | 通过，口径清晰 | 默认预算、单期覆盖、自定义周期、剩余日均、分类树和趋势均有实现；需要真机检查长分类名、窄屏滚动和周期日期表达。 |
| 退款 / 报销 | 通过，模型领先 | 关联退款、部分退款、待到账/已到账、跨账户和附件主流程已有实现；跨账户退款不进入到账账户通用流水仍是已登记限制。 |
| 导入 / 数据管理 | 功能完整但风险边界需加固 | 多平台 parser、预览零落库、备份/恢复、加密、SAF、WebDAV、自动备份均有实现；远端/压缩输入限制见 P1-1/P1-2/P1-3。 |
| AI / 截图识账 / 分享 | 边界设计正确 | AI 只生成草稿、查询工具只读、端上 OCR、分享与 Intent 入口已实现；需 release/R8 真机验证 ML Kit、权限和异常图片。 |
| 设置 / 应用锁 / 通知 | 功能齐全但安全与反馈有缺口 | 设置草稿保存、应用锁、生物识别、提醒、更新入口齐全；应用锁强度和通知失败反馈见 P1-5/P1-7。 |
| 桌面小组件 / 快捷磁贴 | 架构完整 | 四种固定模板、实例配置、账本/指标选择、Glance 原生绘制、定时刷新和快速记账入口均已实现；图表无内容描述见 P2-3，需真机启动器验证。 |
| 国际化 / 法律文案 | 通过 | ARB 键集完全一致，隐私政策已经写明 AI/WebDAV 出网边界；法律正文仍是中文固定文本，英文用户会看到中文长文，这是产品决策但应在 UI 明示。 |

## 已确认的优点

- SQLite 迁移、Repository 契约、模型四向映射和多账本隔离有专门测试。
- 多币种保存原币、账户实际金额和冻结本位币金额，历史交易不会随汇率变化静默重算。
- 退款、跨币转账、预算排除和信用还款都沿用统一领域口径。
- 导入先预览后落库，备份写入有回读校验，应用锁忘记路径有双重破坏性确认。
- 页面骨架、卡片、Header、账户/分类图标、金额数字键盘、反馈 Host 和图表交互已有共享组件。
- 当前统一设计已经移除玻璃/模糊/折射材质，页面表面策略与项目规范一致。
- 全量 Dart 测试通过，默认没有发现静态分析问题。

## 建议执行顺序

1. **数据安全**：处理 P1-1/P1-2/P1-3，给 WebDAV、ZIP、加密信封统一输入上限。
2. **网络与凭据**：处理 P1-4/P1-6；至少把 HTTP 限制和凭据保护策略变成显式产品边界。
3. **真实反馈**：处理 P1-5，确保通知测试只有在系统调用成功时才显示成功；同时补 Android release/R8 真机验收。
4. **体验收尾**：处理 P2-1/P2-2/P2-3，统一弹层 chrome、触控命中盒和小组件无障碍语义。
5. **工程门禁**：把恶意输入、依赖解析和真机能力纳入 CI/发布前清单；签名与 GitHub Actions 风险按维护者豁免处理。
