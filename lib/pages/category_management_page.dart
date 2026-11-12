import 'dart:async';
import 'dart:math' as math;

import 'package:anchored_menu/anchored_menu.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/auto_save.dart';
import '../app/category_tree.dart';
import '../app/common_widgets.dart';
import '../app/entry_sheets.dart';
import '../app/feedback.dart';
import '../app/ledger_math.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import 'sheets.dart';
import 'transactions_pages.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  EntryType _type = EntryType.expense;
  late final AutoSave _autoSave = AutoSave(save: _saveOrder);
  bool _sorting = false;
  List<Category> _draftCategories = <Category>[];

  // 收起的父分类 id；首次进入时默认收起所有有子分类的父节点。
  final Set<String> _collapsed = <String>{};
  bool _collapseDefaultsInitialized = false;

  @override
  void dispose() {
    _autoSave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final categories = _sorting ? _draftCategories : controller.categories;
    if (!_collapseDefaultsInitialized) {
      _collapsed.addAll(
        categories
            .where((category) => childrenOf(categories, category.id).isNotEmpty)
            .map((category) => category.id),
      );
      _collapseDefaultsInitialized = true;
    }
    final roots = rootCategories(categories, _type);

    return AutoSavePopScope(
      autoSave: _autoSave,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: AppLocalizations.of(context).categoryMgmt,
                  subtitle: AppLocalizations.of(context).categoryMgmtSubtitle,
                  showBack: true,
                  actions: <Widget>[
                    if (!_sorting)
                      HeaderAction(
                        icon: Icons.add,
                        tooltip: AppLocalizations.of(context).addTopCategory,
                        onPressed: () => _createCategory(),
                      ),
                    if (_sorting)
                      HeaderAction(
                        icon: Icons.check,
                        tooltip: AppLocalizations.of(context).panelSortDone,
                        onPressed: _finishSorting,
                      )
                    else
                      HeaderAction(
                        icon: Icons.swap_vert,
                        tooltip: AppLocalizations.of(context).sortLabel,
                        onPressed:
                            categories
                                .where((category) => category.type == _type)
                                .skip(1)
                                .isNotEmpty
                            ? () => _startSorting(controller)
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                AutoSaveFailureBanner(autoSave: _autoSave),
                VeriSegmentedControl<EntryType>(
                  values: EntryType.userSelectable,
                  selected: _type,
                  labelOf: (type) => type.label(AppLocalizations.of(context)),
                  // 支出/收入/转账各用各的语义色，与记账页的分段条保持一致。
                  accentOf: (type) => type == EntryType.expense
                      ? veriSemantic(context, veriExpense)
                      : type == EntryType.income
                      ? veriSemantic(context, veriIncome)
                      : veriSemantic(context, veriBlue),
                  // 排序期间不接受切换口径。
                  onChanged: _sorting
                      ? null
                      : (type) => setState(() => _type = type),
                ),
                const SizedBox(height: 10),
                VeriCard(
                  padding: EdgeInsets.zero,
                  child: _buildLevel(controller, categories, roots, null, 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 递归渲染某父级（[parentId] 为 null 即顶级）下的同级分类，
  /// 展开的父分类下方缩进渲染其子级。每级各自是一个可拖拽重排的列表。
  Widget _buildLevel(
    VeriFinController controller,
    List<Category> allCategories,
    List<Category> siblings,
    String? parentId,
    int depth,
  ) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: siblings.length,
      onReorderItem: (oldIndex, newIndex) {
        if (_sorting) {
          _reorderDraft(parentId, oldIndex, newIndex);
        }
      },
      itemBuilder: (context, index) {
        final category = siblings[index];
        final children = childrenOf(allCategories, category.id);
        final collapsed = _collapsed.contains(category.id);
        final row = _sorting
            ? _CategoryManageRow(
                index: index,
                depth: depth,
                category: category,
                childCount: children.length,
                usageCount: controller.categoryUsageCountInTree(category.id),
                collapsed: collapsed,
                onToggle: children.isEmpty
                    ? null
                    : () => setState(() {
                        if (collapsed) {
                          _collapsed.remove(category.id);
                        } else {
                          _collapsed.add(category.id);
                        }
                      }),
                sorting: true,
              )
            : AnchoredMenuAnchor(
                entries: _categoryMenuEntries(category),
                semanticLabel: category.label,
                builder: (context, openMenu, menuOpen) => _CategoryManageRow(
                  index: index,
                  depth: depth,
                  category: category,
                  childCount: children.length,
                  usageCount: controller.categoryUsageCountInTree(category.id),
                  collapsed: collapsed,
                  onToggle: children.isEmpty
                      ? null
                      : () => setState(() {
                          if (collapsed) {
                            _collapsed.remove(category.id);
                          } else {
                            _collapsed.add(category.id);
                          }
                        }),
                  onTap: openMenu,
                  onActions: openMenu,
                  sorting: false,
                ),
              );
        return Column(
          key: ValueKey<String>(category.id),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            row,
            if (children.isNotEmpty && !collapsed)
              _buildLevel(
                controller,
                allCategories,
                children,
                category.id,
                depth + 1,
              ),
          ],
        );
      },
    );
  }

  void _startSorting(VeriFinController controller) {
    setState(() {
      _sorting = true;
      _draftCategories = List<Category>.of(controller.categories);
    });
  }

  void _finishSorting() {
    setState(() {
      _sorting = false;
      _draftCategories = <Category>[];
    });
  }

  void _reorderDraft(String? parentId, int oldIndex, int newIndex) {
    final positions = <int>[];
    for (var index = 0; index < _draftCategories.length; index++) {
      final category = _draftCategories[index];
      if (category.type == _type && category.parentId == parentId) {
        positions.add(index);
      }
    }
    if (oldIndex < 0 ||
        oldIndex >= positions.length ||
        newIndex < 0 ||
        newIndex > positions.length) {
      return;
    }
    setState(() {
      final siblings = <Category>[
        for (final position in positions) _draftCategories[position],
      ];
      final moved = siblings.removeAt(oldIndex);
      siblings.insert(newIndex.clamp(0, siblings.length), moved);
      for (var index = 0; index < positions.length; index++) {
        _draftCategories[positions[index]] = siblings[index];
      }
    });
    _autoSave.schedule(immediate: true);
  }

  Future<bool> _saveOrder() => VeriFinScope.of(context).saveCategoryOrderDraft(
    _draftCategories.map((category) => category.id).toList(),
  );

  Future<void> _createCategory({Category? parent}) async {
    final typeLabel = (parent?.type ?? _type).label(
      AppLocalizations.of(context),
    );
    final label = await showTextInputDialog(
      context: context,
      title: parent == null
          ? AppLocalizations.of(context).addCategoryTitle(typeLabel)
          : AppLocalizations.of(context).addSubCategoryTitle(parent.label),
      label: AppLocalizations.of(context).categoryNameLabel,
    );
    if (!mounted || label == null) {
      return;
    }
    final iconCode = await _pickCategoryIcon(selected: 'category');
    if (!mounted || iconCode == null) {
      return;
    }
    VeriFinScope.of(context).addCategory(
      type: parent?.type ?? _type,
      label: label,
      iconCode: iconCode,
      parentId: parent?.id,
    );
    // 新建子分类后确保父分类展开可见。
    if (parent != null && mounted) {
      setState(() => _collapsed.remove(parent.id));
    }
  }

  List<AnchoredMenuEntry> _categoryMenuEntries(Category category) {
    // 系统分类（余额调整）可改名、换图标，但不能移动、合并、删除。
    final protected = category.isBalanceAdjust;
    final l10n = AppLocalizations.of(context);
    return <AnchoredMenuEntry>[
      AnchoredMenuItem(
        id: 'category_view_entries',
        icon: Icons.receipt_long_outlined,
        title: l10n.viewCategoryEntries,
        onPressed: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) =>
                  TransactionsPage(initialCategoryId: category.id),
            ),
          );
        },
      ),
      AnchoredMenuItem(
        id: 'category_edit',
        icon: Icons.edit_outlined,
        title: l10n.commonEdit,
        children: <AnchoredMenuEntry>[
          AnchoredMenuItem(
            id: 'category_rename',
            icon: Icons.drive_file_rename_outline,
            title: l10n.commonRename,
            onPressed: () async => _renameCategory(category),
          ),
          AnchoredMenuItem(
            id: 'category_icon',
            icon: Icons.palette_outlined,
            title: l10n.changeIcon,
            onPressed: () async => _changeCategoryIcon(category),
          ),
          AnchoredMenuItem(
            id: 'category_add_sub',
            icon: Icons.create_new_folder_outlined,
            title: l10n.addSubCategory,
            onPressed: () async => _createCategory(parent: category),
          ),
          if (!protected)
            AnchoredMenuItem(
              id: 'category_move',
              icon: Icons.drive_file_move_outline,
              title: l10n.moveTo,
              onPressed: () async => _moveCategory(category),
            ),
          if (!protected)
            AnchoredMenuItem(
              id: 'category_merge',
              icon: Icons.merge_type_rounded,
              title: l10n.mergeCategory,
              onPressed: () async => _mergeCategory(category),
            ),
        ],
      ),
      if (!protected) const AnchoredMenuDivider(),
      if (!protected)
        AnchoredMenuItem(
          id: 'category_delete',
          icon: Icons.delete_outline,
          title: l10n.deleteCategory,
          foregroundColor: Theme.of(context).colorScheme.error,
          onPressed: () async => _deleteCategory(category),
        ),
    ];
  }

  /// 把该分类的全部交易并入另一个同类型分类，随后删除该分类（统一同义分类）。
  /// 分类目标选择器（移动 / 合并共用）：带图标 + 层级树，自动排除自身及其后代。
  /// [topLevelLabel] 非空时在顶部提供「移到顶级」选项（返回 [categoryPickerTopLevel]）。
  Future<String?> _pickCategoryTarget({
    required Category source,
    required String title,
    String? topLevelLabel,
  }) {
    final controller = VeriFinScope.of(context);
    final all = controller.categories;
    final candidates = controller
        .categoriesForType(source.type)
        .where(
          (c) => c.id != source.id && !isDescendantOf(all, c.id, source.id),
        )
        .toList();
    if (candidates.isEmpty && topLevelLabel == null) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: AppLocalizations.of(context).noMoveTarget,
          tone: VeriFeedbackTone.warning,
        ),
      );
      return Future<String?>.value();
    }
    return showCategoryPickerSheet(
      context,
      categories: candidates,
      selectedId: '',
      title: title,
      topLevelLabel: topLevelLabel,
    );
  }

  Future<void> _mergeCategory(Category category) async {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    // 有子分类无法整体合并，先引导处理子分类。
    if (controller.childCategories(category.id).isNotEmpty) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: l10n.moveSubFirst,
          tone: VeriFeedbackTone.warning,
        ),
      );
      return;
    }
    final targetId = await _pickCategoryTarget(
      source: category,
      title: l10n.mergeCategoryPickTitle(category.label),
    );
    if (!mounted || targetId == null) {
      return;
    }
    final targetLabel = controller.categoryById(targetId).label;
    final count = controller.categoryUsageCount(category.id);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.mergeCategoryConfirmTitle,
      message: l10n.mergeCategoryConfirmMessage(
        category.label,
        count,
        targetLabel,
      ),
      confirmLabel: l10n.mergeCategoryConfirmButton,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final changed = await controller.mergeCategoryInto(category.id, targetId);
    if (!mounted) {
      return;
    }
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: changed < 0
            ? l10n.mergeCategoryFailed
            : l10n.mergedCategoryResult(changed, targetLabel),
        tone: changed < 0 ? VeriFeedbackTone.error : VeriFeedbackTone.success,
        duration: changed < 0
            ? VeriFeedbackDuration.long
            : VeriFeedbackDuration.standard,
        priority: changed < 0
            ? VeriFeedbackPriority.high
            : VeriFeedbackPriority.normal,
      ),
    );
  }

  Future<void> _moveCategory(Category category) async {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final selected = await _pickCategoryTarget(
      source: category,
      title: l10n.moveCategoryTitle(category.label),
      // 已在顶级的分类不提供「移到顶级」。
      topLevelLabel: category.parentId != null ? l10n.topCategory : null,
    );
    if (!mounted || selected == null) {
      return;
    }
    final moved = controller.moveCategory(
      category.id,
      selected == categoryPickerTopLevel ? null : selected,
    );
    if (!moved && mounted) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: l10n.cannotMoveHere,
          tone: VeriFeedbackTone.warning,
        ),
      );
    }
  }

  Future<void> _renameCategory(Category category) async {
    final label = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).renameCategoryTitle,
      label: AppLocalizations.of(context).categoryNameLabel,
      initialValue: category.label,
    );
    if (!mounted || label == null) {
      return;
    }
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await controller.renameCategory(category.id, label);
    if (!mounted || result != RenameResult.duplicate) {
      return;
    }
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: l10n.categoryNameDuplicate,
        tone: VeriFeedbackTone.warning,
      ),
    );
  }

  Future<void> _changeCategoryIcon(Category category) async {
    final iconCode = await _pickCategoryIcon(selected: category.iconCode);
    if (!mounted || iconCode == null) {
      return;
    }
    VeriFinScope.of(context).updateCategoryIcon(category.id, iconCode);
  }

  Future<String?> _pickCategoryIcon({required String selected}) {
    return showCategoryIconPickerSheet(context: context, selected: selected);
  }

  Future<void> _deleteCategory(Category category) async {
    final controller = VeriFinScope.of(context);
    if (category.isBalanceAdjust) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: AppLocalizations.of(context).systemCategoryUndeletable,
          tone: VeriFeedbackTone.warning,
        ),
      );
      return;
    }
    final usageCount = controller.categoryUsageCount(category.id);
    if (usageCount > 0) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: AppLocalizations.of(context).categoryInUse(usageCount),
          tone: VeriFeedbackTone.warning,
        ),
      );
      return;
    }
    final recurringCount = controller.categoryRecurringRuleCount(category.id);
    if (recurringCount > 0) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: AppLocalizations.of(
            context,
          ).categoryUsedByRecurring(recurringCount),
          tone: VeriFeedbackTone.warning,
          duration: VeriFeedbackDuration.long,
        ),
      );
      return;
    }
    if (controller.childCategories(category.id).isNotEmpty) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: AppLocalizations.of(context).moveSubFirst,
          tone: VeriFeedbackTone.warning,
        ),
      );
      return;
    }
    if (controller.categoriesForType(category.type).length <= 1) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: AppLocalizations.of(context).keepOneCategory,
          tone: VeriFeedbackTone.warning,
        ),
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: AppLocalizations.of(context).deleteCategoryTitle,
      message: AppLocalizations.of(
        context,
      ).deleteCategoryMessage(category.label),
      confirmLabel: AppLocalizations.of(context).commonDelete,
      destructive: true,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final deleted = await controller.deleteCategory(category.id);
    if (!deleted && mounted) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: AppLocalizations.of(context).categoryUndeletable,
          tone: VeriFeedbackTone.warning,
        ),
      );
    }
  }
}

