import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../app/avatar_picker.dart';
import '../app/common_widgets.dart';
import '../app/currency_math.dart';
import '../app/feedback.dart';
import '../app/image_cropper.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/platform_bridge.dart';
import '../app/veri_fin_scope.dart';
import '../app/widget_config.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

class WidgetGalleryPage extends StatefulWidget {
  const WidgetGalleryPage({super.key});

  @override
  State<WidgetGalleryPage> createState() => _WidgetGalleryPageState();
}

class _WidgetGalleryPageState extends State<WidgetGalleryPage> {
  bool _editing = false;
  List<String> _order = const [];

  Future<void> _create() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const WidgetCreatePage()),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _edit(UserWidgetDefinition definition) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UserWidgetEditorPage(definition: definition),
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  void _syncOrder(List<UserWidgetDefinition> definitions) {
    final ids = definitions.map((item) => item.id).toSet();
    _order = [
      ..._order.where(ids.contains),
      ...definitions.map((item) => item.id).where((id) => !_order.contains(id)),
    ];
  }

  Future<void> _reorder(
    int from,
    int to,
    List<UserWidgetDefinition> definitions,
  ) async {
    final ids = definitions.map((item) => item.id).toList();
    final moved = ids.removeAt(from);
    ids.insert(to.clamp(0, ids.length), moved);
    final byId = {for (final item in definitions) item.id: item};
    await VeriFinScope.of(
      context,
    ).saveUserWidgetDefinitions(ids.map((id) => byId[id]!).toList());
    if (mounted) setState(() => _order = ids);
  }

  Future<void> _deleteById(String id) async {
    final controller = VeriFinScope.of(context);
    final definition = controller.userWidgetDefinitions.firstWhere(
      (item) => item.id == id,
    );
    await _delete(definition);
  }

  Future<void> _delete(UserWidgetDefinition definition) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l10n.widgetDelete,
      message: definition.name,
      confirmLabel: l10n.widgetDelete,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    final controller = VeriFinScope.of(context);
    final definitions = controller.userWidgetDefinitions
        .where((item) => item.id != definition.id)
        .toList();
    await controller.saveUserWidgetDefinitions(definitions);
    if (!mounted) return;
    setState(() {});
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: l10n.widgetDesignDeleted,
        tone: VeriFeedbackTone.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final definitions = controller.userWidgetDefinitions;
    _syncOrder(definitions);
    final ordered = [
      for (final id in _order) ...definitions.where((item) => item.id == id),
    ];
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: [
              VeriHeader(
                title: l10n.myWidgetsTitle,
                subtitle: l10n.myWidgetsSubtitle,
                showBack: true,
                actions: [
                  HeaderAction(
                    icon: Icons.add,
                    tooltip: l10n.widgetCreateNew,
                    onPressed: _create,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionTitle(title: l10n.myWidgetsSection),
              const SizedBox(height: 8),
              if (definitions.isEmpty)
                VeriCard(
                  child: Column(
                    children: [
                      Icon(
                        Icons.dashboard_customize_outlined,
                        size: 40,
                        color: veriRoyal,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.widgetEmpty,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.widgetEmptyHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              else
                _MasonryCanvas(
                  definitions: ordered,
                  editing: _editing,
                  onTap: _edit,
                  onLongPress: () => setState(() => _editing = true),
                  onDelete: _deleteById,
                  onReorder: (from, to) => _reorder(from, to, ordered),
                ),
            ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _MasonryCanvas extends StatelessWidget {
  const _MasonryCanvas({
    required this.definitions,
    required this.editing,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onReorder,
  });
  final List<UserWidgetDefinition> definitions;
  final bool editing;
  final ValueChanged<UserWidgetDefinition> onTap;
  final VoidCallback onLongPress;
  final ValueChanged<String> onDelete;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 3 : 2;
      final gap = 10.0;
      final cellWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      final heights = List<double>.filled(columns, 0);
      final placed = <_MasonryPlacement>[];
      for (var index = 0; index < definitions.length; index++) {
        final definition = definitions[index];
        final wide =
            definition.size == WidgetSize.fourByOne ||
            definition.size == WidgetSize.fourByTwo;
        final span = wide ? columns : 1;
        final width = cellWidth * span + gap * (span - 1);
        final ratio =
            _previewSize(definition.size).height /
            _previewSize(definition.size).width;
        final height = width * ratio;
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
      final totalHeight = heights.isEmpty
          ? 0.0
          : heights.reduce(math.max) - gap;
      return SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            for (final item in placed)
              Positioned(
                left: item.left,
                top: item.top,
                width: item.width,
                height: item.height,
                child: _MasonryTile(
                  definition: definitions[item.index],
                  sourceIndex: item.index,
                  editing: editing,
                  onTap: () => onTap(definitions[item.index]),
                  onLongPress: onLongPress,
                  onDelete: () => onDelete(definitions[item.index].id),
                  onReorder: (from) => onReorder(from, item.index),
                ),
              ),
          ],
        ),
      );
    },
  );
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
    required this.definition,
    required this.sourceIndex,
    required this.editing,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onReorder,
  });
  final UserWidgetDefinition definition;
  final int sourceIndex;
  final bool editing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final ValueChanged<int> onReorder;

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      onTap: editing ? null : onTap,
      onLongPress: onLongPress,
      child: _DefinitionPreview(definition: definition, width: double.infinity),
    );
    if (editing) {
      child = LongPressDraggable<int>(
        data: sourceIndex,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 160,
            child: _DefinitionPreview(definition: definition),
          ),
        ),
        child: DragTarget<int>(
          onAcceptWithDetails: (details) => onReorder(details.data),
          builder: (context, candidates, rejected) => child,
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (editing)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black.withValues(alpha: .55),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: AppLocalizations.of(context).widgetDelete,
                onPressed: onDelete,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
      ],
    );
  }
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

