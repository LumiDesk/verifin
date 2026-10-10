import 'dart:convert';
import 'dart:io';

import 'package:json_events/json_events.dart';

import '../attachments/attachment_store.dart';
import 'backup_progress.dart';

/// 识别到旧版加密信封（需要口令才能解密）时抛出，交由调用方走信封解密路径。
class LegacyEncryptedEnvelopeDetected implements Exception {
  const LegacyEncryptedEnvelopeDetected();
}

/// 以事件流重写一份旧版（v1/v2）明文备份 JSON。
///
/// 旧版把图片以 base64 内嵌在单个巨大 JSON 文本里，直接 `jsonDecode` 会把整份文档
/// 读进内存（Issue 45 的另一条 OOM 路径）。这里前向遍历事件流：文件按块解码，单张
/// 图片只在处理它时驻留内存，附件 `dataUrl` 解出字节落盘并改写为空串，其余字段原样
/// 转发。输出不含 base64，因此可以安全整份读回交给导入层。
Future<String> rewriteLegacyBackupJson({
  required String sourcePath,
  required AttachmentStore sink,
  BackupProgressCallback? onProgress,
  bool Function()? isCancelled,
}) async {
  final out = StringBuffer();
  final rewriter = _LegacyJsonRewriter(out, sink);
  onProgress?.call(const BackupProgress(phase: BackupPhase.unpacking));
  final events = File(sourcePath)
      .openRead()
      .transform(const Utf8Decoder())
      .transform(const JsonEventDecoder())
      .flatten();
  var rewritten = 0;
  await for (final event in events) {
    if (isCancelled?.call() ?? false) {
      throw const BackupCancelledException();
    }
    await rewriter.handle(event);
    if (event.type == JsonEventType.propertyValue && event.value is String) {
      rewritten++;
      if (rewritten % 64 == 0) {
        onProgress?.call(
          BackupProgress(
            phase: BackupPhase.unpacking,
            detail: '${rewriter.convertedAttachments}',
          ),
        );
      }
    }
  }
  return out.toString();
}

/// 事件 → JSON 文本的流式重写器（含附件外置）。
class _LegacyJsonRewriter {
  _LegacyJsonRewriter(this.out, this.sink);

  final StringBuffer out;
  final AttachmentStore sink;

  final List<_Frame> _frames = <_Frame>[];
  bool _lastWasCompositeEnd = false;
  bool _pendingEnvelopeCheck = false;

  /// 已外置的附件数量（进度展示用）。
  int convertedAttachments = 0;

  Future<void> handle(JsonEvent event) async {
    switch (event.type) {
      case JsonEventType.beginObject:
        _beforeValueInArray();
        out.write('{');
        _frames.add(_Frame(isObject: true));
        _lastWasCompositeEnd = false;
      case JsonEventType.endObject:
        out.write('}');
        _frames.removeLast();
        _lastWasCompositeEnd = true;
      case JsonEventType.beginArray:
        _beforeValueInArray();
        out.write('[');
        _frames.add(_Frame(isObject: false));
        _lastWasCompositeEnd = false;
      case JsonEventType.endArray:
        out.write(']');
        _frames.removeLast();
        _lastWasCompositeEnd = true;
      case JsonEventType.propertyName:
        final name = event.value as String;
        final frame = _frames.last;
        if (frame.members > 0) {
          out.write(',');
        }
        frame.members++;
        frame.pendingKey = name;
        if (name == 'enc') {
          _pendingEnvelopeCheck = true;
        }
        out.write(jsonEncode(name));
        out.write(':');
        _lastWasCompositeEnd = false;
      case JsonEventType.propertyValue:
        if (_lastWasCompositeEnd) {
          // 复合值（对象/数组）结束后的补位事件，结构已在 begin/end 写出。
          _lastWasCompositeEnd = false;
          _clearPendingKey();
          return;
        }
        await _writeScalar(event.value);
      case JsonEventType.arrayElement:
        if (_lastWasCompositeEnd) {
          _lastWasCompositeEnd = false;
          return;
        }
        _beforeValueInArray();
        await _writeScalar(event.value);
    }
  }

  void _beforeValueInArray() {
    if (_frames.isEmpty || _frames.last.isObject) {
      return;
    }
    final frame = _frames.last;
    if (frame.members > 0) {
      out.write(',');
    }
    frame.members++;
  }

  void _clearPendingKey() {
    if (_frames.isNotEmpty && _frames.last.isObject) {
      _frames.last.pendingKey = null;
    }
  }

  Future<void> _writeScalar(Object? value) async {
    final frame = _frames.isEmpty ? null : _frames.last;
    final key = frame?.isObject == true ? frame!.pendingKey : null;
    if (_pendingEnvelopeCheck && key == 'enc' && value == 'aes-gcm') {
      // 旧版加密信封：调用方改用口令解密路径。
      throw const LegacyEncryptedEnvelopeDetected();
    }
    if (key == 'id' && value is String) {
      if (frame != null) {
        frame.lastId = value;
      }
    }
    if (key == 'dataUrl' && value is String && value.startsWith('data:')) {
      final id = frame?.lastId;
      if (id == null || id.isEmpty) {
        throw const FormatException('备份文件格式不正确');
      }
      final comma = value.indexOf(',');
      final bytes = comma < 0
          ? null
          : _tryDecodeBase64(value.substring(comma + 1));
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('备份文件格式不正确');
      }
      await sink.writeBytes(id, bytes);
      convertedAttachments++;
      final mime = _dataUrlMime(value);
      // 写出空 dataUrl，并补上导入层需要的 MIME 与字节数。
      out.write(jsonEncode(''));
      out.write(',${jsonEncode('mimeType')}:${jsonEncode(mime)}');
      out.write(',${jsonEncode('byteSize')}:${bytes.length}');
      _clearPendingKey();
      return;
    }
    out.write(_encodeScalar(value));
    _clearPendingKey();
    _pendingEnvelopeCheck = false;
  }

  static String _encodeScalar(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is String) {
      return jsonEncode(value);
    }
    if (value is bool) {
      return value ? 'true' : 'false';
    }
    if (value is num) {
      return value.toString();
    }
    return jsonEncode(value.toString());
  }
}

class _Frame {
  _Frame({required this.isObject});

  final bool isObject;
  int members = 0;
  String? pendingKey;
  String? lastId;
}

List<int>? _tryDecodeBase64(String value) {
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}

String _dataUrlMime(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma <= 5) return 'image/jpeg';
  final header = dataUrl.substring(5, comma);
  final semicolon = header.indexOf(';');
  final mime = (semicolon < 0 ? header : header.substring(0, semicolon)).trim();
  return RegExp(r'^[a-zA-Z0-9.+-]+/[a-zA-Z0-9.+-]+$').hasMatch(mime)
      ? mime
      : 'image/jpeg';
}
