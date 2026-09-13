import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/app_theme.dart';
import '../app/avatar_picker.dart';
import '../app/common_widgets.dart';
import '../app/feedback.dart';
import '../app/image_cropper.dart';
import '../app/home_widget_service.dart';
import '../app/platform_bridge.dart';
import '../app/veri_fin_scope.dart';
import '../app/widget_config.dart';
import '../app/widget_presentation.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';
import 'widget_design_preview.dart';

// Explicit options keep cancelling a selector distinct from clearing a field.
const _currentBookOption = '__widget_current_book__';
const _noSecondaryOption = '__widget_no_secondary__';
const _noChartOption = '__widget_no_chart__';

class WidgetGalleryPage extends StatefulWidget {
  const WidgetGalleryPage({super.key});

  @override
  State<WidgetGalleryPage> createState() => _WidgetGalleryPageState();
}

class _WidgetGalleryPageState extends State<WidgetGalleryPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const showcaseSizes = <WidgetSize>[
      WidgetSize.oneByTwo,
      WidgetSize.twoByTwo,
      WidgetSize.twoByTwo,
      WidgetSize.twoByFour,
    ];
    final definitions = [
      for (var index = 0; index < WidgetTemplate.values.length; index++)
        () {
          final template = WidgetTemplate.values[index];
          return UserWidgetDefinition(
            id: 'showcase_${template.name}',
            name: switch (template) {
              WidgetTemplate.quickEntry => l10n.widgetQuickEntryName,
              WidgetTemplate.budget => l10n.widgetBudgetName,
              WidgetTemplate.trend => l10n.widgetTrendName,
              WidgetTemplate.netWorth => l10n.widgetNetWorthName,
            },
            template: template,
            size: showcaseSizes[index],
            primaryMetric: defaultWidgetMetric(template),
            chartMetric: defaultWidgetChart(template),
          );
        }(),
    ];
    return PopScope(
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: [
                VeriHeader(
                  title: l10n.widgetGalleryTitle,
                  subtitle: l10n.widgetGallerySubtitle,
                  showBack: true,
                ),
                const SizedBox(height: 10),
                _MasonryCanvas(
                  definitions: definitions,
                  editing: false,
                  interactive: false,
                  activeTileId: null,
                  onTap: (_) {},
                  onLongPress: (_) {},
                  onTapBlank: () {},
                  onDelete: (_) {},
                  onReorder: (_, _) async {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WidgetCreatePage extends StatelessWidget {
  const WidgetCreatePage({super.key});

  Future<void> _open(BuildContext context, WidgetTemplate template) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UserWidgetEditorPage(template: template),
      ),
    );
    if (saved == true && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: [
              VeriHeader(title: l10n.widgetCreateNew, showBack: true),
              const SizedBox(height: 14),
              for (final template in WidgetTemplate.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TemplateCard(
                    template: template,
                    onCreate: () => _open(context, template),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MasonryCanvas extends StatefulWidget {
  const _MasonryCanvas({
    required this.definitions,
    required this.editing,
    required this.interactive,
    required this.activeTileId,
    required this.onTap,
    required this.onLongPress,
    required this.onTapBlank,
    required this.onDelete,
    required this.onReorder,
  });
  final List<UserWidgetDefinition> definitions;
  final bool editing;
  final bool interactive;
  final String? activeTileId;
  final ValueChanged<UserWidgetDefinition> onTap;
  final ValueChanged<String> onLongPress;
  final VoidCallback onTapBlank;
  final ValueChanged<String> onDelete;
  final Future<void> Function(int from, int to) onReorder;

  @override
  State<_MasonryCanvas> createState() => _MasonryCanvasState();
}

class _MasonryCanvasState extends State<_MasonryCanvas> {
  int? _draggingIndex;
  int? _dropIndex;
  Offset? _dragPosition;
  Offset? _dragStartPosition;
  bool _dragMoved = false;

  void _activateTile(int index) {
    if (VeriFinScope.of(context).hapticsEnabled) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _startDrag(int index) {
    if (widget.editing && _draggingIndex == index) return;
    _activateTile(index);
    setState(() {
      _draggingIndex = index;
      _dropIndex = index;
      _dragPosition = null;
      _dragStartPosition = null;
      _dragMoved = false;
    });
  }

  void _finishDrag() {
    if (!mounted) return;
    if (_draggingIndex == null && _dropIndex == null) return;
    setState(() {
      _draggingIndex = null;
      _dropIndex = null;
      _dragPosition = null;
      _dragStartPosition = null;
      _dragMoved = false;
    });
  }

  void _startLongPress(int index, Offset position) {
    if (_draggingIndex != null && _dragMoved && _draggingIndex != index) {
      return;
    }
    _startDrag(index);
    _dragStartPosition = position;
    _updateLongPress(position);
    widget.onLongPress(widget.definitions[index].id);
  }

  void _updateLongPress(Offset globalPosition) {
    final dragging = _draggingIndex;
    if (dragging == null) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final point = renderObject.globalToLocal(globalPosition);
    final moved =
        _dragMoved ||
        (_dragStartPosition != null &&
            (globalPosition - _dragStartPosition!).distance > 8);
    if (!moved) {
      setState(() => _dragPosition = point);
      return;
    }
    _dragMoved = true;
    final placed = _placements(widget.definitions, renderObject.size.width);
    final target = _targetForPoint(point, placed);
    setState(() {
      _dragPosition = point;
      _dropIndex = target;
    });
  }

  Future<void> _endLongPress(Offset finalPosition) async {
    final from = _draggingIndex;
    if (from == null) return;
    if (finalPosition != Offset.zero) _updateLongPress(finalPosition);
    if (!_dragMoved) {
      _finishDrag();
      return;
    }
    var target = _dropIndex ?? from;
    final renderObject = context.findRenderObject();
    final position = _dragPosition;
    if (renderObject is RenderBox && position != null) {
      target = _targetForPoint(
        position,
        _placements(widget.definitions, renderObject.size.width),
      );
    }
    try {
      await widget.onReorder(from, target);
    } finally {
      _finishDrag();
    }
  }

  List<_MasonryPlacement> _placements(
    List<UserWidgetDefinition> definitions,
    double maxWidth,
  ) {
    final columns = maxWidth >= 560 ? 3 : 2;
    const gap = 10.0;
    final cellWidth = (maxWidth - gap * (columns - 1)) / columns;
    final heights = List<double>.filled(columns, 0);
    final placed = <_MasonryPlacement>[];
    for (var index = 0; index < definitions.length; index++) {
      final definition = definitions[index];
      final wide = supportedWidgetSize(definition.size) == WidgetSize.twoByFour;
      final span = wide ? columns : 1;
      final width = cellWidth * span + gap * (span - 1);
      final height = width / widgetSizeAspect(definition.size);
      final start = span == columns
          ? 0
          : List.generate(
              columns - span + 1,
              (i) => i,
            ).reduce((a, b) => heights[a] <= heights[b] ? a : b);
      final top = span == columns
          ? heights.reduce(math.max)
          : heights.sublist(start, start + span).reduce(math.max);
      placed.add(
        _MasonryPlacement(
          index: index,
          left: start * (cellWidth + gap),
          top: top,
          width: width,
          height: height,
        ),
      );
      for (var column = start; column < start + span; column++) {
        heights[column] = top + height + gap;
      }
    }
    return placed;
  }

  int _targetForPoint(Offset point, List<_MasonryPlacement> placed) {
    var target = placed.length;
    for (final item in placed) {
      final horizontal =
          point.dx >= item.left && point.dx <= item.left + item.width;
      final vertical =
          point.dy >= item.top && point.dy <= item.top + item.height;
      if (horizontal && vertical) return item.index;
      if (vertical && point.dx > item.left + item.width) {
        target = math.min(target, item.index + 1);
      } else if (point.dy < item.top && target == placed.length) {
        target = item.index;
      }
    }
    return target.clamp(0, placed.length);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final definitions = widget.definitions;
      final dragging = _draggingIndex;
      final moving = dragging == null || !_dragMoved
          ? null
          : definitions[dragging];
      final renderDefinitions = <UserWidgetDefinition>[];
      if (moving == null) {
        renderDefinitions.addAll(definitions);
      } else {
        renderDefinitions.addAll(
          definitions.where((item) => item.id != moving.id),
        );
        final insertion = (_dropIndex ?? dragging!)
            .clamp(0, renderDefinitions.length)
            .toInt();
        renderDefinitions.insert(insertion, moving);
      }
      final renderPlaced = _placements(renderDefinitions, constraints.maxWidth);
      final totalHeight = renderPlaced.isEmpty
          ? 0.0
          : renderPlaced.map((item) => item.top + item.height).reduce(math.max);
      final movingPlacement = moving == null
          ? null
          : renderPlaced.firstWhere(
              (item) => renderDefinitions[item.index].id == moving.id,
            );
      final canvas = SizedBox(
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.editing)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTapBlank,
                ),
              ),
            if (moving != null && movingPlacement != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                key: ValueKey('widget_drop_position_${moving.id}'),
                left: movingPlacement.left,
                top: movingPlacement.top,
                width: movingPlacement.width,
                height: movingPlacement.height,
                child: const _WidgetDropPlaceholder(
                  key: ValueKey('widget_drop_placeholder'),
                ),
              ),
            for (final item in renderPlaced)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                key: ValueKey(
                  'widget_position_${renderDefinitions[item.index].id}',
                ),
                left: item.left,
                top: item.top,
                width: item.width,
                height: item.height,
                child: Opacity(
                  opacity:
                      moving != null &&
                          renderDefinitions[item.index].id == moving.id
                      ? 0
                      : 1,
                  child: _MasonryTile(
                    key: ValueKey(
                      'widget_tile_wrapper_${renderDefinitions[item.index].id}',
                    ),
                    definition: renderDefinitions[item.index],
                    editing: widget.editing,
                    interactive: widget.interactive,
                    deleteVisible:
                        widget.activeTileId == renderDefinitions[item.index].id,
                    onTap: () => widget.onTap(renderDefinitions[item.index]),
                    onLongPressStart: (position) {
                      final id = renderDefinitions[item.index].id;
                      final originalIndex = definitions.indexWhere(
                        (item) => item.id == id,
                      );
                      _startLongPress(originalIndex, position);
                    },
                    onLongPressMove: _updateLongPress,
                    onLongPressEnd: (position) => _endLongPress(position),
                    onDelete: () =>
                        widget.onDelete(renderDefinitions[item.index].id),
                  ),
                ),
              ),
            if (moving != null &&
                movingPlacement != null &&
                _dragPosition != null)
              Positioned(
                left: _dragPosition!.dx - movingPlacement.width / 2,
                top: _dragPosition!.dy - movingPlacement.height / 2,
                width: movingPlacement.width,
                height: movingPlacement.height,
                child: Material(
                  color: Colors.transparent,
                  child: WidgetDesignPreview(
                    definition: moving,
                    width: movingPlacement.width,
                  ),
                ),
              ),
          ],
        ),
      );
      return canvas;
    },
  );
}

class _WidgetDropPlaceholder extends StatelessWidget {
  const _WidgetDropPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _WidgetDropPlaceholderPainter(
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

class _WidgetDropPlaceholderPainter extends CustomPainter {
  const _WidgetDropPlaceholderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1.5),
      Radius.circular(veriRadiusLg),
    );
    final paint = Paint()
      ..color = color.withValues(alpha: .78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 8), paint);
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(_WidgetDropPlaceholderPainter old) => old.color != color;
}

