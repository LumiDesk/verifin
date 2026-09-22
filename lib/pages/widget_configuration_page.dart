import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/feedback.dart';
import '../app/logging/app_logger.dart';
import '../app/native_widget_preview.dart';
import '../app/widget_configuration_session.dart';
import '../local_storage/local_storage.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

Future<void> runWidgetConfiguration() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = AppLogger(await LocalKeyValueStore.create());
  final locale = await HomeWidget.getWidgetData<String>(
    'verifin.widget.locale',
  );
  final theme = await HomeWidget.getWidgetData<String>('verifin.widget.theme');
  runApp(WidgetConfigurationApp(logger: logger, locale: locale, theme: theme));
}

class WidgetConfigurationApp extends StatefulWidget {
  const WidgetConfigurationApp({
    super.key,
    this.logger,
    this.locale,
    this.theme,
  });
  final AppLogger? logger;
  final String? locale;
  final String? theme;
  @override
  State<WidgetConfigurationApp> createState() => _WidgetConfigurationAppState();
}

class _WidgetConfigurationAppState extends State<WidgetConfigurationApp> {
  final _feedback = VeriFeedbackController();
  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: widget.locale == null
        ? null
        : Locale(widget.locale!.split('_').first),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: buildVeriFinTheme(Brightness.light),
    darkTheme: buildVeriFinTheme(Brightness.dark),
    themeMode: switch (widget.theme) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    },
    builder: (context, child) =>
        VeriFeedbackHost(controller: _feedback, child: child!),
    home: WidgetConfigurationPage(logger: widget.logger),
  );
}

class WidgetConfigurationPage extends StatefulWidget {
  const WidgetConfigurationPage({super.key, this.logger});
  final AppLogger? logger;
  @override
  State<WidgetConfigurationPage> createState() =>
      _WidgetConfigurationPageState();
}

class _WidgetConfigurationPageState extends State<WidgetConfigurationPage> {
  WidgetConfigurationSession? _session;
  String _bookId = '';
  String _metric = '';
  bool _loading = true, _failed = false, _saving = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final session = await WidgetConfigurationSession.load();
      if (!mounted) return;
      setState(() {
        _session = session;
        _bookId = session.bookId;
        _metric = session.metric;
        _loading = false;
      });
    } on Object catch (error) {
      widget.logger?.error(
        'Widget configuration load failed',
        source: 'widgets',
        error: error,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _session == null) return;
    setState(() => _saving = true);
    try {
      await _session!.save(bookId: _bookId, metric: _metric);
    } on Object catch (error) {
      widget.logger?.error(
        'Widget configuration save failed',
        source: 'widgets',
        error: error,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: AppLocalizations.of(context).saveFailed,
          tone: VeriFeedbackTone.error,
        ),
      );
    }
  }

  String _label(AppLocalizations l, String metric) => switch (metric) {
    'budgetRemaining' => l.widgetMetricBudgetRemaining,
    'netWorth' => l.widgetMetricNetWorth,
    'periodExpense' => l.widgetMetricPeriodExpense,
    _ => l.widgetMetricTodayExpense,
  };

  Future<void> _pickBook(WidgetConfigurationSession session) async {
    final selected = await showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).widgetBook,
      values: session.books.keys.toList(growable: false),
      selected: _bookId,
      labelOf: (id) => session.books[id] ?? id,
    );
    if (selected != null && mounted && !_saving) {
      setState(() => _bookId = selected);
    }
  }

  Future<void> _pickMetric() async {
    final l = AppLocalizations.of(context);
    final selected = await showOptionSheet<String>(
      context: context,
      title: l.widgetPrimaryMetric,
      values: widgetBasicMetrics,
      selected: _metric,
      labelOf: (metric) => _label(l, metric),
    );
    if (selected != null && mounted && !_saving) {
      setState(() => _metric = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final session = _session;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                VeriHeader(
                  title: l.widgetConfigTitle,
                  showBack: true,
                  onBack: _saving ? () {} : () => SystemNavigator.pop(),
                ),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_failed || session == null)
                  Text(l.widgetConfigurationFailed)
                else ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width =
                          (session.template == 'trend'
                                  ? constraints.maxWidth
                                  : 180.0)
                              .floor()
                              .clamp(100, 560);
                      final height = session.template == 'quick_entry'
                          ? 72
                          : 180;
                      return Center(
                        child: NativeWidgetPreview(
                          template: session.template,
                          width: width,
                          height: height,
                          bookId: _bookId,
                          metric: _metric,
                          sample: false,
                          semanticLabel: l.widgetPreview,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l.widgetBook,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    key: const Key('widget_book'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(session.books[_bookId] ?? _bookId),
                    trailing: const Icon(Icons.expand_more),
                    onTap: _saving ? null : () => _pickBook(session),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l.widgetPrimaryMetric,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    key: const Key('widget_metric'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(_label(l, _metric)),
                    trailing: const Icon(Icons.expand_more),
                    onTap: _saving ? null : _pickMetric,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('widget_save'),
                    onPressed: _saving || !session.books.containsKey(_bookId)
                        ? null
                        : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(),
                          )
                        : Text(l.widgetSaveConfig),
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
