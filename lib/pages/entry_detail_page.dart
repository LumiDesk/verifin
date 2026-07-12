import 'package:flutter/material.dart';

import '../app/ai/ai_entry_parser.dart';
import '../app/app_theme.dart';
import '../app/category_suggest.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
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
  }) : draftEntry = null,
       draftExtraAccounts = null,
       draftExtraCategories = null,
       draftExtraTags = null;

  /// 草稿编辑模式：编辑一条已有交易（如导入预览里的条目），保存时**不落库**，
  /// 而是通过 `Navigator.pop` 返回修改后的 [LedgerEntry] 供上层处理。
  /// [extraAccounts]/[extraCategories]/[extraTags] 是尚未落库的临时账户/分类/标签
  /// （如导入将新建的），合并进选择器与展示，保证草稿引用到它们时能正确解析、不被回退。
  EntryDetailPage.draft({
    super.key,
    required LedgerEntry entry,
    List<Account> extraAccounts = const <Account>[],
    List<Category> extraCategories = const <Category>[],
    List<Tag> extraTags = const <Tag>[],
  }) : draftEntry = entry,
       draftExtraAccounts = extraAccounts,
       draftExtraCategories = extraCategories,
       draftExtraTags = extraTags,
       initialAmount = entry.amount,
       initialAccountId = null,
       initialDraft = null;

  final double initialAmount;
  final String? initialAccountId;

  /// AI 解析出的草稿：非空时预填表单并显示复核提示，供用户确认/修改后落账。
  final AiEntryDraft? initialDraft;

  /// 草稿编辑模式下要编辑的交易；非空即进入「返回草稿不落库」模式。
  final LedgerEntry? draftEntry;

  /// 草稿模式下额外可选的临时账户 / 分类 / 标签（未落库，如导入待新建项）。
  final List<Account>? draftExtraAccounts;
  final List<Category>? draftExtraCategories;
  final List<Tag>? draftExtraTags;

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
  // 支出可标记「待报销」；新建时不涉及回款冲抵，退款金额建后在编辑页填写。
  bool _reimbursable = false;
  List<String> _tagIds = <String>[];
  // 新增交易时先缓存附件 data URL，保存后再按新交易 id 落库。
  final List<String> _pendingAttachments = <String>[];
  final TextEditingController _noteController = TextEditingController();

  // 自动识别：用户未手动改动某字段前，按历史（金额/备注/时段）自动填充类型、分类、
  // 标签、备注；某字段一旦被用户改过就不再覆盖它。AI 草稿模式（initialDraft）下整体
  // 关闭自动识别，尊重草稿。
  bool _typeTouched = false;
  bool _categoryTouched = false;
  bool _tagsTouched = false;
  bool _noteTouched = false;
  // 防重复提交：极快双击「保存」可能在 pop 生效前触发两次、落两条交易。
  bool _saving = false;
  // 程序化写入备注时置真，令备注监听忽略这次（不误判为用户输入）。
  bool _applyingSuggestion = false;
  bool _didInitialSuggest = false;
  // 草稿编辑模式（导入预览）与 AI 草稿一样关闭自动识别，尊重传入数据。
  late final bool _autoSuggestEnabled =
      widget.initialDraft == null && widget.draftEntry == null;

  bool get _isDraft => widget.draftEntry != null;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteChanged);
    final editing = widget.draftEntry;
    if (editing != null) {
      _type = editing.type;
      if (editing.categoryId.isNotEmpty) {
        _categoryId = editing.categoryId;
      }
      if (editing.type != EntryType.transfer && editing.accountId.isEmpty) {
        _noAccount = true;
        _accountId = '';
      } else {
        _accountId = editing.accountId;
      }
      _toAccountId = editing.toAccountId;
      _occurredAt = editing.occurredAt;
      _fee = editing.fee;
      _reimbursable = editing.reimbursable;
      _tagIds = List<String>.of(editing.tagIds);
      _applyingSuggestion = true;
      _noteController.text = editing.note;
      _applyingSuggestion = false;
    }
    final draft = widget.initialDraft;
    if (draft != null) {
      _type = draft.type;
      if (draft.categoryId.isNotEmpty) {
        _categoryId = draft.categoryId;
      }
      // 转账必须落到账户；收支允许「无账户」（空 accountId）。AI 没识别到账户时，
      // 若配置了默认付款账户（initialAccountId）就用它，否则记为「无账户」。
      if (draft.type != EntryType.transfer && draft.accountId.isEmpty) {
        final fallback = widget.initialAccountId ?? '';
        if (fallback.isNotEmpty) {
          _accountId = fallback;
        } else {
          _noAccount = true;
          _accountId = '';
        }
      } else {
        _accountId = draft.accountId;
      }
      _toAccountId = draft.toAccountId;
      _occurredAt = draft.occurredAt;
      _applyingSuggestion = true;
      _noteController.text = draft.note;
      _applyingSuggestion = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 开屏（金额已确定、备注为空）先按金额习惯识别一次。
    if (_autoSuggestEnabled && !_didInitialSuggest) {
      _didInitialSuggest = true;
      _recomputeSuggestion();
    }
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    if (!_autoSuggestEnabled || _applyingSuggestion || !mounted) {
      return;
    }
    // 用户真的在输备注：标记已改（不再回填备注），并按新备注重算类型/分类/标签。
    _noteTouched = true;
    _recomputeSuggestion();
  }

  /// 按当前金额/备注/时段从历史识别，并填充「用户尚未改过」的字段。
  void _recomputeSuggestion() {
    if (!_autoSuggestEnabled || !mounted) {
      return;
    }
    final controller = VeriFinScope.of(context);
    final suggestion = suggestEntry(
      history: controller.entries,
      expenseCategoryIds: controller
          .categoriesForType(EntryType.expense)
          .map((c) => c.id)
          .toSet(),
      incomeCategoryIds: controller
          .categoriesForType(EntryType.income)
          .map((c) => c.id)
          .toSet(),
      note: _noteController.text,
      amount: _amount,
      hour: _occurredAt.hour,
      // 用户已手动选过类型：不再翻转类型，只在该类型内识别分类/标签/备注。
      forcedType: _typeTouched ? _type : null,
    );
    if (suggestion.isEmpty) {
      return;
    }
    setState(() {
      if (!_typeTouched && suggestion.type != null) {
        _type = suggestion.type!;
      }
      if (!_categoryTouched && suggestion.categoryId != null) {
        _categoryId = suggestion.categoryId!;
      }
      if (!_tagsTouched && _tagIds.isEmpty && suggestion.tagIds != null) {
        _tagIds = List<String>.of(suggestion.tagIds!);
      }
      if (!_noteTouched &&
          _noteController.text.isEmpty &&
          suggestion.note != null) {
        _applyingSuggestion = true;
        _noteController.text = suggestion.note!;
        _applyingSuggestion = false;
      }
    });
  }

  /// 指定类型的可选分类：草稿模式下把传入的临时分类（未落库，如导入将新建的）
  /// 追加到账本现有分类之后，保证草稿引用到它们时能被解析、不被回退。
  List<Category> _categoriesForType(
    VeriFinController controller,
    EntryType type,
  ) {
    final base = controller.categoriesForType(type);
    if (!_isDraft) {
      return base;
    }
    return <Category>[
      ...base,
      ...widget.draftExtraCategories!.where(
        (category) => category.type == type,
      ),
    ];
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
    // 草稿模式下把临时账户（未落库，如导入将新建的）并入可选列表。
    final baseAccounts = _isDraft
        ? <Account>[...controller.accounts, ...widget.draftExtraAccounts!]
        : controller.accounts;
    final accounts = baseAccounts.where((account) => !account.hidden).toList();
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
    final categories = _categoriesForType(controller, _type);
    if (!categories.any((category) => category.id == _categoryId)) {
      _categoryId = categories.first.id;
    }
    // 大金额颜色跟随类型:支出红、收入青绿、转账保持蓝色。
    final amountColor = switch (_type) {
      EntryType.expense => veriExpense,
      EntryType.income => veriIncome,
      EntryType.transfer => veriBlue,
      // 退款不在此页手动选择，仅作穷尽兜底（正向流入用青绿）。
      EntryType.refund => veriIncome,
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
                    segments: EntryType.userSelectable
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
                        _typeTouched = true;
                        _categoryId = _categoriesForType(
                          controller,
                          _type,
                        ).first.id;
                        _normalizeTransferAccounts(accounts);
                      });
                      // 用户改了类型后，在该类型内重新识别分类/标签/备注。
                      _recomputeSuggestion();
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
                      ..._visibleCategoryChips(categories).map(
                        (category) => ChoiceChip(
                          avatar: CategoryGlyph(
                            iconCode: category.iconCode,
                            size: 18,
                          ),
                          label: Text(category.label),
                          selected: _categoryId == category.id,
                          onSelected: (_) {
                            setState(() {
                              _categoryId = category.id;
                              _categoryTouched = true;
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
                    tagLabelOf: (id) =>
                        controller.tagById(id)?.label ?? _extraTagLabel(id),
                    onTap: _pickTags,
                  ),
                  if (_type == EntryType.expense) ...<Widget>[
                    const SizedBox(height: 6),
                    Row(
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
                  ],
                  // 导入草稿编辑不涉及图片附件（附件在正式落库后按 id 关联）。
                  if (!_isDraft) ...<Widget>[
                    const Divider(height: 24),
                    AttachmentsEditor(
                      dataUrls: _pendingAttachments,
                      onAddDataUrl: (dataUrl) =>
                          setState(() => _pendingAttachments.add(dataUrl)),
                      onRemoveIndex: (index) =>
                          setState(() => _pendingAttachments.removeAt(index)),
                    ),
                  ],
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
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).amountEditTitle,
      initialAmount: _amount,
    );

    if (!mounted || amount == null || amount <= 0) {
      return;
    }

    setState(() => _amount = amount);
    // 金额变了，按新金额重新识别。
    _recomputeSuggestion();
  }

  Future<void> _editFee() async {
    final fee = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).transferFeeTitle,
      initialAmount: _fee > 0 ? _fee : null,
      allowZero: true,
    );
    if (!mounted || fee == null || fee < 0) {
      return;
    }
    setState(() => _fee = fee);
  }

  Future<void> _showAllCategories() async {
    final selected = await showCategoryPickerSheet(
      context,
      categories: _categoriesForType(VeriFinScope.of(context), _type),
      selectedId: _categoryId,
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _categoryId = selected;
      _categoryTouched = true;
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

  /// 草稿模式下临时标签（导入待新建）的名称，供展示解析——这些标签尚未落库，
  /// controller 查不到，故回退到 [EntryDetailPage.draftExtraTags]。
  String? _extraTagLabel(String id) {
    final extras = widget.draftExtraTags;
    if (extras == null) {
      return null;
    }
    for (final tag in extras) {
      if (tag.id == id) {
        return tag.label;
      }
    }
    return null;
  }

  Future<void> _pickTags() async {
    final result = await pickEntryTags(
      context: context,
      selectedIds: _tagIds,
      extraTags: widget.draftExtraTags ?? const <Tag>[],
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _tagIds = result;
      _tagsTouched = true;
    });
  }

  void _save() {
    if (_saving) {
      return;
    }
    final controller = VeriFinScope.of(context);
    final noAccount = _type != EntryType.transfer && _noAccount;
    // 草稿编辑模式：不落库，构造修改后的交易并回传给上层（如导入预览页）。
    if (_isDraft) {
      _saving = true;
      final original = widget.draftEntry!;
      Navigator.of(context).pop(
        LedgerEntry(
          id: original.id,
          bookId: original.bookId,
          type: _type,
          amount: _amount,
          // 转账不带分类，与导入/记账口径一致。
          categoryId: _type == EntryType.transfer ? '' : _categoryId,
          accountId: noAccount ? '' : _accountId,
          toAccountId: _type == EntryType.transfer ? _toAccountId : null,
          note: _noteController.text.trim(),
          occurredAt: _occurredAt,
          tagIds: _tagIds,
          fee: _type == EntryType.transfer ? _fee : 0,
          reimbursable: _type == EntryType.expense && _reimbursable,
          refundedAmount: original.refundedAmount,
        ),
      );
      return;
    }
    if (!noAccount &&
        !controller.accounts
            .where((account) => !account.hidden)
            .any((account) => account.id == _accountId)) {
      return;
    }
    _saving = true;
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
        reimbursable: _type == EntryType.expense && _reimbursable,
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