class _MasonryPlacement {
  const _MasonryPlacement({
    required this.index,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
  final int index;
  final double left;
  final double top;
  final double width;
  final double height;
}

class _MasonryTile extends StatelessWidget {
  const _MasonryTile({
    super.key,
    required this.definition,
    required this.editing,
    required this.interactive,
    required this.deleteVisible,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
    required this.onDelete,
  });
  final UserWidgetDefinition definition;
  final bool editing;
  final bool interactive;
  final bool deleteVisible;
  final VoidCallback onTap;
  final ValueChanged<Offset> onLongPressStart;
  final ValueChanged<Offset> onLongPressMove;
  final ValueChanged<Offset> onLongPressEnd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tile = GestureDetector(
      key: ValueKey('widget_tile_${definition.id}'),
      onTap: interactive && !editing ? onTap : null,
      onLongPressStart: interactive
          ? (details) => onLongPressStart(details.globalPosition)
          : null,
      onLongPressMoveUpdate: interactive
          ? (details) => onLongPressMove(details.globalPosition)
          : null,
      onLongPressEnd: interactive
          ? (details) => onLongPressEnd(details.globalPosition)
          : null,
      child: WidgetDesignPreview(
        definition: definition,
        width: double.infinity,
      ),
    );
    final child = tile;
    final stack = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        child,
        if (editing && deleteVisible)
          Positioned(
            top: -14,
            right: -14,
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                key: ValueKey('widget_delete_${definition.id}'),
                tooltip: AppLocalizations.of(context).widgetDelete,
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                icon: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.remove_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return _WobblingTile(enabled: editing && deleteVisible, child: stack);
  }
}

class _WobblingTile extends StatefulWidget {
  const _WobblingTile({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  State<_WobblingTile> createState() => _WobblingTileState();
}

class _WobblingTileState extends State<_WobblingTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _startWobble();
  }

  @override
  void didUpdateWidget(covariant _WobblingTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _startWobble();
    } else if (!widget.enabled && oldWidget.enabled) {
      _controller.stop();
      _controller.value = .5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startWobble() {
    _controller.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Transform.rotate(
      angle: widget.enabled ? (_controller.value - .5) * .032 : 0,
      child: child,
    ),
  );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onCreate});
  final WidgetTemplate template;
  final VoidCallback onCreate;

  String _label(AppLocalizations l10n) => switch (template) {
    WidgetTemplate.quickEntry => l10n.widgetQuickEntryName,
    WidgetTemplate.budget => l10n.widgetBudgetName,
    WidgetTemplate.trend => l10n.widgetTrendName,
    WidgetTemplate.netWorth => l10n.widgetNetWorthName,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VeriCard(
      child: Row(
        children: [
          Icon(
            switch (template) {
              WidgetTemplate.quickEntry => Icons.add_circle_outline,
              WidgetTemplate.budget => Icons.donut_large,
              WidgetTemplate.trend => Icons.show_chart,
              WidgetTemplate.netWorth => Icons.insights_outlined,
            },
            color: veriRoyal,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _label(l10n),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton.tonal(
            onPressed: onCreate,
            child: Text(l10n.widgetTemplateCreate),
          ),
        ],
      ),
    );
  }
}

class UserWidgetEditorPage extends StatefulWidget {
  const UserWidgetEditorPage({
    super.key,
    this.template = WidgetTemplate.trend,
    this.definition,
  });
  final WidgetTemplate template;
  final UserWidgetDefinition? definition;

  @override
  State<UserWidgetEditorPage> createState() => _UserWidgetEditorPageState();
}

class _UserWidgetEditorPageState extends State<UserWidgetEditorPage> {
  final EditorExitController _exitController = EditorExitController();
  bool _saving = false;
  String? _initialFingerprint;
  late WidgetTemplate _template =
      widget.definition?.template ?? widget.template;
  late WidgetSize _size = supportedWidgetSize(
    widget.definition?.size ?? WidgetSize.twoByTwo,
  );
  late WidgetMetric _metric =
      widget.definition?.primaryMetric ?? defaultWidgetMetric(_template);
  late WidgetMetric? _secondary =
      widget.definition == null || widget.definition!.secondaryMetrics.isEmpty
      ? null
      : widget.definition!.secondaryMetrics.first;
  late String? _bookId = widget.definition?.bookId;
  late WidgetChartMetric? _chart = widget.definition == null
      ? defaultWidgetChart(_template)
      : widget.definition!.chartMetric;
  late WidgetDateRange _range =
      widget.definition?.dateRange ?? WidgetDateRange.thirtyDays;
  late WidgetAction _action =
      widget.definition?.action ??
      switch (_template) {
        WidgetTemplate.quickEntry => WidgetAction.entry,
        WidgetTemplate.budget => WidgetAction.budget,
        WidgetTemplate.trend => WidgetAction.trend,
        WidgetTemplate.netWorth => WidgetAction.assets,
      };
  late bool _hideAmounts = widget.definition?.hideAmounts ?? false;
  late WidgetBackground _background =
      widget.definition?.background ?? const WidgetBackground();
  late final TextEditingController _name = TextEditingController(
    text: widget.definition?.name,
  );
  late final String _id =
      widget.definition?.id ?? 'uw_${DateTime.now().microsecondsSinceEpoch}';

  UserWidgetDefinition _draft(AppLocalizations l) => UserWidgetDefinition(
    id: _id,
    name: _name.text.trim().isEmpty
        ? l.widgetDesignNameDefault
        : _name.text.trim(),
    template: _template,
    size: _size,
    bookId: _bookId,
    primaryMetric: _metric,
    secondaryMetrics: _secondary == null ? const [] : [_secondary!],
    chartMetric: _chart,
    dateRange: _range,
    accountId: widget.definition?.accountId,
    categoryId: widget.definition?.categoryId,
    tagId: widget.definition?.tagId,
    hideAmounts: _hideAmounts,
    action: _action,
    background: _background,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initialFingerprint ??= jsonEncode(
      _draft(AppLocalizations.of(context)).toJson(),
    );
  }

  void _selectTemplate(WidgetTemplate template) {
    if (_template == template) return;
    setState(() {
      _template = template;
      _metric = defaultWidgetMetric(template);
      _chart = defaultWidgetChart(template);
      _action = switch (template) {
        WidgetTemplate.quickEntry => WidgetAction.entry,
        WidgetTemplate.budget => WidgetAction.budget,
        WidgetTemplate.trend => WidgetAction.trend,
        WidgetTemplate.netWorth => WidgetAction.assets,
      };
    });
  }

  String _templateLabel(AppLocalizations l, WidgetTemplate t) => switch (t) {
    WidgetTemplate.quickEntry => l.widgetQuickEntryName,
    WidgetTemplate.budget => l.widgetBudgetName,
    WidgetTemplate.trend => l.widgetTrendName,
    WidgetTemplate.netWorth => l.widgetNetWorthName,
  };
  String _metricLabel(AppLocalizations l, WidgetMetric m) => switch (m) {
    WidgetMetric.todayExpense => l.widgetMetricTodayExpense,
    WidgetMetric.periodExpense => l.widgetMetricPeriodExpense,
    WidgetMetric.periodIncome => l.widgetMetricPeriodIncome,
    WidgetMetric.budgetRemaining => l.widgetMetricBudgetRemaining,
    WidgetMetric.budgetUsed => l.widgetMetricBudgetUsed,
    WidgetMetric.budgetRate => l.widgetMetricBudgetRate,
    WidgetMetric.netWorth => l.widgetMetricNetWorth,
    WidgetMetric.totalAssets => l.widgetMetricTotalAssets,
    WidgetMetric.totalLiabilities => l.widgetMetricTotalLiabilities,
    WidgetMetric.balance => l.widgetMetricBalance,
    WidgetMetric.transactionCount => l.widgetMetricTransactionCount,
    WidgetMetric.savingsRate => l.widgetMetricSavingsRate,
  };
  String _sizeLabel(AppLocalizations l, WidgetSize s) => switch (s) {
    WidgetSize.oneByTwo => '1 × 2',
    WidgetSize.oneByOne => '1 × 1',
    WidgetSize.twoByTwo => '2 × 2',
    WidgetSize.fourByOne => '4 × 1',
    WidgetSize.fourByTwo => '4 × 2',
    WidgetSize.twoByFour => '2 × 4',
  };
  String _chartLabel(AppLocalizations l, WidgetChartMetric? m) => m == null
      ? l.widgetNoChart
      : switch (m) {
          WidgetChartMetric.expense => l.widgetChartExpense,
          WidgetChartMetric.income => l.widgetChartIncome,
          WidgetChartMetric.net => l.widgetChartNet,
          WidgetChartMetric.budgetUsage => l.widgetChartBudgetUsage,
          WidgetChartMetric.netWorth => l.widgetChartNetWorth,
        };
  String _rangeLabel(AppLocalizations l, WidgetDateRange r) => switch (r) {
    WidgetDateRange.sevenDays => l.widgetRange7d,
    WidgetDateRange.thirtyDays => l.widgetRange30d,
    WidgetDateRange.ninetyDays => l.widgetRange90d,
    WidgetDateRange.budgetCycle => l.widgetRangeCycle,
    WidgetDateRange.year => l.widgetRangeYear,
  };
  String _actionLabel(AppLocalizations l, WidgetAction a) => switch (a) {
    WidgetAction.app => l.widgetActionApp,
    WidgetAction.entry => l.widgetActionEntry,
    WidgetAction.budget => l.widgetActionBudget,
    WidgetAction.trend => l.widgetActionTrend,
    WidgetAction.assets => l.widgetActionAssets,
    WidgetAction.profile => l.widgetActionProfile,
  };

  Future<T?> _choose<T>({
    required String title,
    required List<T> values,
    required T selected,
    required String Function(T) labelOf,
  }) => showOptionSheet(
    context: context,
    title: title,
    values: values,
    selected: selected,
    labelOf: labelOf,
  );

  List<VeriMenuEntry> _backgroundMenuEntries(AppLocalizations l) => [
    VeriMenuItem(
      id: 'widget_background_theme',
      icon: Icons.palette_outlined,
      title: l.widgetThemeBackground,
      selected: _background.kind == WidgetBackgroundKind.theme,
      onPressed: () => setState(() => _background = const WidgetBackground()),
    ),
    VeriMenuItem(
      id: 'widget_background_local',
      icon: Icons.photo_library_outlined,
      title: l.widgetPickPhoto,
      onPressed: _pickBackground,
    ),
    VeriMenuItem(
      id: 'widget_background_clear',
      icon: Icons.hide_image_outlined,
      title: l.coverClear,
      enabled: _background.kind == WidgetBackgroundKind.asset,
      foregroundColor: Theme.of(context).colorScheme.error,
      onPressed: () => setState(() => _background = const WidgetBackground()),
    ),
  ];

  Future<void> _pickBackground() async {
    final l = AppLocalizations.of(context);
    final rawImage = await pickRawImageDataUrl();
    if (rawImage == null || !mounted) return;
    final crop = await showImageCropper(
      context: context,
      imageDataUrl: rawImage,
      title: l.widgetBackground,
      aspectRatio: widgetSizeAspect(_size),
    );
    if (crop == null || !mounted) return;
    final targetWidth = 1200;
    final targetHeight = (targetWidth / widgetSizeAspect(_size)).round().clamp(
      300,
      1800,
    );
    final dataUrl = await runWithLoadingDialog<String?>(
      context: context,
      message: l.widgetBackground,
      task: () => cropImageDataUrl(
        sourceDataUrl: rawImage,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        zoom: crop.zoom,
        offsetX: crop.offsetX,
        offsetY: crop.offsetY,
      ),
    );
    if (dataUrl != null && mounted) {
      setState(
        () => _background = WidgetBackground(
          kind: WidgetBackgroundKind.asset,
          value: dataUrl,
          overlayOpacity: .38,
        ),
      );
    }
  }

  Future<bool> _save() async {
    if (_saving) return false;
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final definition = _draft(l10n);
    final definitions = [...controller.userWidgetDefinitions];
    final index = definitions.indexWhere((item) => item.id == definition.id);
    if (index >= 0) {
      definitions[index] = definition;
    } else {
      definitions.add(definition);
    }
    setState(() => _saving = true);
    try {
      await controller.saveUserWidgetDefinitions(definitions);
    } on Object {
      // The controller records the persistence failure; leave this draft intact.
      if (mounted) {
        setState(() => _saving = false);
        unawaited(
          VeriFeedbackHost.of(
            context,
          ).showMessage(message: l10n.saveFailed, tone: VeriFeedbackTone.error),
        );
      }
      return false;
    }
    if (!mounted) return false;
    setState(() => _saving = false);
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: l10n.widgetDesignSaved,
        tone: VeriFeedbackTone.success,
      ),
    );
    return true;
  }

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(
        () => _initialFingerprint = jsonEncode(
          _draft(AppLocalizations.of(context)).toJson(),
        ),
      );
      _exitController.exit(result: () => true);
    }
  }

  Future<void> _deleteDesign() async {
    final definition = widget.definition;
    if (definition == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.widgetDelete,
      message: definition.name,
      confirmLabel: l10n.widgetDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final controller = VeriFinScope.of(context);
    await controller.saveUserWidgetDefinitions(
      controller.userWidgetDefinitions
          .where((item) => item.id != definition.id)
          .toList(),
    );
    if (mounted) _exitController.exit(result: () => true);
  }

  Future<void> _addDesignToHome() async {
    final id = widget.definition?.id;
    if (id == null) return;
    await pushWidgetData(VeriFinScope.of(context));
    if (!mounted) return;
    final ok = await AppWidgetBridge.pinUserWidget(id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (!ok) {
      await showConfirmDialog(
        context,
        title: l10n.widgetPinUnsupported,
        message: l10n.widgetHowToAddDesc,
        confirmLabel: l10n.gotIt,
      );
      return;
    }
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: l10n.widgetPinRequested,
        tone: VeriFeedbackTone.success,
        duration: VeriFeedbackDuration.standard,
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = VeriFinScope.of(context);
    final bookName = _bookId == null
        ? l.widgetCurrentBook
        : c.ledgerBooks
              .firstWhere((b) => b.id == _bookId, orElse: () => c.activeBook)
              .name;
    final draft = _draft(l);
    final dirty = jsonEncode(draft.toJson()) != _initialFingerprint;
    return UnsavedChangesGuard(
      isDirty: dirty,
      onSave: _save,
      exitController: _exitController,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: [
                VeriHeader(
                  title: widget.definition == null
                      ? l.widgetCreateNew
                      : l.widgetEdit,
                  showBack: true,
                  actions: [
                    if (widget.definition != null)
                      HeaderAction(
                        icon: Icons.delete_outline,
                        tooltip: l.widgetDelete,
                        onPressed: _deleteDesign,
                      ),
                    SaveHeaderAction(
                      onPressed:
                          _saving || (widget.definition != null && !dirty)
                          ? null
                          : _saveAndExit,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                WidgetDesignPreview(definition: draft),
                const SizedBox(height: 12),
                VeriCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _name,
                        decoration: InputDecoration(labelText: l.widgetName),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      SelectField(
                        label: l.widgetTemplate,
                        value: _templateLabel(l, _template),
                        icon: Icons.dashboard_outlined,
                        onTap: () async {
                          final v = await _choose(
                            title: l.widgetTemplate,
                            values: WidgetTemplate.values,
                            selected: _template,
                            labelOf: (x) => _templateLabel(l, x),
                          );
                          if (v != null && mounted) _selectTemplate(v);
                        },
                      ),
                      const SizedBox(height: 10),
                      SelectField(
                        label: l.widgetSize,
                        value: _sizeLabel(l, _size),
                        icon: Icons.aspect_ratio,
                        onTap: () async {
                          final v = await _choose(
                            title: l.widgetSize,
                            values: const [
                              WidgetSize.oneByTwo,
                              WidgetSize.twoByTwo,
                              WidgetSize.twoByFour,
                            ],
                            selected: _size,
                            labelOf: (x) => _sizeLabel(l, x),
                          );
                          if (v != null && mounted) setState(() => _size = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      SelectField(
                        label: l.widgetBook,
                        value: bookName,
                        icon: Icons.book_outlined,
                        onTap: () async {
                          final v = await showOptionSheet<String>(
                            context: context,
                            title: l.widgetBook,
                            values: [
                              _currentBookOption,
                              ...c.ledgerBooks.map((b) => b.id),
                            ],
                            selected: _bookId ?? _currentBookOption,
                            labelOf: (id) => id == _currentBookOption
                                ? l.widgetCurrentBook
                                : c.ledgerBooks
                                      .firstWhere((b) => b.id == id)
                                      .name,
                          );
                          if (v != null && mounted) {
                            setState(
                              () =>
                                  _bookId = v == _currentBookOption ? null : v,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      SelectField(
                        label: l.widgetPrimaryMetric,
                        value: _metricLabel(l, _metric),
                        icon: Icons.insights_outlined,
                        onTap: () async {
                          final v = await _choose(
                            title: l.widgetPrimaryMetric,
                            values: WidgetMetric.values,
                            selected: _metric,
                            labelOf: (x) => _metricLabel(l, x),
                          );
                          if (v != null && mounted) setState(() => _metric = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      SelectField(
                        label: l.widgetSecondaryMetric,
                        value: _secondary == null
                            ? l.widgetNoSecondaryMetric
                            : _metricLabel(l, _secondary!),
                        icon: Icons.view_agenda_outlined,
                        onTap: () async {
                          final v = await showOptionSheet<String>(
                            context: context,
                            title: l.widgetSecondaryMetric,
                            values: [
                              _noSecondaryOption,
                              ...WidgetMetric.values.map((m) => m.name),
                            ],
                            selected: _secondary?.name ?? _noSecondaryOption,
                            labelOf: (x) => x == _noSecondaryOption
                                ? l.widgetNoSecondaryMetric
                                : _metricLabel(
                                    l,
                                    WidgetMetric.values.byName(x),
                                  ),
                          );
                          if (v != null && mounted) {
                            setState(
                              () => _secondary = v == _noSecondaryOption
                                  ? null
                                  : WidgetMetric.values.byName(v),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      SelectField(
                        label: l.widgetChart,
                        value: _chartLabel(l, _chart),
                        icon: Icons.show_chart,
                        onTap: () async {
                          final v = await showOptionSheet<String>(
                            context: context,
                            title: l.widgetChart,
                            values: [
                              _noChartOption,
                              ...WidgetChartMetric.values.map((m) => m.name),
                            ],
                            selected: _chart?.name ?? _noChartOption,
                            labelOf: (x) => _chartLabel(
                              l,
                              x == _noChartOption
                                  ? null
                                  : WidgetChartMetric.values.byName(x),
                            ),
                          );
                          if (v != null && mounted) {
                            setState(
                              () => _chart = v == _noChartOption
                                  ? null
                                  : WidgetChartMetric.values.byName(v),
                            );
                          }
                        },
                      ),
                      if (_chart != null) ...[
                        const SizedBox(height: 10),
                        SelectField(
                          label: l.widgetDateRange,
                          value: _rangeLabel(l, _range),
                          icon: Icons.date_range,
                          onTap: () async {
                            final v = await _choose(
                              title: l.widgetDateRange,
                              values: WidgetDateRange.values,
                              selected: _range,
                              labelOf: (x) => _rangeLabel(l, x),
                            );
                            if (v != null && mounted) {
                              setState(() => _range = v);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      SelectField(
                        label: l.widgetTapAction,
                        value: _actionLabel(l, _action),
                        icon: Icons.touch_app_outlined,
                        onTap: () async {
                          final v = await _choose(
                            title: l.widgetTapAction,
                            values: WidgetAction.values,
                            selected: _action,
                            labelOf: (x) => _actionLabel(l, x),
                          );
                          if (v != null && mounted) setState(() => _action = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      VeriAnchoredMenuAnchor(
                        entries: _backgroundMenuEntries(l),
                        semanticLabel: l.widgetBackground,
                        builder: (context, openMenu, menuOpen) => SettingsRow(
                          icon: Icons.wallpaper_outlined,
                          title: l.widgetBackground,
                          trailing:
                              _background.kind == WidgetBackgroundKind.asset
                              ? l.widgetPhotoBackground
                              : l.widgetThemeBackground,
                          trailingIcon: Icons.keyboard_arrow_down,
                          onTap: openMenu,
                        ),
                      ),
                      const SizedBox(height: 4),
                      CompactSwitchRow(
                        icon: Icons.visibility_off_outlined,
                        title: Text(l.widgetHideAmounts),
                        value: _hideAmounts,
                        onChanged: (v) => setState(() => _hideAmounts = v),
                      ),
                    ],
                  ),
                ),
                if (widget.definition != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addDesignToHome,
                      icon: const Icon(Icons.add_to_home_screen),
                      label: Text(l.widgetAddSaved),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
