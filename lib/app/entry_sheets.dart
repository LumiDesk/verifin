import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'calc_expression.dart';
import 'category_tree.dart';
import 'common_widgets.dart';
import 'ledger_math.dart';
import 'models.dart';
import '../l10n/app_localizations.dart';

/// 数字键盘弹层组件体。**勿直接实例化**——统一走 `pages/sheets.dart` 的
/// `showNumberPadSheet`（包装了 showModalBottomSheet 与样式约定）。
class NumberPadSheet extends StatefulWidget {
  const NumberPadSheet({
    super.key,
    required this.title,
    this.initialAmount,
    this.allowNegative = false,
    this.allowZero = false,
    this.hapticsEnabled = true,
    this.maxAmount,
  });

  final String title;
  final double? initialAmount;
  final bool allowNegative;
  final bool allowZero;
  final bool hapticsEnabled;

  /// 可选金额上限：非空时输入框下方展示「最多 {max}」提示（超上限时变红），
  /// 点 OK 确认的结果会被封顶到该值。用于退款「剩余可退」等有上限的输入。
  final double? maxAmount;

  @override
  State<NumberPadSheet> createState() => _NumberPadSheetState();
}

class _NumberPadSheetState extends State<NumberPadSheet> {
  late String _input = widget.initialAmount == null
      ? ''
      : formatAmount(widget.initialAmount!);

  /// 求值当前输入（可能是 `500+800` 这类算式）；不完整/无效时为 null。
  double? get _result => evaluateAmountExpression(_input);
  double get _amount => _result ?? 0;

  /// 输入是否为算式（含运算符）——决定是否展示右下角结果预览。
  bool get _hasOperator => amountExpressionHasOperator(_input);

