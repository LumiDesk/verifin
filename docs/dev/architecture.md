# 架构导览

执行规则以 [AGENTS.md](../../AGENTS.md) 为准；这里仅提供源码导航，不重复维护规则。

Veri Fin 仅交付 Android，权威账目在本机 SQLite，无账号或自有服务端。
正式入口为 `lib/main.dart`；UI 通过 `VeriFinScope` 读取 `VeriFinController`，
Controller 经 repository 写库。`VeriFinController.create()` 是生产初始化入口；
主题、语言等设备偏好通过 KV 和独立 `ValueNotifier` 驱动。

| 领域 | 源码与维护文档 |
| --- | --- |
| 根初始化、启动壳、生命周期 | `main.dart`、`lib/app/startup/`（`VeriFinBootstrap` / `StartupCoordinator` / `StartupErrorSink` / `AppStartup`）；首帧由启动壳渲染，数据库与控制器在首帧之后按阶段载入；备份、周期补记、提醒、小组件与应用锁挂钩；锁状态经 `app/app_lock_session.dart` 向 Shell 暴露 |
| Controller | `veri_fin_controller.dart`、`veri_fin_controller_state.dart`、`veri_fin_controller_ops.dart` |
| SQLite 与持久化 | `lib/data/`；[技术决策](tech-decisions.md)、repository contract 与 migration matrix 测试 |
| 模型 | `lib/app/models/`；`models.dart` 稳定导出；JSON/SQLite 映射须同步 |
| 页面与弹窗 | `lib/pages/`、`pages/sheets.dart`、`app/entry_sheets.dart`；[组件目录](../design/components.md) |
| 共享绘制、锚点菜单、图表 | `common_widgets.dart`、`chart_painters.dart`、`root_navigation.dart`、`veri_bottom_bar.dart`；锚点菜单直接使用 `package:anchored_menu`，视觉令牌在 `app_theme.dart` 桥接；[统一设计](../design/design-system.md) |
| 多币种、预算、退款 | [多币种](multi-currency.md)、[单期预算](category-budget-override.md)、[退款](refund.md)、[交易保存校验与退款金额精度](entry-save-validation.md) |
| 导入、备份 | `lib/app/backup/import/`、`lib/app/backup/`；只在预览确认后落库，字节格式仅由 BackupService 编解码 |
| 图片附件 | `lib/app/attachments/attachment_store.dart` 是字节唯一入口（文件存储、暂存、孤儿回收、迁移期物化）；SQLite 只存元数据；`image_picker_cleanup_io.dart` 只删除选择器缓存副本；[设计](attachment-storage-and-backup.md) |
| AI | `lib/app/ai/`：`ai_chat_session_controller.dart` 管页面内会话，`ai_ledger_snapshot.dart` 冻结账本/余额/预算，`ai_agent_engine.dart` 管协议轮次，`ai_query_tool.dart` 注册只读工具；[渠道预设与模型发现](ai-provider-presets.md)、[只读查询工具](ai-tools.md)、[截图识别与外部采集](auto-capture.md) |
| Android 系统能力 | `platform_bridge*.dart`、`android/`；单一 MethodChannel 分发，真实权限与冷启动验收；`AppLockPreferences.kt` 在 Flutter 启动前读取锁状态，`availableBytes` 为备份解包提供 `StatFs` 空间预检；[桌面小组件](home-widgets.md) |
| 国际化 | `lib/l10n/*.arb` 与 gen-l10n 输出；[国际化验收](i18n-verification.md) |
| 本地调试、发布 | [Android 开发](android-development.md)、`scripts/*.dart`（`dart run scripts/doctor.dart` 环境自检、`publish.dart` 发版、`prune_prereleases.dart` 清理预发布、`clean.dart` 清构建产物） |
| 第三方 vendor 源码 | `third_party/`：`jdenticon_dart`（上游 SDK 上限过旧，本地复刻一份并只放宽约束）与 `liquid_glass_widgets`（MIT，只供可选液态玻璃底栏适配层使用）；与上游的差异、许可与同步方式写在各目录 README，不要在里面做业务改动 |

内存仓储、插件 stub 和 ffi factory 用于测试，不能替代生产持久化。

## 文档权威顺序

判断「当前实现事实」时按以下顺序取信，冲突时前者覆盖后者：

1. **源码、测试、Gradle、CI 工作流与发布脚本**——唯一事实来源。
2. [AGENTS.md](../../AGENTS.md)——执行规范：改动流程与必须遵守的规则。
3. [design-system.md](../design/design-system.md)——界面与交互规范。
4. [ui-guidelines.md](../design/ui-guidelines.md)——页面骨架与交互细则。
5. [components.md](../design/components.md)——可复用组件 / 弹窗 / 纯函数注册表。
6. [tech-decisions.md](tech-decisions.md)（已决策取舍）与 [known-limitations.md](known-limitations.md)（已接受限制与整改阈值）。

文档与实现不一致时，以第 1 条为准，核实后同步修正文档。
