import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// 备份加解密错误（密钥错误、格式损坏等），面向用户可读。
class BackupCryptoException implements Exception {
  const BackupCryptoException(this.message);

  final String message;

  @override
  String toString() => message;
}

const String _encName = 'aes-gcm';
const int _pbkdf2Iterations = 120000;
const int _saltLength = 16;

final AesGcm _aesGcm = AesGcm.with256bits();

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  );
  return pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(passphrase)),
    nonce: salt,
  );
}

/// 判断一段备份文本是否为本应用的加密信封。
bool isEncryptedBackup(String content) {
  try {
    final decoded = jsonDecode(content);
    return decoded is Map &&
        decoded['app'] == 'verifin' &&
        decoded['enc'] == _encName;
  } catch (_) {
    return false;
  }
}

/// 用口令加密明文备份，返回可写入文件的 JSON 信封（含 salt/nonce/密文/MAC）。
Future<String> encryptBackup(String plaintext, String passphrase) async {
  if (passphrase.isEmpty) {
    throw const BackupCryptoException('加密密钥不能为空');
  }
  final salt = _randomBytes(_saltLength);
  final key = await _deriveKey(passphrase, salt);
  final nonce = _aesGcm.newNonce();
  final box = await _aesGcm.encrypt(
    utf8.encode(plaintext),
    secretKey: key,
    nonce: nonce,
  );
  final envelope = <String, Object?>{
    'app': 'verifin',
    'enc': _encName,
    'kdf': 'pbkdf2-sha256',
    'iter': _pbkdf2Iterations,
    'salt': base64Encode(salt),
    'nonce': base64Encode(box.nonce),
    'cipher': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
  };
  return const JsonEncoder.withIndent('  ').convert(envelope);
}

/// 用口令解密加密信封，失败（密钥错误 / 损坏）抛 [BackupCryptoException]。
Future<String> decryptBackup(String envelopeJson, String passphrase) async {
  Map<String, Object?> envelope;
  try {
    final decoded = jsonDecode(envelopeJson);
    if (decoded is! Map) {
      throw const BackupCryptoException('不是有效的加密备份');
    }
    envelope = Map<String, Object?>.from(decoded);
  } on BackupCryptoException {
    rethrow;
  } catch (_) {
    throw const BackupCryptoException('不是有效的加密备份');
  }
  if (envelope['enc'] != _encName) {
    throw const BackupCryptoException('不支持的加密格式');
  }
  try {
    final salt = base64Decode(envelope['salt'] as String);
    final nonce = base64Decode(envelope['nonce'] as String);
    final cipher = base64Decode(envelope['cipher'] as String);
    final mac = base64Decode(envelope['mac'] as String);
    final key = await _deriveKey(passphrase, salt);
    final box = SecretBox(cipher, nonce: nonce, mac: Mac(mac));
    final clear = await _aesGcm.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  } on SecretBoxAuthenticationError {
    throw const BackupCryptoException('密钥错误或备份文件已损坏');
  } on BackupCryptoException {
    rethrow;
  } catch (_) {
    throw const BackupCryptoException('解密失败，请检查密钥后重试');
  }
}
