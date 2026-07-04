// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json',
}) async {
  final blob = html.Blob(<String>[content], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}

Future<String?> pickTextFile() => _pickFileAsText('.json,application/json');

Future<String?> pickCsvFile() =>
    _pickFileAsText('.csv,.txt,text/csv,text/plain');

Future<String?> _pickFileAsText(String accept) {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = false;

  input.onChange.first.then((_) {
    final file = input.files?.isEmpty ?? true ? null : input.files!.first;
    if (file == null) {
      completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('读取文件失败'));
      }
    });
    reader.onLoad.first.then((_) {
      if (!completer.isCompleted) {
        completer.complete(reader.result as String?);
      }
    });
    reader.readAsText(file);
  });
  // 用户取消对话框时不会触发 change,监听 cancel 以完成 Future。
  input.on['cancel'].first.then((_) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });

  input.click();
  return completer.future;
}
