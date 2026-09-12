import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/chart_painters.dart';
import '../app/image_sources.dart';
import '../app/veri_fin_scope.dart';
import '../app/widget_config.dart';
import '../app/widget_presentation.dart';
import '../l10n/app_localizations.dart';

/// The same bounded surface is used by the gallery, editor and drag feedback.
/// A size is expressed as rows × columns, independent of the screen width.
class WidgetDesignPreview extends StatelessWidget {
  const WidgetDesignPreview({super.key, required this.definition, this.width});

  final UserWidgetDefinition definition;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final size = supportedWidgetSize(definition.size);
    final previewWidth =
        width ?? (size == WidgetSize.twoByFour ? 320.0 : 192.0);
    final controller = VeriFinScope.of(context);
    final now = DateTime.now();
    final snapshot = controller.widgetLedgerSnapshot(definition.bookId, now);
    final data = snapshot == null
        ? null
        : buildWidgetPresentation(
            definition: definition,
            snapshot: snapshot,
            now: now,
          );
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final background = definition.background;
    final source = background.kind == WidgetBackgroundKind.asset
        ? background.value
        : null;
    final hasImage = source != null && source.isNotEmpty;
    final foreground = hasImage ? Colors.white : theme.colorScheme.onSurface;
    final muted = foreground.withValues(alpha: .64);
    final surface = AspectRatio(
      aspectRatio: widgetSizeAspect(size),
      child: ClipRRect(
        key: ValueKey('widget_surface_${definition.id}'),
        borderRadius: BorderRadius.circular(veriRadiusLg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: veriContentSurfaceColor(theme.brightness),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage) ...[
                Image(
                  image: imageProviderForSource(source),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
                ColoredBox(
                  color: Colors.black.withValues(
                    alpha: math.max(.35, background.overlayOpacity),
                  ),
                ),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final short = size == WidgetSize.oneByTwo;
                  final padding = short ? 12.0 : 14.0;
                  final text =
                      data?.primary.formatted(
                        data.currencyCode,
                        hidden: definition.hideAmounts,
                      ) ??
                      '—';
                  final label = data == null
                      ? l.widgetRefreshRequired
                      : widgetMetricLabel(l, data.primary.metric);
                  final metric = _MetricBlock(
                    definitionId: definition.id,
                    label: label,
                    value: text,
                    foreground: foreground,
                    muted: muted,
                    large: !short,
                  );
                  final title = Text(
                    definition.name,
                    key: ValueKey('widget_name_${definition.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  );
                  final quick = SizedBox(
                    key: ValueKey('widget_entry_button_${definition.id}'),
                    width: 40,
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: veriRoyal,
                        borderRadius: BorderRadius.circular(veriRadiusMd),
                      ),
                      child: const Center(
                        child: Icon(Icons.add, size: 24, color: Colors.white),
                      ),
                    ),
                  );
                  final chart =
                      data != null &&
                          data.hasChartData &&
                          definition.chartMetric != null
                      ? CustomPaint(
                          key: ValueKey('widget_chart_${definition.id}'),
                          painter: WidgetPreviewChartPainter(
                            values: data.series,
                            color: hasImage ? Colors.white : veriRoyal,
                          ),
                          child: const SizedBox.expand(),
                        )
                      : const SizedBox.expand();
                  final ring = _BudgetProgress(
                    value: data?.budgetUsage,
                    color: hasImage ? Colors.white : veriRoyal,
                    textColor: foreground,
                  );
                  final auxiliaries = _AuxiliaryMetrics(
                    data: data,
                    definition: definition,
                    foreground: foreground,
                    muted: muted,
                  );

                  if (short) {
                    return Padding(
                      padding: EdgeInsets.all(padding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                title,
                                const SizedBox(height: 4),
                                Flexible(child: metric),
                              ],
                            ),
                          ),
                          if (definition.template ==
                              WidgetTemplate.quickEntry) ...[
                            const SizedBox(width: 12),
                            quick,
                          ],
                          if (definition.template == WidgetTemplate.budget) ...[
                            const SizedBox(width: 8),
                            SizedBox(width: 44, height: 44, child: ring),
                          ],
                        ],
                      ),
                    );
                  }

