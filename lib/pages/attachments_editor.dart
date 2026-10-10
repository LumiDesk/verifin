import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/attachment_picker.dart';
import '../app/attachments/attachment_store.dart';
import '../app/common_widgets.dart';
import '../app/models.dart';
import '../l10n/app_localizations.dart';

/// 记账表单里的图片附件编辑区：横向缩略图 + 添加按钮（拍照 / 相册），
/// 点击缩略图全屏查看，长按或查看页可删除。
///
/// 附件字节存应用私有文件，缩略图经 [store] 按 id 取图并限制解码宽度，
/// 不在内存里保留 base64；[onAddBytes] 由调用方把新图片落盘后再交给本组件。
class AttachmentsEditor extends StatelessWidget {
  const AttachmentsEditor({
    super.key,
    required this.attachments,
    required this.store,
    required this.onAddBytes,
    required this.onRemoveIndex,
    this.showHeader = true,
    this.showAddButton = true,
  });

  final List<Attachment> attachments;
  final AttachmentStore store;
  final Future<void> Function(Uint8List bytes) onAddBytes;
  final ValueChanged<int> onRemoveIndex;
  final bool showHeader;
  final bool showAddButton;

  Future<void> _add(BuildContext context, {required bool fromCamera}) async {
    final bytes = await pickAttachmentBytes(fromCamera: fromCamera);
    if (bytes == null || bytes.isEmpty) {
      return;
    }
    await onAddBytes(bytes);
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
                AppLocalizations.of(context).attachCount(attachments.length),
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
                attachments.length +
                (showAddButton && attachmentPickingSupported ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == attachments.length) {
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
                  builder: (context, openMenu, menuOpen) =>
                      _AddButton(onTap: openMenu),
                );
              }
              return _Thumb(
                index: index,
                store: store,
                attachment: attachments[index],
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
          attachments: attachments,
          store: store,
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
    required this.store,
    required this.attachment,
    required this.onView,
    required this.onRemove,
  });

  final int index;
  final AttachmentStore store;
  final Attachment attachment;
  final VoidCallback onView;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: onView,
          // 长按删除：与类注释一致，避免只能点右上角 16dp 小叉删除。
          onLongPress: onRemove,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(veriRadiusSm),
            child: SizedBox(
              width: 76,
              height: 76,
              child: Image(
                image: store.imageProviderFor(attachment.id, cacheWidth: 160),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.08),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
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
    required this.attachments,
    required this.store,
    required this.initialIndex,
    required this.onRemoveIndex,
  });

  final List<Attachment> attachments;
  final AttachmentStore store;
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
          '${_index + 1} / ${widget.attachments.length}',
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
        itemCount: widget.attachments.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image(
              image: widget.store.imageProviderFor(
                widget.attachments[index].id,
              ),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
