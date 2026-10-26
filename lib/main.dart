import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app/app_theme.dart';
import 'app/backup/backup_coordinator.dart';
import 'app/feedback.dart';
import 'app/l10n_outside_context.dart';
import 'app/models.dart';
import 'app/platform_bridge.dart';
import 'app/reminder/notification_scheduler.dart';
import 'app/reminder/reminder_settings.dart';
import 'app/startup/app_startup.dart';
import 'app/startup/startup_error_sink.dart';
import 'app/startup/verifin_bootstrap.dart';
import 'app/veri_fin_controller.dart';
import 'app/veri_fin_scope.dart';
import 'app/widgets/widget_refresh_coordinator.dart';
import 'app/widgets/widget_refresh_scope.dart';
import 'app/widgets/widget_service.dart';
import 'l10n/app_localizations.dart';
import 'pages/app_lock_gate.dart';
import 'pages/onboarding_page.dart';
import 'pages/privacy_consent_gate.dart';
import 'pages/shell.dart';
import 'pages/widget_configuration_page.dart';

@pragma('vm:entry-point')
Future<void> configureMain() => runWidgetConfiguration();

Future<void> main() async {
  // 启动早期（KV 打开之前）也要有地方记录错误：这些记录先攒在内存里，
  // 存储就绪后由 AppStartup 回放进真正的软件日志。
  final errors = StartupErrorSink();
  final systemIsEnglish =
      PlatformDispatcher.instance.locale.languageCode.toLowerCase() != 'zh';
  final startup = AppStartup(errors: errors, systemIsEnglish: systemIsEnglish);
  // 应用运行的顶层 zone，故意不 await（fire-and-forget）；未捕获错误交给下方 onError。
  unawaited(
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        // 未捕获的框架错误与异步错误都记入软件日志，便于用户反馈时提供诊断线索。
        // 安装位置必须在任何存储/插件调用之前，否则启动阶段的崩溃不会留下线索。
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.recordFlutterError(details);
          previousOnError?.call(details);
        };
        // 首帧交给启动壳：数据库/控制器等初始化全部发生在首帧之后，并且有
        // 阶段进度、单阶段看门狗与失败页——不再让用户停在空白启动窗口。
        runApp(
          VeriFinBootstrap(
            errors: errors,
            createCoordinator: startup.createCoordinator,
            buildApp: () => LiquidGlassWidgets.wrap(
              child: VeriFinApp(controller: startup.controller!),
              brightnessResolver: Theme.maybeBrightnessOf,
            ),
          ),
        );
      },
      (error, stack) {
        // runZonedGuarded 兜底：logger 尚未创建时（极早期崩溃）记录到启动缓冲，
        // 存储就绪后自动补进软件日志。
        errors.recordUncaught(error, stack);
        debugPrint('Uncaught zone error: $error');
      },
    ),
  );
}

class VeriFinApp extends StatefulWidget {
  const VeriFinApp({super.key, required this.controller});

  /// 预先构建好的控制器（账目类数据已从 SQLite 载入，含软件日志入口）。
  final VeriFinController controller;

  @override
  State<VeriFinApp> createState() => _VeriFinAppState();
}

