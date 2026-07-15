import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_settings.dart';
import '../../l10n/app_localizations.dart';

/// 移动平台的本地通知实现（`flutter_local_notifications` + `timezone`）。
/// 每日在用户设定时刻发一条记账提醒。**用精确闹钟**（`exactAllowWhileIdle`）：
/// inexact 调度在 Doze / 国产 ROM 后台限制下常被系统无限推迟、根本不显示，是历史上
/// 「设了提醒却收不到」的根因；精确闹钟在休眠下也能准时触发。无精确权限时回退 inexact。
class NotificationScheduler {
  NotificationScheduler();

  static const int _reminderId = 1001;
  static const int _testId = 1002;
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
      // 只有成功解析到本地时区才算就绪；否则保持未就绪以便下次 apply 重试。
      // 若在此把 _timezoneReady 置真，早期通道未就绪等瞬时失败会让 tz.local
      // 永久停在 UTC，导致提醒按 UTC 时刻触发（如 UTC+8 的 21:00 变成次日 05:00）。
      _timezoneReady = true;
    } catch (_) {
      // 拿不到本地时区时本次退回 UTC（仍可工作、时刻可能有偏差），但不置就绪，
      // 下次 apply（开屏/回前台/改配置）会再试一次拿正确时区。
    }
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
        // 精确闹钟权限：Android 12 需用户在系统页授权；13+ 用 USE_EXACT_ALARM
        // 自动授予。失败/被拒不阻断——apply 会回退到 inexact 调度。
        try {
          await android?.requestExactAlarmsPermission();
        } catch (_) {
          // 忽略：无精确权限时回退 inexact。
        }
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
    final details = _details(l10n);
    // 优先精确闹钟（Doze 下也能准时触发、更可靠）；精确权限缺失会抛异常，则回退
    // inexact，至少仍有机会触发，不至于像以前那样彻底不响。
    final ok = await _schedule(
      scheduled,
      details,
      l10n,
      AndroidScheduleMode.exactAllowWhileIdle,
    );
    if (!ok) {
      await _schedule(
        scheduled,
        details,
        l10n,
        AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<bool> _schedule(
    tz.TZDateTime when,
    NotificationDetails details,
    AppLocalizations? l10n,
    AndroidScheduleMode mode,
  ) async {
    try {
      await _plugin.zonedSchedule(
        id: _reminderId,
        title: l10n?.reminderTitle ?? _channelName,
        body: l10n?.reminderNotifBody ?? '别忘了记录今天的收支～',
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  NotificationDetails _details(AppLocalizations? l10n) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      l10n?.reminderTitle ?? _channelName,
      channelDescription: l10n?.reminderChannelDesc ?? _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  /// 立即发一条测试通知：用于让用户当场确认「通知到底能不能显示」，把权限/渠道
  /// 问题与「定时不触发」问题区分开。
  Future<void> showTest({AppLocalizations? l10n}) async {
    if (!supported) {
      return;
    }
    await init();
    try {
      await _plugin.show(
        id: _testId,
        title: l10n?.reminderTitle ?? _channelName,
        body: l10n?.reminderTestBody ?? '这是一条测试通知——能看到它就说明通知功能正常。',
        notificationDetails: _details(l10n),
      );
    } catch (_) {
      // 显示失败（无权限等）静默处理。
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
