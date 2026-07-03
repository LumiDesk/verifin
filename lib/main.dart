import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_theme.dart';
import 'app/account_icon_assets.dart';
import 'app/avatar_picker.dart';
import 'app/chart_painters.dart';
import 'app/common_widgets.dart';
import 'app/data_file_port.dart';
import 'app/demo_data.dart';
import 'app/entry_sheets.dart';
import 'app/image_cropper.dart';
import 'app/ledger_math.dart';
import 'app/models.dart';
import 'app/platform_bridge.dart';
import 'app/veri_fin_controller.dart';
import 'local_storage/local_storage.dart';

const String appVersionLabel = 'v1.0.2+4';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalKeyValueStore.create();
  runApp(VeriFinApp(store: store));
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
            locale: const Locale('zh', 'CN'),
            supportedLocales: const <Locale>[
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
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
  DateTime? _lastBackPressedAt;

  @override
  void initState() {
    super.initState();
    AppPlatformBridge.setQuickEntryHandler(_openQuickEntryFromPlatform);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await AppPlatformBridge.consumeInitialQuickEntryIntent() && mounted) {
        await _openQuickEntryFromPlatform();
      }
    });
  }

  @override
  void dispose() {
    AppPlatformBridge.clearQuickEntryHandler();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const AssetsPage(),
      const ReportsPage(),
      const ProfilePage(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _handleRootBack();
      },
      child: Scaffold(
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
      ),
    );
  }

  void _handleRootBack() {
    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }
    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);
    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressedAt = now;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('再次返回退出程序')));
  }

  Future<void> _startQuickEntry(BuildContext context) async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => NumberPadSheet(
        title: '快速记账',
        hapticsEnabled: VeriFinScope.of(context).hapticsEnabled,
      ),
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

  Future<void> _openQuickEntryFromPlatform() async {
    if (!mounted) {
      return;
    }
    if (_index != 0) {
      setState(() => _index = 0);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!mounted) {
      return;
    }
    await _startQuickEntry(context);
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? veriRoyal
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Tooltip(
      message: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Semantics(
          label: item.label,
          selected: selected,
          button: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: selected ? 42 : 38,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? veriRoyal.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  color: color,
                  size: selected ? 22 : 21,
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
    final trendWindow = sevenDayWindowFor(now);
    final trendEntries = entriesInWindow(monthEntries, trendWindow);
    final trendExpense = sumByType(trendEntries, EntryType.expense);
    final trendIncome = sumByType(trendEntries, EntryType.income);
    final recentEntries = entries.take(5).toList();
    final monthlyBudget = controller.monthlyBudget(now);
    final categoryBudgetSnapshots = _categoryBudgetSnapshots(
      controller: controller,
      month: now,
      monthEntries: monthEntries,
    );
    final categoryBudgetRisk = _topCategoryBudgetRisk(categoryBudgetSnapshots);

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 82),
        children: <Widget>[
          const PageHeader(title: '首页', subtitle: '日常账本'),
          const SizedBox(height: 10),
          HomeTrendPanel(
            window: trendWindow,
            expense: trendExpense,
            income: trendIncome,
            values: valuesForTypeInWindow(
              trendEntries,
              trendWindow,
              EntryType.expense,
            ),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => const IncomeExpenseStatsPage(),
                ),
              );
            },
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
                      categories: controller.categories,
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
          BudgetPanel(
            month: now,
            expense: monthExpense,
            budget: monthlyBudget,
            categoryRisk: categoryBudgetRisk,
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => BudgetSettingsPage(initialMonth: now),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          CalendarPreview(
            entries: monthEntries,
            onDayTap: (date) {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => TransactionsPage(initialDate: date),
                ),
              );
            },
          ),
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
  final VoidCallback? onTap;

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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (trailing.isNotEmpty) ...<Widget>[
              Text(
                trailing,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.52),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const _CircleArrow(),
          ],
        ),
      ),
    );
  }
}

class HomeTrendPanel extends StatelessWidget {
  const HomeTrendPanel({
    super.key,
    required this.window,
    required this.expense,
    required this.income,
    required this.values,
    required this.onTap,
  });

  final DateWindow window;
  final double expense;
  final double income;
  final List<double> values;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = textColor.withValues(alpha: isDark ? 0.62 : 0.52);
    final net = income - expense;
    final daysWithExpense = values.where((value) => value > 0).length;
    final hasExpense = !isZeroAmount(expense);
    final netColor = isZeroAmount(net)
        ? mutedColor
        : (net > 0 ? veriIncome : veriExpense);

    return VeriCard(
      onTap: onTap,
      quietTap: true,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        window.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '支出走势',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const _CircleArrow(),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatExpenseAmount(expense),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: hasExpense ? veriExpense : mutedColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: netColor.withValues(alpha: isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '结余 ${formatSignedAmount(net)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: netColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TrendMetric(
                    label: '收入',
                    value: formatAmount(income),
                    color: isZeroAmount(income) ? mutedColor : veriIncome,
                    dark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TrendMetric(
                    label: '记账日',
                    value: '$daysWithExpense天',
                    color: veriRoyal,
                    dark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TrendMetric(
                    label: '日均支出',
                    value: formatAmount(
                      expense / window.days.length.clamp(1, 7),
                    ),
                    color: veriBlue,
                    dark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 138,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
              decoration: BoxDecoration(
                color: isDark ? veriSurfaceAltDark : const Color(0xFFF7FAFF),
                borderRadius: BorderRadius.circular(veriRadiusSm),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFEAF0F8),
                ),
              ),
              child: CustomPaint(
                painter: TrendLinePainter(
                  color: hasExpense ? veriExpense : mutedColor,
                  values: values,
                  xLabels: labelsForWindow(window),
                  yLabels: reportAxisLabels(expense),
                  labelColor: mutedColor,
                  glow: isDark,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendMetric extends StatelessWidget {
  const _TrendMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.dark,
  });

  final String label;
  final String value;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: dark
            ? color.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(veriRadiusSm),
        border: Border.all(
          color: dark
              ? color.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.50),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: dark ? Colors.white.withValues(alpha: 0.86) : color,
              fontWeight: FontWeight.w800,
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
    required this.categoryRisk,
    required this.onTap,
  });

  final DateTime month;
  final double expense;
  final double budget;
  final CategoryBudgetSnapshot? categoryRisk;
  final VoidCallback onTap;

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
    final ratio = budget <= 0 ? 0.0 : (expense / budget).clamp(0, 1).toDouble();

    return VeriCard(
      onTap: onTap,
      quietTap: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${month.month}月预算',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const _CircleArrow(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _BudgetSideStat(
                  label: '支出',
                  value: formatExpenseAmount(expense),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 116,
                      height: 116,
                      child: CustomPaint(
                        painter: BudgetRingPainter(
                          value: ratio,
                          trackColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.48),
                          progressColor: ratio > 0.85
                              ? veriExpense
                              : veriWarning,
                        ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${(ratio * 100).toStringAsFixed(0)}%',
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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              '预算 ${formatAmount(budget)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.44),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (categoryRisk != null) ...<Widget>[
            const SizedBox(height: 8),
            _HomeBudgetRiskBanner(snapshot: categoryRisk!),
          ],
        ],
      ),
    );
  }
}

class _CircleArrow extends StatelessWidget {
  const _CircleArrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: veriRoyal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Icon(Icons.chevron_right, size: 17, color: veriRoyal),
    );
  }
}

class IncomeExpenseStatsPage extends StatefulWidget {
  const IncomeExpenseStatsPage({super.key});

  @override
  State<IncomeExpenseStatsPage> createState() => _IncomeExpenseStatsPageState();
}

