import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
import '../app/entry_sheets.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'attachments_editor.dart';
import 'sheets.dart';

class EntryDetailPage extends StatefulWidget {
  const EntryDetailPage({
    super.key,
    required this.initialAmount,
    this.initialAccountId,
  });

  final double initialAmount;
  final String? initialAccountId;

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  late double _amount = widget.initialAmount;
  EntryType _type = EntryType.expense;
  String _categoryId = 'dining';
  late String _accountId = widget.initialAccountId ?? '';
  String? _toAccountId;
  DateTime _occurredAt = DateTime.now();
  double _fee = 0;
  List<String> _tagIds = <String>[];
  // 新增交易时先缓存附件 data URL，保存后再按新交易 id 落库。
  final List<String> _pendingAttachments = <String>[];
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final accounts = controller.accounts
        .where((account) => !account.hidden)
        .toList();
    final hasAccounts = accounts.isNotEmpty;
    if (hasAccounts && !accounts.any((account) => account.id == _accountId)) {
      _accountId = accounts.first.id;
    }
    _normalizeTransferAccounts(accounts);
    final categories = controller.categoriesForType(_type);
    if (!categories.any((category) => category.id == _categoryId)) {
      _categoryId = categories.first.id;
    }
    // 大金额颜色跟随类型:支出红、收入青绿、转账保持蓝色。
    final amountColor = switch (_type) {
      EntryType.expense => veriExpense,
      EntryType.income => veriIncome,
      EntryType.transfer => veriBlue,
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                children: <Widget>[
                  VeriHeader(
                    // 标题展示当前账本名（此前误为固定文案）。
                    title: controller.activeBook.name,
                    subtitle: AppLocalizations.of(context).entryDetailSubtitle,
                    showBack: true,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<EntryType>(
                    key: const Key('entry_type_segmented_button'),
                    segments: EntryType.values
                        .map(
                          (type) => ButtonSegment<EntryType>(
                            value: type,
                            label: Text(
                              type.label(AppLocalizations.of(context)),
                            ),
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
                        _normalizeTransferAccounts(accounts);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    key: const Key('detail_amount_button'),
                    borderRadius: BorderRadius.circular(veriRadiusMd),
                    onTap: _editAmount,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        formatAmount(_amount),
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: amountColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Text(
                    AppLocalizations.of(context).commonCategory,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ...categories
                          .take(8)
                          .map(
                            (category) => ChoiceChip(
                              avatar: Icon(
                                iconForCode(category.iconCode),
                                size: 18,
                              ),
                              label: Text(category.label),
                              selected: _categoryId == category.id,
                              onSelected: (_) {
                                setState(() => _categoryId = category.id);
                              },
                            ),
                          ),
                      ActionChip(
                        avatar: const Icon(Icons.more_horiz, size: 18),
                        label: Text(AppLocalizations.of(context).allLabel),
                        onPressed: _showAllCategories,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (hasAccounts && _type == EntryType.transfer) ...<Widget>[
                    SelectField(
                      key: const Key('account_dropdown'),
                      label: AppLocalizations.of(context).transferOutAccount,
                      value:
                          '${accountById(accounts, _accountId).name} (${formatAmount(controller.accountBalance(accountById(accounts, _accountId)))})',
                      leading: AccountIconBox(
                        iconCode: accountById(accounts, _accountId).iconCode,
                        size: 26,
                      ),
                      onTap: () => _pickAccount(accounts),
                    ),
                    const SizedBox(height: 10),
                    SelectField(
                      key: const Key('to_account_dropdown'),
                      label: AppLocalizations.of(context).transferInAccount,
                      value: _toAccountId == null
                          ? AppLocalizations.of(context).pleaseSelect
                          : '${accountById(accounts, _toAccountId!).name} (${formatAmount(controller.accountBalance(accountById(accounts, _toAccountId!)))})',
                      icon: _toAccountId == null ? Icons.call_received : null,
                      leading: _toAccountId == null
                          ? null
                          : AccountIconBox(
                              iconCode: accountById(
                                accounts,
                                _toAccountId!,
                              ).iconCode,
                              size: 26,
                            ),
                      onTap: accounts.length < 2
                          ? null
                          : () => _pickToAccount(accounts),
                    ),
                    const SizedBox(height: 10),
                    SelectField(
                      key: const Key('fee_field'),
                      label: AppLocalizations.of(context).feeLabel,
                      value: _fee > 0
                          ? formatAmount(_fee)
                          : AppLocalizations.of(context).feeNoneTapToFill,
                      icon: Icons.paid_outlined,
                      onTap: _editFee,
                    ),
                  ] else if (hasAccounts)
                    SelectField(
                      key: const Key('account_dropdown'),
                      label: AppLocalizations.of(context).accountLabel,
                      value:
                          '${accountById(accounts, _accountId).name} (${formatAmount(controller.accountBalance(accountById(accounts, _accountId)))})',
                      leading: AccountIconBox(
                        iconCode: accountById(accounts, _accountId).iconCode,
                        size: 26,
                      ),
                      onTap: () => _pickAccount(accounts),
                    )
                  else
                    EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: AppLocalizations.of(context).noUsableAccountTitle,
                      description: AppLocalizations.of(
                        context,
                      ).noUsableAccountDesc,
                    ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('entry_note_field'),
                    controller: _noteController,
                    maxLines: 1,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).commonNote,
                      hintText: AppLocalizations.of(context).noteHint,
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ActionChip(
                        avatar: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          AppLocalizations.of(
                            context,
                          ).dateMonthDay(_occurredAt),
                        ),
                        onPressed: _pickDate,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.schedule, size: 18),
                        label: Text(formatTime(_occurredAt)),
                        onPressed: _pickTime,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  EntryTagField(
                    tagIds: _tagIds,
                    tagLabelOf: (id) => controller.tagById(id)?.label,
                    onTap: _pickTags,
                  ),
                  const Divider(height: 24),
                  AttachmentsEditor(
                    dataUrls: _pendingAttachments,
                    onAddDataUrl: (dataUrl) =>
                        setState(() => _pendingAttachments.add(dataUrl)),
                    onRemoveIndex: (index) =>
                        setState(() => _pendingAttachments.removeAt(index)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: const Key('save_entry_button'),
                  onPressed: _canSave(accounts) ? _save : null,
                  child: Text(AppLocalizations.of(context).commonSave),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAmount() async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => NumberPadSheet(
        title: AppLocalizations.of(context).amountEditTitle,
        initialAmount: _amount,
        hapticsEnabled: VeriFinScope.of(context).hapticsEnabled,
      ),
    );

    if (!mounted || amount == null || amount <= 0) {
      return;
    }

    setState(() => _amount = amount);
  }

  Future<void> _editFee() async {
    final fee = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => NumberPadSheet(
        title: AppLocalizations.of(context).transferFeeTitle,
        initialAmount: _fee > 0 ? _fee : null,
        allowZero: true,
        hapticsEnabled: VeriFinScope.of(context).hapticsEnabled,
      ),
    );
    if (!mounted || fee == null || fee < 0) {
      return;
    }
    setState(() => _fee = fee);
  }

  Future<void> _showAllCategories() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => CategoryPickerSheet(
        categories: VeriFinScope.of(context).categoriesForType(_type),
        selectedId: _categoryId,
      ),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() => _categoryId = selected);
  }

  Future<void> _pickAccount(List<Account> accounts) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: _type == EntryType.transfer
          ? AppLocalizations.of(context).pickTransferOutAccount
          : AppLocalizations.of(context).pickAccountTitle,
      accounts: accounts,
      selectedId: _accountId,
      balanceOf: VeriFinScope.of(context).accountBalance,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _accountId = selected.id;
      _normalizeTransferAccounts(accounts);
    });
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
    if (accounts.length < 2) {
      _toAccountId = null;
      return;
    }
    if (_toAccountId == null ||
        _toAccountId == _accountId ||
        !accounts.any((account) => account.id == _toAccountId)) {
      _toAccountId = accounts
          .firstWhere((account) => account.id != _accountId)
          .id;
    }
  }

