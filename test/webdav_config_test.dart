import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/webdav_config.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  group('webdavAutoBackupsToPrune', () {
    WebdavRemoteFile file(String name, int day) => WebdavRemoteFile(
      href: '/dav/$name',
      name: name,
      modifiedAt: DateTime(2026, 1, day),
      sizeBytes: 100,
    );

    test('只保留最新 N 份自动备份，删掉更旧的', () {
      final files = <WebdavRemoteFile>[
        file('verifin-auto-20260101-000000.zip', 1),
        file('verifin-auto-20260103-000000.zip', 3),
        file('verifin-auto-20260102-000000.zip', 2),
      ];
      final prune = webdavAutoBackupsToPrune(files, 2);
      expect(prune.map((f) => f.name), <String>[
        'verifin-auto-20260101-000000.zip',
      ]);
    });

    test('手动导出不参与清理', () {
      final files = <WebdavRemoteFile>[
        file('verifin-backup-20260101-000000.zip', 1),
        file('verifin-backup-20260102-000000.zip', 2),
        file('verifin-auto-20260103-000000.zip', 3),
      ];
      expect(webdavAutoBackupsToPrune(files, 1), isEmpty);
    });

    test('modifiedAt 为 null 的优先被删', () {
      final files = <WebdavRemoteFile>[
        file('verifin-auto-20260103-000000.zip', 3),
        const WebdavRemoteFile(
          href: '/dav/verifin-auto-old.zip',
          name: 'verifin-auto-old.zip',
          modifiedAt: null,
          sizeBytes: 100,
        ),
      ];
      final prune = webdavAutoBackupsToPrune(files, 1);
      expect(prune.single.name, 'verifin-auto-old.zip');
    });
  });

  group('WebdavConfig', () {
    test('encode/decode 往返', () {
      const config = WebdavConfig(
        url: 'https://dav.example.com/verifin/',
        username: 'u',
        password: 'p',
        autoUpload: true,
      );
      final restored = WebdavConfig.decode(config.encode());
      expect(restored.url, config.url);
      expect(restored.username, 'u');
      expect(restored.password, 'p');
      expect(restored.autoUpload, isTrue);
      expect(restored.isConfigured, isTrue);
    });

    test('空/损坏配置退回默认', () {
      expect(WebdavConfig.decode(null).isConfigured, isFalse);
      expect(WebdavConfig.decode('oops').isConfigured, isFalse);
    });
  });

  group('URL 拼接', () {
    test('集合 URL 规范化补斜杠', () {
      expect(normalizeCollectionUrl('https://a/b'), 'https://a/b/');
      expect(normalizeCollectionUrl('https://a/b/'), 'https://a/b/');
      expect(normalizeCollectionUrl(''), '');
    });

    test('拼接文件名并编码', () {
      expect(
        joinWebdavUrl('https://a/dav', 'verifin-auto-1.json'),
        'https://a/dav/verifin-auto-1.json',
      );
      expect(joinWebdavUrl('https://a/dav/', '有 空格.json'), contains('%20'));
    });
  });

  group('parsePropfindResponse', () {
    const xml = '''
<?xml version="1.0"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/verifin/</D:href>
    <D:propstat><D:prop>
      <D:resourcetype><D:collection/></D:resourcetype>
    </D:prop></D:propstat>
  </D:response>
  <D:response>
    <D:href>/verifin/verifin-auto-20260105-090807.json</D:href>
    <D:propstat><D:prop>
      <D:getlastmodified>Mon, 05 Jan 2026 09:08:07 GMT</D:getlastmodified>
      <D:getcontentlength>2048</D:getcontentlength>
      <D:resourcetype/>
    </D:prop></D:propstat>
  </D:response>
</D:multistatus>''';

    test('跳过集合本身，解析文件名/时间/大小', () {
      final files = parsePropfindResponse(xml);
      expect(files, hasLength(1));
      final file = files.single;
      expect(file.name, 'verifin-auto-20260105-090807.json');
      expect(file.sizeBytes, 2048);
      expect(file.modifiedAt, DateTime.utc(2026, 1, 5, 9, 8, 7));
      expect(file.href, '/verifin/verifin-auto-20260105-090807.json');
    });

    test('兼容小写与百分号编码的 href', () {
      const encoded = '''
<multistatus xmlns="DAV:">
  <response><href>/dav/%E5%A4%87%E4%BB%BD.json</href>
    <propstat><prop><getcontentlength>3</getcontentlength></prop></propstat>
  </response>
</multistatus>''';
      final files = parsePropfindResponse(encoded);
      expect(files.single.name, '备份.json');
    });
  });

  group('控制器 WebDAV 持久化', () {
    test('保存后重启仍在，清除后消失', () async {
      final store = LocalKeyValueStore();
      final controller = await makeController(store);
      controller.setWebdavConfig(
        const WebdavConfig(
          url: 'https://dav.example.com/verifin/',
          username: 'u',
          password: 'p',
        ),
      );
      controller.setWebdavAutoUpload(true);

      final reloaded = await makeController(store);
      expect(reloaded.webdavConfig.isConfigured, isTrue);
      expect(reloaded.webdavConfig.autoUpload, isTrue);
      expect(reloaded.webdavConfig.username, 'u');

      reloaded.clearWebdavConfig();
      final again = await makeController(store);
      expect(again.webdavConfig.isConfigured, isFalse);
    });
  });
}
