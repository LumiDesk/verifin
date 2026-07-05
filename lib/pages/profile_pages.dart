import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_version.dart';
import '../app/avatar_picker.dart';
import '../app/backup/backup_archive.dart';
import '../app/backup/backup_crypto.dart';
import '../app/backup/backup_service.dart';
import '../app/backup/backup_settings.dart';
import '../app/backup/transaction_import.dart';
import '../app/backup/webdav_client.dart';
import '../app/backup/webdav_config.dart';
import '../app/category_tree.dart';
import '../app/common_widgets.dart';
import '../app/data_file_port.dart';
import '../app/demo_data.dart';
import '../app/image_cropper.dart';
import '../app/image_sources.dart';
import '../app/ledger_math.dart';
import '../app/legal_content.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/platform_bridge.dart';
import 'recurring_page.dart';
import '../app/series_math.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import 'app_lock_page.dart';
import 'report_analysis_page.dart';
import 'reminder_settings_page.dart';
import 'legal_pages.dart';
import 'sheets.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final profile = controller.profile;
    final profileTags = _profileSummaryTags(
      profile,
      AppLocalizations.of(context),
    );
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
            title: AppLocalizations.of(context).tabProfile,
            subtitle: AppLocalizations.of(context).profileCenterSubtitle,
            trailing: IconButton(
              tooltip: AppLocalizations.of(context).settingsTooltip,
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
                            if (profileTags.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: profileTags
                                    .map((tag) => _ProfileMetaTag(label: tag))
                                    .toList(),
                              ),
                            ],
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
                        child: Builder(
                          builder: (context) {
                            final (value, label) = bookkeepingDurationStat(
                              AppLocalizations.of(context),
                              bookkeepingDays(controller.entries),
                            );
                            return ProfileStat(label: label, value: value);
                          },
                        ),
                      ),
                      Expanded(
                        child: ProfileStat(
                          label: AppLocalizations.of(context).entryCountStat,
                          value: '${controller.entries.length}',
                        ),
                      ),
                      Expanded(
                        child: ProfileStat(
                          label: AppLocalizations.of(context).netAssets,
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
          _FeatureGridCard(
            title: AppLocalizations.of(context).bookkeepingMgmt,
            tiles: <_FeatureTileData>[
              _FeatureTileData(
                icon: Icons.book_outlined,
                color: veriRoyal,
                label: AppLocalizations.of(context).ledgerLabel,
                subtitle: controller.activeBook.name,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const LedgerBooksPage(),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.category_outlined,
                color: veriBlue,
                label: AppLocalizations.of(context).categoryMgmt,
                subtitle: AppLocalizations.of(
                  context,
                ).countItems(controller.categories.length),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const CategoryManagementPage(),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.label_outline,
                color: veriCyan,
                label: AppLocalizations.of(context).tagMgmt,
                subtitle: AppLocalizations.of(
                  context,
                ).countItems(controller.tags.length),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const TagManagementPage(),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.repeat,
                color: veriMint,
                label: AppLocalizations.of(context).recurringTitle,
                subtitle: AppLocalizations.of(
                  context,
                ).countRules(controller.recurringRules.length),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const RecurringRulesPage(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FeatureGridCard(
            title: AppLocalizations.of(context).dataAndTools,
            tiles: <_FeatureTileData>[
              _FeatureTileData(
                icon: Icons.insights_outlined,
                color: veriRoyal,
                label: AppLocalizations.of(context).statAnalysisTitle,
                subtitle: AppLocalizations.of(context).reportShort,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const ReportAnalysisPage(),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.notifications_active_outlined,
                color: veriWarning,
                label: AppLocalizations.of(context).reminderTitle,
                subtitle: controller.reminderSettings.enabled
                    ? controller.reminderSettings.timeLabel
                    : AppLocalizations.of(context).notEnabled,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const ReminderSettingsPage(),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.storage_outlined,
                color: veriBlue,
                label: AppLocalizations.of(context).dataManagement,
                subtitle: AppLocalizations.of(context).backupRestoreShort,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const DataManagementPage(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 我的页功能宫格卡：标题 + 4 列图标宫格。（阶段 4.4）
class _FeatureGridCard extends StatelessWidget {
  const _FeatureGridCard({required this.title, required this.tiles});

  final String title;
  final List<_FeatureTileData> tiles;

  @override
  Widget build(BuildContext context) {
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(title: title),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.82,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: tiles
                .map((data) => _FeatureTile(data: data))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _FeatureTileData {
  const _FeatureTileData({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.data});

  final _FeatureTileData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(veriRadiusMd),
      onTap: data.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            VeriIconBox(icon: data.icon, color: data.color, size: 42),
            const SizedBox(height: 7),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 1),
            Text(
              data.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.46),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _profileSummaryTags(UserProfile profile, AppLocalizations l10n) {
  final tags = <String>[];
  if (profile.gender != ProfileGender.unset) {
    tags.add(profile.gender.label(l10n));
  }
  if (profile.birthday.isNotEmpty) {
    tags.add(profile.birthday);
  }
  if (profile.city.isNotEmpty) {
    tags.add(profile.city);
  }
  if (profile.occupation.isNotEmpty) {
    tags.add(profile.occupation);
  }
  return tags;
}

class _ProfileMetaTag extends StatelessWidget {
  const _ProfileMetaTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(veriRadiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.58),
          fontWeight: FontWeight.w700,
        ),
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
                title: AppLocalizations.of(context).ledgerLabel,
                subtitle: AppLocalizations.of(
                  context,
                ).currentBookLabel(controller.activeBook.name),
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.add,
                    tooltip: AppLocalizations.of(context).bookAdd,
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
    final name = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).bookAdd,
      label: AppLocalizations.of(context).bookNameLabel,
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
                      '${book.isDefault ? '${AppLocalizations.of(context).defaultBookLabel} · ' : ''}'
                      '${AppLocalizations.of(context).entriesCountFull(entryCount)}',
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
                tooltip: AppLocalizations.of(context).bookActions,
                onSelected: (value) {
                  if (value == 'rename') {
                    _renameBook(context);
                  }
                  if (value == 'delete') {
                    _deleteBook(context);
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'rename',
                    child: Text(AppLocalizations.of(context).commonRename),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    enabled: !book.isDefault,
                    child: Text(
                      book.isDefault
                          ? AppLocalizations.of(context).defaultBookUndeletable
                          : AppLocalizations.of(context).commonDelete,
                    ),
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
    final name = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).bookRenameTitle,
      label: AppLocalizations.of(context).bookNameLabel,
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
        title: Text(AppLocalizations.of(context).bookDeleteTitle),
        content: Text(
          AppLocalizations.of(context).bookDeleteMessage(book.name),
        ),
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
        if (!protected) 'delete',
      ],
      selected: 'rename',
      showSelectedMarker: false,
      labelOf: (value) => switch (value) {
        'rename' => AppLocalizations.of(context).commonRename,
        'icon' => AppLocalizations.of(context).changeIcon,
        'add_sub' => AppLocalizations.of(context).addSubCategory,
        'move' => AppLocalizations.of(context).moveTo,
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
      case 'delete':
        await _deleteCategory(category);
    }
  }

  Future<void> _moveCategory(Category category) async {
    final controller = VeriFinScope.of(context);
    final all = controller.categories;
    // 候选父级：同类型、非自身、非自身后代、且不是当前父级。另加「移到顶级」。
    final candidates = controller
        .categoriesForType(category.type)
        .where(
          (c) =>
              c.id != category.id &&
              c.id != category.parentId &&
              !isDescendantOf(all, c.id, category.id),
        )
        .toList();
    final values = <String>[
      if (category.parentId != null) _moveToRootValue,
      ...candidates.map((c) => c.id),
    ];
    if (values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noMoveTarget)),
      );
      return;
    }
    final selected = await showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).moveCategoryTitle(category.label),
      values: values,
      selected: values.first,
      showSelectedMarker: false,
      labelOf: (value) => value == _moveToRootValue
          ? AppLocalizations.of(context).topCategory
          : controller.categoryPathLabel(value),
    );
    if (!mounted || selected == null) {
      return;
    }
    final moved = controller.moveCategory(
      category.id,
      selected == _moveToRootValue ? null : selected,
    );
    if (!moved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).cannotMoveHere)),
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
    return showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).pickIconTitle,
      values: categoryIconCodes,
      selected: selected,
      labelOf: (code) => iconLabelForCode(AppLocalizations.of(context), code),
    );
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteCategoryTitle),
        content: Text(
          AppLocalizations.of(context).deleteCategoryMessage(category.label),
        ),
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

/// 「移到顶级」在移动选项中的占位值（区别于任何真实分类 id）。
const String _moveToRootValue = '__root__';

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

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final tags = controller.tags;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).tagMgmt,
                subtitle: AppLocalizations.of(context).tagMgmtSubtitle,
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.add,
                    tooltip: AppLocalizations.of(context).tagAdd,
                    onPressed: _createTag,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tags.isEmpty)
                VeriCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).tagsEmpty,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                )
              else
                VeriCard(
                  padding: EdgeInsets.zero,
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: tags.length,
                    onReorderItem: (oldIndex, newIndex) {
                      controller.reorderTags(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      return _TagManageRow(
                        key: ValueKey<String>(tag.id),
                        index: index,
                        tag: tag,
                        usageCount: controller.tagUsageCount(tag.id),
                        onTap: () => _showTagActions(tag),
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

  Future<void> _createTag() async {
    final label = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).tagAdd,
      label: AppLocalizations.of(context).tagNameLabel,
    );
    if (!mounted || label == null) {
      return;
    }
    VeriFinScope.of(context).addTag(label);
  }

  Future<void> _showTagActions(Tag tag) async {
    final selected = await showOptionSheet<String>(
      context: context,
      title: tag.label,
      values: const <String>['rename', 'delete'],
      selected: 'rename',
      showSelectedMarker: false,
      labelOf: (value) => switch (value) {
        'rename' => AppLocalizations.of(context).commonRename,
        'delete' => AppLocalizations.of(context).deleteTag,
        _ => value,
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    switch (selected) {
      case 'rename':
        await _renameTag(tag);
      case 'delete':
        await _deleteTag(tag);
    }
  }

  Future<void> _renameTag(Tag tag) async {
    final label = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).tagRenameTitle,
      label: AppLocalizations.of(context).tagNameLabel,
      initialValue: tag.label,
    );
    if (!mounted || label == null) {
      return;
    }
    VeriFinScope.of(context).renameTag(tag.id, label);
  }

  Future<void> _deleteTag(Tag tag) async {
    final controller = VeriFinScope.of(context);
    final usage = controller.tagUsageCount(tag.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).tagDeleteTitle),
        content: Text(
          usage > 0
              ? AppLocalizations.of(context).tagDeleteInUse(tag.label, usage)
              : AppLocalizations.of(context).tagDeleteMessage(tag.label),
        ),
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
    controller.deleteTag(tag.id);
  }
}

