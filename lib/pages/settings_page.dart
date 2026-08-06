import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_version.dart';
import '../app/build_config.dart';
import '../app/common_widgets.dart';
import '../app/legal_content.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/platform_bridge.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import 'ai_settings_page.dart';
import 'app_lock_page.dart';
import 'legal_pages.dart';
import 'reminder_settings_page.dart';
import 'sheets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ThemePreference _initialTheme;
  late ThemePreference _theme;
  late LocalePreference _initialLocale;
  late LocalePreference _locale;
  late bool _initialHaptics;
  late bool _haptics;
  late bool _initialTwoDecimals;
  late bool _twoDecimals;
  late FabActionMode _initialFabAction;
  late FabActionMode _fabAction;
  String? _initialDefaultAccountId;
  String? _defaultAccountId;
  late bool _initialAutoSuggest;
  late bool _autoSuggest;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final controller = VeriFinScope.of(context);
    _initialTheme = _theme = controller.themePreference;
    _initialLocale = _locale = controller.localePreference;
    _initialHaptics = _haptics = controller.hapticsEnabled;
    _initialTwoDecimals = _twoDecimals = controller.amountForceTwoDecimals;
    _initialFabAction = _fabAction = controller.fabActionMode;
    _initialDefaultAccountId = _defaultAccountId = controller.defaultAccountId;
    _initialAutoSuggest = _autoSuggest = controller.autoSuggestEnabled;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: AppLocalizations.of(context).settingsTitle,
                  showBack: true,
                  actions: <Widget>[
                    SaveHeaderAction(onPressed: _isDirty ? _saveAndExit : null),
                  ],
                ),
                const SizedBox(height: 10),
                _sectionLabel(
                  context,
                  AppLocalizations.of(context).settingsSectionGeneral,
                ),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      SettingsRow(
                        icon: Icons.dark_mode_outlined,
                        title: AppLocalizations.of(context).themeMode,
                        trailing: _theme.label(AppLocalizations.of(context)),
                        trailingIcon: Icons.chevron_right,
                        onTap: _pickThemePreference,
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.translate_outlined,
                        title: AppLocalizations.of(context).settingsLanguage,
                        trailing: _locale.label(AppLocalizations.of(context)),
                        trailingIcon: Icons.chevron_right,
                        onTap: _pickLocalePreference,
                      ),
                      const Divider(height: 1),
                      CompactSwitchRow(
                        icon: Icons.touch_app_outlined,
                        title: Text(AppLocalizations.of(context).hapticsLabel),
                        value: _haptics,
                        onChanged: (value) => setState(() => _haptics = value),
                      ),
                      const Divider(height: 1),
                      CompactSwitchRow(
                        icon: Icons.plus_one_outlined,
                        title: Text(
                          AppLocalizations.of(context).amountTwoDecimalsLabel,
                        ),
                        subtitle: Text(
                          AppLocalizations.of(context).amountTwoDecimalsDesc,
                        ),
                        value: _twoDecimals,
                        onChanged: (value) =>
                            setState(() => _twoDecimals = value),
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.lock_outline,
                        title: AppLocalizations.of(context).appLockLabel,
                        trailing: controller.appLockEnabled
                            ? AppLocalizations.of(context).enabledLabel
                            : AppLocalizations.of(context).notEnabled,
                        trailingIcon: Icons.chevron_right,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) => const AppLockSettingsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionLabel(
                  context,
                  AppLocalizations.of(context).settingsSectionBookkeeping,
                ),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      SettingsRow(
                        icon: Icons.bolt_outlined,
                        title: AppLocalizations.of(context).fabActionTitle,
                        trailing: _fabAction.label(
                          AppLocalizations.of(context),
                        ),
                        trailingIcon: Icons.chevron_right,
                        onTap: _pickFabActionMode,
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.account_balance_wallet_outlined,
                        title: AppLocalizations.of(context).defaultAccountTitle,
                        trailing: _defaultAccountTrailing(context, controller),
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _pickDefaultAccount(controller),
                      ),
                      const Divider(height: 1),
                      CompactSwitchRow(
                        icon: Icons.auto_fix_high_outlined,
                        title: Text(
                          AppLocalizations.of(context).autoSuggestLabel,
                        ),
                        subtitle: Text(
                          AppLocalizations.of(context).autoSuggestDesc,
                        ),
                        value: _autoSuggest,
                        onChanged: (value) =>
                            setState(() => _autoSuggest = value),
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.auto_awesome_outlined,
                        title: AppLocalizations.of(context).aiSettingsTitle,
                        trailing: controller.aiSettings.isConfigured
                            ? AppLocalizations.of(context).aiConfigured
                            : AppLocalizations.of(context).aiNotConfigured,
                        trailingIcon: Icons.chevron_right,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) => const AiSettingsPage(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.notifications_active_outlined,
                        title: AppLocalizations.of(context).reminderTitle,
                        trailing: controller.reminderSettings.enabled
                            ? AppLocalizations.of(context).reminderDailyAt(
                                controller.reminderSettings.timeLabel,
                              )
                            : AppLocalizations.of(context).notEnabled,
                        trailingIcon: Icons.chevron_right,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const ReminderSettingsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionLabel(
                  context,
                  AppLocalizations.of(context).settingsSectionAbout,
                ),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      // 应用内自更新仅 GitHub 自分发版提供；Play 版关闭（见 build_config.dart）。
                      if (kSelfUpdateEnabled)
                        SettingsRow(
                          icon: Icons.system_update_alt_outlined,
                          title: AppLocalizations.of(context).checkUpdate,
                          trailing: 'GitHub Release',
                          trailingIcon: Icons.chevron_right,
                          onTap: () => _checkForUpdate(context),
                        ),
                      for (final entry
                          in LegalDocument.values.indexed) ...<Widget>[
                        if (kSelfUpdateEnabled || entry.$1 > 0)
                          const Divider(height: 1),
                        SettingsRow(
                          icon: entry.$2 == LegalDocument.privacyPolicy
                              ? Icons.privacy_tip_outlined
                              : Icons.description_outlined,
                          title: entry.$2.title(AppLocalizations.of(context)),
                          trailing: AppLocalizations.of(context).viewLabel,
                          trailingIcon: Icons.chevron_right,
                          onTap: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    LegalDocumentPage(document: entry.$2),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'VeriFin $appVersionLabel',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickThemePreference() async {
    final selected = await showOptionSheet<ThemePreference>(
      context: context,
      title: AppLocalizations.of(context).themePickerTitle,
      values: ThemePreference.values,
      selected: _theme,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null && mounted) {
      setState(() => _theme = selected);
    }
  }

  Future<void> _pickLocalePreference() async {
    final l10n = AppLocalizations.of(context);
    final selected = await showOptionSheet<LocalePreference>(
      context: context,
      title: l10n.languagePickerTitle,
      values: LocalePreference.values,
      selected: _locale,
      labelOf: (value) => value.label(l10n),
    );
    if (selected != null && mounted) {
      setState(() => _locale = selected);
    }
  }

  Future<void> _pickFabActionMode() async {
    final l10n = AppLocalizations.of(context);
    final selected = await showOptionSheet<FabActionMode>(
      context: context,
      title: l10n.fabActionPickerTitle,
      values: FabActionMode.values,
      selected: _fabAction,
      labelOf: (value) => value.label(l10n),
    );
    if (selected != null && mounted) {
      setState(() => _fabAction = selected);
    }
  }

  String _defaultAccountTrailing(
    BuildContext context,
    VeriFinController controller,
  ) {
    final id = _defaultAccountId;
    if (id == null) {
      return AppLocalizations.of(context).defaultAccountNone;
    }
    final account = controller.accounts
        .where((account) => account.id == id)
        .firstOrNull;
    return account?.name ?? AppLocalizations.of(context).defaultAccountNone;
  }

  Future<void> _pickDefaultAccount(VeriFinController controller) async {
    final l10n = AppLocalizations.of(context);
    final accounts = controller.accounts
        .where((account) => !account.hidden)
        .toList();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noUsableAccountTitle)));
      return;
    }
    final selected = await showAccountPickerSheet(
      context: context,
      title: l10n.defaultAccountPickerTitle,
      accounts: accounts,
      selectedId: _defaultAccountId ?? '',
      balanceOf: controller.accountBalance,
      noneLabel: l10n.defaultAccountNone,
      noneHint: l10n.defaultAccountNoneHint,
    );
    if (selected == null) {
      return;
    }
    if (mounted) {
      setState(
        () => _defaultAccountId = selected.id.isEmpty ? null : selected.id,
      );
    }
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _UpdateCheckDialog(),
    );
  }

  static Widget _sectionLabel(BuildContext context, String text) {
    return SectionLabel(text);
  }

  bool get _isDirty =>
      _theme != _initialTheme ||
      _locale != _initialLocale ||
      _haptics != _initialHaptics ||
      _twoDecimals != _initialTwoDecimals ||
      _fabAction != _initialFabAction ||
      _defaultAccountId != _initialDefaultAccountId ||
      _autoSuggest != _initialAutoSuggest;

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _save() {
    return VeriFinScope.of(context).saveAppPreferencesDraft(
      themePreference: _theme,
      localePreference: _locale,
      hapticsEnabled: _haptics,
      amountForceTwoDecimals: _twoDecimals,
      fabActionMode: _fabAction,
      defaultAccountId: _defaultAccountId,
      autoSuggestEnabled: _autoSuggest,
    );
  }
}

