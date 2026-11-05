/// 应用内「检查更新」：只读 GitHub Release 的最新**正式版**版本号。
///
/// 只在用户点按「检查更新」时联网，请求只带固定的 User-Agent 与 GitHub 的 Accept
/// 头，不发送任何设备信息或账目。发现新版本后由设置页把用户带到该版本的 GitHub
/// Release 页面（系统浏览器）；应用本身不下载、不安装 APK，也不申请安装权限。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_version.dart';
import '../logging/app_logger.dart';

/// GitHub 上最新正式版 Release 的 API。
///
/// `/releases/latest` 天然排除预发布与草稿，因此 Beta 版本不会出现在应用内检查里。
const String latestReleaseApiUrl =
    'https://api.github.com/repos/LumiDesk/verifin/releases/latest';

/// 建立连接的超时。
const Duration _connectTimeout = Duration(seconds: 10);

/// 单次请求的总时长，同时用作读空闲超时。
const Duration _requestTimeout = Duration(seconds: 15);

/// Release 响应只有几 KB；超过这个量级视为异常响应，避免无限累积。
const int _maxResponseBytes = 256 * 1024;

/// 一次可跳转的更新。
@immutable
class UpdateRelease {
  const UpdateRelease({required this.tag, required this.version});

  /// Release 的原样 tag（形如 `v1.20.16`），用于拼 Release 页面地址。
  final String tag;

  /// 去掉 `v` 前缀的版本号（形如 `1.20.16`）。
  final String version;
}

/// 一次检查的结果。
sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

/// 发现有比当前版本更新的正式版。
final class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable(this.release);

  final UpdateRelease release;
}

/// 当前已经是最新正式版。
final class UpdateUpToDate extends UpdateCheckResult {
  const UpdateUpToDate();
}

/// 检查失败。[reason] 只写软件日志，界面统一使用本地化文案，不透出原始错误。
final class UpdateCheckFailed extends UpdateCheckResult {
  const UpdateCheckFailed(this.reason);

  final String reason;
}

/// 测试注入点：替换真实网络检查。
@visibleForTesting
Future<UpdateCheckResult> Function()? debugUpdateCheckOverride;

/// 检查 GitHub 上是否存在比当前版本更新的正式版。
///
/// [endpoint] 与 [currentVersion] 只供测试覆盖；生产调用不传参。
Future<UpdateCheckResult> checkForUpdate({
  Uri? endpoint,
  String? currentVersion,
}) {
  final override = debugUpdateCheckOverride;
  if (override != null) {
    return override();
  }
  return _checkLatestRelease(
    endpoint ?? Uri.parse(latestReleaseApiUrl),
    currentVersion ?? currentAppVersionNumber(),
  );
}

Future<UpdateCheckResult> _checkLatestRelease(
  Uri endpoint,
  String currentVersion,
) async {
  final client = HttpClient()..connectionTimeout = _connectTimeout;
  try {
    final request = await client.getUrl(endpoint);
    request.headers
      ..set(HttpHeaders.userAgentHeader, 'VeriFin/$currentVersion')
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final response = await request.close().timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.ok) {
      return UpdateCheckFailed('http ${response.statusCode}');
    }
    final body = await _readBody(response);
    return parseLatestRelease(body, currentVersion: currentVersion);
  } on TimeoutException {
    return const UpdateCheckFailed('timeout');
  } on SocketException catch (error) {
    return UpdateCheckFailed(
      'network: ${error.osError?.message ?? error.message}',
    );
  } on HttpException catch (error) {
    return UpdateCheckFailed('http: ${error.message}');
  } on _ResponseTooLargeException {
    return const UpdateCheckFailed('response too large');
  } on Exception catch (error) {
    // TLS 握手失败、连接被重置等：归为一次失败，不向界面透出底层异常。
    return UpdateCheckFailed('unexpected: ${error.runtimeType}');
  } finally {
    client.close(force: true);
  }
}

/// 读取响应体；超过 [_maxResponseBytes] 的量级立即中止。
Future<String> _readBody(HttpClientResponse response) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in response.timeout(_requestTimeout)) {
    bytes.add(chunk);
    if (bytes.length > _maxResponseBytes) {
      throw const _ResponseTooLargeException();
    }
  }
  return utf8.decode(bytes.takeBytes(), allowMalformed: true);
}

/// 解析 `/releases/latest` 的响应体。测试直接调用它覆盖各种响应形态。
@visibleForTesting
UpdateCheckResult parseLatestRelease(
  String body, {
  required String currentVersion,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return const UpdateCheckFailed('invalid json');
  }
  if (decoded is! Map) {
    return const UpdateCheckFailed('invalid payload');
  }
  final rawTag = decoded['tag_name'];
  if (rawTag is! String || rawTag.trim().isEmpty) {
    return const UpdateCheckFailed('missing tag_name');
  }
  final tag = rawTag.trim();
  final version = tag.startsWith('v') ? tag.substring(1) : tag;
  if (version.isEmpty) {
    return const UpdateCheckFailed('empty version');
  }
  if (compareVersions(version, currentVersion) <= 0) {
    return const UpdateUpToDate();
  }
  return UpdateAvailable(UpdateRelease(tag: tag, version: version));
}

/// 语义化版本比较：返回 <0 表示 [a] 比 [b] 旧，0 表示相同。
///
/// 只比较数字段：忽略 `+build` 构建号与 `-beta` 之类的后缀（预发布按同版本处理），
/// 非数字段按 0 处理，避免上游 tag 形态变化时崩溃。
int compareVersions(String a, String b) {
  List<int> parse(String value) {
    final core = value.split('-').first.split('+').first;
    return core
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp('[^0-9]'), '')) ?? 0)
        .toList();
  }

  final left = parse(a);
  final right = parse(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final l = index < left.length ? left[index] : 0;
    final r = index < right.length ? right[index] : 0;
    if (l != r) {
      return l.compareTo(r);
    }
  }
  return 0;
}

/// 当前版本号：去掉展示用的 `v` 前缀与 `+build`，用于和 Release 版本比较。
String currentAppVersionNumber() {
  final label = appVersionLabel.startsWith('v')
      ? appVersionLabel.substring(1)
      : appVersionLabel;
  return label.split('+').first;
}

/// 删除旧版本留下的更新安装包缓存。
///
/// 旧实现把 APK 下到 `<cache>/updates`；现在应用只跳转 Release 页面，这些文件不会
/// 再被使用。启动时调用一次，属于可接受的降级：目录不存在、平台拿不到缓存目录或被
/// 系统清理都直接放过，失败只写日志，绝不影响启动。
Future<void> purgeLegacyUpdateDownloads({
  AppLogger? logger,
  Directory? cacheRoot,
}) async {
  try {
    final root = cacheRoot ?? await getTemporaryDirectory();
    final updates = Directory(p.join(root.path, 'updates'));
    if (!await updates.exists()) {
      return;
    }
    await updates.delete(recursive: true);
    logger?.info('Removed legacy update cache', source: 'update');
  } on Exception catch (error) {
    logger?.warning(
      'Skipped legacy update cache cleanup: $error',
      source: 'update',
    );
  }
}

class _ResponseTooLargeException implements Exception {
  const _ResponseTooLargeException();
}
