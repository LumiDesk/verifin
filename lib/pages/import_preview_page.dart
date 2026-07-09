import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/backup/transaction_import.dart';
import '../app/common_widgets.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'entry_detail_page.dart';
import 'sheets.dart';

/// 导入预览页确认后返回的结果：最终要落库的交易，以及（可能被改名的）待新建
/// 账户 / 分类候选。落库时只创建其中被保留交易实际引用到的那些。
class ImportPreviewResult {
  const ImportPreviewResult({
    required this.entries,
    required this.candidateAccounts,
    required this.candidateCategories,
    this.alwaysCreateAccountIds = const <String>{},
  });

  final List<LedgerEntry> entries;
  final List<Account> candidateAccounts;
  final List<Category> candidateCategories;

  /// 即便没有交易引用也要创建的候选账户 id（Tally 携带余额的账户）；已被用户映射到
  /// 现有账户的不在其中。
  final Set<String> alwaysCreateAccountIds;
}

/// 账单导入预览页：解析后、落库前展示即将导入的交易（按日期分组），用户可逐条排除
/// / 编辑，也可在「导入账户 / 分类」映射区里把某个待新建的账户/分类整体改名或映射到
/// 现有条目（对所有引用它的交易一次性生效）。
class ImportPreviewPage extends StatefulWidget {
  const ImportPreviewPage({
    super.key,
    required this.plan,
    required this.sourceLabel,
  });

  final ImportPlan plan;
  final String sourceLabel;

