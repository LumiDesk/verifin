import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/feedback.dart';
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
  Future<void> _create(WidgetTemplate template) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UserWidgetEditorPage(template: template),
      ),
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

  Future<void> _addToHome(UserWidgetDefinition definition) async {
    final ok = await AppWidgetBridge.pinUserWidget(definition.id);
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final definitions = controller.userWidgetDefinitions;
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
                    onPressed: () => _create(WidgetTemplate.trend),
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
                ...definitions.map(
                  (definition) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DefinitionCard(
                      definition: definition,
                      onEdit: () => _edit(definition),
                      onDelete: () => _delete(definition),
                      onAdd: () => _addToHome(definition),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              _SectionTitle(title: l10n.widgetTemplatesSection),
              const SizedBox(height: 8),
              for (final template in WidgetTemplate.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TemplateCard(
                    template: template,
                    onCreate: () => _create(template),
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

class _DefinitionCard extends StatelessWidget {
  const _DefinitionCard({
    required this.definition,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });
  final UserWidgetDefinition definition;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VeriCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _DefinitionPreview(definition: definition),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    definition.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _sizeLabel(l10n, definition.size),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_to_home_screen, size: 18),
                    label: Text(l10n.widgetAddSaved),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: l10n.widgetEdit,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: l10n.widgetDelete,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ],
      ),
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
  const _DefinitionPreview({required this.definition});
  final UserWidgetDefinition definition;

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
    final size = switch (definition.size) {
      WidgetSize.oneByOne => const Size(1, 1),
      WidgetSize.twoByTwo => const Size(1.25, 1),
      WidgetSize.fourByOne => const Size(2.4, 1),
      WidgetSize.fourByTwo => const Size(2, 1),
      WidgetSize.twoByFour => const Size(.72, 1),
    };
    return AspectRatio(
      aspectRatio: size.width / size.height,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(veriRadiusLg),
        ),
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
            Padding(
              padding: const EdgeInsets.all(16),
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
                  Text(
                    metricLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    definition.hideAmounts ? '••••' : '12,480',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (definition.chartMetric != null) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 24,
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
  }
}

class _PreviewLinePainter extends CustomPainter {
  const _PreviewLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * .8)
      ..lineTo(size.width * .7, size.height * .25)
      ..lineTo(size.width, size.height * .48);
    canvas.drawPath(
      path,
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

  Future<void> _pickBackground() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(
      () => _background = WidgetBackground(
        kind: WidgetBackgroundKind.asset,
        value: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        overlayOpacity: .28,
      ),
    );
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
                  HeaderTextAction(label: l.widgetSaveDesign, onPressed: _save),
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
                          values: WidgetSize.values,
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
                    SelectField(
                      label: l.widgetBackground,
                      value: _background.kind == WidgetBackgroundKind.asset
                          ? l.widgetPhotoBackground
                          : l.widgetThemeBackground,
                      icon: Icons.wallpaper_outlined,
                      onTap: _pickBackground,
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
            ],
          ),
        ),
      ),
    );
  }
}

String _sizeLabel(AppLocalizations l10n, WidgetSize size) => switch (size) {
  WidgetSize.oneByOne => '1 × 1',
  WidgetSize.twoByTwo => '2 × 2',
  WidgetSize.fourByOne => '4 × 1',
  WidgetSize.fourByTwo => '4 × 2',
  WidgetSize.twoByFour => '2 × 4',
};
