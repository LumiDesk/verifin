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
      expect(option.code, startsWith('asset:'));
      expect(<String>{
        'credit',
        'payment',
        'investment',
        'card',
        'digital',
        'bank',
      }, contains(option.groupKey));
      final svg = File(option.assetPath).readAsStringSync();
      expect(svg, contains('viewBox='), reason: option.assetPath);
      expect(svg, isNot(contains('<script')), reason: option.assetPath);
      expect(svg, isNot(contains('<image')), reason: option.assetPath);
      expect(svg, isNot(contains('href="http')), reason: option.assetPath);
      expect(svg, isNot(contains("href='http")), reason: option.assetPath);
    }

    expect(
      File('assets/account_icons/payment_007.svg').readAsStringSync(),
      contains('#F8322B'),
    );
    final meituan = File(
      'assets/account_icons/payment_008.svg',
    ).readAsStringSync();
    expect(meituan, contains('#FBC327'));
    expect(meituan, contains('#000'));
    expect(
      File('assets/account_icons/digital_001.svg').readAsStringSync(),
      contains('#8DEA61'),
    );
    expect(
      File('assets/account_icons/card_002.svg').readAsStringSync(),
      contains('american-express-rounded'),
    );
  });

  test('账户图标按用途分组，并在组内优先展示常用选项', () {
    List<String> labelsOf(String group) => orderedAccountAssetIconOptions
        .where((option) => option.groupKey == group)
        .map((option) => option.label)
        .toList(growable: false);

    expect(labelsOf('payment'), <String>[
      '支付宝',
      '微信支付',
      '云闪付',
      '美团',
      'PayPal',
      'Stripe',
    ]);
    expect(labelsOf('credit'), <String>['花呗', '白条']);
    expect(labelsOf('investment'), <String>[
      '余额宝',
      '国泰海通',
      'Interactive Brokers',
    ]);
    expect(labelsOf('card'), <String>[
      '银联',
      'Mastercard',
      'Visa',
      'American Express',
      'JCB',
      'Diners Club',
      'Discover',
    ]);
    expect(labelsOf('digital'), <String>[
      'Wise',
      'Revolut',
      'Payoneer',
      'Monzo',
      'N26',
    ]);
    expect(labelsOf('bank').take(6), <String>[
      '工商银行',
      '建设银行',
      '农业银行',
      '中国银行',
      '交通银行',
      '中国邮政储蓄银行',
    ]);
  });

  test('搜索别名和账户名推荐共用同一份目录', () {
    final cmb = accountAssetIconByCode('asset:bank_021')!;
    expect(accountAssetIconMatches(cmb, '招行'), isTrue);
    expect(accountAssetIconMatches(cmb, 'CMB'), isTrue);
    expect(accountAssetIconMatches(cmb, '工行'), isFalse);
    expect(suggestedAccountIconCode('CMB 信用卡'), cmb.code);
    expect(suggestedAccountIconCode('ＩＣＢＣ 工资卡'), 'asset:bank_015');
    expect(suggestedAccountIconCode('Alipay 日常消费'), 'asset:payment_006');
    expect(suggestedAccountIconCode('余额宝'), 'asset:investment_001');
    expect(suggestedAccountIconCode('美团月付'), 'asset:payment_008');
    expect(suggestedAccountIconCode('IBKR'), 'asset:investment_003');
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

  testWidgets('新增账户 SVG 均可由正式渲染组件加载', (tester) async {
    const codes = <String>[
      'asset:payment_007',
      'asset:investment_001',
      'asset:investment_002',
      'asset:investment_003',
      'asset:payment_008',
      'asset:card_001',
      'asset:card_002',
      'asset:card_003',
      'asset:card_004',
      'asset:card_005',
      'asset:digital_001',
      'asset:digital_002',
      'asset:digital_003',
      'asset:digital_004',
      'asset:digital_005',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Wrap(
              children: <Widget>[
                for (final code in codes)
                  AccountIconBox(iconCode: code, size: 36),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsNWidgets(codes.length));
    expect(tester.takeException(), isNull);
  });
}
