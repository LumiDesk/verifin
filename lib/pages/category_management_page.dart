import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/category_tree.dart';
import '../app/common_widgets.dart';
import '../app/entry_sheets.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import 'sheets.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  EntryType _type = EntryType.expense;

  // 收起的父分类 id（默认全部展开，收起后隐藏其子树）。
  final Set<String> _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final roots = controller.rootCategoriesForType(_type);

    return Scaffold(
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
                  HeaderAction(
                    icon: Icons.add,
                    tooltip: AppLocalizations.of(context).addTopCategory,
                    onPressed: () => _createCategory(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<EntryType>(
                segments: EntryType.values
                    .map(
                      (type) => ButtonSegment<EntryType>(
                        value: type,
                        label: Text(type.label(AppLocalizations.of(context))),
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
                child: _buildLevel(controller, roots, null, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 递归渲染某父级（[parentId] 为 null 即顶级）下的同级分类，
  /// 展开的父分类下方缩进渲染其子级。每级各自是一个可拖拽重排的列表。
  Widget _buildLevel(
    VeriFinController controller,
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
        controller.reorderCategories(_type, parentId, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final category = siblings[index];
        final children = controller.childCategories(category.id);
        final collapsed = _collapsed.contains(category.id);
        return Column(
          key: ValueKey<String>(category.id),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _CategoryManageRow(
              index: index,
              depth: depth,
              category: category,
              childCount: children.length,
              usageCount: controller.categoryUsageCount(category.id),
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
              onTap: () => _showCategoryActions(category),
            ),
            if (children.isNotEmpty && !collapsed)
              _buildLevel(controller, children, category.id, depth + 1),
          ],
        );
      },
    );
  }

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

  Future<void> _showCategoryActions(Category category) async {
    final protected = _isProtectedCategory(category.id);
    final selected = await showOptionSheet<String>(
      context: context,
      title: category.label,
      values: <String>[
        'rename',
        'icon',
        'add_sub',
        if (!protected) 'move',
        if (!protected) 'merge',
        if (!protected) 'delete',
      ],
      selected: 'rename',
      showSelectedMarker: false,
      labelOf: (value) => switch (value) {
        'rename' => AppLocalizations.of(context).commonRename,
        'icon' => AppLocalizations.of(context).changeIcon,
        'add_sub' => AppLocalizations.of(context).addSubCategory,
        'move' => AppLocalizations.of(context).moveTo,
        'merge' => AppLocalizations.of(context).mergeCategory,
        'delete' => AppLocalizations.of(context).deleteCategory,
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
      case 'add_sub':
        await _createCategory(parent: category);
      case 'move':
        await _moveCategory(category);
      case 'merge':
        await _mergeCategory(category);
      case 'delete':
        await _deleteCategory(category);
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noMoveTarget)),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.moveSubFirst)));
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
    final changed = controller.mergeCategoryInto(category.id, targetId);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          changed < 0
              ? l10n.mergeCategoryFailed
              : l10n.mergedCategoryResult(changed, targetLabel),
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cannotMoveHere)));
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
    return showCategoryIconPickerSheet(context: context, selected: selected);
  }

  Future<void> _deleteCategory(Category category) async {
    final controller = VeriFinScope.of(context);
    if (_isProtectedCategory(category.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).systemCategoryUndeletable),
        ),
      );
      return;
    }
    final usageCount = controller.categoryUsageCount(category.id);
    if (usageCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).categoryInUse(usageCount)),
        ),
      );
      return;
    }
    final recurringCount = controller.categoryRecurringRuleCount(category.id);
    if (recurringCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).categoryUsedByRecurring(recurringCount),
          ),
        ),
      );
      return;
    }
    if (controller.childCategories(category.id).isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).moveSubFirst)),
      );
      return;
    }
    if (controller.categoriesForType(category.type).length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).keepOneCategory)),
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
    final deleted = controller.deleteCategory(category.id);
    if (!deleted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).categoryUndeletable),
        ),
      );
    }
  }
}

bool _isProtectedCategory(String categoryId) {
  return categoryId == 'balance_adjust_expense' ||
      categoryId == 'balance_adjust_income';
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
    required this.onTap,
  });

  final int index;
  final int depth;
  final Category category;
  final int childCount;
  final int usageCount;
  final bool collapsed;

  /// 展开/收起子分类；无子分类时为 null（不显示折叠箭头）。
  final VoidCallback? onToggle;
  final VoidCallback onTap;

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
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14 + depth * 22, 10, 8, 10),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                child: onToggle == null
                    ? (depth > 0
                          ? Icon(
                              Icons.subdirectory_arrow_right,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                            )
                          : null)
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 22,
                        onPressed: onToggle,
                        icon: Icon(
                          collapsed ? Icons.chevron_right : Icons.expand_more,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              CategoryIconBox(iconCode: category.iconCode, size: 30),
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