class _TagManageRow extends StatelessWidget {
  const _TagManageRow({
    super.key,
    required this.index,
    required this.tag,
    required this.usageCount,
    required this.onTap,
  });

  final int index;
  final Tag tag;
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
              Icon(
                Icons.label,
                size: 22,
                color: veriRoyal.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tag.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppLocalizations.of(context).entriesCountFull(usageCount),
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
  late TextEditingController _cityController;
  late TextEditingController _occupationController;
  late String _avatarDataUrl;
  ProfileGender _gender = ProfileGender.unset;
  String _birthday = '';
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
    _cityController = TextEditingController(text: profile.city);
    _occupationController = TextEditingController(text: profile.occupation);
    _avatarDataUrl = profile.avatarDataUrl;
    _gender = profile.gender;
    _birthday = profile.birthday;
    _initialized = true;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).personalInfo,
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.check,
                    tooltip: AppLocalizations.of(context).commonSave,
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
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).nicknameLabel,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).bioLabel,
                ),
              ),
              const SizedBox(height: 10),
              SelectField(
                label: AppLocalizations.of(context).genderLabel,
                value: _gender.label(AppLocalizations.of(context)),
                icon: Icons.person_outline,
                onTap: _pickGender,
              ),
              const SizedBox(height: 10),
              SelectField(
                label: AppLocalizations.of(context).birthdayLabel,
                value: _birthday.isEmpty
                    ? AppLocalizations.of(context).clearOption
                    : _birthday,
                icon: Icons.cake_outlined,
                onTap: _pickBirthday,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _cityController,
                maxLines: 1,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).cityLabel,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _occupationController,
                maxLines: 1,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).occupationLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickGender() async {
    final selected = await showOptionSheet<ProfileGender>(
      context: context,
      title: AppLocalizations.of(context).pickGenderTitle,
      values: ProfileGender.values,
      selected: _gender,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null && mounted) {
      setState(() => _gender = selected);
    }
  }

  Future<void> _pickBirthday() async {
    final initial = DateTime.tryParse(_birthday) ?? DateTime(1998);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() {
        _birthday =
            '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickAvatar() async {
    final rawImage = await pickRawImageDataUrl();
    if (rawImage == null || !mounted) {
      return;
    }
    final crop = await showImageCropper(
      context: context,
      imageDataUrl: rawImage,
      title: AppLocalizations.of(context).cropAvatarTitle,
      aspectRatio: 1,
      circlePreview: true,
    );
    if (crop == null || !mounted) {
      return;
    }
    final avatar = await runWithLoadingDialog<String?>(
      context: context,
      message: AppLocalizations.of(context).avatarGenerating,
      task: () => cropImageDataUrl(
        sourceDataUrl: rawImage,
        targetWidth: 512,
        targetHeight: 512,
        zoom: crop.zoom,
        offsetX: crop.offsetX,
        offsetY: crop.offsetY,
      ),
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
            ? AppLocalizations.of(context).profileDefaultBio
            : _bioController.text.trim(),
        avatarDataUrl: _avatarDataUrl,
        gender: _gender,
        birthday: _birthday,
        city: _cityController.text.trim(),
        occupation: _occupationController.text.trim(),
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
              VeriHeader(
                title: AppLocalizations.of(context).settingsTitle,
                showBack: true,
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.dark_mode_outlined,
                      title: AppLocalizations.of(context).themeMode,
                      trailing: controller.themePreference.label(
                        AppLocalizations.of(context),
                      ),
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _pickThemePreference(context, controller),
                    ),
                    const Divider(height: 1),
                    SettingsRow(
                      icon: Icons.translate_outlined,
                      title: AppLocalizations.of(context).settingsLanguage,
                      trailing: controller.localePreference.label(
                        AppLocalizations.of(context),
                      ),
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _pickLocalePreference(context, controller),
                    ),
                    const Divider(height: 1),
                    CompactSwitchRow(
                      icon: Icons.touch_app_outlined,
                      title: Text(AppLocalizations.of(context).hapticsLabel),
                      value: controller.hapticsEnabled,
                      onChanged: controller.setHapticsEnabled,
                    ),
                    const Divider(height: 1),
                    SettingsRow(
                      icon: Icons.lock_outline,
                      title: AppLocalizations.of(context).appLockLabel,
                      trailing: controller.appLockEnabled
                          ? AppLocalizations.of(context).enabledLabel
                          : AppLocalizations.of(context).notEnabled,
                      trailingIcon: Icons.chevron_right,
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (context) => const AppLockSettingsPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    SettingsRow(
                      icon: Icons.notifications_active_outlined,
                      title: AppLocalizations.of(context).reminderTitle,
                      trailing: controller.reminderSettings.enabled
                          ? AppLocalizations.of(context).reminderDailyAt(
                              controller.reminderSettings.timeLabel,
                            )
                          : AppLocalizations.of(context).notEnabled,
                      trailingIcon: Icons.chevron_right,
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (context) => const ReminderSettingsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: SettingsRow(
                  icon: Icons.system_update_alt_outlined,
                  title: AppLocalizations.of(context).checkUpdate,
                  trailing: 'GitHub Release',
                  trailingIcon: Icons.chevron_right,
                  onTap: () => _checkForUpdate(context),
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    for (final entry
                        in LegalDocument.values.indexed) ...<Widget>[
                      if (entry.$1 != 0) const Divider(),
                      SettingsRow(
                        icon: entry.$2 == LegalDocument.privacyPolicy
                            ? Icons.privacy_tip_outlined
                            : Icons.description_outlined,
                        title: entry.$2.title(AppLocalizations.of(context)),
                        trailing: AppLocalizations.of(context).viewLabel,
                        trailingIcon: Icons.chevron_right,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  LegalDocumentPage(document: entry.$2),
                            ),
                          );
                        },
                      ),
                    ],
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
    final selected = await showOptionSheet<ThemePreference>(
      context: context,
      title: AppLocalizations.of(context).themePickerTitle,
      values: ThemePreference.values,
      selected: controller.themePreference,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null) {
      controller.setThemePreference(selected);
    }
  }

  Future<void> _pickLocalePreference(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showOptionSheet<LocalePreference>(
      context: context,
      title: l10n.languagePickerTitle,
      values: LocalePreference.values,
      selected: controller.localePreference,
      labelOf: (value) => value.label(l10n),
    );
    if (selected != null) {
      controller.setLocalePreference(selected);
    }
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _UpdateCheckDialog(),
    );
  }
}

