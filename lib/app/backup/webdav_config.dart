import 'dart:convert';

import 'backup_settings.dart';

/// WebDAV 服务器配置。密码明文存本机 KV（与备份加密口令同等信任边界）。
class WebdavConfig {
  const WebdavConfig({
    this.url = '',
    this.username = '',
    this.password = '',
    this.autoUpload = false,
  });

  /// 备份所在的 WebDAV 目录 URL（集合），如 `https://dav.example.com/verifin/`。
  final String url;
  final String username;
  final String password;

  /// 自动备份触发时是否也上传到 WebDAV。
  final bool autoUpload;

  bool get isConfigured => url.trim().isNotEmpty;

  WebdavConfig copyWith({
    String? url,
    String? username,
    String? password,
    bool? autoUpload,
  }) {
    return WebdavConfig(
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      autoUpload: autoUpload ?? this.autoUpload,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'username': username,
    'password': password,
    'autoUpload': autoUpload,
  };

  static WebdavConfig fromJson(Map<String, Object?> json) {
    return WebdavConfig(
      url: json['url'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      autoUpload: json['autoUpload'] as bool? ?? false,
    );
  }

  static WebdavConfig decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const WebdavConfig();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return WebdavConfig.fromJson(Map<String, Object?>.from(decoded));
      }
    } catch (_) {
      // 损坏配置退回默认。
    }
    return const WebdavConfig();
  }

  String encode() => jsonEncode(toJson());
}

/// WebDAV 目录中的一个远端文件。
class WebdavRemoteFile {
  const WebdavRemoteFile({
    required this.href,
    required this.name,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String href;
  final String name;
  final DateTime? modifiedAt;
  final int sizeBytes;
}

/// 规范化集合 URL（确保以 `/` 结尾）。
String normalizeCollectionUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed.endsWith('/') ? trimmed : '$trimmed/';
}

/// 拼接集合 URL 与文件名，得到文件的完整 URL。
String joinWebdavUrl(String collectionUrl, String filename) {
  return '${normalizeCollectionUrl(collectionUrl)}${Uri.encodeComponent(filename)}';
}

/// 从 WebDAV 文件列表挑出应删除的旧自动备份（只处理 [autoBackupFilePrefix] 前缀，
/// 按修改时间倒序保留最新 [retention] 份）。`modifiedAt` 为 null 的排在最后、优先删。
List<WebdavRemoteFile> webdavAutoBackupsToPrune(
  List<WebdavRemoteFile> files,
  int retention,
) {
  final autoFiles =
      files.where((f) => f.name.startsWith(autoBackupFilePrefix)).toList()
        ..sort((a, b) {
          final am = a.modifiedAt;
          final bm = b.modifiedAt;
          if (am == null && bm == null) return 0;
          if (am == null) return 1;
          if (bm == null) return -1;
          return bm.compareTo(am);
        });
  if (retention < 1 || autoFiles.length <= retention) {
    return const <WebdavRemoteFile>[];
  }
  return autoFiles.sublist(retention);
}

String _stripTag(String inner, String localName) {
  final match = RegExp(
    '<[^>]*?$localName[^>]*?>(.*?)</[^>]*?$localName[^>]*?>',
    dotAll: true,
    caseSensitive: false,
  ).firstMatch(inner);
  return match?.group(1)?.trim() ?? '';
}

/// 解析 PROPFIND(Depth:1) 的 multistatus XML，返回其中的文件（跳过集合本身）。
/// 命名空间前缀（D:/d:/lp1: 等）不固定，用局部名匹配。
List<WebdavRemoteFile> parsePropfindResponse(String xml, {String? basePath}) {
  final files = <WebdavRemoteFile>[];
  final responses = RegExp(
    r'<[^>]*?response[^>]*?>(.*?)</[^>]*?response[^>]*?>',
    dotAll: true,
    caseSensitive: false,
  ).allMatches(xml);
  for (final response in responses) {
    final inner = response.group(1) ?? '';
    final href = _stripTag(inner, 'href');
    if (href.isEmpty) {
      continue;
    }
    // 集合（目录）本身：resourcetype 含 collection，跳过。
    final isCollection = RegExp(
      r'<[^>]*?collection[^>]*?/?>',
      caseSensitive: false,
    ).hasMatch(inner);
    if (isCollection) {
      continue;
    }
    final decodedHref = Uri.decodeFull(href);
    var name = decodedHref;
    if (name.endsWith('/')) {
      name = name.substring(0, name.length - 1);
    }
    final slash = name.lastIndexOf('/');
    if (slash >= 0) {
      name = name.substring(slash + 1);
    }
    if (name.isEmpty) {
      continue;
    }
    final modifiedRaw = _stripTag(inner, 'getlastmodified');
    final sizeRaw = _stripTag(inner, 'getcontentlength');
    files.add(
      WebdavRemoteFile(
        href: href,
        name: name,
        modifiedAt: _parseHttpDate(modifiedRaw),
        sizeBytes: int.tryParse(sizeRaw) ?? 0,
      ),
    );
  }
  return files;
}

const List<String> _months = <String>[
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

/// 解析 RFC 1123 时间（如 `Wed, 05 Jan 2026 09:08:07 GMT`）为 UTC DateTime。
DateTime? _parseHttpDate(String raw) {
  if (raw.isEmpty) {
    return null;
  }
  final match = RegExp(
    r'(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(raw);
  if (match == null) {
    return null;
  }
  final day = int.parse(match.group(1)!);
  final month = _months.indexOf(match.group(2)!.toLowerCase()) + 1;
  if (month == 0) {
    return null;
  }
  final year = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  return DateTime.utc(year, month, day, hour, minute, second);
}