  @override
  Widget build(BuildContext context) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        _input.isEmpty ? '0' : _input,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      // 算式模式在右下角展示浅色结果预览；不完整则提示。
                      if (_hasOperator) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          _result == null
                              ? AppLocalizations.of(context).calcIncomplete
                              : '= ${formatAmount(_result!)}',
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.maxAmount != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).numberPadMax(formatAmount(widget.maxAmount!)),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _amount > widget.maxAmount! + 0.0001
                            ? veriExpense
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                        fontWeight: _amount > widget.maxAmount! + 0.0001
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                // 5 行键盘：前 3 行满 4 列，最后两行左侧为 2×3 数字区
                // （1 2 3 / 00 0 .，小数点落在 0 右边），右下角 OK 占竖两格。
                // 用固定网格无法跨格，故手写布局。
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 8.0;
                    final cellW = (constraints.maxWidth - spacing * 3) / 4;
                    final cellH = cellW * 3 / 4;
                    Widget cell(String v) => SizedBox(
                      width: cellW,
                      height: cellH,
                      child: _buildKey(context, v),
                    );
                    Widget keyRow(List<String> values) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (var i = 0; i < values.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: spacing),
                          cell(values[i]),
                        ],
                      ],
                    );
                    final leftBottom = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        keyRow(<String>['1', '2', '3']),
                        const SizedBox(height: spacing),
                        keyRow(<String>['00', '0', '.']),
                      ],
                    );
                    final rightBottom = SizedBox(
                      width: cellW,
                      height: cellH * 2 + spacing,
                      child: _buildKey(context, 'OK'),
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        keyRow(<String>['C', '⌫', '÷', '×']),
                        const SizedBox(height: spacing),
                        keyRow(<String>['7', '8', '9', '-']),
                        const SizedBox(height: spacing),
                        keyRow(<String>['4', '5', '6', '+']),
                        const SizedBox(height: spacing),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            leftBottom,
                            const SizedBox(width: spacing),
                            rightBottom,
                          ],
                        ),
                      ],
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

  /// 单个按键：尺寸由外层 SizedBox 约束，按分组配色。
  Widget _buildKey(BuildContext context, String value) {
    final isOk = value == 'OK';
    final isOperator = _operators.contains(value);
    final isClear = value == 'C' || value == '⌫';
    final isDot = value == '.';
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    // 按键分组配色：运算符=强调蓝、清除/退格=红（比运算符更深、
    // 提示可清除）、小数点=琥珀、数字=浅底，彼此一眼可辨。
    final Color buttonBackground;
    final Color buttonForeground;
    if (isOk) {
      buttonBackground = enabled ? veriRoyal : okDisabledBackground;
      buttonForeground = enabled ? Colors.white : okDisabledForeground;
    } else if (isOperator) {
      buttonBackground = isDark
          ? veriRoyal.withValues(alpha: 0.28)
          : const Color(0xFFDCE7FA);
      buttonForeground = isDark
          ? Colors.white.withValues(alpha: 0.94)
          : veriRoyal;
    } else if (isClear) {
      buttonBackground = isDark
          ? veriExpense.withValues(alpha: 0.26)
          : const Color(0xFFF6D2D8);
      buttonForeground = isDark ? const Color(0xFFFFAAB6) : veriExpense;
    } else if (isDot) {
      buttonBackground = isDark
          ? veriWarning.withValues(alpha: 0.26)
          : const Color(0xFFFBEAC6);
      buttonForeground = isDark ? veriWarning : const Color(0xFF9A6A12);
    } else {
      buttonBackground = keyColor;
      buttonForeground = keyTextColor;
    }
    return FilledButton.tonal(
      key: isOk ? const Key('number_pad_ok') : Key('number_key_$value'),
      style: FilledButton.styleFrom(
        backgroundColor: buttonBackground,
        foregroundColor: buttonForeground,
        disabledBackgroundColor: isOk
            ? okDisabledBackground
            : keyColor.withValues(alpha: 0.42),
        disabledForegroundColor: isOk
            ? okDisabledForeground
            : keyTextColor.withValues(alpha: 0.36),
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(veriRadiusMd),
        ),
      ),
      onPressed: isOk && !canSubmit ? null : () => _handleKey(value),
      child: value == '⌫'
          ? Icon(Icons.backspace_outlined, color: buttonForeground)
          : Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: buttonForeground,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  bool get _canSubmit {
    final result = _result;
    if (result == null) {
      // 空输入在允许零时视为 0（清空后可直接确认为 0，如清除预算/信用额度）；
      // 非空但算式不完整/无效（如末尾挂着运算符）时才不允许确认。
      return _input.isEmpty && widget.allowZero;
    }
    if (widget.allowNegative) {
      return widget.allowZero || !isZeroAmount(result);
    }
    return widget.allowZero ? result >= 0 : result > 0;
  }

  static const String _operators = '+-×÷';

  /// 当前正在输入的操作数（最后一个运算符之后的片段；首位 `-` 视为负号不算运算符）。
  String get _currentOperand {
    final idx = _lastOperatorIndex();
    return idx < 0 ? _input : _input.substring(idx + 1);
  }

  int _lastOperatorIndex() {
    for (var i = _input.length - 1; i >= 0; i--) {
      final ch = _input[i];
      if (ch == '+' || ch == '×' || ch == '÷') {
        return i;
      }
      if (ch == '-' && i != 0) {
        return i;
      }
    }
    return -1;
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
      final max = widget.maxAmount;
      // 有上限时确认即封顶（配合下方「最多 xxx」提示，超额当场生效、不必等保存）。
      final result = max != null && _amount > max ? max : _amount;
      Navigator.of(context).pop(result);
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
      if (_operators.contains(value)) {
        _appendOperator(value);
        return;
      }
      if (value == '.') {
        final operand = _currentOperand;
        if (operand.contains('.')) {
          return;
        }
        _input += operand.isEmpty ? '0.' : '.';
        return;
      }
      // 数字键：小数位与前导零规则只针对当前操作数。
      final operand = _currentOperand;
      if (operand.contains('.')) {
        final decimalLength = operand.split('.').last.length;
        if (decimalLength >= 2) {
          return;
        }
      }
      if (operand == '0' && value != '00') {
        // 用新数字替换当前操作数的前导零。
        _input = _input.substring(0, _input.length - 1) + value;
      } else if (operand == '-0' && value != '00') {
        _input = '${_input.substring(0, _input.length - 1)}$value';
      } else if (operand.isEmpty && value == '00') {
        _input += '0';
      } else {
        _input += value;
      }
    });
  }

  /// 追加一个运算符：不能以运算符开头；末尾已是运算符则替换；末尾的 `.` 先去掉。
  void _appendOperator(String op) {
    if (_input.isEmpty) {
      return;
    }
    var next = _input;
    if (next.endsWith('.')) {
      next = next.substring(0, next.length - 1);
    }
    if (next.isEmpty || next == '-') {
      return;
    }
    final last = next[next.length - 1];
    final endsWithOperator =
        last == '+' ||
        last == '×' ||
        last == '÷' ||
        (last == '-' && next.length > 1);
    if (endsWithOperator) {
      next = next.substring(0, next.length - 1) + op;
    } else {
      next += op;
    }
    _input = next;
  }
}

/// 记账时选择分类的底部弹窗。支持多级分类：父分类可展开/收起，
/// 子分类缩进显示，点选任意层级的分类（父或子）都会返回其 id。
/// [CategoryPickerSheet] 选择「移到顶级」时返回的哨兵值（区别于任何真实分类 id）。
const String categoryPickerTopLevel = '__category_picker_top_level__';

/// [CategoryPickerSheet] 选择「全部分类」时返回的哨兵值（筛选场景用）。
const String categoryPickerAll = '__category_picker_all__';

/// 分类选择弹层组件体。**勿直接实例化**——统一走 `pages/sheets.dart` 的
/// `showCategoryPickerSheet`。
class CategoryPickerSheet extends StatefulWidget {
  const CategoryPickerSheet({
    super.key,
    required this.categories,
    required this.selectedId,
    this.title,
    this.topLevelLabel,
    this.allLabel,
  });

  /// 当前类型下的全部分类（含各级子分类），由调用方按类型过滤后传入。
  final List<Category> categories;
  final String selectedId;

  /// 弹窗标题；为空时用「全部分类」。
  final String? title;

