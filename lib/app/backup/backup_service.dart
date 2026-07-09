import 'dart:convert';
import 'dart:typed_data';

import 'backup_archive.dart';
import 'backup_crypto.dart';
import 'backup_settings.dart';
import 'backup_storage.dart';

/// 一次备份写入的结果。
class BackupWriteResult {
  const BackupWriteResult({required this.filename, required this.fileUri});

  final String filename;
  final String? fileUri;
}

/// 备份写入后回读校验失败：文件写坏 / 被截断 / 读不回来。抛出它让调用方告警，
/// 而不是让用户以为备份成功、实际文件已损坏（本地优先 App 的数据安全网）。
class BackupVerificationException implements Exception {
  const BackupVerificationException(this.filename);

  final String filename;

  @override
  String toString() => 'Backup verification failed for "$filename"';
}

/// 一份准备好的备份内容：文件名 + 待写字节。未加密走 zip（.zip，附件不膨胀），
/// 加密走既有文本信封（.json）。
class PreparedBackup {
  const PreparedBackup({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;
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

  static String _stamp(DateTime now) =>
      '${now.year}${_pad(now.month)}${_pad(now.day)}'
      '-${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';

  /// 手动「立即备份」文件名，带日期时间，与自动备份前缀区分。未加密为 `.zip`，
  /// 加密为 `.json`。
  static String manualBackupFilename(DateTime now, [String ext = 'zip']) {
    return 'verifin-backup-${_stamp(now)}.$ext';
  }

  /// 自动备份文件名，使用 [autoBackupFilePrefix] 前缀便于识别与清理。
  static String autoBackupFilename(DateTime now, [String ext = 'zip']) {
    return '$autoBackupFilePrefix${_stamp(now)}.$ext';
  }

  /// 按需加密备份内容；[passphrase] 为空则原样返回明文文本。
  static Future<String> prepareContent(String content, String passphrase) {
    if (passphrase.isEmpty) {
      return Future<String>.value(content);
    }
    return encryptBackup(content, passphrase);
  }

  /// 把导出 JSON 准备成待写入的备份：无口令→zip 字节（附件不膨胀）、`.zip`；
  /// 有口令→既有文本信封的 UTF-8 字节、`.json`。[auto] 决定文件名前缀。
  static Future<PreparedBackup> prepare({
    required String json,
    required String passphrase,
    required DateTime now,
    required bool auto,
  }) async {
    if (passphrase.isEmpty) {
      final name = auto
          ? autoBackupFilename(now, 'zip')
          : manualBackupFilename(now, 'zip');
      return PreparedBackup(filename: name, bytes: packBackupArchive(json));
    }
    final envelope = await encryptBackup(json, passphrase);
    final name = auto
        ? autoBackupFilename(now, 'json')
        : manualBackupFilename(now, 'json');
    return PreparedBackup(
      filename: name,
      bytes: Uint8List.fromList(utf8.encode(envelope)),
    );
  }

  /// 写入手动备份到目录。[content] 为导出 JSON；[passphrase] 非空则加密。
  static Future<BackupWriteResult> writeManualBackup({
    required BackupSettings settings,
    required String content,
    required DateTime now,
    String passphrase = '',
  }) async {
    final prepared = await prepare(
      json: content,
      passphrase: passphrase,
      now: now,
      auto: false,
    );
    final uri = await _writeVerified(
      directoryUri: settings.directoryUri,
      prepared: prepared,
    );
    return BackupWriteResult(filename: prepared.filename, fileUri: uri);
  }

  /// 写入自动备份并按保留份数清理旧文件。清理失败不影响本次备份成功。
  static Future<BackupWriteResult> writeAutoBackup({
    required BackupSettings settings,
    required String content,
    required DateTime now,
    String passphrase = '',
  }) async {
    final prepared = await prepare(
      json: content,
      passphrase: passphrase,
      now: now,
      auto: true,
    );
    return writeAutoBackupPrepared(settings: settings, prepared: prepared);
  }

  /// 用已准备好的备份内容写入自动备份并清理旧文件——供协调器把同一份 [PreparedBackup]
  /// 同时用于本地与 WebDAV，避免重复导出/加密（加密时 PBKDF2 很贵）。
  static Future<BackupWriteResult> writeAutoBackupPrepared({
    required BackupSettings settings,
    required PreparedBackup prepared,
  }) async {
    final uri = await _writeVerified(
      directoryUri: settings.directoryUri,
      prepared: prepared,
    );
    await _pruneOldAutoBackups(settings);
    return BackupWriteResult(filename: prepared.filename, fileUri: uri);
  }

  /// 写入备份并**立即回读逐字节比对**，防「写坏 / 截断却以为成功」。校验不通过抛
  /// [BackupVerificationException]。无法回读（uri 为空的平台）时跳过校验、不阻断。
  static Future<String?> _writeVerified({
    required String directoryUri,
    required PreparedBackup prepared,
  }) async {
    final uri = await writeBackupBytesFile(
      directoryUri: directoryUri,
      filename: prepared.filename,
      bytes: prepared.bytes,
    );
    if (uri != null) {
      final readBack = await readBackupBytesFile(uri);
      if (readBack == null || !_bytesEqual(readBack, prepared.bytes)) {
        throw BackupVerificationException(prepared.filename);
      }
    }
    return uri;
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
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

  /// 读取备份文件原始字节（zip 与旧版 JSON 统一按字节读入，调用方判别格式）。
  static Future<Uint8List?> readBackup(String fileUri) {
    return readBackupBytesFile(fileUri);
  }
}