class _CategoryManageRow extends StatelessWidget {
  const _CategoryManageRow({
    required this.index,
    required this.depth,
    required this.category,
    required this.childCount,
    required this.usageCount,
    required this.collapsed,
    required this.onToggle,
    required this.sorting,
    this.onTap,
    this.onActions,
  });

  final int index;
  final int depth;
  final Category category;
  final int childCount;
  final int usageCount;
  final bool collapsed;

  /// 展开/收起子分类；无子分类时为 null（不显示折叠箭头）。
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onActions;
  final bool sorting;

  @override
  Widget build(BuildContext context) {
    final typeLabel = category.type.label(AppLocalizations.of(context));
    final subtitle = childCount > 0
        ? AppLocalizations.of(
            context,
          ).catSubChildren(typeLabel, childCount, usageCount)
        : AppLocalizations.of(context).catSubPlain(typeLabel, usageCount);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: sorting ? null : onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14 + depth * 22, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              CategoryIconBox(
                iconCode: category.iconCode,
                color: colorForType(context, category.type),
                size: 30,
              ),
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
                      subtitle,
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
              if (onToggle != null)
                IconButton(
                  key: ValueKey<String>(
                    'category_manage_toggle_${category.id}',
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  iconSize: 22,
                  onPressed: onToggle,
                  icon: Transform.rotate(
                    angle: collapsed ? -math.pi / 2 : 0,
                    child: Icon(
                      Icons.expand_more,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                )
              else
                const SizedBox(width: 40),
              if (sorting)
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
                )
              else
                IconButton(
                  tooltip: category.label,
                  onPressed: onActions,
                  icon: const Icon(Icons.more_vert),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