                  final isWide = size == WidgetSize.twoByFour;
                  return Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        const SizedBox(height: 8),
                        Expanded(
                          child: isWide
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: metric,
                                            ),
                                          ),
                                          auxiliaries,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child:
                                          definition.template ==
                                              WidgetTemplate.budget
                                          ? Center(
                                              child: SizedBox(
                                                width: 76,
                                                height: 76,
                                                child: ring,
                                              ),
                                            )
                                          : definition.template ==
                                                WidgetTemplate.quickEntry
                                          ? Align(
                                              alignment: Alignment.bottomRight,
                                              child: quick,
                                            )
                                          : chart,
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: metric,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      height: 44,
                                      child:
                                          definition.template ==
                                              WidgetTemplate.quickEntry
                                          ? Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Expanded(child: auxiliaries),
                                                const SizedBox(width: 8),
                                                quick,
                                              ],
                                            )
                                          : definition.template ==
                                                WidgetTemplate.budget
                                          ? Row(
                                              children: [
                                                Expanded(child: auxiliaries),
                                                const SizedBox(width: 8),
                                                SizedBox(
                                                  width: 44,
                                                  height: 44,
                                                  child: ring,
                                                ),
                                              ],
                                            )
                                          : chart,
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (width == double.infinity) return surface;
    return Center(
      child: SizedBox(width: previewWidth, child: surface),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.definitionId,
    required this.label,
    required this.value,
    required this.foreground,
    required this.muted,
    required this.large,
  });
  final String definitionId;
  final String label;
  final String value;
  final Color foreground;
  final Color muted;
  final bool large;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (large)
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: muted, fontSize: 11, height: 1.1),
        ),
      if (large) const SizedBox(height: 4),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            key: ValueKey('widget_amount_$definitionId'),
            textAlign: TextAlign.left,
            style: TextStyle(
              color: foreground,
              fontSize: large ? 30 : 24,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ],
  );
}

class _AuxiliaryMetrics extends StatelessWidget {
  const _AuxiliaryMetrics({
    required this.data,
    required this.definition,
    required this.foreground,
    required this.muted,
  });
  final WidgetPresentation? data;
  final UserWidgetDefinition definition;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    if (data == null || data!.secondary.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in data!.secondary.take(1)) ...[
          Text(
            widgetMetricLabel(l, item.metric),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: muted, fontSize: 10, height: 1.1),
          ),
          const SizedBox(height: 3),
          Text(
            item.formatted(data!.currencyCode, hidden: definition.hideAmounts),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _BudgetProgress extends StatelessWidget {
  const _BudgetProgress({
    required this.value,
    required this.color,
    required this.textColor,
  });
  final double? value;
  final Color color;
  final Color textColor;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: BudgetRingPainter(
      value: (value ?? 0).clamp(0, 1),
      trackColor: color.withValues(alpha: .16),
      progressColor: color,
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: FittedBox(
          child: Text(
            value == null ? '—' : '${(value! * 100).round()}%',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    ),
  );
}

class WidgetPreviewChartPainter extends CustomPainter {
  const WidgetPreviewChartPainter({required this.values, required this.color});
  final List<double?> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || values.length < 2 || values.any((v) => v == null)) {
      return;
    }
    final points = values.cast<double>();
    final minimum = math.min(0.0, points.reduce(math.min));
    final maximum = points.reduce(math.max);
    final range = math.max(1.0, maximum - minimum);
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final x = 2 + i * (size.width - 4) / (points.length - 1);
      final y = 2 + (maximum - points[i]) / range * (size.height - 4);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    final fill = Path.from(line)
      ..lineTo(size.width - 2, size.height)
      ..lineTo(2, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .30), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(WidgetPreviewChartPainter old) =>
      old.color != color || old.values != values;
}
