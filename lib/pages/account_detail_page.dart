// 账户详情相关页面：从 assets_pages 拆出。账户详情/编辑、账户报表、
// 信用卡还款日横幅与迷你分段切换控件。
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/services.dart';

import '../app/account_icon_assets.dart';
import '../app/app_theme.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/credit_card.dart';
import '../app/currency_catalog.dart';
import '../app/currency_math.dart';
import '../app/icon_catalog.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/series_math.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'credit_repayment_page.dart';
import 'entry_detail_page.dart';
import 'sheets.dart';
import 'transactions_pages.dart';

const double assetCoverAspectRatio = 1200 / 760;

const int assetCoverTargetWidth = 1200;

const int assetCoverTargetHeight = 760;

class AccountDetailPage extends StatefulWidget {
  const AccountDetailPage({super.key, required this.account});

  final Account account;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  final EditorExitController _exitController = EditorExitController();
  bool _monthlyTrend = false;
  late Account _initialAccount;
  late Account _draftAccount;
  late bool _initialDefault;
  late bool _draftDefault;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final controller = VeriFinScope.of(context);
    final account = controller.accounts.firstWhere(
      (item) => item.id == widget.account.id,
      orElse: () => widget.account,
    );
    _initialAccount = account;
    _draftAccount = account;
    _initialDefault = controller.defaultAccountId == account.id;
    _draftDefault = _initialDefault;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final persistedAccount = controller.accounts.firstWhere(
      (item) => item.id == widget.account.id,
      orElse: () => widget.account,
    );
    final currentAccount = _draftAccount;
    final balance = controller.accountBalance(currentAccount);
    final entries = controller.entries
        .where((entry) => entryTouchesAccount(entry, currentAccount.id))
        .toList();
    final balanceTrendValues = _monthlyTrend
        ? accountMonthlyBalanceSeries(currentAccount, entries)
        : accountBalanceSeries(currentAccount, entries);
    final matchingGroups = controller.accountGroups.where(
      (group) => group.id == currentAccount.groupId,
    );
    final groupName = matchingGroups.isEmpty
        ? AppLocalizations.of(context).assetsUngrouped
        : matchingGroups.first.name;

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      exitController: _exitController,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: currentAccount.name,
                  subtitle: currentAccount.type.label(
                    AppLocalizations.of(context),
                  ),
                  showBack: true,
                  actions: <Widget>[
                    HeaderAction(
                      icon: Icons.edit_outlined,
                      tooltip: AppLocalizations.of(
                        context,
                      ).balanceAdjustTooltip,
                      onPressed: () => _editBalance(persistedAccount, balance),
                    ),
                    SaveHeaderAction(onPressed: _isDirty ? _saveAndExit : null),
                  ],
                ),
                const SizedBox(height: 10),
                if (currentAccount.type.supportsCredit &&
                    currentAccount.dueDay != null) ...<Widget>[
                  _CreditCardDueBanner(dueDay: currentAccount.dueDay!),
                  const SizedBox(height: 10),
                ],
                VeriCard(
                  onTap: () => _editBalance(persistedAccount, balance),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(AppLocalizations.of(context).currentBalance),
                            const SizedBox(height: 6),
                            Text(
                              formatMoney(balance, currentAccount.currencyCode),
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    color: veriBlue,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      VeriIconBox(icon: Icons.edit_outlined, size: 36),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (currentAccount.type.supportsCredit &&
                    (currentAccount.creditLimit != null ||
                        currentAccount.statementDay != null)) ...<Widget>[
                  _CreditSummaryCard(
                    account: currentAccount,
                    balance: balance,
                    entries: entries,
                  ),
                  const SizedBox(height: 10),
                ],
                if (currentAccount.type.supportsCredit) ...<Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _startRepayment(persistedAccount),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(
                        AppLocalizations.of(context).creditRepayAction,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                VeriCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).balanceTrend,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          _MiniSegmentedToggle(
                            value: _monthlyTrend,
                            leftLabel: AppLocalizations.of(context).dayShort,
                            rightLabel: AppLocalizations.of(context).monthShort,
                            onChanged: (value) =>
                                setState(() => _monthlyTrend = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 148,
                        child: InteractiveTrendChart(
                          color: veriBlue,
                          values: balanceTrendValues,
                          xLabels: _monthlyTrend
                              ? evenMonthAxisLabels()
                              : monthAxisLabels(DateTime.now()),
                          yLabels: balanceAxisLabels(balanceTrendValues),
                          labelColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.50),
                          tooltipOf: (index) => ChartTooltip(
                            title: _monthlyTrend
                                ? AppLocalizations.of(
                                    context,
                                  ).monthNumber(index + 1)
                                : AppLocalizations.of(context).dateMonthDay(
                                    DateTime(
                                      DateTime.now().year,
                                      DateTime.now().month,
                                      index + 1,
                                    ),
                                  ),
                            lines: <ChartTooltipLine>[
                              ChartTooltipLine(
                                text: AppLocalizations.of(context)
                                    .balanceAmount(
                                      formatMoney(
                                        balanceTrendValues[index],
                                        currentAccount.currencyCode,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  AccountReportPage(account: persistedAccount),
                            ),
                          );
                        },
                        child: Text(AppLocalizations.of(context).viewReport),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                VeriCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).panelRecentLabel,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          VeriSectionAction(
                            icon: Icons.add,
                            tooltip: AppLocalizations.of(
                              context,
                            ).addEntryTooltip,
                            onPressed: () => _startEntryForAccount(
                              context,
                              persistedAccount,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (entries.isEmpty)
                        EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: AppLocalizations.of(context).noEntriesTitle,
                          description: AppLocalizations.of(
                            context,
                          ).accountNoEntriesDesc,
                        )
                      else
                        ...entries
                            .where((e) => e.type != EntryType.refund)
                            .take(3)
                            .map(
                              (entry) => TransactionTile(
                                entry,
                                accounts: controller.accounts,
                                categories: controller.categories,
                                tags: controller.tags,
                                showDate: true,
                                baseCurrencyCode:
                                    controller.activeBook.baseCurrencyCode,
                                onTap: () => openEntryDetail(context, entry),
                              ),
                            ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) => TransactionsPage(
                                accountId: currentAccount.id,
                                title: AppLocalizations.of(
                                  context,
                                ).accountEntriesTitle(currentAccount.name),
                              ),
                            ),
                          );
                        },
                        child: Text(AppLocalizations.of(context).allEntries),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SectionLabel(AppLocalizations.of(context).accountSectionBasic),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      SettingsRow(
                        icon: Icons.category_outlined,
                        title: AppLocalizations.of(context).commonType,
                        trailing: currentAccount.type.label(
                          AppLocalizations.of(context),
                        ),
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _pickAccountType(currentAccount),
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.badge_outlined,
                        title: AppLocalizations.of(context).commonName,
                        trailing: currentAccount.name,
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _editAccountName(currentAccount),
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.image_outlined,
                        title: AppLocalizations.of(context).commonIcon,
                        trailing: iconLabelForCode(
                          AppLocalizations.of(context),
                          currentAccount.iconCode,
                        ),
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _pickAccountIcon(currentAccount),
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.currency_exchange,
                        title: AppLocalizations.of(context).commonCurrency,
                        trailing:
                            '${currentAccount.currencyCode} · ${CurrencyCatalog.require(currentAccount.currencyCode).nameForLocale(Localizations.localeOf(context).toLanguageTag())}',
                        trailingIcon:
                            controller.accountCurrencyLocked(persistedAccount)
                            ? Icons.lock_outline
                            : Icons.chevron_right,
                        onTap: () => _pickAccountCurrency(
                          persistedAccount,
                          currentAccount,
                        ),
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.notes,
                        title: AppLocalizations.of(context).commonNote,
                        trailing: currentAccount.note.isEmpty
                            ? AppLocalizations.of(context).commonNoneShort
                            : currentAccount.note,
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _editAccountNote(currentAccount),
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.folder_outlined,
                        title: AppLocalizations.of(context).commonGroup,
                        trailing: groupName,
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _pickAccountGroup(currentAccount),
                      ),
                    ],
                  ),
                ),
                if (currentAccount.type.supportsCardLast4) ...<Widget>[
                  const SizedBox(height: 12),
                  SectionLabel(AppLocalizations.of(context).accountSectionCard),
                  VeriCard(
                    child: Column(
                      children: <Widget>[
                        SettingsRow(
                          icon: Icons.credit_card,
                          title: AppLocalizations.of(context).cardLabel,
                          trailing: currentAccount.cardLast4.isEmpty
                              ? AppLocalizations.of(context).notSet
                              : currentAccount.cardLast4,
                          trailingIcon: Icons.chevron_right,
                          onTap: () => _editCard(currentAccount),
                        ),
                        if (currentAccount.cardNumber.isNotEmpty) ...<Widget>[
                          const Divider(height: 1),
                          SettingsRow(
                            icon: Icons.numbers_outlined,
                            title: AppLocalizations.of(context).cardNumberTitle,
                            trailing: currentAccount.cardNumber,
                            trailingIcon: Icons.copy_outlined,
                            onTap: () =>
                                _copyCardNumber(currentAccount.cardNumber),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (currentAccount.type.supportsCredit) ...<Widget>[
                  const SizedBox(height: 12),
                  SectionLabel(
                    AppLocalizations.of(context).accountSectionCredit,
                  ),
                  VeriCard(
                    child: Column(
                      children: <Widget>[
                        SettingsRow(
                          icon: Icons.speed_outlined,
                          title: AppLocalizations.of(context).creditLimitLabel,
                          trailing: currentAccount.creditLimit == null
                              ? AppLocalizations.of(context).notSet
                              : formatMoney(
                                  currentAccount.creditLimit!,
                                  currentAccount.currencyCode,
                                ),
                          trailingIcon: Icons.chevron_right,
                          onTap: () => _editCreditLimit(currentAccount),
                        ),
                        const Divider(height: 1),
                        SettingsRow(
                          icon: Icons.event_note_outlined,
                          title: AppLocalizations.of(context).statementDay,
                          trailing: currentAccount.statementDay == null
                              ? AppLocalizations.of(context).notSet
                              : AppLocalizations.of(
                                  context,
                                ).monthlyDayLabel(currentAccount.statementDay!),
                          trailingIcon: Icons.chevron_right,
                          onTap: () => _pickBillingDay(currentAccount, false),
                        ),
                        const Divider(height: 1),
                        SettingsRow(
                          icon: Icons.event_available_outlined,
                          title: AppLocalizations.of(context).dueDay,
                          trailing: currentAccount.dueDay == null
                              ? AppLocalizations.of(context).notSet
                              : AppLocalizations.of(
                                  context,
                                ).monthlyDayLabel(currentAccount.dueDay!),
                          trailingIcon: Icons.chevron_right,
                          onTap: () => _pickBillingDay(currentAccount, true),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SectionLabel(
                  AppLocalizations.of(context).accountSectionDisplay,
                ),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      CompactSwitchRow(
                        icon: Icons.account_balance_wallet_outlined,
                        title: Text(
                          AppLocalizations.of(context).includeInAssets,
                        ),
                        value: currentAccount.includeInAssets,
                        onChanged: (value) => setState(
                          () => _draftAccount = currentAccount.copyWith(
                            includeInAssets: value,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      CompactSwitchRow(
                        icon: Icons.visibility_off_outlined,
                        title: Text(AppLocalizations.of(context).accountHide),
                        value: currentAccount.hidden,
                        onChanged: (value) => setState(() {
                          _draftAccount = currentAccount.copyWith(
                            hidden: value,
                          );
                          if (value) {
                            _draftDefault = false;
                          }
                        }),
                      ),
                      // 设为该账本记账时的默认付款账户（关闭即清除默认）。隐藏账户不提供。
                      if (!currentAccount.hidden) ...<Widget>[
                        const Divider(height: 1),
                        CompactSwitchRow(
                          icon: Icons.push_pin_outlined,
                          title: Text(
                            AppLocalizations.of(context).setAsDefaultAccount,
                          ),
                          subtitle: Text(
                            AppLocalizations.of(
                              context,
                            ).setAsDefaultAccountHint,
                          ),
                          value: _draftDefault,
                          onChanged: (value) =>
                              setState(() => _draftDefault = value),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionLabel(AppLocalizations.of(context).accountSectionDanger),
                VeriCard(
                  child: SettingsRow(
                    icon: Icons.delete_outline,
                    title: AppLocalizations.of(context).accountDelete,
                    contentColor: veriExpense,
                    trailing: entries.isEmpty
                        ? AppLocalizations.of(context).deletableLabel
                        : AppLocalizations.of(context).hasEntriesLabel,
                    trailingIcon: Icons.chevron_right,
                    onTap: () async {
                      final completed = await confirmDeleteAccount(
                        context,
                        persistedAccount,
                        entries,
                      );
                      if (completed && mounted) {
                        _exitController.exit();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editBalance(Account account, double balance) async {
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).balanceAdjustTooltip,
      initialAmount: balance,
      allowNegative: true,
      allowZero: true,
    );
    if (amount == null || !mounted) {
      return;
    }
    var recordEntry = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).balanceEditConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppLocalizations.of(context).balanceEditConfirmMessage(
                  account.name,
                  formatMoney(amount, account.currencyCode),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: recordEntry,
                onChanged: (value) =>
                    setDialogState(() => recordEntry = value ?? true),
                title: Text(AppLocalizations.of(context).balanceEditRecord),
                subtitle: Text(
                  AppLocalizations.of(context).balanceEditRecordDesc,
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppLocalizations.of(context).commonConfirm),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final controller = VeriFinScope.of(context);
    if (recordEntry) {
      final saved = controller.adjustAccountBalance(
        account,
        amount,
        note: AppLocalizations.of(context).balanceAdjustNote,
      );
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).balanceAdjustMissingRate(account.currencyCode),
            ),
          ),
        );
      }
    } else {
      controller.rebaseAccountBalance(account, amount);
    }
  }

  Future<void> _startEntryForAccount(
    BuildContext context,
    Account account,
  ) async {
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).quickEntry,
    );
    if (!context.mounted || amount == null || amount <= 0) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => EntryDetailPage(
          initialAmount: amount,
          initialAccountId: account.id,
        ),
      ),
    );
  }

  Future<void> _pickAccountType(Account account) async {
    final selected = await showOptionSheet<AccountType>(
      context: context,
      title: AppLocalizations.of(context).accountTypePickerTitle,
      values: AccountType.values,
      selected: account.type,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null && mounted) {
      final losesCredit = !selected.supportsCredit;
      setState(() {
        _draftAccount = account.copyWith(
          type: selected,
          cardLast4: selected.supportsCardLast4 ? account.cardLast4 : '',
          cardNumber: selected.supportsCardLast4 ? account.cardNumber : '',
          clearCreditLimit: losesCredit,
          clearStatementDay: losesCredit,
          clearDueDay: losesCredit,
        );
      });
    }
  }

  Future<void> _pickAccountCurrency(
    Account persistedAccount,
    Account currentAccount,
  ) async {
    var controller = VeriFinScope.of(context);
    var accountDraft = currentAccount;
    if (controller.accountCurrencyLocked(persistedAccount)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).accountCurrencyLocked),
        ),
      );
      return;
    }
    if (controller.activeBook.currencySetupStatus ==
        CurrencySetupStatus.legacyUnconfirmed) {
      final confirmed = await confirmLegacyLedgerCurrency(
        context: context,
        book: controller.activeBook,
      );
      if (!mounted || !confirmed) return;
      controller = VeriFinScope.of(context);
      final latest = controller.accounts.firstWhere(
        (account) => account.id == persistedAccount.id,
        orElse: () => currentAccount,
      );
      setState(() {
        _initialAccount = latest;
        _draftAccount = latest;
      });
      accountDraft = latest;
    }
    final selected = await showCurrencyPickerSheet(
      context: context,
      title: AppLocalizations.of(context).selectAccountCurrency,
      selectedCode: accountDraft.currencyCode,
      preferredCodes: controller.accounts.map(
        (account) => account.currencyCode,
      ),
    );
    if (selected != null && mounted) {
      setState(
        () =>
            _draftAccount = accountDraft.copyWith(currencyCode: selected.code),
      );
    }
  }

  Future<void> _editAccountName(Account account) async {
    final name = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).accountNameEditTitle,
      label: AppLocalizations.of(context).accountNameLabel,
      initialValue: account.name,
    );
    if (name != null && mounted) {
      final suggested = suggestedAccountIconCode(name);
      setState(() {
        _draftAccount = account.copyWith(
          name: name,
          iconCode: suggested ?? account.iconCode,
        );
      });
    }
  }

  Future<void> _editCard(Account account) async {
    final result = await showCardNumberDialog(
      context: context,
      initialNumber: account.cardNumber,
      initialLast4: account.cardLast4,
      initialFollows: account.cardLast4Follows,
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _draftAccount = account.copyWith(
        cardNumber: result.number,
        cardLast4: result.last4,
        cardLast4Follows: result.follows,
      );
    });
  }

  Future<void> _copyCardNumber(String cardNumber) async {
    await Clipboard.setData(ClipboardData(text: cardNumber));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)),
    );
  }

  void _startRepayment(Account account) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => CreditRepaymentPage(account: account),
      ),
    );
  }

  /// 设置信用额度；输入 0 视为清除额度（不再展示可用额度）。
  Future<void> _editCreditLimit(Account account) async {
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).creditLimitEditTitle,
      initialAmount: account.creditLimit,
      allowZero: true,
    );
    if (amount == null || !mounted) {
      return;
    }
    setState(() {
      _draftAccount = account.copyWith(
        creditLimit: amount <= 0 ? null : amount,
        clearCreditLimit: amount <= 0,
      );
    });
  }

  Future<void> _pickAccountIcon(Account account) async {
    final selected = await showAccountIconSheet(
      context: context,
      selected: account.iconCode,
    );
    if (selected != null && mounted) {
      setState(() => _draftAccount = account.copyWith(iconCode: selected));
    }
  }

  /// 选择信用卡账单日 / 还款日（1–28 或不设置）。
  Future<void> _pickBillingDay(Account account, bool isDue) async {
    const clearValue = 0;
    final current =
        (isDue ? account.dueDay : account.statementDay) ?? clearValue;
    final selected = await showOptionSheet<int>(
      context: context,
      title: isDue
          ? AppLocalizations.of(context).pickDueDay
          : AppLocalizations.of(context).pickStatementDay,
      values: <int>[clearValue, for (var d = 1; d <= 28; d++) d],
      selected: current,
      labelOf: (value) => value == clearValue
          ? AppLocalizations.of(context).clearOption
          : AppLocalizations.of(context).monthlyDayLabel(value),
    );
    if (selected == null || !mounted) {
      return;
    }
    if (isDue) {
      setState(() {
        _draftAccount = account.copyWith(
          dueDay: selected == clearValue ? null : selected,
          clearDueDay: selected == clearValue,
        );
      });
    } else {
      setState(() {
        _draftAccount = account.copyWith(
          statementDay: selected == clearValue ? null : selected,
          clearStatementDay: selected == clearValue,
        );
      });
    }
  }

  Future<void> _editAccountNote(Account account) async {
    final note = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).accountNoteEditTitle,
      label: AppLocalizations.of(context).commonNote,
      initialValue: account.note,
      allowEmpty: true,
    );
    if (note != null && mounted) {
      setState(() => _draftAccount = account.copyWith(note: note));
    }
  }

  Future<void> _pickAccountGroup(Account account) async {
    final controller = VeriFinScope.of(context);
    final groups = controller.accountGroups;
    final values = <String>['ungrouped', ...groups.map((group) => group.id)];
    final selected = await showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).accountGroupPickerTitle,
      values: values,
      selected: account.groupId ?? 'ungrouped',
      labelOf: (value) {
        if (value == 'ungrouped') {
          return AppLocalizations.of(context).assetsUngrouped;
        }
        return groups.firstWhere((group) => group.id == value).name;
      },
    );
    if (selected != null && mounted) {
      setState(() => _draftAccount = account.copyWith(groupId: selected));
    }
  }

  bool get _isDirty =>
      !mapEquals(_initialAccount.toJson(), _draftAccount.toJson()) ||
      _initialDefault != _draftDefault;

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(() {
        _initialAccount = _draftAccount;
        _initialDefault = _draftDefault;
      });
      _exitController.exit();
    }
  }

  Future<bool> _save() async {
    final controller = VeriFinScope.of(context);
    if (!await controller.saveAccountDraft(_draftAccount)) {
      return false;
    }
    if (_initialDefault != _draftDefault &&
        !await controller.saveDefaultAccountDraft(
          _draftDefault ? _draftAccount.id : null,
        )) {
      return false;
    }
    return true;
  }
}