  bool _canSave(List<Account> accounts) {
    if (accounts.isEmpty) {
      return false;
    }
    if (_type != EntryType.transfer) {
      return true;
    }
    return _toAccountId != null && _toAccountId != _accountId;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (!mounted || picked == null) {
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

    if (!mounted || picked == null) {
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

  Future<void> _pickTags() async {
    final result = await pickEntryTags(context: context, selectedIds: _tagIds);
    if (!mounted || result == null) {
      return;
    }
    setState(() => _tagIds = result);
  }

  void _save() {
    final controller = VeriFinScope.of(context);
    if (!controller.accounts
        .where((account) => !account.hidden)
        .any((account) => account.id == _accountId)) {
      return;
    }
    final entryId = DateTime.now().microsecondsSinceEpoch.toString();
    controller.addEntry(
      LedgerEntry(
        id: entryId,
        bookId: controller.activeBook.id,
        type: _type,
        amount: _amount,
        categoryId: _categoryId,
        accountId: _accountId,
        toAccountId: _type == EntryType.transfer ? _toAccountId : null,
        note: _noteController.text.trim(),
        occurredAt: _occurredAt,
        tagIds: _tagIds,
        fee: _type == EntryType.transfer ? _fee : 0,
      ),
    );
    for (final dataUrl in _pendingAttachments) {
      controller.addAttachment(entryId, dataUrl);
    }
    Navigator.of(context).pop();
  }
}
