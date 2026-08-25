import 'package:flutter/material.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/entry_sheets.dart';
import 'package:verifin/app/models.dart';

/// “记一笔”页面的静态交互方案。
///
/// 这里只使用演示数据，验证分类宫格、多级分类弹窗和轻量元数据标签的布局；
/// 不连接 Controller、SQLite、KV 或任何平台能力。
class EntryFormPreview extends StatelessWidget {
  const EntryFormPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: const Key('entry_preview_navigator'),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const _EntryFormPreviewBody(),
      ),
    );
  }
}

class _EntryFormPreviewBody extends StatefulWidget {
  const _EntryFormPreviewBody();

  @override
  State<_EntryFormPreviewBody> createState() => _EntryFormPreviewBodyState();
}

class _EntryFormPreviewBodyState extends State<_EntryFormPreviewBody> {
  _PreviewEntryType _type = _PreviewEntryType.expense;
  late final Map<_PreviewEntryType, _PreviewCategory> _selectedCategories =
      <_PreviewEntryType, _PreviewCategory>{
        _PreviewEntryType.expense: _expenseCategories.first,
        _PreviewEntryType.income: _incomeCategories.first,
        _PreviewEntryType.transfer: _transferCategories.first,
      };
  bool _reimbursable = false;
  bool _currencyDetailsVisible = false;
  int _attachmentSequence = 0;
  List<_PreviewAttachment> _attachments = <_PreviewAttachment>[];
  int _newTagSequence = 0;
  List<Tag> _availableTags = <Tag>[
    const Tag(id: 'daily', label: '日常'),
    const Tag(id: 'food', label: '聚餐'),
    const Tag(id: 'work', label: '工作'),
    const Tag(id: 'commute', label: '通勤'),
  ];
  List<String> _selectedTagIds = <String>['daily', 'food'];

  List<_PreviewCategory> get _categories => switch (_type) {
    _PreviewEntryType.expense => _expenseCategories,
    _PreviewEntryType.income => _incomeCategories,
    _PreviewEntryType.transfer => _transferCategories,
  };

  _PreviewCategory get _selectedCategory => _selectedCategories[_type]!;

  Color get _accent => switch (_type) {
    _PreviewEntryType.expense => veriExpense,
    _PreviewEntryType.income => veriIncome,
    _PreviewEntryType.transfer => veriRoyal,
  };

