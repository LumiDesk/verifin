import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 支出详情页里的「退款」区：展示某笔支出的退款明细（可点开编辑）与净支出汇总，
/// 并提供「添加退款」。退款条目由 controller 即时增删改（与附件一致，不走保存按钮）。
class RefundSection extends StatelessWidget {
  const RefundSection({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final expense = controller.entries
        .where((e) => e.id == expenseId)
        .firstOrNull;
    if (expense == null || expense.type != EntryType.expense) {
      return const SizedBox.shrink();
    }
    final refunds = controller.refundsForEntry(expenseId);
    final remaining = controller.remainingRefundable(expenseId);
    final pendingTotal = refunds
        .where((r) => r.isPendingRefund)
        .fold<double>(0, (sum, r) => sum + r.amount);

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
                  l10n.refundNetLabel(formatAmount(expense.netAmount)),
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
            for (final refund in refunds)
              _RefundRow(
                refund: refund,
                accounts: controller.accounts,
                onTap: () => showRefundSheet(
                  context,
                  expenseId: expenseId,
                  existing: refund,
                ),
              ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: remaining <= 0
                  ? null
                  : () => showRefundSheet(context, expenseId: expenseId),
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
      borderRadius: BorderRadius.circular(10),
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

/// 添加 / 编辑退款的底部弹窗。传 [existing] 为编辑（含删除入口），否则为新增。
/// 直接经 controller 落库，无返回值。
Future<void> showRefundSheet(
  BuildContext context, {
  required String expenseId,
  LedgerEntry? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (_) => _RefundSheet(expenseId: expenseId, existing: existing),
  );
}

class _RefundSheet extends StatefulWidget {
  const _RefundSheet({required this.expenseId, this.existing});

  final String expenseId;
  final LedgerEntry? existing;

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  late double _amount;
  late String _accountId;
  late bool _settled;
  late DateTime _settledAt;
  late DateTime _initiatedAt;
  late String _note;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = VeriFinScope.of(context);
    final expense = controller.entries.firstWhere(
      (e) => e.id == widget.expenseId,
    );
    final existing = widget.existing;
    // 本次可退上限：新增=剩余可退；编辑=剩余可退 + 本笔旧值（本笔可占回自己那份）。
    final maxRefund =
        controller.remainingRefundable(widget.expenseId) +
        (existing?.amount ?? 0);
    if (existing != null) {
      _amount = existing.amount;
      _accountId = existing.accountId;
      _settled = existing.settledAt != null;
      _settledAt = existing.settledAt ?? DateTime.now();
      _initiatedAt = existing.occurredAt;
      _note = existing.note;
    } else {
      _amount = maxRefund; // 默认填满剩余可退
      _accountId = expense.accountId; // 默认原支出账户
      _settled = true;
      _settledAt = DateTime.now();
      _initiatedAt = DateTime.now();
      _note = '';
    }
  }

  double get _maxRefund {
    final controller = VeriFinScope.of(context);
    return controller.remainingRefundable(widget.expenseId) +
        (widget.existing?.amount ?? 0);
  }

  Future<void> _editAmount() async {
    final l10n = AppLocalizations.of(context);
    final value = await showNumberPadSheet(
      context,
      title: l10n.refundAmountShort,
      initialAmount: _amount > 0 ? _amount : null,
      // 数字键盘内显示「最多 剩余可退」并在 OK 时当场封顶（决策 D：禁止超额）。
      maxAmount: _maxRefund,
    );
    if (value == null || value <= 0 || !mounted) return;
    setState(() => _amount = value);
  }

  Future<void> _pickAccount() async {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final selected = await showAccountPickerSheet(
      context: context,
      title: l10n.refundToAccountLabel,
      accounts: controller.accounts.where((a) => !a.hidden).toList(),
      selectedId: _accountId,
      balanceOf: controller.accountBalance,
      noneLabel: l10n.commonNoneShort,
    );
    if (selected == null || !mounted) return;
    setState(() => _accountId = selected.id);
  }

  Future<void> _pickDate({required bool arrival}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: arrival ? _settledAt : _initiatedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
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
    if (value == null || !mounted) return;
    setState(() => _note = value);
  }

  void _save() {
    final controller = VeriFinScope.of(context);
    if (_amount <= 0) return;
    final settledAt = _settled ? _settledAt : null;
    final existing = widget.existing;
    if (existing == null) {
      controller.addRefund(
        expenseId: widget.expenseId,
        amount: _amount,
        accountId: _accountId,
        initiatedAt: _initiatedAt,
        settledAt: settledAt,
        note: _note,
      );
    } else {
      controller.updateRefund(
        existing.copyWith(
          amount: _amount,
          accountId: _accountId,
          occurredAt: _initiatedAt,
          settledAt: settledAt,
          clearSettledAt: settledAt == null,
          note: _note,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.refundRecordsTitle,
      message: l10n.refundDeleteConfirm,
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    controller.deleteRefund(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
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
    return SafeArea(
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
                // 删除放右上角，与底部「保存」彻底分开，避免误触。
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
            // 大金额（点击改）+ 剩余可退提示。
            InkWell(
              onTap: _editAmount,
              borderRadius: BorderRadius.circular(10),
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
              onChanged: (v) => setState(() => _settled = v),
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
                onPressed: _amount > 0 ? _save : null,
                child: Text(l10n.commonSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
