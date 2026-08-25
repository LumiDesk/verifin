import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/feedback.dart';
import 'package:verifin/l10n/app_localizations.dart';
import 'package:verifin/pages/shell.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('常驻提示不占进度区域并可手动关闭', (tester) async {
    final controller = VeriFeedbackController();
    await _pumpHost(tester, controller: controller);

    final result = controller.showMessage(
      message: '再按一次退出',
      duration: VeriFeedbackDuration.persistent,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    final card = find.byKey(const Key('veri_feedback_card_0'));
    final icon = find.byKey(const Key('veri_feedback_icon_0'));
    expect(tester.getSize(card), const Size(168, 40));
    expect(
      tester.getRect(icon).center.dy,
      closeTo(tester.getRect(card).center.dy, 0.1),
    );
    expect(find.byKey(const Key('veri_feedback_progress_0')), findsNothing);

    await _close(tester, 0);
    expect(await result, VeriFeedbackResult.dismissed);
    controller.dispose();
  });

  testWidgets('操作按钮返回 action 结果', (tester) async {
    final controller = VeriFeedbackController();
    await _pumpHost(tester, controller: controller);

    final result = controller.showMessage(
      message: '已删除交易',
      tone: VeriFeedbackTone.warning,
      duration: VeriFeedbackDuration.persistent,
      actionLabel: '撤销',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(
      tester.getSize(find.byKey(const Key('veri_feedback_card_0'))).width,
      240,
    );

    await tester.tap(find.byKey(const Key('veri_feedback_action_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(await result, VeriFeedbackResult.action);
    controller.dispose();
  });

  testWidgets('根级 Host 在 push 和 pop 路由时保持提示', (tester) async {
    final controller = VeriFeedbackController();
    await _pumpHost(
      tester,
      controller: controller,
      home: const _RouteLauncher(),
    );

    unawaited(
      controller.showMessage(
        message: '跨页面提示',
        duration: VeriFeedbackDuration.long,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final before = _progress(tester, 0);

    await tester.tap(find.byKey(const Key('push_route')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('第二页'), findsOneWidget);
    expect(find.byKey(const Key('veri_feedback_card_0')), findsOneWidget);
    expect(_progress(tester, 0), lessThan(before));

    await tester.tap(find.byKey(const Key('pop_route')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('push_route')), findsOneWidget);
    expect(find.byKey(const Key('veri_feedback_card_0')), findsOneWidget);
    controller.dispose();
  });

  testWidgets('可见栈满后按优先级提升等待消息', (tester) async {
    final controller = VeriFeedbackController();
    await _pumpHost(
      tester,
      controller: controller,
      maxVisible: 2,
      queueLimit: 2,
    );

    unawaited(
      controller.showMessage(
        message: '可见低优先级',
        duration: VeriFeedbackDuration.persistent,
        priority: VeriFeedbackPriority.low,
      ),
    );
    unawaited(
      controller.showMessage(
        message: '可见普通',
        duration: VeriFeedbackDuration.persistent,
      ),
    );
    final dropped = controller.showMessage(
      message: '等待低优先级',
      duration: VeriFeedbackDuration.persistent,
      priority: VeriFeedbackPriority.low,
    );
    unawaited(
      controller.showMessage(
        message: '等待普通',
        duration: VeriFeedbackDuration.persistent,
      ),
    );
    unawaited(
      controller.showMessage(
        message: '等待高优先级',
        duration: VeriFeedbackDuration.persistent,
        priority: VeriFeedbackPriority.high,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(await dropped, VeriFeedbackResult.dropped);
    expect(find.byKey(const Key('veri_feedback_card_0')), findsOneWidget);
    expect(find.byKey(const Key('veri_feedback_card_1')), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);

    await _close(tester, 0);
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('等待高优先级'), findsOneWidget);
    await _close(tester, 1);
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('等待普通'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('dedupeKey 合并重复提示并刷新倒计时', (tester) async {
    final controller = VeriFeedbackController();
    await _pumpHost(tester, controller: controller);

    final first = controller.showMessage(
      message: '正在备份',
      duration: VeriFeedbackDuration.long,
      dedupeKey: 'backup',
      actionLabel: '取消',
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    final before = _progress(tester, 0);

    final second = controller.showMessage(
      message: '仍在备份',
      duration: VeriFeedbackDuration.long,
      dedupeKey: 'backup',
      actionLabel: '取消',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('仍在备份', findRichText: true), findsOneWidget);
    expect(find.textContaining('×2', findRichText: true), findsOneWidget);
    expect(_progress(tester, 0), greaterThan(before));
    final messageRect = tester.getRect(
      find.byKey(const Key('veri_feedback_message_0')),
    );
    final actionRect = tester.getRect(
      find.byKey(const Key('veri_feedback_action_label_0')),
    );
    final leadingIconRect = tester.getRect(
      find.byKey(const Key('veri_feedback_icon_0')),
    );
    final closeIconRect = tester.getRect(
      find.byKey(const Key('veri_feedback_close_icon_0')),
    );
    expect(actionRect.center.dy, closeTo(messageRect.center.dy, 0.1));
    expect(closeIconRect.center.dy, closeTo(leadingIconRect.center.dy, 0.1));
    expect(await second, VeriFeedbackResult.replaced);

    await tester.tap(find.byKey(const Key('veri_feedback_action_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(await first, VeriFeedbackResult.action);
    controller.dispose();
  });

  testWidgets('Host 挂载前的重复请求也会合并', (tester) async {
    final controller = VeriFeedbackController();
    final first = controller.showMessage(
      message: '启动中',
      duration: VeriFeedbackDuration.persistent,
      dedupeKey: 'startup',
    );
    final second = controller.showMessage(
      message: '仍在启动',
      duration: VeriFeedbackDuration.persistent,
      dedupeKey: 'startup',
    );

    await _pumpHost(tester, controller: controller);
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.textContaining('仍在启动', findRichText: true), findsOneWidget);
    expect(find.textContaining('×2', findRichText: true), findsOneWidget);
    expect(await second, VeriFeedbackResult.replaced);

    await _close(tester, 0);
    expect(await first, VeriFeedbackResult.dismissed);
    controller.dispose();
  });

  testWidgets('进入后台暂停倒计时，回前台继续', (tester) async {
    final controller = VeriFeedbackController();
    await _pumpHost(tester, controller: controller);

    final result = controller.showMessage(
      message: '生命周期提示',
      duration: VeriFeedbackDuration.short,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final beforePause = _progress(tester, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('veri_feedback_card_0')), findsOneWidget);
    expect(_progress(tester, 0), closeTo(beforePause, 0.001));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(await result, VeriFeedbackResult.timedOut);
    controller.dispose();
  });

  testWidgets('关闭一条时其他提示不重建或重置进度', (tester) async {
    final controller = VeriFeedbackController();
    await _pumpHost(tester, controller: controller);

    for (final message in <String>['第一条', '第二条', '第三条']) {
      unawaited(
        controller.showMessage(
          message: message,
          duration: VeriFeedbackDuration.long,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
    }
    await tester.pump(const Duration(seconds: 1));
    final before = _progress(tester, 1);

    await tester.tap(find.byKey(const Key('veri_feedback_close_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final closing = tester
        .widget<SizeTransition>(find.byKey(const Key('veri_feedback_size_0')))
        .sizeFactor
        .value;
    expect(closing, greaterThan(0));
    expect(closing, lessThan(1));
    final during = _progress(tester, 1);
    expect(during, lessThan(before));

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(find.byKey(const Key('veri_feedback_card_0')), findsNothing);
    expect(find.byKey(const Key('veri_feedback_card_1')), findsOneWidget);
    expect(find.byKey(const Key('veri_feedback_card_2')), findsOneWidget);
    expect(_progress(tester, 1), lessThan(during));
    controller.dispose();
  });

  testWidgets('VeriFinApp 在根导航之上安装全局 Host', (tester) async {
    await pumpApp(tester);
    expect(find.byType(VeriFeedbackHost), findsOneWidget);

    final controller = VeriFeedbackHost.of(
      tester.element(find.byType(VeriFinShell)),
    );
    final result = controller.showMessage(
      message: '切换 Tab 后仍显示',
      duration: VeriFeedbackDuration.persistent,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('切换 Tab 后仍显示'), findsOneWidget);

    await tapBottomTab(tester, 1);
    expect(find.text('切换 Tab 后仍显示'), findsOneWidget);
    controller.dismissAll();
    await tester.pump();
    expect(await result, VeriFeedbackResult.cleared);
  });

  testWidgets('首页首次返回使用根级轻提示而不是 SnackBar', (tester) async {
    await pumpApp(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('再次返回退出程序'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('全局持久化失败使用高优先级去重错误提示', (tester) async {
    final appController = await pumpApp(tester);

    appController.onPersistError?.call(StateError('test'));
    appController.onPersistError?.call(StateError('test again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.textContaining('保存失败', findRichText: true), findsOneWidget);
    expect(find.textContaining('×2', findRichText: true), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required VeriFeedbackController controller,
  Widget home = const Scaffold(body: SizedBox.expand()),
  int maxVisible = 4,
  int queueLimit = 16,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildVeriFinTheme(Brightness.light),
      builder: (context, child) => VeriFeedbackHost(
        controller: controller,
        maxVisible: maxVisible,
        queueLimit: queueLimit,
        bottomMargin: 0,
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
    ),
  );
}

Future<void> _close(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(Key('veri_feedback_close_$id')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

double _progress(WidgetTester tester, int id) {
  return tester
      .widget<FractionallySizedBox>(
        find.byKey(Key('veri_feedback_progress_$id')),
      )
      .widthFactor!;
}

class _RouteLauncher extends StatelessWidget {
  const _RouteLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('push_route'),
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      key: const Key('pop_route'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('第二页'),
                    ),
                  ),
                ),
              ),
            );
          },
          child: const Text('进入第二页'),
        ),
      ),
    );
  }
}
