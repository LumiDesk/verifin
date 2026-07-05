import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'app/backup/backup_coordinator.dart';
import 'app/home_widget_service.dart';
import 'app/models.dart';
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
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalKeyValueStore.create();
  final database = await AppDatabase.open();
  final controller = await VeriFinController.create(
    store,
    repository: SqliteLedgerRepository(database),
  );
  // 打开应用时补记到期的周期交易。
  controller.applyDueRecurring(DateTime.now());
  runApp(VeriFinApp(controller: controller));
}

class VeriFinApp extends StatefulWidget {
  const VeriFinApp({super.key, required this.controller});

  /// 预先构建好的控制器（账目类数据已从 SQLite 载入）。
  final VeriFinController controller;

  @override
  State<VeriFinApp> createState() => _VeriFinAppState();
}

class _VeriFinAppState extends State<VeriFinApp> with WidgetsBindingObserver {
  late final VeriFinController _controller = widget.controller;
  final NotificationScheduler _notifications = NotificationScheduler();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 记账后自动备份挂钩；应用打开时按配置尝试一次自动备份。
    _controller.onEntryAdded = _handleEntryAdded;
    // 记账提醒：配置变化时重排本地通知，开屏按当前配置对齐一次。
    _controller.onReminderChanged = _handleReminderChanged;
    _notifications.apply(_controller.reminderSettings);
    BackupCoordinator.maybeBackupOnOpen(_controller);
    // 打开应用时刷新桌面小组件「今日支出」。
    pushTodayExpenseToWidget(_controller);
  }

  void _handleEntryAdded() {
    BackupCoordinator.maybeBackupAfterEntry(_controller);
    pushTodayExpenseToWidget(_controller);
  }

  void _handleReminderChanged(ReminderSettings settings) {
    _notifications.apply(settings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.applyDueRecurring(DateTime.now());
      BackupCoordinator.maybeBackupOnOpen(_controller);
      pushTodayExpenseToWidget(_controller);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_controller.onEntryAdded == _handleEntryAdded) {
      _controller.onEntryAdded = null;
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
