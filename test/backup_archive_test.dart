import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/backup_archive.dart';

void main() {
  // 造一张「图片」：一段可压缩的字节，base64 内嵌到 dataUrl。
  final imageBytes = Uint8List.fromList(
    List<int>.generate(4096, (i) => (i * 7) % 256),
  );
  final dataUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';

  String buildExportJson({required bool withAttachments}) {
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'app': 'verifin',
      'version': 1,
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
                  'dataUrl': dataUrl,
                },
              ]
            : <Object?>[],
        'profile': <String, Object?>{'signature': '数据自主 · 本地优先'},
      },
    });
  }

  test('pack/unpack 往返还原附件 dataUrl 与其它数据', () {
    final exportJson = buildExportJson(withAttachments: true);
    final zip = packBackupArchive(exportJson);

    expect(looksLikeZipBytes(zip), isTrue);

    final restored = unpackBackupArchive(zip);
    final decoded = jsonDecode(restored) as Map<String, Object?>;
    final data = decoded['data'] as Map<String, Object?>;
    final attachments = data['attachments'] as List<Object?>;
    final att = attachments.single as Map<String, Object?>;

    // 附件 dataUrl 完整还原，且未污染其它字段（含中文/emoji）。
    expect(att['dataUrl'], dataUrl);
    expect(att['id'], 'att-1');
    final entries = data['entries'] as List<Object?>;
    expect((entries.single as Map)['note'], '午餐 🍚');
    expect((data['profile'] as Map)['signature'], '数据自主 · 本地优先');
  });

  test('pack/unpack 保留非 JPEG 附件的 MIME 类型', () {
    final png = 'data:image/png;base64,${base64Encode(<int>[1, 2, 3])}';
    final json = const JsonEncoder().convert(<String, Object?>{
      'app': 'verifin',
      'data': <String, Object?>{
        'attachments': <Object?>[
          <String, Object?>{'id': 'png-1', 'dataUrl': png},
        ],
      },
    });
    final restored =
        jsonDecode(unpackBackupArchive(packBackupArchive(json)))
            as Map<String, Object?>;
    final data = restored['data'] as Map<String, Object?>;
    final attachment =
        (data['attachments'] as List<Object?>).single as Map<String, Object?>;
    expect(attachment['dataUrl'], png);
  });

  test('zip 明显小于内嵌 base64 的原始 JSON（附件不再膨胀）', () {
    final exportJson = buildExportJson(withAttachments: true);
    final zip = packBackupArchive(exportJson);
    // 低熵测试图能被压缩，zip 应远小于内嵌 base64 的文本。
    expect(zip.length, lessThan(utf8.encode(exportJson).length));
  });

  test('无附件时也能正常打包解包', () {
    final exportJson = buildExportJson(withAttachments: false);
    final zip = packBackupArchive(exportJson);
    final restored = unpackBackupArchive(zip);
    final data =
        (jsonDecode(restored) as Map<String, Object?>)['data']
            as Map<String, Object?>;
    expect((data['attachments'] as List<Object?>), isEmpty);
    expect((data['ledgerBooks'] as List<Object?>).single, isA<Map>());
  });

  test('looksLikeZipBytes 对 JSON 文本返回 false', () {
    final jsonBytes = utf8.encode('{"app":"verifin"}');
    expect(looksLikeZipBytes(jsonBytes), isFalse);
    expect(looksLikeZipBytes(<int>[1, 2]), isFalse);
  });

  test('backup.json 里附件 dataUrl 被剥离（不含 base64）', () {
    final zip = packBackupArchive(buildExportJson(withAttachments: true));
    // 直接在 zip 字节里找原 base64 片段：应已被移出 JSON。
    final needle = base64Encode(imageBytes).substring(0, 40);
    final haystack = String.fromCharCodes(zip);
    expect(haystack.contains(needle), isFalse);
  });
}
