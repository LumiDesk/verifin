import '../veri_fin_controller.dart';
import 'backup_service.dart';

/// 自动备份协调器：在应用打开与记账后按配置触发自动备份。真正的文件 I/O 在
/// [BackupService]（条件导入存储端口）；控制器只提供配置与数据，不做 I/O。
class BackupCoordinator {
  const BackupCoordinator._();

  static bool _running = false;

  /// 应用打开（冷启动 / 回前台）时调用。
  static Future<void> maybeBackupOnOpen(VeriFinController controller) {
    return _maybeRun(controller, afterEntry: false);
  }

  /// 新增交易后调用。
  static Future<void> maybeBackupAfterEntry(VeriFinController controller) {
    return _maybeRun(controller, afterEntry: true);
  }

  static Future<void> _maybeRun(
    VeriFinController controller, {
    required bool afterEntry,
  }) async {
    final settings = controller.backupSettings;
    final now = DateTime.now();
    if (!settings.shouldAutoBackup(now, afterEntry: afterEntry)) {
      return;
    }
    // 避免并发重入（打开与记账事件叠加）。
    if (_running) {
      return;
    }
    _running = true;
    try {
      await BackupService.writeAutoBackup(
        settings: settings,
        content: controller.exportDataJson(),
        now: now,
      );
      controller.recordBackupTime(now);
    } catch (_) {
      // 自动备份失败静默处理（目录被移除 / 授权失效），不打断用户操作。
    } finally {
      _running = false;
    }
  }
}
