import 'dart:typed_data';

/// 一次图片附件选择与处理的结果。
///
/// 相册一次可选多张，拍照为单张；取消选择时 [picked] 为 0。
class AttachmentPickOutcome {
  const AttachmentPickOutcome({
    required this.picked,
    required this.added,
    required this.failed,
    this.stoppedEarly = false,
    this.error,
    this.stackTrace,
  });

  const AttachmentPickOutcome.cancelled()
    : picked = 0,
      added = 0,
      failed = 0,
      stoppedEarly = false,
      error = null,
      stackTrace = null;

  /// 用户在系统选择器中选中的图片数（相机单张为 1，取消为 0）。
  final int picked;

  /// 已成功交给调用方的图片数。
  final int added;

  /// 读取或解码失败、被跳过的图片数。
  final int failed;

  /// 调用方在添加过程中要求停止后续处理（例如页面已经离开）。
  final bool stoppedEarly;

  /// 第一张读取/解码失败时的原始异常，供调用方写入本地日志。
  ///
  /// 单张坏图属于可接受的降级：跳过它并在 [failed] 里计数，由调用方给出
  /// 用户可见提示；没有失败时为 `null`。
  final Object? error;

  /// 与 [error] 对应的调用栈。
  final StackTrace? stackTrace;
}

/// 选图/压缩实现的可替换签名，供 widget 测试注入。
///
/// 真实实现见 `attachment_picker_image_picker.dart`。
typedef AttachmentPickImages =
    Future<AttachmentPickOutcome> Function({
      required bool fromCamera,
      required Future<bool> Function(Uint8List bytes) onImage,
      void Function(int done, int total)? onProgress,
    });