class _MiniSegmentedToggle extends StatelessWidget {
  const _MiniSegmentedToggle({
    required this.value,
    required this.leftLabel,
    required this.rightLabel,
    required this.onChanged,
  });

  final bool value;
  final String leftLabel;
  final String rightLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(veriRadiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _MiniSegmentButton(
            label: leftLabel,
            selected: !value,
            onTap: () => onChanged(false),
          ),
          _MiniSegmentButton(
            label: rightLabel,
            selected: value,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _MiniSegmentButton extends StatelessWidget {
  const _MiniSegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.surface
          : Colors.transparent,
      borderRadius: BorderRadius.circular(veriRadiusSm - 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm - 2),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: selected ? 0.88 : 0.48),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountReportPage extends StatelessWidget {
  const AccountReportPage({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final currentAccount = controller.accounts.firstWhere(
      (item) => item.id == account.id,
      orElse: () => account,
    );
    final entries = controller.entries
        .where((entry) => entryTouchesAccount(entry, currentAccount.id))
        .toList();
    final expense = sumByType(entries, EntryType.expense);
    final income = sumByType(entries, EntryType.income);
    final balance = controller.accountBalance(currentAccount);
    final reportBalanceValues = accountBalanceSeries(currentAccount, entries);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).accountReportTitle,
                subtitle: currentAccount.name,
                showBack: true,
              ),
              const SizedBox(height: 10),
              VeriCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 16,
                ),
                child: Row(
                  children: <Widget>[
                    SummaryMetric(
                      label: AppLocalizations.of(context).currentBalance,
                      value: formatMoney(balance, currentAccount.currencyCode),
                      color: balance < 0 ? veriExpense : veriRoyal,
                    ),
                    SummaryMetric(
                      label: AppLocalizations.of(context).entryTypeIncome,
                      value: formatAmount(income),
                      color: veriIncome,
                    ),
                    SummaryMetric(
                      label: AppLocalizations.of(context).entryTypeExpense,
                      value: formatExpenseAmount(expense),
                      color: isZeroAmount(expense)
                          ? Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.48)
                          : veriExpense,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionTitle(
                      title: AppLocalizations.of(context).balanceTrend,
                      trailing: AppLocalizations.of(context).thisMonth,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 156,
                      child: InteractiveTrendChart(
                        color: veriRoyal,
                        values: reportBalanceValues,
                        xLabels: monthAxisLabels(DateTime.now()),
                        yLabels: balanceAxisLabels(reportBalanceValues),
                        labelColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.50),
                        tooltipOf: (index) => ChartTooltip(
                          title: AppLocalizations.of(context).dateMonthDay(
                            DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              index + 1,
                            ),
                          ),
                          lines: <ChartTooltipLine>[
                            ChartTooltipLine(
                              text: AppLocalizations.of(context).balanceAmount(
                                formatMoney(
                                  reportBalanceValues[index],
                                  currentAccount.currencyCode,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionTitle(
                      title: AppLocalizations.of(context).panelRecentLabel,
                      trailing: null,
                    ),
                    const SizedBox(height: 6),
                    if (entries.isEmpty)
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: AppLocalizations.of(context).noEntriesTitle,
                        description: AppLocalizations.of(
                          context,
                        ).accountNoEntriesDesc,
                      )
                    else
                      ...entries
                          .where((e) => e.type != EntryType.refund)
                          .take(6)
                          .map(
                            (entry) => TransactionTile(
                              entry,
                              accounts: controller.accounts,
                              categories: controller.categories,
                              tags: controller.tags,
                              showDate: true,
                              baseCurrencyCode:
                                  controller.activeBook.baseCurrencyCode,
                              onTap: () => openEntryDetail(context, entry),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 信用卡还款提醒条：展示下一个还款日与剩余天数。
class _CreditCardDueBanner extends StatelessWidget {
  const _CreditCardDueBanner({required this.dueDay});

  final int dueDay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final due = nextDueDate(dueDay, now);
    final days = daysUntilDue(dueDay, now);
    final urgent = days <= 3;
    final color = urgent ? veriExpense : veriRoyal;
    final l10n = AppLocalizations.of(context);
    final daysText = days == 0 ? l10n.dueToday : l10n.dueInDays(days);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(veriRadiusMd),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.event_available_outlined, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${l10n.dueDay} ${l10n.dateMonthDay(due)} · $daysText',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.monthlyRepayLine(dueDay),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 信用类账户（信用卡 / 信用账户）额度与本期账单卡片。
/// 设了额度展示已用 / 可用 + 使用进度条；设了账单日展示本期账单（当前账单周期净消费）。
class _CreditSummaryCard extends StatelessWidget {
  const _CreditSummaryCard({
    required this.account,
    required this.balance,
    required this.entries,
  });

  final Account account;
  final double balance;
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final limit = account.creditLimit;
    final statementDay = account.statementDay;
    final used = usedCredit(balance);

    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (limit != null) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.creditLimitLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  formatMoney(limit, account.currencyCode),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(veriRadiusSm),
              child: LinearProgressIndicator(
                value: limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: veriBlue,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _CreditStat(
                    label: l10n.creditUsedLabel,
                    value: formatMoney(used, account.currencyCode),
                  ),
                ),
                Expanded(
                  child: _CreditStat(
                    label: l10n.creditAvailableLabel,
                    value: formatMoney(
                      availableCredit(limit, balance) ?? 0,
                      account.currencyCode,
                    ),
                    highlight: true,
                  ),
                ),
              ],
            ),
          ],
          if (limit != null && statementDay != null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
          if (statementDay != null)
            _CreditStat(
              label: l10n.currentBillLabel,
              value: formatMoney(
                billingCycleExpense(
                  entries,
                  account.id,
                  currentBillingCycle(statementDay, DateTime.now()),
                ),
                account.currencyCode,
              ),
              hint: _billingHint(l10n, statementDay, account.dueDay),
            ),
        ],
      ),
    );
  }

  String _billingHint(AppLocalizations l10n, int statementDay, int? dueDay) {
    final parts = <String>[
      '${l10n.statementDay} ${l10n.monthlyDayLabel(statementDay)}',
      if (dueDay != null) '${l10n.dueDay} ${l10n.monthlyDayLabel(dueDay)}',
    ];
    return parts.join(' · ');
  }
}

class _CreditStat extends StatelessWidget {
  const _CreditStat({
    required this.label,
    required this.value,
    this.hint,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: highlight ? veriBlue : null,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (hint != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}
