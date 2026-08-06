part of 'budget_pages.dart';

/// 预算设置页（真·设置）：集中配置**默认预算**与周期口径——
/// 默认月预算（每月自动沿用）、按日预算上限、预算周期起始日，以及**分类默认预算**树。
/// 单期临时调整由总览页对应的总预算状态 chip / 分类行进入。
class BudgetSettingsPage extends StatefulWidget {
  const BudgetSettingsPage({super.key});

  @override
  State<BudgetSettingsPage> createState() => _BudgetSettingsPageState();
}

class _BudgetSettingsPageState extends State<BudgetSettingsPage> {
  // 收起的父分类 id（默认折叠：首次构建时把所有含子类的分类加入）。
  final Set<String> _collapsedCategories = <String>{};
  bool _collapseInitialized = false;
  bool _draftInitialized = false;
  late double _initialDefaultBudget;
  late double _draftDefaultBudget;
  late double _initialDailyBudget;
  late double _draftDailyBudget;
  late int _initialStartDay;
  late int _draftStartDay;
  final Map<String, double> _initialCategoryBudgets = <String, double>{};
  final Map<String, double> _draftCategoryBudgets = <String, double>{};

  void _initCollapse(VeriFinController controller) {
    if (_collapseInitialized) {
      return;
    }
    _collapseInitialized = true;
    for (final category in controller.categoriesForType(EntryType.expense)) {
      if (controller.childCategories(category.id).isNotEmpty) {
        _collapsedCategories.add(category.id);
      }
    }
  }

