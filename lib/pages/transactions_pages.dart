import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/category_tree.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
import '../app/entry_sheets.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/series_math.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'attachments_editor.dart';
import 'sheets.dart';

enum TransactionTimeFilter {
  all,
  year,
  quarter,
  month,
  week,
  last12Months,
  last30Days,
  last6Weeks;

  String label(AppLocalizations l10n) {
    switch (this) {
      case TransactionTimeFilter.all:
        return l10n.timeAll;
      case TransactionTimeFilter.year:
        return l10n.timeYear;
      case TransactionTimeFilter.quarter:
        return l10n.timeQuarter;
      case TransactionTimeFilter.month:
        return l10n.thisMonth;
      case TransactionTimeFilter.week:
        return l10n.timeWeek;
      case TransactionTimeFilter.last12Months:
        return l10n.timeLast12Months;
      case TransactionTimeFilter.last30Days:
        return l10n.timeLast30Days;
      case TransactionTimeFilter.last6Weeks:
        return l10n.timeLast6Weeks;
    }
  }
}

enum TransactionSortOrder {
  dateDesc,
  dateAsc,
  amountDesc,
  amountAsc;

  String label(AppLocalizations l10n) {
    switch (this) {
      case TransactionSortOrder.dateDesc:
        return l10n.sortDateDesc;
      case TransactionSortOrder.dateAsc:
        return l10n.sortDateAsc;
      case TransactionSortOrder.amountDesc:
        return l10n.sortAmountDesc;
      case TransactionSortOrder.amountAsc:
        return l10n.sortAmountAsc;
    }
  }
}

/// 报销状态筛选：全部 / 待报销（已标记且未完全冲抵）/ 已报销（已有回款冲抵）。
enum ReimbursementFilter {
  all,
  pending,
  reimbursed;

  String label(AppLocalizations l10n) {
    switch (this) {
      case ReimbursementFilter.all:
        return l10n.reimbursementStatusAll;
      case ReimbursementFilter.pending:
        return l10n.badgeReimbursable;
      case ReimbursementFilter.reimbursed:
        return l10n.reimbursementReimbursed;
    }
  }

  bool matches(LedgerEntry entry) {
    switch (this) {
      case ReimbursementFilter.all:
        return true;
      case ReimbursementFilter.pending:
        // 已标记待报销、且尚未完全冲抵的支出（还有钱没报回来）。
        return entry.reimbursable && entry.refundedAmount < entry.amount;
      case ReimbursementFilter.reimbursed:
        // 已有退款/报销回款冲抵（含部分冲抵）。
        return entry.refundedAmount > 0;
    }
  }
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({
    super.key,
    this.initialDate,
    this.accountId,
    this.title,
  });

  final DateTime? initialDate;
  final String? accountId;
  final String? title;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  static const String _allFilterValue = '__all__';

  TransactionTimeFilter _timeFilter = TransactionTimeFilter.all;
  TransactionSortOrder _sortOrder = TransactionSortOrder.dateDesc;
  DateTime _periodAnchor = DateTime.now();
  late DateTime _visibleDate = widget.initialDate ?? DateTime.now();
  late bool _dateMode = widget.initialDate != null;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String? _selectedTagId;
  ReimbursementFilter _reimbursementFilter = ReimbursementFilter.all;
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.accountId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final entries = _sortedEntries(_filteredEntries(controller.entries));
    final expense = sumByType(entries, EntryType.expense);
    final income = sumByType(entries, EntryType.income);
    final groupedEntries = groupEntriesByDate(entries);

