import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'app/avatar_picker.dart';
import 'app/chart_painters.dart';
import 'app/common_widgets.dart';
import 'app/demo_data.dart';
import 'app/entry_sheets.dart';
import 'app/ledger_math.dart';
import 'app/models.dart';
import 'app/veri_fin_controller.dart';
import 'local_storage/local_storage.dart';

void main() {
  runApp(const VeriFinApp());
}

class VeriFinApp extends StatefulWidget {
  const VeriFinApp({super.key, this.store});

  final LocalKeyValueStore? store;

  @override
  State<VeriFinApp> createState() => _VeriFinAppState();
}

class _VeriFinAppState extends State<VeriFinApp> {
  late final VeriFinController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VeriFinController(widget.store ?? LocalKeyValueStore());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VeriFinScope(
      controller: _controller,
      child: ValueListenableBuilder<ThemePreference>(
        valueListenable: _controller.themePreferenceListenable,
        builder: (context, themePreference, _) {
          return MaterialApp(
            title: 'Veri Fin',
            debugShowCheckedModeBanner: false,
            themeMode: themePreference.themeMode,
            theme: buildVeriFinTheme(Brightness.light),
            darkTheme: buildVeriFinTheme(Brightness.dark),
            home: const VeriFinShell(),
          );
        },
      ),
    );
  }
}

class VeriFinScope extends InheritedNotifier<VeriFinController> {
  const VeriFinScope({
    super.key,
    required VeriFinController controller,
    required super.child,
  }) : super(notifier: controller);

  static VeriFinController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<VeriFinScope>();
    assert(scope != null, 'VeriFinScope not found');
    return scope!.notifier!;
  }
}

class VeriFinShell extends StatefulWidget {
  const VeriFinShell({super.key});

  @override
  State<VeriFinShell> createState() => _VeriFinShellState();
}

class _VeriFinShellState extends State<VeriFinShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const AssetsPage(),
      const ReportsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              key: const Key('quick_entry_fab'),
              onPressed: () => _startQuickEntry(context),
              tooltip: '快速记账',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: VeriBottomNav(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
      ),
    );
  }

  Future<void> _startQuickEntry(BuildContext context) async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const NumberPadSheet(title: '快速记账'),
    );

    if (!context.mounted || amount == null || amount <= 0) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => EntryDetailPage(initialAmount: amount),
      ),
    );
  }
}