  void _initDraft(VeriFinController controller) {
    if (_draftInitialized) {
      return;
    }
    _draftInitialized = true;
    _initialDefaultBudget = _draftDefaultBudget =
        controller.defaultMonthlyBudget;
    _initialDailyBudget = _draftDailyBudget = controller.dailyBudget();
    _initialStartDay = _draftStartDay = controller.budgetCycleStartDay;
    for (final category in controller.categoriesForType(EntryType.expense)) {
      final amount = controller.defaultCategoryBudget(category.id);
      _initialCategoryBudgets[category.id] = amount;
      _draftCategoryBudgets[category.id] = amount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    _initCollapse(controller);
    _initDraft(controller);

    // 分类默认预算树展示「当前周期实际花销 vs 默认预算」，spent 只作参考。
    final now = DateTime.now();
    final keyMonth = budgetCycleKeyMonthFor(now, _draftStartDay);
    final periodEntries = entriesInWindow(
      controller.entries,
      budgetCycleOfKeyMonth(keyMonth, _draftStartDay),
    );
    final persistedCategorySnapshots = computeCategoryBudgetSnapshots(
      controller: controller,
      month: keyMonth,
      monthEntries: periodEntries,
      useDefaultBudget: true,
    );
    final categorySnapshots = persistedCategorySnapshots
        .map(
          (snapshot) => CategoryBudgetSnapshot(
            category: snapshot.category,
            spent: snapshot.spent,
            budget: _draftCategoryBudgets[snapshot.category.id] ?? 0,
            previousSpent: snapshot.previousSpent,
          ),
        )
        .toList();

    final defaultBudget = _draftDefaultBudget;
    final dailyBudget = _draftDailyBudget;
    final startDay = _draftStartDay;

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: l10n.budgetSettingsTitle,
                  subtitle: controller.activeBook.name,
                  showBack: true,
                  actions: <Widget>[
                    SaveHeaderAction(onPressed: _isDirty ? _saveAndExit : null),
                  ],
                ),
                const SizedBox(height: 10),
                _sectionLabel(context, l10n.budgetSettingsSectionOverall),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      SettingsRow(
                        icon: Icons.flag_outlined,
                        title: l10n.defaultMonthlyBudgetTitle,
                        trailing: defaultBudget > 0
                            ? formatAmount(defaultBudget)
                            : l10n.budgetCycleNotSet,
                        trailingIcon: Icons.chevron_right,
                        onTap: _editDefaultMonthlyBudget,
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.today_outlined,
                        title: l10n.dailyBudgetTitle,
                        trailing: dailyBudget > 0
                            ? formatAmount(dailyBudget)
                            : l10n.budgetCycleNotSet,
                        trailingIcon: Icons.chevron_right,
                        onTap: _editDailyBudget,
                      ),
                      const Divider(height: 1),
                      SettingsRow(
                        icon: Icons.event_repeat_outlined,
                        title: l10n.budgetCycleStartDayTitle,
                        trailing: startDay == naturalMonthStartDay
                            ? l10n.budgetCycleNaturalMonth
                            : l10n.budgetCycleStartDayOption(startDay),
                        trailingIcon: Icons.chevron_right,
                        onTap: _editCycleStartDay,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionLabel(context, l10n.budgetSettingsSectionCategory),
                VeriCard(
                  padding: const EdgeInsets.fromLTRB(13, 6, 13, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 6, 0, 2),
                        child: Text(
                          l10n.defaultCategoryBudgetDesc,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.52),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (categorySnapshots.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              l10n.noExpenseCategories,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.48),
                                  ),
                            ),
                          ),
                        )
                      else
                        ..._buildCategoryDefaultTree(
                          controller,
                          <String, CategoryBudgetSnapshot>{
                            for (final snapshot in categorySnapshots)
                              snapshot.category.id: snapshot,
                          },
                          controller.rootCategoriesForType(EntryType.expense),
                          0,
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

  /// 可编辑的分类默认预算树（结构同总览只读树，但每行点击设「默认预算」）。
  List<Widget> _buildCategoryDefaultTree(
    VeriFinController controller,
    Map<String, CategoryBudgetSnapshot> byId,
    List<Category> siblings,
    int depth,
  ) {
    final rows = <Widget>[];
    for (final category in siblings) {
      final snapshot = byId[category.id];
      if (snapshot == null) {
        continue;
      }
      final children = controller.childCategories(category.id);
      final collapsed = _collapsedCategories.contains(category.id);
      rows.add(
        _CategoryBudgetRow(
          snapshot: snapshot,
          depth: depth,
          childCount: children.length,
          collapsed: collapsed,
          onToggle: children.isEmpty
              ? null
              : () => setState(() {
                  if (collapsed) {
                    _collapsedCategories.remove(category.id);
                  } else {
                    _collapsedCategories.add(category.id);
                  }
                }),
          onTap: () => _editDefaultCategoryBudget(category),
        ),
      );
      if (children.isNotEmpty && !collapsed) {
        rows.addAll(
          _buildCategoryDefaultTree(controller, byId, children, depth + 1),
        );
      }
    }
    return rows;
  }

  /// 预算金额输入统一走数字键盘（与记账一致，支持算式）；允许 0（清除该预算）。
  Future<double?> _promptBudgetAmount(String title, double current) {
    return showNumberPadSheet(
      context,
      title: title,
      initialAmount: current > 0 ? current : null,
      allowZero: true,
    );
  }

  Future<void> _editDefaultMonthlyBudget() async {
    final amount = await _promptBudgetAmount(
      AppLocalizations.of(context).setDefaultMonthlyBudgetTitle,
      _draftDefaultBudget,
    );
    if (amount == null || !mounted) {
      return;
    }
    setState(() => _draftDefaultBudget = amount);
  }

  Future<void> _editDailyBudget() async {
    final amount = await _promptBudgetAmount(
      AppLocalizations.of(context).setDailyBudgetTitle,
      _draftDailyBudget,
    );
    if (amount == null || !mounted) {
      return;
    }
    setState(() => _draftDailyBudget = amount);
  }

  /// 选择预算周期起始日（1–28，账本级）。改起始日只是换周期口径，各键月已存
  /// 的预算金额不动。
  Future<void> _editCycleStartDay() async {
    final l10n = AppLocalizations.of(context);
    final selected = await showOptionSheet<int>(
      context: context,
      title: l10n.budgetCycleStartDayTitle,
      values: <int>[
        for (
          var day = budgetCycleStartDayMin;
          day <= budgetCycleStartDayMax;
          day++
        )
          day,
      ],
      selected: _draftStartDay,
      labelOf: (day) => day == naturalMonthStartDay
          ? l10n.budgetCycleNaturalMonth
          : l10n.budgetCycleStartDayOption(day),
    );
    if (selected != null && mounted) {
      setState(() => _draftStartDay = selected);
    }
  }

  Future<void> _editDefaultCategoryBudget(Category category) async {
    final amount = await _promptBudgetAmount(
      AppLocalizations.of(
        context,
      ).setDefaultCategoryBudgetTitle(category.label),
      _draftCategoryBudgets[category.id] ?? 0,
    );
    if (amount == null || !mounted) {
      return;
    }
    setState(() => _draftCategoryBudgets[category.id] = amount);
  }

  bool get _isDirty {
    if (_draftDefaultBudget != _initialDefaultBudget ||
        _draftDailyBudget != _initialDailyBudget ||
        _draftStartDay != _initialStartDay ||
        _draftCategoryBudgets.length != _initialCategoryBudgets.length) {
      return true;
    }
    for (final entry in _draftCategoryBudgets.entries) {
      if (_initialCategoryBudgets[entry.key] != entry.value) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(() {
        _initialDefaultBudget = _draftDefaultBudget;
        _initialDailyBudget = _draftDailyBudget;
        _initialStartDay = _draftStartDay;
        _initialCategoryBudgets
          ..clear()
          ..addAll(_draftCategoryBudgets);
      });
      Navigator.of(context).pop();
    }
  }

  Future<bool> _save() => VeriFinScope.of(context).saveBudgetSettingsDraft(
    defaultMonthlyBudget: _draftDefaultBudget,
    dailyBudget: _draftDailyBudget,
    cycleStartDay: _draftStartDay,
    defaultCategoryBudgets: _draftCategoryBudgets,
  );
}

/// 段落标题（与设置页风格一致的小节标签）。
Widget _sectionLabel(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58),
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
