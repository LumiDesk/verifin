import 'dart:async';

import 'package:flutter/material.dart';

import '../app/auto_save.dart';
import '../app/common_widgets.dart';
import '../app/feedback.dart';
import '../app/reminder/notification_scheduler.dart';
import '../app/reminder/reminder_settings.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';

/// 记账提醒设置页：开关每日提醒并选择提醒时刻。开启时向系统申请通知权限。
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  late final AutoSave _autoSave;
  final NotificationScheduler _scheduler = NotificationScheduler();
  late ReminderSettings _draftSettings;
  bool _permissionCheckedForEnabled = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    final controller = VeriFinScope.of(context);
    _draftSettings = controller.reminderSettings;
    _permissionCheckedForEnabled = _draftSettings.enabled;
    _autoSave = AutoSave(save: _save, logger: controller.logger);
  }

  @override
  void dispose() {
    _autoSave.dispose();
    super.dispose();
  }

  void _apply(ReminderSettings settings) {
    setState(() => _draftSettings = settings);
    _autoSave.schedule(immediate: true);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _draftSettings.hour,
        minute: _draftSettings.minute,
      ),
      helpText: AppLocalizations.of(context).reminderPickTime,
    );
    if (picked != null && mounted) {
      _apply(_draftSettings.copyWith(hour: picked.hour, minute: picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _draftSettings;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);

    return AutoSavePopScope(
      autoSave: _autoSave,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: AppLocalizations.of(context).reminderTitle,
                  showBack: true,
                ),
                const SizedBox(height: 10),
                AutoSaveFailureBanner(autoSave: _autoSave),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      CompactSwitchRow(
                        icon: Icons.notifications_active_outlined,
                        title: Text(AppLocalizations.of(context).reminderDaily),
                        value: settings.enabled,
                        onChanged: (enabled) =>
                            _apply(settings.copyWith(enabled: enabled)),
                      ),
                      if (settings.enabled) ...<Widget>[
                        const Divider(height: 1),
                        SettingsRow(
                          icon: Icons.schedule_outlined,
                          title: AppLocalizations.of(context).reminderTimeLabel,
                          trailing: settings.timeLabel,
                          trailingIcon: Icons.chevron_right,
                          onTap: _pickTime,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _scheduler.supported
                        ? AppLocalizations.of(context).reminderDescSupported
                        : AppLocalizations.of(context).reminderDescUnsupported,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: muted, height: 1.5),
                  ),
                ),
                if (_scheduler.supported) ...<Widget>[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _sendTest,
                    icon: const Icon(Icons.notifications_outlined, size: 18),
                    label: Text(
                      AppLocalizations.of(context).reminderTestButton,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendTest() async {
    final feedback = VeriFeedbackHost.of(context);
    final l10n = AppLocalizations.of(context);
    // 先确保有通知/精确闹钟权限（首次可能未申请过），再立即发一条测试通知。
    final granted = await _scheduler.requestPermission();
    if (!mounted) {
      return;
    }
    // 权限被拒时不能报「已发送」：用户会以为提醒正常，实际一条都收不到。
    if (!granted) {
      unawaited(
        feedback.showMessage(
          message: l10n.reminderPermissionDenied,
          tone: VeriFeedbackTone.warning,
          duration: VeriFeedbackDuration.long,
        ),
      );
      return;
    }
    final sent = await _scheduler.showTest(l10n: l10n);
    if (!mounted) {
      return;
    }
    if (!sent) {
      unawaited(
        feedback.showMessage(
          message: l10n.reminderTestFailed,
          tone: VeriFeedbackTone.error,
          duration: VeriFeedbackDuration.long,
        ),
      );
      return;
    }
    unawaited(
      feedback.showMessage(
        message: l10n.reminderTestSent,
        tone: VeriFeedbackTone.success,
      ),
    );
  }

  Future<bool> _save() async {
    final feedback = VeriFeedbackHost.of(context);
    final l10n = AppLocalizations.of(context);
    var granted = true;
    if (_draftSettings.enabled && !_permissionCheckedForEnabled) {
      _permissionCheckedForEnabled = true;
      granted = await _scheduler.requestPermission();
      if (!mounted) {
        return false;
      }
    }
    final saved = await VeriFinScope.of(
      context,
    ).saveReminderSettingsDraft(_draftSettings);
    if (!mounted || !saved) {
      return false;
    }
    if (_draftSettings.enabled && _scheduler.supported && !granted) {
      unawaited(
        feedback.showMessage(
          message: l10n.reminderPermissionDenied,
          tone: VeriFeedbackTone.warning,
          duration: VeriFeedbackDuration.long,
        ),
      );
    }
    return true;
  }
}
