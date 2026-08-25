import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/attachment_picker.dart';
import '../app/common_widgets.dart';
import '../app/image_sources.dart';
import '../l10n/app_localizations.dart';

/// 记账表单里的图片附件编辑区：横向缩略图 + 添加按钮（拍照 / 相册），
/// 点击缩略图全屏查看，长按或查看页可删除。[dataUrls] 为当前附件（压缩 JPEG）。
class AttachmentsEditor extends StatelessWidget {
  const AttachmentsEditor({
    super.key,
    required this.dataUrls,
    required this.onAddDataUrl,
    required this.onRemoveIndex,
    this.showHeader = true,
    this.showAddButton = true,
  });

  final List<String> dataUrls;
  final ValueChanged<String> onAddDataUrl;
  final ValueChanged<int> onRemoveIndex;
  final bool showHeader;
  final bool showAddButton;

  Future<void> _add(BuildContext context, {required bool fromCamera}) async {
    final dataUrl = await pickAttachmentDataUrl(fromCamera: fromCamera);
    if (dataUrl == null || dataUrl.isEmpty) {
      return;
    }
    onAddDataUrl(dataUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showHeader) ...<Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.image_outlined,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).attachTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                AppLocalizations.of(context).attachCount(dataUrls.length),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount:
                dataUrls.length +
                (showAddButton && attachmentPickingSupported ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == dataUrls.length) {
                final l10n = AppLocalizations.of(context);
                return VeriAnchoredMenuAnchor(
                  entries: <VeriMenuEntry>[
                    VeriMenuItem(
                      id: 'attachment_camera',
                      icon: Icons.photo_camera_outlined,
                      title: l10n.attachTakePhoto,
                      onPressed: () =>
                          unawaited(_add(context, fromCamera: true)),
                    ),
                    VeriMenuItem(
                      id: 'attachment_gallery',
                      icon: Icons.photo_library_outlined,
                      title: l10n.attachFromGallery,
                      onPressed: () =>
                          unawaited(_add(context, fromCamera: false)),
                    ),
                  ],
                  semanticLabel: l10n.attachTitle,
                  width: 196,
                  builder: (context, openMenu, menuOpen) =>
                      _AddButton(onTap: openMenu),
                );
              }
              final dataUrl = dataUrls[index];
              return _Thumb(
                index: index,
                dataUrl: dataUrl,
                onView: () => _viewFullScreen(context, index),
                onRemove: () => onRemoveIndex(index),
              );
            },
          ),
        ),
        if (showAddButton && !attachmentPickingSupported)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              AppLocalizations.of(context).attachUnsupported,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
      ],
    );
  }

  void _viewFullScreen(BuildContext context, int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _AttachmentViewerPage(
          dataUrls: dataUrls,
          initialIndex: index,
          onRemoveIndex: onRemoveIndex,
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(veriRadiusSm),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.18),
          ),
        ),
        child: Icon(
          Icons.add_a_photo_outlined,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.index,
    required this.dataUrl,
    required this.onView,
    required this.onRemove,
  });

  final int index;
  final String dataUrl;
  final VoidCallback onView;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: onView,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(veriRadiusSm),
            child: SizedBox(
              width: 76,
              height: 76,
              child: imageForSource(dataUrl),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  key: Key('attachment_remove_visual_$index'),
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 10, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttachmentViewerPage extends StatefulWidget {
  const _AttachmentViewerPage({
    required this.dataUrls,
    required this.initialIndex,
    required this.onRemoveIndex,
  });

  final List<String> dataUrls;
  final int initialIndex;
  final ValueChanged<int> onRemoveIndex;

  @override
  State<_AttachmentViewerPage> createState() => _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends State<_AttachmentViewerPage> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_index + 1} / ${widget.dataUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: AppLocalizations.of(context).attachDeleteTooltip,
            onPressed: () {
              widget.onRemoveIndex(_index);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.delete_outline, color: Colors.white),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.dataUrls.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(child: imageForSource(widget.dataUrls[index])),
        ),
      ),
    );
  }
}
