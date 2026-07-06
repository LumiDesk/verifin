import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  test('加密备份信封被拒绝，且不清空现有数据', () async {
    final controller = await makeController();
    controller.addAccountGroup('我的分组');
    final groupsBefore = controller.accountGroups.length;
    expect(groupsBefore, greaterThan(0));

    // 加密信封：带 app 标记与 enc/cipher，但无任何数据键。
    final envelope = jsonEncode(<String, Object?>{
      'app': 'verifin',
      'enc': 'aes-gcm',
      'v': 1,
      'salt': 'AAAA',
      'nonce': 'BBBB',
      'cipher': 'CCCC',
      'mac': 'DDDD',
    });

    expect(() => controller.importDataJson(envelope), throwsFormatException);
    // 数据原样保留，未被默认值覆盖。
    expect(controller.accountGroups.length, groupsBefore);
    expect(controller.accountGroups.any((g) => g.name == '我的分组'), isTrue);
  });

  test('仅有 app 标记、无任何数据键的 JSON 被拒绝', () async {
    final controller = await makeController();
    final before = controller.accountGroups.length;
    final json = jsonEncode(<String, Object?>{'app': 'verifin', 'version': 1});
    expect(() => controller.importDataJson(json), throwsFormatException);
    expect(controller.accountGroups.length, before);
  });

  test('合法备份仍能正常导入', () async {
    final source = await makeController();
    source.addAccountGroup('可导入分组');
    final exported = source.exportDataJson();

    final target = await makeController();
    target.importDataJson(exported);
    expect(target.accountGroups.any((g) => g.name == '可导入分组'), isTrue);
  });
}