  @override
  State<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends State<ImportPreviewPage> {
  late final List<LedgerEntry> _entries = List<LedgerEntry>.of(
    widget.plan.entries,
  )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  final Set<String> _excluded = <String>{};

  // 映射：待新建账户/分类 id → 改后的名称（默认原名）。
  late final Map<String, String> _accountName = <String, String>{
    for (final account in widget.plan.newAccounts) account.id: account.name,
  };
  late final Map<String, String> _categoryName = <String, String>{
    for (final category in widget.plan.newCategories)
      category.id: category.label,
  };
  // 映射：待新建账户/分类 id → 映射到的现有条目 id（存在=映射，缺省=新建）。
  final Map<String, String> _accountMapTo = <String, String>{};
  final Map<String, String> _categoryMapTo = <String, String>{};

  // 携带余额的来源（Tally）默认展开账户区，便于核对账户与余额；其余默认折叠。
  late bool _accountsExpanded = widget.plan.standaloneAccountIds.isNotEmpty;
  bool _categoriesExpanded = false;

  bool _isIncluded(LedgerEntry entry) => !_excluded.contains(entry.id);

  /// 某待新建账户导入后的余额 = 初始余额 + 该账户在**当前保留且编辑后**的待导入交易
  /// 中的增量合计。只算保留交易，与落库（`applyImportEntries` 同样只加入保留交易）
  /// 结果一致——排除或改金额后此处会随之更新，不再一直显示来源原始余额。
  double _accountResultingBalance(Account account) {
    var balance = account.initialBalance;
    for (final entry in _entries) {
      if (!_isIncluded(entry)) {
        continue;
      }
      balance += accountDeltaForEntry(entry, account.id);
    }
    return balance;
  }

  /// 该来源是否携带账户余额（Tally 等）：有独立账户即认为带余额，用于决定是否展示金额。
  bool get _hasAccountBalances => widget.plan.standaloneAccountIds.isNotEmpty;

  /// 会被创建的独立账户数（未映射到现有账户的）。
  int get _accountsToCreateCount => widget.plan.standaloneAccountIds
      .where((id) => !_accountMapTo.containsKey(id))
      .length;

  String _resolveAccountId(String id) => _accountMapTo[id] ?? id;
  String _resolveCategoryId(String id) => _categoryMapTo[id] ?? id;

  /// 把交易里对「待新建账户/分类」的引用解析为最终 id（映射后）。
  LedgerEntry _resolved(LedgerEntry entry) {
    final toAccountId = entry.toAccountId;
    return entry.copyWith(
      accountId: _resolveAccountId(entry.accountId),
      categoryId: _resolveCategoryId(entry.categoryId),
      toAccountId: (toAccountId == null || toAccountId.isEmpty)
          ? toAccountId
          : _resolveAccountId(toAccountId),
    );
  }

  List<Account> _mergedAccounts(List<Account> existing) => <Account>[
    ...existing,
    ...widget.plan.newAccounts.map(
      (account) => account.copyWith(name: _accountName[account.id]),
    ),
  ];

  List<Category> _mergedCategories(List<Category> existing) => <Category>[
    ...existing,
    ...widget.plan.newCategories.map(
      (category) => category.copyWith(label: _categoryName[category.id]),
    ),
  ];

  void _toggle(LedgerEntry entry) {
    setState(() {
      if (_excluded.contains(entry.id)) {
        _excluded.remove(entry.id);
      } else {
        _excluded.add(entry.id);
      }
    });
  }

  void _selectAll() => setState(_excluded.clear);

  void _deselectAll() => setState(() {
    _excluded
      ..clear()
      ..addAll(_entries.map((entry) => entry.id));
  });

  Future<void> _edit(
    LedgerEntry resolvedEntry,
    List<Account> accounts,
    List<Category> categories,
  ) async {
    final edited = await Navigator.of(context).push<LedgerEntry>(
      MaterialPageRoute<LedgerEntry>(
        builder: (_) => EntryDetailPage.draft(
          entry: resolvedEntry,
          extraAccounts: _mergedAccounts(accounts)
              .where(
                (account) =>
                    widget.plan.newAccounts.any((a) => a.id == account.id),
              )
              .toList(),
          extraCategories: _mergedCategories(categories)
              .where(
                (category) =>
                    widget.plan.newCategories.any((c) => c.id == category.id),
              )
              .toList(),
        ),
      ),
    );
    if (edited == null || !mounted) {
      return;
    }
    setState(() {
      final index = _entries.indexWhere((item) => item.id == edited.id);
      if (index != -1) {
        _entries[index] = edited;
      }
    });
  }

  void _confirm() {
    final included = _entries
        .where(_isIncluded)
        .map(_resolved)
        .toList(growable: false);
    Navigator.of(context).pop(
      ImportPreviewResult(
        entries: included,
        candidateAccounts: widget.plan.newAccounts
            .map((account) => account.copyWith(name: _accountName[account.id]))
            .toList(),
        candidateCategories: widget.plan.newCategories
            .map(
              (category) =>
                  category.copyWith(label: _categoryName[category.id]),
            )
            .toList(),
        // 映射到现有账户的独立账户不再新建（交易已改指向现有账户）。
        alwaysCreateAccountIds: widget.plan.standaloneAccountIds
            .where((id) => !_accountMapTo.containsKey(id))
            .toSet(),
      ),
    );
  }

  Future<void> _showSkippedRows() {
    final l10n = AppLocalizations.of(context);
    final lines = widget.plan.errors
        .take(20)
        .map((error) => l10n.lineError(error.line, error.message))
        .join('\n');
    final more = widget.plan.errorCount > 20
        ? '\n${l10n.moreLines(widget.plan.errorCount - 20)}'
        : '';
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importPreviewSkippedTitle),
        content: SingleChildScrollView(child: Text('$lines$more')),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.gotIt),
          ),
        ],
      ),
    );
  }

  // ── 账户映射 ────────────────────────────────────────────────
  Future<void> _pickAccountDecision(
    Account provisional,
    List<Account> existing,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _DecisionSheet(
        title: l10n.mappingAccountSheetTitle(_accountName[provisional.id]!),
        keepNewLabel: l10n.mappingKeepNewAccount,
        mapSectionLabel: l10n.mappingMapToExistingAccount,
        keepNewSelected: !_accountMapTo.containsKey(provisional.id),
        options: <_DecisionOption>[
          for (final account in existing.where((a) => !a.hidden))
            _DecisionOption(
              id: account.id,
              label: account.name,
              leading: AccountIconBox(iconCode: account.iconCode, size: 26),
              selected: _accountMapTo[provisional.id] == account.id,
            ),
        ],
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      if (result == _DecisionSheet.keepNewValue) {
        _accountMapTo.remove(provisional.id);
      } else {
        _accountMapTo[provisional.id] = result;
      }
    });
  }

  Future<void> _renameAccount(Account provisional) async {
    final name = await _promptName(
      title: AppLocalizations.of(context).mappingRenameAccount,
      initial: _accountName[provisional.id]!,
    );
    if (name == null || !mounted) {
      return;
    }
    setState(() {
      _accountName[provisional.id] = name;
      _accountMapTo.remove(provisional.id);
    });
  }

  // ── 分类映射 ────────────────────────────────────────────────
  Future<void> _pickCategoryDecision(
    Category provisional,
    List<Category> existing,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _DecisionSheet(
        title: l10n.mappingCategorySheetTitle(_categoryName[provisional.id]!),
        keepNewLabel: l10n.mappingKeepNewCategory,
        mapSectionLabel: l10n.mappingMapToExistingCategory,
        keepNewSelected: !_categoryMapTo.containsKey(provisional.id),
        options: <_DecisionOption>[
          for (final category in existing.where(
            (c) => c.type == provisional.type,
          ))
            _DecisionOption(
              id: category.id,
              label: category.label,
              leading: CategoryIconBox(
                iconCode: category.iconCode,
                color: veriRoyal,
                size: 26,
              ),
              selected: _categoryMapTo[provisional.id] == category.id,
            ),
        ],
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      if (result == _DecisionSheet.keepNewValue) {
        _categoryMapTo.remove(provisional.id);
      } else {
        _categoryMapTo[provisional.id] = result;
      }
    });
  }

  Future<void> _renameCategory(Category provisional) async {
    final name = await _promptName(
      title: AppLocalizations.of(context).mappingRenameCategory,
      initial: _categoryName[provisional.id]!,
    );
    if (name == null || !mounted) {
      return;
    }
    setState(() {
      _categoryName[provisional.id] = name;
      _categoryMapTo.remove(provisional.id);
    });
  }

  Future<String?> _promptName({
    required String title,
    required String initial,
  }) {
    return showTextInputDialog(
      context: context,
      title: title,
      label: AppLocalizations.of(context).mappingNewNameLabel,
      initialValue: initial,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final existingAccounts = controller.accounts;
    final existingCategories = controller.categories;
    final accounts = _mergedAccounts(existingAccounts);
    final categories = _mergedCategories(existingCategories);

    final displayGroups = groupEntriesByDate(
      _entries.map(_resolved).toList(growable: false),
    );
    final selectedIds = _entries
        .where(_isIncluded)
        .map((entry) => entry.id)
        .toSet();
    final includedCount = selectedIds.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: VeriHeader(
                title: l10n.importPreviewTitle,
                subtitle: widget.sourceLabel,
                showBack: true,
                actions: <Widget>[
                  if (_entries.isNotEmpty)
                    HeaderTextAction(
                      label: includedCount == _entries.length
                          ? l10n.importPreviewDeselectAll
                          : l10n.importPreviewSelectAll,
                      onPressed: includedCount == _entries.length
                          ? _deselectAll
                          : _selectAll,
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                children: <Widget>[
                  // 有交易或有跳过行时才显示交易汇总卡；纯账户导入时略去。
                  if (_entries.isNotEmpty || widget.plan.errorCount > 0)
                    _SummaryCard(
                      included: includedCount,
                      total: _entries.length,
                      skipped: widget.plan.errorCount,
                      onViewSkipped: _showSkippedRows,
                    ),
                  if (widget.plan.newAccounts.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    _MappingCard(
                      title: l10n.importAccountMapping,
                      summary: _accountSummary(l10n),
                      expanded: _accountsExpanded,
                      onToggle: () => setState(
                        () => _accountsExpanded = !_accountsExpanded,
                      ),
                      rows: <Widget>[
                        for (final account in widget.plan.newAccounts)
                          _MappingRow(
                            source: account.name,
                            decision: _accountDecisionText(l10n, account),
                            keptNew: !_accountMapTo.containsKey(account.id),
                            // 携带余额的来源（Tally）展示每个账户导入后的余额，便于核对。
                            amountText: _hasAccountBalances
                                ? formatAmount(
                                    _accountResultingBalance(account),
                                  )
                                : null,
                            onRename: () => _renameAccount(account),
                            onTap: () =>
                                _pickAccountDecision(account, existingAccounts),
                          ),
                      ],
                    ),
                  ],
                  if (widget.plan.newCategories.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    _MappingCard(
                      title: l10n.importCategoryMapping,
                      summary: _categorySummary(l10n),
                      expanded: _categoriesExpanded,
                      onToggle: () => setState(
                        () => _categoriesExpanded = !_categoriesExpanded,
                      ),
                      rows: <Widget>[
                        for (final category in widget.plan.newCategories)
                          _MappingRow(
                            source: category.label,
                            decision: _categoryDecisionText(l10n, category),
                            keptNew: !_categoryMapTo.containsKey(category.id),
                            onRename: () => _renameCategory(category),
                            onTap: () => _pickCategoryDecision(
                              category,
                              existingCategories,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
                    child: Text(
                      l10n.importPreviewHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  for (final group in displayGroups) ...<Widget>[
                    DateGroupHeader(date: group.date, entries: group.entries),
                    const SizedBox(height: 8),
                    Opacity(
                      // 全组被排除时整体淡化。
                      opacity:
                          group.entries.any((e) => selectedIds.contains(e.id))
                          ? 1
                          : 0.5,
                      child: TransactionListCard(
                        entries: group.entries,
                        accounts: accounts,
                        categories: categories,
                        selectionMode: true,
                        selectedIds: selectedIds,
                        onEntryTap: _toggle,
                        onEntryLongPress: (entry) =>
                            _edit(entry, existingAccounts, existingCategories),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  // 有交易可导入、或有账户可创建（纯账户导入）时都可确认。
                  onPressed: (includedCount == 0 && _accountsToCreateCount == 0)
                      ? null
                      : _confirm,
                  child: Text(
                    includedCount == 0
                        ? l10n.importPreviewConfirmAccountsOnly(
                            _accountsToCreateCount,
                          )
                        : l10n.importPreviewConfirm(includedCount),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _accountDecisionText(AppLocalizations l10n, Account provisional) {
    final target = _accountMapTo[provisional.id];
    if (target != null) {
      final name = VeriFinScope.of(context).accounts
          .firstWhere((a) => a.id == target, orElse: () => provisional)
          .name;
      return l10n.mappingRowMapped(name);
    }
    final name = _accountName[provisional.id]!;
    return name == provisional.name
        ? l10n.mappingRowNew
        : l10n.mappingRowRenamed(name);
  }

  String _categoryDecisionText(AppLocalizations l10n, Category provisional) {
    final target = _categoryMapTo[provisional.id];
    if (target != null) {
      final label = VeriFinScope.of(context).categoryById(target).label;
      return l10n.mappingRowMapped(label);
    }
    final name = _categoryName[provisional.id]!;
    return name == provisional.label
        ? l10n.mappingRowNew
        : l10n.mappingRowRenamed(name);
  }

  String _accountSummary(AppLocalizations l10n) {
    final mapped = _accountMapTo.length;
    final keptNew = widget.plan.newAccounts.length - mapped;
    return l10n.mappingSummary(keptNew, mapped);
  }

  String _categorySummary(AppLocalizations l10n) {
    final mapped = _categoryMapTo.length;
    final keptNew = widget.plan.newCategories.length - mapped;
    return l10n.mappingSummary(keptNew, mapped);
  }
}

/// 顶部汇总卡：将导入笔数 + 跳过行入口。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.included,
    required this.total,
    required this.skipped,
    required this.onViewSkipped,
  });

  final int included;
  final int total;
  final int skipped;
  final VoidCallback onViewSkipped;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VeriCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.importPreviewSelectedOf(included, total),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (skipped > 0)
            ActionChip(
              avatar: Icon(Icons.error_outline, size: 16, color: veriExpense),
              label: Text(l10n.importPreviewSkipped(skipped)),
              onPressed: onViewSkipped,
            ),
        ],
      ),
    );
  }
}

/// 可折叠的映射卡（导入账户 / 导入分类）。
class _MappingCard extends StatelessWidget {
  const _MappingCard({
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.rows,
  });

  final String title;
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return VeriCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(veriRadiusMd),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) ...<Widget>[
            const Divider(height: 1),
            ...rows,
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

/// 映射区里的一行：来源名称 + 当前处理（新建 / 改名 / 映射到现有），可改名、可点开选择。
class _MappingRow extends StatelessWidget {
  const _MappingRow({
    required this.source,
    required this.decision,
    required this.keptNew,
    required this.onRename,
    required this.onTap,
    this.amountText,
  });

  final String source;
  final String decision;
  final bool keptNew;
  final VoidCallback onRename;
  final VoidCallback onTap;

  /// 可选：右侧展示的金额文案（如账户导入后的余额）。为空则不展示。
  final String? amountText;

  @override
  Widget build(BuildContext context) {
    final amount = amountText;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 8, 6, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    decision,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            if (amount != null) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                amount,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (keptNew)
              IconButton(
                tooltip: AppLocalizations.of(context).mappingRenameTooltip,
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onRename,
              ),
            const Icon(Icons.unfold_more, size: 18),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _DecisionOption {
  const _DecisionOption({
    required this.id,
    required this.label,
    required this.leading,
    required this.selected,
  });

  final String id;
  final String label;
  final Widget leading;
  final bool selected;
}

/// 处理某个待新建账户/分类的选择弹窗：新建 或 映射到某个现有条目。
class _DecisionSheet extends StatelessWidget {
  const _DecisionSheet({
    required this.title,
    required this.keepNewLabel,
    required this.mapSectionLabel,
    required this.keepNewSelected,
    required this.options,
  });

  static const String keepNewValue = '__keep_new__';

  final String title;
  final String keepNewLabel;
  final String mapSectionLabel;
  final bool keepNewSelected;
  final List<_DecisionOption> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(keepNewLabel),
              trailing: keepNewSelected
                  ? const Icon(Icons.check, color: veriRoyal)
                  : null,
              onTap: () => Navigator.of(context).pop(keepNewValue),
            ),
            if (options.isNotEmpty) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Text(
                  mapSectionLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              for (final option in options)
                ListTile(
                  leading: option.leading,
                  title: Text(option.label),
                  trailing: option.selected
                      ? const Icon(Icons.check, color: veriRoyal)
                      : null,
                  onTap: () => Navigator.of(context).pop(option.id),
                ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 改名对话框。用 StatefulWidget 持有并在 [State.dispose]（路由完全移除、退出动画
/// 结束后才触发）里释放控制器，避免退出动画期间 TextField 用到已释放的控制器。