class VeriBottomNav extends StatelessWidget {
  const VeriBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <_NavItem>[
    _NavItem(Icons.home_outlined, Icons.home, '首页'),
    _NavItem(
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      '资产',
    ),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, '看板'),
    _NavItem(Icons.person_outline, Icons.person, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      key: const Key('main_bottom_nav'),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0F12) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : veriLine),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: <Widget>[
              for (var index = 0; index < _items.length; index += 1)
                Expanded(
                  child: _BottomNavButton(
                    key: Key('main_tab_$index'),
                    item: _items[index],
                    selected: currentIndex == index,
                    onTap: () => onTap(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? veriBlue
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Tooltip(
      message: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Semantics(
          label: item.label,
          selected: selected,
          button: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(selected ? item.activeIcon : item.icon, color: color),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 16 : 4,
                height: 3,
                decoration: BoxDecoration(
                  color: selected ? veriBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final entries = controller.entries;
    final now = DateTime.now();
    final monthEntries = entries
        .where(
          (entry) =>
              entry.occurredAt.year == now.year &&
              entry.occurredAt.month == now.month,
        )
        .toList();
    final monthExpense = sumByType(monthEntries, EntryType.expense);
    final monthIncome = sumByType(monthEntries, EntryType.income);
    final recentEntries = entries.take(5).toList();

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 82),
        children: <Widget>[
          PageHeader(
            title: '日常账本',
            trailing: VeriSectionAction(
              tooltip: '搜索',
              onPressed: () {},
              icon: Icons.search,
            ),
          ),
          const SizedBox(height: 10),
          HomeTrendPanel(
            month: now,
            expense: monthExpense,
            income: monthIncome,
            values: dailyExpenseValues(monthEntries, now),
          ),
          const SizedBox(height: 10),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeaderAction(
                  title: '今日交易',
                  trailing: recentEntries.isEmpty
                      ? '暂无'
                      : formatSignedAmount(
                          recentEntries.fold<double>(
                            0,
                            (sum, entry) => sum + signedAmount(entry),
                          ),
                        ),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const TransactionsPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (recentEntries.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: '还没有交易',
                    description: '点击右下角加号开始第一笔记账。',
                  )
                else
                  for (final item in recentEntries.indexed) ...<Widget>[
                    TransactionTile(
                      item.$2,
                      accounts: controller.accounts,
                      onTap: () => _openEntryDetail(context, item.$2),
                    ),
                    if (item.$1 != recentEntries.length - 1)
                      Divider(
                        indent: 19,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.06),
                      ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          BudgetPanel(month: now.month, expense: monthExpense, budget: 800),
          const SizedBox(height: 10),
          CalendarPreview(entries: monthEntries),
        ],
      ),
    );
  }
}

class SectionHeaderAction extends StatelessWidget {
  const SectionHeaderAction({
    super.key,
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  final String title;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(veriRadiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              trailing,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.52),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: veriBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.chevron_right, size: 17, color: veriBlue),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTrendPanel extends StatelessWidget {
  const HomeTrendPanel({
    super.key,
    required this.month,
    required this.expense,
    required this.income,
    required this.values,
  });

  final DateTime month;
  final double expense;
  final double income;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0B0D11)
            : const Color(0xFF101827),
        borderRadius: BorderRadius.circular(veriRadiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: veriBlue.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${month.month}月支出',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: Colors.white54),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: veriBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.chevron_right,
                  color: veriBlue,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '-${formatAmount(expense)}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: const Color(0xFFFF5573),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '结余 ${formatSignedAmount(income - expense)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white38),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '收入 ${formatAmount(income)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 118,
            child: CustomPaint(
              painter: TrendLinePainter(
                color: const Color(0xFFFF5573),
                values: values,
                xLabels: monthAxisLabels(month),
                labelColor: Colors.white54,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetPanel extends StatelessWidget {
  const BudgetPanel({
    super.key,
    required this.month,
    required this.expense,
    required this.budget,
  });

  final int month;
  final double expense;
  final double budget;

  @override
  Widget build(BuildContext context) {
    final remaining = (budget - expense).clamp(0, budget).toDouble();
    final daysInMonth = DateUtils.getDaysInMonth(
      DateTime.now().year,
      DateTime.now().month,
    );
    final remainingDays = (daysInMonth - DateTime.now().day + 1).clamp(
      1,
      daysInMonth,
    );

    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeaderAction(title: '$month月预算', trailing: '', onTap: () {}),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _BudgetSideStat(
                  label: '支出',
                  value: '-${formatAmount(expense)}',
                  color: const Color(0xFFFF5573),
                ),
              ),
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: CircularProgressIndicator(
                        value: (expense / budget).clamp(0, 1),
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        color: const Color(0xFFFFB33E),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '剩余',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                        ),
                        Text(
                          formatAmount(remaining),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '预算${formatAmount(budget)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _BudgetSideStat(
                  label: '剩余日均',
                  value: formatAmount(remaining / remainingDays),
                  color: veriBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetSideStat extends StatelessWidget {
  const _BudgetSideStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.42),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final entries = controller.entries;
    final expense = sumByType(entries, EntryType.expense);
    final income = sumByType(entries, EntryType.income);
    final groupedEntries = _groupEntriesByDate(entries);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '搜索',
                    onPressed: () {},
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  FilterPill(label: '全部时间', icon: Icons.chevron_left),
                  FilterPill(label: '日期降序'),
                ],
              ),
              const SizedBox(height: 18),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF455064), Color(0xFF132B3A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(veriRadiusLg),
                ),
                child: Row(
                  children: <Widget>[
                    SummaryMetric(
                      label: '支出',
                      value: '-${formatAmount(expense)}',
                      color: Colors.white,
                    ),
                    SummaryMetric(
                      label: '收入',
                      value: formatAmount(income),
                      color: Colors.white,
                    ),
                    SummaryMetric(
                      label: '结余',
                      value: formatSignedAmount(income - expense),
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (entries.isEmpty)
                const VeriCard(
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: '暂无交易',
                    description: '保存交易后会在这里按日期展示。',
                  ),
                )
              else
                for (final group in groupedEntries) ...<Widget>[
                  _DateGroupHeader(entries: group.entries, date: group.date),
                  const SizedBox(height: 8),
                  TransactionListCard(
                    entries: group.entries,
                    accounts: controller.accounts,
                    onEntryTap: (entry) => _openEntryDetail(context, entry),
                  ),
                  const SizedBox(height: 18),
                ],
            ],
          ),
        ),
      ),
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

class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final entry = controller.entries
        .where((item) => item.id == entryId)
        .firstOrNull;
    if (entry == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('交易不存在'))),
      );
    }

    final category = categoryById(entry.categoryId);
    final account = accountById(controller.accounts, entry.accountId);
    final amount = signedAmount(entry);
    final amountColor = colorForType(entry.type);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 26),
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text(
                    entry.type.label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '删除交易',
                    onPressed: () => _confirmDeleteEntry(context, entry),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      formatSignedAmount(amount),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    category.icon,
                    size: 34,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.28),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              DetailInfoRow(label: '分类', value: category.label),
              DetailInfoRow(
                label: '账户',
                value:
                    '${account.name} (${formatAmount(controller.accountBalance(account))})',
              ),
              DetailInfoRow(
                label: '日期',
                value:
                    '${formatDate(entry.occurredAt)}  ${_relativeDay(entry.occurredAt)}',
              ),
              DetailInfoRow(label: '时间', value: formatTime(entry.occurredAt)),
              DetailInfoRow(
                label: '备注',
                value: entry.note.isEmpty ? '点击添加备注' : entry.note,
                placeholder: entry.note.isEmpty,
              ),
              const DetailInfoRow(
                label: '项目',
                value: '点击添加项目',
                placeholder: true,
              ),
              const DetailInfoRow(
                label: '商家',
                value: '点击添加商家',
                placeholder: true,
              ),
              const DetailInfoRow(
                label: '标签',
                value: '点击添加标签',
                placeholder: true,
              ),
            ],
          ),
        ),
      ),
    );
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

