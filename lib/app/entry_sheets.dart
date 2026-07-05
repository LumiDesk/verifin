import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'category_tree.dart';
import 'common_widgets.dart';
import 'demo_data.dart';
import 'ledger_math.dart';
import 'models.dart';
import '../l10n/app_localizations.dart';

class NumberPadSheet extends StatefulWidget {
  const NumberPadSheet({
    super.key,
    required this.title,
    this.initialAmount,
    this.allowNegative = false,
    this.allowZero = false,
    this.hapticsEnabled = true,
  });

  final String title;
  final double? initialAmount;
  final bool allowNegative;
  final bool allowZero;
  final bool hapticsEnabled;

  @override
  State<NumberPadSheet> createState() => _NumberPadSheetState();
}

class _NumberPadSheetState extends State<NumberPadSheet> {
  late String _input = widget.initialAmount == null
      ? ''
      : formatAmount(widget.initialAmount!);

  double get _amount => double.tryParse(_input) ?? 0;

  @override
  Widget build(BuildContext context) {
    final keys = <String>[
      '1',
      '2',
      '3',
      '⌫',
      '4',
      '5',
      '6',
      'C',
      '7',
      '8',
      '9',
      '.',
      '0',
      '00',
      widget.allowNegative ? '+/-' : '',
      'OK',
    ];

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: veriPageMaxWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              0,
              14,
              14 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(veriRadiusMd),
                  ),
                  child: Text(
                    _input.isEmpty ? '0' : _input,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 4 / 3,
                  ),
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    final value = keys[index];
                    if (value.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final isOk = value == 'OK';
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final keyColor = isDark
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : const Color(0xFFEAF0F8);
                    final keyTextColor = isDark
                        ? Colors.white.withValues(alpha: 0.94)
                        : veriInk;
                    final canSubmit = _canSubmit;
                    final enabled = !isOk || canSubmit;
                    final okDisabledBackground = isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : const Color(0xFFD9E5F3);
                    final okDisabledForeground = isDark
                        ? Colors.white.withValues(alpha: 0.46)
                        : const Color(0xFF6B7C93);
                    final buttonBackground = isOk
                        ? (enabled ? veriRoyal : okDisabledBackground)
                        : keyColor;
                    final buttonForeground = isOk
                        ? (enabled ? Colors.white : okDisabledForeground)
                        : keyTextColor;
                    return FilledButton.tonal(
                      key: isOk
                          ? const Key('number_pad_ok')
                          : Key('number_key_$value'),
                      style: FilledButton.styleFrom(
                        backgroundColor: buttonBackground,
                        foregroundColor: buttonForeground,
                        disabledBackgroundColor: isOk
                            ? okDisabledBackground
                            : keyColor.withValues(alpha: 0.42),
                        disabledForegroundColor: isOk
                            ? okDisabledForeground
                            : keyTextColor.withValues(alpha: 0.36),
                        minimumSize: const Size(64, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(veriRadiusMd),
                        ),
                      ),
                      onPressed: isOk && !canSubmit
                          ? null
                          : () => _handleKey(value),
                      child: value == '⌫'
                          ? Icon(
                              Icons.backspace_outlined,
                              color: buttonForeground,
                            )
                          : Text(
                              value,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: buttonForeground,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canSubmit {
    if (widget.allowNegative) {
      return widget.allowZero || !isZeroAmount(_amount);
    }
    return widget.allowZero ? _amount >= 0 : _amount > 0;
  }

  void _handleKey(String value) {
    if (widget.hapticsEnabled) {
      if (value == 'OK') {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
    if (value == 'OK') {
      Navigator.of(context).pop(_amount);
      return;
    }

    setState(() {
      if (value == 'C') {
        _input = '';
        return;
      }
      if (value == '⌫') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
        return;
      }
      if (value == '+/-') {
        if (_input.startsWith('-')) {
          _input = _input.substring(1);
        } else if (_input.isNotEmpty && !isZeroAmount(_amount)) {
          _input = '-$_input';
        }
        return;
      }
      if (value == '.') {
        if (_input.contains('.')) {
          return;
        }
        _input = _input.isEmpty ? '0.' : '$_input.';
        return;
      }
      if (_input.contains('.')) {
        final decimalLength = _input.split('.').last.length;
        if (decimalLength >= 2) {
          return;
        }
      }
      if (_input == '0' && value != '00') {
        _input = value;
      } else if (_input == '-0' && value != '00') {
        _input = '-$value';
      } else {
        _input = '$_input$value';
      }
    });
  }
}

/// 记账时选择分类的底部弹窗。支持多级分类：父分类可展开/收起，
/// 子分类缩进显示，点选任意层级的分类（父或子）都会返回其 id。
class CategoryPickerSheet extends StatefulWidget {
  const CategoryPickerSheet({
    super.key,
    required this.categories,
    required this.selectedId,
  });

  /// 当前类型下的全部分类（含各级子分类），由调用方按类型过滤后传入。
  final List<Category> categories;
  final String selectedId;

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  late final Set<String> _collapsed;

  @override
  void initState() {
    super.initState();
    // 默认展开全部；但收起与当前选中项无关的分支，保持已选项可见。
    _collapsed = <String>{};
  }

  /// 按折叠状态前序展开可见节点。
  List<CategoryNode> _visibleNodes() {
    final result = <CategoryNode>[];
    final visited = <String>{};
    void walk(String? parentId, int depth) {
      final children = widget.categories.where((c) => c.parentId == parentId);
      for (final child in children) {
        if (!visited.add(child.id)) {
          continue;
        }
        result.add(CategoryNode(category: child, depth: depth));
        final hasKids = widget.categories.any((c) => c.parentId == child.id);
        if (hasKids && !_collapsed.contains(child.id)) {
          walk(child.id, depth + 1);
        }
      }
    }

    walk(null, 0);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _visibleNodes();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppLocalizations.of(context).categoryAll,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: nodes.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, index) {
                final node = nodes[index];
                final category = node.category;
                final isSelected = category.id == widget.selectedId;
                final hasKids = widget.categories.any(
                  (c) => c.parentId == category.id,
                );
                final collapsed = _collapsed.contains(category.id);
                return Material(
                  color: isSelected
                      ? veriRoyal.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(veriRadiusSm),
                  child: ListTile(
                    minTileHeight: 48,
                    dense: true,
                    contentPadding: EdgeInsets.only(
                      left: 8 + node.depth * 20,
                      right: 8,
                    ),
                    leading: VeriIconBox(
                      icon: iconForCode(category.iconCode),
                      color: colorForType(category.type),
                      size: 32,
                    ),
                    title: Text(
                      category.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    trailing: hasKids
                        ? IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 22,
                            icon: Icon(
                              collapsed
                                  ? Icons.chevron_right
                                  : Icons.expand_more,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                            onPressed: () => setState(() {
                              if (collapsed) {
                                _collapsed.remove(category.id);
                              } else {
                                _collapsed.add(category.id);
                              }
                            }),
                          )
                        : (isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: veriRoyal,
                                  size: 18,
                                )
                              : null),
                    onTap: () => Navigator.of(context).pop(category.id),
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

/// 记账时给交易多选标签的底部弹窗。展示已有标签的 FilterChip 供多选，
/// 并可即时新建标签。点「完成」返回选中的标签 id 列表（取消返回 null）。
class TagSelectorSheet extends StatefulWidget {
  const TagSelectorSheet({
    super.key,
    required this.tags,
    required this.selectedIds,
    required this.onCreateTag,
  });

  final List<Tag> tags;
  final List<String> selectedIds;

  /// 新建标签：由调用方弹出输入框、创建标签，并返回新标签（重名返回已有，取消返回 null）。
  final Future<Tag?> Function() onCreateTag;

  @override
  State<TagSelectorSheet> createState() => _TagSelectorSheetState();
}

class _TagSelectorSheetState extends State<TagSelectorSheet> {
  late final Set<String> _selected = <String>{...widget.selectedIds};
  late List<Tag> _tags = <Tag>[...widget.tags];

  Future<void> _createTag() async {
    final tag = await widget.onCreateTag();
    if (!mounted || tag == null) {
      return;
    }
    setState(() {
      if (!_tags.any((t) => t.id == tag.id)) {
        _tags = <Tag>[..._tags, tag];
      }
      _selected.add(tag.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                AppLocalizations.of(context).tagPickerTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(_selected.toList()),
                child: Text(AppLocalizations.of(context).commonDone),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final tag in _tags)
                    FilterChip(
                      label: Text(tag.label),
                      selected: _selected.contains(tag.id),
                      onSelected: (value) => setState(() {
                        if (value) {
                          _selected.add(tag.id);
                        } else {
                          _selected.remove(tag.id);
                        }
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(AppLocalizations.of(context).tagCreateTitle),
                    onPressed: _createTag,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