    return Theme(
      data: buildVeriFinTheme(Brightness.dark),
      child: Scaffold(
        bottomNavigationBar: _selectionMode
            ? _BatchActionBar(
                count: _selectedIds.length,
                onSelectAll: () => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(entries.map((e) => e.id));
                }),
                onDelete: _selectedIds.isEmpty ? null : _batchDelete,
                onChangeCategory: _selectedIds.isEmpty
                    ? null
                    : () => _batchChangeCategory(controller),
                onChangeAccount: _selectedIds.isEmpty
                    ? null
                    : () => _batchChangeAccount(controller),
              )
            : null,
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: _selectionMode
                      ? AppLocalizations.of(
                          context,
                        ).selectedCount(_selectedIds.length)
                      : (widget.title ??
                            (_dateMode
                                ? AppLocalizations.of(context).dayEntriesTitle
                                : AppLocalizations.of(
                                    context,
                                  ).entriesListTitle)),
                  subtitle: _selectionMode
                      ? null
                      : (_dateMode
                            ? '${_visibleDate.month}.${_visibleDate.day}'
                            : null),
                  showBack: true,
                  actions: <Widget>[
                    if (_selectionMode)
                      HeaderAction(
                        icon: Icons.close,
                        tooltip: AppLocalizations.of(context).exitMultiSelect,
                        onPressed: () => setState(() {
                          _selectionMode = false;
                          _selectedIds.clear();
                        }),
                      )
                    else if (entries.isNotEmpty)
                      HeaderAction(
                        icon: Icons.checklist,
                        tooltip: AppLocalizations.of(context).multiSelect,
                        onPressed: () => setState(() => _selectionMode = true),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_dateMode)
                  Row(
                    children: <Widget>[
                      _DateFilterBar(
                        date: _visibleDate,
                        onPrevious: () => setState(() {
                          _visibleDate = _visibleDate.subtract(
                            const Duration(days: 1),
                          );
                        }),
                        onNext: () => setState(() {
                          _visibleDate = _visibleDate.add(
                            const Duration(days: 1),
                          );
                        }),
                        onTap: _pickTimeFilter,
                      ),
                      const SizedBox(width: 10),
                      FilterPill(
                        label: _sortOrder.label(AppLocalizations.of(context)),
                        onTap: _pickSortOrder,
                      ),
                    ],
                  )
                else
                  Row(
                    children: <Widget>[
                      _TransactionFilterBar(
                        label: _periodLabel(),
                        showNavigation:
                            _timeFilter != TransactionTimeFilter.all,
                        onPrevious: () => _movePeriod(-1),
                        onNext: () => _movePeriod(1),
                        onTap: _pickTimeFilter,
                      ),
                      const SizedBox(width: 10),
                      FilterPill(
                        label: _sortOrder.label(AppLocalizations.of(context)),
                        onTap: _pickSortOrder,
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                _TransactionSearchFilters(
                  controller: _searchController,
                  accountLabel: _accountFilterLabel(controller),
                  categoryLabel: _categoryFilterLabel(controller),
                  accountLocked: widget.accountId != null,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  onPickAccount: widget.accountId == null
                      ? () => _pickAccountFilter(controller)
                      : null,
                  onPickCategory: () => _pickCategoryFilter(controller),
                  tagLabel: _tagFilterLabel(controller),
                  tagSelected: _selectedTagId != null,
                  onPickTag: controller.tags.isEmpty
                      ? null
                      : () => _pickTagFilter(controller),
                  onClear: _hasSecondaryFilters
                      ? () {
                          setState(() {
                            _searchController.clear();
                            _query = '';
                            if (widget.accountId == null) {
                              _selectedAccountId = null;
                            }
                            _selectedCategoryId = null;
                            _selectedTagId = null;
                            _reimbursementFilter = ReimbursementFilter.all;
                          });
                        }
                      : null,
                  reimbursementLabel: _reimbursementFilterLabel(),
                  reimbursementActive:
                      _reimbursementFilter != ReimbursementFilter.all,
                  onPickReimbursement: _pickReimbursementFilter,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).entriesCountFull(entries.length),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.28),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                VeriCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 16,
                  ),
                  child: Row(
                    children: <Widget>[
                      SummaryMetric(
                        label: AppLocalizations.of(context).entryTypeExpense,
                        value: formatExpenseAmount(expense),
                        color: isZeroAmount(expense)
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.48)
                            : veriExpense,
                      ),
                      SummaryMetric(
                        label: AppLocalizations.of(context).entryTypeIncome,
                        value: formatAmount(income),
                        color: isZeroAmount(income)
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.48)
                            : veriIncome,
                      ),
                      SummaryMetric(
                        label: AppLocalizations.of(context).netLabel,
                        value: formatSignedAmount(income - expense),
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (entries.isEmpty)
                  VeriCard(
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: _hasSecondaryFilters
                          ? AppLocalizations.of(context).noMatchTitle
                          : AppLocalizations.of(context).noEntriesTitle,
                      description: _hasSecondaryFilters
                          ? AppLocalizations.of(context).noMatchDesc
                          : AppLocalizations.of(context).emptyEntriesDesc,
                    ),
                  )
                else
                  for (final group in groupedEntries) ...<Widget>[
                    DateGroupHeader(entries: group.entries, date: group.date),
                    const SizedBox(height: 8),
                    TransactionListCard(
                      entries: group.entries,
                      accounts: controller.accounts,
                      categories: controller.categories,
                      selectionMode: _selectionMode,
                      selectedIds: _selectedIds,
                      onEntryTap: (entry) {
                        if (_selectionMode) {
                          _toggleSelected(entry.id);
                        } else {
                          openEntryDetail(context, entry);
                        }
                      },
                      onEntryLongPress: (entry) {
                        setState(() {
                          _selectionMode = true;
                          _selectedIds.add(entry.id);
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<LedgerEntry> _filteredEntries(List<LedgerEntry> entries) {
    final scopedEntries = widget.accountId == null
        ? entries
        : entries
              .where((entry) => entryTouchesAccount(entry, widget.accountId!))
              .toList();

    List<LedgerEntry> filtered;
    if (_dateMode) {
      filtered = scopedEntries
          .where((entry) => DateUtils.isSameDay(entry.occurredAt, _visibleDate))
          .toList();
    } else {
      final period = _activePeriod();
      if (period == null) {
        filtered = scopedEntries;
      } else {
        final endExclusive = period.end.add(const Duration(days: 1));
        filtered = scopedEntries
            .where(
              (entry) =>
                  !entry.occurredAt.isBefore(period.start) &&
                  entry.occurredAt.isBefore(endExclusive),
            )
            .toList();
      }
    }

    final controller = VeriFinScope.of(context);
    final normalizedQuery = _query.toLowerCase();
    return filtered
        .where((entry) => _matchesSecondaryFilters(entry, controller))
        .where(
          (entry) => normalizedQuery.isEmpty
              ? true
              : _matchesQuery(entry, controller, normalizedQuery),
        )
        .toList();
  }

  bool get _hasSecondaryFilters =>
      _query.isNotEmpty ||
      (widget.accountId == null && _selectedAccountId != null) ||
      _selectedCategoryId != null ||
      _selectedTagId != null ||
      _reimbursementFilter != ReimbursementFilter.all;

  bool _matchesSecondaryFilters(
    LedgerEntry entry,
    VeriFinController controller,
  ) {
    if (_selectedAccountId != null &&
        !entryTouchesAccount(entry, _selectedAccountId!)) {
      return false;
    }
    // 选中某分类时，连同它的所有子分类一起筛出（与看板统计「归总到顶级」口径
    // 一致：选大类=大类及其全部子类的交易）。
    if (_selectedCategoryId != null) {
      final ids = <String>{
        _selectedCategoryId!,
        ...descendantIds(controller.categories, _selectedCategoryId!),
      };
      if (!ids.contains(entry.categoryId)) {
        return false;
      }
    }
    if (_selectedTagId != null && !entry.tagIds.contains(_selectedTagId)) {
      return false;
    }
    // 报销状态：全部 / 待报销（未完全冲抵）/ 已报销（已有回款冲抵）。
    if (!_reimbursementFilter.matches(entry)) {
      return false;
    }
    return true;
  }

  bool _matchesQuery(
    LedgerEntry entry,
    VeriFinController controller,
    String query,
  ) {
    final category = controller.categoryById(entry.categoryId);
    final noneLabel = AppLocalizations.of(context).noAccountLabel;
    final searchable = <String>[
      entry.note,
      category.label,
      accountDisplayName(controller.accounts, entry.accountId, noneLabel),
      if (entry.toAccountId != null && entry.toAccountId!.isNotEmpty)
        accountById(controller.accounts, entry.toAccountId!).name,
      entry.type.label(AppLocalizations.of(context)),
      formatAmount(entry.amount),
      formatSignedAmount(signedAmount(entry)),
      for (final id in entry.tagIds)
        if (controller.tagById(id) case final Tag tag) tag.label,
      // 报销状态也纳入搜索：可用「待报销」「已退」「已报销」关键词检索。
      if (entry.refundedAmount > 0) ...<String>[
        AppLocalizations.of(context).badgeRefunded,
        AppLocalizations.of(context).reimbursementReimbursed,
      ] else if (entry.reimbursable)
        AppLocalizations.of(context).badgeReimbursable,
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  List<LedgerEntry> _sortedEntries(List<LedgerEntry> entries) {
    final sorted = List<LedgerEntry>.from(entries);
    switch (_sortOrder) {
      case TransactionSortOrder.dateDesc:
        sorted.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      case TransactionSortOrder.dateAsc:
        sorted.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      case TransactionSortOrder.amountDesc:
        sorted.sort((a, b) => b.amount.compareTo(a.amount));
      case TransactionSortOrder.amountAsc:
        sorted.sort((a, b) => a.amount.compareTo(b.amount));
    }
    return sorted;
  }

  Future<void> _pickTimeFilter() async {
    final selected = await showOptionSheet<TransactionTimeFilter>(
      context: context,
      title: AppLocalizations.of(context).filterTimeTitle,
      values: TransactionTimeFilter.values,
      selected: _timeFilter,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null) {
      setState(() {
        _dateMode = false;
        _timeFilter = selected;
        _periodAnchor = DateTime.now();
      });
    }
  }

  Future<void> _pickSortOrder() async {
    final selected = await showOptionSheet<TransactionSortOrder>(
      context: context,
      title: AppLocalizations.of(context).sortTitle,
      values: TransactionSortOrder.values,
      selected: _sortOrder,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null) {
      setState(() => _sortOrder = selected);
    }
  }

  Future<void> _pickAccountFilter(VeriFinController controller) async {
    final values = <String>[
      _allFilterValue,
      for (final account in controller.accounts) account.id,
    ];
    final selected = await showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).filterAccountTitle,
      values: values,
      selected: _selectedAccountId ?? _allFilterValue,
      labelOf: (value) => value == _allFilterValue
          ? AppLocalizations.of(context).allAccounts
          : accountById(controller.accounts, value).name,
    );
    if (selected != null) {
      setState(() {
        _selectedAccountId = selected == _allFilterValue ? null : selected;
      });
    }
  }

  Future<void> _pickCategoryFilter(VeriFinController controller) async {
    // 按类型 + 层级（前序）平铺分类，子分类缩进展示，用户既能选大类也能选子类。
    final depthOfId = <String, int>{};
    final values = <String>[_allFilterValue];
    for (final type in EntryType.values) {
      for (final node in flattenTree(controller.categories, type)) {
        depthOfId[node.category.id] = node.depth;
        values.add(node.category.id);
      }
    }
    final selected = await showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).filterCategoryTitle,
      values: values,
      selected: _selectedCategoryId ?? _allFilterValue,
      labelOf: (value) => value == _allFilterValue
          ? AppLocalizations.of(context).categoryAll
          : '${'　' * (depthOfId[value] ?? 0)}${controller.categoryById(value).label}',
    );
    if (selected != null) {
      setState(() {
        _selectedCategoryId = selected == _allFilterValue ? null : selected;
      });
    }
  }

  String _accountFilterLabel(VeriFinController controller) {
    final accountId = _selectedAccountId;
    if (accountId == null) {
      return AppLocalizations.of(context).allAccounts;
    }
    return accountById(controller.accounts, accountId).name;
  }

  String _categoryFilterLabel(VeriFinController controller) {
    final categoryId = _selectedCategoryId;
    if (categoryId == null) {
      return AppLocalizations.of(context).categoryAll;
    }
    return controller.categoryById(categoryId).label;
  }

  Future<void> _pickTagFilter(VeriFinController controller) async {
    final values = <String>[
      _allFilterValue,
      for (final tag in controller.tags) tag.id,
    ];
    final selected = await showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).filterTagTitle,
      values: values,
      selected: _selectedTagId ?? _allFilterValue,
      labelOf: (value) => value == _allFilterValue
          ? AppLocalizations.of(context).allTags
          : (controller.tagById(value)?.label ??
                AppLocalizations.of(context).unknownTag),
    );
    if (selected != null) {
      setState(() {
        _selectedTagId = selected == _allFilterValue ? null : selected;
      });
    }
  }

  String _tagFilterLabel(VeriFinController controller) {
    final tagId = _selectedTagId;
    if (tagId == null) {
      return AppLocalizations.of(context).tagLabel;
    }
    return controller.tagById(tagId)?.label ??
        AppLocalizations.of(context).tagLabel;
  }

  /// 报销筛选胶囊的文案：未筛选时显示维度名「报销」，否则显示所选状态。
  String _reimbursementFilterLabel() {
    final l10n = AppLocalizations.of(context);
    return _reimbursementFilter == ReimbursementFilter.all
        ? l10n.reimbursementFilterName
        : _reimbursementFilter.label(l10n);
  }

  Future<void> _pickReimbursementFilter() async {
    final selected = await showOptionSheet<ReimbursementFilter>(
      context: context,
      title: AppLocalizations.of(context).reimbursementFilterTitle,
      values: ReimbursementFilter.values,
      selected: _reimbursementFilter,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null) {
      setState(() => _reimbursementFilter = selected);
    }
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _batchDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteEntriesTitle(count)),
        content: Text(AppLocalizations.of(context).deleteEntriesMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).commonDelete),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    VeriFinScope.of(context).deleteEntries(Set<String>.of(_selectedIds));
    _exitSelection();
  }

  Future<void> _batchChangeCategory(VeriFinController controller) async {
    final selected = await showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).changeCategoryTitle,
      values: controller.categories.map((c) => c.id).toList(),
      selected: controller.categories.first.id,
      labelOf: (id) => controller.categoryById(id).label,
    );
    if (selected == null || !mounted) {
      return;
    }
    final changed = controller.setEntriesCategory(
      Set<String>.of(_selectedIds),
      selected,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).changedCategoryCount(changed),
          ),
        ),
      );
    }
    _exitSelection();
  }

  Future<void> _batchChangeAccount(VeriFinController controller) async {
    if (controller.accounts.isEmpty) {
      return;
    }
    final selected = await showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).changeAccountTitle,
      values: controller.accounts.map((a) => a.id).toList(),
      selected: controller.accounts.first.id,
      labelOf: (id) => accountById(controller.accounts, id).name,
    );
    if (selected == null || !mounted) {
      return;
    }
    final changed = controller.setEntriesAccount(
      Set<String>.of(_selectedIds),
      selected,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).changedAccountCount(changed),
          ),
        ),
      );
    }
    _exitSelection();
  }

  DateWindow? _activePeriod() {
    final anchor = dateOnly(_periodAnchor);
    switch (_timeFilter) {
      case TransactionTimeFilter.all:
        return null;
      case TransactionTimeFilter.year:
        return DateWindow(
          start: DateTime(anchor.year),
          end: DateTime(anchor.year, 12, 31),
        );
      case TransactionTimeFilter.quarter:
        final quarter = ((anchor.month - 1) ~/ 3) + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        return DateWindow(
          start: DateTime(anchor.year, startMonth),
          end: DateTime(anchor.year, startMonth + 3, 0),
        );
      case TransactionTimeFilter.month:
        return DateWindow(
          start: DateTime(anchor.year, anchor.month),
          end: DateTime(anchor.year, anchor.month + 1, 0),
        );
      case TransactionTimeFilter.week:
        final start = anchor.subtract(Duration(days: anchor.weekday - 1));
        return DateWindow(
          start: start,
          end: start.add(const Duration(days: 6)),
        );
      case TransactionTimeFilter.last12Months:
        return DateWindow(
          start: DateTime(anchor.year, anchor.month - 11),
          end: DateTime(anchor.year, anchor.month + 1, 0),
        );
      case TransactionTimeFilter.last30Days:
        return DateWindow(
          start: anchor.subtract(const Duration(days: 29)),
          end: anchor,
        );
      case TransactionTimeFilter.last6Weeks:
        final weekEnd = anchor.add(Duration(days: 7 - anchor.weekday));
        return DateWindow(
          start: weekEnd.subtract(const Duration(days: 41)),
          end: weekEnd,
        );
    }
  }

  String _periodLabel() {
    final now = DateTime.now();
    final period = _activePeriod();
    if (period == null) {
      return _timeFilter.label(AppLocalizations.of(context));
    }
    final anchor = _periodAnchor;
    switch (_timeFilter) {
      case TransactionTimeFilter.all:
        return _timeFilter.label(AppLocalizations.of(context));
      case TransactionTimeFilter.year:
        return anchor.year == now.year
            ? AppLocalizations.of(context).timeYear
            : AppLocalizations.of(context).yearLabel(anchor.year);
      case TransactionTimeFilter.quarter:
        final quarter = ((anchor.month - 1) ~/ 3) + 1;
        return anchor.year == now.year
            ? AppLocalizations.of(context).quarterLabel(quarter)
            : '${twoDigitYear(anchor.year)}.Q$quarter';
      case TransactionTimeFilter.month:
        return anchor.year == now.year
            ? AppLocalizations.of(context).monthNumber(anchor.month)
            : '${twoDigitYear(anchor.year)}.${anchor.month.toString().padLeft(2, '0')}';
      case TransactionTimeFilter.week:
        final week = isoWeekNumber(anchor);
        final year = isoWeekYear(anchor);
        return year == now.year
            ? AppLocalizations.of(context).weekNumber(week)
            : AppLocalizations.of(context).yearWeek(year, week);
      case TransactionTimeFilter.last12Months:
      case TransactionTimeFilter.last30Days:
        return '${period.start.month}.${period.start.day}-${period.end.month}.${period.end.day}';
      case TransactionTimeFilter.last6Weeks:
        return '${twoDigitYear(isoWeekYear(period.start))}.${isoWeekNumber(period.start).toString().padLeft(2, '0')}-${twoDigitYear(isoWeekYear(period.end))}.${isoWeekNumber(period.end).toString().padLeft(2, '0')}';
    }
  }

  void _movePeriod(int direction) {
    setState(() {
      switch (_timeFilter) {
        case TransactionTimeFilter.all:
          break;
        case TransactionTimeFilter.year:
          _periodAnchor = DateTime(
            _periodAnchor.year + direction,
            _periodAnchor.month,
          );
        case TransactionTimeFilter.quarter:
          _periodAnchor = DateTime(
            _periodAnchor.year,
            _periodAnchor.month + direction * 3,
          );
        case TransactionTimeFilter.month:
          _periodAnchor = DateTime(
            _periodAnchor.year,
            _periodAnchor.month + direction,
          );
        case TransactionTimeFilter.week:
          _periodAnchor = _periodAnchor.add(Duration(days: direction * 7));
        case TransactionTimeFilter.last12Months:
          _periodAnchor = DateTime(
            _periodAnchor.year,
            _periodAnchor.month + direction * 12,
          );
        case TransactionTimeFilter.last30Days:
          _periodAnchor = _periodAnchor.add(Duration(days: direction * 30));
        case TransactionTimeFilter.last6Weeks:
          _periodAnchor = _periodAnchor.add(Duration(days: direction * 42));
      }
    });
  }
}

