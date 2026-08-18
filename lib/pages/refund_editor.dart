import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/currency_catalog.dart';
import '../app/currency_math.dart';
import '../app/model_lookup.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

class RefundEditResult {
  const RefundEditResult.saved(this.refund) : deleted = false;

  const RefundEditResult.deleted() : refund = null, deleted = true;

  final LedgerEntry? refund;
  final bool deleted;
}

/// Controlled refund editor section used by the transaction aggregate draft.
class RefundSection extends StatelessWidget {
  const RefundSection({
    super.key,
    required this.expense,
    required this.refunds,
    required this.onChanged,
  });

  final LedgerEntry expense;
  final List<LedgerEntry> refunds;
  final ValueChanged<List<LedgerEntry>> onChanged;

  double get _remaining {
    final total = refunds.fold<double>(0, (sum, refund) => sum + refund.amount);
    return (expense.amount - total).clamp(0.0, expense.amount).toDouble();
  }

  double get _settledBaseTotal => refunds
      .where((refund) => refund.isSettledRefund)
      .fold<double>(0, (sum, refund) => sum + refund.baseAmount);

  List<LedgerEntry> get _sortedRefunds =>
      List<LedgerEntry>.of(refunds)..sort((a, b) {
        final aDate = a.settledAt ?? a.occurredAt;
        final bDate = b.settledAt ?? b.occurredAt;
        return bDate.compareTo(aDate);
      });

