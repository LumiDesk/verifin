import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppPlatformBridge {
  AppPlatformBridge._();

  static const MethodChannel _channel = MethodChannel('verifin/app');
  static Future<void> Function()? _quickEntryHandler;
  static final ValueNotifier<UpdateDownloadProgress?> updateProgress =
      ValueNotifier<UpdateDownloadProgress?>(null);

  static void setQuickEntryHandler(Future<void> Function() handler) {
    _quickEntryHandler = handler;
    _ensureMethodHandler();
  }

  static void clearQuickEntryHandler() {
    _quickEntryHandler = null;
    _ensureMethodHandler();
  }

  static void _ensureMethodHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openQuickEntry') {
        await _quickEntryHandler?.call();
        return;
      }
      if (call.method == 'updateDownloadProgress') {
        final args = Map<String, Object?>.from(
          call.arguments as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{},
        );
        updateProgress.value = UpdateDownloadProgress.fromMap(args);
      }
    });
  }

  static Future<bool> consumeInitialQuickEntryIntent() async {
    try {
      return await _channel.invokeMethod<bool>('consumeQuickEntryIntent') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 推送「今日支出」到 Android 桌面小组件（非 Android 平台静默忽略）。
  static Future<void> updateTodayExpenseWidget({
    required String amount,
    required String label,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateTodayExpenseWidget', {
        'amount': amount,
        'label': label,
      });
    } on MissingPluginException {
      // 非 Android 平台没有桌面小组件。
    } on PlatformException {
      // 小组件更新失败不影响主流程，忽略。
    }
  }

  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'checkLatestRelease',
      );
      return UpdateCheckResult.fromMap(result ?? const <String, Object?>{});
    } on MissingPluginException {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.unsupported,
        message: '当前预览环境不支持 Android 应用更新。',
      );
    } on PlatformException catch (error) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.error,
        message: error.message ?? '检查更新失败，请稍后再试。',
      );
    }
  }

  static Future<UpdateCheckResult> downloadLatestUpdate() async {
    updateProgress.value = const UpdateDownloadProgress(progress: 0);
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'downloadLatestUpdate',
      );
      return UpdateCheckResult.fromMap(result ?? const <String, Object?>{});
    } on MissingPluginException {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.unsupported,
        message: '当前预览环境不支持 Android 应用更新。',
      );
    } on PlatformException catch (error) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.error,
        message: error.message ?? '下载更新失败，请稍后再试。',
      );
    }
  }

  static Future<bool> saveTextToDownloads({
    required String filename,
    required String content,
    required String mimeType,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('saveTextToDownloads', {
            'filename': filename,
            'content': content,
            'mimeType': mimeType,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      throw Exception(error.message ?? '导出失败，请稍后再试。');
    }
  }

  /// 通过系统文档树选择器（SAF）让用户选择备份目录，返回持久化的树 URI 与可读名称。
  /// 用户取消时返回 null。
  static Future<Map<String, String>?> pickBackupDirectory() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'pickBackupDirectory',
      );
      if (result == null) {
        return null;
      }
      return <String, String>{
        'uri': result['uri'] as String? ?? '',
        'label': result['label'] as String? ?? '',
      };
    } on MissingPluginException {
      throw Exception('当前平台不支持选择备份目录。');
    } on PlatformException catch (error) {
      throw Exception(error.message ?? '选择备份目录失败，请稍后再试。');
    }
  }

  /// 向已授权的备份目录写入一个文本文件（同名覆盖），返回新文件 URI。
  static Future<String?> writeBackupFile({
    required String directoryUri,
    required String filename,
    required String content,
    String mimeType = 'application/json',
  }) async {
    try {
      return await _channel.invokeMethod<String>('writeBackupFile', {
        'directoryUri': directoryUri,
        'filename': filename,
        'content': content,
        'mimeType': mimeType,
      });
    } on MissingPluginException {
      throw Exception('当前平台不支持写入备份目录。');
    } on PlatformException catch (error) {
      throw Exception(error.message ?? '写入备份失败，请稍后再试。');
    }
  }

  /// 列出备份目录内的文件元数据。
  static Future<List<Map<Object?, Object?>>> listBackupFiles(
    String directoryUri,
  ) async {
    try {
      final result = await _channel.invokeListMethod<Object?>(
        'listBackupFiles',
        <String, Object?>{'directoryUri': directoryUri},
      );
      return (result ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .toList();
    } on MissingPluginException {
      return const <Map<Object?, Object?>>[];
    } on PlatformException catch (error) {
      throw Exception(error.message ?? '读取备份目录失败，请稍后再试。');
    }
  }

  /// 读取备份目录内某个文件的文本内容。
  static Future<String?> readBackupFile(String fileUri) async {
    try {
      return await _channel.invokeMethod<String>('readBackupFile', {
        'fileUri': fileUri,
      });
    } on MissingPluginException {
      throw Exception('当前平台不支持读取备份文件。');
    } on PlatformException catch (error) {
      throw Exception(error.message ?? '读取备份文件失败，请稍后再试。');
    }
  }

  /// 向下载目录写入字节文件（zip 导出）。Android 10+ 成功返回 true；更低版本或
  /// 无插件返回 false，由调用方回退到系统「保存到」选择器。
  static Future<bool> saveBytesToDownloads({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('saveBytesToDownloads', {
            'filename': filename,
            'bytes': bytes,
            'mimeType': mimeType,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      throw Exception(error.message ?? '导出失败，请稍后再试。');
    }
  }

  /// 向已授权的备份目录写入一个字节文件（同名覆盖，zip 备份），返回新文件 URI。
  static Future<String?> writeBackupBytes({
    required String directoryUri,
    required String filename,
    required Uint8List bytes,
    String mimeType = 'application/zip',
  }) async {
    try {
      return await _channel.invokeMethod<String>('writeBackupBytes', {
        'directoryUri': directoryUri,
        'filename': filename,
        'bytes': bytes,
        'mimeType': mimeType,
      });
    } on MissingPluginException {
      throw Exception('当前平台不支持写入备份目录。');
    } on PlatformException catch (error) {
      throw Exception(error.message ?? '写入备份失败，请稍后再试。');
    }
  }

  /// 读取备份目录内某个文件的原始字节（用于 zip / 旧版 JSON 统一按字节读入）。
  static Future<Uint8List?> readBackupBytes(String fileUri) async {
    try {
      return await _channel.invokeMethod<Uint8List>('readBackupBytes', {
        'fileUri': fileUri,
      });
    } on MissingPluginException {
      throw Exception('当前平台不支持读取备份文件。');
    } on PlatformException catch (error) {
      throw Exception(error.message ?? '读取备份文件失败，请稍后再试。');
    }
  }

  /// 删除备份目录内某个文件。
  static Future<bool> deleteBackupFile(String fileUri) async {
    try {
      return await _channel.invokeMethod<bool>('deleteBackupFile', {
            'fileUri': fileUri,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      throw Exception(error.message ?? '删除备份文件失败，请稍后再试。');
    }
  }
}

enum UpdateCheckStatus {
  available,
  installing,
  upToDate,
  noAsset,
  unsupported,
  error,
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    required this.message,
    this.currentVersion = '',
    this.latestVersion = '',
  });

  final UpdateCheckStatus status;
  final String message;
  final String currentVersion;
  final String latestVersion;

  static UpdateCheckResult fromMap(Map<String, Object?> map) {
    final statusName = map['status'] as String? ?? 'error';
    return UpdateCheckResult(
      status: UpdateCheckStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => UpdateCheckStatus.error,
      ),
      message: map['message'] as String? ?? '检查更新失败，请稍后再试。',
      currentVersion: map['currentVersion'] as String? ?? '',
      latestVersion: map['latestVersion'] as String? ?? '',
    );
  }
}

class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    required this.progress,
    this.receivedBytes = 0,
    this.totalBytes = 0,
  });

  final double progress;
  final int receivedBytes;
  final int totalBytes;

  int get percent => (progress.clamp(0, 1) * 100).round();

  static UpdateDownloadProgress fromMap(Map<String, Object?> map) {
    return UpdateDownloadProgress(
      progress: (map['progress'] as num? ?? 0)
          .toDouble()
          .clamp(0, 1)
          .toDouble(),
      receivedBytes: (map['receivedBytes'] as num? ?? 0).toInt(),
      totalBytes: (map['totalBytes'] as num? ?? 0).toInt(),
    );
  }
}
