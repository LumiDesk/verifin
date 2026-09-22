import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

const widgetConfigPrefix = 'verifin.widget.config.';
const widgetBasicMetrics = [
  'todayExpense',
  'budgetRemaining',
  'netWorth',
  'periodExpense',
];

/// One edit session owns exactly one launcher instance. No ledger Controller is
/// constructed in the secondary Flutter engine.
class WidgetConfigurationSession {
  const WidgetConfigurationSession({
    required this.id,
    required this.template,
    required this.provider,
    required this.books,
    required this.bookId,
    required this.metric,
  });
  final int id;
  final String template;
  final String provider;
  final Map<String, String> books;
  final String bookId;
  final String metric;

  static const _channel = MethodChannel('verifin/app');
  static Future<WidgetConfigurationSession> load() async {
    final id = int.tryParse(
      await HomeWidget.initiallyLaunchedFromHomeWidgetConfigure() ?? '',
    );
    if (id == null || id <= 0) throw StateError('Invalid widget instance');
    final info = await _channel.invokeMapMethod<String, Object?>(
      'widgetConfigurationInfo',
      {'widgetId': id},
    );
    if (info == null) throw StateError('Widget metadata unavailable');
    final rawBooks = await HomeWidget.getWidgetData<String>(
      'verifin.widget.books',
      defaultValue: '[]',
    );
    final books = <String, String>{};
    for (final book
        in (jsonDecode(rawBooks ?? '[]') as List).whereType<Map>()) {
      if (book['id'] is String && (book['id'] as String).isNotEmpty) {
        books[book['id'] as String] = book['name']?.toString() ?? '';
      }
    }
    final raw = await HomeWidget.getWidgetData<String>(
      '$widgetConfigPrefix$id',
    );
    final config = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    final active = await HomeWidget.getWidgetData<String>(
      'verifin.widget.active_book',
    );
    // An explicitly selected deleted book stays unresolved: never substitute a
    // different ledger silently. The form requires selecting an existing book.
    final selected = config['bookId'] as String?;
    final bookId = selected?.isNotEmpty == true
        ? selected!
        : (books.containsKey(active) ? active! : books.keys.firstOrNull ?? '');
    final metric = config['metric'] as String?;
    return WidgetConfigurationSession(
      id: id,
      template: info['template'] as String,
      provider: info['provider'] as String,
      books: books,
      bookId: bookId,
      metric: widgetBasicMetrics.contains(metric)
          ? metric!
          : info['metric'] as String,
    );
  }

  Future<void> save({required String bookId, required String metric}) async {
    if (!books.containsKey(bookId) || !widgetBasicMetrics.contains(metric)) {
      throw StateError('Invalid widget configuration');
    }
    final encoded = jsonEncode({'bookId': bookId, 'metric': metric});
    final saved = await HomeWidget.saveWidgetData<String>(
      '$widgetConfigPrefix$id',
      encoded,
    );
    if (saved != true) throw StateError('Widget preference write failed');
    final reread = await HomeWidget.getWidgetData<String>(
      '$widgetConfigPrefix$id',
    );
    if (reread != encoded) {
      throw StateError('Widget preference verification failed');
    }
    // Publish this exact instance before acknowledging success to the launcher.
    // This uses the same Glance content as previews; no broadcast timing race.
    await _channel.invokeMethod<void>('refreshWidgetInstance', {
      'widgetId': id,
    });
    await HomeWidget.finishHomeWidgetConfigure();
  }
}
