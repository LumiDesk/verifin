import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/account_icon_assets.dart';
import 'package:verifin/app/icon_catalog.dart';

void main() {
  test('账户 SVG 目录与注册表一一对应且资源安全', () {
    final codes = accountAssetIconOptions.map((option) => option.code).toList();
    final labels = accountAssetIconOptions
        .map((option) => option.label)
        .toList();
    final paths = accountAssetIconOptions
        .map((option) => option.assetPath)
        .toList();
    expect(codes.toSet(), hasLength(codes.length));
    expect(labels.toSet(), hasLength(labels.length));
    expect(paths.toSet(), hasLength(paths.length));

    final registered = paths.toSet();
    final onDisk = Directory('assets/account_icons')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.svg'))
        .map((file) => file.path.replaceAll('\\', '/'))
        .toSet();
    expect(onDisk, registered);

    for (final option in accountAssetIconOptions) {
      expect(option.code, startsWith('asset:${option.groupKey}_'));
      expect(<String>{'credit', 'payment', 'bank'}, contains(option.groupKey));
      final svg = File(option.assetPath).readAsStringSync();
      expect(svg, contains('viewBox='), reason: option.assetPath);
      expect(svg, isNot(contains('<script')), reason: option.assetPath);
      expect(svg, isNot(contains('<image')), reason: option.assetPath);
      expect(svg, isNot(contains('href="http')), reason: option.assetPath);
      expect(svg, isNot(contains("href='http")), reason: option.assetPath);
    }
  });

  test('搜索别名和账户名推荐共用同一份目录', () {
    final cmb = accountAssetIconByCode('asset:bank_021')!;
    expect(accountAssetIconMatches(cmb, '招行'), isTrue);
    expect(accountAssetIconMatches(cmb, 'CMB'), isTrue);
    expect(accountAssetIconMatches(cmb, '工行'), isFalse);
    expect(suggestedAccountIconCode('CMB 信用卡'), cmb.code);
    expect(suggestedAccountIconCode('ＩＣＢＣ 工资卡'), 'asset:bank_015');
    expect(suggestedAccountIconCode('Alipay 日常消费'), 'asset:payment_006');
  });

  test('历史通用支付和文件夹图标只保留渲染兼容', () {
    expect(accountIconCodes, isNot(contains('alipay')));
    expect(accountIconCodes, isNot(contains('folder')));
    expect(iconForCode('alipay'), isNotNull);
    expect(iconForCode('folder'), isNotNull);
  });
}
