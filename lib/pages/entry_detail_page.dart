import 'package:flutter/material.dart';

import '../app/ai/ai_entry_parser.dart';
import '../app/app_theme.dart';
import '../app/category_suggest.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
import '../app/entry_sheets.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'attachments_editor.dart';
import 'sheets.dart';

class EntryDetailPage extends StatefulWidget {
  const EntryDetailPage({
    super.key,
    required this.initialAmount,
    this.initialAccountId,
    this.initialDraft,
  });

  final double initialAmount;
  final String? initialAccountId;

  /// AI 解析出的草稿：非空时预填表单并显示复核提示，供用户确认/修改后落账。
  final AiEntryDraft? initialDraft;

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  late double _amount = widget.initialAmount;
  EntryType _type = EntryType.expense;
  String _categoryId = 'dining';
  late String _accountId = widget.initialAccountId ?? '';
  // 「无账户」：只记金额、不计入任何账户余额（仅收支有效，转账必须选账户）。
  bool _noAccount = false;
  String? _toAccountId;
  DateTime _occurredAt = DateTime.now();
  double _fee = 0;
  List<String> _tagIds = <String>[];
  // 新增交易时先缓存附件 data URL，保存后再按新交易 id 落库。
  final List<String> _pendingAttachments = <String>[];
  final TextEditingController _noteController = TextEditingController();

