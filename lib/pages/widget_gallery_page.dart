import 'package:flutter/material.dart';

import '../app/common_widgets.dart';
import '../app/home_widget_service.dart';
import '../app/native_widget_preview.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';

class WidgetGalleryPage extends StatefulWidget {
  const WidgetGalleryPage({super.key});
  @override
  State<WidgetGalleryPage> createState() => _WidgetGalleryPageState();
}

class _WidgetGalleryPageState extends State<WidgetGalleryPage> {
  Future<void>? _ready;
  int _generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ready = pushWidgetData(VeriFinScope.of(context));
    _generation++;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              VeriHeader(
                title: l.widgetGalleryTitle,
                subtitle: l.widgetGallerySubtitle,
                showBack: true,
              ),
              const SizedBox(height: 10),
              FutureBuilder<void>(
                future: _ready,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final column = ((constraints.maxWidth - 12) / 2)
                          .floor()
                          .clamp(100, 280);
                      final width = column * 2 + 12;
                      final trendTop = 72 + column + 24;
                      Widget preview(
                        String template,
                        String label,
                        int w,
                        int h,
                      ) => NativeWidgetPreview(
                        key: ValueKey('$_generation:$template'),
                        template: template,
                        width: w,
                        height: h,
                        semanticLabel: label,
                      );
                      return SizedBox(
                        height: (trendTop + column).toDouble(),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              child: preview(
                                'quick_entry',
                                l.widgetQuickEntryName,
                                column,
                                72,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: preview(
                                'budget',
                                l.widgetBudgetName,
                                column,
                                column,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 84,
                              child: preview(
                                'net_worth',
                                l.widgetNetWorthName,
                                column,
                                column,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: trendTop.toDouble(),
                              child: preview(
                                'trend',
                                l.widgetTrendName,
                                width,
                                column,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(l.widgetHowToAddDesc),
            ],
          ),
        ),
      ),
    );
  }
}
