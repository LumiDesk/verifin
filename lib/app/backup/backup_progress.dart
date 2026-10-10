/// 备份/恢复/迁移的阶段，用于统一进度展示。
enum BackupPhase {
  /// 读取数据、准备导出 JSON。
  preparing,

  /// 打包 zip。
  packing,

  /// 写入目标位置（备份目录 / 下载目录 / WebDAV）。
  writing,

  /// 写后校验。
  verifying,

  /// 读取备份文件。
  reading,

  /// 解密。
  decrypting,

  /// 加密。
  encrypting,

  /// 解包并校验结构。
  unpacking,

  /// 导入账目数据。
  importing,

  /// 清理临时文件。
  cleaning,
}

/// 一次备份/恢复的进度快照。
///
/// [fraction] 为 null 表示该阶段无法给出确定比例（界面上用不确定进度条）。
class BackupProgress {
  const BackupProgress({required this.phase, this.fraction, this.detail});

  final BackupPhase phase;
  final double? fraction;
  final String? detail;
}

typedef BackupProgressCallback = void Function(BackupProgress progress);

/// 用户取消备份/恢复时抛出。调用方负责清理临时文件并提示「已取消」。
class BackupCancelledException implements Exception {
  const BackupCancelledException();

  @override
  String toString() => 'Backup cancelled';
}
