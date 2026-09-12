import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _editing) setState(() => _editing = false);
      },
      child: Scaffold(
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
                const SizedBox(height: 10),
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
            supportedWidgetSize(definition.size) == WidgetSize.twoByFour;
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
    final tile = GestureDetector(
      key: ValueKey('widget_tile_${definition.id}'),
      onTap: editing ? null : onTap,
      onLongPress: editing ? null : onLongPress,
      child: WidgetDesignPreview(
        definition: definition,
        width: double.infinity,
      ),
    );
    final child = editing
        ? LongPressDraggable<int>(
            data: sourceIndex,
            childWhenDragging: Opacity(opacity: .35, child: tile),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 160,
                child: WidgetDesignPreview(definition: definition),
              ),
            ),
            child: DragTarget<int>(
              onWillAcceptWithDetails: (details) => details.data != sourceIndex,
              onAcceptWithDetails: (details) => onReorder(details.data),
              builder: (context, candidates, rejected) => tile,
            ),
          )
        : tile;
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
                key: ValueKey('widget_delete_${definition.id}'),
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
                        width: 216,
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
