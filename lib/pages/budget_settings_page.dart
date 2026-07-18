part of 'budget_pages.dart';

/// 预算设置页（真·设置）：集中配置**默认预算**与周期口径——
/// 默认月预算（每月自动沿用）、按日预算上限、预算周期起始日，以及**分类默认预算**树。
/// 总览页只读，单月的临时调整走 [showMonthlyBudgetOverrideSheet]。
class BudgetSettingsPage extends StatefulWidget {
  const BudgetSettingsPage({super.key});

  @override
  State<BudgetSettingsPage> createState() => _BudgetSettingsPageState();
}

class _BudgetSettingsPageState extends State<BudgetSettingsPage> {
  // 收起的父分类 id（默认折叠：首次构建时把所有含子类的分类加入）。
  final Set<String> _collapsedCategories = <String>{};
  bool _collapseInitialized = false;

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

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    _initCollapse(controller);

    // 分类默认预算树展示「当前周期实际花销 vs 默认预算」，spent 只作参考。
    final now = DateTime.now();
    final keyMonth = controller.budgetKeyMonthFor(now);
    final periodEntries = entriesInWindow(
      controller.entries,
      controller.budgetWindow(keyMonth),
    );
    final categorySnapshots = computeCategoryBudgetSnapshots(
      controller: controller,
      month: keyMonth,
      monthEntries: periodEntries,
      useDefaultBudget: true,
    );

    final defaultBudget = controller.defaultMonthlyBudget;
    final dailyBudget = controller.dailyBudget();
    final startDay = controller.budgetCycleStartDay;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: l10n.budgetSettingsTitle,
                subtitle: controller.activeBook.name,
                showBack: true,
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                                  color: Theme.of(context).colorScheme.onSurface
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
    final controller = VeriFinScope.of(context);
    final amount = await _promptBudgetAmount(
      AppLocalizations.of(context).setDefaultMonthlyBudgetTitle,
      controller.defaultMonthlyBudget,
    );
    if (amount == null || !mounted) {
      return;
    }
    controller.setDefaultMonthlyBudget(amount);
  }

  Future<void> _editDailyBudget() async {
    final controller = VeriFinScope.of(context);
    final amount = await _promptBudgetAmount(
      AppLocalizations.of(context).setDailyBudgetTitle,
      controller.dailyBudget(),
    );
    if (amount == null || !mounted) {
      return;
    }
    controller.setDailyBudget(amount);
  }

  /// 选择预算周期起始日（1–28，账本级）。改起始日只是换周期口径，各键月已存
  /// 的预算金额不动。
  Future<void> _editCycleStartDay() async {
    final controller = VeriFinScope.of(context);
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
      selected: controller.budgetCycleStartDay,
      labelOf: (day) => day == naturalMonthStartDay
          ? l10n.budgetCycleNaturalMonth
          : l10n.budgetCycleStartDayOption(day),
    );
    if (selected != null && mounted) {
      controller.setBudgetCycleStartDay(selected);
    }
  }

  Future<void> _editDefaultCategoryBudget(Category category) async {
    final controller = VeriFinScope.of(context);
    final amount = await _promptBudgetAmount(
      AppLocalizations.of(
        context,
      ).setDefaultCategoryBudgetTitle(category.label),
      controller.defaultCategoryBudget(category.id),
    );
    if (amount == null || !mounted) {
      return;
    }
    controller.setDefaultCategoryBudget(category.id, amount);
  }
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

/// 单月覆盖弹窗：为某键月单独设一个不同于默认的预算，或清除覆盖回到沿用默认。
/// 总览页状态 chip 与历史页月份行都从这里进入。
Future<void> showMonthlyBudgetOverrideSheet(
  BuildContext context,
  DateTime month,
) async {
  final controller = VeriFinScope.of(context);
  final l10n = AppLocalizations.of(context);
  final isOverride = controller.monthlyBudgetIsOverride(month);
  final defaultBudget = controller.defaultMonthlyBudget;

  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l10n.monthBudgetTitle(month),
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: Text(l10n.budgetOverrideSetAmount),
              onTap: () => Navigator.of(sheetContext).pop('set'),
            ),
            if (isOverride)
              ListTile(
                leading: const Icon(Icons.event_repeat_outlined),
                title: Text(
                  defaultBudget > 0
                      ? l10n.budgetOverrideRestore(formatAmount(defaultBudget))
                      : l10n.budgetOverrideClear,
                ),
                onTap: () => Navigator.of(sheetContext).pop('clear'),
              ),
            const SizedBox(height: 4),
          ],
        ),
      );
    },
  );

  if (action == 'clear') {
    controller.clearMonthlyBudgetOverride(month);
    return;
  }
  if (action == 'set' && context.mounted) {
    final current = controller.monthlyBudget(month);
    final amount = await showNumberPadSheet(
      context,
      title: l10n.setMonthBudgetTitle,
      initialAmount: current > 0 ? current : null,
      allowZero: true,
    );
    if (amount != null) {
      controller.setMonthlyBudget(month, amount);
    }
  }
}
