import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/common_widgets.dart';
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
        : '${account.name} (${formatAmount(controller.accountBalance(account))})';
    final canSave =
        (accounts.isNotEmpty || _noAccount) &&
        (_type != EntryType.transfer ||
            (_toAccountId != null && _toAccountId != _accountId)) &&
        (_type == EntryType.expense
            ? _refundTotal <= _amount + 0.0001
            : _refunds.isEmpty);
    final amountColor = colorForType(_type);
    final amountText = switch (_type) {
      EntryType.expense => formatExpenseAmount(_amount),
      EntryType.income => '+${formatIncomeAmount(_amount)}',
      EntryType.transfer => formatAmount(_amount),
      EntryType.refund => '+${formatIncomeAmount(_amount)}',
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
                      DetailInfoRow(
                        label: AppLocalizations.of(context).commonType,
                        value: _type.label(AppLocalizations.of(context)),
                        onTap: _pickType,
                      ),
                      DetailInfoRow(
                        label: AppLocalizations.of(context).commonCategory,
                        value: category.label,
                        onTap: _pickCategory,
                      ),
                      if (_type == EntryType.transfer) ...<Widget>[
                        DetailInfoRow(
                          label: AppLocalizations.of(
                            context,
                          ).transferOutAccount,
                          value:
                              '${account.name} (${formatAmount(controller.accountBalance(account))})',
                          onTap: accounts.isEmpty
                              ? null
                              : () => _pickAccount(accounts),
                        ),
                        DetailInfoRow(
                          label: AppLocalizations.of(context).transferInAccount,
                          value: toAccount == null
                              ? AppLocalizations.of(context).pleaseSelect
                              : '${toAccount.name} (${formatAmount(controller.accountBalance(toAccount))})',
                          placeholder: toAccount == null,
                          onTap: accounts.length < 2
                              ? null
                              : () => _pickToAccount(accounts),
                        ),
                        DetailInfoRow(
                          label: AppLocalizations.of(context).feeLabel,
                          value: _fee > 0
                              ? formatAmount(_fee)
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

  Future<void> _editAmount() async {
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).amountEditTitle,
      initialAmount: _amount,
    );
    if (amount == null || amount <= 0 || !mounted) {
      return;
    }
    setState(() => _amount = amount);
  }

  Future<void> _editFee() async {
    final fee = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).transferFeeTitle,
      initialAmount: _fee > 0 ? _fee : null,
      allowZero: true,
    );
    if (fee == null || fee < 0 || !mounted) {
      return;
    }
    setState(() => _fee = fee);
  }

  Future<void> _pickType() async {
    final values = _refunds.isEmpty
        ? EntryType.userSelectable
        : const <EntryType>[EntryType.expense];
    final selected = await showOptionSheet<EntryType>(
      context: context,
      title: AppLocalizations.of(context).pickTypeTitle,
      values: values,
      selected: _type,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _type = selected;
      final controller = VeriFinScope.of(context);
      if (controller.categoryById(_categoryId).type != _type) {
        _categoryId = controller.categoriesForType(_type).first.id;
      }
      _normalizeTransferAccounts(controller.accounts);
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
        } else {
          _noAccount = false;
          _accountId = selected.id;
        }
        _normalizeTransferAccounts(accounts);
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
      setState(() => _toAccountId = selected.id);
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

  double get _settledRefundTotal => _refunds
      .where((refund) => refund.isSettledRefund)
      .fold<double>(0, (total, refund) => total + refund.amount);

  LedgerEntry _buildEntry() {
    final entry = _initialEntry;
    if (entry == null) {
      throw StateError('Transaction draft is not initialized.');
    }
    final noAccount = _type != EntryType.transfer && _noAccount;
    return entry.copyWith(
      type: _type,
      amount: _amount,
      categoryId: _categoryId,
      accountId: noAccount ? '' : _accountId,
      toAccountId: _type == EntryType.transfer ? _toAccountId : null,
      clearToAccountId: _type != EntryType.transfer,
      note: _noteController.text.trim(),
      occurredAt: _occurredAt,
      tagIds: List<String>.of(_tagIds),
      fee: _type == EntryType.transfer ? _fee : 0,
      reimbursable: _type == EntryType.expense && _reimbursable,
      refundedAmount: _type == EntryType.expense
          ? _settledRefundTotal.clamp(0.0, _amount).toDouble()
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).transferNeedsTwoAccounts),
        ),
      );
      return false;
    }
    if (_refundTotal > _amount + 0.0001 ||
        (_type != EntryType.expense && _refunds.isNotEmpty)) {
      return false;
    }
    _saving = true;
    final saved = await VeriFinScope.of(context).saveEntryAggregateDraft(
      entry: _buildEntry(),
      isNew: false,
      refunds: _refunds,
      attachments: _attachments,
    );
    if (mounted) {
      _saving = false;
    }
    return saved;
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