void _openEntryDetail(BuildContext context, LedgerEntry entry) {
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

class AssetsPage extends StatelessWidget {
  const AssetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final accounts = controller.accounts;
    final groups = controller.accountGroups;
    final balances = <Account, double>{
      for (final account in accounts)
        account: controller.accountBalance(account),
    };
    final assetBalances = balances.entries
        .where((entry) => entry.key.includeInAssets && !entry.key.hidden)
        .map((entry) => entry.value);
    final assets = assetBalances
        .where((value) => value > 0)
        .fold<double>(0, (sum, value) => sum + value);
    final liabilities = assetBalances
        .where((value) => value < 0)
        .fold<double>(0, (sum, value) => sum + value);
    final visibleGroups = <AccountGroup>[
      ...groups,
      const AccountGroup(
        id: 'ungrouped',
        name: '未分组',
        iconCode: 'folder',
        sortOrder: 999,
      ),
    ];

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 82),
        children: <Widget>[
          PageHeader(
            title: '净资产',
            trailing: PopupMenuButton<String>(
              tooltip: '资产操作',
              icon: const Icon(Icons.add, size: 22),
              onSelected: (value) {
                if (value == 'add_account') {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const AddAccountPage(),
                    ),
                  );
                }
                if (value == 'manage_groups') {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const AccountGroupsPage(),
                    ),
                  );
                }
              },
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'add_account',
                  child: Text('添加账户'),
                ),
                PopupMenuItem<String>(
                  value: 'manage_groups',
                  child: Text('管理分组'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF176CBA), veriRoyal, veriIndigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(veriRadiusMd),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: veriRoyal.withValues(alpha: 0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('净资产', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(
                  formatAmount(assets + liabilities),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '资产 ${formatAmount(assets)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      '负债 ${formatAmount(liabilities.abs())}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final group in visibleGroups) ...<Widget>[
            if (accounts.any(
              (account) => account.groupId == group.id && !account.hidden,
            )) ...<Widget>[
              AccountGroupCard(
                title: group.name,
                accounts: accounts
                    .where(
                      (account) =>
                          account.groupId == group.id && !account.hidden,
                    )
                    .toList(),
                balances: balances,
                onAccountTap: (account) {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => AccountDetailPage(account: account),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class AccountGroupsPage extends StatefulWidget {
  const AccountGroupsPage({super.key});

  @override
  State<AccountGroupsPage> createState() => _AccountGroupsPageState();
}

class _AccountGroupsPageState extends State<AccountGroupsPage> {
  String? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final groups = controller.accountGroups;
    final accounts = controller.accounts;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        '账户分组',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '新增分组',
                      onPressed: () => _showGroupNameDialog(context),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 86),
                  itemCount: groups.length,
                  // ignore: deprecated_member_use
                  onReorder: controller.reorderAccountGroup,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final groupAccounts = accounts
                        .where((account) => account.groupId == group.id)
                        .toList();
                    final total = groupAccounts.fold<double>(
                      0,
                      (sum, account) =>
                          sum + controller.accountBalance(account),
                    );
                    final selected = _selectedGroupId == group.id;

                    return Padding(
                      key: ValueKey(group.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(veriRadiusMd),
                        onLongPress: () =>
                            setState(() => _selectedGroupId = group.id),
                        onTap: () => setState(() {
                          _selectedGroupId = selected ? null : group.id;
                        }),
                        child: VeriCard(
                          child: Row(
                            children: <Widget>[
                              VeriIconBox(icon: iconForCode(group.iconCode)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      group.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(
                                          veriRadiusSm,
                                        ),
                                      ),
                                      child: Text(
                                        '${groupAccounts.length}个账户',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatAmount(total),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (selected) const SizedBox(width: 6),
                              if (selected)
                                const Icon(Icons.check_circle, color: veriBlue),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _selectedGroupId == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _showGroupNameDialog(
                          context,
                          groupId: _selectedGroupId,
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Text('重命名'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _showIconDialog(context),
                        icon: const Icon(Icons.palette_outlined),
                        label: const Text('图标'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          controller.deleteAccountGroup(_selectedGroupId!);
                          setState(() => _selectedGroupId = null);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _showGroupNameDialog(
    BuildContext context, {
    String? groupId,
  }) async {
    final controller = VeriFinScope.of(context);
    final editingGroup = groupId == null
        ? null
        : controller.accountGroups.firstWhere((group) => group.id == groupId);
    final textController = TextEditingController(
      text: editingGroup?.name ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(groupId == null ? '新增分组' : '重命名分组'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(labelText: '分组名称'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (!context.mounted || name == null) {
      return;
    }
    if (groupId == null) {
      controller.addAccountGroup(name);
    } else {
      controller.renameAccountGroup(groupId, name);
    }
  }

  Future<void> _showIconDialog(BuildContext context) async {
    final controller = VeriFinScope.of(context);
    final groupId = _selectedGroupId;
    if (groupId == null) {
      return;
    }
    final iconCode = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择分组图标'),
        children: accountIconCodes
            .map(
              (code) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(code),
                child: Row(
                  children: <Widget>[
                    Icon(iconForCode(code)),
                    const SizedBox(width: 12),
                    Text(iconLabelForCode(code)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (iconCode != null) {
      controller.updateAccountGroupIcon(groupId, iconCode);
    }
  }
}

class AddAccountPage extends StatefulWidget {
  const AddAccountPage({super.key});

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _noteController = TextEditingController();
  AccountType _type = AccountType.onlinePayment;
  String _iconCode = 'wallet';
  String _groupId = 'ungrouped';

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final groups = controller.accountGroups;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        '添加账户',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '保存账户',
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AccountType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: '账户类型'),
                  items: AccountType.values
                      .map(
                        (type) => DropdownMenuItem<AccountType>(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _type = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '账户名称'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '账户名称必填';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '账户余额',
                    hintText: '不填默认为 0',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _iconCode,
                  decoration: const InputDecoration(labelText: '账户图标'),
                  items: accountIconCodes
                      .map(
                        (code) => DropdownMenuItem<String>(
                          value: code,
                          child: Row(
                            children: <Widget>[
                              Icon(iconForCode(code)),
                              const SizedBox(width: 8),
                              Text(iconLabelForCode(code)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _iconCode = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '账户备注'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _groupId,
                  decoration: const InputDecoration(labelText: '账户分组'),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: 'ungrouped',
                      child: Text('未分组'),
                    ),
                    ...groups.map(
                      (group) => DropdownMenuItem<String>(
                        value: group.id,
                        child: Text(group.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _groupId = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final controller = VeriFinScope.of(context);
    controller.addAccount(
      Account(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        type: _type,
        groupId: _groupId,
        initialBalance: double.tryParse(_balanceController.text.trim()) ?? 0,
        iconCode: _iconCode,
        note: _noteController.text.trim(),
        includeInAssets: true,
        hidden: false,
      ),
    );
    Navigator.of(context).pop();
  }
}

class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final currentAccount = controller.accounts.firstWhere(
      (item) => item.id == account.id,
      orElse: () => account,
    );
    final balance = controller.accountBalance(currentAccount);
    final entries = controller.entries
        .where((entry) => entry.accountId == currentAccount.id)
        .toList();
    final matchingGroups = controller.accountGroups.where(
      (group) => group.id == currentAccount.groupId,
    );
    final groupName = matchingGroups.isEmpty
        ? '未分组'
        : matchingGroups.first.name;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      currentAccount.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '删除账户',
                    onPressed: () {
                      controller.deleteAccount(currentAccount.id);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('当前余额'),
                          const SizedBox(height: 6),
                          Text(
                            formatAmount(balance),
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: veriBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                    VeriIconBox(
                      icon: iconForCode(currentAccount.iconCode),
                      size: 36,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionTitle(title: '余额趋势', trailing: '日'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 148,
                      child: CustomPaint(
                        painter: TrendLinePainter(
                          color: veriBlue,
                          values: accountBalanceSeries(currentAccount, entries),
                          xLabels: monthAxisLabels(DateTime.now()),
                          yLabels: reportAxisLabels(balance.abs()),
                          labelColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.50),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    TextButton(onPressed: () {}, child: const Text('查看报告')),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionTitle(title: '最近交易', trailing: '+'),
                    const SizedBox(height: 6),
                    if (entries.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: '暂无交易',
                        description: '该账户还没有交易记录。',
                      )
                    else
                      ...entries
                          .take(3)
                          .map(
                            (entry) => TransactionTile(
                              entry,
                              accounts: controller.accounts,
                            ),
                          ),
                    TextButton(onPressed: () {}, child: const Text('所有交易')),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('计入资产'),
                      value: currentAccount.includeInAssets,
                      onChanged: (value) {
                        controller.updateAccount(
                          currentAccount.copyWith(includeInAssets: value),
                        );
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('隐藏账户'),
                      value: currentAccount.hidden,
                      onChanged: (value) {
                        controller.updateAccount(
                          currentAccount.copyWith(hidden: value),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.category_outlined,
                      title: '类型',
                      trailing: currentAccount.type.label,
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.badge_outlined,
                      title: '名称',
                      trailing: currentAccount.name,
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.image_outlined,
                      title: '图标',
                      trailing: iconLabelForCode(currentAccount.iconCode),
                    ),
                    const Divider(),
                    const SettingsRow(
                      icon: Icons.currency_yuan,
                      title: '货币',
                      trailing: '人民币',
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.notes,
                      title: '备注',
                      trailing: currentAccount.note.isEmpty
                          ? '无'
                          : currentAccount.note,
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.folder_outlined,
                      title: '分组',
                      trailing: groupName,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final entries = controller.entries;
    final expenseEntries = entries
        .where((entry) => entry.type == EntryType.expense)
        .toList(growable: false);
    final expenseTotal = sumByType(entries, EntryType.expense);
    final topCategory = _topCategory(expenseEntries);

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 82),
        children: <Widget>[
          const PageHeader(title: '数据看板'),
          const SizedBox(height: 10),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: '分类统计',
                  trailing:
                      '-${formatAmount(expenseTotal)} · ${DateTime.now().month}月 · 支出',
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 138,
                      height: 138,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          CircularProgressIndicator(
                            value: expenseTotal > 0 ? 1 : 0,
                            strokeWidth: 18,
                            color: veriBlue,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '全部',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              Text(
                                '-${formatAmount(expenseTotal)}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            topCategory,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(expenseTotal == 0 ? '暂无支出记录' : '100.0% · 一级分类'),
                          const SizedBox(height: 8),
                          const Divider(),
                          Text(
                            '保存记录后自动聚合分类占比。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: '日趋势',
                  trailing: '-${formatAmount(expenseTotal)}',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 138,
                  child: CustomPaint(
                    painter: TrendLinePainter(
                      color: const Color(0xFFE84D6A),
                      values: dailyExpenseValues(entries, DateTime.now()),
                      xLabels: monthAxisLabels(DateTime.now()),
                      yLabels: reportAxisLabels(expenseTotal),
                      labelColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.50),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionTitle(title: '月度收支', trailing: '今年'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 146,
                  child: CustomPaint(
                    painter: BarChartPainter(
                      values: monthlyExpenseValues(entries),
                      xLabels: const <String>[
                        '1',
                        '2',
                        '3',
                        '4',
                        '5',
                        '6',
                        '7',
                        '8',
                        '9',
                        '10',
                        '11',
                        '12',
                      ],
                      labelColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.50),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final profile = controller.profile;
    final netAssets = controller.accounts
        .where((account) => account.includeInAssets && !account.hidden)
        .fold<double>(
          0,
          (sum, account) => sum + controller.accountBalance(account),
        );

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 82),
        children: <Widget>[
          PageHeader(
            title: '我的',
            trailing: IconButton(
              tooltip: '设置',
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const SettingsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(veriRadiusMd),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => const ProfileInfoPage(),
                ),
              );
            },
            child: VeriCard(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      ProfileAvatar(profile: profile, radius: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              profile.nickname,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              profile.bio,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ProfileStat(
                          label: '记账天数',
                          value: '${bookkeepingDays(controller.entries)}',
                        ),
                      ),
                      Expanded(
                        child: ProfileStat(
                          label: '交易笔数',
                          value: '${controller.entries.length}',
                        ),
                      ),
                      Expanded(
                        child: ProfileStat(
                          label: '净资产',
                          value: formatAmount(netAssets),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          VeriCard(
            child: Row(
              children: <Widget>[
                const VeriIconBox(icon: Icons.book),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '日常账本',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '当前账本',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 10),
          VeriCard(
            child: Column(
              children: <Widget>[
                SettingsRow(
                  icon: Icons.storage_outlined,
                  title: '本地数据',
                  trailing: '${controller.entries.length} 笔记录',
                ),
                const Divider(),
                const SettingsRow(
                  icon: Icons.cloud_off_outlined,
                  title: '云同步',
                  trailing: '本地优先',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileInfoPage extends StatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  State<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<ProfileInfoPage> {
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late String _avatarDataUrl;
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final profile = VeriFinScope.of(context).profile;
    _nicknameController = TextEditingController(text: profile.nickname);
    _bioController = TextEditingController(text: profile.bio);
    _avatarDataUrl = profile.avatarDataUrl;
    _initialized = true;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final netAssets = controller.accounts
        .where((account) => account.includeInAssets && !account.hidden)
        .fold<double>(
          0,
          (sum, account) => sum + controller.accountBalance(account),
        );

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      '个人信息',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '保存',
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(42),
                  onTap: _pickAvatar,
                  child: ProfileAvatar(
                    profile: controller.profile.copyWith(
                      avatarDataUrl: _avatarDataUrl,
                    ),
                    radius: 40,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(labelText: '昵称'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '简介'),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: ProfileStat(
                        label: '记账天数',
                        value: '${bookkeepingDays(controller.entries)}',
                      ),
                    ),
                    Expanded(
                      child: ProfileStat(
                        label: '交易笔数',
                        value: '${controller.entries.length}',
                      ),
                    ),
                    Expanded(
                      child: ProfileStat(
                        label: '净资产',
                        value: formatAmount(netAssets),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final avatar = await pickAvatarDataUrl();
    if (avatar == null || !mounted) {
      return;
    }
    setState(() => _avatarDataUrl = avatar);
  }

  void _save() {
    VeriFinScope.of(context).updateProfile(
      UserProfile(
        nickname: _nicknameController.text.trim().isEmpty
            ? 'Veri Fin'
            : _nicknameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? '完全免费 · 数据自主'
            : _bioController.text.trim(),
        avatarDataUrl: _avatarDataUrl,
      ),
    );
    Navigator.of(context).pop();
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text(
                    '设置',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '主题模式',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<ThemePreference>(
                      key: const Key('theme_segmented_button'),
                      segments: ThemePreference.values
                          .map(
                            (preference) => ButtonSegment<ThemePreference>(
                              value: preference,
                              label: Text(preference.label),
                            ),
                          )
                          .toList(),
                      selected: <ThemePreference>{controller.themePreference},
                      onSelectionChanged: (selection) {
                        controller.setThemePreference(selection.first);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.cloud_off_outlined,
                      title: '同步方式',
                      trailing: '本地优先',
                    ),
                    Divider(),
                    SettingsRow(
                      icon: Icons.android_outlined,
                      title: 'Android 打包',
                      trailing: 'GitHub CI',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, required this.radius});

  final UserProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (profile.avatarDataUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(profile.avatarDataUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: veriRoyal,
      child: Text(
        profile.nickname.isEmpty ? 'VF' : profile.nickname.characters.first,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ProfileStat extends StatelessWidget {
  const ProfileStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class EntryDetailPage extends StatefulWidget {
  const EntryDetailPage({super.key, required this.initialAmount});

  final double initialAmount;

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  late double _amount = widget.initialAmount;
  EntryType _type = EntryType.expense;
  late String _categoryId = categoriesFor(_type).first.id;
  String _accountId = defaultAccounts.first.id;
  DateTime _occurredAt = DateTime.now();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final accounts = controller.accounts.isEmpty
        ? defaultAccounts
        : controller.accounts;
    if (!accounts.any((account) => account.id == _accountId)) {
      _accountId = accounts.first.id;
    }
    final categories = categoriesFor(_type);
    final selectedAccount = accountById(accounts, _accountId);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: '返回',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '日常账本',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down),
                      const Spacer(),
                      TextButton(onPressed: () {}, child: const Text('设置')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<EntryType>(
                    key: const Key('entry_type_segmented_button'),
                    segments: EntryType.values
                        .map(
                          (type) => ButtonSegment<EntryType>(
                            value: type,
                            label: Text(type.label),
                          ),
                        )
                        .toList(),
                    selected: <EntryType>{_type},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _type = selection.first;
                        _categoryId = categoriesFor(_type).first.id;
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
                              color: veriBlue,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Text('分类', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ...categories
                          .take(8)
                          .map(
                            (category) => ChoiceChip(
                              avatar: Icon(category.icon, size: 18),
                              label: Text(category.label),
                              selected: _categoryId == category.id,
                              onSelected: (_) {
                                setState(() => _categoryId = category.id);
                              },
                            ),
                          ),
                      ActionChip(
                        avatar: const Icon(Icons.more_horiz, size: 18),
                        label: const Text('全部'),
                        onPressed: _showAllCategories,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('账户', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: const Key('account_dropdown'),
                    initialValue: _accountId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.wallet),
                    ),
                    items: accounts
                        .map(
                          (account) => DropdownMenuItem<String>(
                            value: account.id,
                            child: Text(
                              '${account.name} (${formatAmount(account.initialBalance)})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _accountId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('entry_note_field'),
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '备注',
                      hintText: '点击添加备注',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ActionChip(
                        avatar: const Icon(Icons.calendar_today, size: 18),
                        label: Text(formatDate(_occurredAt)),
                        onPressed: _pickDate,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.schedule, size: 18),
                        label: Text(formatTime(_occurredAt)),
                        onPressed: _pickTime,
                      ),
                      Chip(
                        avatar: Icon(
                          iconForCode(selectedAccount.iconCode),
                          size: 18,
                        ),
                        label: Text(selectedAccount.name),
                      ),
                    ],
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
                  onPressed: _save,
                  child: const Text('保存'),
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
      builder: (context) =>
          NumberPadSheet(title: '修改金额', initialAmount: _amount),
    );

    if (!mounted || amount == null || amount <= 0) {
      return;
    }

    setState(() => _amount = amount);
  }

  Future<void> _showAllCategories() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => CategoryPickerSheet(
        categories: categoriesFor(_type),
        selectedId: _categoryId,
      ),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() => _categoryId = selected);
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

  void _save() {
    final controller = VeriFinScope.of(context);
    controller.addEntry(
      LedgerEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: _type,
        amount: _amount,
        categoryId: _categoryId,
        accountId: _accountId,
        note: _noteController.text.trim(),
        occurredAt: _occurredAt,
      ),
    );
    Navigator.of(context).pop();
  }
}

String _topCategory(List<LedgerEntry> entries) {
  if (entries.isEmpty) {
    return '暂无';
  }

  final totals = <String, double>{};
  for (final entry in entries) {
    totals.update(
      entry.categoryId,
      (value) => value + entry.amount,
      ifAbsent: () => entry.amount,
    );
  }

  final top = totals.entries.reduce(
    (previous, current) => previous.value >= current.value ? previous : current,
  );
  return categoryById(top.key).label;
}

List<String> monthAxisLabels(DateTime month) {
  final days = DateUtils.getDaysInMonth(month.year, month.month);
  return <String>[
    '${month.month}.1',
    '${month.month}.${(days / 2).round()}',
    '${month.month}.$days',
  ];
}

List<String> reportAxisLabels(double maxValue) {
  final top = maxValue <= 0 ? 100 : maxValue;
  return <String>['0', formatAmount(top / 2), formatAmount(top)];
}

List<double> accountBalanceSeries(Account account, List<LedgerEntry> entries) {
  final now = DateTime.now();
  final days = DateUtils.getDaysInMonth(now.year, now.month);
  var runningBalance = account.initialBalance;
  final values = List<double>.filled(days, account.initialBalance.abs());
  final sortedEntries = List<LedgerEntry>.from(entries)
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

  for (final entry in sortedEntries) {
    if (entry.occurredAt.year != now.year ||
        entry.occurredAt.month != now.month) {
      continue;
    }
    runningBalance += signedAmount(entry);
    values[entry.occurredAt.day - 1] = runningBalance.abs();
  }

  for (var i = 1; i < values.length; i += 1) {
    if (values[i] == account.initialBalance.abs()) {
      values[i] = values[i - 1];
    }
  }
  return values;
}

int bookkeepingDays(List<LedgerEntry> entries) {
  if (entries.isEmpty) {
    return 0;
  }
  final first = entries
      .map((entry) => entry.occurredAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return DateTime.now().difference(first).inDays + 1;
}