class DataManagementPage extends StatelessWidget {
  const DataManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).dataManagement,
                subtitle: AppLocalizations.of(context).dataMgmtSubtitle,
                showBack: true,
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.download_outlined,
                      title: AppLocalizations.of(context).exportData,
                      trailing: AppLocalizations.of(context).jsonBackup,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _exportData(context, controller),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.upload_file_outlined,
                      title: AppLocalizations.of(context).importData,
                      trailing: AppLocalizations.of(context).restoreFromFile,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _confirmImport(context, controller),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _sectionLabel(
                context,
                AppLocalizations.of(context).importFromSheets,
              ),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.table_chart_outlined,
                      title: AppLocalizations.of(context).importCsv,
                      trailing: AppLocalizations.of(context).byTemplate,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _importCsv(context, controller),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.swap_horiz_outlined,
                      title: AppLocalizations.of(context).importFromOtherApps,
                      trailing: AppLocalizations.of(context).otherAppsHint,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _importFromOtherApp(context, controller),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.file_download_outlined,
                      title: AppLocalizations.of(context).downloadCsvTemplate,
                      trailing: AppLocalizations.of(context).excelHint,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _downloadCsvTemplate(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _sectionLabel(
                context,
                AppLocalizations.of(context).backupToLocalDir,
              ),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.folder_outlined,
                      title: AppLocalizations.of(context).backupDirLabel,
                      trailing: controller.backupSettings.hasDirectory
                          ? controller.backupSettings.directoryLabel
                          : AppLocalizations.of(context).notChosen,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _chooseBackupDirectory(context, controller),
                    ),
                    const Divider(),
                    SettingsRow(
                      icon: Icons.backup_outlined,
                      title: AppLocalizations.of(context).backupNow,
                      trailing: _lastBackupLabel(
                        AppLocalizations.of(context),
                        controller.backupSettings,
                      ),
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _backupNow(context, controller),
                    ),
                    if (controller.backupSettings.hasDirectory) ...<Widget>[
                      const Divider(),
                      SettingsRow(
                        icon: Icons.link_off,
                        title: AppLocalizations.of(context).clearBackupDir,
                        trailing: AppLocalizations.of(context).stopLocalBackup,
                        trailingIcon: Icons.chevron_right,
                        contentColor: veriExpense,
                        onTap: () => controller.clearBackupDirectory(),
                      ),
                    ],
                  ],
                ),
              ),
              if (controller.backupSettings.hasDirectory) ...<Widget>[
                const SizedBox(height: 10),
                _sectionLabel(context, AppLocalizations.of(context).autoBackup),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      SettingsRow(
                        icon: Icons.schedule_outlined,
                        title: AppLocalizations.of(
                          context,
                        ).backupFrequencyLabel,
                        trailing: controller.backupSettings.frequency.label(
                          AppLocalizations.of(context),
                        ),
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _pickBackupFrequency(context, controller),
                      ),
                      if (controller.backupSettings.frequency ==
                          BackupFrequency.everyNHours) ...<Widget>[
                        const Divider(),
                        SettingsRow(
                          icon: Icons.hourglass_bottom_outlined,
                          title: AppLocalizations.of(
                            context,
                          ).backupIntervalLabel,
                          trailing: AppLocalizations.of(context)
                              .everyNHoursLabel(
                                controller.backupSettings.intervalHours,
                              ),
                          trailingIcon: Icons.chevron_right,
                          onTap: () => _pickBackupInterval(context, controller),
                        ),
                      ],
                      const Divider(),
                      SettingsRow(
                        icon: Icons.inventory_2_outlined,
                        title: AppLocalizations.of(context).retentionLabel,
                        trailing: AppLocalizations.of(
                          context,
                        ).latestNCopies(controller.backupSettings.retention),
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _pickBackupRetention(context, controller),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _sectionLabel(
                context,
                AppLocalizations.of(context).backupEncryption,
              ),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.enhanced_encryption_outlined,
                      title: AppLocalizations.of(context).encryptionKey,
                      trailing: controller.backupEncryptionEnabled
                          ? AppLocalizations.of(context).enabledLabel
                          : AppLocalizations.of(context).notSet,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _editBackupPassphrase(context, controller),
                    ),
                    if (controller.backupEncryptionEnabled) ...<Widget>[
                      const Divider(),
                      SettingsRow(
                        icon: Icons.no_encryption_outlined,
                        title: AppLocalizations.of(context).clearEncryptionKey,
                        trailing: AppLocalizations.of(context).noEncryptHint,
                        trailingIcon: Icons.chevron_right,
                        contentColor: veriExpense,
                        onTap: () =>
                            _confirmClearPassphrase(context, controller),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _sectionLabel(
                context,
                AppLocalizations.of(context).webdavSection,
              ),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    SettingsRow(
                      icon: Icons.cloud_outlined,
                      title: AppLocalizations.of(context).webdavServer,
                      trailing: controller.webdavConfig.isConfigured
                          ? AppLocalizations.of(context).configuredLabel
                          : AppLocalizations.of(context).notConfigured,
                      trailingIcon: Icons.chevron_right,
                      onTap: () => _editWebdav(context, controller),
                    ),
                    if (controller.webdavConfig.isConfigured) ...<Widget>[
                      const Divider(),
                      SettingsRow(
                        icon: Icons.cloud_upload_outlined,
                        title: AppLocalizations.of(context).uploadToWebdav,
                        trailing: AppLocalizations.of(context).uploadNow,
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _uploadToWebdav(context, controller),
                      ),
                      const Divider(),
                      SettingsRow(
                        icon: Icons.cloud_download_outlined,
                        title: AppLocalizations.of(context).restoreFromWebdav,
                        trailing: AppLocalizations.of(context).chooseBackup,
                        trailingIcon: Icons.chevron_right,
                        onTap: () => _restoreFromWebdav(context, controller),
                      ),
                      const Divider(),
                      CompactSwitchRow(
                        icon: Icons.sync_outlined,
                        title: Text(
                          AppLocalizations.of(context).autoUploadWebdav,
                        ),
                        value: controller.webdavConfig.autoUpload,
                        onChanged: controller.setWebdavAutoUpload,
                      ),
                      const Divider(),
                      SettingsRow(
                        icon: Icons.cloud_off_outlined,
                        title: AppLocalizations.of(context).clearWebdav,
                        trailing: AppLocalizations.of(context).disconnectLabel,
                        trailingIcon: Icons.chevron_right,
                        contentColor: veriExpense,
                        onTap: () => _confirmClearWebdav(context, controller),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: SettingsRow(
                  icon: Icons.restart_alt,
                  title: AppLocalizations.of(context).resetData,
                  trailing: AppLocalizations.of(context).deleteAllLocal,
                  trailingIcon: Icons.chevron_right,
                  contentColor: veriExpense,
                  onTap: () => _confirmReset(context, controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _lastBackupLabel(
    AppLocalizations l10n,
    BackupSettings settings,
  ) {
    final last = settings.lastBackupAt;
    if (last == null) {
      return l10n.neverBackedUp;
    }
    String two(int v) => v.toString().padLeft(2, '0');
    return l10n.lastBackupAt(
      '${last.year}-${two(last.month)}-${two(last.day)} '
      '${two(last.hour)}:${two(last.minute)}',
    );
  }

  Future<void> _chooseBackupDirectory(
    BuildContext context,
    VeriFinController controller,
  ) async {
    try {
      final picked = await BackupService.chooseDirectory();
      if (picked == null || !context.mounted) {
        return;
      }
      controller.setBackupDirectory(picked.uri, picked.label);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).chosenBackupDir(picked.label),
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _backupErrorText(AppLocalizations.of(context), error),
            ),
          ),
        );
      }
    }
  }

  Future<void> _backupNow(
    BuildContext context,
    VeriFinController controller,
  ) async {
    if (!controller.backupSettings.hasDirectory) {
      await _chooseBackupDirectory(context, controller);
      if (!context.mounted || !controller.backupSettings.hasDirectory) {
        return;
      }
    }
    try {
      final now = DateTime.now();
      final result = await BackupService.writeManualBackup(
        settings: controller.backupSettings,
        content: controller.exportDataJson(),
        now: now,
        passphrase: controller.backupPassphrase,
      );
      controller.recordBackupTime(now);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).backedUpFile(result.filename),
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _backupErrorText(AppLocalizations.of(context), error),
            ),
          ),
        );
      }
    }
  }

  static String _backupErrorText(AppLocalizations l10n, Object error) {
    final message = error is Exception
        ? error.toString().replaceFirst('Exception: ', '')
        : l10n.backupFailedRetry;
    return message.isEmpty ? l10n.backupFailedRetry : message;
  }

  Future<void> _pickBackupFrequency(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final selected = await showOptionSheet<BackupFrequency>(
      context: context,
      title: AppLocalizations.of(context).pickBackupFrequency,
      values: BackupFrequency.values,
      selected: controller.backupSettings.frequency,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null) {
      controller.setBackupFrequency(selected);
    }
  }

  Future<void> _pickBackupInterval(
    BuildContext context,
    VeriFinController controller,
  ) async {
    const options = <int>[1, 3, 6, 12, 24, 48, 72];
    final selected = await showOptionSheet<int>(
      context: context,
      title: AppLocalizations.of(context).backupIntervalTitle,
      values: options,
      selected: options.contains(controller.backupSettings.intervalHours)
          ? controller.backupSettings.intervalHours
          : 24,
      labelOf: (value) => AppLocalizations.of(context).everyNHoursLabel(value),
    );
    if (selected != null) {
      controller.setBackupIntervalHours(selected);
    }
  }

  Future<void> _pickBackupRetention(
    BuildContext context,
    VeriFinController controller,
  ) async {
    const options = <int>[3, 5, 10, 20, 50];
    final selected = await showOptionSheet<int>(
      context: context,
      title: AppLocalizations.of(context).retentionTitle,
      values: options,
      selected: options.contains(controller.backupSettings.retention)
          ? controller.backupSettings.retention
          : 10,
      labelOf: (value) => AppLocalizations.of(context).latestNCopies(value),
    );
    if (selected != null) {
      controller.setBackupRetention(selected);
    }
  }

  Future<void> _exportData(
    BuildContext context,
    VeriFinController controller,
  ) async {
    try {
      // 未加密→zip（附件不膨胀）、加密→文本信封，统一按字节写入下载目录。
      final prepared = await BackupService.prepare(
        json: controller.exportDataJson(),
        passphrase: controller.backupPassphrase,
        now: DateTime.now(),
        auto: false,
      );
      final saved = await downloadBytesFile(
        filename: prepared.filename,
        bytes: prepared.bytes,
        mimeType: controller.backupEncryptionEnabled
            ? 'application/json'
            : 'application/zip',
      );
      if (saved && context.mounted) {
        final hint = controller.backupEncryptionEnabled
            ? AppLocalizations.of(context).encryptedSuffix
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).exportedTo(hint)),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).exportFailed)),
        );
      }
    }
  }

  /// 从备份字节导入：zip（新版精简备份）直接解包导入；否则按文本处理，加密的先
  /// 解密再导入。返回是否成功导入；用户取消解密返回 false。空/坏文件抛
  /// FormatException 由调用方提示。
  Future<bool> _importBackupBytes(
    BuildContext context,
    VeriFinController controller,
    List<int> bytes,
  ) async {
    if (bytes.isEmpty) {
      throw const FormatException('空备份文件');
    }
    if (looksLikeZipBytes(bytes)) {
      controller.importBackupBytes(bytes);
      return true;
    }
    var text = utf8.decode(bytes);
    if (text.trim().isEmpty) {
      throw const FormatException('空备份文件');
    }
    if (isEncryptedBackup(text)) {
      if (!context.mounted) {
        return false;
      }
      final decrypted = await _decryptForImport(context, controller, text);
      if (decrypted == null) {
        return false;
      }
      text = decrypted;
    }
    controller.importDataJson(text);
    return true;
  }

  /// 处理加密备份的解密：先尝试已保存口令，失败或未设置则弹窗要求输入，
  /// 输入错误可重试。返回明文；用户取消返回 null。
  Future<String?> _decryptForImport(
    BuildContext context,
    VeriFinController controller,
    String content,
  ) async {
    final saved = controller.backupPassphrase;
    if (saved.isNotEmpty) {
      try {
        return await decryptBackup(content, saved);
      } on BackupCryptoException {
        // 已保存口令不匹配（可能来自其他设备/旧口令），改为手动输入。
      }
    }
    var errorText = '';
    while (true) {
      if (!context.mounted) {
        return null;
      }
      final passphrase = await _promptPassphrase(
        context,
        title: AppLocalizations.of(context).enterBackupKeyTitle,
        message: AppLocalizations.of(context).enterBackupKeyMessage,
        errorText: errorText,
      );
      if (passphrase == null) {
        return null;
      }
      try {
        return await decryptBackup(content, passphrase);
      } on BackupCryptoException catch (error) {
        errorText = error.message;
      }
    }
  }

  Future<String?> _promptPassphrase(
    BuildContext context, {
    required String title,
    required String message,
    String errorText = '',
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).backupKeyLabel,
                errorText: errorText.isEmpty ? null : errorText,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(AppLocalizations.of(context).okLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _editBackupPassphrase(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final keyController = TextEditingController();
    final confirmController = TextEditingController();
    final isChange = controller.backupEncryptionEnabled;
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              isChange
                  ? AppLocalizations.of(context).changeKeyTitle
                  : AppLocalizations.of(context).setKeyTitle,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(AppLocalizations.of(context).setKeyMessage),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  autofocus: true,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).keyMinLabel,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).keyRepeatLabel,
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context).commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  final key = keyController.text;
                  if (key.length < 4) {
                    setState(
                      () =>
                          errorText = AppLocalizations.of(context).keyTooShort,
                    );
                    return;
                  }
                  if (key != confirmController.text) {
                    setState(
                      () =>
                          errorText = AppLocalizations.of(context).keyMismatch,
                    );
                    return;
                  }
                  Navigator.of(context).pop(key);
                },
                child: Text(AppLocalizations.of(context).commonSave),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && result.isNotEmpty) {
      controller.setBackupPassphrase(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).keySet)),
        );
      }
    }
  }

  Future<void> _confirmClearPassphrase(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).clearKeyTitle),
        content: Text(AppLocalizations.of(context).clearKeyMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: veriExpense),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).clearLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.clearBackupPassphrase();
    }
  }

  Future<void> _editWebdav(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final existing = controller.webdavConfig;
    final urlController = TextEditingController(text: existing.url);
    final userController = TextEditingController(text: existing.username);
    final passController = TextEditingController(text: existing.password);
    WebdavConfig current() => WebdavConfig(
      url: urlController.text.trim(),
      username: userController.text.trim(),
      password: passController.text,
      autoUpload: existing.autoUpload,
    );

    final saved = await showDialog<WebdavConfig>(
      context: context,
      builder: (context) {
        String? statusText;
        var testing = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(AppLocalizations.of(context).webdavServer),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: urlController,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).webdavUrlLabel,
                      hintText: 'https://dav.example.com/verifin/',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: userController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).webdavUserLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).webdavPassLabel,
                    ),
                  ),
                  if (statusText != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      statusText!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context).commonCancel),
              ),
              TextButton(
                onPressed: testing || urlController.text.trim().isEmpty
                    ? null
                    : () async {
                        setState(() {
                          testing = true;
                          statusText = AppLocalizations.of(
                            context,
                          ).testingConnection;
                        });
                        try {
                          await webdavTestConnection(current());
                          setState(
                            () => statusText = AppLocalizations.of(
                              context,
                            ).connectionOk,
                          );
                        } catch (error) {
                          setState(
                            () => statusText = AppLocalizations.of(
                              context,
                            ).connectionFailed('$error'),
                          );
                        } finally {
                          setState(() => testing = false);
                        }
                      },
                child: Text(AppLocalizations.of(context).testConnection),
              ),
              FilledButton(
                onPressed: () {
                  if (urlController.text.trim().isEmpty) {
                    setState(
                      () => statusText = AppLocalizations.of(
                        context,
                      ).fillServerUrl,
                    );
                    return;
                  }
                  Navigator.of(context).pop(current());
                },
                child: Text(AppLocalizations.of(context).commonSave),
              ),
            ],
          ),
        );
      },
    );
    if (saved != null && saved.isConfigured) {
      controller.setWebdavConfig(saved);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).webdavSaved)),
        );
      }
    }
  }

  Future<void> _uploadToWebdav(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).uploadingWebdav)),
    );
    try {
      final now = DateTime.now();
      final prepared = await BackupService.prepare(
        json: controller.exportDataJson(),
        passphrase: controller.backupPassphrase,
        now: now,
        auto: false,
      );
      await webdavUpload(
        controller.webdavConfig,
        prepared.filename,
        prepared.bytes,
      );
      controller.recordBackupTime(now);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.uploadedFile(prepared.filename))),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.uploadFailed('$error'))),
      );
    }
  }

  Future<void> _restoreFromWebdav(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    List<WebdavRemoteFile> files;
    try {
      files = await webdavList(controller.webdavConfig);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.readFailed('$error'))),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (files.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noWebdavBackups)),
      );
      return;
    }
    files.sort((a, b) {
      final at = a.modifiedAt;
      final bt = b.modifiedAt;
      if (at == null || bt == null) {
        return b.name.compareTo(a.name);
      }
      return bt.compareTo(at);
    });
    final chosen = await showModalBottomSheet<WebdavRemoteFile>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppLocalizations.of(context).chooseRestoreBackup,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final file in files)
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(file.name),
                subtitle: file.modifiedAt == null
                    ? null
                    : Text(file.modifiedAt!.toLocal().toString()),
                onTap: () => Navigator.of(context).pop(file),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).restoreFromThisTitle),
        content: Text(
          AppLocalizations.of(context).restoreFromThisMessage(chosen.name),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).restoreLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      final bytes = await webdavDownload(controller.webdavConfig, chosen.href);
      if (!context.mounted) {
        return;
      }
      final imported = await _importBackupBytes(context, controller, bytes);
      if (imported && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).restoredFromWebdav),
          ),
        );
      }
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.restoreFailedFormat)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.restoreFailedError('$error'))),
      );
    }
  }

  Future<void> _confirmClearWebdav(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).clearWebdavTitle),
        content: Text(AppLocalizations.of(context).clearWebdavMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: veriExpense),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).clearLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.clearWebdavConfig();
    }
  }

  Future<void> _downloadCsvTemplate(BuildContext context) async {
    try {
      final saved = await downloadTextFile(
        filename: 'verifin-import-template.csv',
        content: transactionCsvTemplate(),
        mimeType: 'text/csv',
      );
      if (saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).csvTemplateSaved),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).csvTemplateSaveFailed),
          ),
        );
      }
    }
  }

  Future<void> _importCsv(BuildContext context, VeriFinController controller) {
    return _runCsvImport(
      context,
      controller,
      title: AppLocalizations.of(context).importCsvTitle,
      message: AppLocalizations.of(context).importCsvMessage,
    );
  }

  Future<void> _importFromOtherApp(
    BuildContext context,
    VeriFinController controller,
  ) {
    return _runCsvImport(
      context,
      controller,
      title: AppLocalizations.of(context).importOtherTitle,
      message: AppLocalizations.of(context).importOtherMessage,
    );
  }

  Future<void> _runCsvImport(
    BuildContext context,
    VeriFinController controller, {
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).chooseFile),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      final content = await pickCsvFile();
      if (content == null) {
        return;
      }
      if (content.trim().isEmpty) {
        throw const FormatException('空文件');
      }
      final plan = controller.importTransactionsFromCsv(content);
      if (!context.mounted) {
        return;
      }
      if (plan.importedCount == 0 && plan.errorCount > 0) {
        await _showImportResult(context, plan);
        return;
      }
      final sourceHint =
          plan.source != null && plan.source != ImportSource.veriFin
          ? AppLocalizations.of(context).recognizedAs(plan.source!.label)
          : '';
      final suffix = plan.errorCount > 0
          ? AppLocalizations.of(context).skippedRows(plan.errorCount)
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).importedEntries(plan.importedCount)}$sourceHint$suffix',
          ),
        ),
      );
      if (plan.errorCount > 0) {
        await _showImportResult(context, plan);
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).importFailedWithMessage(error.message),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).importFailedCheckFile),
          ),
        );
      }
    }
  }

  Future<void> _showImportResult(BuildContext context, ImportPlan plan) {
    final lines = plan.errors
        .take(10)
        .map((e) => AppLocalizations.of(context).lineError(e.line, e.message))
        .join('\n');
    final more = plan.errorCount > 10
        ? AppLocalizations.of(context).moreLines(plan.errorCount - 10)
        : '';
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context).importDoneTitle(plan.importedCount),
        ),
        content: SingleChildScrollView(
          child: Text(
            plan.errorCount == 0
                ? AppLocalizations.of(context).allImported
                : AppLocalizations.of(context).skippedFollowing('$lines$more'),
          ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).gotIt),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmImport(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).importLocalTitle),
        content: Text(AppLocalizations.of(context).importLocalMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).chooseFile),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final fileTypeLabel = AppLocalizations.of(context).backupFileTypeLabel;

    try {
      final bytes = await pickBackupBytes(label: fileTypeLabel);
      if (bytes == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      final imported = await _importBackupBytes(context, controller, bytes);
      if (imported && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).importedLocal)),
        );
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).importFailedFormat),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).importFailedCheckFile),
          ),
        );
      }
    }
  }

  Future<void> _confirmReset(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final firstConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).resetAllTitle),
        content: Text(AppLocalizations.of(context).resetAllMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: veriExpense),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).continueLabel),
          ),
        ],
      ),
    );
    if (firstConfirmed != true || !context.mounted) {
      return;
    }

    final secondConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).resetConfirmTitle),
        content: Text(AppLocalizations.of(context).resetConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: veriExpense),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).resetConfirmAction),
          ),
        ],
      ),
    );
    if (secondConfirmed == true) {
      controller.resetAllData();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _UpdateCheckDialog extends StatefulWidget {
  const _UpdateCheckDialog();

  @override
  State<_UpdateCheckDialog> createState() => _UpdateCheckDialogState();
}

class _UpdateCheckDialogState extends State<_UpdateCheckDialog> {
  UpdateCheckResult? _result;
  bool _checking = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _downloading = false;
    });
    final result = await AppPlatformBridge.checkForUpdate();
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _checking = false;
    });
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    final result = await AppPlatformBridge.downloadLatestUpdate();
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _downloading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final hasUpdate = result?.status == UpdateCheckStatus.available;

    return AlertDialog(
      title: Text(AppLocalizations.of(context).checkUpdate),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _VersionInfoRow(
              label: AppLocalizations.of(context).currentVersion,
              value: appVersionLabel,
            ),
            const SizedBox(height: 8),
            _VersionInfoRow(
              label: AppLocalizations.of(context).latestVersion,
              value: _checking
                  ? AppLocalizations.of(context).checkingLabel
                  : _displayVersion(result),
            ),
            const SizedBox(height: 14),
            if (_checking)
              Row(
                children: <Widget>[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(AppLocalizations.of(context).queryingGithub),
                ],
              )
            else
              Text(
                result?.message ??
                    AppLocalizations.of(context).updateCheckFailed,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            if (_downloading) ...<Widget>[
              const SizedBox(height: 14),
              ValueListenableBuilder<UpdateDownloadProgress?>(
                valueListenable: AppPlatformBridge.updateProgress,
                builder: (context, progress, _) {
                  final knownSize = progress != null && progress.totalBytes > 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      LinearProgressIndicator(
                        value: knownSize ? progress.progress : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        knownSize
                            ? AppLocalizations.of(
                                context,
                              ).downloadingPercent(progress.percent)
                            : AppLocalizations.of(context).downloadingLabel,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).closeLabel),
        ),
        if (!_checking && result?.status == UpdateCheckStatus.error)
          TextButton(
            onPressed: _downloading ? null : _check,
            child: Text(AppLocalizations.of(context).retryLabel),
          ),
        if (hasUpdate)
          FilledButton(
            onPressed: _downloading ? null : _download,
            child: Text(
              _downloading
                  ? AppLocalizations.of(context).downloadingShort
                  : AppLocalizations.of(context).downloadNewVersion,
            ),
          ),
      ],
    );
  }

  String _displayVersion(UpdateCheckResult? result) {
    final latest = result?.latestVersion ?? '';
    if (latest.isEmpty) {
      return '--';
    }
    return latest.startsWith('v') ? latest : 'v$latest';
  }
}

class _VersionInfoRow extends StatelessWidget {
  const _VersionInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.54),
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
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
        backgroundImage: imageProviderForSource(profile.avatarDataUrl),
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
