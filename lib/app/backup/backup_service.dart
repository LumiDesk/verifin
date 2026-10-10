import 'dart:io';

import 'package:path/path.dart' as p;

import '../attachments/attachment_store.dart';
import 'backup_archive.dart';
import 'backup_crypto.dart';
import 'backup_progress.dart';
import 'backup_settings.dart';
import 'backup_storage.dart';
import 'legacy_json_stream.dart';

// 调用方（页面/controller）只 import 本文件即可完成备份的编解码全流程，
// 不必触达 archive/crypto 实现细节；解密错误类型一并从这里透出。
export 'backup_crypto.dart' show BackupCryptoException;
export 'backup_progress.dart'
    show
        BackupCancellation,
        BackupCancelledException,
        BackupPhase,
        BackupProgress,
        BackupProgressCallback;

/// 备份字节的解码结果：明文导出 JSON，或需口令解密的加密信封。
/// 由 [BackupService.decodeBackupFile] 产出。
sealed class DecodedBackup {
  const DecodedBackup();
}

/// 已还原成明文导出 JSON（zip 已解包：附件字节已写入暂存存储、正文只留元数据）。
/// 可直接交给 `VeriFinController.importDataJson`。
class PlainBackupJson extends DecodedBackup {
  const PlainBackupJson(this.json);

  final String json;
}

/// 加密文本信封：需向用户索要口令，经 [BackupService.decryptEnvelope] 解密
/// 得到明文 JSON 后再导入。
/// 旧版格式，仅保留读取兼容。
class EncryptedBackupEnvelope extends DecodedBackup {
  const EncryptedBackupEnvelope(this.envelope);

  final String envelope;
}

/// 新版流式加密容器（加密的 zip）。需向用户索要口令，经
/// [BackupService.decryptStreamToZip] 解出缓存 zip 后再走统一解包。
class EncryptedStreamBackup extends DecodedBackup {
  const EncryptedStreamBackup();
}

/// 一次备份写入的结果。
class BackupWriteResult {
  const BackupWriteResult({required this.filename, required this.fileUri});

  final String filename;
  final String? fileUri;
}

/// 备份写入后校验失败：文件写坏 / 被截断 / 读不回来。抛出它让调用方告警，
/// 而不是让用户以为备份成功、实际文件已损坏（本地优先 App 的数据安全网）。
class BackupVerificationException implements Exception {
  const BackupVerificationException(this.filename);

  final String filename;

  @override
  String toString() => 'Backup verification failed for "$filename"';
}

/// 一份准备好的备份：文件名 + 缓存文件路径 + 内容 SHA-256 与字节数。
///
/// 备份可能上 GB，内容只存在于缓存文件里（不进内存）；[cachePath] 由调用方在用完后
/// 通过 [BackupService.deletePrepared] 清理。
class PreparedBackup {
  const PreparedBackup({
    required this.filename,
    required this.cachePath,
    required this.sha256,
    required this.byteSize,
  });

  final String filename;
  final String cachePath;
  final String sha256;
  final int byteSize;
}