class _DefinitionPreview extends StatelessWidget {
  const _DefinitionPreview({required this.definition, this.width});
  final UserWidgetDefinition definition;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metricLabel = switch (definition.primaryMetric) {
      WidgetMetric.todayExpense => l10n.widgetMetricTodayExpense,
      WidgetMetric.periodExpense => l10n.widgetMetricPeriodExpense,
      WidgetMetric.periodIncome => l10n.widgetMetricPeriodIncome,
      WidgetMetric.budgetRemaining => l10n.widgetMetricBudgetRemaining,
      WidgetMetric.budgetUsed => l10n.widgetMetricBudgetUsed,
      WidgetMetric.budgetRate => l10n.widgetMetricBudgetRate,
      WidgetMetric.netWorth => l10n.widgetMetricNetWorth,
      WidgetMetric.totalAssets => l10n.widgetMetricTotalAssets,
      WidgetMetric.totalLiabilities => l10n.widgetMetricTotalLiabilities,
      WidgetMetric.balance => l10n.widgetMetricBalance,
      WidgetMetric.transactionCount => l10n.widgetMetricTransactionCount,
      WidgetMetric.savingsRate => l10n.widgetMetricSavingsRate,
      null => '—',
    };
    final imageValue = definition.background.kind == WidgetBackgroundKind.asset
        ? definition.background.value
        : null;
    ImageProvider? backgroundImage;
    if (imageValue != null && imageValue.isNotEmpty) {
      if (imageValue.startsWith('data:')) {
        try {
          backgroundImage = MemoryImage(
            base64Decode(imageValue.split(',').skip(1).join(',')),
          );
        } on Object {
          backgroundImage = null;
        }
      } else {
        backgroundImage = FileImage(File(imageValue));
      }
    }
    final controller = VeriFinScope.of(context);
    final book = definition.bookId == null
        ? controller.activeBook
        : controller.ledgerBooks.firstWhere(
            (item) => item.id == definition.bookId,
            orElse: () => controller.activeBook,
          );
    final entries = controller.entriesForBook(book.id);
    final now = DateTime.now();
    final periodEntries = entries.where(
      (entry) =>
          entry.occurredAt.year == now.year &&
          entry.occurredAt.month == now.month,
    );
    final amount = switch (definition.primaryMetric) {
      WidgetMetric.todayExpense => dayExpenseTotal(entries, dateOnly(now)),
      WidgetMetric.periodIncome => sumByType(periodEntries, EntryType.income),
      WidgetMetric.netWorth =>
        book.id == controller.activeBook.id
            ? controller
                      .accountBalancesInBase(
                        accounts: controller.accounts.where(
                          (account) =>
                              account.includeInAssets && !account.hidden,
                        ),
                        date: now,
                      )
                      .completeTotal ??
                  0
            : 0,
      WidgetMetric.transactionCount => entries.length.toDouble(),
      _ => sumByType(periodEntries, EntryType.expense),
    };
    final size = _previewSize(definition.size);
    final aspect = _widgetAspect(definition.size);
    final previewWidth = width ?? size.width;
    final compact =
        definition.size == WidgetSize.fourByOne ||
        (previewWidth.isFinite && previewWidth / aspect < 120);
    final surface = AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(veriRadiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backgroundImage != null)
              Image(
                image: backgroundImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    ColoredBox(color: veriPreviewCanvasDark),
              )
            else
              ColoredBox(
                color: theme.brightness == Brightness.dark
                    ? veriPreviewSurfaceDark
                    : veriSurfaceLight,
              ),
            ColoredBox(color: Colors.black.withValues(alpha: .28)),
            if (definition.template == WidgetTemplate.quickEntry)
              Positioned(
                top: 12,
                right: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: veriRoyal,
                    borderRadius: BorderRadius.circular(veriRadiusMd),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ),
            if (definition.template == WidgetTemplate.budget)
              const Positioned(
                top: 14,
                right: 14,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CustomPaint(painter: _BudgetRingPreviewPainter()),
                ),
              ),
            if (definition.template == WidgetTemplate.netWorth)
              const Positioned(
                right: 14,
                bottom: 12,
                child: Text(
                  '+2.4%',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(compact ? 8 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (!compact)
                    Text(
                      metricLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  if (!compact) const SizedBox(height: 2),
                  Text(
                    definition.hideAmounts
                        ? '••••'
                        : formatUserMoney(amount, book.baseCurrencyCode),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (!compact && definition.chartMetric != null) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 24,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _PreviewLinePainter(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (width == double.infinity) return surface;
    return Center(
      child: SizedBox(width: previewWidth, child: surface),
    );
  }
}

Size _previewSize(WidgetSize size) => switch (size) {
  WidgetSize.oneByTwo => const Size(220, 110),
  WidgetSize.oneByOne => const Size(124, 124),
  WidgetSize.twoByTwo => const Size(220, 176),
  WidgetSize.fourByOne => const Size(320, 80),
  WidgetSize.fourByTwo => const Size(320, 160),
  WidgetSize.twoByFour => const Size(150, 300),
};

double _widgetAspect(WidgetSize size) => switch (size) {
  WidgetSize.oneByTwo => 2,
  WidgetSize.oneByOne => 1,
  WidgetSize.twoByTwo => 1.25,
  WidgetSize.fourByOne => 4,
  WidgetSize.fourByTwo => 2,
  WidgetSize.twoByFour => .5,
};

class _PreviewLinePainter extends CustomPainter {
  const _PreviewLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Path()
      ..moveTo(0, size.height * .8)
      ..lineTo(size.width * .24, size.height * .62)
      ..lineTo(size.width * .5, size.height * .22)
      ..lineTo(size.width * .72, size.height * .46)
      ..lineTo(size.width, size.height * .34);
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .34), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PreviewLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _BudgetRingPreviewPainter extends CustomPainter {
  const _BudgetRingPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(3),
      -math.pi / 2,
      math.pi * 1.45,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: .92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BudgetRingPreviewPainter oldDelegate) => false;
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
  late WidgetTemplate _template =
      widget.definition?.template ?? widget.template;
  late WidgetSize _size = widget.definition?.size ?? WidgetSize.twoByTwo;
  late WidgetMetric _metric =
      widget.definition?.primaryMetric ?? WidgetMetric.periodExpense;
  late WidgetMetric? _secondary =
      widget.definition == null || widget.definition!.secondaryMetrics.isEmpty
      ? null
      : widget.definition!.secondaryMetrics.first;
  late String? _bookId = widget.definition?.bookId;
  late WidgetChartMetric? _chart =
      widget.definition?.chartMetric ?? WidgetChartMetric.expense;
  late WidgetDateRange _range =
      widget.definition?.dateRange ?? WidgetDateRange.thirtyDays;
  late WidgetAction _action = widget.definition?.action ?? WidgetAction.app;
  late bool _hideAmounts = widget.definition?.hideAmounts ?? false;
  late WidgetBackground _background =
      widget.definition?.background ?? const WidgetBackground();
  late final TextEditingController _name = TextEditingController(
    text: widget.definition?.name,
  );

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
      aspectRatio: _widgetAspect(_size),
    );
    if (crop == null || !mounted) return;
    final targetWidth = 1200;
    final targetHeight = (targetWidth / _widgetAspect(_size)).round().clamp(
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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final name = _name.text.trim().isEmpty
        ? l10n.widgetDesignNameDefault
        : _name.text.trim();
    final definition = UserWidgetDefinition(
      id:
          widget.definition?.id ??
          'uw_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      template: _template,
      size: _size,
      bookId: _bookId,
      primaryMetric: _metric,
      secondaryMetrics: _secondary == null ? const [] : [_secondary!],
      chartMetric: _chart,
      dateRange: _range,
      hideAmounts: _hideAmounts,
      action: _action,
      background: _background,
    );
    final definitions = [...controller.userWidgetDefinitions];
    final index = definitions.indexWhere((item) => item.id == definition.id);
    if (index >= 0) {
      definitions[index] = definition;
    } else {
      definitions.add(definition);
    }
    await controller.saveUserWidgetDefinitions(definitions);
    if (!mounted) return;
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: l10n.widgetDesignSaved,
        tone: VeriFeedbackTone.success,
      ),
    );
    Navigator.of(context).pop(true);
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
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _addDesignToHome() async {
    final id = widget.definition?.id;
    if (id == null) return;
    final ok = await AppWidgetBridge.pinUserWidget(id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: ok ? l10n.widgetPinRequested : l10n.widgetPinUnsupported,
        tone: ok ? VeriFeedbackTone.success : VeriFeedbackTone.warning,
        duration: ok
            ? VeriFeedbackDuration.standard
            : VeriFeedbackDuration.long,
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
    return Scaffold(
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
                  SaveHeaderAction(onPressed: _save),
                ],
              ),
              const SizedBox(height: 10),
              _DefinitionPreview(
                definition: UserWidgetDefinition(
                  id: 'preview',
                  name: _name.text.isEmpty
                      ? l.widgetDesignNameDefault
                      : _name.text,
                  template: _template,
                  size: _size,
                  primaryMetric: _metric,
                  secondaryMetrics: _secondary == null
                      ? const []
                      : [_secondary!],
                  chartMetric: _chart,
                  dateRange: _range,
                  hideAmounts: _hideAmounts,
                  action: _action,
                  background: _background,
                ),
              ),
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
                        if (v != null) setState(() => _template = v);
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
                        if (v != null) setState(() => _size = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    SelectField(
                      label: l.widgetBook,
                      value: bookName,
                      icon: Icons.book_outlined,
                      onTap: () async {
                        final v = await showOptionSheet<String?>(
                          context: context,
                          title: l.widgetBook,
                          values: [null, ...c.ledgerBooks.map((b) => b.id)],
                          selected: _bookId,
                          labelOf: (id) => id == null
                              ? l.widgetCurrentBook
                              : c.ledgerBooks
                                    .firstWhere((b) => b.id == id)
                                    .name,
                        );
                        if (v != null || _bookId != null) {
                          setState(() => _bookId = v);
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
                        if (v != null) setState(() => _metric = v);
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
                        final v = await showOptionSheet<WidgetMetric?>(
                          context: context,
                          title: l.widgetSecondaryMetric,
                          values: [null, ...WidgetMetric.values],
                          selected: _secondary,
                          labelOf: (x) => x == null
                              ? l.widgetNoSecondaryMetric
                              : _metricLabel(l, x),
                        );
                        setState(() => _secondary = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    SelectField(
                      label: l.widgetChart,
                      value: _chartLabel(l, _chart),
                      icon: Icons.show_chart,
                      onTap: () async {
                        final v = await showOptionSheet<WidgetChartMetric?>(
                          context: context,
                          title: l.widgetChart,
                          values: [null, ...WidgetChartMetric.values],
                          selected: _chart,
                          labelOf: (x) => _chartLabel(l, x),
                        );
                        setState(() => _chart = v);
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
                          if (v != null) setState(() => _range = v);
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
                        if (v != null) setState(() => _action = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    VeriAnchoredMenuAnchor(
                      entries: _backgroundMenuEntries(l),
                      semanticLabel: l.widgetBackground,
                      width: 216,
                      builder: (context, openMenu, menuOpen) => SettingsRow(
                        icon: Icons.wallpaper_outlined,
                        title: l.widgetBackground,
                        trailing: _background.kind == WidgetBackgroundKind.asset
                            ? l.widgetPhotoBackground
                            : l.widgetThemeBackground,
                        trailingIcon: Icons.keyboard_arrow_down,
                        onTap: openMenu,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
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
    );
  }
}
