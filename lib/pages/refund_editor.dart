import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/ledger_math.dart';
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

  double get _settledTotal => refunds
      .where((refund) => refund.isSettledRefund)
      .fold<double>(0, (sum, refund) => sum + refund.amount);

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
    final netAmount = (expense.amount - _settledTotal)
        .clamp(0.0, expense.amount)
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
                  l10n.refundNetLabel(formatAmount(netAmount)),
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
                l10n.refundPendingTotal(formatAmount(pendingTotal)),
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
                    '+${formatAmount(refund.amount)} · $accountName',
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
}) {
  return showModalBottomSheet<RefundEditResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (_) =>
        _RefundSheet(expense: expense, refunds: refunds, existing: existing),
  );
}

typedef _RefundSnapshot = ({
  double amount,
  String accountId,
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
  });

  final LedgerEntry expense;
  final List<LedgerEntry> refunds;
  final LedgerEntry? existing;

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  final EditorExitController _exitController = EditorExitController();
  late final String _refundId;
  late double _amount;
  late String _accountId;
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
      _settled = existing.settledAt != null;
      _settledAt = existing.settledAt ?? DateTime.now();
      _initiatedAt = existing.occurredAt;
      _note = existing.note;
    } else {
      _amount = _maxRefund;
      _accountId = widget.expense.accountId;
      _settled = true;
      _settledAt = DateTime.now();
      _initiatedAt = DateTime.now();
      _note = '';
    }
    _initialSnapshot = _snapshot;
  }

  double get _maxRefund {
    final otherTotal = widget.refunds
        .where((refund) => refund.id != widget.existing?.id)
        .fold<double>(0, (sum, refund) => sum + refund.amount);
    return (widget.expense.amount - otherTotal)
        .clamp(0.0, widget.expense.amount)
        .toDouble();
  }

  _RefundSnapshot get _snapshot => (
    amount: _amount,
    accountId: _accountId,
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
    );
    if (value == null || value <= 0 || !mounted) {
      return;
    }
    setState(() => _amount = value);
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
    setState(() => _accountId = selected.id);
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
      }
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
    categoryId: widget.expense.categoryId,
    accountId: _accountId,
    note: _note.trim(),
    occurredAt: _initiatedAt,
    refundOf: widget.expense.id,
    settledAt: _settled ? _settledAt : null,
  );

  Future<bool> _save() async {
    if (_amount <= 0 || _maxRefund <= 0) {
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
    final canSave = _amount > 0 && (widget.existing == null || _isDirty);

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
                        '+${formatAmount(_amount)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: veriIncome,
                        ),
                      ),
                      Text(
                        l10n.refundRemainingLabel(formatAmount(_maxRefund)),
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
              DetailInfoRow(
                label: l10n.refundToAccountLabel,
                value: accountName,
                onTap: _pickAccount,
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
