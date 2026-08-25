import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/currency_catalog.dart';
import '../app/currency_math.dart';
import '../app/entry_currency_draft.dart';
import '../app/feedback.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 周期记账规则列表：新增 / 编辑 / 启停 / 删除。
class RecurringRulesPage extends StatefulWidget {
  const RecurringRulesPage({super.key});

  @override
  State<RecurringRulesPage> createState() => _RecurringRulesPageState();
}

class _RecurringRulesPageState extends State<RecurringRulesPage> {
  final EditorExitController _exitController = EditorExitController();
  final Map<String, bool> _initialActive = <String, bool>{};
  final Map<String, bool> _draftActive = <String, bool>{};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _syncRules(VeriFinScope.of(context).recurringRules);
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final rules = controller.recurringRules;
    final missingByRule = controller.dueRecurringMissingRates(DateTime.now());
    _syncRules(rules);

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
                  title: AppLocalizations.of(context).recurringTitle,
                  subtitle: AppLocalizations.of(context).recurringSubtitle,
                  showBack: true,
                  actions: <Widget>[
                    HeaderAction(
                      icon: Icons.add,
                      tooltip: AppLocalizations.of(context).recurringAddTooltip,
                      onPressed: () => _openEditor(context, null),
                    ),
                    SaveHeaderAction(onPressed: _isDirty ? _saveAndExit : null),
                  ],
                ),
                const SizedBox(height: 10),
                if (missingByRule.isNotEmpty) ...<Widget>[
                  VeriCard(
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.currency_exchange, color: veriWarning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).recurringMissingRateCount(missingByRule.length),
                          ),
                        ),
                        TextButton(
                          onPressed: _retryDue,
                          child: Text(
                            AppLocalizations.of(context).recurringRetryNow,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (rules.isEmpty)
                  VeriCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context).recurringEmpty,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                        ),
                      ),
                    ),
                  )
                else
                  VeriCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        for (final rule in rules)
                          _RecurringRow(
                            rule: rule.copyWith(
                              active: _draftActive[rule.id] ?? rule.active,
                            ),
                            category: controller.categoryById(rule.categoryId),
                            missingCodes:
                                missingByRule[rule.id] ?? const <String>{},
                            onTap: () => _openEditor(context, rule),
                            onToggle: (value) {
                              setState(() => _draftActive[rule.id] = value);
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncRules(List<RecurringRule> rules) {
    final ids = rules.map((rule) => rule.id).toSet();
    _initialActive.removeWhere((id, _) => !ids.contains(id));
    _draftActive.removeWhere((id, _) => !ids.contains(id));
    for (final rule in rules) {
      _initialActive.putIfAbsent(rule.id, () => rule.active);
      _draftActive.putIfAbsent(rule.id, () => rule.active);
    }
  }

  bool get _isDirty {
    if (_draftActive.length != _initialActive.length) {
      return true;
    }
    return _draftActive.entries.any(
      (entry) => _initialActive[entry.key] != entry.value,
    );
  }

  Future<void> _openEditor(BuildContext context, RecurringRule? rule) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => RecurringRuleEditPage(rule: rule),
      ),
    );
    if (mounted) {
      setState(() {
        _syncRules(VeriFinScope.of(context).recurringRules);
      });
    }
  }

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(() {
        _initialActive
          ..clear()
          ..addAll(_draftActive);
      });
      _exitController.exit();
    }
  }

  Future<bool> _save() =>
      VeriFinScope.of(context).saveRecurringActiveDraft(_draftActive);

  Future<void> _retryDue() async {
    final controller = VeriFinScope.of(context);
    final generated = await controller.applyDueRecurring(DateTime.now());
    if (!mounted) return;
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: generated < 0
            ? AppLocalizations.of(context).saveFailed
            : AppLocalizations.of(context).recurringGeneratedCount(generated),
        tone: generated < 0 ? VeriFeedbackTone.error : VeriFeedbackTone.success,
        duration: generated < 0
            ? VeriFeedbackDuration.long
            : VeriFeedbackDuration.standard,
        priority: generated < 0
            ? VeriFeedbackPriority.high
            : VeriFeedbackPriority.normal,
        dedupeKey: generated < 0 ? 'recurring-generate' : null,
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({
    required this.rule,
    required this.category,
    required this.missingCodes,
    required this.onTap,
    required this.onToggle,
  });

  final RecurringRule rule;
  final Category category;
  final Set<String> missingCodes;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final sign = switch (rule.type) {
      EntryType.expense => '-',
      EntryType.income => '+',
      EntryType.transfer => '',
      // 周期规则不产生退款，仅作穷尽兜底。
      EntryType.refund => '+',
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: <Widget>[
            CategoryIconBox(
              iconCode: category.iconCode,
              color: colorForType(rule.type),
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    rule.note.isEmpty ? category.label : rule.note,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${rule.frequency.label(AppLocalizations.of(context))} · $sign${formatUserMoney(rule.amount, rule.currencyCode)}'
                    ' · ${AppLocalizations.of(context).nextRun(AppLocalizations.of(context).dateMonthDay(rule.nextRunDate))}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (missingCodes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      '${AppLocalizations.of(context).recurringMissingRate}: ${(missingCodes.toList()..sort()).join(', ')}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: veriWarning,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(value: rule.active, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

/// 周期规则新增 / 编辑表单。
typedef _RecurringRuleDraftSnapshot = ({
  EntryType type,
  double amount,
  String currencyCode,
  double? accountAmount,
  double? toAccountAmount,
  double baseAmount,
  RecurringRatePolicy ratePolicy,
  String categoryId,
  String accountId,
  String? toAccountId,
  RecurringFrequency frequency,
  DateTime startDate,
  String note,
});

class RecurringRuleEditPage extends StatefulWidget {
  const RecurringRuleEditPage({super.key, this.rule});

  final RecurringRule? rule;

  @override
  State<RecurringRuleEditPage> createState() => _RecurringRuleEditPageState();
}

class _RecurringRuleEditPageState extends State<RecurringRuleEditPage> {
  final EditorExitController _exitController = EditorExitController();
  late EntryType _type;
  late double _amount;
  late String _currencyCode;
  double? _accountAmount;
  double? _toAccountAmount;
  double _baseAmount = 0;
  RecurringRatePolicy _ratePolicy = RecurringRatePolicy.latestAvailable;
  bool _currencyTouched = false;
  bool _accountAmountTouched = false;
  bool _toAccountAmountTouched = false;
  bool _baseAmountTouched = false;
  Set<String> _missingRateCodes = <String>{};
  late String _categoryId;
  late String _accountId;
  String? _toAccountId;
  late RecurringFrequency _frequency;
  late DateTime _startDate;
  late final TextEditingController _noteController;
  late _RecurringRuleDraftSnapshot _initialDraft;
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    final controller = VeriFinScope.of(context);
    final rule = widget.rule;
    if (rule != null) {
      _type = rule.type;
      _amount = rule.amount;
      _currencyCode = rule.currencyCode;
      _accountAmount = rule.accountAmount;
      _toAccountAmount = rule.toAccountAmount;
      _baseAmount = rule.baseAmount;
      _ratePolicy = rule.ratePolicy;
      _categoryId = rule.categoryId;
      _accountId = rule.accountId;
      _toAccountId = rule.toAccountId;
      _frequency = rule.frequency;
      _startDate = rule.startDate;
      _noteController = TextEditingController(text: rule.note);
    } else {
      _type = EntryType.expense;
      _amount = 0;
      _categoryId = controller.categoriesForType(EntryType.expense).first.id;
      _accountId = controller.accounts.isEmpty
          ? ''
          : controller.accounts.first.id;
      _currencyCode = controller.accounts.isEmpty
          ? controller.activeBook.baseCurrencyCode
          : controller.accounts.first.currencyCode;
      _frequency = RecurringFrequency.monthly;
      _startDate = dateOnly(DateTime.now());
      _noteController = TextEditingController();
      _resolveAmounts(
        controller,
        controller.accounts,
        forceAccount: true,
        forceToAccount: true,
        forceBase: true,
      );
    }
    _initialDraft = _draftSnapshot;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Account? _findAccount(List<Account> accounts, String? id) {
    if (id == null || id.isEmpty) return null;
    return accounts.where((account) => account.id == id).firstOrNull;
  }

  double? _converted(
    VeriFinController controller,
    double amount,
    String sourceCode,
    String targetCode,
  ) {
    final result = controller.convertAmount(
      amount: amount,
      sourceCurrencyCode: sourceCode,
      targetCurrencyCode: targetCode,
      date: _startDate,
    );
    if (result is ConvertedCurrencyAmount) return result.amount;
    if (result is MissingCurrencyRate) {
      _missingRateCodes.addAll(result.currencyCodes);
    }
    return null;
  }

  void _resolveAmounts(
    VeriFinController controller,
    List<Account> accounts, {
    bool forceAccount = false,
    bool forceToAccount = false,
    bool forceBase = false,
  }) {
    _missingRateCodes = <String>{};
    final account = _findAccount(accounts, _accountId);
    final toAccount = _findAccount(accounts, _toAccountId);
    final baseCode = controller.activeBook.baseCurrencyCode;
    if (_amount <= 0) {
      _accountAmount = _accountId.isEmpty ? null : 0;
      _toAccountAmount = null;
      _baseAmount = 0;
      return;
    }
    if (_type == EntryType.transfer) {
      if (account != null) {
        _currencyCode = account.currencyCode;
        _amount = normalizeCurrencyAmount(_amount, _currencyCode);
        _accountAmount = _amount;
      }
      _baseAmount = 0;
      if (toAccount == null) {
        _toAccountAmount = null;
      } else if (toAccount.currencyCode == _currencyCode) {
        _toAccountAmount = normalizeCurrencyAmount(
          _amount,
          toAccount.currencyCode,
        );
        _toAccountAmountTouched = false;
      } else if (forceToAccount || !_toAccountAmountTouched) {
        _toAccountAmount = _converted(
          controller,
          _amount,
          _currencyCode,
          toAccount.currencyCode,
        );
      }
      return;
    }
    if (account == null) {
      _accountAmount = null;
    } else if (account.currencyCode == _currencyCode) {
      _accountAmount = normalizeCurrencyAmount(_amount, account.currencyCode);
      _accountAmountTouched = false;
    } else if (forceAccount || !_accountAmountTouched) {
      _accountAmount = _converted(
        controller,
        _amount,
        _currencyCode,
        account.currencyCode,
      );
    }
    if (_currencyCode == baseCode) {
      _baseAmount = normalizeCurrencyAmount(_amount, baseCode);
      _baseAmountTouched = false;
    } else if (account?.currencyCode == baseCode && _accountAmount != null) {
      _baseAmount = _accountAmount!;
      _baseAmountTouched = _accountAmountTouched;
    } else if (forceBase || !_baseAmountTouched) {
      _baseAmount =
          _converted(controller, _amount, _currencyCode, baseCode) ?? 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final accounts = controller.accounts;
    final category = controller.categoryById(_categoryId);
    final account = accounts.where((a) => a.id == _accountId).firstOrNull;

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
                  title: widget.rule == null
                      ? AppLocalizations.of(context).recurringNewTitle
                      : AppLocalizations.of(context).recurringEditTitle,
                  showBack: true,
                  actions: <Widget>[
                    if (widget.rule != null)
                      HeaderAction(
                        icon: Icons.delete_outline,
                        tooltip: AppLocalizations.of(
                          context,
                        ).recurringDeleteTooltip,
                        destructive: true,
                        onPressed: _delete,
                      ),
                    SaveHeaderAction(
                      onPressed: _isDirty && _canSave(accounts)
                          ? _saveAndExit
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SegmentedButton<EntryType>(
                  segments: EntryType.userSelectable
                      .map(
                        (type) => ButtonSegment<EntryType>(
                          value: type,
                          label: Text(type.label(AppLocalizations.of(context))),
                        ),
                      )
                      .toList(),
                  selected: <EntryType>{_type},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _type = selection.first;
                      _categoryId = controller
                          .categoriesForType(_type)
                          .first
                          .id;
                      if (_type == EntryType.transfer) {
                        _currencyTouched = false;
                      }
                      _resolveAmounts(
                        controller,
                        accounts,
                        forceAccount: true,
                        forceToAccount: true,
                        forceBase: true,
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      DetailInfoRow(
                        label: AppLocalizations.of(context).amountLabel,
                        value: _amount > 0
                            ? formatUserMoney(_amount, _currencyCode)
                            : AppLocalizations.of(context).tapToFill,
                        placeholder: _amount <= 0,
                        onTap: _editAmount,
                      ),
                      DetailInfoRow(
                        label: AppLocalizations.of(context).entryCurrencyLabel,
                        value: _currencyCode,
                        onTap: _type == EntryType.transfer
                            ? null
                            : _pickCurrency,
                      ),
                      DetailInfoRow(
                        label: AppLocalizations.of(context).commonCategory,
                        value: category.label,
                        onTap: _pickCategory,
                      ),
                      DetailInfoRow(
                        label: _type == EntryType.transfer
                            ? AppLocalizations.of(context).transferOutAccount
                            : AppLocalizations.of(context).accountLabel,
                        value: accounts.isEmpty
                            ? AppLocalizations.of(context).addAccountFirst
                            : _accountId.isEmpty
                            ? AppLocalizations.of(context).noAccountLabel
                            : account?.name ??
                                  AppLocalizations.of(context).noAccountLabel,
                        placeholder: accounts.isEmpty,
                        onTap: accounts.isEmpty
                            ? null
                            : () => _pickAccount(false),
                      ),
                      if (_type == EntryType.transfer)
                        DetailInfoRow(
                          label: AppLocalizations.of(context).transferInAccount,
                          value:
                              accounts
                                  .where((a) => a.id == _toAccountId)
                                  .firstOrNull
                                  ?.name ??
                              AppLocalizations.of(context).pleaseSelect,
                          placeholder: _toAccountId == null,
                          onTap: accounts.length < 2
                              ? null
                              : () => _pickAccount(true),
                        ),
                      ..._currencyAmountFields(controller, accounts),
                      VeriAnchoredChoice<RecurringRatePolicy>(
                        values: RecurringRatePolicy.values,
                        selected: _ratePolicy,
                        idOf: (value) => 'recurring_rate_${value.name}',
                        labelOf: (value) =>
                            value == RecurringRatePolicy.latestAvailable
                            ? AppLocalizations.of(
                                context,
                              ).recurringRatePolicyLatest
                            : AppLocalizations.of(
                                context,
                              ).recurringRatePolicyFixed,
                        iconOf: (value) =>
                            value == RecurringRatePolicy.latestAvailable
                            ? Icons.currency_exchange_outlined
                            : Icons.lock_clock_outlined,
                        onSelected: (value) =>
                            setState(() => _ratePolicy = value),
                        semanticLabel: AppLocalizations.of(
                          context,
                        ).recurringRatePolicyLabel,
                        width: 252,
                        builder: (context, openMenu, menuOpen) => DetailInfoRow(
                          label: AppLocalizations.of(
                            context,
                          ).recurringRatePolicyLabel,
                          value:
                              _ratePolicy == RecurringRatePolicy.latestAvailable
                              ? AppLocalizations.of(
                                  context,
                                ).recurringRatePolicyLatest
                              : AppLocalizations.of(
                                  context,
                                ).recurringRatePolicyFixed,
                          onTap: openMenu,
                        ),
                      ),
                      VeriAnchoredChoice<RecurringFrequency>(
                        values: RecurringFrequency.values,
                        selected: _frequency,
                        idOf: (value) => 'recurring_frequency_${value.name}',
                        labelOf: (value) =>
                            value.label(AppLocalizations.of(context)),
                        iconOf: (value) => switch (value) {
                          RecurringFrequency.daily => Icons.today_outlined,
                          RecurringFrequency.weekly => Icons.view_week_outlined,
                          RecurringFrequency.monthly =>
                            Icons.calendar_month_outlined,
                          RecurringFrequency.yearly => Icons.event_outlined,
                        },
                        onSelected: (value) =>
                            setState(() => _frequency = value),
                        semanticLabel: AppLocalizations.of(
                          context,
                        ).pickFrequencyTitle,
                        width: 196,
                        builder: (context, openMenu, menuOpen) => DetailInfoRow(
                          label: AppLocalizations.of(context).frequencyLabel,
                          value: _frequency.label(AppLocalizations.of(context)),
                          onTap: openMenu,
                        ),
                      ),
                      DetailInfoRow(
                        label: AppLocalizations.of(context).startDateLabel,
                        value: AppLocalizations.of(
                          context,
                        ).dateMonthDay(_startDate),
                        onTap: _pickStartDate,
                      ),
                      DetailInfoRow(
                        label: AppLocalizations.of(context).commonNote,
                        value: _noteController.text.trim().isEmpty
                            ? AppLocalizations.of(context).noteHint
                            : _noteController.text.trim(),
                        placeholder: _noteController.text.trim().isEmpty,
                        onTap: _editNote,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canSave(List<Account> accounts) {
    if (_amount <= 0 ||
        (_type != EntryType.transfer && _baseAmount <= 0) ||
        (_accountId.isNotEmpty && (_accountAmount ?? 0) <= 0)) {
      return false;
    }
    if (_type == EntryType.transfer) {
      // 转账两端都需具体账户，且不能相同。
      if (accounts.length < 2 || _accountId.isEmpty) {
        return false;
      }
      if (_toAccountId == null || _toAccountId == _accountId) {
        return false;
      }
      return (_toAccountAmount ?? 0) > 0;
    }
    // 收支：选了具体账户或「无账户」都可保存（与记账页一致）。
    return true;
  }

  List<Widget> _currencyAmountFields(
    VeriFinController controller,
    List<Account> accounts,
  ) {
    final l10n = AppLocalizations.of(context);
    final account = _findAccount(accounts, _accountId);
    final toAccount = _findAccount(accounts, _toAccountId);
    final baseCode = controller.activeBook.baseCurrencyCode;
    final fields = <Widget>[];
    if (_type == EntryType.transfer &&
        toAccount != null &&
        toAccount.currencyCode != _currencyCode) {
      fields.add(
        CurrencyAmountField(
          key: const Key('recurring_to_account_amount'),
          label: l10n.entryTransferInAmount,
          currencyCode: toAccount.currencyCode,
          amount: _toAccountAmount,
          missingText: l10n.exchangeRateNotSet,
          onTap: () => _editToAmount(toAccount.currencyCode),
        ),
      );
    } else if (_type != EntryType.transfer) {
      if (account != null && account.currencyCode != _currencyCode) {
        fields.add(
          CurrencyAmountField(
            key: const Key('recurring_account_amount'),
            label: _type == EntryType.expense
                ? l10n.entryAccountAmountExpense
                : l10n.entryAccountAmountIncome,
            currencyCode: account.currencyCode,
            amount: _accountAmount,
            missingText: l10n.exchangeRateNotSet,
            onTap: () => _editAccountAmount(account.currencyCode),
          ),
        );
      }
      if (_currencyCode != baseCode) {
        fields.add(
          CurrencyAmountField(
            key: const Key('recurring_base_amount'),
            label: l10n.entryLedgerAmountLabel,
            currencyCode: baseCode,
            amount: _baseAmount > 0 ? _baseAmount : null,
            missingText: l10n.exchangeRateNotSet,
            onTap: () => _editBaseAmount(baseCode),
          ),
        );
      }
    }
    if (_missingRateCodes.isNotEmpty) {
      fields.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            l10n.entryMissingRate(
              (_missingRateCodes.toList()..sort()).join(', '),
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: veriWarning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    return fields;
  }

  Future<void> _pickCurrency() async {
    final controller = VeriFinScope.of(context);
    final selected = await showCurrencyPickerSheet(
      context: context,
      title: AppLocalizations.of(context).entryCurrencyPickTitle,
      selectedCode: _currencyCode,
      preferredCodes: <String>[
        controller.activeBook.baseCurrencyCode,
        for (final account in controller.accounts) account.currencyCode,
      ],
    );
    if (!mounted || selected == null || selected.code == _currencyCode) return;
    setState(() {
      _currencyCode = selected.code;
      _currencyTouched = true;
      _amount = normalizeCurrencyAmount(_amount, _currencyCode);
      _accountAmountTouched = false;
      _baseAmountTouched = false;
      _resolveAmounts(
        controller,
        controller.accounts,
        forceAccount: true,
        forceBase: true,
      );
    });
  }

  Future<void> _editAmount() async {
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).amountLabel,
      initialAmount: _amount > 0 ? _amount : null,
      maxFractionDigits: CurrencyCatalog.require(_currencyCode).minorUnit,
    );
    if (amount == null || amount <= 0 || !mounted) {
      return;
    }
    setState(() {
      final controller = VeriFinScope.of(context);
      final previousAmount = _amount;
      _amount = normalizeCurrencyAmount(amount, _currencyCode);
      if (_ratePolicy == RecurringRatePolicy.fixedAmounts) {
        final account = _findAccount(controller.accounts, _accountId);
        final toAccount = _findAccount(controller.accounts, _toAccountId);
        if (account != null) {
          _accountAmount = scaleDependentCurrencyAmount(
            dependentAmount: _accountAmount,
            previousOriginalAmount: previousAmount,
            nextOriginalAmount: _amount,
            targetCurrencyCode: account.currencyCode,
          );
          _accountAmountTouched = true;
        }
        if (toAccount != null) {
          _toAccountAmount = scaleDependentCurrencyAmount(
            dependentAmount: _toAccountAmount,
            previousOriginalAmount: previousAmount,
            nextOriginalAmount: _amount,
            targetCurrencyCode: toAccount.currencyCode,
          );
          _toAccountAmountTouched = true;
        }
        _baseAmount =
            scaleDependentCurrencyAmount(
              dependentAmount: _baseAmount,
              previousOriginalAmount: previousAmount,
              nextOriginalAmount: _amount,
              targetCurrencyCode: controller.activeBook.baseCurrencyCode,
            ) ??
            0;
        _baseAmountTouched = true;
      } else {
        _resolveAmounts(controller, controller.accounts);
      }
    });
  }

  Future<void> _editAccountAmount(String currencyCode) async {
    final value = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).entryAmountInputTitle(
        _type == EntryType.expense
            ? AppLocalizations.of(context).entryAccountAmountExpense
            : AppLocalizations.of(context).entryAccountAmountIncome,
        currencyCode,
      ),
      initialAmount: _accountAmount,
      maxFractionDigits: CurrencyCatalog.require(currencyCode).minorUnit,
    );
    if (!mounted || value == null || value <= 0) return;
    setState(() {
      _accountAmount = normalizeCurrencyAmount(value, currencyCode);
      _accountAmountTouched = true;
      if (currencyCode ==
          VeriFinScope.of(context).activeBook.baseCurrencyCode) {
        _baseAmount = _accountAmount!;
        _baseAmountTouched = true;
      }
      _missingRateCodes.clear();
    });
  }

  Future<void> _editToAmount(String currencyCode) async {
    final value = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).entryAmountInputTitle(
        AppLocalizations.of(context).entryTransferInAmount,
        currencyCode,
      ),
      initialAmount: _toAccountAmount,
      maxFractionDigits: CurrencyCatalog.require(currencyCode).minorUnit,
    );
    if (!mounted || value == null || value <= 0) return;
    setState(() {
      _toAccountAmount = normalizeCurrencyAmount(value, currencyCode);
      _toAccountAmountTouched = true;
      _missingRateCodes.clear();
    });
  }

  Future<void> _editBaseAmount(String baseCode) async {
    final value = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).entryAmountInputTitle(
        AppLocalizations.of(context).entryLedgerAmountLabel,
        baseCode,
      ),
      initialAmount: _baseAmount > 0 ? _baseAmount : null,
      maxFractionDigits: CurrencyCatalog.require(baseCode).minorUnit,
    );
    if (!mounted || value == null || value <= 0) return;
    setState(() {
      _baseAmount = normalizeCurrencyAmount(value, baseCode);
      _baseAmountTouched = true;
      final account = _findAccount(
        VeriFinScope.of(context).accounts,
        _accountId,
      );
      if (account?.currencyCode == baseCode) {
        _accountAmount = _baseAmount;
        _accountAmountTouched = true;
      }
      _missingRateCodes.clear();
    });
  }

  Future<void> _pickCategory() async {
    final controller = VeriFinScope.of(context);
    final selected = await showCategoryPickerSheet(
      context,
      categories: controller.categoriesForType(_type),
      selectedId: _categoryId,
    );
    if (selected != null && mounted) {
      setState(() => _categoryId = selected);
    }
  }

  Future<void> _pickAccount(bool toAccount) async {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final accounts = controller.accounts;
    // 兜底：无账户时不弹选择器。调用点也各有守卫，这里再挡一层。
    if (accounts.isEmpty) {
      return;
    }
    final isTransfer = _type == EntryType.transfer;
    // 转入账户不能与转出账户相同。
    final pickable = toAccount
        ? accounts.where((a) => a.id != _accountId).toList()
        : accounts;
    if (pickable.isEmpty) {
      return;
    }
    // 与记账 / 编辑交易用同一个账户选择器：带账户图标、余额、卡号后四位；收支的
    // 转出账户可选「无账户」，转账两端都需具体账户故不提供。
    final selected = await showAccountPickerSheet(
      context: context,
      title: toAccount
          ? l10n.pickTransferInAccount
          : (isTransfer ? l10n.pickTransferOutAccount : l10n.pickAccountTitle),
      accounts: pickable,
      selectedId: toAccount ? _toAccountId : _accountId,
      balanceOf: controller.accountBalance,
      noneLabel: (toAccount || isTransfer) ? null : l10n.noAccountLabel,
      noneHint: (toAccount || isTransfer) ? null : l10n.noAccountHint,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      if (toAccount) {
        _toAccountId = selected.id;
        _toAccountAmountTouched = false;
      } else {
        // 选到「无账户」时 selected.id 为空串，正是 RecurringRule 表达无账户的方式。
        _accountId = selected.id;
        if (!_currencyTouched || isTransfer) {
          _currencyCode = selected.id.isEmpty
              ? controller.activeBook.baseCurrencyCode
              : selected.currencyCode;
        }
        _accountAmountTouched = false;
        _baseAmountTouched = false;
      }
      _resolveAmounts(
        controller,
        accounts,
        forceAccount: !toAccount,
        forceToAccount: true,
        forceBase: !toAccount,
      );
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = dateOnly(picked);
        final controller = VeriFinScope.of(context);
        _resolveAmounts(controller, controller.accounts);
      });
    }
  }

  Future<void> _editNote() async {
    final note = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).commonNote,
      label: AppLocalizations.of(context).commonNote,
      initialValue: _noteController.text,
      allowEmpty: true,
    );
    if (note != null && mounted) {
      setState(() => _noteController.text = note);
    }
  }

  _RecurringRuleDraftSnapshot get _draftSnapshot => (
    type: _type,
    amount: _amount,
    currencyCode: _currencyCode,
    accountAmount: _accountAmount,
    toAccountAmount: _type == EntryType.transfer ? _toAccountAmount : null,
    baseAmount: _type == EntryType.transfer ? 0 : _baseAmount,
    ratePolicy: _ratePolicy,
    categoryId: _categoryId,
    accountId: _accountId,
    toAccountId: _type == EntryType.transfer ? _toAccountId : null,
    frequency: _frequency,
    startDate: _startDate,
    note: _noteController.text.trim(),
  );

  bool get _isDirty => _initialized && _draftSnapshot != _initialDraft;

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(() => _initialDraft = _draftSnapshot);
      _exitController.exit();
    }
  }

  Future<bool> _save() async {
    final controller = VeriFinScope.of(context);
    final existing = widget.rule;
    final draft = existing == null
        ? RecurringRule(
            id: 'recur_${DateTime.now().microsecondsSinceEpoch}',
            bookId: controller.activeBook.id,
            type: _type,
            amount: normalizeCurrencyAmount(_amount, _currencyCode),
            currencyCode: _currencyCode,
            accountAmount: _accountId.isEmpty ? null : _accountAmount,
            toAccountAmount: _type == EntryType.transfer
                ? _toAccountAmount
                : null,
            baseAmount: _type == EntryType.transfer ? 0 : _baseAmount,
            ratePolicy: _ratePolicy,
            categoryId: _categoryId,
            accountId: _accountId,
            toAccountId: _type == EntryType.transfer ? _toAccountId : null,
            note: _noteController.text.trim(),
            frequency: _frequency,
            startDate: _startDate,
            nextRunDate: _startDate,
          )
        : existing.copyWith(
            type: _type,
            amount: normalizeCurrencyAmount(_amount, _currencyCode),
            currencyCode: _currencyCode,
            accountAmount: _accountId.isEmpty ? null : _accountAmount,
            clearAccountAmount: _accountId.isEmpty,
            toAccountAmount: _type == EntryType.transfer
                ? _toAccountAmount
                : null,
            clearToAccountAmount: _type != EntryType.transfer,
            baseAmount: _type == EntryType.transfer ? 0 : _baseAmount,
            ratePolicy: _ratePolicy,
            categoryId: _categoryId,
            accountId: _accountId,
            toAccountId: _type == EntryType.transfer ? _toAccountId : null,
            clearToAccountId: _type != EntryType.transfer,
            note: _noteController.text.trim(),
            frequency: _frequency,
            startDate: _startDate,
          );
    if (!await controller.saveRecurringRuleDraft(
      draft,
      isNew: existing == null,
    )) {
      return false;
    }
    // 立即补记已到期的交易。
    await controller.applyDueRecurring(DateTime.now());
    return true;
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: AppLocalizations.of(context).recurringDeleteTitle,
      message: AppLocalizations.of(context).recurringDeleteMessage,
      confirmLabel: AppLocalizations.of(context).commonDelete,
      destructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    VeriFinScope.of(context).deleteRecurringRule(widget.rule!.id);
    _exitController.exit();
  }
}
