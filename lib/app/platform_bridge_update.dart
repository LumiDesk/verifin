part of 'platform_bridge.dart';

/// GitHub Release 更新检查与下载（原生侧实现网络与安装流程；下载进度经
/// 入站 `updateDownloadProgress` 事件回推 [updateProgress]）。
class AppUpdateBridge {
  AppUpdateBridge._();

  static final ValueNotifier<UpdateDownloadProgress?> updateProgress =
      ValueNotifier<UpdateDownloadProgress?>(null);

  static Future<UpdateCheckResult> checkForUpdate({
    bool includePrerelease = false,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'checkLatestRelease',
        <String, Object?>{'includePrerelease': includePrerelease},
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

  static Future<UpdateCheckResult> downloadLatestUpdate({
    bool includePrerelease = false,
  }) async {
    updateProgress.value = const UpdateDownloadProgress(progress: 0);
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'downloadLatestUpdate',
        <String, Object?>{'includePrerelease': includePrerelease},
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
    this.isPrerelease = false,
  });

  final UpdateCheckStatus status;
  final String message;
  final String currentVersion;
  final String latestVersion;

  /// 命中的目标 Release 是否为预发布版本（供 UI 在下载前提示不稳定风险）。
  final bool isPrerelease;

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
      isPrerelease: map['isPrerelease'] as bool? ?? false,
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
