import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'common_widgets.dart';
import 'image_sources.dart';

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

/// 预览里 offset=±1 对应的最大平移量（显示像素）。与实际裁剪
/// （`cropImageDataUrl`）同一套映射：±1 恰好把取景框推到图片边缘，
/// 保证「预览看到的 = 保存下来的」。
Offset cropperPanShift({
  required Size sourceSize,
  required Size boxSize,
  required double zoom,
}) {
  if (sourceSize.width <= 0 || sourceSize.height <= 0 || boxSize.isEmpty) {
    return Offset.zero;
  }
  final coverScale = math.max(
    boxSize.width / sourceSize.width,
    boxSize.height / sourceSize.height,
  );
  final scale = coverScale * zoom;
  final visibleWidth = boxSize.width / scale;
  final visibleHeight = boxSize.height / scale;
  final maxOffsetX = math.max(0.0, sourceSize.width - visibleWidth) / 2;
  final maxOffsetY = math.max(0.0, sourceSize.height - visibleHeight) / 2;
  return Offset(maxOffsetX * scale, maxOffsetY * scale);
}

class _ImageCropperPageState extends State<ImageCropperPage> {
  double _zoom = 1;
  double _offsetX = 0;
  double _offsetY = 0;

  // 图片解码后的真实尺寸（已含 EXIF 方向），平移映射需要它换算比例。
  Size? _sourceSize;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  @override
  void initState() {
    super.initState();
    _imageStream = imageProviderForSource(
      widget.imageDataUrl,
    ).resolve(ImageConfiguration.empty);
    _imageListener = ImageStreamListener((ImageInfo info, _) {
      if (mounted) {
        setState(() {
          _sourceSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      }
      info.dispose();
    });
    _imageStream!.addListener(_imageListener!);
  }

  @override
  void dispose() {
    if (_imageListener != null) {
      _imageStream?.removeListener(_imageListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          widget.circlePreview ? 999 : veriRadiusMd,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sourceSize = _sourceSize;
            // 尺寸未知（图片尚在解码）时先不平移，数据 URL 解码近乎即时。
            final maxShift = sourceSize == null
                ? Offset.zero
                : cropperPanShift(
                    sourceSize: sourceSize,
                    boxSize: constraints.biggest,
                    zoom: _zoom,
                  );
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(color: Colors.black.withValues(alpha: 0.92)),
                Transform.translate(
                  offset: Offset(
                    _offsetX * maxShift.dx,
                    _offsetY * maxShift.dy,
                  ),
                  child: Transform.scale(
                    scale: _zoom,
                    child: imageForSource(
                      widget.imageDataUrl,
                      fit: BoxFit.cover,
                    ),
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
            );
          },
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
