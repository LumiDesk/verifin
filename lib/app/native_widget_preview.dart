import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'platform_bridge.dart';
import '../l10n/app_localizations.dart';

/// Displays the actual Glance composition. Draft changes only render pixels;
/// they never write the home_widget instance preferences.
class NativeWidgetPreview extends StatefulWidget {
  const NativeWidgetPreview({
    super.key,
    required this.template,
    required this.width,
    required this.height,
    this.bookId = '',
    this.metric = '',
    this.sample = false,
    required this.semanticLabel,
  });
  final String template;
  final int width;
  final int height;
  final String bookId;
  final String metric;
  final bool sample;
  final String semanticLabel;
  @override
  State<NativeWidgetPreview> createState() => _NativeWidgetPreviewState();
}

class _NativeWidgetPreviewState extends State<NativeWidgetPreview> {
  late Future<Uint8List?> _image;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(NativeWidgetPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.template != widget.template ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height ||
        oldWidget.bookId != widget.bookId ||
        oldWidget.metric != widget.metric ||
        oldWidget.sample != widget.sample) {
      _load();
    }
  }

  void _load() {
    _image = AppWidgetBridge.renderPreview(
      template: widget.template,
      widthDp: widget.width,
      heightDp: widget.height,
      bookId: widget.bookId,
      metric: widget.metric,
      sample: widget.sample,
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width.toDouble(),
    height: widget.height.toDouble(),
    child: Semantics(
      label: widget.semanticLabel,
      image: true,
      child: FutureBuilder<Uint8List?>(
        future: _image,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data;
          if (snapshot.hasError || bytes == null) {
            return Center(
              child: Text(AppLocalizations.of(context).widgetPreviewFailed),
            );
          }
          return Image.memory(
            bytes,
            key: ValueKey('native_widget_preview_${widget.template}'),
            width: widget.width.toDouble(),
            height: widget.height.toDouble(),
            excludeFromSemantics: true,
          );
        },
      ),
    ),
  );
}
