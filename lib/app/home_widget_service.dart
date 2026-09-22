import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'l10n_outside_context.dart';
import 'veri_fin_controller.dart';
import 'widget_config.dart';
import 'widget_presentation.dart';

const _widgetProviders = <String>[
  'top.talyra42.verifin.QuickEntryWidgetProvider',
  'top.talyra42.verifin.BudgetWidgetProvider',
  'top.talyra42.verifin.NetWorthWidgetProvider',
  'top.talyra42.verifin.TrendWidgetProvider',
];

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

Map<String, Object?> _metricJson({
  required String label,
  required String amount,
}) => <String, Object?>{'label': label, 'amount': amount};

/// Publishes a process-independent projection through the maintained home_widget
/// plugin. The Glance providers read this data even when Flutter is not running.
Future<void> pushWidgetData(VeriFinController controller) async {
  final l10n = l10nForPreference(controller.localePreference);
  final now = DateTime.now();
  final snapshots = <String, Object?>{};

  for (final book in controller.ledgerBooks) {
    final snapshot = controller.widgetLedgerSnapshot(book.id, now);
    if (snapshot == null) continue;
    final metrics = <String, Object?>{};
    for (final metric in <WidgetMetric>[
      WidgetMetric.todayExpense,
      WidgetMetric.budgetRemaining,
      WidgetMetric.netWorth,
      WidgetMetric.periodExpense,
    ]) {
      final presentation = buildWidgetPresentation(
        definition: WidgetProjectionDefinition(
          id: 'projection_${book.id}_${metric.name}',
          name: 'VeriFin',
          template: switch (metric) {
            WidgetMetric.todayExpense => WidgetTemplate.quickEntry,
            WidgetMetric.budgetRemaining => WidgetTemplate.budget,
            WidgetMetric.netWorth => WidgetTemplate.netWorth,
            _ => WidgetTemplate.trend,
          },
          bookId: book.id,
          primaryMetric: metric,
          chartMetric: null,
        ),
        snapshot: snapshot,
        now: now,
      );
      metrics[metric.name] = _metricJson(
        label: widgetMetricLabel(l10n, metric),
        amount: presentation.primary.formatted(presentation.currencyCode),
      );
    }
    snapshots[book.id] = <String, Object?>{
      'date': _dateKey(now),
      'currency': book.baseCurrencyCode,
      ...metrics,
    };
  }

  try {
    await HomeWidget.saveWidgetData<String>(
      'verifin.widget.snapshots',
      jsonEncode(snapshots),
    );
    await HomeWidget.saveWidgetData<String>(
      'verifin.widget.books',
      jsonEncode(
        controller.ledgerBooks
            .map((book) => <String, Object?>{'id': book.id, 'name': book.name})
            .toList(growable: false),
      ),
    );
    await HomeWidget.saveWidgetData<String>(
      'verifin.widget.active_book',
      controller.activeBook.id,
    );
    await HomeWidget.saveWidgetData<String>(
      'verifin.widget.locale',
      l10n.localeName,
    );

    await Future.wait(
      _widgetProviders.map(
        (provider) => HomeWidget.updateWidget(qualifiedAndroidName: provider),
      ),
    );

    // home_widget owns the alarm receiver and re-arms it after reboot/app update.
    // Recomputing the next local midnight on every foreground push also handles
    // timezone changes without a custom receiver.
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    await Future.wait(
      _widgetProviders.map(
        (provider) => HomeWidget.scheduleWidgetUpdates([
          nextMidnight,
        ], qualifiedAndroidName: provider),
      ),
    );
  } on MissingPluginException {
    // Widget channels do not exist on desktop/widget tests.
  } on Object catch (error) {
    controller.logger?.warning(
      'Widget projection update failed: $error',
      source: 'widgets',
    );
  }
}