/// 备份编排：写入备份文件、按保留份数清理旧的自动备份。真正的目录/文件 I/O
/// 委托给条件导入的 [backup_storage]（Android 走 SAF，桌面走 dart:io）。
///
/// 内存约定：打包、写盘、校验、读回、解包全部走缓存文件与流式 API，
/// 峰值与备份总体积无关。
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

  /// 把 [fileUri]（用户选择的备份文件）流式落到缓存目录，返回本地路径。
  ///
  /// 流式复制意味着选择 1 GB 的备份也不会把整包读进内存——Issue 45 的崩溃点。
  static Future<StagedCacheFile?> stageBackupFile(String fileUri) {
    return stageBackupFileToCache(fileUri);
  }

  /// 备份文件的**唯一解码入口**：zip（新版精简备份）→ 附件字节写入 [sink]，
  /// 返回去掉内嵌 base64 的 JSON；加密文本信封 → 原样返回待解密；其余按旧版明文
  /// JSON 文本处理（内嵌 base64 先抽取到 [sink]）。空文件抛 [FormatException]。
  static Future<DecodedBackup> decodeBackupFile({
    required String cachePath,
    required AttachmentStore sink,
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    _throwIfCancelled(isCancelled);
    final file = File(cachePath);
    if (!await file.exists()) {
      throw const FormatException('空备份文件');
    }
    if (await file.length() == 0) {
      throw const FormatException('空备份文件');
    }
    onProgress?.call(const BackupProgress(phase: BackupPhase.reading));
    final header = await _readHeader(file);
    if (looksLikeZipBytes(header)) {
      onProgress?.call(const BackupProgress(phase: BackupPhase.unpacking));
      final json = await unpackCacheZip(
        cachePath: cachePath,
        sink: sink,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      return PlainBackupJson(json);
    }
    if (looksLikeEncryptedStream(header)) {
      return const EncryptedStreamBackup();
    }
    // 旧版明文 JSON：流式重写，边解析边把内嵌 base64 附件外置，整份文档不进内存。
    try {
      final rewritten = await rewriteLegacyBackupJson(
        sourcePath: cachePath,
        sink: sink,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      return PlainBackupJson(rewritten);
    } on BackupCancelledException {
      rethrow;
    } on LegacyEncryptedEnvelopeDetected {
      // 旧版加密信封：密文内嵌在 JSON 文本里，按文本读取后交由调用方索要口令。
    } catch (_) {
      throw const FormatException('备份文件格式不正确');
    }
    final String text;
    try {
      text = await file.readAsString();
    } on FormatException {
      // readAsString 的原始报错是英文，不直接给用户看。
      throw const FormatException('备份文件格式不正确');
    }
    if (text.trim().isEmpty) {
      throw const FormatException('空备份文件');
    }
    if (isEncryptedBackup(text)) {
      return EncryptedBackupEnvelope(text);
    }
    return PlainBackupJson(await extractLegacyAttachments(text, sink));
  }

  /// 把缓存里的 zip 解包到 [sink]，返回去掉内嵌 base64 的导出 JSON。
  static Future<String> unpackCacheZip({
    required String cachePath,
    required AttachmentStore sink,
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) {
    onProgress?.call(const BackupProgress(phase: BackupPhase.unpacking));
    return unpackBackupArchiveFile(
      archivePath: cachePath,
      sink: sink,
      onProgress: (done, total) => onProgress?.call(
        BackupProgress(
          phase: BackupPhase.unpacking,
          fraction: total == 0 ? null : done / total,
        ),
      ),
      isCancelled: isCancelled,
    );
  }

  /// 解密新版加密容器到缓存 zip，返回该 zip 的路径（调用方负责清理）。
  static Future<String> decryptStreamToZip({
    required String encryptedPath,
    required Directory cacheDirectory,
    required String passphrase,
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    _throwIfCancelled(isCancelled);
    onProgress?.call(const BackupProgress(phase: BackupPhase.decrypting));
    final outputPath = restoreCachePath(cacheDirectory);
    await decryptFileToFile(
      encryptedPath: encryptedPath,
      outputPath: outputPath,
      passphrase: passphrase,
    );
    _throwIfCancelled(isCancelled);
    return outputPath;
  }

  /// 解密加密信封，返回明文导出 JSON。口令错误/密文损坏抛 [BackupCryptoException]。
  static Future<String> decryptEnvelope(String envelope, String passphrase) {
    return decryptBackup(envelope, passphrase);
  }

  /// 旧版加密信封解密后的明文 JSON → 统一形态：内嵌的 base64 附件抽取到 [sink]。
  static Future<String> prepareDecryptedLegacyJson(
    String json,
    AttachmentStore sink,
  ) {
    return extractLegacyAttachments(json, sink);
  }

  /// 把导出 JSON 准备成缓存文件里的备份：无口令→zip（附件不膨胀）、`.zip`；
  /// 有口令→既有文本信封、`.json`。[auto] 决定文件名前缀。
  static Future<PreparedBackup> prepare({
    required String json,
    required AttachmentStore store,
    required Directory cacheDirectory,
    required String passphrase,
    required DateTime now,
    required bool auto,
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    _throwIfCancelled(isCancelled);
    onProgress?.call(const BackupProgress(phase: BackupPhase.preparing));
    final encrypted = passphrase.isNotEmpty;
    final ext = encrypted ? 'verifin' : 'zip';
    final name = auto
        ? autoBackupFilename(now, ext)
        : manualBackupFilename(now, ext);
    // 缓存文件名带唯一前缀：即便用户把备份目录选成同一个目录（桌面端可能发生），
    // 缓存文件也不会与最终写出的备份文件同名互相覆盖。
    final path = p.join(
      cacheDirectory.path,
      '_${DateTime.now().microsecondsSinceEpoch}_$name',
    );
    try {
      if (encrypted) {
        // 先把 zip 打包到临时文件，再流式加密成新容器：附件与账目都不进内存。
        // 旧版的 JSON 信封仍可读取导入（见 decodeBackupFile）。
        final plainPath =
            '${cacheDirectory.path}${Platform.pathSeparator}'
            '_${DateTime.now().microsecondsSinceEpoch}_plain.zip';
        try {
          await packBackupArchiveToFile(
            exportJson: json,
            store: store,
            outputPath: plainPath,
            onProgress: (done, total) => onProgress?.call(
              BackupProgress(
                phase: BackupPhase.packing,
                fraction: total == 0 ? 1 : done / total,
              ),
            ),
            isCancelled: isCancelled,
          );
          onProgress?.call(const BackupProgress(phase: BackupPhase.encrypting));
          await encryptFileToFile(
            plainPath: plainPath,
            outputPath: path,
            passphrase: passphrase,
          );
        } finally {
          try {
            await File(plainPath).delete();
          } catch (_) {
            // 临时明文 zip 删除失败只留下缓存文件；不阻断备份。
          }
        }
      } else {
        onProgress?.call(const BackupProgress(phase: BackupPhase.packing));
        await packBackupArchiveToFile(
          exportJson: json,
          store: store,
          outputPath: path,
          onProgress: (done, total) => onProgress?.call(
            BackupProgress(
              phase: BackupPhase.packing,
              fraction: total == 0 ? 1 : done / total,
            ),
          ),
          isCancelled: isCancelled,
        );
      }
      _throwIfCancelled(isCancelled);
      onProgress?.call(const BackupProgress(phase: BackupPhase.verifying));
      final size = await File(path).length();
      final sha = await hashFileSha256(path);
      return PreparedBackup(
        filename: name,
        cachePath: path,
        sha256: sha,
        byteSize: size,
      );
    } catch (_) {
      // 失败或取消时删掉写了一半的缓存文件，不留残片。
      try {
        final partial = File(path);
        if (await partial.exists()) {
          await partial.delete();
        }
      } catch (_) {
        // 清理失败只留下缓存文件，不影响用户数据。
      }
      rethrow;
    }
  }

  /// 写入手动备份到目录。[content] 为导出 JSON；[passphrase] 非空则加密。
  static Future<BackupWriteResult> writeManualBackup({
    required BackupSettings settings,
    required String content,
    required AttachmentStore store,
    required Directory cacheDirectory,
    required DateTime now,
    String passphrase = '',
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final prepared = await prepare(
      json: content,
      store: store,
      cacheDirectory: cacheDirectory,
      passphrase: passphrase,
      now: now,
      auto: false,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    try {
      final uri = await _writeVerified(
        directoryUri: settings.directoryUri,
        prepared: prepared,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      return BackupWriteResult(filename: prepared.filename, fileUri: uri);
    } finally {
      await deletePrepared(prepared);
    }
  }

  /// 写入自动备份并按保留份数清理旧文件。清理失败不影响本次备份成功。
  static Future<BackupWriteResult> writeAutoBackup({
    required BackupSettings settings,
    required String content,
    required AttachmentStore store,
    required Directory cacheDirectory,
    required DateTime now,
    String passphrase = '',
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final prepared = await prepare(
      json: content,
      store: store,
      cacheDirectory: cacheDirectory,
      passphrase: passphrase,
      now: now,
      auto: true,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    try {
      return await writeAutoBackupPrepared(
        settings: settings,
        prepared: prepared,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    } finally {
      await deletePrepared(prepared);
    }
  }

  /// 用已准备好的备份内容写入自动备份并清理旧文件——供协调器把同一份 [PreparedBackup]
  /// 同时用于本地与 WebDAV，避免重复导出/加密（加密时 PBKDF2 很贵）。
  static Future<BackupWriteResult> writeAutoBackupPrepared({
    required BackupSettings settings,
    required PreparedBackup prepared,
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final uri = await _writeVerified(
      directoryUri: settings.directoryUri,
      prepared: prepared,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    await _pruneOldAutoBackups(settings);
    return BackupWriteResult(filename: prepared.filename, fileUri: uri);
  }

  /// 把已准备的备份流式写入系统下载目录（zip 导出）。返回 null 表示当前平台
  /// 需要调用方回退到系统「保存到」选择器。
  static Future<StreamedWriteReceipt?> exportToDownloads(
    PreparedBackup prepared, {
    String mimeType = 'application/zip',
  }) {
    return saveCacheFileToDownloadsFromCache(
      filename: prepared.filename,
      cachePath: prepared.cachePath,
      mimeType: mimeType,
    );
  }

  /// 删除已准备备份的缓存文件（用完即删；失败不阻断主流程）。
  static Future<void> deletePrepared(PreparedBackup prepared) async {
    try {
      await deleteCacheFile(prepared.cachePath);
    } catch (_) {
      // 缓存目录属应用私有空间，删除失败只留下临时文件，不影响用户数据。
    }
  }

  /// 删除某个缓存文件（流式恢复路径收尾）。
  static Future<void> deleteCachePath(String path) async {
    try {
      await deleteCacheFile(path);
    } catch (_) {
      // 同上：清理失败只留下临时文件。
    }
  }

  /// 在缓存目录里生成一个恢复用的临时文件路径（WebDAV 下载等）。
  static String restoreCachePath(Directory cacheDirectory) => p.join(
    cacheDirectory.path,
    'restore_${DateTime.now().microsecondsSinceEpoch}',
  );

  /// 写入备份并**流式校验**：原生写盘时同步算 SHA-256 与字节数，与打包侧比对，
  /// 不一致即判定写坏。校验不通过抛 [BackupVerificationException]。
  static Future<String?> _writeVerified({
    required String directoryUri,
    required PreparedBackup prepared,
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    _throwIfCancelled(isCancelled);
    onProgress?.call(const BackupProgress(phase: BackupPhase.writing));
    final result = await writeBackupFromCacheFile(
      directoryUri: directoryUri,
      filename: prepared.filename,
      cachePath: prepared.cachePath,
    );
    if (result == null) {
      throw BackupVerificationException(prepared.filename);
    }
    onProgress?.call(const BackupProgress(phase: BackupPhase.verifying));
    if (result.receipt.byteSize != prepared.byteSize ||
        result.receipt.sha256 != prepared.sha256) {
      throw BackupVerificationException(prepared.filename);
    }
    return result.uri;
  }

  static void _throwIfCancelled(bool Function()? isCancelled) {
    if (isCancelled?.call() ?? false) {
      throw const BackupCancelledException();
    }
  }

  static Future<List<int>> _readHeader(File file) async {
    final handle = await file.open();
    try {
      // 读够新版加密容器魔数所需的长度；zip 判定只看前 4 字节。
      return await handle.read(32);
    } finally {
      await handle.close();
    }
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
}
