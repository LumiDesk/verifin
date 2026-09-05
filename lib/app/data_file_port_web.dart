import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

export 'data_file_picker.dart';

/// true 只表示浏览器已接收下载请求，浏览器不会返回用户最终保存的路径。
Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json',
}) => downloadBytesFile(
  filename: filename,
  bytes: utf8.encode(content),
  mimeType: mimeType,
);

Future<bool> downloadBytesFile({
  required String filename,
  required Uint8List bytes,
  String mimeType = 'application/zip',
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.appendChild(anchor);
  try {
    anchor.click();
  } finally {
    anchor.remove();
    // 下载任务异步读取 blob；不能在 click 同步返回时立即回收。
    Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  }
  return true;
}
