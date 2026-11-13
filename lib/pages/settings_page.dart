import 'dart:async';

import 'package:anchored_menu/anchored_menu.dart';
import 'package:flutter/material.dart';

import '../app/app_version.dart';
import '../app/auto_save.dart';
import '../app/build_config.dart';
import '../app/common_widgets.dart';
import '../app/credits.dart';
import '../app/external_links.dart';
import '../app/feedback.dart';
import '../app/haptics.dart';
import '../app/legal_content.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/root_navigation_styles.dart';
import '../app/update/update_check.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import 'ai_settings_page.dart';
import 'app_lock_page.dart';
import 'credits_page.dart';
import 'legal_pages.dart';
import 'navigation_style_settings_page.dart';
import 'reminder_settings_page.dart';
import 'sheets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AutoSave _autoSave;
  late ThemePreference _theme;
  late ThemeColorPreference _themeColor;
  late LocalePreference _locale;
  late NavigationStylePreference _navigationStyle;
  late bool _haptics;
  late bool _twoDecimals;
  late MoneyUnitStyle _moneyUnitStyle;
  late bool _hideSingleCurrencyUnit;
  late FabActionMode _fabAction;
  late NumberPadLayout _numberPadLayout;
  String? _defaultAccountId;
  late bool _autoSuggest;
  late bool _showRunningBalance;
  bool _initialized = false;

  /// 「检查更新」正在进行：设置行显示「检查中…」并禁用点击，避免重复发请求。
  bool _checkingUpdate = false;

  @override
  void dispose() {
    _autoSave.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final controller = VeriFinScope.of(context);
    _autoSave = AutoSave(save: _save, logger: controller.logger);
    _theme = controller.themePreference;
    _themeColor = controller.themeColorPreference;
    _locale = controller.localePreference;
    _navigationStyle = controller.navigationStylePreference;
    _haptics = controller.hapticsEnabled;
    _twoDecimals =
        controller.currencyFractionStyle == CurrencyFractionStyle.standard;
    _moneyUnitStyle = controller.moneyUnitStyle;
    _hideSingleCurrencyUnit = controller.hideUnitInSingleCurrency;
    _fabAction = controller.fabActionMode;
    _numberPadLayout = controller.numberPadLayout;
    _defaultAccountId = controller.defaultAccountId;
    _autoSuggest = controller.autoSuggestEnabled;
    _showRunningBalance = controller.showRunningBalance;
    _initialized = true;
  }

  void _change(VoidCallback update) {
    setState(update);
    _autoSave.schedule(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);

    return AutoSavePopScope(
      autoSave: _autoSave,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: AppLocalizations.of(context).settingsTitle,
                  showBack: true,
                ),
                const SizedBox(height: 10),
                AutoSaveFailureBanner(autoSave: _autoSave),
                _sectionLabel(
                  context,
                  AppLocalizations.of(context).settingsSectionAppearance,
                ),
                VeriCard(
                  key: const ValueKey('settingsSectionAppearance'),
                  child: Column(
                    children: <Widget>[
                      AnchoredMenuChoice<ThemePreference>(
                        values: ThemePreference.values,
                        selected: _theme,
                        idOf: (value) => 'settings_theme_${value.name}',
                        labelOf: (value) =>
                            value.label(AppLocalizations.of(context)),
                        iconOf: (value) => switch (value) {
                          ThemePreference.system => Icons.brightness_auto,
                          ThemePreference.light => Icons.light_mode_outlined,
                          ThemePreference.dark => Icons.dark_mode_outlined,
                        },
                        onSelected: (value) => _change(() => _theme = value),
                        semanticLabel: AppLocalizations.of(
                          context,
                        ).themePickerTitle,
                        builder: (context, openMenu, menuOpen) => SettingsRow(
                          icon: Icons.dark_mode_outlined,
                          title: AppLocalizations.of(context).themeMode,
                          trailing: _theme.label(AppLocalizations.of(context)),
                          trailingIcon: Icons.chevron_right,
                          onTap: openMenu,
                        ),
                      ),
                      const Divider(height: 1),
                      AnchoredMenuChoice<ThemeColorMode>(
                        values: ThemeColorMode.values,
                        selected: _themeColor.mode,
                        idOf: (value) => 'settings_theme_color_${value.name}',
                        labelOf: (value) => switch (value) {
                          ThemeColorMode.defaultColor => AppLocalizations.of(
                            context,
                          ).themeColorDefault,
                          ThemeColorMode.system => AppLocalizations.of(
                            context,
                          ).themeColorSystem,
                          ThemeColorMode.custom => AppLocalizations.of(
                            context,
                          ).themeColorCustom,
                        },
                        iconOf: (value) => switch (value) {
                          ThemeColorMode.defaultColor => Icons.color_lens,
                          ThemeColorMode.system => Icons.auto_awesome,
                          ThemeColorMode.custom => Icons.palette_outlined,
                        },
                        onSelected: (value) => _change(
                          () => _themeColor = _themeColor.copyWith(mode: value),
                        ),
                        semanticLabel: AppLocalizations.of(
                          context,
                        ).themeColorLabel,
                        builder: (context, openMenu, menuOpen) => SettingsRow(
                          icon: Icons.color_lens_outlined,
                          title: AppLocalizations.of(context).themeColorLabel,
                          trailing: switch (_themeColor.mode) {
                            ThemeColorMode.defaultColor => AppLocalizations.of(
                              context,
                            ).themeColorDefault,
                            ThemeColorMode.system => AppLocalizations.of(
                              context,
                            ).themeColorSystem,
                            ThemeColorMode.custom => AppLocalizations.of(
                              context,
                            ).themeColorCustom,
                          },
                          trailingIcon: Icons.chevron_right,
                          onTap: openMenu,
                        ),
                      ),
                      if (_themeColor.mode ==
                          ThemeColorMode.custom) ...<Widget>[
                        const Divider(height: 1),
                        SettingsRow(
                          key: const ValueKey('settings_theme_color_custom'),
                          icon: Icons.palette_outlined,
                          title: AppLocalizations.of(context).themeColorCustom,
                          trailing: _themeColorHex,
                          trailingIcon: Icons.chevron_right,
                          onTap: _editThemeColor,
                          contentColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                      const Divider(height: 1),
                      SettingsRow(
                        key: const ValueKey('settings_navigation_style'),
                        icon: Icons.dashboard_outlined,
                        title: AppLocalizations.of(
                          context,
                        ).navigationStyleLabel,
                        trailing: veriRootNavigationStyleFor(
                          _navigationStyle.name,
                        ).label(AppLocalizations.of(context)),
                        trailingIcon: Icons.chevron_right,
                        onTap: _pickNavigationStyle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionLabel(
                  context,
                  AppLocalizations.of(context).settingsSectionAmountDisplay,
                ),
                VeriCard(
                  key: const ValueKey('settingsSectionAmountDisplay'),
                  child: Column(
                    children: <Widget>[
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
                            _change(() => _twoDecimals = value),
                      ),
                      const Divider(height: 1),
                      AnchoredMenuChoice<MoneyUnitStyle>(
                        values: MoneyUnitStyle.values,
                        selected: _moneyUnitStyle,
                        idOf: (value) => 'settings_money_unit_${value.name}',
                        labelOf: (value) => _moneyUnitStyleLabel(
                          AppLocalizations.of(context),
                          value,
                        ),
                        iconOf: (value) => switch (value) {
                          MoneyUnitStyle.symbol => Icons.currency_yen_rounded,
                          MoneyUnitStyle.code => Icons.code_rounded,
                        },
                        onSelected: (value) =>
                            _change(() => _moneyUnitStyle = value),
                        semanticLabel: AppLocalizations.of(
                          context,
                        ).moneyUnitStyleLabel,
                        builder: (context, openMenu, menuOpen) => SettingsRow(
                          icon: Icons.currency_exchange_outlined,
                          title: AppLocalizations.of(
                            context,
                          ).moneyUnitStyleLabel,
                          trailing: _moneyUnitStyleLabel(
                            AppLocalizations.of(context),
                            _moneyUnitStyle,
                          ),
                          trailingIcon: Icons.chevron_right,
                          onTap: openMenu,
                        ),
                      ),
                      const Divider(height: 1),
                      CompactSwitchRow(
                        key: const Key('hide_single_currency_unit'),
                        icon: Icons.visibility_off_outlined,
                        title: Text(
                          AppLocalizations.of(
                            context,
                          ).hideSingleCurrencyUnitLabel,
                        ),
                        subtitle: Text(
                          AppLocalizations.of(
                            context,
                          ).hideSingleCurrencyUnitDesc,
                        ),
                        value: _hideSingleCurrencyUnit,
                        onChanged: (value) =>
                            _change(() => _hideSingleCurrencyUnit = value),
                      ),
                      const Divider(height: 1),
                      CompactSwitchRow(
                        key: const Key('show_running_balance'),
                        icon: Icons.functions_outlined,
                        title: Text(
                          AppLocalizations.of(context).runningBalanceLabel,
                        ),
                        subtitle: Text(
                          AppLocalizations.of(context).runningBalanceDesc,
                        ),
                        value: _showRunningBalance,
                        onChanged: (value) =>
                            _change(() => _showRunningBalance = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionLabel(
                  context,
                  AppLocalizations.of(context).settingsSectionGeneral,
                ),
                VeriCard(
                  key: const ValueKey('settingsSectionGeneral'),
                  child: Column(
                    children: <Widget>[
                      AnchoredMenuChoice<LocalePreference>(
                        values: LocalePreference.values,
                        selected: _locale,
                        idOf: (value) => 'settings_locale_${value.name}',
                        labelOf: (value) =>
                            value.label(AppLocalizations.of(context)),
                        iconOf: (value) => switch (value) {
                          LocalePreference.system => Icons.language_outlined,
                          LocalePreference.zh => Icons.translate_outlined,
                          LocalePreference.en => Icons.abc_rounded,
                        },
                        onSelected: (value) => _change(() => _locale = value),
                        semanticLabel: AppLocalizations.of(
                          context,
                        ).languagePickerTitle,
                        builder: (context, openMenu, menuOpen) => SettingsRow(
                          icon: Icons.translate_outlined,
                          title: AppLocalizations.of(context).settingsLanguage,
                          trailing: _locale.label(AppLocalizations.of(context)),
                          trailingIcon: Icons.chevron_right,
                          onTap: openMenu,
                        ),
                      ),
                      const Divider(height: 1),
                      CompactSwitchRow(
                        icon: Icons.touch_app_outlined,
                        title: Text(AppLocalizations.of(context).hapticsLabel),
                        subtitle: Text(
                          AppLocalizations.of(context).hapticsSubtitle,
                        ),
                        value: _haptics,
                        onChanged: (value) {
                          if (value) {
                            // 打开这一下闸门还是关的（写入要等下一次保存），
                            // 主动给一次确认，让用户当场知道效果。
                            VeriHaptics.preview();
                          }
                          _change(() => _haptics = value);
                        },
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
                      AnchoredMenuChoice<FabActionMode>(
                        values: FabActionMode.values,
                        selected: _fabAction,
                        idOf: (value) => 'settings_fab_${value.name}',
                        labelOf: (value) =>
                            value.label(AppLocalizations.of(context)),
                        iconOf: (value) => switch (value) {
                          FabActionMode.manual => Icons.edit_outlined,
                          FabActionMode.ai => Icons.auto_awesome_outlined,
                          FabActionMode.manualTapAiLongPress =>
                            Icons.touch_app_outlined,
                        },
                        onSelected: (value) =>
                            _change(() => _fabAction = value),
                        semanticLabel: AppLocalizations.of(
                          context,
                        ).fabActionPickerTitle,
                        builder: (context, openMenu, menuOpen) => SettingsRow(
                          icon: Icons.bolt_outlined,
                          title: AppLocalizations.of(context).fabActionTitle,
                          trailing: _fabAction.label(
                            AppLocalizations.of(context),
                          ),
                          trailingIcon: Icons.chevron_right,
                          onTap: openMenu,
                        ),
                      ),
                      const Divider(height: 1),
                      AnchoredMenuChoice<NumberPadLayout>(
                        values: NumberPadLayout.values,
                        selected: _numberPadLayout,
                        idOf: (value) =>
                            'settings_number_pad_layout_${value.name}',
                        labelOf: (value) =>
                            value.label(AppLocalizations.of(context)),
                        iconOf: (value) => switch (value) {
                          NumberPadLayout.standard => Icons.calculate_outlined,
                          NumberPadLayout.phone => Icons.dialpad_outlined,
                        },
                        onSelected: (value) =>
                            _change(() => _numberPadLayout = value),
                        semanticLabel: AppLocalizations.of(
                          context,
                        ).numberPadLayoutPickerTitle,
                        width: null,
                        builder: (context, openMenu, menuOpen) => SettingsRow(
                          icon: Icons.dialpad_outlined,
                          title: AppLocalizations.of(
                            context,
                          ).numberPadLayoutLabel,
                          trailing: _numberPadLayout.label(
                            AppLocalizations.of(context),
                          ),
                          trailingIcon: Icons.chevron_right,
                          onTap: openMenu,
                        ),
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
                            _change(() => _autoSuggest = value),
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
                      for (final entry
                          in LegalDocument.values.indexed) ...<Widget>[
                        if (entry.$1 > 0) const Divider(height: 1),
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
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.volunteer_activism_outlined,
                        title: AppLocalizations.of(context).creditsTitle,
                        trailing: AppLocalizations.of(
                          context,
                        ).creditsSupporterCount(creditsSupporters.length),
                        trailingIcon: Icons.chevron_right,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) => const CreditsPage(),
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
                  AppLocalizations.of(context).settingsSectionMore,
                ),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      // 检查更新只在 GitHub 自分发版提供；Play 版由商店负责更新
                      // （见 build_config.dart）。
                      if (kUpdateCheckEnabled) ...<Widget>[
                        SettingsRow(
                          icon: Icons.system_update_alt_outlined,
                          title: AppLocalizations.of(context).checkUpdate,
                          trailing: _checkingUpdate
                              ? AppLocalizations.of(context).checkingLabel
                              : 'GitHub Release',
                          trailingIcon: _checkingUpdate
                              ? null
                              : Icons.chevron_right,
                          onTap: _checkingUpdate ? null : _checkForUpdate,
                        ),
                        const Divider(height: 1),
                      ],
                      SettingsRow(
                        icon: Icons.code_rounded,
                        title: AppLocalizations.of(
                          context,
                        ).githubRepositoryLabel,
                        trailing: 'LumiDesk/verifin',
                        trailingIcon: Icons.chevron_right,
                        onTap: _openGitHubRepository,
                      ),
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

  String _moneyUnitStyleLabel(AppLocalizations l10n, MoneyUnitStyle style) =>
      switch (style) {
        MoneyUnitStyle.symbol => l10n.moneyUnitStyleSymbol,
        MoneyUnitStyle.code => l10n.moneyUnitStyleCode,
      };

  String get _themeColorHex {
    final color = Color(_themeColor.customColorValue);
    return '#${_colorByte(color.r).toRadixString(16).padLeft(2, '0')}'
            '${_colorByte(color.g).toRadixString(16).padLeft(2, '0')}'
            '${_colorByte(color.b).toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  /// 进入导航栏样式选择页。
  ///
  /// 样式页选中即写入设备偏好；返回后只需把本页显示值同步到 Controller，
  /// 不再触发一次全量设置保存。
  Future<void> _pickNavigationStyle() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            NavigationStyleSettingsPage(initialStyleId: _navigationStyle.name),
      ),
    );
    if (!mounted) {
      return;
    }
    final current = VeriFinScope.of(context).navigationStylePreference;
    if (current != _navigationStyle) {
      setState(() => _navigationStyle = current);
    }
  }

  Future<void> _editThemeColor() async {
    final picked = await showThemeColorPickerSheet(
      context: context,
      initialColor: Color(_themeColor.customColorValue),
    );
    if (!mounted || picked == null) return;
    _change(
      () => _themeColor = _themeColor.copyWith(
        mode: ThemeColorMode.custom,
        customColorValue:
            (_colorByte(picked.a) << 24) |
            (_colorByte(picked.r) << 16) |
            (_colorByte(picked.g) << 8) |
            _colorByte(picked.b),
      ),
    );
  }

  int _colorByte(double channel) => (channel * 255).round().clamp(0, 255);

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
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: l10n.noUsableAccountTitle,
          tone: VeriFeedbackTone.warning,
        ),
      );
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
      _change(
        () => _defaultAccountId = selected.id.isEmpty ? null : selected.id,
      );
    }
  }

  /// 检查 GitHub 上是否有更新的正式版。
  ///
  /// 有更新时展示「关闭 / 前往」普通弹窗，由用户决定是否去浏览器打开该版本的
  /// Release 页面；无更新与失败只给轻提示，不打断当前设置草稿。
  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) {
      return;
    }
    setState(() => _checkingUpdate = true);
    final result = await checkForUpdate();
    if (!mounted) {
      return;
    }
    setState(() => _checkingUpdate = false);
    final l10n = AppLocalizations.of(context);
    switch (result) {
      case UpdateCheckFailed(:final reason):
        VeriFinScope.of(
          context,
        ).logger?.warning('Update check failed: $reason', source: 'update');
        unawaited(
          VeriFeedbackHost.of(context).showMessage(
            message: l10n.updateCheckFailed,
            tone: VeriFeedbackTone.error,
          ),
        );
      case UpdateUpToDate():
        unawaited(
          VeriFeedbackHost.of(context).showMessage(
            message: l10n.updateUpToDate,
            tone: VeriFeedbackTone.info,
          ),
        );
      case UpdateAvailable(:final release):
        final proceed = await showConfirmDialog(
          context,
          title: l10n.updateAvailableTitle,
          message: l10n.updateAvailableMessage(
            currentAppVersionNumber(),
            release.version,
          ),
          cancelLabel: l10n.closeLabel,
          confirmLabel: l10n.updateOpenRelease,
        );
        if (!proceed || !mounted) {
          return;
        }
        final opened = await ExternalLinks.openVerifinRelease(release.tag);
        if (!opened && mounted) {
          VeriFinScope.of(context).logger?.warning(
            'Failed to open release page: ${release.tag}',
            source: 'update',
          );
          unawaited(
            VeriFeedbackHost.of(context).showMessage(
              message: l10n.openLinkFailed,
              tone: VeriFeedbackTone.error,
            ),
          );
        }
    }
  }

  /// 用系统浏览器打开项目仓库主页（源码、Issue 与更新记录都在那里）。
  Future<void> _openGitHubRepository() async {
    final opened = await ExternalLinks.openVerifinRepository();
    if (opened || !mounted) {
      return;
    }
    VeriFinScope.of(context).logger?.warning(
      'Failed to open the GitHub repository',
      source: 'settings',
    );
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: AppLocalizations.of(context).openLinkFailed,
        tone: VeriFeedbackTone.error,
      ),
    );
  }

  static Widget _sectionLabel(BuildContext context, String text) {
    return SectionLabel(text);
  }

  Future<bool> _save() {
    return VeriFinScope.of(context).saveAppPreferencesDraft(
      themePreference: _theme,
      themeColorPreference: _themeColor,
      localePreference: _locale,
      navigationStylePreference: _navigationStyle,
      hapticsEnabled: _haptics,
      currencyFractionStyle: _twoDecimals
          ? CurrencyFractionStyle.standard
          : CurrencyFractionStyle.compact,
      moneyUnitStyle: _moneyUnitStyle,
      hideUnitInSingleCurrency: _hideSingleCurrencyUnit,
      fabActionMode: _fabAction,
      numberPadLayout: _numberPadLayout,
      defaultAccountId: _defaultAccountId,
      autoSuggestEnabled: _autoSuggest,
      showRunningBalance: _showRunningBalance,
    );
  }
}