class _TransactionFilterBar extends StatelessWidget {
  const _TransactionFilterBar({
    required this.label,
    required this.showNavigation,
    required this.onPrevious,
    required this.onNext,
    required this.onTap,
  });

  final String label;
  final bool showNavigation;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!showNavigation) {
      return FilterPill(label: label, onTap: onTap);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: AppLocalizations.of(context).prevRange,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left, size: 18),
        ),
        FilterPill(label: label, onTap: onTap),
        IconButton(
          tooltip: AppLocalizations.of(context).nextRange,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, size: 18),
        ),
      ],
    );
  }
}

class _TransactionSearchFilters extends StatelessWidget {
  const _TransactionSearchFilters({
    required this.controller,
    required this.accountLabel,
    required this.categoryLabel,
    required this.accountLocked,
    required this.onChanged,
    required this.onPickCategory,
    this.onPickAccount,
    this.tagLabel,
    this.tagSelected = false,
    this.onPickTag,
    required this.reimbursementLabel,
    this.reimbursementActive = false,
    this.onPickReimbursement,
    this.onClear,
  });

  final TextEditingController controller;
  final String accountLabel;
  final String categoryLabel;
  final bool accountLocked;
  final ValueChanged<String> onChanged;
  final VoidCallback? onPickAccount;
  final VoidCallback onPickCategory;

