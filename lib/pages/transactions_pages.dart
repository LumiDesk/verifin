import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
import '../app/entry_sheets.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/series_math.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import 'attachments_editor.dart';
import 'sheets.dart';

enum TransactionTimeFilter {
  all('全部时间'),
  year('本年'),
  quarter('本季'),
  month('本月'),
  week('本周'),
  last12Months('近12个月'),
  last30Days('近30天'),
  last6Weeks('近6周');

  const TransactionTimeFilter(this.label);

  final String label;
}

enum TransactionSortOrder {
  dateDesc('日期降序'),
  dateAsc('日期升序'),
  amountDesc('金额降序'),
  amountAsc('金额升序');

  const TransactionSortOrder(this.label);

  final String label;
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
  bool _onlyReimbursable = false;

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
    final groupedEntries = _groupEntriesByDate(entries);

    return Theme(
      data: buildVeriFinTheme(Brightness.dark),
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: widget.title ?? (_dateMode ? '当日交易' : '交易明细'),
                  subtitle: _dateMode
                      ? '${_visibleDate.month}.${_visibleDate.day}'
                      : null,
                  showBack: true,
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
                        label: _sortOrder.label,
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
                        label: _sortOrder.label,
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
                            _onlyReimbursable = false;
                          });
                        }
                      : null,
                  reimbursableOnly: _onlyReimbursable,
                  onToggleReimbursable: () =>
                      setState(() => _onlyReimbursable = !_onlyReimbursable),
                ),
                const SizedBox(height: 16),
                Text(
                  '${entries.length}笔交易',
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
                        label: '支出',
                        value: formatExpenseAmount(expense),
                        color: isZeroAmount(expense)
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.48)
                            : veriExpense,
                      ),
                      SummaryMetric(
                        label: '收入',
                        value: formatAmount(income),
                        color: isZeroAmount(income)
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.48)
                            : veriIncome,
                      ),
                      SummaryMetric(
                        label: '结余',
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
                      title: _hasSecondaryFilters ? '没有匹配交易' : '暂无交易',
                      description: _hasSecondaryFilters
                          ? '换一个关键词、账户或分类再试。'
                          : '保存交易后会在这里按日期展示。',
                    ),
                  )
                else
                  for (final group in groupedEntries) ...<Widget>[
                    _DateGroupHeader(entries: group.entries, date: group.date),
                    const SizedBox(height: 8),
                    TransactionListCard(
                      entries: group.entries,
                      accounts: controller.accounts,
                      categories: controller.categories,
                      onEntryTap: (entry) => openEntryDetail(context, entry),
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
      _onlyReimbursable;

  bool _matchesSecondaryFilters(
    LedgerEntry entry,
    VeriFinController controller,
  ) {
    if (_selectedAccountId != null &&
        !entryTouchesAccount(entry, _selectedAccountId!)) {
      return false;
    }
    if (_selectedCategoryId != null &&
        entry.categoryId != _selectedCategoryId) {
      return false;
    }
    if (_selectedTagId != null && !entry.tagIds.contains(_selectedTagId)) {
      return false;
    }
    // 待报销：仅显示标记待报销、且尚未完全冲抵的支出。
    if (_onlyReimbursable &&
        !(entry.reimbursable && entry.refundedAmount < entry.amount)) {
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
    final account = accountById(controller.accounts, entry.accountId);
    final searchable = <String>[
      entry.note,
      category.label,
      account.name,
      if (entry.toAccountId != null)
        accountById(controller.accounts, entry.toAccountId!).name,
      entry.type.label,
      formatAmount(entry.amount),
      formatSignedAmount(signedAmount(entry)),
      for (final id in entry.tagIds)
        if (controller.tagById(id) case final Tag tag) tag.label,
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
      title: '筛选时间',
      values: TransactionTimeFilter.values,
      selected: _timeFilter,
      labelOf: (value) => value.label,
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
      title: '排序方式',
      values: TransactionSortOrder.values,
      selected: _sortOrder,
      labelOf: (value) => value.label,
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
      title: '筛选账户',
      values: values,
      selected: _selectedAccountId ?? _allFilterValue,
      labelOf: (value) => value == _allFilterValue
          ? '全部账户'
          : accountById(controller.accounts, value).name,
    );
    if (selected != null) {
      setState(() {
        _selectedAccountId = selected == _allFilterValue ? null : selected;
      });
    }
  }

  Future<void> _pickCategoryFilter(VeriFinController controller) async {
    final values = <String>[
      _allFilterValue,
      for (final category in controller.categories) category.id,
    ];
    final selected = await showOptionSheet<String>(
      context: context,
      title: '筛选分类',
      values: values,
      selected: _selectedCategoryId ?? _allFilterValue,
      labelOf: (value) => value == _allFilterValue
          ? '全部分类'
          : controller.categoryById(value).label,
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
      return '全部账户';
    }
    return accountById(controller.accounts, accountId).name;
  }

  String _categoryFilterLabel(VeriFinController controller) {
    final categoryId = _selectedCategoryId;
    if (categoryId == null) {
      return '全部分类';
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
      title: '筛选标签',
      values: values,
      selected: _selectedTagId ?? _allFilterValue,
      labelOf: (value) => value == _allFilterValue
          ? '全部标签'
          : (controller.tagById(value)?.label ?? '未知标签'),
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
      return '标签';
    }
    return controller.tagById(tagId)?.label ?? '标签';
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
      return _timeFilter.label;
    }
    final anchor = _periodAnchor;
    switch (_timeFilter) {
      case TransactionTimeFilter.all:
        return _timeFilter.label;
      case TransactionTimeFilter.year:
        return anchor.year == now.year ? '本年' : '${anchor.year}年';
      case TransactionTimeFilter.quarter:
        final quarter = ((anchor.month - 1) ~/ 3) + 1;
        return anchor.year == now.year
            ? '季度$quarter'
            : '${twoDigitYear(anchor.year)}.Q$quarter';
      case TransactionTimeFilter.month:
        return anchor.year == now.year
            ? '${anchor.month}月'
            : '${twoDigitYear(anchor.year)}.${anchor.month.toString().padLeft(2, '0')}';
      case TransactionTimeFilter.week:
        final week = isoWeekNumber(anchor);
        final year = isoWeekYear(anchor);
        return year == now.year ? '$week周' : '$year年$week周';
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
          tooltip: '上一段',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left, size: 18),
        ),
        FilterPill(label: label, onTap: onTap),
        IconButton(
          tooltip: '下一段',
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
    this.reimbursableOnly = false,
    this.onToggleReimbursable,
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
  final bool reimbursableOnly;
  final VoidCallback? onToggleReimbursable;
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
              hintText: '搜索备注、分类、账户或金额',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: onClear == null
                  ? null
                  : IconButton(
                      tooltip: '清空筛选',
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
                    label: tagLabel ?? '标签',
                    icon: tagSelected ? Icons.label : Icons.label_outline,
                    onTap: onPickTag,
                  ),
                if (onToggleReimbursable != null)
                  FilterPill(
                    label: '待报销',
                    icon: reimbursableOnly
                        ? Icons.check_circle
                        : Icons.receipt_long_outlined,
                    onTap: onToggleReimbursable,
                    showChevron: false,
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
          tooltip: '前一天',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        FilterPill(label: '${date.month}.${date.day}', onTap: onTap),
        IconButton(
          tooltip: '后一天',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _DateEntryGroup {
  const _DateEntryGroup({required this.date, required this.entries});

  final DateTime date;
  final List<LedgerEntry> entries;
}

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.date, required this.entries});

  final DateTime date;
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final dayTotal = entries.fold<double>(
      0,
      (sum, entry) => sum + signedAmount(entry),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${formatDate(date)}  ${_relativeDay(date)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.42),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            formatSignedAmount(dayTotal),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.35),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('交易不存在'))),
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
    _normalizeTransferAccounts(accounts);
    final account = accountById(accounts, _accountId);
    final toAccount = _toAccountId == null
        ? null
        : accountById(accounts, _toAccountId!);
    final canSave =
        accounts.isNotEmpty &&
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
                  title: _type.label,
                  showBack: true,
                  actions: <Widget>[
                    HeaderAction(
                      icon: Icons.delete_outline,
                      tooltip: '删除交易',
                      destructive: true,
                      onPressed: () => _confirmDeleteEntry(context, entry),
                    ),
                    HeaderAction(
                      icon: Icons.check,
                      tooltip: '保存交易',
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
                              '金额',
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
                        label: '类型',
                        value: _type.label,
                        onTap: _pickType,
                      ),
                      DetailInfoRow(
                        label: '分类',
                        value: category.label,
                        onTap: _pickCategory,
                      ),
                      if (_type == EntryType.transfer) ...<Widget>[
                        DetailInfoRow(
                          label: '转出账户',
                          value:
                              '${account.name} (${formatAmount(controller.accountBalance(account))})',
                          onTap: accounts.isEmpty
                              ? null
                              : () => _pickAccount(accounts),
                        ),
                        DetailInfoRow(
                          label: '转入账户',
                          value: toAccount == null
                              ? '请选择'
                              : '${toAccount.name} (${formatAmount(controller.accountBalance(toAccount))})',
                          placeholder: toAccount == null,
                          onTap: accounts.length < 2
                              ? null
                              : () => _pickToAccount(accounts),
                        ),
                        DetailInfoRow(
                          label: '手续费',
                          value: _fee > 0 ? formatAmount(_fee) : '无',
                          placeholder: _fee <= 0,
                          onTap: _editFee,
                        ),
                      ] else
                        DetailInfoRow(
                          label: '账户',
                          value:
                              '${account.name} (${formatAmount(controller.accountBalance(account))})',
                          onTap: accounts.isEmpty
                              ? null
                              : () => _pickAccount(accounts),
                        ),
                      DetailInfoRow(
                        label: '日期',
                        value:
                            '${formatDate(_occurredAt)}  ${_relativeDay(_occurredAt)}',
                        onTap: _pickDate,
                      ),
                      DetailInfoRow(
                        label: '时间',
                        value: formatTime(_occurredAt),
                        onTap: _pickTime,
                      ),
                      DetailInfoRow(
                        label: '备注',
                        value: _noteController.text.trim().isEmpty
                            ? '点击添加备注'
                            : _noteController.text.trim(),
                        placeholder: _noteController.text.trim().isEmpty,
                        onTap: _editNote,
                      ),
                      DetailInfoRow(
                        label: '标签',
                        value: _tagLabels(controller).isEmpty
                            ? '点击添加标签'
                            : _tagLabels(controller).join('、'),
                        placeholder: _tagLabels(controller).isEmpty,
                        onTap: _pickTags,
                      ),
                      if (_type == EntryType.expense) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: <Widget>[
                              const Expanded(child: Text('标记待报销')),
                              Switch(
                                value: _reimbursable,
                                onChanged: (value) =>
                                    setState(() => _reimbursable = value),
                              ),
                            ],
                          ),
                        ),
                        DetailInfoRow(
                          label: '退款 / 报销回款',
                          value: _refundedAmount > 0
                              ? '已冲抵 ${formatAmount(_refundedAmount)}'
                              : '无',
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
        title: '修改金额',
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
        title: '转账手续费',
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
        title: '退款 / 报销回款金额',
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
      title: '选择类型',
      values: EntryType.values,
      selected: _type,
      labelOf: (value) => value.label,
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
    final selected = await showAccountPickerSheet(
      context: context,
      title: _type == EntryType.transfer ? '选择转出账户' : '选择账户',
      accounts: accounts,
      selectedId: _accountId,
      balanceOf: VeriFinScope.of(context).accountBalance,
    );
    if (selected != null && mounted) {
      setState(() {
        _accountId = selected.id;
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
      title: '选择转入账户',
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
      title: '编辑备注',
      label: '备注',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('转账需要两个不同的账户,请先添加转入账户。')));
      return;
    }
    VeriFinScope.of(context).updateEntry(
      entry.copyWith(
        type: _type,
        amount: _amount,
        categoryId: _categoryId,
        accountId: _accountId,
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
      title: const Text('删除此交易？'),
      content: const Text('删除后无法恢复，本地保存的这笔记录会被移除。'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
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

List<_DateEntryGroup> _groupEntriesByDate(List<LedgerEntry> entries) {
  final groups = <DateTime, List<LedgerEntry>>{};
  for (final entry in entries) {
    final date = DateTime(
      entry.occurredAt.year,
      entry.occurredAt.month,
      entry.occurredAt.day,
    );
    groups.putIfAbsent(date, () => <LedgerEntry>[]).add(entry);
  }
  return groups.entries
      .map((entry) => _DateEntryGroup(date: entry.key, entries: entry.value))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

String _relativeDay(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) {
    return '今天';
  }
  if (diff == 1) {
    return '昨天';
  }
  return '';
}
