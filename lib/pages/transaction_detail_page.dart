import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/currency_catalog.dart';
import '../app/currency_math.dart';
import '../app/entry_currency_draft.dart';
import '../app/feedback.dart';
import '../app/model_lookup.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'attachments_editor.dart';
import 'refund_editor.dart';
import 'sheets.dart';

class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final EditorExitController _exitController = EditorExitController();
  LedgerEntry? _initialEntry;
  late EntryType _type;
  late double _amount;
  late String _currencyCode;
  late double? _accountAmount;
  late double? _toAccountAmount;
  late double _baseAmount;
  late ConversionSource _conversionSource;
  bool _currencyTouched = false;
  bool _accountAmountTouched = false;
  bool _toAccountAmountTouched = false;
  bool _baseAmountTouched = false;
  bool _rememberRate = false;
  Set<String> _missingRateCodes = <String>{};
  late String _categoryId;
  late String _accountId;
  // 「无账户」：只记金额、不计入任何账户余额（仅收支有效）。
  late bool _noAccount;
  late String? _toAccountId;
  late DateTime _occurredAt;
  late List<String> _tagIds;
  late double _fee;
  late bool _reimbursable;
  late final TextEditingController _noteController;
  late List<LedgerEntry> _refunds;
  late List<Attachment> _attachments;
  late String _initialFingerprint;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialEntry != null) {
      return;
    }
    final controller = VeriFinScope.of(context);
    final entry = controller.entries
        .where((item) => item.id == widget.entryId)
        .firstOrNull;
    if (entry == null) {
      return;
    }
    _initialEntry = entry;
    _type = entry.type;
    _amount = entry.amount;
    _currencyCode = entry.currencyCode;
    _accountAmount = entry.accountAmount;
    _toAccountAmount = entry.toAccountAmount;
    _baseAmount = entry.baseAmount;
    _conversionSource = entry.conversionSource;
    _categoryId = entry.categoryId;
    _accountId = entry.accountId;
    _noAccount = entry.type != EntryType.transfer && entry.accountId.isEmpty;
    _toAccountId = entry.toAccountId;
    _occurredAt = entry.occurredAt;
    _tagIds = List<String>.of(entry.tagIds);
    _fee = entry.fee;
    _reimbursable = entry.reimbursable;
    _noteController = TextEditingController(text: entry.note);
    _refunds = List<LedgerEntry>.of(controller.refundsForEntry(entry.id));
    _attachments = List<Attachment>.of(
      controller.attachmentsForEntry(entry.id),
    );
    _initialFingerprint = _draftFingerprint;
  }

  @override
  void dispose() {
    if (_initialEntry != null) {
      _noteController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final entry = _initialEntry;
    if (entry == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(child: Text(AppLocalizations.of(context).entryMissing)),
        ),
      );
    }

    final currentCategories = controller.categoriesForType(_type);
    if (!currentCategories.any((category) => category.id == _categoryId)) {
      _categoryId = currentCategories.first.id;
    }
    final category = controller.categoryById(_categoryId);
    final accounts = controller.accounts
        .where((account) => !account.hidden || account.id == _accountId)
        .toList();
    if (_type == EntryType.transfer &&
        _toAccountId != null &&
        !accounts.any((account) => account.id == _toAccountId)) {
      final toAccount = controller.accounts.where(
        (account) => account.id == _toAccountId,
      );
      accounts.addAll(toAccount);
    }
    // 转账必须落到具体账户，不允许「无账户」。
    if (_type == EntryType.transfer) {
      _noAccount = false;
    }
    _normalizeTransferAccounts(accounts);
    final account = accountById(accounts, _accountId);
    final toAccount = _toAccountId == null
        ? null
        : accountById(accounts, _toAccountId!);
    final noneLabel = AppLocalizations.of(context).noAccountLabel;
    final accountFieldValue = _noAccount
        ? noneLabel
        : '${account.name} (${formatUserMoney(controller.accountBalance(account), account.currencyCode)})';
    final canSave =
        (accounts.isNotEmpty || _noAccount) &&
        (_type == EntryType.transfer ||
            _baseAmount > 0 && (_noAccount || (_accountAmount ?? 0) > 0)) &&
        (_type != EntryType.transfer ||
            (_toAccountId != null &&
                _toAccountId != _accountId &&
                (_accountAmount ?? 0) > 0 &&
                (_toAccountAmount ?? 0) > 0)) &&
        (_type == EntryType.expense
            ? _refundTotal <= _amount + currencyAmountTolerance(_currencyCode)
            : _refunds.isEmpty);
    final amountColor = colorForType(_type);
    final formattedAmount = formatCurrencyNumber(_amount, _currencyCode);
    final amountText = switch (_type) {
      EntryType.expense => '-$formattedAmount',
      EntryType.income => '+$formattedAmount',
      EntryType.transfer => formattedAmount,
      EntryType.refund => '+$formattedAmount',
    };

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      exitController: _exitController,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 26),
              children: <Widget>[
                VeriHeader(
                  title: _type.label(AppLocalizations.of(context)),
                  showBack: true,
                  actions: <Widget>[
                    HeaderAction(
                      icon: Icons.delete_outline,
                      tooltip: AppLocalizations.of(context).deleteEntryTooltip,
                      destructive: true,
                      onPressed: _delete,
                    ),
                    SaveHeaderAction(
                      onPressed: canSave && _isDirty ? _saveAndExit : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                VeriCard(
                  onTap: _editAmount,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppLocalizations.of(context).amountLabel,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.42),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              amountText,
                              style: Theme.of(context).textTheme.displayLarge
                                  ?.copyWith(
                                    color: amountColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      CategoryIconBox(
                        iconCode: category.iconCode,
                        color: amountColor,
                        size: 38,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      if (_refunds.isNotEmpty)
                        DetailInfoRow(
                          label: AppLocalizations.of(context).commonType,
                          value: _type.label(AppLocalizations.of(context)),
                        )
                      else
                        VeriAnchoredChoice<EntryType>(
                          key: const Key('transaction_type_choice'),
                          values: EntryType.userSelectable,
                          selected: _type,
                          idOf: (value) =>
                              'transaction_detail_type_${value.name}',
                          labelOf: (value) =>
                              value.label(AppLocalizations.of(context)),
                          iconOf: (value) => switch (value) {
                            EntryType.expense => Icons.arrow_upward_rounded,
                            EntryType.income => Icons.arrow_downward_rounded,
                            EntryType.transfer => Icons.swap_horiz_rounded,
                            EntryType.refund => Icons.undo_rounded,
                          },
                          onSelected: _selectType,
                          semanticLabel: AppLocalizations.of(
                            context,
                          ).pickTypeTitle,
                          width: 188,
                          builder: (context, openMenu, menuOpen) =>
                              DetailInfoRow(
                                label: AppLocalizations.of(context).commonType,
                                value: _type.label(
                                  AppLocalizations.of(context),
                                ),
                                onTap: openMenu,
                              ),
                        ),
                      DetailInfoRow(
                        label: AppLocalizations.of(context).commonCategory,
                        value: category.label,
                        onTap: _pickCategory,
                      ),
                      DetailInfoRow(
                        key: const Key('transaction_currency_field'),
                        label: AppLocalizations.of(context).entryCurrencyLabel,
                        value: _currencyCode,
                        onTap: _type == EntryType.transfer
                            ? null
                            : _refunds.isEmpty
                            ? _pickCurrency
                            : () => unawaited(
                                VeriFeedbackHost.of(context).showMessage(
                                  message: AppLocalizations.of(
                                    context,
                                  ).entryCurrencyLockedByRefund,
                                  tone: VeriFeedbackTone.warning,
                                ),
                              ),
                      ),
                      if (_type == EntryType.transfer) ...<Widget>[
                        DetailInfoRow(
                          label: AppLocalizations.of(
                            context,
                          ).transferOutAccount,
                          value:
                              '${account.name} (${formatUserMoney(controller.accountBalance(account), account.currencyCode)})',
                          onTap: accounts.isEmpty
                              ? null
                              : () => _pickAccount(accounts),
                        ),
                        DetailInfoRow(
                          label: AppLocalizations.of(context).transferInAccount,
                          value: toAccount == null
                              ? AppLocalizations.of(context).pleaseSelect
                              : '${toAccount.name} (${formatUserMoney(controller.accountBalance(toAccount), toAccount.currencyCode)})',
                          placeholder: toAccount == null,
                          onTap: accounts.length < 2
                              ? null
                              : () => _pickToAccount(accounts),
                        ),
                        DetailInfoRow(
                          label: AppLocalizations.of(context).feeLabel,
                          value: _fee > 0
                              ? formatUserMoney(_fee, _currencyCode)
                              : AppLocalizations.of(context).commonNoneShort,
                          placeholder: _fee <= 0,
                          onTap: _editFee,
                        ),
                      ] else
                        DetailInfoRow(
                          label: AppLocalizations.of(context).accountLabel,
                          value: accountFieldValue,
                          placeholder: _noAccount,
                          onTap: accounts.isEmpty && !_noAccount
                              ? null
                              : () => _pickAccount(accounts),
                        ),
                      ..._buildCurrencyAmountFields(
                        controller,
                        accounts,
                        account,
                        toAccount,
                      ),
                      DetailInfoRow(
                        label: AppLocalizations.of(context).dateLabel,
                        value:
                            '${AppLocalizations.of(context).dateMonthDay(_occurredAt)}  ${relativeDay(AppLocalizations.of(context), _occurredAt)}',
                        onTap: _pickDate,
                      ),
                      DetailInfoRow(
                        label: AppLocalizations.of(context).timeLabel,
                        value: formatTime(_occurredAt),
                        onTap: _pickTime,
                      ),
                      DetailInfoRow(
                        label: AppLocalizations.of(context).commonNote,
                        value: _noteController.text.trim().isEmpty
                            ? AppLocalizations.of(context).noteHint
                            : _noteController.text.trim(),
                        placeholder: _noteController.text.trim().isEmpty,
                        onTap: _editNote,
                      ),
                      DetailInfoRow(
                        label: AppLocalizations.of(context).tagLabel,
                        value: _tagLabels(controller).isEmpty
                            ? AppLocalizations.of(context).entryAddTags
                            : _tagLabels(controller).join('、'),
                        placeholder: _tagLabels(controller).isEmpty,
                        onTap: _pickTags,
                      ),
                      if (_type == EntryType.expense)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context).markReimbursable,
                                ),
                              ),
                              Switch(
                                value: _reimbursable,
                                onChanged: (value) =>
                                    setState(() => _reimbursable = value),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // 退款与交易本体共用同一份草稿，只在页头保存时一起落库。
                if (_type == EntryType.expense) ...<Widget>[
                  const SizedBox(height: 12),
                  RefundSection(
                    expense: _buildEntry(),
                    refunds: _refunds,
                    onChanged: (refunds) => setState(() => _refunds = refunds),
                  ),
                ],
                const SizedBox(height: 12),
                VeriCard(
                  child: AttachmentsEditor(
                    dataUrls: _attachments
                        .map((attachment) => attachment.dataUrl)
                        .toList(growable: false),
                    onAddDataUrl: (dataUrl) {
                      setState(() {
                        _attachments.add(
                          Attachment(
                            id: 'att_${widget.entryId}_${DateTime.now().microsecondsSinceEpoch}',
                            entryId: widget.entryId,
                            dataUrl: dataUrl,
                          ),
                        );
                      });
                    },
                    onRemoveIndex: (index) =>
                        setState(() => _attachments.removeAt(index)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      date: _occurredAt,
    );
    if (result is ConvertedCurrencyAmount) return result.amount;
    if (result is MissingCurrencyRate) {
      _missingRateCodes.addAll(result.currencyCodes);
    }
    return null;
  }

  void _resolveCurrencyAmounts(
    VeriFinController controller,
    List<Account> accounts, {
    bool forceAccount = false,
    bool forceToAccount = false,
    bool forceBase = false,
  }) {
    _missingRateCodes = <String>{};
    final account = _noAccount ? null : _findAccount(accounts, _accountId);
    final toAccount = _findAccount(accounts, _toAccountId);
    final baseCode = controller.activeBook.baseCurrencyCode;
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
      _conversionSource = _toAccountAmountTouched
          ? ConversionSource.manual
          : toAccount != null && toAccount.currencyCode != _currencyCode
          ? ConversionSource.rateTable
          : ConversionSource.identity;
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
      _baseAmount = normalizeCurrencyAmount(_accountAmount!, baseCode);
      _baseAmountTouched = _accountAmountTouched;
    } else if (forceBase || !_baseAmountTouched) {
      _baseAmount =
          _converted(controller, _amount, _currencyCode, baseCode) ?? 0;
    }
    _conversionSource = _accountAmountTouched || _baseAmountTouched
        ? ConversionSource.manual
        : _currencyCode == baseCode &&
              (account == null || account.currencyCode == baseCode)
        ? ConversionSource.identity
        : ConversionSource.rateTable;
  }

  List<Widget> _buildCurrencyAmountFields(
    VeriFinController controller,
    List<Account> accounts,
    Account account,
    Account? toAccount,
  ) {
    final l10n = AppLocalizations.of(context);
    final fields = <Widget>[];
    if (_type == EntryType.transfer &&
        toAccount != null &&
        toAccount.currencyCode != _currencyCode) {
      fields.add(
        CurrencyAmountField(
          key: const Key('transaction_to_account_amount'),
          label: l10n.entryTransferInAmount,
          currencyCode: toAccount.currencyCode,
          amount: _toAccountAmount,
          missingText: l10n.exchangeRateNotSet,
          onTap: () => _editToAccountAmount(toAccount.currencyCode),
        ),
      );
      fields.add(
        DetailInfoRow(
          label: l10n.entryRateLabel,
          value: _toAccountAmount == null || _amount <= 0
              ? l10n.exchangeRateNotSet
              : l10n.entryRateEquation(
                  _currencyCode,
                  formatRateValue(_toAccountAmount! / _amount),
                  toAccount.currencyCode,
                ),
          placeholder: _toAccountAmount == null,
          onTap: () => _editDerivedRate(
            targetCode: toAccount.currencyCode,
            transfer: true,
          ),
        ),
      );
    } else if (_type != EntryType.transfer) {
      if (!_noAccount && account.currencyCode != _currencyCode) {
        fields.add(
          CurrencyAmountField(
            key: const Key('transaction_account_amount'),
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
      final baseCode = controller.activeBook.baseCurrencyCode;
      if (_currencyCode != baseCode) {
        fields.add(
          CurrencyAmountField(
            key: const Key('transaction_base_amount'),
            label: l10n.entryLedgerAmountLabel,
            currencyCode: baseCode,
            amount: _baseAmount > 0 ? _baseAmount : null,
            missingText: l10n.exchangeRateNotSet,
            onTap: () => _editBaseAmount(baseCode),
          ),
        );
        fields.add(
          DetailInfoRow(
            label: l10n.entryRateLabel,
            value: _baseAmount <= 0 || _amount <= 0
                ? l10n.exchangeRateNotSet
                : l10n.entryRateEquation(
                    _currencyCode,
                    formatRateValue(_baseAmount / _amount),
                    baseCode,
                  ),
            placeholder: _baseAmount <= 0,
            onTap: () =>
                _editDerivedRate(targetCode: baseCode, transfer: false),
          ),
        );
        fields.add(
          CompactSwitchRow(
            icon: Icons.bookmark_add_outlined,
            title: Text(l10n.entryRememberRate),
            subtitle: Text(l10n.entryRememberRateHint),
            value: _rememberRate,
            onChanged: (value) => setState(() => _rememberRate = value),
          ),
        );
      }
    }
    if (_missingRateCodes.isNotEmpty) {
      fields.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
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
    } else if (fields.isNotEmpty) {
      final baseCode = controller.activeBook.baseCurrencyCode;
      final involvedCodes = <String>{
        _currencyCode,
        if (!_noAccount) account.currencyCode,
        if (toAccount != null) toAccount.currencyCode,
      }..remove(baseCode);
      final rateDates = <DateTime>{
        for (final code in involvedCodes)
          ?controller.exchangeRateFor(code, _occurredAt)?.effectiveDate,
      }.toList()..sort();
      final stale = rateDates.any(
        (date) => calendarDaysBetween(date, _occurredAt) > 30,
      );
      fields.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _conversionSource == ConversionSource.manual
                ? l10n.entryConversionSourceManual
                : rateDates.isEmpty
                ? l10n.entryConversionSourceRateTable
                : l10n.entryConversionRateTrace(
                    rateDates.map(currencyDateKey).join(' / '),
                    stale ? ' · ${l10n.exchangeRateStale}' : '',
                  ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
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
      _rememberRate = false;
      _resolveCurrencyAmounts(
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
      title: AppLocalizations.of(context).amountEditTitle,
      initialAmount: _amount,
      maxFractionDigits: CurrencyCatalog.require(_currencyCode).minorUnit,
    );
    if (amount == null || amount <= 0 || !mounted) {
      return;
    }
    setState(() {
      final controller = VeriFinScope.of(context);
      final previousAmount = _amount;
      _amount = normalizeCurrencyAmount(amount, _currencyCode);
      if (_conversionSource == ConversionSource.manual ||
          _conversionSource == ConversionSource.imported ||
          _conversionSource == ConversionSource.legacy) {
        final account = _findAccount(controller.accounts, _accountId);
        final toAccount = _findAccount(controller.accounts, _toAccountId);
        if (!_noAccount && account != null) {
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
        _resolveCurrencyAmounts(controller, controller.accounts);
      }
    });
  }

  Future<void> _editFee() async {
    final fee = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).transferFeeTitle,
      initialAmount: _fee > 0 ? _fee : null,
      allowZero: true,
      maxFractionDigits: CurrencyCatalog.require(_currencyCode).minorUnit,
    );
    if (fee == null || fee < 0 || !mounted) {
      return;
    }
    setState(() => _fee = normalizeCurrencyAmount(fee, _currencyCode));
  }

  Future<void> _editAccountAmount(String currencyCode) async {
    final l10n = AppLocalizations.of(context);
    final value = await showNumberPadSheet(
      context,
      title: l10n.entryAmountInputTitle(
        _type == EntryType.expense
            ? l10n.entryAccountAmountExpense
            : l10n.entryAccountAmountIncome,
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
      _conversionSource = ConversionSource.manual;
      _missingRateCodes.clear();
    });
  }

  Future<void> _editToAccountAmount(String currencyCode) async {
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
      _conversionSource = ConversionSource.manual;
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
      if (!_noAccount && account?.currencyCode == baseCode) {
        _accountAmount = _baseAmount;
        _accountAmountTouched = true;
      }
      _conversionSource = ConversionSource.manual;
      _missingRateCodes.clear();
    });
  }

  Future<void> _editDerivedRate({
    required String targetCode,
    required bool transfer,
  }) async {
    final current = transfer ? _toAccountAmount : _baseAmount;
    final rate = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(
        context,
      ).entryRateEditTitle(_currencyCode, targetCode),
      initialAmount: current == null || current <= 0 || _amount <= 0
          ? null
          : current / _amount,
      maxFractionDigits: 10,
    );
    if (!mounted || rate == null || rate <= 0) return;
    setState(() {
      final target = normalizeCurrencyAmount(_amount * rate, targetCode);
      if (transfer) {
        _toAccountAmount = target;
        _toAccountAmountTouched = true;
      } else {
        _baseAmount = target;
        _baseAmountTouched = true;
        final account = _findAccount(
          VeriFinScope.of(context).accounts,
          _accountId,
        );
        if (!_noAccount && account?.currencyCode == targetCode) {
          _accountAmount = target;
          _accountAmountTouched = true;
        }
      }
      _conversionSource = ConversionSource.manual;
      _missingRateCodes.clear();
    });
  }

  void _selectType(EntryType selected) {
    if (_type == selected || _refunds.isNotEmpty) return;
    setState(() {
      _type = selected;
      final controller = VeriFinScope.of(context);
      if (controller.categoryById(_categoryId).type != _type) {
        _categoryId = controller.categoriesForType(_type).first.id;
      }
      _normalizeTransferAccounts(controller.accounts);
      if (_type == EntryType.transfer) {
        _currencyTouched = false;
      }
      _resolveCurrencyAmounts(
        controller,
        controller.accounts,
        forceAccount: true,
        forceToAccount: true,
        forceBase: true,
      );
    });
  }

  Future<void> _pickCategory() async {
    final selected = await showCategoryPickerSheet(
      context,
      categories: VeriFinScope.of(context).categoriesForType(_type),
      selectedId: _categoryId,
    );
    if (selected != null && mounted) {
      setState(() => _categoryId = selected);
    }
  }

  Future<void> _pickAccount(List<Account> accounts) async {
    final isTransfer = _type == EntryType.transfer;
    final selected = await showAccountPickerSheet(
      context: context,
      title: isTransfer
          ? AppLocalizations.of(context).pickTransferOutAccount
          : AppLocalizations.of(context).pickAccountTitle,
      accounts: accounts,
      selectedId: _noAccount ? '' : _accountId,
      balanceOf: VeriFinScope.of(context).accountBalance,
      // 转账两端都必须是具体账户，故转出账户不提供「无账户」。
      noneLabel: isTransfer
          ? null
          : AppLocalizations.of(context).noAccountLabel,
      noneHint: isTransfer ? null : AppLocalizations.of(context).noAccountHint,
    );
    if (selected != null && mounted) {
      setState(() {
        if (selected.id.isEmpty) {
          _noAccount = true;
          if (!_currencyTouched) {
            _currencyCode = VeriFinScope.of(
              context,
            ).activeBook.baseCurrencyCode;
          }
        } else {
          _noAccount = false;
          _accountId = selected.id;
          if (!_currencyTouched || isTransfer) {
            _currencyCode = selected.currencyCode;
          }
        }
        _normalizeTransferAccounts(accounts);
        _accountAmountTouched = false;
        _toAccountAmountTouched = false;
        _baseAmountTouched = false;
        _rememberRate = false;
        _resolveCurrencyAmounts(
          VeriFinScope.of(context),
          accounts,
          forceAccount: true,
          forceToAccount: true,
          forceBase: true,
        );
      });
    }
  }

  Future<void> _pickToAccount(List<Account> accounts) async {
    final selectableAccounts = accounts
        .where((account) => account.id != _accountId)
        .toList();
    if (selectableAccounts.isEmpty) {
      return;
    }
    final selected = await showAccountPickerSheet(
      context: context,
      title: AppLocalizations.of(context).pickTransferInAccount,
      accounts: selectableAccounts,
      selectedId: _toAccountId,
      balanceOf: VeriFinScope.of(context).accountBalance,
    );
    if (selected != null && mounted) {
      setState(() {
        _toAccountId = selected.id;
        _toAccountAmountTouched = false;
        _resolveCurrencyAmounts(
          VeriFinScope.of(context),
          accounts,
          forceToAccount: true,
        );
      });
    }
  }

  void _normalizeTransferAccounts(List<Account> accounts) {
    if (_type != EntryType.transfer) {
      _toAccountId = null;
      return;
    }
    final available = accounts;
    if (available.length < 2) {
      _toAccountId = null;
      return;
    }
    if (_toAccountId == null ||
        _toAccountId == _accountId ||
        !available.any((account) => account.id == _toAccountId)) {
      _toAccountId = available
          .firstWhere((account) => account.id != _accountId)
          .id;
    }
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
      // 已保存交易的三层金额是历史事实；只改日期不得按新日期汇率静默重算。
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _occurredAt = DateTime(
        _occurredAt.year,
        _occurredAt.month,
        _occurredAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _editNote() async {
    final note = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).noteEditTitle,
      label: AppLocalizations.of(context).commonNote,
      initialValue: _noteController.text,
      allowEmpty: true,
    );
    if (note != null && mounted) {
      setState(() => _noteController.text = note);
    }
  }

  double get _refundTotal =>
      _refunds.fold<double>(0, (total, refund) => total + refund.amount);

  LedgerEntry _buildEntry() {
    final entry = _initialEntry;
    if (entry == null) {
      throw StateError('Transaction draft is not initialized.');
    }
    final noAccount = _type != EntryType.transfer && _noAccount;
    return entry.copyWith(
      type: _type,
      amount: normalizeCurrencyAmount(_amount, _currencyCode),
      currencyCode: _currencyCode,
      accountAmount: noAccount
          ? null
          : normalizeCurrencyAmount(
              _accountAmount ?? _amount,
              _findAccount(
                    VeriFinScope.of(context).accounts,
                    _accountId,
                  )?.currencyCode ??
                  _currencyCode,
            ),
      clearAccountAmount: noAccount,
      toAccountAmount: _type == EntryType.transfer && _toAccountId != null
          ? normalizeCurrencyAmount(
              _toAccountAmount ?? _amount,
              _findAccount(
                    VeriFinScope.of(context).accounts,
                    _toAccountId,
                  )?.currencyCode ??
                  _currencyCode,
            )
          : null,
      clearToAccountAmount: _type != EntryType.transfer,
      baseAmount: _type == EntryType.transfer
          ? 0
          : normalizeCurrencyAmount(
              _baseAmount,
              VeriFinScope.of(context).activeBook.baseCurrencyCode,
            ),
      conversionSource: _conversionSource,
      categoryId: _categoryId,
      accountId: noAccount ? '' : _accountId,
      toAccountId: _type == EntryType.transfer ? _toAccountId : null,
      clearToAccountId: _type != EntryType.transfer,
      note: _noteController.text.trim(),
      occurredAt: _occurredAt,
      tagIds: List<String>.of(_tagIds),
      fee: _type == EntryType.transfer
          ? normalizeCurrencyAmount(_fee, _currencyCode)
          : 0,
      reimbursable: _type == EntryType.expense && _reimbursable,
      refundedBaseAmount: _type == EntryType.expense
          ? _refunds
                .where((refund) => refund.isSettledRefund)
                .fold<double>(0, (total, refund) => total + refund.baseAmount)
                .clamp(0.0, _baseAmount)
                .toDouble()
          : 0,
    );
  }

  String get _draftFingerprint {
    final refunds = List<LedgerEntry>.of(_refunds)
      ..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode(<String, Object?>{
      'entry': _buildEntry().toJson(),
      'refunds': refunds.map((refund) => refund.toJson()).toList(),
      'attachments': _attachments
          .map((attachment) => attachment.toJson())
          .toList(),
    });
  }

  bool get _isDirty =>
      _initialEntry != null && _draftFingerprint != _initialFingerprint;

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(() => _initialFingerprint = _draftFingerprint);
      _exitController.exit();
    }
  }

  Future<bool> _save() async {
    if (_saving || _initialEntry == null) {
      return false;
    }
    if (_type == EntryType.transfer &&
        (_toAccountId == null || _toAccountId == _accountId)) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: AppLocalizations.of(context).transferNeedsTwoAccounts,
          tone: VeriFeedbackTone.warning,
        ),
      );
      return false;
    }
    if (_refundTotal > _amount + currencyAmountTolerance(_currencyCode) ||
        (_type != EntryType.expense && _refunds.isNotEmpty)) {
      return false;
    }
    _saving = true;
    final result = await VeriFinScope.of(context).saveEntryAggregateDraftResult(
      entry: _buildEntry(),
      isNew: false,
      refunds: _refunds,
      attachments: _attachments,
      rememberRateCurrencyCode: _rememberRate ? _currencyCode : null,
      rememberRateToBase: _rememberRate ? _baseAmount / _amount : null,
      rememberRateEffectiveDate: _rememberRate ? _occurredAt : null,
    );
    if (mounted) {
      _saving = false;
    }
    if (result is EntrySaveValidationFailure && mounted) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: AppLocalizations.of(context).entrySaveValidationFailed,
          tone: VeriFeedbackTone.warning,
          duration: VeriFeedbackDuration.long,
        ),
      );
    }
    return result.isSuccess;
  }

  Future<void> _delete() async {
    final entry = _initialEntry;
    if (entry == null || !await _confirmDeleteEntry(context, entry)) {
      return;
    }
    if (mounted) {
      _exitController.exit();
    }
  }

  List<String> _tagLabels(VeriFinController controller) {
    return <String>[
      for (final id in _tagIds)
        if (controller.tagById(id) case final Tag tag) tag.label,
    ];
  }

  Future<void> _pickTags() async {
    final result = await pickEntryTags(context: context, selectedIds: _tagIds);
    if (!mounted || result == null) {
      return;
    }
    setState(() => _tagIds = result);
  }
}

Future<bool> _confirmDeleteEntry(
  BuildContext context,
  LedgerEntry entry,
) async {
  final controller = VeriFinScope.of(context);
  final confirmed = await showConfirmDialog(
    context,
    title: AppLocalizations.of(context).deleteEntryTitle,
    message: AppLocalizations.of(context).deleteEntryMessage,
    confirmLabel: AppLocalizations.of(context).commonDelete,
    destructive: true,
  );
  if (!context.mounted || !confirmed) {
    return false;
  }
  controller.deleteEntry(entry.id);
  return true;
}

void openEntryDetail(BuildContext context, LedgerEntry entry) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => TransactionDetailPage(entryId: entry.id),
    ),
  );
}

/// 多选模式底部操作栏：全选 / 删除 / 改分类 / 改账户。