  // 自动分类：用户尚未手动选过分类前，按备注/习惯自动推荐并选中；一旦手动选过就不再
  // 覆盖。_suggestedCategoryId 记当前推荐项（用于提示与置顶展示）。
  bool _categoryTouched = false;
  String? _suggestedCategoryId;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteChanged);
    final draft = widget.initialDraft;
    if (draft != null) {
      _type = draft.type;
      if (draft.categoryId.isNotEmpty) {
        _categoryId = draft.categoryId;
        // AI 已给出分类，视作已选，不用历史推荐覆盖。
        _categoryTouched = true;
      }
      // 转账必须落到账户；收支允许「无账户」（空 accountId）。
      if (draft.type != EntryType.transfer && draft.accountId.isEmpty) {
        _noAccount = true;
        _accountId = '';
      } else {
        _accountId = draft.accountId;
      }
      _toAccountId = draft.toAccountId;
      _occurredAt = draft.occurredAt;
      _noteController.text = draft.note;
    }
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  // 备注变化时，若用户还没手动选过分类，重跑推荐（触发 build 重算）。
  void _onNoteChanged() {
    if (_categoryTouched || !mounted) {
      return;
    }
    setState(() {});
  }

  /// 在未手动选分类时，按当前备注/金额/时段从历史推荐一个分类并选中。
  /// 直接在 build 期间调用（与既有「分类不在清单则回退首项」同为纯赋值，不触发
  /// setState）。返回推荐的分类 id（无把握时为 null）。
  String? _applyAutoCategory(VeriFinController controller, EntryType type) {
    if (_categoryTouched || type == EntryType.transfer) {
      return null;
    }
    final candidateIds = controller
        .categoriesForType(type)
        .map((c) => c.id)
        .toSet();
    final history = controller.entries
        .where((e) => e.type == type)
        .toList(growable: false);
    final suggestion = suggestCategoryId(
      history: history,
      candidateIds: candidateIds,
      note: _noteController.text,
      amount: _amount,
      hour: _occurredAt.hour,
    );
    if (suggestion != null) {
      _categoryId = suggestion;
    }
    return suggestion;
  }

  /// 分类快捷区展示的前若干个分类；若当前选中项（含自动推荐）不在前 8 个里，则把它
  /// 置顶插入，保证被选中/推荐的分类始终可见。
  List<Category> _visibleCategoryChips(List<Category> categories) {
    final shown = categories.take(8).toList();
    if (!shown.any((c) => c.id == _categoryId)) {
      final idx = categories.indexWhere((c) => c.id == _categoryId);
      if (idx >= 0) {
        shown.insert(0, categories[idx]);
        if (shown.length > 8) {
          shown.removeLast();
        }
      }
    }
    return shown;
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final accounts = controller.accounts
        .where((account) => !account.hidden)
        .toList();
    final hasAccounts = accounts.isNotEmpty;
    // 转账必须落到具体账户，不允许「无账户」。
    if (_type == EntryType.transfer) {
      _noAccount = false;
    }
    if (hasAccounts &&
        !_noAccount &&
        !accounts.any((account) => account.id == _accountId)) {
      _accountId = accounts.first.id;
    }
    _normalizeTransferAccounts(accounts);
    final categories = controller.categoriesForType(_type);
    if (!categories.any((category) => category.id == _categoryId)) {
      _categoryId = categories.first.id;
    }
    // 自动分类：未手动选过时按备注/习惯推荐并选中（可能改写上面的 _categoryId）。
    _suggestedCategoryId = _applyAutoCategory(controller, _type);
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
                  if (widget.initialDraft != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _AiReviewBanner(draft: widget.initialDraft!),
                  ],
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
                  Row(
                    children: <Widget>[
                      Text(
                        AppLocalizations.of(context).commonCategory,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_suggestedCategoryId != null &&
                          !_categoryTouched) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.auto_awesome, size: 14, color: veriRoyal),
                        const SizedBox(width: 3),
                        Text(
                          AppLocalizations.of(context).categoryAutoSuggested,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: veriRoyal,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ..._visibleCategoryChips(categories).map(
                        (category) => ChoiceChip(
                          avatar: Icon(
                            _categoryId == category.id &&
                                    _suggestedCategoryId == category.id &&
                                    !_categoryTouched
                                ? Icons.auto_awesome
                                : iconForCode(category.iconCode),
                            size: 18,
                          ),
                          label: Text(category.label),
                          selected: _categoryId == category.id,
                          onSelected: (_) {
                            setState(() {
                              _categoryId = category.id;
                              _categoryTouched = true;
                              _suggestedCategoryId = null;
                            });
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
                      value: _noAccount
                          ? AppLocalizations.of(context).noAccountLabel
                          : '${accountById(accounts, _accountId).name} (${formatAmount(controller.accountBalance(accountById(accounts, _accountId)))})',
                      icon: _noAccount ? Icons.money_off_csred_outlined : null,
                      leading: _noAccount
                          ? null
                          : AccountIconBox(
                              iconCode: accountById(
                                accounts,
                                _accountId,
                              ).iconCode,
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

    setState(() {
      _categoryId = selected;
      _categoryTouched = true;
      _suggestedCategoryId = null;
    });
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
    if (!mounted || selected == null) {
      return;
    }
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
    if (_type != EntryType.transfer) {
      // 无账户也可保存（只记金额）；否则需有可选账户。
      return _noAccount || accounts.isNotEmpty;
    }
    if (accounts.isEmpty) {
      return false;
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
    final noAccount = _type != EntryType.transfer && _noAccount;
    if (!noAccount &&
        !controller.accounts
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
        accountId: noAccount ? '' : _accountId,
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

/// AI 记账草稿的复核提示条：说明这是 AI 解析结果，并列出降级提示（分类/账户未匹配）。
class _AiReviewBanner extends StatelessWidget {
  const _AiReviewBanner({required this.draft});

  final AiEntryDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(veriRadiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.aiEntryReviewHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          for (final warning in draft.warnings) ...<Widget>[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                aiDraftWarningLabel(l10n, warning),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 把解析降级提示码本地化为一句提示文案。
String aiDraftWarningLabel(AppLocalizations l10n, AiDraftWarning warning) {
  switch (warning) {
    case AiDraftWarning.categoryUnmatched:
      return l10n.aiWarningCategoryUnmatched;
    case AiDraftWarning.accountUnmatched:
      return l10n.aiWarningAccountUnmatched;
  }
}
