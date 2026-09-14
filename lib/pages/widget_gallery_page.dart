import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/common_widgets.dart';
import '../app/home_widget_service.dart';
import '../app/platform_bridge.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';

/// Every card is rendered by Android's actual provider layout. Flutter only
/// positions the returned pixels, so it cannot silently drift from the widget.
class WidgetGalleryPage extends StatefulWidget {
  const WidgetGalleryPage({super.key});

  @override
  State<WidgetGalleryPage> createState() => _WidgetGalleryPageState();
}

class _WidgetGalleryPageState extends State<WidgetGalleryPage> {
  late VeriFinController _controller;
  late Future<void> _dataReady;
  final _previews = <String, Future<Uint8List?>>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = VeriFinScope.of(context);
    _dataReady = pushWidgetData(_controller);
    _previews.clear();
  }

  Future<Uint8List?> _render(String template, int width, int height) async {
    try {
      await _dataReady;
      return await AppWidgetBridge.renderPreview(
        template: template,
        widthDp: width,
        heightDp: height,
      );
    } catch (error) {
      _controller.logger?.error(
        'Native widget preview failed',
        source: 'widgets',
        error: error,
      );
      rethrow;
    }
  }

  Widget _card(String template, String label, int width, int height) {
    final key = '$template:$width:$height';
    return SizedBox(
      width: width.toDouble(),
      height: height.toDouble(),
      child: Semantics(
        label: label,
        image: true,
        child: FutureBuilder<Uint8List?>(
          future: _previews.putIfAbsent(
            key,
            () => _render(template, width, height),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final bytes = snapshot.data;
            if (snapshot.hasError || bytes == null) {
              return Center(
                child: Text(AppLocalizations.of(context).widgetRefreshRequired),
              );
            }
            return Image.memory(
              bytes,
              key: ValueKey('native_widget_preview_$template'),
              width: width.toDouble(),
              height: height.toDouble(),
              gaplessPlayback: true,
              excludeFromSemantics: true,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: [
              VeriHeader(
                title: l.widgetGalleryTitle,
                subtitle: l.widgetGallerySubtitle,
                showBack: true,
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final column = ((constraints.maxWidth - 12) / 2)
                      .floor()
                      .clamp(100, 280);
                  final width = column * 2 + 12;
                  const quickHeight = 72;
                  final trendTop = quickHeight + column + 24;
                  return SizedBox(
                    height: (trendTop + column).toDouble(),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: _card(
                            'quick_entry',
                            l.widgetQuickEntryName,
                            column,
                            quickHeight,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: _card(
                            'budget',
                            l.widgetBudgetName,
                            column,
                            column,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: quickHeight + 12,
                          child: _card(
                            'net_worth',
                            l.widgetNetWorthName,
                            column,
                            column,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: trendTop.toDouble(),
                          child: _card(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
