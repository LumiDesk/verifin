import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../app/app_theme.dart';
import '../l10n/app_localizations.dart';

@pragma('vm:entry-point')
Future<void> runWidgetConfiguration() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WidgetConfigurationApp());
}

class WidgetConfigurationApp extends StatelessWidget {
  const WidgetConfigurationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildVeriFinTheme(Brightness.light),
      darkTheme: buildVeriFinTheme(Brightness.dark),
      home: const WidgetConfigurationPage(),
    );
  }
}

class WidgetConfigurationPage extends StatefulWidget {
  const WidgetConfigurationPage({super.key});

  @override
  State<WidgetConfigurationPage> createState() =>
      _WidgetConfigurationPageState();
}

class _WidgetConfigurationPageState extends State<WidgetConfigurationPage> {
  int? _widgetId;
  List<Map<String, String>> _books = const [];
  Map<String, Map<String, String>> _snapshots = const {};
  String _bookId = '';
  String _metric = 'todayExpense';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await HomeWidget.initiallyLaunchedFromHomeWidgetConfigure();
    final booksRaw = await HomeWidget.getWidgetData<String>(
      'verifin.widget.books',
      defaultValue: '[]',
    );
    final snapshotsRaw = await HomeWidget.getWidgetData<String>(
      'verifin.widget.snapshots',
      defaultValue: '{}',
    );
    final books = <Map<String, String>>[];
    final snapshots = <String, Map<String, String>>{};
    try {
      final list = jsonDecode(booksRaw ?? '[]');
      if (list is List) {
        for (final item in list.whereType<Map>()) {
          final book = <String, String>{
            'id': item['id']?.toString() ?? '',
            'name': item['name']?.toString() ?? '',
          };
          if (book['id']!.isNotEmpty) books.add(book);
        }
      }
    } on Object {
      // An empty list is a safe configuration fallback.
    }
    try {
      final decoded = jsonDecode(snapshotsRaw ?? '{}');
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is Map) {
            final values = <String, String>{};
            for (final metric in value.entries) {
              final item = metric.value;
              if (item is Map) {
                values[metric.key.toString()] =
                    item['amount']?.toString() ?? '0';
              }
            }
            snapshots[entry.key.toString()] = values;
          }
        }
      }
    } on Object {
      // Preview falls back to zero when a projection is unavailable.
    }
    if (!mounted) return;
    setState(() {
      _widgetId = int.tryParse(id ?? '');
      _books = books;
      _snapshots = snapshots;
      _bookId = books.isEmpty ? '' : books.first['id']!;
      _loading = false;
    });
  }

  String _value() =>
      _snapshots[_bookId]?[_metric] ?? _snapshots[_bookId]?['amount'] ?? '0';

  String _label(AppLocalizations l10n) => switch (_metric) {
    'budgetRemaining' => l10n.widgetMetricBudgetRemaining,
    'netWorth' => l10n.widgetMetricNetWorth,
    'periodExpense' => l10n.widgetMetricPeriodExpense,
    _ => l10n.widgetMetricTodayExpense,
  };

  Future<void> _save() async {
    final widgetId = _widgetId;
    if (widgetId == null || widgetId <= 0) return;
    setState(() => _saving = true);
    try {
      await HomeWidget.saveWidgetData(
        'verifin.widget.config.$widgetId',
        jsonEncode(<String, String>{'bookId': _bookId, 'metric': _metric}),
      );
      final providers = <String>[
        'top.talyra42.verifin.QuickEntryWidgetProvider',
        'top.talyra42.verifin.BudgetWidgetProvider',
        'top.talyra42.verifin.NetWorthWidgetProvider',
        'top.talyra42.verifin.TrendWidgetProvider',
      ];
      for (final provider in providers) {
        await HomeWidget.updateWidget(qualifiedAndroidName: provider);
      }
      await HomeWidget.finishHomeWidgetConfigure();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.widgetConfigTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _PreviewCard(label: _label(l10n), amount: _value()),
          const SizedBox(height: 20),
          Text(l10n.widgetBook, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _bookId.isEmpty ? null : _bookId,
            items: _books
                .map(
                  (book) => DropdownMenuItem<String>(
                    value: book['id'],
                    child: Text(
                      book['name']!.isEmpty ? book['id']! : book['name']!,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _bookId = value ?? ''),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.widgetPrimaryMetric,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _metric,
            items:
                [
                      ('todayExpense', l10n.widgetMetricTodayExpense),
                      ('budgetRemaining', l10n.widgetMetricBudgetRemaining),
                      ('netWorth', l10n.widgetMetricNetWorth),
                      ('periodExpense', l10n.widgetMetricPeriodExpense),
                    ]
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.$1,
                        child: Text(item.$2),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _metric = value ?? _metric),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.widgetSaveConfig),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 132,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(veriRadiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
