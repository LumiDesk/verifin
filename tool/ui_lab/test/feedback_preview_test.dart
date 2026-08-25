import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin_ui_lab/feedback_preview.dart';
import 'package:verifin_ui_lab/main.dart';

void main() {
  testWidgets('轻提示保持紧凑并提供单条关闭入口', (tester) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.feedback),
    );
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.byKey(const Key('veri_feedback_card_0')), findsOneWidget);
    expect(find.text('再按一次退出'), findsOneWidget);
    expect(find.byKey(const Key('veri_feedback_close_0')), findsOneWidget);
    expect(find.byKey(const Key('veri_feedback_progress_0')), findsOneWidget);

    final cardFinder = find.byKey(const Key('veri_feedback_card_0'));
    final cardRect = tester.getRect(cardFinder);
    final navigationRect = tester.getRect(
      find.byKey(const Key('lab_nav_capsule')),
    );
    expect(tester.getSize(cardFinder), const Size(168, 40));
    expect(cardRect.bottom, lessThan(navigationRect.top));

    final card = tester.widget<Material>(cardFinder);
    final shape = card.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(veriRadiusMd));
  });

  testWidgets('最多堆叠四条并把更多提示放入等待队列', (tester) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.feedback),
    );
    await tester.pump(const Duration(milliseconds: 240));

    for (final tone in <FeedbackTone>[
      FeedbackTone.success,
      FeedbackTone.warning,
      FeedbackTone.error,
    ]) {
      await tester.tap(find.text(tone.label));
      await tester.pump();
      await tester.tap(find.byKey(const Key('feedback_add')));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pump(const Duration(milliseconds: 240));

    final cards = _feedbackCards();
    expect(cards, findsNWidgets(4));
    for (var index = 0; index < 3; index += 1) {
      expect(
        tester.getRect(cards.at(index)).bottom,
        lessThan(tester.getRect(cards.at(index + 1)).top),
      );
    }

    await tester.tap(find.text(FeedbackTone.info.label));
    await tester.pump();
    await tester.tap(find.byKey(const Key('feedback_add')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(cards, findsNWidgets(4));
    expect(find.text('+1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('veri_feedback_close_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();
    expect(cards, findsNWidgets(4));
    expect(find.byKey(const Key('veri_feedback_pending_count')), findsNothing);
    expect(find.byKey(const Key('veri_feedback_close_4')), findsOneWidget);
  });

  testWidgets('提示支持短时长、常驻与手动关闭', (tester) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.feedback),
    );
    await tester.pump(const Duration(milliseconds: 240));

    await tester.tap(find.byKey(const Key('veri_feedback_close_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    expect(_feedbackCards(), findsNothing);

    await tester.tap(find.text(FeedbackLifetime.short.label));
    await tester.pump();
    await tester.tap(find.byKey(const Key('feedback_add')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final progress = tester.widget<FractionallySizedBox>(
      find.byKey(const Key('veri_feedback_progress_1')),
    );
    expect(progress.widthFactor, lessThan(1));
    expect(progress.widthFactor, greaterThan(0.5));

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    expect(_feedbackCards(), findsNothing);

    await tester.tap(find.text(FeedbackLifetime.persistent.label));
    await tester.pump();
    await tester.tap(find.byKey(const Key('feedback_add')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.byKey(const Key('veri_feedback_card_2')), findsOneWidget);
    expect(find.byKey(const Key('veri_feedback_progress_2')), findsNothing);
    final persistentCardRect = tester.getRect(
      find.byKey(const Key('veri_feedback_card_2')),
    );
    final persistentIconRect = tester.getRect(
      find.byKey(const Key('veri_feedback_icon_2')),
    );
    expect(
      persistentIconRect.center.dy,
      closeTo(persistentCardRect.center.dy, 0.1),
    );

    await tester.pump(const Duration(seconds: 9));
    expect(find.byKey(const Key('veri_feedback_card_2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('veri_feedback_close_2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    expect(_feedbackCards(), findsNothing);
  });

  testWidgets('关闭一条时其他提示保持倒计时并逐帧收拢', (tester) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.feedback),
    );
    await tester.pump(const Duration(milliseconds: 240));

    await tester.tap(find.text(FeedbackLifetime.long.label));
    await tester.pump();
    for (final tone in <FeedbackTone>[
      FeedbackTone.success,
      FeedbackTone.warning,
    ]) {
      await tester.tap(find.text(tone.label));
      await tester.pump();
      await tester.tap(find.byKey(const Key('feedback_add')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
    }
    await tester.pump(const Duration(seconds: 1));

    final before = tester
        .widget<FractionallySizedBox>(
          find.byKey(const Key('veri_feedback_progress_1')),
        )
        .widthFactor!;
    await tester.tap(find.byKey(const Key('veri_feedback_close_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    final closingSize = tester
        .widget<SizeTransition>(find.byKey(const Key('veri_feedback_size_0')))
        .sizeFactor
        .value;
    expect(closingSize, greaterThan(0));
    expect(closingSize, lessThan(1));
    final duringClose = tester
        .widget<FractionallySizedBox>(
          find.byKey(const Key('veri_feedback_progress_1')),
        )
        .widthFactor!;
    expect(duringClose, lessThan(before));

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(find.byKey(const Key('veri_feedback_close_0')), findsNothing);
    expect(find.byKey(const Key('veri_feedback_close_1')), findsOneWidget);
    expect(find.byKey(const Key('veri_feedback_close_2')), findsOneWidget);
    final after = tester
        .widget<FractionallySizedBox>(
          find.byKey(const Key('veri_feedback_progress_1')),
        )
        .widthFactor!;
    expect(after, lessThan(duringClose));
  });

  testWidgets('Web 悬停会暂停倒计时，移开后继续', (tester) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.feedback),
    );
    await tester.pump(const Duration(milliseconds: 240));
    await tester.tap(find.byKey(const Key('veri_feedback_close_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();

    await tester.tap(find.text(FeedbackLifetime.short.label));
    await tester.pump();
    await tester.tap(find.byKey(const Key('feedback_add')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('veri_feedback_card_1'))),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('veri_feedback_card_1')), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    expect(_feedbackCards(), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('操作按钮和重复合并直接使用正式组件能力', (tester) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.feedback),
    );
    await tester.pump(const Duration(milliseconds: 240));

    await tester.tap(find.byKey(const Key('feedback_action_toggle')));
    await tester.tap(find.byKey(const Key('feedback_dedupe_toggle')));
    await tester.tap(find.text(FeedbackLifetime.persistent.label));
    await tester.pump();
    await tester.tap(find.byKey(const Key('feedback_add')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    await tester.tap(find.byKey(const Key('feedback_add')));
    await tester.pump();

    expect(find.textContaining('×2', findRichText: true), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('veri_feedback_card_1'))).width,
      240,
    );
    await tester.tap(find.byKey(const Key('veri_feedback_action_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('最近结果：action'), findsOneWidget);
  });

  testWidgets('嵌套 Navigator 跳转时根级提示保持显示', (tester) async {
    await tester.pumpWidget(
      const VeriFinUiLabApp(initialExperiment: UiLabExperiment.feedback),
    );
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.byKey(const Key('veri_feedback_card_0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('feedback_push_route')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('路由测试页'), findsOneWidget);
    expect(find.byKey(const Key('veri_feedback_card_0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('feedback_pop_route')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('feedback_push_route')), findsOneWidget);
    expect(find.byKey(const Key('veri_feedback_card_0')), findsOneWidget);
  });
}

Finder _feedbackCards() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('veri_feedback_card_');
  });
}
