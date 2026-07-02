import 'package:flutter/material.dart';

import 'app/app_theme.dart';
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: '资产',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: '看板',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
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
    final todayEntries = entries
        .where(
          (entry) =>
              entry.occurredAt.year == now.year &&
              entry.occurredAt.month == now.month &&
              entry.occurredAt.day == now.day,
        )
        .toList();

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        children: <Widget>[
          PageHeader(
            title: '日常账本',
            trailing: IconButton(
              tooltip: '搜索',
              onPressed: () {},
              icon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${now.month}月支出',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '-${formatAmount(monthExpense)}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: const Color(0xFFE84D6A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('收入 ${formatAmount(monthIncome)}'),
                const SizedBox(height: 18),
                SizedBox(
                  height: 120,
                  child: CustomPaint(
                    painter: TrendLinePainter(
                      color: const Color(0xFFE84D6A),
                      values: dailyExpenseValues(monthEntries, now),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: '今日交易',
                  trailing: todayEntries.isEmpty
                      ? '暂无'
                      : formatSignedAmount(
                          todayEntries.fold<double>(
                            0,
                            (sum, entry) => sum + signedAmount(entry),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                if (todayEntries.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: '还没有交易',
                    description: '点击右下角加号开始第一笔记账。',
                  )
                else
                  ...todayEntries.take(5).map(TransactionTile.new),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VeriCard(
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CircularProgressIndicator(
                        value: (monthExpense / 800).clamp(0, 1),
                        strokeWidth: 12,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        color: veriRoyal,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            formatAmount((800 - monthExpense).clamp(0, 800)),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Text('预算剩余'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${now.month}月预算',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('已支出 ${formatAmount(monthExpense)}'),
                      Text('预算 800'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CalendarPreview(entries: monthEntries),
        ],
      ),
    );
  }
}

class AssetsPage extends StatelessWidget {
  const AssetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final balances = <Account, double>{
      for (final account in demoAccounts)
        account: controller.accountBalance(account),
    };
    final assets = balances.values
        .where((value) => value > 0)
        .fold<double>(0, (sum, value) => sum + value);
    final liabilities = balances.values
        .where((value) => value < 0)
        .fold<double>(0, (sum, value) => sum + value);

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        children: <Widget>[
          PageHeader(
            title: '净资产',
            trailing: IconButton(
              tooltip: '新增账户',
              onPressed: () {},
              icon: const Icon(Icons.add),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[veriBlue, veriRoyal, veriIndigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('净资产', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text(
                  formatAmount(assets + liabilities),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
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
          const SizedBox(height: 16),
          AccountGroupCard(
            title: '网络支付',
            accounts: demoAccounts
                .where((account) => account.group == '网络支付')
                .toList(),
            balances: balances,
          ),
          const SizedBox(height: 16),
          AccountGroupCard(
            title: '信用账户',
            accounts: demoAccounts
                .where((account) => account.group == '信用账户')
                .toList(),
            balances: balances,
          ),
        ],
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        children: <Widget>[
          const PageHeader(title: '数据看板'),
          const SizedBox(height: 16),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionTitle(title: '分类统计', trailing: '支出'),
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        CircularProgressIndicator(
                          value: expenseTotal > 0 ? 1 : 0,
                          strokeWidth: 28,
                          color: veriBlue,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(topCategory),
                            Text('-${formatAmount(expenseTotal)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: '日趋势',
                  trailing: '-${formatAmount(expenseTotal)}',
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 150,
                  child: CustomPaint(
                    painter: TrendLinePainter(
                      color: const Color(0xFFE84D6A),
                      values: dailyExpenseValues(entries, DateTime.now()),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionTitle(title: '月度收支', trailing: '今年'),
                const SizedBox(height: 18),
                SizedBox(
                  height: 160,
                  child: CustomPaint(
                    painter: BarChartPainter(
                      values: monthlyExpenseValues(entries),
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

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        children: <Widget>[
          const PageHeader(title: '我的'),
          const SizedBox(height: 16),
          VeriCard(
            child: Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: veriRoyal,
                  child: Text(
                    'VF',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Veri Fin',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      const Text('完全免费 · 数据自主'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('主题模式', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          VeriCard(
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 18,
              crossAxisSpacing: 12,
              children: const <Widget>[
                ToolEntry(icon: Icons.category, label: '分类'),
                ToolEntry(icon: Icons.book, label: '账本'),
                ToolEntry(icon: Icons.file_download_outlined, label: '导入'),
                ToolEntry(icon: Icons.file_upload_outlined, label: '导出'),
                ToolEntry(icon: Icons.security, label: '安全'),
                ToolEntry(icon: Icons.notifications_none, label: '提醒'),
                ToolEntry(icon: Icons.menu_book_outlined, label: '手册'),
                ToolEntry(icon: Icons.share_outlined, label: '分享'),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                  trailing: '未启用',
                ),
              ],
            ),
          ),
        ],
      ),
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
  String _accountId = demoAccounts.first.id;
  DateTime _occurredAt = DateTime.now();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = categoriesFor(_type);
    final selectedAccount = demoAccounts.firstWhere(
      (account) => account.id == _accountId,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: '返回',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '日常账本',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Icon(Icons.keyboard_arrow_down),
                      const Spacer(),
                      TextButton(onPressed: () {}, child: const Text('设置')),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 24),
                  InkWell(
                    key: const Key('detail_amount_button'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: _editAmount,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                  const Divider(height: 32),
                  Text('分类', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
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
                  const SizedBox(height: 24),
                  Text('账户', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: const Key('account_dropdown'),
                    initialValue: _accountId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.wallet),
                    ),
                    items: demoAccounts
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
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
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
                        avatar: Icon(selectedAccount.icon, size: 18),
                        label: Text(selectedAccount.name),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
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
