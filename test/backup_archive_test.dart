import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/attachments/attachment_store.dart';
import 'package:verifin/app/backup/backup_archive.dart';

void main() {
  // 造一张「图片」：一段可压缩的字节，走 AttachmentStore 文件路径。
  final imageBytes = Uint8List.fromList(
    List<int>.generate(4096, (i) => (i * 7) % 256),
  );

  String buildExportJson({
    required bool withAttachments,
    String mimeType = 'image/jpeg',
  }) {
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'app': 'verifin',
      'version': 3,
      'data': <String, Object?>{
        'ledgerBooks': <Object?>[
          <String, Object?>{'id': 'default', 'name': '日常账本'},
        ],
        'entries': <Object?>[
          <String, Object?>{'id': 'e1', 'note': '午餐 🍚', 'amount': 45},
        ],
        'attachments': withAttachments
            ? <Object?>[
                <String, Object?>{
                  'id': 'att-1',
                  'entryId': 'e1',
                  'mimeType': mimeType,
                  'byteSize': imageBytes.length,
                },
              ]
            : <Object?>[],
        'profile': <String, Object?>{'signature': '数据自主 · 本地优先'},
      },
    });
  }

  Future<InMemoryAttachmentStore> storeWithImage() async {
    final store = InMemoryAttachmentStore();
    await store.writeBytes('att-1', imageBytes);
    return store;
  }

  Future<T> withTempDir<T>(Future<T> Function(String dir) body) async {
    final dir = await Directory.systemTemp.createTemp('verifin_archive_test');
    try {
      return await body(dir.path);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  test('pack/unpack 往返：附件字节进 zip，JSON 里不含 base64', () async {
    await withTempDir((dir) async {
      final store = await storeWithImage();
      final archivePath = '$dir/backup.zip';
      await packBackupArchiveToFile(
        exportJson: buildExportJson(withAttachments: true),
        store: store,
        outputPath: archivePath,
      );
      expect(looksLikeZipBytes(await File(archivePath).readAsBytes()), isTrue);

      final sink = InMemoryAttachmentStore();
      final restored = await unpackBackupArchiveFile(
        archivePath: archivePath,
        sink: sink,
      );
      final decoded = jsonDecode(restored) as Map<String, Object?>;
      final data = decoded['data'] as Map<String, Object?>;
      final att = (data['attachments'] as List<Object?>).single as Map;

      // 附件字节逐张还原；JSON 只留元数据（保持 v3 形状的空 dataUrl，不含 base64）。
      expect(await sink.readBytes('att-1'), imageBytes);
      expect(att['id'], 'att-1');
      expect(att['dataUrl'], isEmpty);
      expect(att['byteSize'], imageBytes.length);
      // 其它字段（含中文/emoji）原样保留。
      final entries = data['entries'] as List<Object?>;
      expect((entries.single as Map)['note'], '午餐 🍚');
      expect((data['profile'] as Map)['signature'], '数据自主 · 本地优先');
    });
  });

  test('保留非 JPEG 附件的 MIME 类型', () async {
    await withTempDir((dir) async {
      final store = InMemoryAttachmentStore();
      await store.writeBytes('att-1', imageBytes);
      final archivePath = '$dir/backup.zip';
      await packBackupArchiveToFile(
        exportJson: buildExportJson(
          withAttachments: true,
          mimeType: 'image/png',
        ),
        store: store,
        outputPath: archivePath,
      );
      final restored =
          jsonDecode(
                await unpackBackupArchiveFile(
                  archivePath: archivePath,
                  sink: InMemoryAttachmentStore(),
                ),
              )
              as Map;
      final data = restored['data'] as Map;
      final attachment = (data['attachments'] as List).single as Map;
      expect(attachment['mimeType'], 'image/png');
    });
  });

  test('zip 明显小于内嵌 base64 的等价 JSON（附件不再膨胀）', () async {
    await withTempDir((dir) async {
      final store = await storeWithImage();
      final archivePath = '$dir/backup.zip';
      await packBackupArchiveToFile(
        exportJson: buildExportJson(withAttachments: true),
        store: store,
        outputPath: archivePath,
      );
      final inlineJson = jsonEncode(<String, Object?>{
        'app': 'verifin',
        'data': <String, Object?>{
          'attachments': <Object?>[
            <String, Object?>{
              'id': 'att-1',
              'dataUrl': 'data:image/jpeg;base64,${base64Encode(imageBytes)}',
            },
          ],
        },
      });
      final archiveSize = await File(archivePath).length();
      expect(archiveSize, lessThan(utf8.encode(inlineJson).length));
    });
  });

  test('无附件时也能正常打包解包', () async {
    await withTempDir((dir) async {
      final archivePath = '$dir/backup.zip';
      await packBackupArchiveToFile(
        exportJson: buildExportJson(withAttachments: false),
        store: InMemoryAttachmentStore(),
        outputPath: archivePath,
      );
      final restored =
          jsonDecode(
                await unpackBackupArchiveFile(
                  archivePath: archivePath,
                  sink: InMemoryAttachmentStore(),
                ),
              )
              as Map;
      final data = restored['data'] as Map;
      expect(data['attachments'] as List, isEmpty);
      expect((data['ledgerBooks'] as List).single, isA<Map>());
    });
  });

  test('附件字节取不到时整次打包失败（不产出缺附件的备份）', () async {
    await withTempDir((dir) async {
      await expectLater(
        packBackupArchiveToFile(
          exportJson: buildExportJson(withAttachments: true),
          store: InMemoryAttachmentStore(),
          outputPath: '$dir/backup.zip',
        ),
        throwsA(isA<BackupAttachmentUnavailableException>()),
      );
    });
  });

  test('looksLikeZipBytes 对 JSON 文本返回 false', () {
    final jsonBytes = utf8.encode('{"app":"verifin"}');
    expect(looksLikeZipBytes(jsonBytes), isFalse);
    expect(looksLikeZipBytes(<int>[1, 2]), isFalse);
  });

  test('缺 backup.json 的压缩包被拒绝', () async {
    await withTempDir((dir) async {
      // 空 zip（无 backup.json）必须报错，而不是当成空备份吞掉用户数据。
      final emptyZipPath = '$dir/empty.zip';
      await File(
        emptyZipPath,
      ).writeAsBytes(base64Decode('UEsFBgAAAAAAAAAAAAAAAAAAAAAAAA=='));
      await expectLater(
        unpackBackupArchiveFile(
          archivePath: emptyZipPath,
          sink: InMemoryAttachmentStore(),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