  Future<void> _edit(BuildContext context, LedgerEntry? existing) async {
    final result = await showRefundSheet(
      context: context,
      expense: expense,
      refunds: refunds,
      existing: existing,
    );
    if (result == null || !context.mounted) {
      return;
    }
    final next = List<LedgerEntry>.of(refunds);
    if (result.deleted) {
      next.removeWhere((refund) => refund.id == existing?.id);
    } else {
      final refund = result.refund!;
      final index = next.indexWhere((item) => item.id == refund.id);
      if (index == -1) {
        next.add(refund);
      } else {
        next[index] = refund;
      }
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (expense.type != EntryType.expense) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final pendingTotal = refunds
        .where((refund) => refund.isPendingRefund)
        .fold<double>(0, (sum, refund) => sum + refund.amount);
    final netBaseAmount = (expense.baseAmount - _settledBaseTotal)
        .clamp(0.0, expense.baseAmount)
        .toDouble();

    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.refundRecordsTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (refunds.isNotEmpty)
                Text(
                  l10n.refundNetLabel(
                    formatUserMoney(
                      netBaseAmount,
                      controller.activeBook.baseCurrencyCode,
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
          if (pendingTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l10n.refundPendingTotal(
                  formatUserMoney(pendingTotal, expense.currencyCode),
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: veriBlue),
              ),
            ),
          const SizedBox(height: 4),
          if (refunds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                l10n.refundEmpty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            for (final refund in _sortedRefunds)
              _RefundRow(
                refund: refund,
                accounts: controller.accounts,
                onTap: () => _edit(context, refund),
              ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _remaining <= 0 ? null : () => _edit(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.refundAdd),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundRow extends StatelessWidget {
  const _RefundRow({
    required this.refund,
    required this.accounts,
    required this.onTap,
  });

  final LedgerEntry refund;
  final List<Account> accounts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settled = refund.settledAt != null;
    final date = refund.settledAt ?? refund.occurredAt;
    final accountName = accountDisplayName(
      accounts,
      refund.accountId,
      l10n.commonNoneShort,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              settled ? Icons.check_circle : Icons.schedule,
              size: 20,
              color: settled ? veriIncome : veriBlue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '+${formatUserMoney(refund.amount, refund.currencyCode)} · $accountName',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${settled ? l10n.refundStatusSettled : l10n.refundStatusPending}'
                    ' · ${l10n.dateMonthDay(date)}'
                    '${refund.note.isEmpty ? '' : ' · ${refund.note}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

Future<RefundEditResult?> showRefundSheet({
  required BuildContext context,
  required LedgerEntry expense,
  required List<LedgerEntry> refunds,
  LedgerEntry? existing,
  bool markSettled = false,
}) {
  return showModalBottomSheet<RefundEditResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (_) => _RefundSheet(
      expense: expense,
      refunds: refunds,
      existing: existing,
      markSettled: markSettled,
    ),
  );
}

typedef _RefundSnapshot = ({
  double amount,
  String accountId,
  double? accountAmount,
  double baseAmount,
  bool settled,
  DateTime settledAt,
  DateTime initiatedAt,
  String note,
});

class _RefundSheet extends StatefulWidget {
  const _RefundSheet({
    required this.expense,
    required this.refunds,
    this.existing,
    this.markSettled = false,
  });

  final LedgerEntry expense;
  final List<LedgerEntry> refunds;
  final LedgerEntry? existing;
  final bool markSettled;

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  final EditorExitController _exitController = EditorExitController();
  late final String _refundId;
  late double _amount;
  late String _accountId;
  double? _accountAmount;
  late double _baseAmount;
  bool _accountAmountTouched = false;
  bool _baseAmountTouched = false;
  ConversionSource _conversionSource = ConversionSource.identity;
  late bool _settled;
  late DateTime _settledAt;
  late DateTime _initiatedAt;
  late String _note;
  late _RefundSnapshot _initialSnapshot;
  RefundEditResult? _result;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _refundId =
        widget.existing?.id ??
        'entry_refund_${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    final existing = widget.existing;
    if (existing != null) {
      _amount = existing.amount;
      _accountId = existing.accountId;
      _accountAmount = existing.accountAmount;
      _baseAmount = existing.baseAmount;
      _conversionSource = existing.conversionSource;
      _settled = existing.settledAt != null;
      _settledAt = existing.settledAt ?? DateTime.now();
      _initiatedAt = existing.occurredAt;
      _note = existing.note;
    } else {
      _amount = _maxRefund;
      _accountId = widget.expense.accountId;
      _baseAmount = 0;
      _settled = true;
      _settledAt = DateTime.now();
      _initiatedAt = DateTime.now();
      _note = '';
      _resolveAmounts(forceAccount: true, forceBase: true);
    }
    _initialSnapshot = _snapshot;
    if (existing != null && widget.markSettled && !_settled) {
      _settled = true;
      _settledAt = DateTime.now();
    }
  }

  double get _maxRefund {
    final otherTotal = widget.refunds
        .where((refund) => refund.id != widget.existing?.id)
        .fold<double>(0, (sum, refund) => sum + refund.amount);
    return (widget.expense.amount - otherTotal)
        .clamp(0.0, widget.expense.amount)
        .toDouble();
  }

  Account? get _selectedAccount {
    if (_accountId.isEmpty) return null;
    return VeriFinScope.of(
      context,
    ).accounts.where((account) => account.id == _accountId).firstOrNull;
  }

  void _resolveAmounts({bool forceAccount = false, bool forceBase = false}) {
    final controller = VeriFinScope.of(context);
    final expense = widget.expense;
    final baseCode = controller.activeBook.baseCurrencyCode;
    if ((forceBase || !_baseAmountTouched) && expense.amount > 0) {
      _baseAmount = normalizeCurrencyAmount(
        expense.baseAmount * _amount / expense.amount,
        baseCode,
      );
    }
    final account = _selectedAccount;
    if (account == null) {
      _accountAmount = null;
    } else if (forceAccount || !_accountAmountTouched) {
      if (account.id == expense.accountId && expense.accountAmount != null) {
        _accountAmount = normalizeCurrencyAmount(
          expense.accountAmount! * _amount / expense.amount,
          account.currencyCode,
        );
      } else if (account.currencyCode == baseCode) {
        _accountAmount = _baseAmount;
      } else {
        final converted = controller.convertAmount(
          amount: _amount,
          sourceCurrencyCode: expense.currencyCode,
          targetCurrencyCode: account.currencyCode,
          date: _initiatedAt,
        );
        _accountAmount = converted is ConvertedCurrencyAmount
            ? converted.amount
            : null;
      }
    }
    _conversionSource = _accountAmountTouched || _baseAmountTouched
        ? ConversionSource.manual
        : expense.currencyCode == baseCode &&
              (account == null || account.currencyCode == baseCode)
        ? ConversionSource.identity
        : ConversionSource.rateTable;
  }

  _RefundSnapshot get _snapshot => (
    amount: _amount,
    accountId: _accountId,
    accountAmount: _accountAmount,
    baseAmount: _baseAmount,
    settled: _settled,
    settledAt: _settledAt,
    initiatedAt: _initiatedAt,
    note: _note.trim(),
  );

  bool get _isDirty =>
      _initialized &&
      (widget.existing == null || _snapshot != _initialSnapshot);

  Future<void> _editAmount() async {
    final value = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).refundAmountShort,
      initialAmount: _amount > 0 ? _amount : null,
      maxAmount: _maxRefund,
      maxFractionDigits: CurrencyCatalog.require(
        widget.expense.currencyCode,
      ).minorUnit,
    );
    if (value == null || value <= 0 || !mounted) {
      return;
    }
    setState(() {
      _amount = normalizeCurrencyAmount(value, widget.expense.currencyCode);
      _resolveAmounts();
    });
  }

  Future<void> _pickAccount() async {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final selected = await showAccountPickerSheet(
      context: context,
      title: l10n.refundToAccountLabel,
      accounts: controller.accounts
          .where((account) => !account.hidden)
          .toList(),
      selectedId: _accountId,
      balanceOf: controller.accountBalance,
      noneLabel: l10n.commonNoneShort,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _accountId = selected.id;
      _accountAmountTouched = false;
      _resolveAmounts(forceAccount: true);
    });
  }

  Future<void> _pickDate({required bool arrival}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: arrival ? _settledAt : _initiatedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (arrival) {
        _settledAt = picked;
      } else {
        _initiatedAt = picked;
        _resolveAmounts();
      }
    });
  }

  Future<void> _editAccountAmount(String currencyCode) async {
    final value = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).entryAmountInputTitle(
        AppLocalizations.of(context).refundAccountAmountLabel,
        currencyCode,
      ),
      initialAmount: _accountAmount,
      maxFractionDigits: CurrencyCatalog.require(currencyCode).minorUnit,
    );
    if (value == null || value <= 0 || !mounted) return;
    setState(() {
      _accountAmount = normalizeCurrencyAmount(value, currencyCode);
      _accountAmountTouched = true;
      if (currencyCode ==
          VeriFinScope.of(context).activeBook.baseCurrencyCode) {
        _baseAmount = _accountAmount!;
        _baseAmountTouched = true;
      }
      _conversionSource = ConversionSource.manual;
    });
  }

