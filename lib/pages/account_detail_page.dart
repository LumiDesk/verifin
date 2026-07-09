// 账户详情相关页面：从 assets_pages 拆出。账户详情/编辑、账户报表、
// 信用卡还款日横幅与迷你分段切换控件。
import 'package:flutter/material.dart';

import '../app/account_icon_assets.dart';
import '../app/app_theme.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/credit_card.dart';
import '../app/demo_data.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/series_math.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
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
  bool _monthlyTrend = false;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final currentAccount = controller.accounts.firstWhere(
      (item) => item.id == widget.account.id,
      orElse: () => widget.account,
    );
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

    return Scaffold(
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
                    tooltip: AppLocalizations.of(context).balanceAdjustTooltip,
                    onPressed: () => _editBalance(currentAccount, balance),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (currentAccount.type == AccountType.creditCard &&
                  currentAccount.dueDay != null) ...<Widget>[
                _CreditCardDueBanner(dueDay: currentAccount.dueDay!),
                const SizedBox(height: 10),
              ],
              VeriCard(
                onTap: () => _editBalance(currentAccount, balance),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(AppLocalizations.of(context).currentBalance),
                          const SizedBox(height: 6),
                          Text(
                            formatAmount(balance),
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
                              text: AppLocalizations.of(context).balanceAmount(
                                formatAmount(balanceTrendValues[index]),
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
                                AccountReportPage(account: currentAccount),
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
                          tooltip: AppLocalizations.of(context).addEntryTooltip,
                          onPressed: () =>
                              _startEntryForAccount(context, currentAccount),
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
                          .take(3)
                          .map(
                            (entry) => TransactionTile(
                              entry,
                              accounts: controller.accounts,
                              categories: controller.categories,
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
              VeriCard(
                child: Column(
                  children: <Widget>[
                    CompactSwitchRow(
                      icon: Icons.account_balance_wallet_outlined,
                      title: Text(AppLocalizations.of(context).includeInAssets),
                      value: currentAccount.includeInAssets,
                      onChanged: (value) {
                        controller.updateAccount(
                          currentAccount.copyWith(includeInAssets: value),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    CompactSwitchRow(
                      icon: Icons.visibility_off_outlined,
                      title: Text(AppLocalizations.of(context).accountHide),
                      value: currentAccount.hidden,
                      onChanged: (value) {
                        controller.updateAccount(
                          currentAccount.copyWith(hidden: value),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
                    const Divider(),
                    SettingsRow(
                      icon: Icons.badge_outlined,
                      title: AppLocalizations.of(context).commonName,
                      trailing: currentAccount.name,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _editAccountName(currentAccount),
                    ),
                    const Divider(),
                    if (currentAccount.type.supportsCardLast4) ...<Widget>[
                      SettingsRow(
                        icon: Icons.credit_card,
                        title: AppLocalizations.of(context).cardLast4Label,
                        trailing: currentAccount.cardLast4.isEmpty
                            ? AppLocalizations.of(context).notSet
                            : currentAccount.cardLast4,
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _editCardLast4(currentAccount),
                      ),
                      const Divider(),
                    ],
                    if (currentAccount.type ==
                        AccountType.creditCard) ...<Widget>[
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
                      const Divider(),
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
                      const Divider(),
                    ],
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
                    const Divider(),
                    SettingsRow(
                      icon: Icons.currency_yuan,
                      title: AppLocalizations.of(context).commonCurrency,
                      trailing: AppLocalizations.of(context).currencyCny,
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.notes,
                      title: AppLocalizations.of(context).commonNote,
                      trailing: currentAccount.note.isEmpty
                          ? AppLocalizations.of(context).commonNoneShort
                          : currentAccount.note,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _editAccountNote(currentAccount),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.folder_outlined,
                      title: AppLocalizations.of(context).commonGroup,
                      trailing: groupName,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _pickAccountGroup(currentAccount),
                    ),
                    const Divider(),
                    // 设为该账本记账时的默认付款账户（关闭即清除默认）。隐藏账户不提供。
                    if (!currentAccount.hidden)
                      CompactSwitchRow(
                        icon: Icons.push_pin_outlined,
                        title: Text(
                          AppLocalizations.of(context).setAsDefaultAccount,
                        ),
                        subtitle: Text(
                          AppLocalizations.of(context).setAsDefaultAccountHint,
                        ),
                        value: controller.defaultAccountId == currentAccount.id,
                        onChanged: (value) => controller.setDefaultAccountId(
                          value ? currentAccount.id : null,
                        ),
                      ),
                    if (!currentAccount.hidden) const Divider(),
                    SettingsRow(
                      icon: Icons.delete_outline,
                      title: AppLocalizations.of(context).accountDelete,
                      trailing: entries.isEmpty
                          ? AppLocalizations.of(context).deletableLabel
                          : AppLocalizations.of(context).hasEntriesLabel,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => confirmDeleteAccount(
                        context,
                        currentAccount,
                        entries,
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
                AppLocalizations.of(
                  context,
                ).balanceEditConfirmMessage(account.name, formatAmount(amount)),
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
      controller.adjustAccountBalance(
        account,
        amount,
        note: AppLocalizations.of(context).balanceAdjustNote,
      );
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
      VeriFinScope.of(context).updateAccount(
        account.copyWith(
          type: selected,
          cardLast4: selected.supportsCardLast4 ? account.cardLast4 : '',
        ),
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
      VeriFinScope.of(context).updateAccount(
        account.copyWith(name: name, iconCode: suggested ?? account.iconCode),
      );
    }
  }

  Future<void> _editCardLast4(Account account) async {
    final cardLast4 = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).cardLast4EditTitle,
      label: AppLocalizations.of(context).cardLast4Label,
      initialValue: account.cardLast4,
      allowEmpty: true,
      keyboardType: TextInputType.number,
    );
    if (cardLast4 == null || !mounted) {
      return;
    }
    final normalized = cardLast4.replaceAll(RegExp(r'\D'), '');
    VeriFinScope.of(context).updateAccount(
      account.copyWith(
        cardLast4: normalized.length > 4
            ? normalized.substring(normalized.length - 4)
            : normalized,
      ),
    );
  }

  Future<void> _pickAccountIcon(Account account) async {
    final selected = await showAccountIconSheet(
      context: context,
      selected: account.iconCode,
    );
    if (selected != null && mounted) {
      VeriFinScope.of(
        context,
      ).updateAccount(account.copyWith(iconCode: selected));
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
    final controller = VeriFinScope.of(context);
    if (isDue) {
      controller.updateAccount(
        account.copyWith(
          dueDay: selected == clearValue ? null : selected,
          clearDueDay: selected == clearValue,
        ),
      );
    } else {
      controller.updateAccount(
        account.copyWith(
          statementDay: selected == clearValue ? null : selected,
          clearStatementDay: selected == clearValue,
        ),
      );
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
      VeriFinScope.of(context).updateAccount(account.copyWith(note: note));
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
      controller.updateAccount(account.copyWith(groupId: selected));
    }
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
                      value: formatAmount(balance),
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
                                formatAmount(reportBalanceValues[index]),
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
                          .take(6)
                          .map(
                            (entry) => TransactionTile(
                              entry,
                              accounts: controller.accounts,
                              categories: controller.categories,
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
