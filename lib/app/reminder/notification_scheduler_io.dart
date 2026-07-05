import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_settings.dart';
import '../../l10n/app_localizations.dart';

/// 移动平台的本地通知实现（`flutter_local_notifications` + `timezone`）。
/// 每日在用户设定时刻发一条记账提醒，使用 inexact 调度（免精确闹钟权限）。
class NotificationScheduler {
  NotificationScheduler();

  static const int _reminderId = 1001;
  static const String _channelId = 'verifin_daily_reminder';
  static const String _channelName = '记账提醒';
  static const String _channelDescription = '每日记账提醒通知';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timezoneReady = false;

  bool get supported => Platform.isAndroid || Platform.isIOS;

  Future<void> init() async {
    if (_initialized || !supported) {
      return;
    }
    await _ensureTimezone();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
    );
    _initialized = true;
  }

  Future<void> _ensureTimezone() async {
    if (_timezoneReady) {
      return;
    }
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // 拿不到本地时区时退回 UTC，仍可工作（时刻可能有偏差）。
    }
    _timezoneReady = true;
  }

  Future<bool> requestPermission() async {
    if (!supported) {
      return false;
    }
    await init();
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? true;
      }
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<void> apply(
    ReminderSettings settings, {
    AppLocalizations? l10n,
  }) async {
    if (!supported) {
      return;
    }
    await init();
    await cancel();
    if (!settings.enabled) {
      return;
    }
    final scheduled = _nextInstanceOf(settings.hour, settings.minute);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n?.reminderTitle ?? _channelName,
        channelDescription: l10n?.reminderChannelDesc ?? _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    try {
      await _plugin.zonedSchedule(
        id: _reminderId,
        title: l10n?.reminderTitle ?? _channelName,
        body: l10n?.reminderNotifBody ?? '别忘了记录今天的收支～',
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // 调度失败（权限缺失等）静默处理。
    }
  }

  Future<void> cancel() async {
    if (!supported) {
      return;
    }
    try {
      await _plugin.cancel(id: _reminderId);
    } catch (_) {
      // 忽略取消失败。
    }
  }

  /// 计算下一次 hour:minute 的本地时区时刻（今天已过则顺延到明天）。
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