  /// 非空时在列表顶部加一个「移到顶级」选项，点选返回 [categoryPickerTopLevel]。
  final String? topLevelLabel;

  /// 非空时在列表顶部加一个「全部」选项（筛选场景），点选返回 [categoryPickerAll]；
  /// 当 [selectedId] 为 [categoryPickerAll] 时该项高亮。
  final String? allLabel;

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

  /// 按类型分区（支出→收入→转账）并按折叠状态前序展开：每个非空类型前插入一行
  /// 类型标题，区内根分类保持列表顺序（= 用户在分类页拖拽设置的顺序），子分类缩进。
  List<_CategoryPickerRow> _buildRows() {
    final rows = <_CategoryPickerRow>[];
    final visited = <String>{};
    void walkChildren(String parentId, int depth) {
      for (final child in widget.categories.where(
        (c) => c.parentId == parentId,
      )) {
        if (!visited.add(child.id)) {
          continue;
        }
        rows.add(
          _CategoryPickerRow.node(CategoryNode(category: child, depth: depth)),
        );
        final hasKids = widget.categories.any((c) => c.parentId == child.id);
        if (hasKids && !_collapsed.contains(child.id)) {
          walkChildren(child.id, depth + 1);
        }
      }
    }

    // 类型顺序固定为 支出→收入→转账；末尾兜底追加任何其它出现过的顶级类型（防御，
    // 正常不会有 refund 类分类）。
    final types = <EntryType>[
      for (final type in const <EntryType>[
        EntryType.expense,
        EntryType.income,
        EntryType.transfer,
      ])
        if (widget.categories.any((c) => c.parentId == null && c.type == type))
          type,
    ];
    for (final root in widget.categories.where((c) => c.parentId == null)) {
      if (!types.contains(root.type)) {
        types.add(root.type);
      }
    }

    for (final type in types) {
      rows.add(_CategoryPickerRow.header(type));
      for (final root in widget.categories.where(
        (c) => c.parentId == null && c.type == type,
      )) {
        if (!visited.add(root.id)) {
          continue;
        }
        rows.add(
          _CategoryPickerRow.node(CategoryNode(category: root, depth: 0)),
        );
        final hasKids = widget.categories.any((c) => c.parentId == root.id);
        if (hasKids && !_collapsed.contains(root.id)) {
          walkChildren(root.id, 1);
        }
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();
    // 「全部」「移到顶级」等非分类的元操作项用中性主题色（深浅色自适应），不用蓝色。
    final metaIconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.title ?? AppLocalizations.of(context).categoryAll,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (widget.allLabel != null)
            ListTile(
              minTileHeight: 48,
              dense: true,
              selected: widget.selectedId == categoryPickerAll,
              selectedTileColor: veriRoyal.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(veriRadiusSm),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: VeriIconBox(
                icon: Icons.select_all,
                color: metaIconColor,
                size: 32,
              ),
              title: Text(
                widget.allLabel!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: widget.selectedId == categoryPickerAll
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
              trailing: widget.selectedId == categoryPickerAll
                  ? const Icon(Icons.check, color: veriRoyal, size: 18)
                  : null,
              onTap: () => Navigator.of(context).pop(categoryPickerAll),
            ),
          if (widget.topLevelLabel != null)
            ListTile(
              minTileHeight: 48,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: VeriIconBox(
                icon: Icons.vertical_align_top,
                color: metaIconColor,
                size: 32,
              ),
              title: Text(
                widget.topLevelLabel!,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(context).pop(categoryPickerTopLevel),
            ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: rows.length,
              separatorBuilder: (context, index) {
                // 类型标题行两侧不画分隔线。
                if (rows[index].isHeader || rows[index + 1].isHeader) {
                  return const SizedBox.shrink();
                }
                return Divider(
                  height: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.06),
                );
              },
              itemBuilder: (context, index) {
                final row = rows[index];
                if (row.isHeader) {
                  final type = row.headerType!;
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 8,
                      right: 8,
                      top: index == 0 ? 2 : 14,
                      bottom: 4,
                    ),
                    child: Text(
                      type.label(AppLocalizations.of(context)),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorForType(type),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  );
                }
                final node = row.node!;
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
                    leading: CategoryIconBox(
                      iconCode: category.iconCode,
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

/// 分类选择弹窗的列表行：要么是一行类型标题（[headerType]），要么是一个分类节点
/// （[node]）。用于把分类按 支出/收入/转账 分区展示。
class _CategoryPickerRow {
  const _CategoryPickerRow.header(EntryType type)
    : headerType = type,
      node = null;
  const _CategoryPickerRow.node(CategoryNode this.node) : headerType = null;

  final EntryType? headerType;
  final CategoryNode? node;

  bool get isHeader => headerType != null;
}

/// 记账时给交易多选标签的底部弹窗。展示已有标签的 FilterChip 供多选，
/// 并可即时新建标签。点「完成」返回选中的标签 id 列表（取消返回 null）。
/// 标签选择弹层组件体。**勿直接实例化**——统一走 `pages/sheets.dart` 的
/// `showTagSelectorSheet`。
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
