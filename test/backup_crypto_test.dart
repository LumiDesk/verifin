import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/backup_crypto.dart';
import 'package:verifin/app/backup/backup_service.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  group('备份加密', () {
    test('加密后可用相同口令解密还原', () async {
      const plain = '{"app":"verifin","data":{"n":1}}';
      final envelope = await encryptBackup(plain, 'hunter2');
      expect(isEncryptedBackup(envelope), isTrue);
      expect(envelope.contains(plain), isFalse); // 明文不出现在密文中
      final restored = await decryptBackup(envelope, 'hunter2');
      expect(restored, plain);
    });

    test('错误口令解密抛出可读异常', () async {
      final envelope = await encryptBackup('secret payload', 'right-key');
      expect(
        () => decryptBackup(envelope, 'wrong-key'),
        throwsA(isA<BackupCryptoException>()),
      );
    });

    test('明文备份不被识别为加密信封', () {
      expect(isEncryptedBackup('{"app":"verifin","version":1}'), isFalse);
      expect(isEncryptedBackup('not json'), isFalse);
    });

    test('空口令加密被拒绝', () {
      expect(
        () => encryptBackup('x', ''),
        throwsA(isA<BackupCryptoException>()),
      );
    });

    test('两次加密使用不同 salt/nonce（密文不同）', () async {
      final a = await encryptBackup('same', 'key');
      final b = await encryptBackup('same', 'key');
      expect(a, isNot(equals(b)));
    });

    test('BackupService.prepareContent 空口令返回明文', () async {
      final out = await BackupService.prepareContent('plain', '');
      expect(out, 'plain');
    });

    test('BackupService.prepareContent 有口令则加密', () async {
      final out = await BackupService.prepareContent('plain', 'key1');
      expect(isEncryptedBackup(out), isTrue);
      expect(await decryptBackup(out, 'key1'), 'plain');
    });
  });

  group('控制器加密口令持久化', () {
    test('设置口令后重启仍在，清除后消失', () async {
      final store = LocalKeyValueStore();
      final controller = await makeController(store);
      expect(controller.backupEncryptionEnabled, isFalse);
      controller.setBackupPassphrase('mykey');

      final reloaded = await makeController(store);
      expect(reloaded.backupEncryptionEnabled, isTrue);
      expect(reloaded.backupPassphrase, 'mykey');

      reloaded.clearBackupPassphrase();
      final again = await makeController(store);
      expect(again.backupEncryptionEnabled, isFalse);
    });

    test('加密导出再导入能还原数据', () async {
      final controller = await makeController();
      controller.setBackupPassphrase('roundtrip');
      final cipher = await BackupService.prepareContent(
        controller.exportDataJson(),
        controller.backupPassphrase,
      );
      final plain = await decryptBackup(cipher, 'roundtrip');
      final decoded = jsonDecode(plain);
      expect(decoded, isA<Map<String, Object?>>());
      // 不应抛异常，且能被控制器导入。
      controller.importDataJson(plain);
    });
  });
}