  String get _amountPrefix => switch (_type) {
    _PreviewEntryType.expense => '−',
    _PreviewEntryType.income => '+',
    _PreviewEntryType.transfer => '',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('entry_form_preview'),
      backgroundColor: scheme.surface,
      bottomNavigationBar: _BottomSaveBar(onSave: _showSavedFeedback),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
          children: <Widget>[
            const _EntryHeader(),
            const SizedBox(height: 12),
            _TypeSelector(
              selected: _type,
              onChanged: (value) {
                setState(() {
                  _type = value;
                  _currencyDetailsVisible = false;
                });
              },
            ),
            const SizedBox(height: 16),
            _AmountHero(
              prefix: _amountPrefix,
              color: _accent,
              onTap: () => _showPreviewFeedback('预览：重新输入金额'),
            ),
            const SizedBox(height: 14),
            Text(
              '分类',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 9),
            _CategoryGrid(
              categories: _categories,
              selected: _selectedCategory,
              accent: _accent,
              onSelected: _handleTopCategoryTap,
              onOpenBranch: _openCategoryBranch,
              onOpenAll: _openAllCategories,
            ),
            const SizedBox(height: 18),
            _ExistingPrimaryFields(
              transfer: _type == _PreviewEntryType.transfer,
              onAccountTap: () => _showPreviewFeedback(
                _type == _PreviewEntryType.transfer
                    ? '预览：选择转出 / 转入账户'
                    : '预览：选择账户',
              ),
              onNoteTap: () => _showPreviewFeedback('预览：填写备注'),
              onFeeTap: () => _showPreviewFeedback('预览：填写手续费'),
            ),
            const SizedBox(height: 14),
            Text(
              '更多信息',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.48),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              key: const Key('entry_metadata_chips'),
              spacing: 7,
              runSpacing: 7,
              children: <Widget>[
                _MetadataChip(
                  chipKey: const Key('metadata_date'),
                  icon: Icons.calendar_today_outlined,
                  label: '8月25日 · 今天',
                  onTap: () => _showPreviewFeedback('预览：选择日期'),
                ),
                _MetadataChip(
                  chipKey: const Key('metadata_time'),
                  icon: Icons.schedule_rounded,
                  label: '10:35',
                  onTap: () => _showPreviewFeedback('预览：选择时间'),
                ),
                _MetadataChip(
                  chipKey: const Key('metadata_tags'),
                  icon: Icons.sell_outlined,
                  label: _selectedTagIds.isEmpty
                      ? '标签'
                      : '标签 ${_selectedTagIds.length}',
                  selected: _selectedTagIds.isNotEmpty,
                  onTap: _openTagPicker,
                ),
                if (_type == _PreviewEntryType.expense)
                  _MetadataChip(
                    chipKey: const Key('metadata_reimbursable'),
                    icon: Icons.receipt_long_outlined,
                    label: '待报销',
                    selected: _reimbursable,
                    onTap: () {
                      setState(() => _reimbursable = !_reimbursable);
                    },
                  ),
                _AttachmentMetadataAnchor(
                  attachmentCount: _attachments.length,
                  onAdd: _addPreviewAttachment,
                ),
                _MetadataChip(
                  chipKey: const Key('metadata_currency'),
                  icon: Icons.currency_exchange_rounded,
                  label: 'CNY',
                  selected: _currencyDetailsVisible,
                  onTap: () {
                    setState(
                      () => _currencyDetailsVisible = !_currencyDetailsVisible,
                    );
                  },
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: _attachments.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _AttachmentPreviewStrip(
                        attachments: _attachments,
                        onRemove: _removePreviewAttachment,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: _currencyDetailsVisible
                  ? const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: _CurrencyDetails(),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTopCategoryTap(_PreviewCategory category) {
    final selectedRoot = _rootFor(_categories, _selectedCategory.id);
    if (selectedRoot?.id == category.id && category.children.isNotEmpty) {
      _openCategoryBranch(category);
      return;
    }
    setState(() => _selectedCategories[_type] = category);
  }

  Future<void> _openCategoryBranch(_PreviewCategory category) async {
    await _showCategoryPicker(
      roots: <_PreviewCategory>[category],
      title: '选择${category.label}分类',
    );
  }

  Future<void> _openAllCategories() async {
    await _showCategoryPicker(roots: _categories, title: '全部分类');
  }

  Future<void> _showCategoryPicker({
    required List<_PreviewCategory> roots,
    required String title,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
      ),
      builder: (_) => CategoryPickerSheet(
        categories: _toModelCategories(roots, _type.entryType),
        selectedId: _selectedCategory.id,
        title: title,
      ),
    );
    if (!mounted || selected == null) return;
    final category = _findCategory(_categories, selected);
    if (category != null) {
      setState(() => _selectedCategories[_type] = category);
    }
  }

  Future<void> _openTagPicker() async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
          ),
          child: TagSelectorSheet(
            tags: _availableTags,
            selectedIds: _selectedTagIds,
            onCreateTag: () => _createPreviewTag(sheetContext),
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedTagIds = selected);
  }

  Future<Tag?> _createPreviewTag(BuildContext sheetContext) async {
    final label = await showDialog<String>(
      context: sheetContext,
      useRootNavigator: false,
      builder: (_) => const _CreateTagDialog(),
    );
    if (!mounted || label == null) return null;
    for (final tag in _availableTags) {
      if (tag.label == label) return tag;
    }
    final tag = Tag(id: 'preview_${_newTagSequence++}', label: label);
    setState(() => _availableTags = <Tag>[..._availableTags, tag]);
    return tag;
  }

  void _addPreviewAttachment() {
    final sequence = _attachmentSequence++;
    final template =
        _previewAttachmentCatalog[sequence % _previewAttachmentCatalog.length];
    setState(() {
      _attachments = <_PreviewAttachment>[
        ..._attachments,
        template.withId('${template.id}_$sequence'),
      ];
    });
  }

  void _removePreviewAttachment(String attachmentId) {
    setState(() {
      _attachments = _attachments
          .where((attachment) => attachment.id != attachmentId)
          .toList();
    });
  }

  void _showSavedFeedback() {
    _showPreviewFeedback('预览：保存记账草稿');
  }

  void _showPreviewFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text(message),
        ),
      );
  }
}

