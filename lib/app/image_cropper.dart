import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'common_widgets.dart';

class ImageCropResult {
  const ImageCropResult({
    required this.zoom,
    required this.offsetX,
    required this.offsetY,
  });

  final double zoom;
  final double offsetX;
  final double offsetY;
}

Future<ImageCropResult?> showImageCropper({
  required BuildContext context,
  required String imageDataUrl,
  required String title,
  required double aspectRatio,
  bool circlePreview = false,
}) {
  return Navigator.of(context).push<ImageCropResult>(
    MaterialPageRoute<ImageCropResult>(
      builder: (context) => ImageCropperPage(
        imageDataUrl: imageDataUrl,
        title: title,
        aspectRatio: aspectRatio,
        circlePreview: circlePreview,
      ),
    ),
  );
}

class ImageCropperPage extends StatefulWidget {
  const ImageCropperPage({
    super.key,
    required this.imageDataUrl,
    required this.title,
    required this.aspectRatio,
    this.circlePreview = false,
  });

  final String imageDataUrl;
  final String title;
  final double aspectRatio;
  final bool circlePreview;

  @override
  State<ImageCropperPage> createState() => _ImageCropperPageState();
}

class _ImageCropperPageState extends State<ImageCropperPage> {
  double _zoom = 1;
  double _offsetX = 0;
  double _offsetY = 0;

  @override
  Widget build(BuildContext context) {
    final preview = AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          widget.circlePreview ? 999 : veriRadiusMd,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: Colors.black.withValues(alpha: 0.92)),
            Transform.translate(
              offset: Offset(_offsetX * 74, _offsetY * 74),
              child: Transform.scale(
                scale: _zoom,
                child: Image.network(widget.imageDataUrl, fit: BoxFit.cover),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  widget.circlePreview ? 999 : veriRadiusMd,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.70),
                  width: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: widget.title,
                subtitle: '调整图片位置',
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.check,
                    tooltip: '完成裁剪',
                    onPressed: () {
                      Navigator.of(context).pop(
                        ImageCropResult(
                          zoom: _zoom,
                          offsetX: _offsetX,
                          offsetY: _offsetY,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: <Widget>[
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: widget.circlePreview ? 240 : 380,
                        ),
                        child: preview,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CropSlider(
                      label: '缩放',
                      value: _zoom,
                      min: 1,
                      max: 3,
                      divisions: 40,
                      onChanged: (value) => setState(() => _zoom = value),
                    ),
                    _CropSlider(
                      label: '水平',
                      value: _offsetX,
                      min: -1,
                      max: 1,
                      divisions: 40,
                      onChanged: (value) => setState(() => _offsetX = value),
                    ),
                    _CropSlider(
                      label: '垂直',
                      value: _offsetY,
                      min: -1,
                      max: 1,
                      divisions: 40,
                      onChanged: (value) => setState(() => _offsetY = value),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _zoom = 1;
                            _offsetX = 0;
                            _offsetY = 0;
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 17),
                        label: const Text('重置'),
                      ),
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

class _CropSlider extends StatelessWidget {
  const _CropSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
