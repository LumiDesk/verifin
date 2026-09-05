# 架构导览

执行规则以 [AGENTS.md](../../AGENTS.md) 为准；这里仅提供源码导航，不重复维护规则。

Veri Fin 仅交付 Android，权威账目在本机 SQLite，无账号或自有服务端。
正式入口为 `lib/main.dart`；UI 通过 `VeriFinScope` 读取 `VeriFinController`，
Controller 经 repository 写库。`VeriFinController.create()` 是生产初始化入口；
主题、语言、高级材质等设备偏好通过 KV 和独立 ValueNotifier 驱动。

| 领域 | 源码与维护文档 |
| --- | --- |
| 根初始化、生命周期 | `lib/main.dart`；备份、周期补记、提醒、小组件与应用锁挂钩 |
| Controller | `veri_fin_controller.dart`、`veri_fin_controller_state.dart`、`veri_fin_controller_ops.dart` |
| SQLite 与持久化 | `lib/data/`；[技术决策](tech-decisions.md)、repository contract 与 migration matrix 测试 |
| 模型 | `lib/app/models/`，`models.dart` 稳定导出；JSON/SQLite 映射须同步 |
| 页面与弹窗 | `lib/pages/`、`pages/sheets.dart`、`app/entry_sheets.dart`；[组件目录](components.md) |
| 共享绘制、菜单、图表 | `common_widgets.dart`、`chart_painters.dart`、`root_navigation.dart`；[统一设计](../design-system.md) |
| 多币种、预算、退款 | [多币种](multi-currency-design.md)、[单期预算](category-budget-override-design.md)、[退款](refund-design.md) |
| 导入、备份 | `lib/app/backup/import/`、`lib/app/backup/`；只在预览确认后落库，字节格式仅由 BackupService 编解码 |
| AI | `lib/app/ai/`；[只读查询工具](ai-tools.md)、[主动采集](auto-capture-plan.md) |
| Android 系统能力 | `platform_bridge*.dart`、`android/`；单一 MethodChannel 分发，真实权限与冷启动验收 |
| 国际化 | `lib/l10n/*.arb` 与 gen-l10n 输出；[国际化验收](i18n-verification.md) |
| 本地调试、发版 | [Android 开发](android-development.md)、[玻璃调查](android-glass-investigation.md)、`scripts/publish.*` |

内存仓储、插件 stub 和 ffi factory 用于测试，不能替代生产持久化。
历史设计稿中的旧行为需要用当前源码复核；Web 预览已移除，历史记录不再代表支持范围。
