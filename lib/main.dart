import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'app/backup/backup_coordinator.dart';
import 'app/home_widget_service.dart';
import 'app/l10n_outside_context.dart';
import 'app/logging/app_logger.dart';
import 'app/models.dart';
import 'app/platform_bridge.dart';
import 'app/reminder/notification_scheduler.dart';
import 'app/reminder/reminder_settings.dart';
import 'app/veri_fin_controller.dart';
import 'app/veri_fin_scope.dart';
import 'data/app_database.dart';
import 'data/ledger_repository.dart';
import 'l10n/app_localizations.dart';
import 'local_storage/local_storage.dart';
import 'pages/app_lock_gate.dart';
import 'pages/privacy_consent_gate.dart';
import 'pages/shell.dart';

Future<void> main() async {
  // 应用运行的顶层 zone，故意不 await（fire-and-forget）；未捕获错误交给下方 onError。
  unawaited(
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        final store = await LocalKeyValueStore.create();
        final logger = AppLogger(store);
        // 未捕获的框架错误与异步错误都记入软件日志，便于用户反馈时提供诊断线索。
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          logger.error(
            details.exceptionAsString(),
            source: 'flutter',
            error: details.exception,
          );
          previousOnError?.call(details);
        };
        final VeriFinController controller;
        try {
          final database = await AppDatabase.open();
          controller = await VeriFinController.create(
            store,
            repository: SqliteLedgerRepository(database),
            logger: logger,
            // 语言偏好为「跟随系统」时，首启动播种的默认数据（账本/分类/简介）按系统语言选文案。
            systemIsEnglish:
                PlatformDispatcher.instance.locale.languageCode.toLowerCase() !=
                'zh',
          );
        } catch (error) {
          // 数据库损坏或版本降级（用户安装了更旧 APK）时打开会抛异常。不做破坏性
          // 处理（绝不删库），而是展示可诊断的错误页，明确告知用户数据很可能仍在、
          // 不要清除应用数据，避免「白屏 → 误以为数据丢了 → 清数据 → 真丢」。
          logger.error(
            'Database open failed: $error',
            source: 'startup',
            error: error,
          );
          runApp(DatabaseErrorApp(detail: '$error'));
          return;
        }
        // 打开应用时补记到期的周期交易。
        controller.applyDueRecurring(DateTime.now());
        runApp(VeriFinApp(controller: controller));
      },
      (error, stack) {
        // runZonedGuarded 兜底：此时 logger 可能尚未创建（极早期崩溃），仅调试打印。
        debugPrint('Uncaught zone error: $error');
      },
    ),
  );
}

/// 数据库无法打开时的兜底错误页。用最小依赖自绘（不依赖 controller），
/// 语言跟随系统。核心目的：把「白屏」换成明确「数据很可能还在、别清数据」的提示。
class DatabaseErrorApp extends StatelessWidget {
  const DatabaseErrorApp({super.key, required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildVeriFinTheme(Brightness.light),
      darkTheme: buildVeriFinTheme(Brightness.dark),
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final scheme = Theme.of(context).colorScheme;
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(
                        Icons.storage_rounded,
                        size: 56,
                        color: scheme.error,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.dbErrorTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.dbErrorBody,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.dbErrorHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.dbErrorDetail,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          detail,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
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
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 记账后自动备份挂钩；应用打开时按配置尝试一次自动备份。
    _controller.onEntryAdded = _handleEntryAdded;
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
    // 打开应用时刷新桌面小组件「今日支出」。
    pushWidgetData(_controller);
  }

  void _handleEntryAdded() {
    BackupCoordinator.maybeBackupAfterEntry(_controller);
    pushWidgetData(_controller);
  }

  void _handlePersistError(Object error) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    final l10n = AppLocalizations.of(messenger.context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.applyDueRecurring(DateTime.now());
      BackupCoordinator.maybeBackupOnOpen(_controller);
      pushWidgetData(_controller);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // 切后台时把挂起写入刷盘（KV 偏好 + SQLite 账目），缩小「刚改完设置 /
      // 刚记完账就被系统回收 → 丢失」的窗口。
      unawaited(_controller.flushPendingWrites());
    }
  }

  @override
  void dispose() {
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VeriFinScope(
      controller: _controller,
      child: ValueListenableBuilder<ThemePreference>(
        valueListenable: _controller.themePreferenceListenable,
        builder: (context, themePreference, _) {
          return ValueListenableBuilder<LocalePreference>(
            valueListenable: _controller.localePreferenceListenable,
            builder: (context, localePreference, _) {
              return MaterialApp(
                scaffoldMessengerKey: _messengerKey,
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context).appTitle,
                debugShowCheckedModeBanner: false,
                // null 表示跟随系统语言（按 supportedLocales 解析，找不到回落中文）。
                locale: localePreference.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                themeMode: themePreference.themeMode,
                theme: buildVeriFinTheme(Brightness.light),
                darkTheme: buildVeriFinTheme(Brightness.dark),
                builder: (context, child) => PrivacyConsentGate(
                  child: AppLockGate(child: child ?? const SizedBox.shrink()),
                ),
                home: const VeriFinShell(),
              );
            },
          );
        },
      ),
    );
  }
}
