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
        key: const Key('main_bottom_nav'),
        currentIndex: _index,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (value) => setState(() => _index = value),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '',
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 88),
        children: <Widget>[
          PageHeader(
            title: '日常账本',
            trailing: IconButton(
              tooltip: '搜索',
              onPressed: () {},
              icon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                SizedBox(
                  height: 118,
                  child: CustomPaint(
                    painter: TrendLinePainter(
                      color: const Color(0xFFE84D6A),
                      values: dailyExpenseValues(monthEntries, now),
                      xLabels: monthAxisLabels(now),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                  ...todayEntries
                      .take(5)
                      .map(
                        (entry) => TransactionTile(
                          entry,
                          accounts: controller.accounts,
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          VeriCard(
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 104,
                  height: 104,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CircularProgressIndicator(
                        value: (monthExpense / 800).clamp(0, 1),
                        strokeWidth: 8,
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '预算剩余',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
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
          const SizedBox(height: 12),
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 88),
        children: <Widget>[
          PageHeader(
            title: '净资产',
            trailing: PopupMenuButton<String>(
              tooltip: '资产操作',
              icon: const Icon(Icons.add),
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
          const SizedBox(height: 12),
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
              const SizedBox(height: 16),
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
                        style: Theme.of(context).textTheme.headlineSmall,
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onLongPress: () =>
                            setState(() => _selectedGroupId = group.id),
                        onTap: () => setState(() {
                          _selectedGroupId = selected ? null : group.id;
                        }),
                        child: VeriCard(
                          child: Row(
                            children: <Widget>[
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: veriBlue.withValues(
                                  alpha: 0.16,
                                ),
                                child: Icon(
                                  iconForCode(group.iconCode),
                                  color: veriBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
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
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('${groupAccounts.length}个账户'),
                                    ),
                                  ],
                                ),
                              ),
                              Text(formatAmount(total)),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: '保存账户',
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '账户备注'),
                ),
                const SizedBox(height: 12),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                      style: Theme.of(context).textTheme.headlineSmall,
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
              const SizedBox(height: 12),
              VeriCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('当前余额'),
                          const SizedBox(height: 10),
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
                    Icon(iconForCode(currentAccount.iconCode), color: veriBlue),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionTitle(title: '余额趋势', trailing: '日'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 148,
                      child: CustomPaint(
                        painter: TrendLinePainter(
                          color: veriBlue,
                          values: accountBalanceSeries(currentAccount, entries),
                          xLabels: monthAxisLabels(DateTime.now()),
                          yLabels: reportAxisLabels(balance.abs()),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    TextButton(onPressed: () {}, child: const Text('查看报告')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionTitle(title: '最近交易', trailing: '+'),
                    const SizedBox(height: 8),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        children: <Widget>[
          const PageHeader(title: '数据看板'),
          const SizedBox(height: 16),
          VeriCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  title: '分类统计',
                  trailing:
                      '-${formatAmount(expenseTotal)} · ${DateTime.now().month}月 · 支出',
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 168,
                      height: 168,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          CircularProgressIndicator(
                            value: expenseTotal > 0 ? 1 : 0,
                            strokeWidth: 24,
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
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
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
                          const SizedBox(height: 10),
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
          const SizedBox(height: 12),
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
                      xLabels: monthAxisLabels(DateTime.now()),
                      yLabels: reportAxisLabels(expenseTotal),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
