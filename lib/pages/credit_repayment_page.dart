import 'package:flutter/material.dart';

import '../app/common_widgets.dart';
import '../app/credit_card.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 信用类账户（信用卡 / 信用账户）还款页：本质是一笔「扣款账户 → 本账户」的转账，
/// 使欠款减少。扣款账户可选「无账户」以适配他人代还场景。转账不计入收支统计。
class CreditRepaymentPage extends StatefulWidget {
  const CreditRepaymentPage({super.key, required this.account});

  final Account account;

  @override
  State<CreditRepaymentPage> createState() => _CreditRepaymentPageState();
}

class _CreditRepaymentPageState extends State<CreditRepaymentPage> {
  double _amount = 0;
  // 扣款账户 id；空串表示「无账户（代还）」。null 表示尚未初始化，build 时按默认解析。
  String? _fromAccountId;
  bool _noAccount = false;
  DateTime _occurredAt = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    final controller = VeriFinScope.of(context);
    // 还款金额默认预填当前欠款。
    _amount = usedCredit(controller.accountBalance(widget.account));
    _noteController.text = AppLocalizations.of(context).creditRepayDefaultNote;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// 可作扣款账户的候选：非隐藏且不是本账户（不能从自己还给自己）。
  List<Account> _payableAccounts(VeriFinController controller) {
    return controller.accounts
        .where(
          (account) => !account.hidden && account.id != widget.account.id,
        )
        .toList();
  }

  /// 默认扣款账户：优先记账默认账户（若可用且非本账户），否则第一个候选账户，
  /// 都没有则回落「无账户」。仅在用户尚未手动选择时生效。
  void _ensureDefaultFrom(VeriFinController controller) {
    if (_fromAccountId != null || _noAccount) {
      return;
    }
    final payable = _payableAccounts(controller);
    final defaultId = controller.defaultAccountId;
    if (defaultId != null &&
        defaultId != widget.account.id &&
        payable.any((account) => account.id == defaultId)) {
      _fromAccountId = defaultId;
    } else if (payable.isNotEmpty) {
      _fromAccountId = payable.first.id;
    } else {
      _noAccount = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    _ensureDefaultFrom(controller);
    final canConfirm = _amount > 0;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: l10n.creditRepayTitle,
                subtitle: widget.account.name,
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.check,
                    tooltip: l10n.commonConfirm,
                    onPressed: canConfirm ? _save : null,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SelectField(
                label: l10n.creditRepayAmountLabel,
                value: formatAmount(_amount),
                icon: Icons.payments_outlined,
                onTap: _pickAmount,
              ),
              const SizedBox(height: 10),
              SelectField(
                key: const Key('repay_from_account'),
                label: l10n.creditRepayFromAccount,
                value: _noAccount
                    ? l10n.creditRepayNoAccountLabel
                    : _fromAccountLabel(controller),
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => _pickFromAccount(controller),
              ),
              const SizedBox(height: 10),
              SelectField(
                label: l10n.dateLabel,
                value: l10n.dateMonthDay(_occurredAt),
                icon: Icons.event_outlined,
                onTap: _pickDate,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: 1,
                decoration: InputDecoration(labelText: l10n.commonNote),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fromAccountLabel(VeriFinController controller) {
    final matches = controller.accounts.where(
      (account) => account.id == _fromAccountId,
    );
    if (matches.isEmpty) {
      return AppLocalizations.of(context).creditRepayNoAccountLabel;
    }
    final account = matches.first;
    return '${account.name} '
        '(${formatAmount(controller.accountBalance(account))})';
  }

  Future<void> _pickAmount() async {
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).creditRepayAmountLabel,
      initialAmount: _amount,
    );
    if (amount != null && mounted) {
      setState(() => _amount = amount);
    }
  }

  Future<void> _pickFromAccount(VeriFinController controller) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showAccountPickerSheet(
      context: context,
      title: l10n.creditRepayFromAccount,
      accounts: _payableAccounts(controller),
      selectedId: _noAccount ? '' : _fromAccountId,
      balanceOf: controller.accountBalance,
      noneLabel: l10n.creditRepayNoAccountLabel,
      noneHint: l10n.creditRepayNoAccountHint,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      if (selected.id.isEmpty) {
        _noAccount = true;
        _fromAccountId = null;
      } else {
        _noAccount = false;
        _fromAccountId = selected.id;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  void _save() {
    if (_amount <= 0 || _saving) {
      return;
    }
    final controller = VeriFinScope.of(context);
    final fromId = _noAccount ? '' : (_fromAccountId ?? '');
    _saving = true;
    controller.addEntry(
      LedgerEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bookId: controller.activeBook.id,
        type: EntryType.transfer,
        amount: _amount,
        categoryId: '',
        accountId: fromId,
        toAccountId: widget.account.id,
        note: _noteController.text.trim(),
        occurredAt: _occurredAt,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).creditRepaySuccess)),
    );
    Navigator.of(context).pop();
  }
}
