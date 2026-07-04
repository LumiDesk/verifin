import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// 应用锁的锁类型。生物识别不是独立锁，只是 PIN/图案之上的快捷解锁，因此不在此枚举。
enum AppLockKind {
  none('无'),
  pin('数字密码'),
  pattern('图案密码');

  const AppLockKind(this.label);

  /// 用户可见的锁类型名称。
  final String label;

  static AppLockKind fromName(String? name) {
    return AppLockKind.values.firstWhere(
      (kind) => kind.name == name,
      orElse: () => AppLockKind.none,
    );
  }
}

/// PIN 位数：固定 6 位。
const int kAppLockPinLength = 6;

/// 图案最少连接点数。
const int kAppLockPatternMinPoints = 4;

/// 应用锁配置。密钥（PIN 数字串 / 图案点序列）只以加盐 SHA-256 存储，绝不存明文。
///
/// 存储位置为偏好类 KV（`verifin.app_lock.v1`）。威胁模型是"他人拿到已解锁手机后
/// 打开本应用"，加盐哈希足以防止顺手偷看；不做抗取证级保护。
class AppLockConfig {
  const AppLockConfig({
    required this.kind,
    required this.secretHash,
    required this.salt,
    required this.biometricEnabled,
  });

  const AppLockConfig.none()
    : kind = AppLockKind.none,
      secretHash = '',
      salt = '',
      biometricEnabled = false;

  final AppLockKind kind;
  final String secretHash;
  final String salt;
  final bool biometricEnabled;

  bool get enabled => kind != AppLockKind.none;

  AppLockConfig copyWith({
    AppLockKind? kind,
    String? secretHash,
    String? salt,
    bool? biometricEnabled,
  }) {
    return AppLockConfig(
      kind: kind ?? this.kind,
      secretHash: secretHash ?? this.secretHash,
      salt: salt ?? this.salt,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }

  /// 用给定密钥新建一份配置（生成新盐并计算哈希）。
  factory AppLockConfig.fromSecret({
    required AppLockKind kind,
    required String secret,
    bool biometricEnabled = false,
  }) {
    final salt = generateAppLockSalt();
    return AppLockConfig(
      kind: kind,
      secretHash: hashAppLockSecret(secret, salt),
      salt: salt,
      biometricEnabled: biometricEnabled,
    );
  }

  /// 校验输入密钥是否匹配。
  bool verify(String input) {
    if (!enabled) {
      return false;
    }
    return hashAppLockSecret(input, salt) == secretHash;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'secretHash': secretHash,
    'salt': salt,
    'biometricEnabled': biometricEnabled,
  };

  factory AppLockConfig.fromJson(Map<String, dynamic> json) {
    final kind = AppLockKind.fromName(json['kind'] as String?);
    if (kind == AppLockKind.none) {
      return const AppLockConfig.none();
    }
    return AppLockConfig(
      kind: kind,
      secretHash: (json['secretHash'] as String?) ?? '',
      salt: (json['salt'] as String?) ?? '',
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
    );
  }
}

/// 生成 16 字节随机盐（Base64），使用密码学安全随机源。
String generateAppLockSalt() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}

/// 加盐 SHA-256 哈希。空盐/空密钥同样计算，交由调用方保证语义。
String hashAppLockSecret(String secret, String salt) {
  final digest = sha256.convert(utf8.encode('$salt::$secret'));
  return digest.toString();
}
