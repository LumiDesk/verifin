import 'dart:convert';

/// 自动备份触发频率。
enum BackupFrequency {
  /// 不自动备份，仅手动「立即备份」。
  manual,

  /// 每次打开应用（冷启动 / 回前台解锁后）时备份。
  onOpen,

  /// 每次记账（新增交易）后备份。
  onEntry,

  /// 每隔 N 小时备份（打开应用时检查是否到期）。
  everyNHours;

  String get label {
    switch (this) {
      case BackupFrequency.manual:
        return '仅手动';
      case BackupFrequency.onOpen:
        return '每次打开应用';
      case BackupFrequency.onEntry:
        return '每次记账后';
      case BackupFrequency.everyNHours:
        return '每隔一段时间';
    }
  }

  static BackupFrequency fromStorage(String? value) {
    return BackupFrequency.values.firstWhere(
      (item) => item.name == value,
      orElse: () => BackupFrequency.manual,
    );
  }
}

/// 备份目录与自动备份配置。目录在 Android 上是 SAF 树 URI，在桌面上是路径。
class BackupSettings {
  const BackupSettings({
    this.directoryUri = '',
    this.directoryLabel = '',
    this.frequency = BackupFrequency.manual,
    this.intervalHours = 24,
    this.retention = 10,
    this.lastBackupAt,
  });

  final String directoryUri;
  final String directoryLabel;
  final BackupFrequency frequency;
  final int intervalHours;
  final int retention;
  final DateTime? lastBackupAt;

  bool get hasDirectory => directoryUri.isNotEmpty;

  /// 是否配置了自动备份（非「仅手动」）。
  bool get autoBackupEnabled => frequency != BackupFrequency.manual;

  BackupSettings copyWith({
    String? directoryUri,
    String? directoryLabel,
    BackupFrequency? frequency,
    int? intervalHours,
    int? retention,
    DateTime? lastBackupAt,
    bool clearLastBackupAt = false,
    bool clearDirectory = false,
  }) {
    return BackupSettings(
      directoryUri: clearDirectory ? '' : (directoryUri ?? this.directoryUri),
      directoryLabel: clearDirectory
          ? ''
          : (directoryLabel ?? this.directoryLabel),
      frequency: frequency ?? this.frequency,
      intervalHours: intervalHours ?? this.intervalHours,
      retention: retention ?? this.retention,
      lastBackupAt: clearLastBackupAt
          ? null
          : (lastBackupAt ?? this.lastBackupAt),
    );
  }

  /// 仅按频率与上次备份时间判断在 [now] 是否到期（不要求已配置目录）。
  /// [afterEntry] 表示当前调用是否由「记账后」事件触发。供本地目录与 WebDAV 共用。
  bool isFrequencyDue(DateTime now, {bool afterEntry = false}) {
    switch (frequency) {
      case BackupFrequency.manual:
        return false;
      case BackupFrequency.onOpen:
        return !afterEntry;
      case BackupFrequency.onEntry:
        return afterEntry;
      case BackupFrequency.everyNHours:
        if (afterEntry) {
          return false;
        }
        final last = lastBackupAt;
        if (last == null) {
          return true;
        }
        final elapsed = now.difference(last);
        return elapsed.inMinutes >= intervalHours * 60;
    }
  }

  /// 依据频率与上次备份时间，判断在 [now] 是否应触发本地目录自动备份。
  bool shouldAutoBackup(DateTime now, {bool afterEntry = false}) {
    return hasDirectory && isFrequencyDue(now, afterEntry: afterEntry);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'directoryUri': directoryUri,
      'directoryLabel': directoryLabel,
      'frequency': frequency.name,
      'intervalHours': intervalHours,
      'retention': retention,
      'lastBackupAt': lastBackupAt?.toIso8601String(),
    };
  }

  static BackupSettings fromJson(Map<String, Object?> json) {
    final rawLast = json['lastBackupAt'] as String?;
    final rawInterval = (json['intervalHours'] as num?)?.toInt() ?? 24;
    final rawRetention = (json['retention'] as num?)?.toInt() ?? 10;
    return BackupSettings(
      directoryUri: json['directoryUri'] as String? ?? '',
      directoryLabel: json['directoryLabel'] as String? ?? '',
      frequency: BackupFrequency.fromStorage(json['frequency'] as String?),
      intervalHours: rawInterval < 1 ? 1 : rawInterval,
      retention: rawRetention < 1 ? 1 : rawRetention,
      lastBackupAt: rawLast == null ? null : DateTime.tryParse(rawLast),
    );
  }

  static BackupSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const BackupSettings();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return BackupSettings.fromJson(Map<String, Object?>.from(decoded));
      }
    } catch (_) {
      // 损坏配置退回默认。
    }
    return const BackupSettings();
  }

  String encode() => jsonEncode(toJson());
}

/// 备份目录中的一个文件的元数据。
class BackupFileInfo {
  const BackupFileInfo({
    required this.uri,
    required this.name,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String uri;
  final String name;
  final DateTime modifiedAt;
  final int sizeBytes;

  static BackupFileInfo fromMap(Map<Object?, Object?> map) {
    final millis = (map['modifiedAt'] as num?)?.toInt() ?? 0;
    return BackupFileInfo(
      uri: map['uri'] as String? ?? '',
      name: map['name'] as String? ?? '',
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(millis),
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 自动备份文件名前缀，与手动导出（`verifin-backup-`）区分。
const String autoBackupFilePrefix = 'verifin-auto-';

/// 根据保留份数，从 [files] 中挑出应删除的旧自动备份（按修改时间倒序保留最新 N 份）。
/// 只处理自动备份文件（前缀 [autoBackupFilePrefix]），手动导出不参与清理。
List<BackupFileInfo> autoBackupsToPrune(
  List<BackupFileInfo> files,
  int retention,
) {
  final autoFiles =
      files.where((file) => file.name.startsWith(autoBackupFilePrefix)).toList()
        ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  if (retention < 1 || autoFiles.length <= retention) {
    return const <BackupFileInfo>[];
  }
  return autoFiles.sublist(retention);
}
