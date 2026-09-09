import 'dart:async';

import 'package:flutter/material.dart';

import '../app/common_widgets.dart';
import '../app/credit_card.dart';
import '../app/currency_catalog.dart';
import '../app/currency_math.dart';
import '../app/entry_currency_draft.dart';
import '../app/feedback.dart';
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
  double? _fromAmount;
  bool _fromAmountTouched = false;
  // 扣款账户 id；空串表示「无账户（代还）」。null 表示尚未初始化，build 时按默认解析。
  String? _fromAccountId;
  bool _noAccount = false;
  DateTime _occurredAt = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _saving = false;
  bool _saved = false;
  late final String _entryId = DateTime.now().microsecondsSinceEpoch.toString();
  final EditorExitController _exitController = EditorExitController();
  bool _initialized = false;
  // 进页面时的草稿指纹。用它而不是 `_saved` 判断脏状态：页面一进来就预填了欠款，
  // 若把「预填」当成用户改动，点返回就会弹出以「保存」为主按钮的确认框，
  // 顺手一点就会真的写一笔还款。
  String? _initialSignature;

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
        .where((account) => !account.hidden && account.id != widget.account.id)
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

  /// 草稿指纹：用户实际可改的字段。金额用定点字符串，避免浮点尾差把「没动」判成「动过」。
  String _draftSignature() {
    final date = _occurredAt;
    return <String>[
      _amount.toStringAsFixed(6),
      _noAccount ? 'none' : (_fromAccountId ?? ''),
      // 只精确到分钟：页面只编辑日期，重选同一天不该被判成「有改动」。
      '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute}',
      // 跨币种时用户可手改「转出金额」，漏掉它会让改动被静默丢弃。
      _fromAmountTouched ? (_fromAmount?.toStringAsFixed(6) ?? '') : '',
      _noteController.text.trim(),
    ].join('|');
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    _ensureDefaultFrom(controller);
    _resolveFromAmount(controller);
    // 预填与默认扣款账户解析完成后取一次基准；之后只有用户改动才会让它变化。
    _initialSignature ??= _draftSignature();
    final sourceAccount = _fromAccount(controller);
    final canConfirm = _amount > 0 && (_noAccount || (_fromAmount ?? 0) > 0);

    return UnsavedChangesGuard(
      isDirty: !_saved && _draftSignature() != _initialSignature,
      onSave: _save,
      exitController: _exitController,
      child: Scaffold(
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
                    SaveHeaderAction(
                      onPressed: canConfirm ? _saveAndExit : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SelectField(
                  label: l10n.creditRepayAmountLabel,
                  value: formatUserMoney(_amount, widget.account.currencyCode),
                  icon: Icons.payments_outlined,
                  onTap: _pickAmount,
                ),
                if (!_noAccount && sourceAccount != null) ...<Widget>[
                  if (sourceAccount.currencyCode !=
                      widget.account.currencyCode) ...<Widget>[
                    const SizedBox(height: 10),
                    SelectField(
                      key: const Key('repay_from_amount'),
                      label: l10n.entryTransferOutAmount,
                      value: _fromAmount == null
                          ? l10n.exchangeRateNotSet
                          : formatUserMoney(
                              _fromAmount!,
                              sourceAccount.currencyCode,
                            ),
                      icon: Icons.currency_exchange,
                      onTap: () => _pickFromAmount(sourceAccount.currencyCode),
                    ),
                  ],
                ],
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
                  onChanged: (_) => setState(() {}),
                  maxLines: 1,
                  decoration: InputDecoration(labelText: l10n.commonNote),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fromAccountLabel(VeriFinController controller) {
    final account = _fromAccount(controller);
    if (account == null) {
      return AppLocalizations.of(context).creditRepayNoAccountLabel;
    }
    return '${account.name} '
        '(${formatUserMoney(controller.accountBalance(account), account.currencyCode)})';
  }

  Account? _fromAccount(VeriFinController controller) => controller.accounts
      .where((account) => account.id == _fromAccountId)
      .firstOrNull;

  void _resolveFromAmount(VeriFinController controller) {
    if (_noAccount) {
      _fromAmount = null;
      return;
    }
    final source = _fromAccount(controller);
    if (source == null) return;
    if (source.currencyCode == widget.account.currencyCode) {
      _fromAmount = normalizeCurrencyAmount(_amount, source.currencyCode);
      _fromAmountTouched = false;
      return;
    }
    if (_fromAmountTouched) return;
    final result = controller.convertAmount(
      amount: _amount,
      sourceCurrencyCode: widget.account.currencyCode,
      targetCurrencyCode: source.currencyCode,
      date: _occurredAt,
    );
    _fromAmount = result is ConvertedCurrencyAmount ? result.amount : null;
  }

  Future<void> _pickAmount() async {
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).creditRepayAmountLabel,
      initialAmount: _amount,
      maxFractionDigits: CurrencyCatalog.require(
        widget.account.currencyCode,
      ).minorUnit,
    );
    if (amount != null && mounted) {
      setState(() {
        final previousAmount = _amount;
        _amount = normalizeCurrencyAmount(amount, widget.account.currencyCode);
        if (_fromAmountTouched) {
          final source = _fromAccount(VeriFinScope.of(context));
          if (source != null) {
            _fromAmount = scaleDependentCurrencyAmount(
              dependentAmount: _fromAmount,
              previousOriginalAmount: previousAmount,
              nextOriginalAmount: _amount,
              targetCurrencyCode: source.currencyCode,
            );
          }
        } else {
          _resolveFromAmount(VeriFinScope.of(context));
        }
      });
    }
  }

  Future<void> _pickFromAmount(String currencyCode) async {
    final value = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).entryAmountInputTitle(
        AppLocalizations.of(context).entryTransferOutAmount,
        currencyCode,
      ),
      initialAmount: _fromAmount,
      maxFractionDigits: CurrencyCatalog.require(currencyCode).minorUnit,
    );
    if (value == null || value <= 0 || !mounted) return;
    setState(() {
      _fromAmount = normalizeCurrencyAmount(value, currencyCode);
      _fromAmountTouched = true;
    });
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
        _fromAmount = null;
      } else {
        _noAccount = false;
        _fromAccountId = selected.id;
        _fromAmountTouched = false;
        _resolveFromAmount(controller);
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
      _resolveFromAmount(VeriFinScope.of(context));
    });
  }

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      _exitController.exit();
    }
  }

  Future<bool> _save() async {
    if (_amount <= 0 || _saving) {
      return false;
    }
    final controller = VeriFinScope.of(context);
    final fromId = _noAccount ? '' : (_fromAccountId ?? '');
    final source = _fromAccount(controller);
    final sourceCode = source?.currencyCode ?? widget.account.currencyCode;
    final sourceAmount = _noAccount ? _amount : _fromAmount;
    if (sourceAmount == null || sourceAmount <= 0) {
      return false;
    }
    // 用转账分类（「转出」），与普通转账一致，避免列表按空分类回退成「已删除分类」。
    final transferCategories = controller.categoriesForType(EntryType.transfer);
    final categoryId = transferCategories.isEmpty
        ? ''
        : transferCategories.first.id;
    _saving = true;
    final result = await controller.saveEntryAggregateDraftResult(
      entry: LedgerEntry(
        id: _entryId,
        bookId: controller.activeBook.id,
        type: EntryType.transfer,
        amount: normalizeCurrencyAmount(sourceAmount, sourceCode),
        currencyCode: sourceCode,
        accountAmount: _noAccount
            ? null
            : normalizeCurrencyAmount(sourceAmount, sourceCode),
        toAccountAmount: normalizeCurrencyAmount(
          _amount,
          widget.account.currencyCode,
        ),
        baseAmount: 0,
        conversionSource:
            sourceCode == widget.account.currencyCode && !_fromAmountTouched
            ? ConversionSource.identity
            : _fromAmountTouched
            ? ConversionSource.manual
            : ConversionSource.rateTable,
        categoryId: categoryId,
        accountId: fromId,
        toAccountId: widget.account.id,
        note: _noteController.text.trim(),
        occurredAt: _occurredAt,
      ),
      isNew: true,
    );
    if (!mounted || !result.isSuccess) {
      _saving = false;
      if (mounted && result is EntrySaveValidationFailure) {
        unawaited(
          VeriFeedbackHost.of(context).showMessage(
            message: AppLocalizations.of(context).entrySaveValidationFailed,
            tone: VeriFeedbackTone.warning,
            duration: VeriFeedbackDuration.long,
          ),
        );
      }
      return false;
    }
    _saved = true;
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: AppLocalizations.of(context).creditRepaySuccess,
        tone: VeriFeedbackTone.success,
      ),
    );
    return true;
  }
}