class _UpdateCheckDialog extends StatefulWidget {
  const _UpdateCheckDialog();

  @override
  State<_UpdateCheckDialog> createState() => _UpdateCheckDialogState();
}

class _UpdateCheckDialogState extends State<_UpdateCheckDialog> {
  UpdateCheckResult? _result;
  bool _checking = true;
  bool _downloading = false;
  bool _installing = false;
  // 下载完成后置真：主按钮变「立即安装」，用户在系统安装页点错取消可反复重试，无需重下。
  bool _downloaded = false;
  bool _includePrerelease = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _downloading = false;
      _downloaded = false;
    });
    final result = await AppUpdateBridge.checkForUpdate(
      includePrerelease: _includePrerelease,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _checking = false;
    });
  }

  Future<void> _download() async {
    // 预发布版本下载前先提示不稳定风险，用户确认后再继续。
    if (_result?.isPrerelease ?? false) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).prereleaseWarningTitle),
          content: Text(AppLocalizations.of(context).prereleaseWarningMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                AppLocalizations.of(context).prereleaseDownloadAnyway,
              ),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) {
        return;
      }
    }
    setState(() => _downloading = true);
    final result = await AppUpdateBridge.downloadLatestUpdate(
      includePrerelease: _includePrerelease,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _downloading = false;
      // 下载并已拉起安装：记住 APK 已就绪，主按钮转为「立即安装」可反复重试。
      _downloaded = result.status == UpdateCheckStatus.installing;
    });
  }

  Future<void> _install() async {
    setState(() => _installing = true);
    final result = await AppUpdateBridge.installDownloadedUpdate();
    if (!mounted) {
      return;
    }
    setState(() {
      _installing = false;
      _result = result;
      // 已下载文件不在了（缓存被系统清理），回退到重新下载。
      if (result.status == UpdateCheckStatus.noAsset) {
        _downloaded = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final hasUpdate = result?.status == UpdateCheckStatus.available;

    return AlertDialog(
      title: Text(AppLocalizations.of(context).checkUpdate),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _VersionInfoRow(
              label: AppLocalizations.of(context).currentVersion,
              value: appVersionLabel,
            ),
            const SizedBox(height: 8),
            _VersionInfoRow(
              label: AppLocalizations.of(context).latestVersion,
              value: _checking
                  ? AppLocalizations.of(context).checkingLabel
                  : _displayVersion(result),
            ),
            const SizedBox(height: 14),
            if (_checking)
              Row(
                children: <Widget>[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(AppLocalizations.of(context).queryingGithub),
                ],
              )
            else
              Text(
                result?.message ??
                    AppLocalizations.of(context).updateCheckFailed,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            if (hasUpdate && (result?.isPrerelease ?? false)) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: veriExpense,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).prereleaseNoticeInline,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: veriExpense,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_downloading) ...<Widget>[
              const SizedBox(height: 14),
              ValueListenableBuilder<UpdateDownloadProgress?>(
                valueListenable: AppUpdateBridge.updateProgress,
                builder: (context, progress, _) {
                  final knownSize = progress != null && progress.totalBytes > 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      LinearProgressIndicator(
                        value: knownSize ? progress.progress : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        knownSize
                            ? AppLocalizations.of(
                                context,
                              ).downloadingPercent(progress.percent)
                            : AppLocalizations.of(context).downloadingLabel,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 6),
            const Divider(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).includePrereleaseLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Switch(
                  value: _includePrerelease,
                  onChanged: (_checking || _downloading)
                      ? null
                      : (value) {
                          setState(() => _includePrerelease = value);
                          _check();
                        },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: (_downloading || _installing)
              ? null
              : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).closeLabel),
        ),
        if (!_checking &&
            !_downloaded &&
            result?.status == UpdateCheckStatus.error)
          TextButton(
            onPressed: _downloading ? null : _check,
            child: Text(AppLocalizations.of(context).retryLabel),
          ),
        if (_downloaded)
          // 下载已完成：主按钮转为「立即安装」，可反复点击重新拉起系统安装器，无需重下。
          FilledButton(
            onPressed: (_downloading || _installing) ? null : _install,
            child: Text(AppLocalizations.of(context).installNow),
          )
        // hasUpdate 或已下载文件丢失（noAsset 回退）时，都提供「下载新版本」入口。
        else if (hasUpdate || result?.status == UpdateCheckStatus.noAsset)
          FilledButton(
            onPressed: _downloading ? null : _download,
            child: Text(
              _downloading
                  ? AppLocalizations.of(context).downloadingShort
                  : AppLocalizations.of(context).downloadNewVersion,
            ),
          ),
      ],
    );
  }

  String _displayVersion(UpdateCheckResult? result) {
    final latest = result?.latestVersion ?? '';
    if (latest.isEmpty) {
      return '--';
    }
    return latest.startsWith('v') ? latest : 'v$latest';
  }
}

class _VersionInfoRow extends StatelessWidget {
  const _VersionInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.54),
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
