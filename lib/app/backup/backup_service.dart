import 'backup_crypto.dart';
import 'backup_settings.dart';
import 'backup_storage.dart';

/// 一次备份写入的结果。
class BackupWriteResult {
  const BackupWriteResult({required this.filename, required this.fileUri});

  final String filename;
  final String? fileUri;
}

/// 备份编排：写入备份文件、按保留份数清理旧的自动备份。真正的目录/文件 I/O
/// 委托给条件导入的 [backup_storage]（Android 走 SAF，桌面走 dart:io）。
class BackupService {
  const BackupService._();

  /// 让用户选择备份目录（返回持久化的目录句柄）。
  static Future<PickedBackupDirectory?> chooseDirectory() {
    return pickBackupDirectory();
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  /// 手动「立即备份」文件名，带日期时间，与自动备份前缀区分。
  static String manualBackupFilename(DateTime now) {
    final stamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}'
        '-${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    return 'verifin-backup-$stamp.json';
  }

  /// 自动备份文件名，使用 [autoBackupFilePrefix] 前缀便于识别与清理。
  static String autoBackupFilename(DateTime now) {
    final stamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}'
        '-${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    return '$autoBackupFilePrefix$stamp.json';
  }

  /// 按需加密备份内容；[passphrase] 为空则原样返回明文。
  static Future<String> prepareContent(String content, String passphrase) {
    if (passphrase.isEmpty) {
      return Future<String>.value(content);
    }
    return encryptBackup(content, passphrase);
  }

  /// 写入手动备份到目录。[passphrase] 非空则加密后写入。
  static Future<BackupWriteResult> writeManualBackup({
    required BackupSettings settings,
    required String content,
    required DateTime now,
    String passphrase = '',
  }) async {
    final filename = manualBackupFilename(now);
    final payload = await prepareContent(content, passphrase);
    final uri = await writeBackupFile(
      directoryUri: settings.directoryUri,
      filename: filename,
      content: payload,
    );
    return BackupWriteResult(filename: filename, fileUri: uri);
  }

  /// 写入自动备份并按保留份数清理旧文件。清理失败不影响本次备份成功。
  static Future<BackupWriteResult> writeAutoBackup({
    required BackupSettings settings,
    required String content,
    required DateTime now,
    String passphrase = '',
  }) async {
    final filename = autoBackupFilename(now);
    final payload = await prepareContent(content, passphrase);
    final uri = await writeBackupFile(
      directoryUri: settings.directoryUri,
      filename: filename,
      content: payload,
    );
    await _pruneOldAutoBackups(settings);
    return BackupWriteResult(filename: filename, fileUri: uri);
  }

  static Future<void> _pruneOldAutoBackups(BackupSettings settings) async {
    try {
      final files = await listBackupFiles(settings.directoryUri);
      for (final file in autoBackupsToPrune(files, settings.retention)) {
        await deleteBackupFile(file.uri);
      }
    } catch (_) {
      // 清理是尽力而为，不阻断备份主流程。
    }
  }

  /// 列出备份目录内的备份文件（供恢复选择）。
  static Future<List<BackupFileInfo>> listBackups(String directoryUri) {
    return listBackupFiles(directoryUri);
  }

  static Future<String?> readBackup(String fileUri) {
    return readBackupFile(fileUri);
  }
}
