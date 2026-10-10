import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/attachments/attachment_store.dart';
import 'package:verifin/app/backup/legacy_json_stream.dart';

void main() {
  test('流式重写：内嵌 base64 外置，其余字段与结构保持不变', () async {
    final store = InMemoryAttachmentStore();
    final bytes = Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));
    final legacy = const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'app': 'verifin',
      'version': 1,
      'data': <String, Object?>{
        'ledgerBooks': <Object?>[
          <String, Object?>{'id': 'default', 'name': '日常', 'isDefault': true},
        ],
        'entries': <Object?>[
          <String, Object?>{
            'id': 'e1',
            'amount': 45.5,
            'note': '午餐 "x" \\ 反斜杠',
            'tags': <Object?>['a', 'b'],
            'settledAt': null,
          },
        ],
        'attachments': <Object?>[
          <String, Object?>{
            'id': 'att-1',
            'entryId': 'e1',
            'dataUrl': 'data:image/png;base64,${base64Encode(bytes)}',
          },
          <String, Object?>{'id': 'att-2', 'entryId': 'e1', 'dataUrl': ''},
        ],
        'dailyBudgets': <String, Object?>{'2026-07': 12.5},
        'empty': <Object?>[],
        'nested': <String, Object?>{
          'a': <Object?>[
            1,
            2,
            <Object?>[3, 4],
          ],
          'b': <String, Object?>{'c': null},
        },
      },
    });

    final dir = await Directory.systemTemp.createTemp('verifin_legacy_stream');
    final src = '${dir.path}${Platform.pathSeparator}legacy.json';
    await File(src).writeAsString(legacy);
    try {
      final rewritten = await rewriteLegacyBackupJson(
        sourcePath: src,
        sink: store,
      );
      final decoded = jsonDecode(rewritten) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final attachments = data['attachments'] as List<dynamic>;
      final first = attachments[0] as Map<String, dynamic>;

      // 附件字节外置；正文只留元数据。
      expect(first['dataUrl'], '');
      expect(first['mimeType'], 'image/png');
      expect(first['byteSize'], bytes.length);
      expect(await store.readBytes('att-1'), bytes);
      expect((attachments[1] as Map<String, dynamic>)['dataUrl'], '');

      // 其它字段（含转义、null、嵌套数组/对象、数字）保持等价。
      final entry = (data['entries'] as List<dynamic>).first as Map;
      expect(entry['note'], '午餐 "x" \\ 反斜杠');
      expect(entry['settledAt'], isNull);
      expect(entry['tags'], <String>['a', 'b']);
      expect(entry['amount'], 45.5);
      expect((data['dailyBudgets'] as Map)['2026-07'], 12.5);
      final nested = data['nested'] as Map<String, dynamic>;
      expect(nested['a'], <Object?>[
        1,
        2,
        <Object?>[3, 4],
      ]);
      expect((nested['b'] as Map)['c'], isNull);
      expect(data['empty'], isEmpty);
      expect((data['ledgerBooks'] as List).first, isA<Map>());
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('旧版加密信封被识别并交给信封解密路径', () async {
    final store = InMemoryAttachmentStore();
    final dir = await Directory.systemTemp.createTemp('verifin_legacy_env');
    final src = '${dir.path}${Platform.pathSeparator}legacy.json';
    await File(src).writeAsString(
      jsonEncode(<String, Object?>{
        'app': 'verifin',
        'enc': 'aes-gcm',
        'kdf': 'pbkdf2-sha256',
        'iter': 120000,
        'salt': 'AA==',
        'nonce': 'BB==',
        'cipher': 'CC==',
        'mac': 'DD==',
      }),
    );
    try {
      await expectLater(
        rewriteLegacyBackupJson(sourcePath: src, sink: store),
        throwsA(isA<LegacyEncryptedEnvelopeDetected>()),
      );
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
