// 截图识账 / 外部采集记账：提示词、预过滤等纯函数，与 AI 弹层入口的 UI 行为。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_entry_parser.dart';
import 'package:verifin/app/ai/ai_settings.dart';
import 'package:verifin/app/models.dart';

import 'support/test_harness.dart';

AiEntryContext _context() => AiEntryContext(
  expenseCategories: const <AiOption>[
    AiOption(id: 'dining', label: '餐饮'),
    AiOption(id: 'transport', label: '交通'),
  ],
  incomeCategories: const <AiOption>[AiOption(id: 'salary', label: '工资')],
  accounts: const <AiOption>[AiOption(id: 'cash', label: '现金')],
  today: DateTime(2026, 7, 7, 12, 30),
  bookId: 'default',
);

void main() {
  useTestDatabases();

  group('capturedTextLikelyTransaction', () {
    test('含数字的文本判定可能是交易', () {
      expect(capturedTextLikelyTransaction('支付成功 ￥32.50'), isTrue);
      expect(capturedTextLikelyTransaction('到账１００元'), isTrue); // 全角数字
    });

    test('无任何数字的文本直接短路', () {
      expect(capturedTextLikelyTransaction('周末一起吃饭吗'), isFalse);
      expect(capturedTextLikelyTransaction(''), isFalse);
    });
  });

  group('buildCapturedEntryPrompt', () {
    test('在基础提示词上追加采集文本规则', () {
      final prompt = buildCapturedEntryPrompt(_context());
      // 沿用基础提示词的清单与日期。
      expect(prompt, contains('2026-07-07'));
      expect(prompt, contains('dining'));
      expect(prompt, contains('salary'));
      expect(prompt, contains('cash'));
      // 采集文本专属规则：OCR 噪音、忽略余额类数字、交易时间优先、非交易置 0。
      expect(prompt, contains('OCR'));
      expect(prompt, contains('余额'));
      expect(prompt, contains('交易时间'));
      expect(prompt, contains('amount 置为 0'));
    });
  });

  group('requestCapturedEntryDraft 预过滤', () {
    test('无数字文本不调 AI 直接报无金额', () async {
      await expectLater(
        requestCapturedEntryDraft(
          // 未配置的设置：若预过滤失效走到网络层会抛别的异常，测试即失败。
          settings: const AiSettings(),
          capturedText: '今晚吃什么',
          context: _context(),
        ),
        throwsA(
          isA<AiEntryException>().having(
            (e) => e.error,
            'error',
            AiEntryError.noAmount,
          ),
        ),
      );
    });

    test('空白文本同样短路', () async {
      await expectLater(
        requestCapturedEntryDraft(
          settings: const AiSettings(),
          capturedText: '   \n ',
          context: _context(),
        ),
        throwsA(isA<AiEntryException>()),
      );
    });
  });

  group('AI 弹层的截图识账入口', () {
    testWidgets('已配置 AI 时弹层内展示截图识账按钮', (tester) async {
      final controller = await pumpApp(tester);
      controller.setAiSettings(
        const AiSettings(
          baseUrl: 'http://localhost:11434/v1',
          apiKey: 'test',
          model: 'test-model',
        ),
      );
      controller.setFabActionMode(FabActionMode.ai);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_entry_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_entry_screenshot_button')), findsOne);

      // 点按钮：弹层关闭并接力截图流程；测试宿主选图不可用视作取消，不应崩溃。
      await tester.tap(find.byKey(const Key('ai_entry_screenshot_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai_entry_screenshot_button')), findsNothing);
    });

    testWidgets('未配置 AI 时先弹配置引导', (tester) async {
      final controller = await pumpApp(tester);
      controller.setFabActionMode(FabActionMode.ai);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_entry_fab')));
      await tester.pumpAndSettle();

      expect(find.text('尚未配置 AI'), findsOne);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });
  });
}