  /// 标签筛选：仅当存在标签时由上层传入 [onPickTag]，否则不展示该胶囊。
  final String? tagLabel;
  final bool tagSelected;
  final VoidCallback? onPickTag;
  final String reimbursementLabel;
  final bool reimbursementActive;
  final VoidCallback? onPickReimbursement;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return VeriCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        children: <Widget>[
          TextField(
            key: const Key('transaction_search_field'),
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              hintText: AppLocalizations.of(context).searchHint,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: onClear == null
                  ? null
                  : IconButton(
                      tooltip: AppLocalizations.of(context).clearFilters,
                      onPressed: onClear,
                      icon: const Icon(Icons.close, size: 18),
                    ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : veriSurfaceLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(veriRadiusSm),
                borderSide: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(veriRadiusSm),
                borderSide: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(veriRadiusSm),
                borderSide: const BorderSide(color: veriRoyal, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilterPill(
                  label: accountLabel,
                  icon: accountLocked
                      ? Icons.lock_outline
                      : Icons.account_balance_wallet_outlined,
                  onTap: onPickAccount,
                  showChevron: !accountLocked,
                ),
                FilterPill(
                  label: categoryLabel,
                  icon: Icons.category_outlined,
                  onTap: onPickCategory,
                ),
                if (onPickTag != null)
                  FilterPill(
                    label: tagLabel ?? AppLocalizations.of(context).tagLabel,
                    icon: tagSelected ? Icons.label : Icons.label_outline,
                    onTap: onPickTag,
                  ),
                FilterPill(
                  label: reimbursementLabel,
                  icon: reimbursementActive
                      ? Icons.check_circle
                      : Icons.receipt_long_outlined,
                  onTap: onPickReimbursement,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateFilterBar extends StatelessWidget {
  const _DateFilterBar({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onTap,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: AppLocalizations.of(context).prevDay,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        FilterPill(label: '${date.month}.${date.day}', onTap: onTap),
        IconButton(
          tooltip: AppLocalizations.of(context).nextDay,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
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
  late double _refundedAmount;
  late final TextEditingController _noteController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialEntry != null) {
      return;
    }
    final entry = VeriFinScope.of(
      context,
    ).entries.where((item) => item.id == widget.entryId).firstOrNull;
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
    _refundedAmount = entry.refundedAmount;
    _noteController = TextEditingController(text: entry.note);
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
            (_toAccountId != null && _toAccountId != _accountId));
    final amountColor = colorForType(_type);
    final amountText = switch (_type) {
      EntryType.expense => formatExpenseAmount(_amount),
      EntryType.income => '+${formatIncomeAmount(_amount)}',
      EntryType.transfer => formatAmount(_amount),
    };

    return Theme(
      data: buildVeriFinTheme(Brightness.dark),
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
                      onPressed: () => _confirmDeleteEntry(context, entry),
                    ),
                    HeaderAction(
                      icon: Icons.check,
                      tooltip: AppLocalizations.of(context).saveEntryTooltip,
                      onPressed: canSave ? _save : null,
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
                      VeriIconBox(
                        icon: iconForCode(category.iconCode),
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
                      if (_type == EntryType.expense) ...<Widget>[
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
                        DetailInfoRow(
                          label: AppLocalizations.of(context).refundLabel,
                          value: _refundedAmount > 0
                              ? AppLocalizations.of(
                                  context,
                                ).refundedAmountLabel(
                                  formatAmount(_refundedAmount),
                                )
                              : AppLocalizations.of(context).commonNoneShort,
                          placeholder: _refundedAmount <= 0,
                          onTap: _editRefund,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                VeriCard(
                  child: Builder(
                    builder: (context) {
                      final attachments = controller.attachmentsForEntry(
                        widget.entryId,
                      );
                      return AttachmentsEditor(
                        dataUrls: attachments
                            .map((a) => a.dataUrl)
                            .toList(growable: false),
                        onAddDataUrl: (dataUrl) =>
                            controller.addAttachment(widget.entryId, dataUrl),
                        onRemoveIndex: (index) =>
                            controller.removeAttachment(attachments[index].id),
                      );
                    },
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
    if (amount == null || amount <= 0 || !mounted) {
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
    if (fee == null || fee < 0 || !mounted) {
      return;
    }
    setState(() => _fee = fee);
  }

  Future<void> _editRefund() async {
    final refunded = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => NumberPadSheet(
        title: AppLocalizations.of(context).refundAmountTitle,
        initialAmount: _refundedAmount > 0 ? _refundedAmount : null,
        allowZero: true,
        hapticsEnabled: VeriFinScope.of(context).hapticsEnabled,
      ),
    );
    if (refunded == null || refunded < 0 || !mounted) {
      return;
    }
    // 冲抵金额不超过原支出金额。
    setState(() => _refundedAmount = refunded.clamp(0, _amount).toDouble());
  }

  Future<void> _pickType() async {
    final selected = await showOptionSheet<EntryType>(
      context: context,
      title: AppLocalizations.of(context).pickTypeTitle,
      values: EntryType.values,
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
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => CategoryPickerSheet(
        categories: VeriFinScope.of(context).categoriesForType(_type),
        selectedId: _categoryId,
      ),
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

  void _save() {
    final entry = _initialEntry;
    if (entry == null) {
      return;
    }
    if (_type == EntryType.transfer &&
        (_toAccountId == null || _toAccountId == _accountId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).transferNeedsTwoAccounts),
        ),
      );
      return;
    }
    final noAccount = _type != EntryType.transfer && _noAccount;
    VeriFinScope.of(context).updateEntry(
      entry.copyWith(
        type: _type,
        amount: _amount,
        categoryId: _categoryId,
        accountId: noAccount ? '' : _accountId,
        toAccountId: _type == EntryType.transfer ? _toAccountId : null,
        clearToAccountId: _type != EntryType.transfer,
        note: _noteController.text.trim(),
        occurredAt: _occurredAt,
        tagIds: _tagIds,
        fee: _type == EntryType.transfer ? _fee : 0,
        reimbursable: _type == EntryType.expense && _reimbursable,
        refundedAmount: _type == EntryType.expense ? _refundedAmount : 0,
      ),
    );
    Navigator.of(context).pop();
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

Future<void> _confirmDeleteEntry(
  BuildContext context,
  LedgerEntry entry,
) async {
  final controller = VeriFinScope.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(AppLocalizations.of(context).deleteEntryTitle),
      content: Text(AppLocalizations.of(context).deleteEntryMessage),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(AppLocalizations.of(context).commonDelete),
        ),
      ],
    ),
  );
  if (!context.mounted || confirmed != true) {
    return;
  }
  controller.deleteEntry(entry.id);
  Navigator.of(context).pop();
}

void openEntryDetail(BuildContext context, LedgerEntry entry) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => TransactionDetailPage(entryId: entry.id),
    ),
  );
}

/// 多选模式底部操作栏：全选 / 删除 / 改分类 / 改账户。
class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({
    required this.count,
    required this.onSelectAll,
    required this.onDelete,
    required this.onChangeCategory,
    required this.onChangeAccount,
  });

  final int count;
  final VoidCallback onSelectAll;
  final VoidCallback? onDelete;
  final VoidCallback? onChangeCategory;
  final VoidCallback? onChangeAccount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _BatchAction(
              icon: Icons.select_all,
              label: AppLocalizations.of(context).selectAll,
              onTap: onSelectAll,
            ),
            _BatchAction(
              icon: Icons.category_outlined,
              label: AppLocalizations.of(context).changeCategoryShort,
              onTap: onChangeCategory,
            ),
            _BatchAction(
              icon: Icons.account_balance_wallet_outlined,
              label: AppLocalizations.of(context).changeAccountShort,
              onTap: onChangeAccount,
            ),
            _BatchAction(
              icon: Icons.delete_outline,
              label: AppLocalizations.of(context).commonDelete,
              destructive: true,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchAction extends StatelessWidget {
  const _BatchAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final base = destructive
        ? veriExpense
        : Theme.of(context).colorScheme.onSurface;
    final color = enabled ? base : base.withValues(alpha: 0.3);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