class _VeriFinAppState extends State<VeriFinApp> with WidgetsBindingObserver {
  late final VeriFinController _controller = widget.controller;
  final NotificationScheduler _notifications = NotificationScheduler();
  final VeriFeedbackController _feedbackController = VeriFeedbackController();
  late final WidgetRefreshCoordinator _widgetRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 记账后自动备份挂钩；应用打开时按配置尝试一次自动备份。
    _controller.onEntryAdded = _handleEntryAdded;
    // 桌面小组件投影：只在账目类数据落库后重算（防抖），语言变化也要重推
    // （桌面文案跟随应用语言）。
    _widgetRefresh = WidgetRefreshCoordinator(
      _controller.flushPendingWrites,
      ({required bool force}) =>
          pushWidgetProjection(_controller, force: force),
    );
    _controller.onWidgetDataChanged = _widgetRefresh.schedule;
    _controller.localePreferenceListenable.addListener(_widgetRefresh.schedule);
    // 落库失败时弹出「保存失败」提示，避免用户以为已保存。
    _controller.onPersistError = _handlePersistError;
    // 应用锁开关变化时同步 FLAG_SECURE；开屏按当前状态对齐一次。
    _controller.onAppLockChanged = _handleAppLockChanged;
    AppSecurityBridge.setSecureFlag(_controller.appLockEnabled);
    // 记账提醒：配置变化时重排本地通知，开屏按当前配置对齐一次。
    _controller.onReminderChanged = _handleReminderChanged;
    _notifications.apply(
      _controller.reminderSettings,
      l10n: l10nForPreference(_controller.localePreference),
    );
    BackupCoordinator.maybeBackupOnOpen(_controller);
    // 打开应用时刷新桌面小组件：这里强制推一次，保证用户之后新添加的实例
    // 第一次渲染就能读到数据（即使此刻桌面上还没有实例）。
    unawaited(_widgetRefresh.pushNow(force: true));
    // 附件维护（孤儿回收 / 清理中断的暂存）与存量 base64 迁移都在启动后后台执行：
    // 迁移可中断、读取路径有 base64 兜底，期间记账与查看不受影响。
    unawaited(_runAttachmentMaintenance());
  }

  Future<void> _runAttachmentMaintenance() async {
    await _controller.maintainAttachmentFiles();
    final result = await _controller.migrateLegacyAttachments();
    if (result.failed == 0) {
      // 旧的 base64 都落盘后回收 `data_url` 列与文件空间（幂等；失败只记日志）。
      await _controller.reclaimLegacyAttachmentStorage();
    }
    if (!mounted || result.converted == 0) {
      return;
    }
    final l10n = l10nForPreference(_controller.localePreference);
    unawaited(
      _feedbackController.showMessage(
        message: result.failed == 0
            ? l10n.attachmentMigrationDone
            : l10n.attachmentMigrationFailed,
        tone: result.failed == 0
            ? VeriFeedbackTone.success
            : VeriFeedbackTone.warning,
        duration: result.failed == 0
            ? VeriFeedbackDuration.standard
            : VeriFeedbackDuration.long,
        dedupeKey: 'attachment-migration',
      ),
    );
  }

  void _handleEntryAdded() {
    BackupCoordinator.maybeBackupAfterEntry(_controller);
  }

  void _handlePersistError(Object _) {
    final l10n = l10nForPreference(_controller.localePreference);
    unawaited(
      _feedbackController.showMessage(
        message: l10n.saveFailed,
        tone: VeriFeedbackTone.error,
        duration: VeriFeedbackDuration.long,
        priority: VeriFeedbackPriority.high,
        dedupeKey: 'persist-error',
      ),
    );
  }

  void _handleAppLockChanged(bool appLockEnabled) {
    AppSecurityBridge.setSecureFlag(appLockEnabled);
  }

  void _handleReminderChanged(ReminderSettings settings) {
    _notifications.apply(
      settings,
      l10n: l10nForPreference(_controller.localePreference),
    );
  }

  Future<void> _postDueRecurringAndRefresh() async {
    await _controller.applyDueRecurring(DateTime.now());
    await BackupCoordinator.maybeBackupOnOpen(_controller);
    // 回前台强制推一次：补记后的数据、以及可能在后台期间新添加的实例都要对齐。
    await _widgetRefresh.pushNow(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 顺序约束：先补记到期的周期交易，再备份 / 推送小组件——顺序颠倒会把
      // 补记前的旧数据备份出去、推到桌面小组件上。
      unawaited(_postDueRecurringAndRefresh());
      // 每次回前台都重排提醒：每日提醒底层是「触发时自排下一天」的精确闹钟链，
      // 一旦某次因 Doze / force-stop / 重启 / 时区变化断掉，就再也不会自愈。只在
      // 冷启动重排会漏掉「常驻后台、只热恢复」的用户；apply 幂等（先 cancel 再排），
      // 每次回前台对齐一次能把断掉的链重新排上。
      _notifications.apply(
        _controller.reminderSettings,
        l10n: l10nForPreference(_controller.localePreference),
      );
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // 切后台时把挂起写入刷盘（KV 偏好 + SQLite 账目），缩小「刚改完设置 /
      // 刚记完账就被系统回收 → 丢失」的窗口。
      unawaited(_widgetRefresh.flush());
    }
  }

  @override
  void dispose() {
    _widgetRefresh.dispose();
    _controller.localePreferenceListenable.removeListener(
      _widgetRefresh.schedule,
    );
    if (_controller.onWidgetDataChanged == _widgetRefresh.schedule) {
      _controller.onWidgetDataChanged = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    if (_controller.onEntryAdded == _handleEntryAdded) {
      _controller.onEntryAdded = null;
    }
    if (_controller.onPersistError == _handlePersistError) {
      _controller.onPersistError = null;
    }
    if (_controller.onAppLockChanged == _handleAppLockChanged) {
      _controller.onAppLockChanged = null;
    }
    if (_controller.onReminderChanged == _handleReminderChanged) {
      _controller.onReminderChanged = null;
    }
    _feedbackController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VeriFinScope(
      controller: _controller,
      child: WidgetRefreshScope(
        coordinator: _widgetRefresh,
        child: ValueListenableBuilder<ThemePreference>(
          valueListenable: _controller.themePreferenceListenable,
          builder: (context, themePreference, _) {
            return ValueListenableBuilder<ThemeColorPreference>(
              valueListenable: _controller.themeColorPreferenceListenable,
              builder: (context, themeColorPreference, _) {
                return ValueListenableBuilder<LocalePreference>(
                  valueListenable: _controller.localePreferenceListenable,
                  builder: (context, localePreference, _) {
                    return MaterialApp(
                      onGenerateTitle: (context) =>
                          AppLocalizations.of(context).appTitle,
                      debugShowCheckedModeBanner: false,
                      // null 表示跟随系统语言（按 supportedLocales 解析，找不到回落中文）。
                      locale: localePreference.locale,
                      supportedLocales: AppLocalizations.supportedLocales,
                      localizationsDelegates:
                          AppLocalizations.localizationsDelegates,
                      themeMode: themePreference.themeMode,
                      theme: buildVeriFinTheme(
                        Brightness.light,
                        colorPreference: themeColorPreference,
                      ),
                      darkTheme: buildVeriFinTheme(
                        Brightness.dark,
                        colorPreference: themeColorPreference,
                      ),
                      builder: (context, child) => Material(
                        type: MaterialType.transparency,
                        child: PrivacyConsentGate(
                          child: AppLockGate(
                            child: OnboardingGate(
                              child: VeriFeedbackHost(
                                controller: _feedbackController,
                                child: child ?? const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      home: const VeriFinShell(),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
