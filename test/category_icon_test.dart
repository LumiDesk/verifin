import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/icon_catalog.dart';
import 'package:verifin/pages/sheets.dart';

import 'support/test_harness.dart';

void main() {
  group('emoji 图标 code 助手', () {
    test('封装 / 识别 / 取值', () {
      final code = emojiIconCode('🍜');
      expect(code, 'emoji:🍜');
      expect(isEmojiIconCode(code), isTrue);
      expect(emojiOfIconCode(code), '🍜');
    });

    test('内置图标 code 不被误判为 emoji', () {
      expect(isEmojiIconCode('dining'), isFalse);
      // 非 emoji code 原样返回。
      expect(emojiOfIconCode('dining'), 'dining');
    });

    test('扩充后的内置图标 code 都能解析出图标（无回退到默认钱包以外的异常）', () {
      for (final code in categoryIconCodes) {
        expect(iconForCode(code), isA<IconData>());
      }
    });
  });

  testWidgets('CategoryIconBox 渲染 emoji 为文字、内置为图标', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              CategoryIconBox(iconCode: emojiIconCode('🍜')),
              const CategoryIconBox(iconCode: 'dining'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('🍜'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
  });

  testWidgets('图标选择器点 emoji 返回 emoji code', (tester) async {
    String? picked;
    await tester.pumpWidget(
      zhMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showCategoryIconPickerSheet(
                    context: context,
                    selected: 'category',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // 点第一个 emoji 快选（在滚动区内，先滚动到可见）。
    await tester.ensureVisible(find.text(categoryEmojiChoices.first));
    await tester.pumpAndSettle();
    await tester.tap(find.text(categoryEmojiChoices.first));
    await tester.pumpAndSettle();
    expect(picked, emojiIconCode(categoryEmojiChoices.first));
  });
}
