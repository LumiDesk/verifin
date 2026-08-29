import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:verifin/app/account_icon_assets.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/icon_catalog.dart';
import 'package:verifin/app/models.dart';

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

    final registered = <String>{
      ...paths,
      ...genericAccountIconAssetPaths.values,
    };
    final onDisk = Directory('assets/account_icons')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.svg'))
        .map((file) => file.path.replaceAll('\\', '/'))
        .toSet();
    expect(onDisk, registered);

    expect(genericAccountIconCodes, accountIconCodes);
    expect(genericAccountIconAssetPaths.keys, genericAccountIconCodes);
    const expectedColors = <String, String>{
      'wallet': '#346EDB',
      'credit': '#7B61D1',
      'bank': '#2F6F8A',
      'cash': '#16A36F',
      'investment': '#E9862D',
      'savings': '#D95C8A',
      'card': '#2A8FB0',
    };
    for (final entry in genericAccountIconAssetPaths.entries) {
      final path = entry.value;
      final svg = File(path).readAsStringSync();
      expect(svg, contains('viewBox='), reason: path);
      expect(
        svg,
        contains('fill="${expectedColors[entry.key]}"'),
        reason: path,
      );
      expect(svg, isNot(contains('currentColor')), reason: path);
      expect(svg, isNot(contains('<script')), reason: path);
      expect(svg, isNot(contains('<image')), reason: path);
    }

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

  test('历史图标 code 只在数据边界迁移到当前目录', () {
    expect(normalizeAccountIconCode('alipay'), 'asset:payment_006');
    expect(normalizeAccountIconCode('wechat'), 'asset:payment_004');
    expect(normalizeAccountIconCode('folder'), 'wallet');
    expect(normalizeAccountIconCode('unknown'), 'wallet');
    expect(normalizeAccountIconCode(null), 'wallet');

    for (final legacy in const <String>['alipay', 'wechat', 'folder']) {
      final account = Account.fromJson(<String, Object?>{
        'id': 'legacy-$legacy',
        'iconCode': legacy,
      });
      expect(account.iconCode, normalizeAccountIconCode(legacy));
    }
  });

  testWidgets('默认与品牌账户图标统一使用白底 SVG 和 10% 内边距', (tester) async {
    Future<void> pump(Brightness brightness) {
      return tester.pumpWidget(
        MaterialApp(
          theme: buildVeriFinTheme(brightness),
          home: Scaffold(
            body: Row(
              children: const <Widget>[
                AccountIconBox(
                  key: Key('generic_account_icon'),
                  iconCode: 'wallet',
                  size: 36,
                ),
                AccountIconBox(
                  key: Key('brand_account_icon'),
                  iconCode: 'asset:payment_006',
                  size: 36,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Container iconContainer(String key) {
      return tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Container),
            )
            .first,
      );
    }

    await pump(Brightness.dark);
    expect(find.byType(SvgPicture), findsNWidgets(2));
    for (final key in const <String>[
      'generic_account_icon',
      'brand_account_icon',
    ]) {
      final container = iconContainer(key);
      expect((container.padding! as EdgeInsets).left, closeTo(3.6, 0.001));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(
        decoration.border!.top.color,
        Colors.black.withValues(alpha: 0.08),
      );
    }

    await pump(Brightness.light);
    expect(
      (iconContainer('generic_account_icon').decoration! as BoxDecoration)
          .color,
      Colors.white,
    );
  });
}