class _EntryHeader extends StatelessWidget {
  const _EntryHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: '返回',
            onPressed: () {},
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '日常账本',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '记账详情',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.46),
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

class _BottomSaveBar extends StatelessWidget {
  const _BottomSaveBar({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: ColoredBox(
        key: const Key('entry_preview_save_bar'),
        color: scheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: FilledButton(
            key: const Key('entry_preview_save_bottom'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder(),
              textStyle: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            onPressed: onSave,
            child: const Text('保存'),
          ),
        ),
      ),
    );
  }
}

class _CreateTagDialog extends StatefulWidget {
  const _CreateTagDialog();

  @override
  State<_CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends State<_CreateTagDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建标签'),
      content: TextField(
        key: const Key('preview_tag_input'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '标签名称'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('preview_tag_add'),
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isNotEmpty) Navigator.of(context).pop(value);
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final _PreviewEntryType selected;
  final ValueChanged<_PreviewEntryType> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(veriRadiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: <Widget>[
            for (final type in _PreviewEntryType.values)
              Expanded(
                child: _TypeButton(
                  type: type,
                  selected: selected == type,
                  onTap: () => onChanged(type),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final _PreviewEntryType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = switch (type) {
      _PreviewEntryType.expense => veriExpense,
      _PreviewEntryType.income => veriIncome,
      _PreviewEntryType.transfer => veriRoyal,
    };
    return Material(
      color: selected ? scheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: InkWell(
        key: Key('entry_type_${type.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(veriRadiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            type.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? accent
                  : scheme.onSurface.withValues(alpha: 0.48),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountHero extends StatelessWidget {
  const _AmountHero({
    required this.prefix,
    required this.color,
    required this.onTap,
  });

  final String prefix;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('entry_preview_amount'),
        borderRadius: BorderRadius.circular(veriRadiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$prefix 68.00'.trim(),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.accent,
    required this.onSelected,
    required this.onOpenBranch,
    required this.onOpenAll,
  });

  final List<_PreviewCategory> categories;
  final _PreviewCategory selected;
  final Color accent;
  final ValueChanged<_PreviewCategory> onSelected;
  final ValueChanged<_PreviewCategory> onOpenBranch;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final selectedRoot = _rootFor(categories, selected.id);
    return GridView.builder(
      key: const Key('category_grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 6,
        mainAxisExtent: 40,
      ),
      itemBuilder: (context, index) {
        if (index == categories.length) {
          return _AllCategoriesTile(onTap: onOpenAll);
        }
        final category = categories[index];
        final isSelected = selectedRoot?.id == category.id;
        return _CategoryTile(
          category: category,
          displayLabel: isSelected && selected.id != category.id
              ? selected.label
              : category.label,
          selected: isSelected,
          accent: accent,
          onTap: () => onSelected(category),
          onOpenBranch: category.children.isNotEmpty && isSelected
              ? () => onOpenBranch(category)
              : null,
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.displayLabel,
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.onOpenBranch,
  });

  final _PreviewCategory category;
  final String displayLabel;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onOpenBranch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Align(
          child: SizedBox(
            height: 31,
            width: double.infinity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: ShapeDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.08)
                    : scheme.surfaceContainerLow,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: selected
                        ? accent.withValues(alpha: 0.50)
                        : scheme.outlineVariant.withValues(alpha: 0.58),
                  ),
                ),
              ),
              child: Material(
                key: Key('category_capsule_${category.id}'),
                color: Colors.transparent,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('category_tile_${category.id}'),
                  customBorder: const StadiumBorder(),
                  onTap: onTap,
                  child: Center(
                    child: Row(
                      key: Key('category_content_${category.id}'),
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          category.icon,
                          size: 16,
                          color: selected
                              ? accent
                              : scheme.onSurface.withValues(alpha: 0.68),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: selected ? accent : scheme.onSurface,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (onOpenBranch != null)
          Positioned(
            key: Key('category_branch_badge_position_${category.id}'),
            right: -1,
            bottom: 0,
            child: Material(
              color: accent,
              elevation: 1,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('category_branch_menu_${category.id}'),
                customBorder: const CircleBorder(),
                onTap: onOpenBranch,
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AllCategoriesTile extends StatelessWidget {
  const _AllCategoriesTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      child: SizedBox(
        height: 31,
        width: double.infinity,
        child: Material(
          key: const Key('category_capsule_all'),
          color: scheme.surfaceContainerLow,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('category_tile_all'),
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.grid_view_rounded,
                  size: 16,
                  color: scheme.onSurface.withValues(alpha: 0.48),
                ),
                const SizedBox(width: 4),
                Text(
                  '全部',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.56),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExistingPrimaryFields extends StatelessWidget {
  const _ExistingPrimaryFields({
    required this.transfer,
    required this.onAccountTap,
    required this.onNoteTap,
    required this.onFeeTap,
  });

  final bool transfer;
  final VoidCallback onAccountTap;
  final VoidCallback onNoteTap;
  final VoidCallback onFeeTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (transfer) ...<Widget>[
          SelectField(
            key: const Key('account_dropdown'),
            label: '转出账户',
            value: '现金账户 (2,436 ¥)',
            leading: const AccountIconBox(iconCode: 'cash', size: 26),
            onTap: onAccountTap,
          ),
          const SizedBox(height: 10),
          SelectField(
            key: const Key('to_account_dropdown'),
            label: '转入账户',
            value: '招商银行卡 (8,520 ¥)',
            leading: const AccountIconBox(iconCode: 'bank', size: 26),
            onTap: onAccountTap,
          ),
          const SizedBox(height: 10),
          SelectField(
            key: const Key('fee_field'),
            label: '手续费',
            value: '无手续费，点击填写',
            icon: Icons.paid_outlined,
            onTap: onFeeTap,
          ),
        ] else
          SelectField(
            key: const Key('account_dropdown'),
            label: '账户',
            value: '日常支出 (2,436 ¥)',
            leading: const AccountIconBox(iconCode: 'cash', size: 26),
            onTap: onAccountTap,
          ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('entry_note_field'),
          maxLines: 1,
          onTap: onNoteTap,
          decoration: const InputDecoration(
            labelText: '备注',
            hintText: '点击添加备注',
            prefixIcon: Icon(Icons.notes),
          ),
        ),
      ],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({
    required this.chipKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final Key chipKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? veriRoyal : scheme.onSurface;
    return Material(
      color: selected
          ? veriRoyal.withValues(alpha: 0.10)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        key: chipKey,
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: color.withValues(alpha: 0.72)),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color.withValues(alpha: selected ? 0.92 : 0.68),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentMetadataAnchor extends StatelessWidget {
  const _AttachmentMetadataAnchor({
    required this.attachmentCount,
    required this.onAdd,
  });

  final int attachmentCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, -6),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(veriRadiusMd),
          ),
        ),
      ),
      menuChildren: <Widget>[
        MenuItemButton(
          leadingIcon: const Icon(Icons.photo_camera_outlined),
          onPressed: onAdd,
          child: const Text('拍照'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.photo_library_outlined),
          onPressed: onAdd,
          child: const Text('从相册选择'),
        ),
      ],
      builder: (context, controller, child) => _MetadataChip(
        chipKey: const Key('metadata_attachments'),
        icon: Icons.add_photo_alternate_outlined,
        label: attachmentCount == 0 ? '附件' : '附件 $attachmentCount',
        selected: attachmentCount > 0 || controller.isOpen,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _AttachmentPreviewStrip extends StatelessWidget {
  const _AttachmentPreviewStrip({
    required this.attachments,
    required this.onRemove,
  });

  final List<_PreviewAttachment> attachments;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('attachment_preview_strip'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(veriRadiusMd),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '已添加 ${attachments.length} 个附件',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.52),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: attachments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final attachment = attachments[index];
                return Tooltip(
                  message: attachment.name,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(veriRadiusSm),
                        child: ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: SizedBox(
                            key: Key('attachment_preview_$index'),
                            width: 60,
                            height: 60,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                attachment.assetPath,
                                package: 'verifin',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Material(
                          color: scheme.inverseSurface,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: Key('attachment_remove_$index'),
                            customBorder: const CircleBorder(),
                            onTap: () => onRemove(attachment.id),
                            child: SizedBox(
                              key: Key('attachment_remove_size_$index'),
                              width: 16,
                              height: 16,
                              child: Icon(
                                Icons.close_rounded,
                                size: 10,
                                color: scheme.onInverseSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewAttachment {
  const _PreviewAttachment({
    required this.id,
    required this.assetPath,
    required this.name,
  });

  final String id;
  final String assetPath;
  final String name;

  _PreviewAttachment withId(String nextId) =>
      _PreviewAttachment(id: nextId, assetPath: assetPath, name: name);
}

const List<_PreviewAttachment> _previewAttachmentCatalog = <_PreviewAttachment>[
  _PreviewAttachment(
    id: 'alipay',
    assetPath: 'assets/import_icons/alipay.png',
    name: '支付宝账单截图.jpg',
  ),
  _PreviewAttachment(
    id: 'wechat',
    assetPath: 'assets/import_icons/wechat.png',
    name: '微信支付截图.jpg',
  ),
  _PreviewAttachment(
    id: 'mint',
    assetPath: 'assets/import_icons/mint.png',
    name: '消费凭证.jpg',
  ),
  _PreviewAttachment(
    id: 'qianji',
    assetPath: 'assets/import_icons/qianji.png',
    name: '电子小票.jpg',
  ),
];

class _CurrencyDetails extends StatelessWidget {
  const _CurrencyDetails();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('currency_details_panel'),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: veriRoyal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(veriRadiusMd),
        border: Border.all(color: veriRoyal.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.currency_exchange_rounded,
            size: 19,
            color: veriRoyal,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '本单无需换算',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '交易币种与账本本位币均为 CNY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.48),
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

enum _PreviewEntryType { expense, income, transfer }

extension on _PreviewEntryType {
  String get label => switch (this) {
    _PreviewEntryType.expense => '支出',
    _PreviewEntryType.income => '收入',
    _PreviewEntryType.transfer => '转账',
  };

  EntryType get entryType => switch (this) {
    _PreviewEntryType.expense => EntryType.expense,
    _PreviewEntryType.income => EntryType.income,
    _PreviewEntryType.transfer => EntryType.transfer,
  };
}

class _PreviewCategory {
  const _PreviewCategory({
    required this.id,
    required this.label,
    required this.icon,
    this.iconCode = 'category',
    this.children = const <_PreviewCategory>[],
  });

  final String id;
  final String label;
  final IconData icon;
  final String iconCode;
  final List<_PreviewCategory> children;

  bool contains(String categoryId) {
    return id == categoryId ||
        children.any((child) => child.contains(categoryId));
  }
}

_PreviewCategory? _rootFor(List<_PreviewCategory> roots, String categoryId) {
  for (final root in roots) {
    if (root.contains(categoryId)) return root;
  }
  return null;
}

_PreviewCategory? _findCategory(
  List<_PreviewCategory> categories,
  String categoryId,
) {
  for (final category in categories) {
    if (category.id == categoryId) return category;
    final child = _findCategory(category.children, categoryId);
    if (child != null) return child;
  }
  return null;
}

List<Category> _toModelCategories(
  List<_PreviewCategory> roots,
  EntryType type,
) {
  final result = <Category>[];
  void addBranch(_PreviewCategory category, String? parentId) {
    result.add(
      Category(
        id: category.id,
        label: category.label,
        type: type,
        iconCode: category.iconCode,
        parentId: parentId,
      ),
    );
    for (final child in category.children) {
      addBranch(child, category.id);
    }
  }

  for (final root in roots) {
    addBranch(root, null);
  }
  return result;
}

const List<_PreviewCategory> _expenseCategories = <_PreviewCategory>[
  _PreviewCategory(
    id: 'dining',
    label: '餐饮',
    icon: Icons.restaurant_rounded,
    iconCode: 'dining',
    children: <_PreviewCategory>[
      _PreviewCategory(
        id: 'dining-breakfast',
        label: '早餐',
        icon: Icons.bakery_dining_rounded,
      ),
      _PreviewCategory(
        id: 'dining-meal',
        label: '正餐',
        icon: Icons.rice_bowl_rounded,
        children: <_PreviewCategory>[
          _PreviewCategory(
            id: 'dining-work-meal',
            label: '工作午餐',
            icon: Icons.business_center_outlined,
          ),
          _PreviewCategory(
            id: 'dining-family-meal',
            label: '家庭聚餐',
            icon: Icons.groups_2_outlined,
          ),
        ],
      ),
      _PreviewCategory(
        id: 'dining-coffee',
        label: '咖啡茶饮',
        icon: Icons.local_cafe_rounded,
      ),
      _PreviewCategory(
        id: 'dining-takeout',
        label: '外卖',
        icon: Icons.delivery_dining_rounded,
      ),
    ],
  ),
  _PreviewCategory(
    id: 'shopping',
    label: '购物',
    icon: Icons.shopping_bag_rounded,
    iconCode: 'shopping',
  ),
  _PreviewCategory(
    id: 'daily',
    label: '日用',
    icon: Icons.sanitizer_outlined,
    children: <_PreviewCategory>[
      _PreviewCategory(
        id: 'daily-cleaning',
        label: '清洁用品',
        icon: Icons.cleaning_services_outlined,
      ),
      _PreviewCategory(
        id: 'daily-care',
        label: '个人护理',
        icon: Icons.spa_outlined,
      ),
    ],
  ),
  _PreviewCategory(
    id: 'transport',
    label: '交通',
    icon: Icons.directions_subway_rounded,
    iconCode: 'transport',
  ),
  _PreviewCategory(
    id: 'housing',
    label: '居住',
    icon: Icons.home_work_outlined,
    iconCode: 'housing',
  ),
  _PreviewCategory(
    id: 'medical',
    label: '医疗',
    icon: Icons.medical_services_outlined,
    iconCode: 'medical',
  ),
  _PreviewCategory(
    id: 'entertainment',
    label: '娱乐',
    icon: Icons.sports_esports_rounded,
    iconCode: 'entertainment',
  ),
  _PreviewCategory(
    id: 'communication',
    label: '通讯',
    icon: Icons.smartphone_rounded,
  ),
];

const List<_PreviewCategory> _incomeCategories = <_PreviewCategory>[
  _PreviewCategory(
    id: 'salary',
    label: '工资',
    icon: Icons.payments_rounded,
    iconCode: 'salary',
    children: <_PreviewCategory>[
      _PreviewCategory(
        id: 'salary-base',
        label: '基本工资',
        icon: Icons.account_balance_wallet_outlined,
      ),
      _PreviewCategory(
        id: 'salary-performance',
        label: '绩效奖金',
        icon: Icons.workspace_premium_outlined,
      ),
    ],
  ),
  _PreviewCategory(
    id: 'bonus',
    label: '奖金',
    icon: Icons.redeem_rounded,
    iconCode: 'bonus',
  ),
  _PreviewCategory(
    id: 'interest',
    label: '利息',
    icon: Icons.savings_outlined,
    iconCode: 'interest',
  ),
  _PreviewCategory(
    id: 'part-time',
    label: '兼职',
    icon: Icons.work_outline_rounded,
    iconCode: 'work',
  ),
  _PreviewCategory(
    id: 'investment',
    label: '投资',
    icon: Icons.trending_up_rounded,
    iconCode: 'investment',
  ),
];

const List<_PreviewCategory> _transferCategories = <_PreviewCategory>[
  _PreviewCategory(
    id: 'account-transfer',
    label: '账户互转',
    icon: Icons.swap_horiz_rounded,
  ),
  _PreviewCategory(
    id: 'repayment',
    label: '信用还款',
    icon: Icons.credit_card_rounded,
    iconCode: 'credit',
  ),
  _PreviewCategory(
    id: 'cash-transfer',
    label: '现金存取',
    icon: Icons.local_atm_rounded,
    iconCode: 'cash',
  ),
];