  Future<void> _editBaseAmount(String baseCode) async {
    final value = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).entryAmountInputTitle(
        AppLocalizations.of(context).refundBaseAmountLabel,
        baseCode,
      ),
      initialAmount: _baseAmount > 0 ? _baseAmount : null,
      maxFractionDigits: CurrencyCatalog.require(baseCode).minorUnit,
    );
    if (value == null || value <= 0 || !mounted) return;
    setState(() {
      _baseAmount = normalizeCurrencyAmount(value, baseCode);
      _baseAmountTouched = true;
      if (_selectedAccount?.currencyCode == baseCode) {
        _accountAmount = _baseAmount;
        _accountAmountTouched = true;
      }
      _conversionSource = ConversionSource.manual;
    });
  }

  Future<void> _editNote() async {
    final l10n = AppLocalizations.of(context);
    final value = await showTextInputDialog(
      context: context,
      title: l10n.commonNote,
      label: l10n.commonNote,
      initialValue: _note,
      allowEmpty: true,
    );
    if (value == null || !mounted) {
      return;
    }
    setState(() => _note = value);
  }

  LedgerEntry _buildRefund() => LedgerEntry(
    id: _refundId,
    bookId: widget.expense.bookId,
    type: EntryType.refund,
    amount: _amount.clamp(0.0, _maxRefund).toDouble(),
    currencyCode: widget.expense.currencyCode,
    accountAmount: _accountId.isEmpty ? null : _accountAmount,
    baseAmount: _baseAmount,
    conversionSource: _conversionSource,
    categoryId: widget.expense.categoryId,
    accountId: _accountId,
    note: _note.trim(),
    occurredAt: _initiatedAt,
    refundOf: widget.expense.id,
    settledAt: _settled ? _settledAt : null,
  );

  Future<bool> _save() async {
    if (_amount <= 0 ||
        _maxRefund <= 0 ||
        _baseAmount <= 0 ||
        (_accountId.isNotEmpty && (_accountAmount ?? 0) <= 0)) {
      return false;
    }
    _result = RefundEditResult.saved(_buildRefund());
    return true;
  }

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      _exitController.exit(result: () => _result);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.refundRecordsTitle,
      message: l10n.refundDeleteConfirm,
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    _result = const RefundEditResult.deleted();
    _exitController.exit(result: () => _result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final theme = Theme.of(context);
    final accountName = accountDisplayName(
      controller.accounts,
      _accountId,
      l10n.commonNoneShort,
    );
    final account = _selectedAccount;
    final baseCode = controller.activeBook.baseCurrencyCode;
    final canSave =
        _amount > 0 &&
        _baseAmount > 0 &&
        (_accountId.isEmpty || (_accountAmount ?? 0) > 0) &&
        (widget.existing == null || _isDirty);

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      popResult: () => _result,
      exitController: _exitController,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.existing == null
                          ? l10n.refundAdd
                          : l10n.refundEditTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (widget.existing != null)
                    IconButton(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                      color: veriExpense,
                      tooltip: l10n.commonDelete,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _editAmount,
                borderRadius: BorderRadius.circular(veriRadiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '+${formatUserMoney(_amount, widget.expense.currencyCode)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: veriIncome,
                        ),
                      ),
                      Text(
                        l10n.refundRemainingLabel(
                          formatUserMoney(
                            _maxRefund,
                            widget.expense.currencyCode,
                          ),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.refundCurrencyLockedHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              DetailInfoRow(
                label: l10n.refundToAccountLabel,
                value: accountName,
                onTap: _pickAccount,
              ),
              if (account != null)
                CurrencyAmountField(
                  key: const Key('refund_account_amount'),
                  label: l10n.refundAccountAmountLabel,
                  currencyCode: account.currencyCode,
                  amount: _accountAmount,
                  missingText: l10n.exchangeRateNotSet,
                  onTap: () => _editAccountAmount(account.currencyCode),
                ),
              CurrencyAmountField(
                key: const Key('refund_base_amount'),
                label: l10n.refundBaseAmountLabel,
                currencyCode: baseCode,
                amount: _baseAmount > 0 ? _baseAmount : null,
                missingText: l10n.exchangeRateNotSet,
                onTap: () => _editBaseAmount(baseCode),
              ),
              CompactSwitchRow(
                icon: Icons.check_circle_outline,
                title: Text(l10n.refundIsSettledLabel),
                value: _settled,
                onChanged: (value) => setState(() => _settled = value),
              ),
              if (_settled)
                DetailInfoRow(
                  label: l10n.refundArrivalDateLabel,
                  value:
                      '${l10n.dateMonthDay(_settledAt)}  ${relativeDay(l10n, _settledAt)}',
                  onTap: () => _pickDate(arrival: true),
                ),
              DetailInfoRow(
                label: l10n.refundInitiatedDateLabel,
                value:
                    '${l10n.dateMonthDay(_initiatedAt)}  ${relativeDay(l10n, _initiatedAt)}',
                onTap: () => _pickDate(arrival: false),
              ),
              DetailInfoRow(
                label: l10n.commonNote,
                value: _note.isEmpty ? l10n.noteHint : _note,
                placeholder: _note.isEmpty,
                onTap: _editNote,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canSave ? _saveAndExit : null,
                  child: Text(l10n.commonSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
