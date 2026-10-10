import 'dart:convert';
import 'dart:io';
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
const int _minPbkdf2Iterations = 10000;
const int _maxPbkdf2Iterations = 1000000;
const int _saltLength = 16;
const int _macLength = 16;
const int _maxCiphertextBytes = 256 * 1024 * 1024;

/// 新版加密容器的文件头魔数（文本行）。后面跟一行 JSON 参数，再跟纯密文字节。
///
/// 为什么另起容器：旧信封把整份明文 JSON（含 base64 附件）读进内存再加密，备份上 GB
/// 就会 OOM。新容器直接流式加密 zip，附件与账目都不进内存。
const String encryptedStreamMagic = 'VERIFIN-ENC2';

final AesGcm _aesGcm = AesGcm.with256bits();

/// 是否为新版流式加密容器（读首部若干字节即可判定）。
bool looksLikeEncryptedStream(List<int> header) {
  if (header.length < encryptedStreamMagic.length) {
    return false;
  }
  return ascii.decode(header.sublist(0, encryptedStreamMagic.length)) ==
      encryptedStreamMagic;
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

Future<SecretKey> _deriveKey(
  String passphrase,
  List<int> salt,
  int iterations,
) {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
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
  final key = await _deriveKey(passphrase, salt, _pbkdf2Iterations);
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
    // 按信封里记录的迭代数派生密钥，而非固定常量：将来若调整 _pbkdf2Iterations，
    // 用旧迭代数加密的备份仍能解开。缺失时回退到当前常量（兼容早期信封）。
    final iterations = (envelope['iter'] as num?)?.toInt() ?? _pbkdf2Iterations;
    if (salt.length != _saltLength ||
        nonce.length != _aesGcm.nonceLength ||
        mac.length != _macLength ||
        cipher.length > _maxCiphertextBytes ||
        iterations < _minPbkdf2Iterations ||
        iterations > _maxPbkdf2Iterations) {
      throw const BackupCryptoException('加密备份参数无效或过大');
    }
    final key = await _deriveKey(passphrase, salt, iterations);
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

/// 把 [plainPath] 的文件内容流式加密写入 [outputPath]（新版容器）。
///
/// 布局：`VERIFIN-ENC2\n` + 一行 JSON 参数 + `\n` + 密文 + 16 字节 GCM MAC。
/// 全程分块，内存与文件体积无关。
Future<void> encryptFileToFile({
  required String plainPath,
  required String outputPath,
  required String passphrase,
}) async {
  if (passphrase.isEmpty) {
    throw const BackupCryptoException('加密密钥不能为空');
  }
  final salt = _randomBytes(_saltLength);
  final key = await _deriveKey(passphrase, salt, _pbkdf2Iterations);
  final nonce = _aesGcm.newNonce();
  Mac? mac;
  final sink = File(outputPath).openWrite();
  try {
    sink.add(ascii.encode('$encryptedStreamMagic\n'));
    sink.add(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'kdf': 'pbkdf2-sha256',
          'iter': _pbkdf2Iterations,
          'salt': base64Encode(salt),
          'nonce': base64Encode(nonce),
        }),
      ),
    );
    sink.add(const <int>[0x0A]);
    await sink.addStream(
      _aesGcm.encryptStream(
        File(plainPath).openRead(),
        secretKey: key,
        nonce: nonce,
        onMac: (value) => mac = value,
      ),
    );
    await sink.flush();
    sink.add(mac!.bytes);
  } finally {
    await sink.close();
  }
}

/// 把新版加密容器 [encryptedPath] 流式解密写入 [outputPath]。
///
/// 口令错误或文件损坏抛 [BackupCryptoException]；输出文件已写入的部分由调用方清理。
Future<void> decryptFileToFile({
  required String encryptedPath,
  required String outputPath,
  required String passphrase,
}) async {
  final file = File(encryptedPath);
  final length = await file.length();
  final handle = await file.open();
  final int headerEnd;
  final Map<String, Object?> header;
  try {
    final prefix = await handle.read(4096);
    final text = latin1.decode(prefix, allowInvalid: true);
    final lines = text.split('\n');
    if (lines.isEmpty || lines.first.trim() != encryptedStreamMagic) {
      throw const BackupCryptoException('不是有效的加密备份');
    }
    if (lines.length < 2) {
      throw const BackupCryptoException('加密备份文件已损坏');
    }
    header = Map<String, Object?>.from(
      jsonDecode(lines[1]) as Map<dynamic, dynamic>,
    );
    headerEnd = utf8.encode('$encryptedStreamMagic\n${lines[1]}\n').length;
  } on BackupCryptoException {
    rethrow;
  } catch (_) {
    throw const BackupCryptoException('不是有效的加密备份');
  } finally {
    await handle.close();
  }
  if (headerEnd + _macLength >= length) {
    throw const BackupCryptoException('加密备份文件已损坏');
  }
  final List<int> salt;
  final List<int> nonce;
  final int iterations;
  try {
    salt = base64Decode(header['salt'] as String);
    nonce = base64Decode(header['nonce'] as String);
    iterations = (header['iter'] as num?)?.toInt() ?? _pbkdf2Iterations;
  } catch (_) {
    throw const BackupCryptoException('加密备份参数无效');
  }
  if (salt.length != _saltLength ||
      nonce.length != _aesGcm.nonceLength ||
      iterations < _minPbkdf2Iterations ||
      iterations > _maxPbkdf2Iterations) {
    throw const BackupCryptoException('加密备份参数无效');
  }
  final key = await _deriveKey(passphrase, salt, iterations);
  final macStart = length - _macLength;
  final macHandle = await file.open();
  final List<int> macBytes;
  try {
    await macHandle.setPosition(macStart);
    macBytes = await macHandle.read(_macLength);
  } finally {
    await macHandle.close();
  }
  final sink = File(outputPath).openWrite();
  try {
    await sink.addStream(
      _aesGcm.decryptStream(
        file.openRead(headerEnd, macStart),
        secretKey: key,
        nonce: nonce,
        mac: Mac(macBytes),
      ),
    );
    await sink.flush();
  } on SecretBoxAuthenticationError {
    throw const BackupCryptoException('密钥错误或备份文件已损坏');
  } on BackupCryptoException {
    rethrow;
  } catch (_) {
    throw const BackupCryptoException('解密失败，请检查密钥后重试');
  } finally {
    try {
      await sink.close();
    } catch (_) {
      // 认证失败时 sink 可能已随流错误关闭；清理失败不覆盖上面的可读原因。
    }
  }
}