class _IncomeExpenseStatsPageState extends State<IncomeExpenseStatsPage> {
  DateTime _focusDate = DateTime.now();
  EntryType _type = EntryType.expense;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final visibleMonth = DateTime(_focusDate.year, _focusDate.month);
    final window = sevenDayWindowFor(_focusDate);
    final scopedEntries = controller.entries
        .where(
          (entry) =>
              entry.occurredAt.year == visibleMonth.year &&
              entry.occurredAt.month == visibleMonth.month &&
              entry.type == _type,
        )
        .toList();
    final windowEntries = entriesInWindow(scopedEntries, window);
    final total = windowEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    final dayRows = _dailyStatRows(windowEntries, window.start, total);
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.52);
    final totalColor = isZeroAmount(total) ? mutedColor : colorForType(_type);
    final totalText = switch (_type) {
      EntryType.expense => formatExpenseAmount(total),
      EntryType.income => formatIncomeAmount(total),
      EntryType.transfer => formatAmount(total),
    };

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              const VeriHeader(title: '收支统计', showBack: true),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  _MonthSwitcher(
                    month: visibleMonth,
                    onPrevious: () => setState(() {
                      _focusDate = DateTime(
                        _focusDate.year,
                        _focusDate.month - 1,
                      );
                    }),
                    onNext: () => setState(() {
                      _focusDate = DateTime(
                        _focusDate.year,
                        _focusDate.month + 1,
                      );
                    }),
                  ),
                  const Spacer(),
                  FilterPill(label: _type.label, onTap: _pickEntryType),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${window.label} ${_type.label}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalText,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: totalColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: CustomPaint(
                        painter: TrendLinePainter(
                          color: totalColor,
                          values: valuesForTypeInWindow(
                            windowEntries,
                            window,
                            _type,
                          ),
                          xLabels: labelsForWindow(window),
                          yLabels: reportAxisLabels(total),
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
                  children: <Widget>[
                    if (dayRows.isEmpty)
                      const EmptyState(
                        icon: Icons.bar_chart_outlined,
                        title: '暂无统计',
                        description: '当前月份没有对应记录。',
                      )
                    else
                      for (final row in dayRows.indexed) ...<Widget>[
                        _DailyStatTile(row: row.$2, type: _type),
                        if (row.$1 != dayRows.length - 1) const Divider(),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickEntryType() async {
    final selected = await _showOptionSheet<EntryType>(
      context: context,
      title: '统计类型',
      values: EntryType.values,
      selected: _type,
      labelOf: (value) => value.label,
    );
    if (selected != null) {
      setState(() => _type = selected);
    }
  }
}

class _HomeBudgetRiskBanner extends StatelessWidget {
  const _HomeBudgetRiskBanner({required this.snapshot});

  final CategoryBudgetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final color = snapshot.overBudget ? veriExpense : veriWarning;
    final text = snapshot.overBudget
        ? '${snapshot.category.label}超出 ${formatAmount(snapshot.spent - snapshot.budget)}'
        : '${snapshot.category.label}已用 ${(snapshot.ratio * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(veriRadiusSm),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            snapshot.overBudget
                ? Icons.warning_amber_rounded
                : Icons.error_outline,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetSettingsPage extends StatefulWidget {
  const BudgetSettingsPage({super.key, required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<BudgetSettingsPage> createState() => _BudgetSettingsPageState();
}

class _BudgetSettingsPageState extends State<BudgetSettingsPage> {
  late DateTime _month = DateTime(
    widget.initialMonth.year,
    widget.initialMonth.month,
  );
  late final TextEditingController _amountController;
  bool _amountInitialized = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_amountInitialized) {
      return;
    }
    _amountController.text = formatAmount(
      VeriFinScope.of(context).monthlyBudget(_month),
    );
    _amountInitialized = true;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final monthEntries = controller.entries
        .where((entry) => _isInMonth(entry, _month))
        .toList(growable: false);
    final previousMonth = DateTime(_month.year, _month.month - 1);
    final previousMonthEntries = controller.entries
        .where((entry) => _isInMonth(entry, previousMonth))
        .toList(growable: false);
    final monthExpense = sumByType(monthEntries, EntryType.expense);
    final previousMonthExpense = sumByType(
      previousMonthEntries,
      EntryType.expense,
    );
    final budget = double.tryParse(_amountController.text) ?? 0;
    final previousBudget = controller.monthlyBudget(previousMonth);
    final remaining = budget - monthExpense;
    final ratio = budget <= 0
        ? 0.0
        : (monthExpense / budget).clamp(0, 1).toDouble();
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    final isPastMonth =
        _month.year < now.year ||
        (_month.year == now.year && _month.month < now.month);
    final remainingDays = isPastMonth
        ? 0
        : isCurrentMonth
        ? (daysInMonth - now.day + 1).clamp(1, daysInMonth)
        : daysInMonth;
    final dailyAvailable = remainingDays <= 0 || remaining <= 0
        ? 0.0
        : remaining / remainingDays;
    final categoryBudgetSnapshots = _categoryBudgetSnapshots(
      controller: controller,
      month: _month,
      monthEntries: monthEntries,
      previousMonthEntries: previousMonthEntries,
    );
    final recentBudgetMonths = _budgetMonthSnapshots(
      controller: controller,
      anchor: _month,
      count: 6,
    );
    final budgetedCategoryCount = categoryBudgetSnapshots
        .where((snapshot) => snapshot.hasBudget)
        .length;
    final categoryBudgetRisk = _topCategoryBudgetRisk(categoryBudgetSnapshots);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: '预算设置',
                subtitle: '${_month.year}年${_month.month}月',
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.check,
                    tooltip: '保存预算',
                    onPressed: _save,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _MonthSwitcher(
                      month: _month,
                      onPrevious: () => _changeMonth(-1),
                      onNext: () => _changeMonth(1),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        SizedBox(
                          width: 132,
                          height: 132,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: 118,
                                height: 118,
                                child: CustomPaint(
                                  painter: BudgetRingPainter(
                                    value: ratio,
                                    trackColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.48),
                                    progressColor: _budgetProgressColor(
                                      budget,
                                      remaining,
                                      ratio,
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    '已用',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.48),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  Text(
                                    '${(budget <= 0 ? 0 : monthExpense / budget * 100).toStringAsFixed(0)}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: _budgetProgressColor(
                                            budget,
                                            remaining,
                                            ratio,
                                          ),
                                        ),
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
                                remaining < 0 ? '本月已超支' : '本月可用预算',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                remaining < 0
                                    ? formatExpenseAmount(remaining.abs())
                                    : formatAmount(remaining),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      color: remaining < 0
                                          ? veriExpense
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _budgetPeriodLabel(
                                  remainingDays,
                                  isPastMonth,
                                  isCurrentMonth,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.52),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.45,
                      children: <Widget>[
                        _BudgetMetricTile(
                          label: '本月支出',
                          value: formatExpenseAmount(monthExpense),
                          icon: Icons.payments_outlined,
                          color: veriExpense,
                        ),
                        _BudgetMetricTile(
                          label: remaining < 0 ? '超出预算' : '剩余额度',
                          value: remaining < 0
                              ? formatExpenseAmount(remaining.abs())
                              : formatAmount(remaining),
                          icon: remaining < 0
                              ? Icons.warning_amber_rounded
                              : Icons.account_balance_wallet_outlined,
                          color: remaining < 0 ? veriExpense : veriIncome,
                        ),
                        _BudgetMetricTile(
                          label: '剩余日均',
                          value: formatAmount(dailyAvailable),
                          icon: Icons.today_outlined,
                          color: veriRoyal,
                        ),
                        _BudgetMetricTile(
                          label: '预算金额',
                          value: formatAmount(budget),
                          icon: Icons.flag_outlined,
                          color: veriBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _BudgetInsightCard(
                budget: budget,
                expense: monthExpense,
                remaining: remaining,
                ratio: ratio,
                remainingDays: remainingDays,
              ),
              const SizedBox(height: 10),
              _BudgetTrendCard(months: recentBudgetMonths),
              const SizedBox(height: 10),
              _BudgetHistoryCard(
                currentMonth: _month,
                previousMonth: previousMonth,
                currentExpense: monthExpense,
                previousExpense: previousMonthExpense,
                currentBudget: budget,
                previousBudget: previousBudget,
                onHistoryTap: _openBudgetHistory,
              ),
              if (categoryBudgetRisk != null ||
                  budgetedCategoryCount > 0) ...<Widget>[
                const SizedBox(height: 10),
                _CategoryBudgetAlertCard(
                  snapshot: categoryBudgetRisk,
                  budgetedCategoryCount: budgetedCategoryCount,
                ),
              ],
              const SizedBox(height: 10),
              VeriCard(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '分类预算',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '本月支出分类',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.48),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (categoryBudgetSnapshots.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            '还没有支出分类',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.48),
                                ),
                          ),
                        ),
                      )
                    else
                      for (final snapshot in categoryBudgetSnapshots)
                        _CategoryBudgetRow(
                          snapshot: snapshot,
                          onTap: () => _editCategoryBudget(snapshot.category),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '设置预算',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '月份预算金额',
                        helperText: '预算为 0 时仅记录支出，不计算剩余日均。',
                        prefixIcon: Icon(Icons.currency_yuan),
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

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _amountController.text = formatAmount(
        VeriFinScope.of(context).monthlyBudget(_month),
      );
    });
  }

  void _save() {
    VeriFinScope.of(
      context,
    ).setMonthlyBudget(_month, double.tryParse(_amountController.text) ?? 0);
    Navigator.of(context).pop();
  }

  Future<void> _editCategoryBudget(Category category) async {
    final controller = VeriFinScope.of(context);
    final currentBudget = controller.categoryBudget(_month, category.id);
    final amountText = await _showTextInputDialog(
      context: context,
      title: '设置${category.label}预算',
      label: '分类预算金额',
      initialValue: currentBudget <= 0 ? '' : formatAmount(currentBudget),
      allowEmpty: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    if (amountText == null || !mounted) {
      return;
    }
    controller.setCategoryBudget(
      _month,
      category.id,
      double.tryParse(amountText) ?? 0,
    );
  }

  void _openBudgetHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => BudgetHistoryPage(anchorMonth: _month),
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: '上个月',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${month.year}年${month.month}月',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        IconButton(
          tooltip: '下个月',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class BudgetHistoryPage extends StatelessWidget {
  const BudgetHistoryPage({super.key, required this.anchorMonth});

  final DateTime anchorMonth;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final months = _budgetMonthSnapshots(
      controller: controller,
      anchor: anchorMonth,
      count: 12,
    ).reversed.toList(growable: false);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              const VeriHeader(
                title: '预算历史',
                subtitle: '最近 12 个月',
                showBack: true,
              ),
              const SizedBox(height: 10),
              _BudgetTrendCard(
                months: months.take(6).toList().reversed.toList(),
              ),
              const SizedBox(height: 10),
              VeriCard(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '月份汇总',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final item in months)
                      _BudgetMonthRow(
                        snapshot: item,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  BudgetSettingsPage(initialMonth: item.month),
                            ),
                          );
                        },
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

class _DailyStatRow {
  const _DailyStatRow({
    required this.date,
    required this.amount,
    required this.percent,
    required this.count,
  });

  final DateTime date;
  final double amount;
  final double percent;
  final int count;
}

class _DailyStatTile extends StatelessWidget {
  const _DailyStatTile({required this.row, required this.type});

  final _DailyStatRow row;
  final EntryType type;

  @override
  Widget build(BuildContext context) {
    final amountColor = colorForType(type);
    final amountText = switch (type) {
      EntryType.expense => formatExpenseAmount(row.amount),
      EntryType.income => '+${formatIncomeAmount(row.amount)}',
      EntryType.transfer => formatAmount(row.amount),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          VeriIconBox(
            icon: Icons.calendar_today_outlined,
            color: amountColor,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${row.date.month.toString().padLeft(2, '0')}.${row.date.day.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${(row.percent * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.48),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                amountText,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${row.count}笔',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.48),
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

class _BudgetMetricTile extends StatelessWidget {
  const _BudgetMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(veriRadiusSm),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: <Widget>[
          VeriIconBox(icon: icon, color: color, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.50),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetTrendCard extends StatelessWidget {
  const _BudgetTrendCard({required this.months});

  final List<BudgetMonthSnapshot> months;

  @override
  Widget build(BuildContext context) {
    final maxValue = months.fold<double>(
      0,
      (max, item) => math.max(max, math.max(item.expense, item.budget)),
    );
    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '近 6 月趋势',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _ChartLegendDot(color: veriRoyal, label: '预算'),
                  const SizedBox(width: 8),
                  _ChartLegendDot(color: veriExpense, label: '支出'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: CustomPaint(
              painter: _BudgetTrendPainter(
                months: months,
                labelColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.50),
                yLabels: reportAxisLabels(maxValue),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.48),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BudgetTrendPainter extends CustomPainter {
  const _BudgetTrendPainter({
    required this.months,
    required this.labelColor,
    required this.yLabels,
  });

  final List<BudgetMonthSnapshot> months;
  final Color labelColor;
  final List<String> yLabels;

  @override
  void paint(Canvas canvas, Size size) {
    const leftInset = 30.0;
    const rightInset = 8.0;
    const bottomInset = 22.0;
    final chartRect = Rect.fromLTWH(
      leftInset,
      0,
      size.width - leftInset - rightInset,
      size.height - bottomInset,
    );
    final axisPaint = Paint()
      ..color = labelColor.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i += 1) {
      final y = chartRect.bottom - chartRect.height * i / 3;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        axisPaint,
      );
    }

    final maxValue = math.max(
      months.fold<double>(
        0,
        (max, item) => math.max(max, math.max(item.expense, item.budget)),
      ),
      1,
    );
    final gap = chartRect.width / math.max(months.length, 1);
    final barPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          veriExpense.withValues(alpha: 0.82),
          veriExpense.withValues(alpha: 0.30),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(chartRect);
    final linePaint = Paint()
      ..color = veriRoyal
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = veriRoyal;
    final path = Path();

    for (var i = 0; i < months.length; i += 1) {
      final item = months[i];
      final centerX = chartRect.left + gap * i + gap / 2;
      final barHeight = item.expense / maxValue * chartRect.height * 0.86;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - gap * 0.16,
          chartRect.bottom - barHeight,
          gap * 0.32,
          barHeight,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(barRect, barPaint);

      final budgetY =
          chartRect.bottom - item.budget / maxValue * chartRect.height * 0.86;
      if (i == 0) {
        path.moveTo(centerX, budgetY);
      } else {
        path.lineTo(centerX, budgetY);
      }
    }
    canvas.drawPath(path, linePaint);
    for (var i = 0; i < months.length; i += 1) {
      final item = months[i];
      final centerX = chartRect.left + gap * i + gap / 2;
      final budgetY =
          chartRect.bottom - item.budget / maxValue * chartRect.height * 0.86;
      canvas.drawCircle(Offset(centerX, budgetY), 2.4, pointPaint);
    }

    _drawBudgetTrendLabels(canvas, chartRect);
  }

  void _drawBudgetTrendLabels(Canvas canvas, Rect chartRect) {
    final labelStyle = TextStyle(
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    for (var i = 0; i < yLabels.length; i += 1) {
      final painter = TextPainter(
        text: TextSpan(text: yLabels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: chartRect.left - 4);
      final y = chartRect.bottom - chartRect.height * i / (yLabels.length - 1);
      painter.paint(canvas, Offset(0, y - painter.height / 2));
    }

    if (months.isEmpty) {
      return;
    }
    final gap = chartRect.width / months.length;
    for (var i = 0; i < months.length; i += 1) {
      final label = '${months[i].month.month}月';
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: gap);
      final x = chartRect.left + gap * i + gap / 2 - painter.width / 2;
      painter.paint(canvas, Offset(x, chartRect.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _BudgetTrendPainter oldDelegate) {
    return oldDelegate.months != months ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.yLabels != yLabels;
  }
}

class _BudgetHistoryCard extends StatelessWidget {
  const _BudgetHistoryCard({
    required this.currentMonth,
    required this.previousMonth,
    required this.currentExpense,
    required this.previousExpense,
    required this.currentBudget,
    required this.previousBudget,
    required this.onHistoryTap,
  });

  final DateTime currentMonth;
  final DateTime previousMonth;
  final double currentExpense;
  final double previousExpense;
  final double currentBudget;
  final double previousBudget;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final expenseDelta = currentExpense - previousExpense;
    final currentUsage = currentBudget <= 0
        ? 0.0
        : currentExpense / currentBudget;
    final previousUsage = previousBudget <= 0
        ? 0.0
        : previousExpense / previousBudget;
    final usageDelta = currentUsage - previousUsage;
    final deltaColor = isZeroAmount(expenseDelta)
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)
        : expenseDelta > 0
        ? veriExpense
        : veriIncome;

    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '历史对比',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: onHistoryTap,
                icon: const Icon(Icons.history, size: 15),
                label: Text('${previousMonth.month}月 → ${currentMonth.month}月'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(44, 32),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _BudgetCompareTile(
                  label: '本月支出',
                  value: formatExpenseAmount(currentExpense),
                  detail: _expenseDeltaLabel(expenseDelta),
                  color: deltaColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BudgetCompareTile(
                  label: '上月支出',
                  value: formatExpenseAmount(previousExpense),
                  detail: previousExpense <= 0 ? '暂无支出' : '对比基准',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: currentUsage.clamp(0, 1).toDouble(),
              minHeight: 5,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
              valueColor: AlwaysStoppedAnimation<Color>(
                currentUsage >= 1
                    ? veriExpense
                    : currentUsage >= 0.85
                    ? veriWarning
                    : veriRoyal,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '预算使用率 ${(currentUsage * 100).toStringAsFixed(0)}%，较上月 ${_usageDeltaLabel(usageDelta)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetMonthRow extends StatelessWidget {
  const _BudgetMonthRow({required this.snapshot, required this.onTap});

  final BudgetMonthSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = snapshot.budget <= 0
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58)
        : snapshot.overBudget
        ? veriExpense
        : veriIncome;
    final status = snapshot.budget <= 0
        ? '未设置预算'
        : snapshot.overBudget
        ? '超出 ${formatAmount(snapshot.expense - snapshot.budget)}'
        : '剩余 ${formatAmount(snapshot.remaining)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: <Widget>[
              VeriIconBox(
                icon: Icons.calendar_month_outlined,
                color: color,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${snapshot.month.year}年${snapshot.month.month}月',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right,
                          size: 17,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.36),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '预算 ${formatAmount(snapshot.budget)} · 支出 ${formatExpenseAmount(snapshot.expense)} · 已用 ${(snapshot.ratio * 100).toStringAsFixed(0)}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.50),
                        fontWeight: FontWeight.w600,
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
}

class _BudgetCompareTile extends StatelessWidget {
  const _BudgetCompareTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(veriRadiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.50),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.44),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetAlertCard extends StatelessWidget {
  const _CategoryBudgetAlertCard({
    required this.snapshot,
    required this.budgetedCategoryCount,
  });

  final CategoryBudgetSnapshot? snapshot;
  final int budgetedCategoryCount;

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    final color = current == null
        ? veriIncome
        : current.overBudget
        ? veriExpense
        : veriWarning;
    final icon = current == null
        ? Icons.check_circle_outline
        : current.overBudget
        ? Icons.warning_amber_rounded
        : Icons.error_outline;
    final title = current == null
        ? '分类预算正常'
        : current.overBudget
        ? '${current.category.label}已超支'
        : '${current.category.label}接近预算';
    final description = current == null
        ? '已设置 $budgetedCategoryCount 个分类预算，当前没有临近超支的分类。'
        : current.overBudget
        ? '已超出 ${formatAmount(current.spent - current.budget)}，本月已用 ${(current.ratio * 100).toStringAsFixed(0)}%。'
        : '剩余 ${formatAmount(current.remaining)}，本月已用 ${(current.ratio * 100).toStringAsFixed(0)}%。';

    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          VeriIconBox(icon: icon, color: color, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
                    height: 1.35,
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

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({required this.snapshot, required this.onTap});

  final CategoryBudgetSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = snapshot.budget <= 0
        ? veriBlue
        : snapshot.spent > snapshot.budget
        ? veriExpense
        : veriRoyal;
    final subtitle = snapshot.budget <= 0
        ? '未设置预算 · 本月支出 ${formatAmount(snapshot.spent)}'
        : snapshot.remaining >= 0
        ? '剩余 ${formatAmount(snapshot.remaining)} · 已用 ${(snapshot.ratio * 100).toStringAsFixed(0)}%'
        : '超出 ${formatAmount(snapshot.remaining.abs())} · 已用 ${(snapshot.ratio * 100).toStringAsFixed(0)}%';
    final previousText = snapshot.previousSpent <= 0
        ? '上月无支出'
        : '上月 ${formatAmount(snapshot.previousSpent)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              VeriIconBox(
                icon: iconForCode(snapshot.category.iconCode),
                color: color,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            snapshot.category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          snapshot.budget <= 0
                              ? '设置'
                              : formatAmount(snapshot.budget),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: snapshot.budget <= 0
                                    ? Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.52)
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right,
                          size: 17,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.36),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.52),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      previousText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.38),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: snapshot.progress,
                        minHeight: 4,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.50),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
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
}

class _BudgetInsightCard extends StatelessWidget {
  const _BudgetInsightCard({
    required this.budget,
    required this.expense,
    required this.remaining,
    required this.ratio,
    required this.remainingDays,
  });

  final double budget;
  final double expense;
  final double remaining;
  final double ratio;
  final int remainingDays;

  @override
  Widget build(BuildContext context) {
    final color = _budgetProgressColor(budget, remaining, ratio);
    final (title, description, icon) = _budgetInsight(
      budget: budget,
      expense: expense,
      remaining: remaining,
      ratio: ratio,
      remainingDays: remainingDays,
    );

    return VeriCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          VeriIconBox(icon: icon, color: color, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
                    height: 1.4,
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

Color _budgetProgressColor(double budget, double remaining, double ratio) {
  if (budget <= 0) {
    return veriLine;
  }
  if (remaining < 0 || ratio >= 1) {
    return veriExpense;
  }
  if (ratio >= 0.85) {
    return veriWarning;
  }
  return veriRoyal;
}

String _budgetPeriodLabel(
  int remainingDays,
  bool isPastMonth,
  bool isCurrentMonth,
) {
  if (isPastMonth) {
    return '月份已结束';
  }
  if (isCurrentMonth) {
    return '含今天还剩 $remainingDays 天';
  }
  return '本月共 $remainingDays 天';
}

(String, String, IconData) _budgetInsight({
  required double budget,
  required double expense,
  required double remaining,
  required double ratio,
  required int remainingDays,
}) {
  if (budget <= 0) {
    return (
      '还没有设置预算',
      '设置本月预算后，首页和这里会同步展示预算进度、剩余额度和剩余日均。',
      Icons.flag_outlined,
    );
  }
  if (remaining < 0) {
    return (
      '预算已经超出',
      '本月支出已超过预算 ${formatAmount(remaining.abs())}，后续支出会继续计入本月统计。',
      Icons.warning_amber_rounded,
    );
  }
  if (ratio >= 0.85) {
    return (
      '预算接近用完',
      '本月预算已使用 ${(ratio * 100).toStringAsFixed(0)}%，剩余 ${formatAmount(remaining)}。',
      Icons.error_outline,
    );
  }
  if (remainingDays > 0) {
    return (
      '预算状态正常',
      '按当前预算，本月剩余每天约可支出 ${formatAmount(remaining / remainingDays)}。',
      Icons.check_circle_outline,
    );
  }
  return (
    '本月预算已结算',
    '这个月份已结束，可切换到其他月份继续查看或调整预算。',
    Icons.event_available_outlined,
  );
}

class CategoryBudgetSnapshot {
  const CategoryBudgetSnapshot({
    required this.category,
    required this.spent,
    required this.budget,
    required this.previousSpent,
  });

  final Category category;
  final double spent;
  final double budget;
  final double previousSpent;

  bool get hasBudget => budget > 0;

  double get remaining => budget - spent;

  double get ratio => hasBudget ? spent / budget : 0;

  double get progress => hasBudget ? ratio.clamp(0, 1).toDouble() : 0;

  bool get overBudget => hasBudget && spent > budget;

  bool get nearLimit => hasBudget && !overBudget && ratio >= 0.85;

  bool get needsAttention => overBudget || nearLimit;
}

class BudgetMonthSnapshot {
  const BudgetMonthSnapshot({
    required this.month,
    required this.budget,
    required this.expense,
  });

  final DateTime month;
  final double budget;
  final double expense;

  double get remaining => budget - expense;

  double get ratio => budget <= 0 ? 0 : expense / budget;

  bool get overBudget => budget > 0 && expense > budget;
}

List<BudgetMonthSnapshot> _budgetMonthSnapshots({
  required VeriFinController controller,
  required DateTime anchor,
  required int count,
}) {
  return List<BudgetMonthSnapshot>.generate(count, (index) {
    final month = DateTime(anchor.year, anchor.month - count + 1 + index);
    final entries = controller.entries
        .where((entry) => _isInMonth(entry, month))
        .toList(growable: false);
    return BudgetMonthSnapshot(
      month: month,
      budget: controller.monthlyBudget(month),
      expense: sumByType(entries, EntryType.expense),
    );
  });
}

List<CategoryBudgetSnapshot> _categoryBudgetSnapshots({
  required VeriFinController controller,
  required DateTime month,
  required List<LedgerEntry> monthEntries,
  List<LedgerEntry> previousMonthEntries = const <LedgerEntry>[],
}) {
  final spentByCategory = <String, double>{};
  for (final entry in monthEntries.where(
    (entry) => entry.type == EntryType.expense,
  )) {
    spentByCategory.update(
      entry.categoryId,
      (amount) => amount + entry.amount,
      ifAbsent: () => entry.amount,
    );
  }
  final previousSpentByCategory = <String, double>{};
  for (final entry in previousMonthEntries.where(
    (entry) => entry.type == EntryType.expense,
  )) {
    previousSpentByCategory.update(
      entry.categoryId,
      (amount) => amount + entry.amount,
      ifAbsent: () => entry.amount,
    );
  }

  final snapshots = controller
      .categoriesForType(EntryType.expense)
      .where((category) => category.id != 'balance_adjust_expense')
      .map(
        (category) => CategoryBudgetSnapshot(
          category: category,
          spent: spentByCategory[category.id] ?? 0,
          budget: controller.categoryBudget(month, category.id),
          previousSpent: previousSpentByCategory[category.id] ?? 0,
        ),
      )
      .toList(growable: false);
  return snapshots..sort(_compareCategoryBudgetSnapshots);
}

CategoryBudgetSnapshot? _topCategoryBudgetRisk(
  List<CategoryBudgetSnapshot> snapshots,
) {
  for (final snapshot in snapshots) {
    if (snapshot.needsAttention) {
      return snapshot;
    }
  }
  return null;
}

int _compareCategoryBudgetSnapshots(
  CategoryBudgetSnapshot a,
  CategoryBudgetSnapshot b,
) {
  final rankCompare = _categoryBudgetSortRank(
    a,
  ).compareTo(_categoryBudgetSortRank(b));
  if (rankCompare != 0) {
    return rankCompare;
  }
  final ratioCompare = b.ratio.compareTo(a.ratio);
  if (ratioCompare != 0) {
    return ratioCompare;
  }
  final spentCompare = b.spent.compareTo(a.spent);
  if (spentCompare != 0) {
    return spentCompare;
  }
  return a.category.label.compareTo(b.category.label);
}

int _categoryBudgetSortRank(CategoryBudgetSnapshot snapshot) {
  if (snapshot.overBudget) {
    return 0;
  }
  if (snapshot.nearLimit) {
    return 1;
  }
  if (snapshot.hasBudget) {
    return 2;
  }
  if (snapshot.spent > 0) {
    return 3;
  }
  return 4;
}

bool _isInMonth(LedgerEntry entry, DateTime month) {
  return entry.occurredAt.year == month.year &&
      entry.occurredAt.month == month.month;
}

String _expenseDeltaLabel(double delta) {
  if (isZeroAmount(delta)) {
    return '与上月持平';
  }
  if (delta > 0) {
    return '比上月多 ${formatAmount(delta)}';
  }
  return '比上月少 ${formatAmount(delta.abs())}';
}

String _usageDeltaLabel(double delta) {
  final points = (delta.abs() * 100).toStringAsFixed(0);
  if (points == '0') {
    return '持平';
  }
  return delta > 0 ? '增加 $points 个点' : '降低 $points 个点';
}

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
                  onClear: _hasSecondaryFilters
                      ? () {
                          setState(() {
                            _searchController.clear();
                            _query = '';
                            if (widget.accountId == null) {
                              _selectedAccountId = null;
                            }
                            _selectedCategoryId = null;
                          });
                        }
                      : null,
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
                        color: veriIncome,
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
                      onEntryTap: (entry) => _openEntryDetail(context, entry),
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
      _selectedCategoryId != null;

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
    final selected = await _showOptionSheet<TransactionTimeFilter>(
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
    final selected = await _showOptionSheet<TransactionSortOrder>(
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
    final selected = await _showOptionSheet<String>(
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
    final selected = await _showOptionSheet<String>(
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
            : '${_yy(anchor.year)}.Q$quarter';
      case TransactionTimeFilter.month:
        return anchor.year == now.year
            ? '${anchor.month}月'
            : '${_yy(anchor.year)}.${anchor.month.toString().padLeft(2, '0')}';
      case TransactionTimeFilter.week:
        final week = isoWeekNumber(anchor);
        final year = isoWeekYear(anchor);
        return year == now.year ? '$week周' : '$year年$week周';
      case TransactionTimeFilter.last12Months:
      case TransactionTimeFilter.last30Days:
        return '${period.start.month}.${period.start.day}-${period.end.month}.${period.end.day}';
      case TransactionTimeFilter.last6Weeks:
        return '${_yy(isoWeekYear(period.start))}.${isoWeekNumber(period.start).toString().padLeft(2, '0')}-${_yy(isoWeekYear(period.end))}.${isoWeekNumber(period.end).toString().padLeft(2, '0')}';
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
    this.onClear,
  });

  final TextEditingController controller;
  final String accountLabel;
  final String categoryLabel;
  final bool accountLocked;
  final ValueChanged<String> onChanged;
  final VoidCallback? onPickAccount;
  final VoidCallback onPickCategory;
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

Future<T?> _showOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> values,
  required T selected,
  required String Function(T value) labelOf,
  bool showSelectedMarker = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final value in values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: showSelectedMarker && value == selected
                                ? veriRoyal.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(veriRadiusSm),
                            child: ListTile(
                              minTileHeight: 44,
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  veriRadiusSm,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              title: Text(
                                labelOf(value),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight:
                                          showSelectedMarker &&
                                              value == selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                              ),
                              trailing: showSelectedMarker && value == selected
                                  ? const Icon(
                                      Icons.check,
                                      color: veriRoyal,
                                      size: 18,
                                    )
                                  : null,
                              onTap: () => Navigator.of(context).pop(value),
                            ),
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
    },
  );
}

Future<String?> _showAccountIconSheet({
  required BuildContext context,
  required String selected,
}) {
  final choices = <_AccountIconChoice>[
    for (final code in accountIconCodes)
      _AccountIconChoice(
        code: code,
        label: iconLabelForCode(code),
        group: '通用图标',
      ),
    for (final option in accountAssetIconOptions)
      _AccountIconChoice(
        code: option.code,
        label: option.label,
        group: option.group,
      ),
  ];

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.sizeOf(context).height * 0.74;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '选择账户图标',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: choices.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      final choice = choices[index];
                      final isSelected = choice.code == selected;
                      return Material(
                        color: isSelected
                            ? veriRoyal.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(veriRadiusSm),
                        child: ListTile(
                          minTileHeight: 48,
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: AccountIconBox(
                            iconCode: choice.code,
                            size: 34,
                          ),
                          title: Text(
                            choice.label,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                          ),
                          subtitle: Text(choice.group),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: veriRoyal,
                                  size: 18,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(choice.code),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AccountIconChoice {
  const _AccountIconChoice({
    required this.code,
    required this.label,
    required this.group,
  });

  final String code;
  final String label;
  final String group;
}

Future<String?> _showTextInputDialog({
  required BuildContext context,
  required String title,
  required String label,
  String initialValue = '',
  bool allowEmpty = false,
  TextInputType? keyboardType,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('确认'),
        ),
      ],
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  final trimmed = result?.trim();
  if (trimmed == null || (!allowEmpty && trimmed.isEmpty)) {
    return null;
  }
  return trimmed;
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
                    ],
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

  Future<void> _pickType() async {
    final selected = await _showOptionSheet<EntryType>(
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
    final selected = await _showOptionSheet<Account>(
      context: context,
      title: '选择账户',
      values: accounts,
      selected: accountById(accounts, _accountId),
      labelOf: (value) => value.name,
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
    final selected = await _showOptionSheet<Account>(
      context: context,
      title: '选择转入账户',
      values: selectableAccounts,
      selected: accountById(selectableAccounts, _toAccountId ?? ''),
      labelOf: (value) => value.name,
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
    final note = await _showTextInputDialog(
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
      ),
    );
    Navigator.of(context).pop();
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

Future<void> _confirmDeleteAccount(
  BuildContext context,
  Account account,
  List<LedgerEntry> entries,
) async {
  final controller = VeriFinScope.of(context);
  if (entries.isNotEmpty) {
    final shouldHide = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('暂不能删除账户'),
        content: Text('此账户已有 ${entries.length} 笔交易。为避免历史记录失去账户来源，可以先隐藏账户。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('隐藏账户'),
          ),
        ],
      ),
    );
    if (context.mounted && shouldHide == true) {
      controller.updateAccount(account.copyWith(hidden: true));
      Navigator.of(context).pop();
    }
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除此账户？'),
      content: Text('账户「${account.name}」删除后无法恢复。'),
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
  controller.deleteAccount(account.id);
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

List<_DailyStatRow> _dailyStatRows(
  List<LedgerEntry> entries,
  DateTime month,
  double total,
) {
  final rows = <_DailyStatRow>[];
  final days = DateUtils.getDaysInMonth(month.year, month.month);
  for (var day = 1; day <= days; day += 1) {
    final dayEntries = entries
        .where((entry) => entry.occurredAt.day == day)
        .toList();
    if (dayEntries.isEmpty) {
      continue;
    }
    final amount = dayEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    rows.add(
      _DailyStatRow(
        date: DateTime(month.year, month.month, day),
        amount: amount,
        percent: total <= 0 ? 0 : amount / total,
        count: dayEntries.length,
      ),
    );
  }
  return rows..sort((a, b) => b.date.compareTo(a.date));
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

  static const List<_AssetCoverPreset> _coverPresets = <_AssetCoverPreset>[
    _AssetCoverPreset(
      label: '蓝色城市',
      url:
          'https://images.unsplash.com/photo-1480714378408-67cf0d13bc1f?auto=format&fit=crop&w=1200&q=80',
    ),
    _AssetCoverPreset(
      label: '极光夜色',
      url:
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
    ),
    _AssetCoverPreset(
      label: '金融办公',
      url:
          'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1200&q=80',
    ),
    _AssetCoverPreset(
      label: '深蓝渐层',
      url:
          'https://images.unsplash.com/photo-1557682250-33bd709cbe85?auto=format&fit=crop&w=1200&q=80',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final accounts = _sortedAccounts(controller.accounts);
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
    final assetTrendValues = monthlyNetAssetSeries(
      accounts,
      controller.entries,
    );
    final hasAssetCover = controller.assetCoverUrl.isNotEmpty;
    final assetCardTextColor = hasAssetCover
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final assetCardMutedColor = assetCardTextColor.withValues(
      alpha: hasAssetCover ? 0.72 : 0.54,
    );
    final hiddenAccounts = accounts
        .where((account) => account.hidden)
        .toList(growable: false);
    final viewMode = controller.assetAccountViewMode;
    final visibleGroups = <AccountGroup>[
      ...groups,
      AccountGroup(
        id: 'ungrouped',
        bookId: controller.activeBook.id,
        name: '未分组',
        iconCode: 'folder',
        sortOrder: 999,
      ),
    ];
    final assetSections = viewMode == AssetAccountViewMode.group
        ? visibleGroups
              .map(
                (group) => _AssetAccountSection(
                  id: group.id,
                  title: group.name,
                  accounts: controller.sortedAccountsForAssetSection(
                    mode: viewMode,
                    sectionId: group.id,
                    accounts: accounts.where(
                      (account) =>
                          _effectiveGroupId(account) == group.id &&
                          !account.hidden,
                    ),
                  ),
                ),
              )
              .toList()
        : AccountType.values
              .map(
                (type) => _AssetAccountSection(
                  id: type.name,
                  title: type.label,
                  accounts: controller.sortedAccountsForAssetSection(
                    mode: viewMode,
                    sectionId: type.name,
                    accounts: accounts.where(
                      (account) => account.type == type && !account.hidden,
                    ),
                  ),
                ),
              )
              .toList();

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 82),
        children: <Widget>[
          PageHeader(
            title: '资产',
            subtitle: '净资产',
            trailing: HeaderAction(
              icon: Icons.add,
              tooltip: '资产操作',
              onPressed: () => _showAssetActions(context),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('asset_cover_card'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: hasAssetCover
                  ? null
                  : Theme.of(context).brightness == Brightness.dark
                  ? veriSurfaceDark
                  : veriSurfaceLight,
              borderRadius: BorderRadius.circular(veriRadiusMd),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : veriLine,
              ),
              image: !hasAssetCover
                  ? null
                  : DecorationImage(
                      image: NetworkImage(controller.assetCoverUrl),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
              boxShadow: <BoxShadow>[
                if (Theme.of(context).brightness == Brightness.light)
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.045),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                if (hasAssetCover)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.48),
                            veriRoyal.withValues(alpha: 0.50),
                            Colors.black.withValues(alpha: 0.28),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '净资产',
                              style: TextStyle(color: assetCardMutedColor),
                            ),
                          ),
                          IconButton(
                            tooltip: '更换资产卡片背景',
                            onPressed: () =>
                                _changeAssetCover(context, controller),
                            style: IconButton.styleFrom(
                              fixedSize: const Size(32, 32),
                              minimumSize: const Size(32, 32),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              Icons.photo_size_select_actual_outlined,
                              color: assetCardMutedColor,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatAmount(assets + liabilities),
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: assetCardTextColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            '资产 ${formatAmount(assets)}',
                            style: TextStyle(color: assetCardTextColor),
                          ),
                          Text(
                            '负债 ${formatAmount(liabilities.abs())}',
                            style: TextStyle(color: assetCardTextColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 112,
                        child: CustomPaint(
                          painter: TrendLinePainter(
                            color: assetCardTextColor,
                            values: assetTrendValues,
                            xLabels: evenMonthAxisLabels(),
                            labelColor: assetCardMutedColor,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!assetSections.any((section) => section.accounts.isNotEmpty)) ...[
            const VeriCard(
              child: EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: '还没有资产账户',
                description: '请先点击右上角添加资产，之后可以在这里按类型或分组查看资产。',
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final section in assetSections) ...<Widget>[
            if (section.accounts.isNotEmpty) ...<Widget>[
              AccountGroupCard(
                title: section.title,
                accounts: section.accounts,
                balances: balances,
                collapsed: controller.isAssetSectionCollapsed(
                  mode: viewMode,
                  sectionId: section.id,
                ),
                onToggleCollapsed: () => controller.toggleAssetSectionCollapsed(
                  mode: viewMode,
                  sectionId: section.id,
                ),
                onReorderAccounts: (oldIndex, newIndex) =>
                    controller.reorderAssetAccounts(
                      mode: viewMode,
                      sectionId: section.id,
                      accounts: section.accounts,
                      oldIndex: oldIndex,
                      newIndex: newIndex,
                    ),
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
          if (hiddenAccounts.isNotEmpty) ...<Widget>[
            VeriCard(
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const HiddenAccountsPage(),
                  ),
                );
              },
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.42),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${hiddenAccounts.length}个隐藏账户',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.52),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.36),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<void> _changeAssetCover(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final action = await _showOptionSheet<String>(
      context: context,
      title: '资产卡片背景',
      values: const <String>['online', 'custom_url', 'local', 'clear'],
      selected: 'online',
      labelOf: (value) {
        return switch (value) {
          'online' => '使用线上图片',
          'custom_url' => '输入图片链接',
          'local' => '选择本地图片',
          'clear' => '清除背景图片',
          _ => value,
        };
      },
    );
    if (action == null || !context.mounted) {
      return;
    }

    switch (action) {
      case 'online':
        final selected = await _showOptionSheet<_AssetCoverPreset>(
          context: context,
          title: '选择线上图片',
          values: _coverPresets,
          selected: _coverPresets.firstWhere(
            (item) => item.url == controller.assetCoverUrl,
            orElse: () => _coverPresets.first,
          ),
          labelOf: (value) => value.label,
        );
        if (selected != null) {
          controller.setAssetCoverUrl(selected.url);
        }
      case 'custom_url':
        final url = await _showTextInputDialog(
          context: context,
          title: '自定义图片',
          label: '图片链接',
          initialValue: controller.assetCoverUrl.startsWith('http')
              ? controller.assetCoverUrl
              : '',
        );
        if (url != null) {
          controller.setAssetCoverUrl(url);
        }
      case 'local':
        final rawImage = await pickRawImageDataUrl();
        if (rawImage == null || !context.mounted) {
          return;
        }
        final crop = await showImageCropper(
          context: context,
          imageDataUrl: rawImage,
          title: '裁剪资产背景',
          aspectRatio: 1200 / 520,
        );
        if (crop == null) {
          return;
        }
        final dataUrl = await cropImageDataUrl(
          sourceDataUrl: rawImage,
          targetWidth: 1200,
          targetHeight: 520,
          zoom: crop.zoom,
          offsetX: crop.offsetX,
          offsetY: crop.offsetY,
        );
        if (dataUrl != null) {
          controller.setAssetCoverUrl(dataUrl);
        }
      case 'clear':
        controller.setAssetCoverUrl('');
    }
  }

  Future<void> _showAssetActions(BuildContext context) async {
    final controller = VeriFinScope.of(context);
    final selected = await _showOptionSheet<String>(
      context: context,
      title: '资产操作',
      values: const <String>['add_account', 'manage_groups', 'switch_view'],
      selected: 'add_account',
      labelOf: (value) {
        return switch (value) {
          'add_account' => '添加账户',
          'manage_groups' => '管理分组',
          'switch_view' => controller.assetAccountViewMode.toggleLabel,
          _ => value,
        };
      },
    );
    if (selected == null || !context.mounted) {
      return;
    }
    if (selected == 'add_account') {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (context) => const AddAccountPage()),
      );
    }
    if (selected == 'manage_groups') {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const AccountGroupsPage(),
        ),
      );
    }
    if (selected == 'switch_view') {
      controller.toggleAssetAccountViewMode();
    }
  }
}

class _AssetAccountSection {
  const _AssetAccountSection({
    required this.id,
    required this.title,
    required this.accounts,
  });

  final String id;
  final String title;
  final List<Account> accounts;
}

class _AssetCoverPreset {
  const _AssetCoverPreset({required this.label, required this.url});

  final String label;
  final String url;
}

String _effectiveGroupId(Account account) {
  return account.groupId ?? 'ungrouped';
}

List<Account> _sortedAccounts(Iterable<Account> accounts) {
  final sorted = accounts.toList();
  sorted.sort((a, b) {
    final hiddenCompare = (a.hidden ? 1 : 0).compareTo(b.hidden ? 1 : 0);
    if (hiddenCompare != 0) {
      return hiddenCompare;
    }
    final includeCompare = (b.includeInAssets ? 1 : 0).compareTo(
      a.includeInAssets ? 1 : 0,
    );
    if (includeCompare != 0) {
      return includeCompare;
    }
    final typeCompare = a.type.index.compareTo(b.type.index);
    if (typeCompare != 0) {
      return typeCompare;
    }
    return a.name.compareTo(b.name);
  });
  return sorted;
}

class HiddenAccountsPage extends StatelessWidget {
  const HiddenAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final accounts = controller.accounts
        .where((account) => account.hidden)
        .toList(growable: false);
    final balances = <Account, double>{
      for (final account in accounts)
        account: controller.accountBalance(account),
    };

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              const VeriHeader(title: '隐藏账户', showBack: true),
              const SizedBox(height: 10),
              if (accounts.isEmpty)
                const VeriCard(
                  child: EmptyState(
                    icon: Icons.visibility_off_outlined,
                    title: '暂无隐藏账户',
                    description: '隐藏账户会在这里集中展示。',
                  ),
                )
              else
                AccountGroupCard(
                  title: '隐藏账户',
                  accounts: _sortedAccounts(accounts),
                  balances: balances,
                  onAccountTap: (account) {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            AccountDetailPage(account: account),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
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
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: VeriHeader(
                  title: '账户分组',
                  showBack: true,
                  actions: <Widget>[
                    HeaderAction(
                      icon: Icons.add,
                      tooltip: '新增分组',
                      onPressed: () => _showGroupNameDialog(context),
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
                        .where(
                          (account) => _effectiveGroupId(account) == group.id,
                        )
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
    final current = controller.accountGroups
        .where((group) => group.id == groupId)
        .firstOrNull;
    final iconCode = await _showOptionSheet<String>(
      context: context,
      title: '选择分组图标',
      values: accountIconCodes,
      selected: current?.iconCode ?? 'folder',
      labelOf: iconLabelForCode,
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

class _SelectField extends StatelessWidget {
  const _SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusMd),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: const Icon(Icons.keyboard_arrow_down),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _AccountIconSelectField extends StatelessWidget {
  const _AccountIconSelectField({
    super.key,
    required this.iconCode,
    required this.onTap,
  });

  final String iconCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusMd),
        onTap: onTap,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: '账户图标',
            suffixIcon: Icon(Icons.keyboard_arrow_down),
          ),
          child: Row(
            children: <Widget>[
              AccountIconBox(iconCode: iconCode, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  iconLabelForCode(iconCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                VeriHeader(
                  title: '添加账户',
                  showBack: true,
                  actions: <Widget>[
                    HeaderAction(
                      icon: Icons.check,
                      tooltip: '保存账户',
                      onPressed: _save,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SelectField(
                  label: '账户类型',
                  value: _type.label,
                  icon: Icons.category_outlined,
                  onTap: _pickAccountType,
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
                _AccountIconSelectField(
                  key: const Key('account_icon_select_field'),
                  iconCode: _iconCode,
                  onTap: _pickAccountIcon,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '账户备注'),
                ),
                const SizedBox(height: 10),
                _SelectField(
                  label: '账户分组',
                  value: _groupLabel(groups),
                  icon: Icons.folder_outlined,
                  onTap: () => _pickAccountGroup(groups),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAccountType() async {
    final selected = await _showOptionSheet<AccountType>(
      context: context,
      title: '选择账户类型',
      values: AccountType.values,
      selected: _type,
      labelOf: (value) => value.label,
    );
    if (selected != null) {
      setState(() => _type = selected);
    }
  }

  Future<void> _pickAccountIcon() async {
    final selected = await _showAccountIconSheet(
      context: context,
      selected: _iconCode,
    );
    if (selected != null) {
      setState(() => _iconCode = selected);
    }
  }

  Future<void> _pickAccountGroup(List<AccountGroup> groups) async {
    final values = <String>['ungrouped', ...groups.map((group) => group.id)];
    final selected = await _showOptionSheet<String>(
      context: context,
      title: '选择账户分组',
      values: values,
      selected: _groupId,
      labelOf: (value) {
        if (value == 'ungrouped') {
          return '未分组';
        }
        return groups
            .firstWhere(
              (group) => group.id == value,
              orElse: () => const AccountGroup(
                id: 'ungrouped',
                bookId: defaultLedgerBookId,
                name: '未分组',
                iconCode: 'folder',
                sortOrder: 999,
              ),
            )
            .name;
      },
    );
    if (selected != null) {
      setState(() => _groupId = selected);
    }
  }

  String _groupLabel(List<AccountGroup> groups) {
    if (_groupId == 'ungrouped') {
      return '未分组';
    }
    return groups
        .firstWhere(
          (group) => group.id == _groupId,
          orElse: () => const AccountGroup(
            id: 'ungrouped',
            bookId: defaultLedgerBookId,
            name: '未分组',
            iconCode: 'folder',
            sortOrder: 999,
          ),
        )
        .name;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final controller = VeriFinScope.of(context);
    controller.addAccount(
      Account(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bookId: controller.activeBook.id,
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

class AccountDetailPage extends StatefulWidget {
  const AccountDetailPage({super.key, required this.account});

  final Account account;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  bool _monthlyTrend = false;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final currentAccount = controller.accounts.firstWhere(
      (item) => item.id == widget.account.id,
      orElse: () => widget.account,
    );
    final balance = controller.accountBalance(currentAccount);
    final entries = controller.entries
        .where((entry) => entryTouchesAccount(entry, currentAccount.id))
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
              VeriHeader(
                title: currentAccount.name,
                subtitle: currentAccount.type.label,
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.edit_outlined,
                    tooltip: '调整余额',
                    onPressed: () => _editBalance(currentAccount, balance),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                onTap: () => _editBalance(currentAccount, balance),
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
                    VeriIconBox(icon: Icons.edit_outlined, size: 36),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '余额趋势',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _MiniSegmentedToggle(
                          value: _monthlyTrend,
                          leftLabel: '日',
                          rightLabel: '月',
                          onChanged: (value) =>
                              setState(() => _monthlyTrend = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 148,
                      child: CustomPaint(
                        painter: TrendLinePainter(
                          color: veriBlue,
                          values: _monthlyTrend
                              ? accountMonthlyBalanceSeries(
                                  currentAccount,
                                  entries,
                                )
                              : accountBalanceSeries(currentAccount, entries),
                          xLabels: _monthlyTrend
                              ? evenMonthAxisLabels()
                              : monthAxisLabels(DateTime.now()),
                          yLabels: reportAxisLabels(balance.abs()),
                          labelColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.50),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                AccountReportPage(account: currentAccount),
                          ),
                        );
                      },
                      child: const Text('查看报告'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '最近交易',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        VeriSectionAction(
                          icon: Icons.add,
                          tooltip: '记一笔',
                          onPressed: () =>
                              _startEntryForAccount(context, currentAccount),
                        ),
                      ],
                    ),
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
                              categories: controller.categories,
                              onTap: () => _openEntryDetail(context, entry),
                            ),
                          ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (context) => TransactionsPage(
                              accountId: currentAccount.id,
                              title: '${currentAccount.name}交易',
                            ),
                          ),
                        );
                      },
                      child: const Text('所有交易'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    _CompactSwitchRow(
                      icon: Icons.account_balance_wallet_outlined,
                      title: const Text('计入资产'),
                      value: currentAccount.includeInAssets,
                      onChanged: (value) {
                        controller.updateAccount(
                          currentAccount.copyWith(includeInAssets: value),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _CompactSwitchRow(
                      icon: Icons.visibility_off_outlined,
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
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _pickAccountType(currentAccount),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.badge_outlined,
                      title: '名称',
                      trailing: currentAccount.name,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _editAccountName(currentAccount),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.image_outlined,
                      title: '图标',
                      trailing: iconLabelForCode(currentAccount.iconCode),
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _pickAccountIcon(currentAccount),
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
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _editAccountNote(currentAccount),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.folder_outlined,
                      title: '分组',
                      trailing: groupName,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _pickAccountGroup(currentAccount),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.delete_outline,
                      title: '删除账户',
                      trailing: entries.isEmpty ? '可删除' : '已有交易',
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _confirmDeleteAccount(
                        context,
                        currentAccount,
                        entries,
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

  Future<void> _editBalance(Account account, double balance) async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => NumberPadSheet(
        title: '调整余额',
        initialAmount: balance,
        allowNegative: true,
        allowZero: true,
        hapticsEnabled: VeriFinScope.of(context).hapticsEnabled,
      ),
    );
    if (amount == null || !mounted) {
      return;
    }
    VeriFinScope.of(context).adjustAccountBalance(account, amount);
  }

  Future<void> _startEntryForAccount(
    BuildContext context,
    Account account,
  ) async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => NumberPadSheet(
        title: '快速记账',
        hapticsEnabled: VeriFinScope.of(context).hapticsEnabled,
      ),
    );
    if (!context.mounted || amount == null || amount <= 0) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => EntryDetailPage(
          initialAmount: amount,
          initialAccountId: account.id,
        ),
      ),
    );
  }

  Future<void> _pickAccountType(Account account) async {
    final selected = await _showOptionSheet<AccountType>(
      context: context,
      title: '选择账户类型',
      values: AccountType.values,
      selected: account.type,
      labelOf: (value) => value.label,
    );
    if (selected != null && mounted) {
      VeriFinScope.of(context).updateAccount(account.copyWith(type: selected));
    }
  }

  Future<void> _editAccountName(Account account) async {
    final name = await _showTextInputDialog(
      context: context,
      title: '编辑账户名称',
      label: '账户名称',
      initialValue: account.name,
    );
    if (name != null && mounted) {
      VeriFinScope.of(context).updateAccount(account.copyWith(name: name));
    }
  }

  Future<void> _pickAccountIcon(Account account) async {
    final selected = await _showAccountIconSheet(
      context: context,
      selected: account.iconCode,
    );
    if (selected != null && mounted) {
      VeriFinScope.of(
        context,
      ).updateAccount(account.copyWith(iconCode: selected));
    }
  }

  Future<void> _editAccountNote(Account account) async {
    final note = await _showTextInputDialog(
      context: context,
      title: '编辑账户备注',
      label: '备注',
      initialValue: account.note,
      allowEmpty: true,
    );
    if (note != null && mounted) {
      VeriFinScope.of(context).updateAccount(account.copyWith(note: note));
    }
  }

  Future<void> _pickAccountGroup(Account account) async {
    final controller = VeriFinScope.of(context);
    final groups = controller.accountGroups;
    final values = <String>['ungrouped', ...groups.map((group) => group.id)];
    final selected = await _showOptionSheet<String>(
      context: context,
      title: '选择账户分组',
      values: values,
      selected: account.groupId ?? 'ungrouped',
      labelOf: (value) {
        if (value == 'ungrouped') {
          return '未分组';
        }
        return groups.firstWhere((group) => group.id == value).name;
      },
    );
    if (selected != null && mounted) {
      controller.updateAccount(account.copyWith(groupId: selected));
    }
  }
}

class _MiniSegmentedToggle extends StatelessWidget {
  const _MiniSegmentedToggle({
    required this.value,
    required this.leftLabel,
    required this.rightLabel,
    required this.onChanged,
  });

  final bool value;
  final String leftLabel;
  final String rightLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(veriRadiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _MiniSegmentButton(
            label: leftLabel,
            selected: !value,
            onTap: () => onChanged(false),
          ),
          _MiniSegmentButton(
            label: rightLabel,
            selected: value,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _MiniSegmentButton extends StatelessWidget {
  const _MiniSegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.surface
          : Colors.transparent,
      borderRadius: BorderRadius.circular(veriRadiusSm - 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm - 2),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: selected ? 0.88 : 0.48),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSwitchRow extends StatelessWidget {
  const _CompactSwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Widget title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          VeriIconBox(icon: icon, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle.merge(
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              child: title,
            ),
          ),
          Transform.scale(
            scale: 0.82,
            alignment: Alignment.centerRight,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class AccountReportPage extends StatelessWidget {
  const AccountReportPage({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final currentAccount = controller.accounts.firstWhere(
      (item) => item.id == account.id,
      orElse: () => account,
    );
    final entries = controller.entries
        .where((entry) => entryTouchesAccount(entry, currentAccount.id))
        .toList();
    final expense = sumByType(entries, EntryType.expense);
    final income = sumByType(entries, EntryType.income);
    final balance = controller.accountBalance(currentAccount);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: '账户报告',
                subtitle: currentAccount.name,
                showBack: true,
              ),
              const SizedBox(height: 10),
              VeriCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 16,
                ),
                child: Row(
                  children: <Widget>[
                    SummaryMetric(
                      label: '当前余额',
                      value: formatAmount(balance),
                      color: balance < 0 ? veriExpense : veriRoyal,
                    ),
                    SummaryMetric(
                      label: '收入',
                      value: formatAmount(income),
                      color: veriIncome,
                    ),
                    SummaryMetric(
                      label: '支出',
                      value: formatExpenseAmount(expense),
                      color: isZeroAmount(expense)
                          ? Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.48)
                          : veriExpense,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionTitle(title: '余额趋势', trailing: '本月'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 156,
                      child: CustomPaint(
                        painter: TrendLinePainter(
                          color: veriRoyal,
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
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionTitle(title: '最近交易', trailing: null),
                    const SizedBox(height: 6),
                    if (entries.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: '暂无交易',
                        description: '该账户还没有交易记录。',
                      )
                    else
                      ...entries
                          .take(6)
                          .map(
                            (entry) => TransactionTile(
                              entry,
                              accounts: controller.accounts,
                              categories: controller.categories,
                              onTap: () => _openEntryDetail(context, entry),
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
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final entries = controller.entries;
    final now = DateTime.now();
    final monthEntries = entries
        .where((entry) => _isInMonth(entry, now))
        .toList(growable: false);
    final monthExpense = sumByType(monthEntries, EntryType.expense);
    final monthlyBudget = controller.monthlyBudget(now);
    final categoryBudgetSnapshots = _categoryBudgetSnapshots(
      controller: controller,
      month: now,
      monthEntries: monthEntries,
    );
    final expenseEntries = entries
        .where((entry) => entry.type == EntryType.expense)
        .toList(growable: false);
    final expenseTotal = sumByType(entries, EntryType.expense);
    final categoryStats = _categoryStats(expenseEntries, controller.categories);
    final topCategory = categoryStats.firstOrNull;
    final trendWindow = sevenDayWindowFor(DateTime.now());
    final trendValues = valuesForTypeInWindow(
      entries,
      trendWindow,
      EntryType.expense,
    );
    final trendMax = trendValues.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final monthlyValues = monthlyExpenseValues(entries);
    final monthlyMax = monthlyValues.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 82),
        children: <Widget>[
          const PageHeader(title: '看板', subtitle: '数据看板'),
          const SizedBox(height: 10),
          _BudgetExecutionCard(
            budget: monthlyBudget,
            expense: monthExpense,
            snapshots: categoryBudgetSnapshots,
          ),
          const SizedBox(height: 10),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: '分类统计',
                  trailing:
                      '${formatExpenseAmount(expenseTotal)} · ${DateTime.now().month}月 · 支出',
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 360;
                    return _CategoryRingChart(
                      stat: topCategory,
                      total: expenseTotal,
                      ringSize: compact ? 126 : 156,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionTitle(title: '分类明细', trailing: '支出'),
                const SizedBox(height: 8),
                if (categoryStats.isEmpty)
                  const EmptyState(
                    icon: Icons.donut_small_outlined,
                    title: '暂无分类数据',
                    description: '保存支出记录后会在这里显示分类排行。',
                  )
                else
                  ...categoryStats
                      .take(6)
                      .map((stat) => _CategoryStatTile(stat: stat)),
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
                  trailing: formatExpenseAmount(expenseTotal),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 138,
                  child: CustomPaint(
                    painter: TrendLinePainter(
                      color: isZeroAmount(expenseTotal)
                          ? Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.42)
                          : veriExpense,
                      values: trendValues,
                      xLabels: labelsForWindow(trendWindow),
                      yLabels: reportAxisLabels(trendMax),
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
                      values: monthlyValues,
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
                      yLabels: reportAxisLabels(monthlyMax),
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

class _BudgetExecutionCard extends StatelessWidget {
  const _BudgetExecutionCard({
    required this.budget,
    required this.expense,
    required this.snapshots,
  });

  final double budget;
  final double expense;
  final List<CategoryBudgetSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    final ratio = budget <= 0 ? 0.0 : expense / budget;
    final remaining = budget - expense;
    final budgetedCount = snapshots
        .where((snapshot) => snapshot.hasBudget)
        .length;
    final overBudgetCount = snapshots
        .where((snapshot) => snapshot.overBudget)
        .length;
    final color = budget <= 0
        ? veriLine
        : remaining < 0
        ? veriExpense
        : ratio >= 0.85
        ? veriWarning
        : veriRoyal;

    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '预算执行',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${DateTime.now().month}月',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.48),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      budget <= 0
                          ? '未设置预算'
                          : remaining < 0
                          ? '已超预算'
                          : '剩余预算',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.50),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      budget <= 0
                          ? formatExpenseAmount(expense)
                          : remaining < 0
                          ? formatExpenseAmount(remaining.abs())
                          : formatAmount(remaining),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: color, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Text(
                budget <= 0
                    ? '仅记录支出'
                    : '已用 ${(ratio * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.48),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: budget <= 0 ? 0 : ratio.clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _BudgetExecutionMetric(
                  label: '本月预算',
                  value: formatAmount(budget),
                ),
              ),
              Expanded(
                child: _BudgetExecutionMetric(
                  label: '本月支出',
                  value: formatExpenseAmount(expense),
                ),
              ),
              Expanded(
                child: _BudgetExecutionMetric(
                  label: '分类预算',
                  value: '$budgetedCount 个',
                  accent: overBudgetCount > 0 ? '$overBudgetCount 个超支' : '正常',
                  accentColor: overBudgetCount > 0 ? veriExpense : veriIncome,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetExecutionMetric extends StatelessWidget {
  const _BudgetExecutionMetric({
    required this.label,
    required this.value,
    this.accent,
    this.accentColor,
  });

  final String label;
  final String value;
  final String? accent;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.48),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (accent != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            accent!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:
                  accentColor ??
                  Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.44),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryRingChart extends StatelessWidget {
  const _CategoryRingChart({
    required this.stat,
    required this.total,
    required this.ringSize,
  });

  final _CategoryStat? stat;
  final double total;
  final double ringSize;

  @override
  Widget build(BuildContext context) {
    final value = stat == null || total <= 0 ? 0.0 : stat!.amount / total;
    final lineColor = stat == null ? veriRoyal : veriRoyal;
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.56);

    return SizedBox(
      width: double.infinity,
      height: ringSize + 26,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _CategoryCalloutPainter(
                label: stat?.category.label ?? '',
                color: lineColor,
                ringSize: ringSize,
                textColor: mutedColor,
              ),
            ),
          ),
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CustomPaint(
                  painter: BudgetRingPainter(
                    value: value,
                    trackColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.72),
                    progressColor: lineColor,
                  ),
                  child: const SizedBox.expand(),
                ),
                SizedBox(
                  width: ringSize * 0.56,
                  child: Text(
                    formatExpenseAmount(total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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

class _CategoryCalloutPainter extends CustomPainter {
  const _CategoryCalloutPainter({
    required this.label,
    required this.color,
    required this.ringSize,
    required this.textColor,
  });

  final String label;
  final Color color;
  final double ringSize;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (label.isEmpty) {
      return;
    }
    final center = Offset(size.width / 2, size.height / 2);
    final radius = ringSize / 2;
    final angle = -math.pi / 5;
    final start = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final elbow =
        center + Offset(math.cos(angle), math.sin(angle)) * (radius + 12);
    final end = Offset(math.min(size.width - 78, elbow.dx + 38), elbow.dy);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, elbow, paint);
    canvas.drawLine(elbow, end, paint);
    canvas.drawCircle(start, 2.3, Paint()..color = color);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 1,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(42, size.width - end.dx - 8));
    textPainter.paint(canvas, Offset(end.dx + 5, end.dy - textPainter.height));
  }

  @override
  bool shouldRepaint(covariant _CategoryCalloutPainter oldDelegate) {
    return oldDelegate.label != label ||
        oldDelegate.color != color ||
        oldDelegate.ringSize != ringSize ||
        oldDelegate.textColor != textColor;
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
            subtitle: '个人中心',
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
                  const SizedBox(height: 20),
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
            child: Column(
              children: <Widget>[
                SettingsRow(
                  icon: Icons.book_outlined,
                  title: '账本',
                  trailing: controller.activeBook.name,
                  trailingIcon: Icons.chevron_right,
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const LedgerBooksPage(),
                      ),
                    );
                  },
                ),
                const Divider(),
                SettingsRow(
                  icon: Icons.category_outlined,
                  title: '分类管理',
                  trailing: '${controller.categories.length} 个分类',
                  trailingIcon: Icons.chevron_right,
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const CategoryManagementPage(),
                      ),
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

class _CategoryStat {
  const _CategoryStat({
    required this.category,
    required this.amount,
    required this.percent,
    required this.count,
  });

  final Category category;
  final double amount;
  final double percent;
  final int count;
}

class _CategoryStatTile extends StatelessWidget {
  const _CategoryStatTile({required this.stat});

  final _CategoryStat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          VeriIconBox(
            icon: iconForCode(stat.category.iconCode),
            color: veriExpense,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        stat.category.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '-${formatAmount(stat.amount)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: veriExpense,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: stat.percent.clamp(0, 1).toDouble(),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(999),
                  color: veriExpense,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(stat.percent * 100).toStringAsFixed(1)}% · ${stat.count}笔',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.46),
                    fontWeight: FontWeight.w700,
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

class LedgerBooksPage extends StatelessWidget {
  const LedgerBooksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final books = controller.ledgerBooks;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: '账本',
                subtitle: '当前：${controller.activeBook.name}',
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.add,
                    tooltip: '新增账本',
                    onPressed: () => _createBook(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    for (final item in books.indexed) ...<Widget>[
                      _LedgerBookRow(book: item.$2),
                      if (item.$1 != books.length - 1) const Divider(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createBook(BuildContext context) async {
    final name = await _showTextInputDialog(
      context: context,
      title: '新增账本',
      label: '账本名称',
    );
    if (!context.mounted || name == null) {
      return;
    }
    VeriFinScope.of(context).addLedgerBook(name);
  }
}

class _LedgerBookRow extends StatelessWidget {
  const _LedgerBookRow({required this.book});

  final LedgerBook book;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final selected = controller.activeBook.id == book.id;
    final entryCount = controller.entryCountForBook(book.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: () => controller.switchLedgerBook(book.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              VeriIconBox(
                icon: book.isDefault ? Icons.book : Icons.book_outlined,
                color: selected
                    ? veriRoyal
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      book.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${book.isDefault ? '默认账本 · ' : ''}$entryCount 笔交易',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.48),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: veriRoyal, size: 18),
              PopupMenuButton<String>(
                tooltip: '账本操作',
                onSelected: (value) {
                  if (value == 'rename') {
                    _renameBook(context);
                  }
                  if (value == 'delete') {
                    _deleteBook(context);
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'rename',
                    child: Text('重命名'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    enabled: !book.isDefault,
                    child: Text(book.isDefault ? '默认账本不可删除' : '删除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameBook(BuildContext context) async {
    final name = await _showTextInputDialog(
      context: context,
      title: '重命名账本',
      label: '账本名称',
      initialValue: book.name,
    );
    if (!context.mounted || name == null) {
      return;
    }
    VeriFinScope.of(context).renameLedgerBook(book.id, name);
  }

  Future<void> _deleteBook(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账本？'),
        content: Text('账本「${book.name}」及其中交易会被删除，此操作无法恢复。'),
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
    VeriFinScope.of(context).deleteLedgerBook(book.id);
  }
}

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  EntryType _type = EntryType.expense;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final categories = controller.categoriesForType(_type);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: '分类管理',
                subtitle: '用于记账和统计',
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.add,
                    tooltip: '新增分类',
                    onPressed: _createCategory,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<EntryType>(
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
                  setState(() => _type = selection.first);
                },
              ),
              const SizedBox(height: 10),
              VeriCard(
                padding: EdgeInsets.zero,
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: categories.length,
                  onReorderItem: (oldIndex, newIndex) {
                    controller.reorderCategories(_type, oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _CategoryManageRow(
                      key: ValueKey(category.id),
                      index: index,
                      category: category,
                      usageCount: controller.categoryUsageCount(category.id),
                      onTap: () => _showCategoryActions(category),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createCategory() async {
    final label = await _showTextInputDialog(
      context: context,
      title: '新增${_type.label}分类',
      label: '分类名称',
    );
    if (!mounted || label == null) {
      return;
    }
    final iconCode = await _pickCategoryIcon(selected: 'category');
    if (!mounted || iconCode == null) {
      return;
    }
    VeriFinScope.of(
      context,
    ).addCategory(type: _type, label: label, iconCode: iconCode);
  }

  Future<void> _showCategoryActions(Category category) async {
    final selected = await _showOptionSheet<String>(
      context: context,
      title: category.label,
      values: const <String>['rename', 'icon', 'delete'],
      selected: 'rename',
      showSelectedMarker: false,
      labelOf: (value) => switch (value) {
        'rename' => '重命名',
        'icon' => '更换图标',
        'delete' => '删除分类',
        _ => value,
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    switch (selected) {
      case 'rename':
        await _renameCategory(category);
      case 'icon':
        await _changeCategoryIcon(category);
      case 'delete':
        await _deleteCategory(category);
    }
  }

  Future<void> _renameCategory(Category category) async {
    final label = await _showTextInputDialog(
      context: context,
      title: '重命名分类',
      label: '分类名称',
      initialValue: category.label,
    );
    if (!mounted || label == null) {
      return;
    }
    VeriFinScope.of(context).renameCategory(category.id, label);
  }

  Future<void> _changeCategoryIcon(Category category) async {
    final iconCode = await _pickCategoryIcon(selected: category.iconCode);
    if (!mounted || iconCode == null) {
      return;
    }
    VeriFinScope.of(context).updateCategoryIcon(category.id, iconCode);
  }

  Future<String?> _pickCategoryIcon({required String selected}) {
    return _showOptionSheet<String>(
      context: context,
      title: '选择图标',
      values: categoryIconCodes,
      selected: selected,
      labelOf: iconLabelForCode,
    );
  }

  Future<void> _deleteCategory(Category category) async {
    final controller = VeriFinScope.of(context);
    if (_isProtectedCategory(category.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('系统分类不能删除')));
      return;
    }
    final usageCount = controller.categoryUsageCount(category.id);
    if (usageCount > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已有 $usageCount 笔交易使用该分类，不能删除')));
      return;
    }
    if (controller.categoriesForType(category.type).length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('至少需要保留一个分类')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类？'),
        content: Text('分类「${category.label}」删除后无法恢复。'),
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
    if (!mounted || confirmed != true) {
      return;
    }
    final deleted = controller.deleteCategory(category.id);
    if (!deleted && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该分类暂时不能删除')));
    }
  }
}

bool _isProtectedCategory(String categoryId) {
  return categoryId == 'balance_adjust_expense' ||
      categoryId == 'balance_adjust_income';
}

class _CategoryManageRow extends StatelessWidget {
  const _CategoryManageRow({
    super.key,
    required this.index,
    required this.category,
    required this.usageCount,
    required this.onTap,
  });

  final int index;
  final Category category;
  final int usageCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: <Widget>[
              VeriIconBox(icon: iconForCode(category.iconCode), size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      category.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${category.type.label} · $usageCount 笔交易',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.48),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_handle,
                    size: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ],
          ),
        ),
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
              VeriHeader(
                title: '个人信息',
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.check,
                    tooltip: '保存',
                    onPressed: _save,
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
    final rawImage = await pickRawImageDataUrl();
    if (rawImage == null || !mounted) {
      return;
    }
    final crop = await showImageCropper(
      context: context,
      imageDataUrl: rawImage,
      title: '裁剪头像',
      aspectRatio: 1,
      circlePreview: true,
    );
    if (crop == null) {
      return;
    }
    final avatar = await cropImageDataUrl(
      sourceDataUrl: rawImage,
      targetWidth: 512,
      targetHeight: 512,
      zoom: crop.zoom,
      offsetX: crop.offsetX,
      offsetY: crop.offsetY,
    );
    if (avatar != null && mounted) {
      setState(() => _avatarDataUrl = avatar);
    }
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
              const VeriHeader(title: '设置', showBack: true),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.dark_mode_outlined,
                      title: '主题模式',
                      trailing: controller.themePreference.label,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _pickThemePreference(context, controller),
                    ),
                    const Divider(height: 1),
                    _CompactSwitchRow(
                      icon: Icons.touch_app_outlined,
                      title: const Text('触感反馈'),
                      value: controller.hapticsEnabled,
                      onChanged: controller.setHapticsEnabled,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.download_outlined,
                      title: '导出数据',
                      trailing: 'JSON 备份',
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _exportData(context, controller),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.upload_file_outlined,
                      title: '导入数据',
                      trailing: '从文件恢复',
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _confirmImport(context, controller),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.system_update_alt_outlined,
                      title: '检查更新',
                      trailing: 'GitHub Release',
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _checkForUpdate(context),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.restart_alt,
                      title: '初始化数据',
                      trailing: '删除所有本地数据',
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _confirmReset(context, controller),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'VeriFin $appVersionLabel',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickThemePreference(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final selected = await _showOptionSheet<ThemePreference>(
      context: context,
      title: '选择主题模式',
      values: ThemePreference.values,
      selected: controller.themePreference,
      labelOf: (value) => value.label,
    );
    if (selected != null) {
      controller.setThemePreference(selected);
    }
  }

  Future<void> _exportData(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    try {
      await downloadTextFile(
        filename: 'verifin-backup-$date.json',
        content: controller.exportDataJson(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已导出本地数据备份')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('导出失败，请稍后再试')));
      }
    }
  }

  Future<void> _confirmImport(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入本地备份？'),
        content: const Text('导入会替换当前本地交易、账户、账本、预算、个人信息和设置。建议先导出当前数据。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('选择文件'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      final content = await pickTextFile();
      if (content == null) {
        return;
      }
      if (content.trim().isEmpty) {
        throw const FormatException('空备份文件');
      }
      controller.importDataJson(content);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已导入本地数据')));
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('导入失败：备份文件格式不正确')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('导入失败，请检查文件后重试')));
      }
    }
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在检查 GitHub Release...')),
    );
    final result = await AppPlatformBridge.checkForUpdate();
    if (!context.mounted) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _confirmReset(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('初始化所有数据？'),
        content: const Text('这会删除本地交易、账户、账本、预算、个人信息和主题偏好，操作无法恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('初始化'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.resetAllData();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                children: <Widget>[
                  const VeriHeader(
                    title: '日常账本',
                    subtitle: '记账详情',
                    showBack: true,
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
                        label: const Text('全部'),
                        onPressed: _showAllCategories,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (hasAccounts && _type == EntryType.transfer) ...<Widget>[
                    _SelectField(
                      key: const Key('account_dropdown'),
                      label: '转出账户',
                      value:
                          '${accountById(accounts, _accountId).name} (${formatAmount(controller.accountBalance(accountById(accounts, _accountId)))})',
                      icon: Icons.call_made,
                      onTap: () => _pickAccount(accounts),
                    ),
                    const SizedBox(height: 10),
                    _SelectField(
                      key: const Key('to_account_dropdown'),
                      label: '转入账户',
                      value: _toAccountId == null
                          ? '请选择'
                          : '${accountById(accounts, _toAccountId!).name} (${formatAmount(controller.accountBalance(accountById(accounts, _toAccountId!)))})',
                      icon: Icons.call_received,
                      onTap: accounts.length < 2
                          ? null
                          : () => _pickToAccount(accounts),
                    ),
                  ] else if (hasAccounts)
                    _SelectField(
                      key: const Key('account_dropdown'),
                      label: '账户',
                      value:
                          '${accountById(accounts, _accountId).name} (${formatAmount(controller.accountBalance(accountById(accounts, _accountId)))})',
                      icon: Icons.wallet,
                      onTap: () => _pickAccount(accounts),
                    )
                  else
                    const EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: '没有可用账户',
                      description: '请先在资产页添加或取消隐藏一个账户。',
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
                      if (hasAccounts)
                        Chip(
                          avatar: AccountIconBox(
                            iconCode: accountById(
                              accounts,
                              _accountId,
                            ).iconCode,
                            size: 22,
                          ),
                          label: Text(accountById(accounts, _accountId).name),
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
                  onPressed: _canSave(accounts) ? _save : null,
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
      builder: (context) => NumberPadSheet(
        title: '修改金额',
        initialAmount: _amount,
        hapticsEnabled: VeriFinScope.of(context).hapticsEnabled,
      ),
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
    final selected = await _showOptionSheet<Account>(
      context: context,
      title: '选择账户',
      values: accounts,
      selected: accountById(accounts, _accountId),
      labelOf: (value) => value.name,
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
    final selected = await _showOptionSheet<Account>(
      context: context,
      title: '选择转入账户',
      values: selectableAccounts,
      selected: accountById(selectableAccounts, _toAccountId ?? ''),
      labelOf: (value) => value.name,
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

  void _save() {
    final controller = VeriFinScope.of(context);
    if (!controller.accounts
        .where((account) => !account.hidden)
        .any((account) => account.id == _accountId)) {
      return;
    }
    controller.addEntry(
      LedgerEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bookId: controller.activeBook.id,
        type: _type,
        amount: _amount,
        categoryId: _categoryId,
        accountId: _accountId,
        toAccountId: _type == EntryType.transfer ? _toAccountId : null,
        note: _noteController.text.trim(),
        occurredAt: _occurredAt,
      ),
    );
    Navigator.of(context).pop();
  }
}

List<_CategoryStat> _categoryStats(
  List<LedgerEntry> entries,
  List<Category> categories,
) {
  final totals = <String, double>{};
  final counts = <String, int>{};
  for (final entry in entries) {
    totals.update(
      entry.categoryId,
      (value) => value + entry.amount,
      ifAbsent: () => entry.amount,
    );
    counts.update(entry.categoryId, (value) => value + 1, ifAbsent: () => 1);
  }

  final total = totals.values.fold<double>(0, (sum, value) => sum + value);
  final stats =
      totals.entries
          .map(
            (entry) => _CategoryStat(
              category: categoryById(entry.key, categories),
              amount: entry.value,
              percent: total <= 0 ? 0 : entry.value / total,
              count: counts[entry.key] ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
  return stats;
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
  return <String>['0', _formatAxisAmount(top / 2), _formatAxisAmount(top)];
}

String _formatAxisAmount(num value) {
  final abs = value.abs();
  if (abs >= 10000) {
    final compact = value / 10000;
    final decimals = compact.abs() >= 10 || compact % 1 == 0 ? 0 : 1;
    return '${compact.toStringAsFixed(decimals)}w';
  }
  return formatAmount(value);
}

String _yy(int year) => (year % 100).toString().padLeft(2, '0');

int isoWeekYear(DateTime date) {
  return date.add(Duration(days: 4 - date.weekday)).year;
}

int isoWeekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final weekOne = firstThursday.add(Duration(days: 4 - firstThursday.weekday));
  return thursday.difference(weekOne).inDays ~/ 7 + 1;
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
    runningBalance += accountDeltaForEntry(entry, account.id);
    values[entry.occurredAt.day - 1] = runningBalance.abs();
  }

  for (var i = 1; i < values.length; i += 1) {
    if (values[i] == account.initialBalance.abs()) {
      values[i] = values[i - 1];
    }
  }
  return values;
}

List<double> accountMonthlyBalanceSeries(
  Account account,
  List<LedgerEntry> entries,
) {
  final now = DateTime.now();
  var runningBalance = account.initialBalance;
  final values = List<double>.filled(12, account.initialBalance.abs());
  final sortedEntries = List<LedgerEntry>.from(entries)
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  for (var month = 1; month <= 12; month += 1) {
    for (final entry in sortedEntries) {
      if (entry.occurredAt.year != now.year ||
          entry.occurredAt.month != month) {
        continue;
      }
      runningBalance += accountDeltaForEntry(entry, account.id);
    }
    values[month - 1] = runningBalance.abs();
  }
  return values;
}

List<double> monthlyNetAssetSeries(
  List<Account> accounts,
  List<LedgerEntry> entries,
) {
  if (accounts.isEmpty) {
    return List<double>.filled(12, 0);
  }
  final now = DateTime.now();
  final visibleAccounts = accounts
      .where((account) => account.includeInAssets && !account.hidden)
      .toList();
  if (visibleAccounts.isEmpty) {
    return List<double>.filled(12, 0);
  }
  return List<double>.generate(12, (index) {
    final month = index + 1;
    var total = 0.0;
    for (final account in visibleAccounts) {
      var balance = account.initialBalance;
      for (final entry in entries.where((entry) {
        return entryTouchesAccount(entry, account.id) &&
            entry.occurredAt.year == now.year &&
            entry.occurredAt.month <= month;
      })) {
        balance += accountDeltaForEntry(entry, account.id);
      }
      total += balance;
    }
    return total.abs();
  });
}

List<String> evenMonthAxisLabels() {
  return const <String>['2', '4', '6', '8', '10', '12'];
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
