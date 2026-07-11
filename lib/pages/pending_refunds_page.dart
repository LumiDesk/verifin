import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'refund_editor.dart';

/// 「待退款」清单：汇总当前账本所有「待到账」退款（已申请、钱还没回来），可一键
/// 「标记已到账」核销，或点开编辑。入口在交易列表页头（有待退款时出现）。
class PendingRefundsPage extends StatelessWidget {
  const PendingRefundsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final pending = controller.pendingRefunds;
    final total = pending.fold<double>(0, (sum, r) => sum + r.amount);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: l10n.pendingRefundsTitle,
                subtitle: l10n.pendingRefundsSubtitle,
                showBack: true,
              ),
              const SizedBox(height: 10),
              if (pending.isEmpty)
                EmptyState(
                  icon: Icons.schedule,
                  title: l10n.pendingRefundsEmpty,
                  description: l10n.pendingRefundsSubtitle,
                )
              else ...<Widget>[
                VeriCard(
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.schedule, color: veriBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.pendingRefundsCount(pending.length),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '+${formatAmount(total)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: veriIncome,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                VeriCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      for (final refund in pending)
                        _PendingRefundRow(refund: refund),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingRefundRow extends StatelessWidget {
  const _PendingRefundRow({required this.refund});

  final LedgerEntry refund;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = VeriFinScope.of(context);
    final expense = controller.entries
        .where((e) => e.id == refund.refundOf)
        .firstOrNull;
    final context1 = expense == null
        ? ''
        : (expense.note.isNotEmpty
              ? expense.note
              : controller.categoryById(expense.categoryId).label);
    final accountName = accountDisplayName(
      controller.accounts,
      refund.accountId,
      l10n.commonNoneShort,
    );

    return InkWell(
      onTap: expense == null
          ? null
          : () => showRefundSheet(
              context,
              expenseId: expense.id,
              existing: refund,
            ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '+${formatAmount(refund.amount)} · $accountName',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${context1.isEmpty ? '' : '$context1 · '}'
                    '${l10n.refundInitiatedDateLabel} ${l10n.dateMonthDay(refund.occurredAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () =>
                  controller.setRefundSettled(refund.id, DateTime.now()),
              child: Text(l10n.refundMarkSettled),
            ),
          ],
        ),
      ),
    );
  }
}
