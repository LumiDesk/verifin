/// 记账提醒的本地通知平台适配入口。移动端（io）走 `flutter_local_notifications`
/// + `timezone`，测试宿主走占位（不可用）。
library;

export 'notification_scheduler_stub.dart'
    if (dart.library.io) 'notification_scheduler_io.dart';
