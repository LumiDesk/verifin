import 'reminder_settings.dart';
import '../../l10n/app_localizations.dart';

/// 非移动平台（测试宿主）的通知占位实现：一律不可用、不做任何调度。
class NotificationScheduler {
  const NotificationScheduler();

  /// 平台是否支持本地通知。
  bool get supported => false;

  /// 初始化通知插件与时区。占位实现无操作。
  Future<void> init() async {}

  /// 请求通知权限（Android 13+ / iOS）。占位返回 false。
  Future<bool> requestPermission() async => false;

  /// 按配置应用每日提醒：开启则调度、关闭则取消。占位无操作。
  Future<void> apply(
    ReminderSettings settings, {
    AppLocalizations? l10n,
  }) async {}

  /// 取消已安排的记账提醒。占位无操作。
  Future<void> cancel() async {}
}
