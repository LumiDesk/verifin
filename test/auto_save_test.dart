import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/auto_save.dart';
import 'package:verifin/app/common_widgets.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('连续改动在防抖结束后只提交最后一次', (WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final values = <int>[];
    var value = 0;
    final autoSave = AutoSave(
      save: () async {
        values.add(value);
        return true;
      },
      debounce: const Duration(milliseconds: 500),
    );
    addTearDown(autoSave.dispose);

    value = 1;
    autoSave.schedule();
    await tester.pump(const Duration(milliseconds: 200));
    value = 2;
    autoSave.schedule();
    await tester.pump(const Duration(milliseconds: 499));
    expect(values, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(values, <int>[2]);
    expect(autoSave.state, AutoSaveState.idle);
    expect(autoSave.hasPendingWork, isFalse);
  });

  testWidgets('保存进行中又有改动时，用最新状态再提交一次', (WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final gate = Completer<void>();
    final values = <int>[];
    var value = 1;
    final autoSave = AutoSave(
      save: () async {
        values.add(value);
        if (values.length == 1) {
          await gate.future;
        }
        return true;
      },
      debounce: const Duration(milliseconds: 10),
    );
    addTearDown(autoSave.dispose);

    autoSave.schedule();
    await tester.pump(const Duration(milliseconds: 10));
    expect(values, <int>[1]);

    value = 2;
    autoSave.schedule();
    expect(values, <int>[1]);
    expect(autoSave.hasPendingWork, isTrue);

    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(values, <int>[1, 2]);
    expect(autoSave.state, AutoSaveState.idle);
  });

  testWidgets('保存失败保留待保存状态，flush 可重试成功', (WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    var fail = true;
    var saves = 0;
    final autoSave = AutoSave(
      save: () async {
        saves += 1;
        return !fail;
      },
      debounce: const Duration(milliseconds: 10),
    );
    addTearDown(autoSave.dispose);

    autoSave.schedule();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(saves, 1);
    expect(autoSave.state, AutoSaveState.failed);
    expect(autoSave.hasFailed, isTrue);
    expect(autoSave.hasPendingWork, isTrue);

    fail = false;
    expect(await autoSave.flush(), isTrue);
    expect(saves, 2);
    expect(autoSave.state, AutoSaveState.idle);
    expect(autoSave.hasPendingWork, isFalse);
  });

  testWidgets('flush 会取消防抖并立即提交', (WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    var saves = 0;
    final autoSave = AutoSave(
      save: () async {
        saves += 1;
        return true;
      },
      debounce: const Duration(milliseconds: 500),
    );
    addTearDown(autoSave.dispose);

    autoSave.schedule();
    expect(await autoSave.flush(), isTrue);
    expect(saves, 1);
    await tester.pump(const Duration(milliseconds: 600));
    expect(saves, 1);
  });

  testWidgets('dispose 后不再触发保存', (WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    var saves = 0;
    final autoSave = AutoSave(
      save: () async {
        saves += 1;
        return true;
      },
      debounce: const Duration(milliseconds: 10),
    );

    autoSave.schedule();
    autoSave.dispose();
    await tester.pump(const Duration(milliseconds: 20));
    expect(saves, 0);
  });

  testWidgets('输入法组合期间不触发，组合结束后才触发', (WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var changes = 0;
    final detach = bindAutoSaveText(controller, () => changes += 1);

    controller.value = const TextEditingValue(
      text: 'ni',
      composing: TextRange(start: 0, end: 2),
    );
    expect(changes, 0);

    controller.value = const TextEditingValue(text: '你');
    expect(changes, 1);

    detach();
    controller.text = '你 好';
    expect(changes, 1);
  });

  testWidgets('失败提示只在失败时出现并可重试', (WidgetTester tester) async {
    var fail = true;
    final autoSave = AutoSave(
      save: () async => !fail,
      debounce: const Duration(milliseconds: 10),
    );
    addTearDown(autoSave.dispose);

    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(body: AutoSaveFailureBanner(autoSave: autoSave)),
      ),
    );
    expect(find.text('保存失败，请重试'), findsNothing);

    autoSave.schedule();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();
    expect(find.text('保存失败，请重试'), findsNothing);
  });

  testWidgets('自动保存页返回前先冲刷待保存改动', (WidgetTester tester) async {
    var saves = 0;
    final autoSave = AutoSave(
      save: () async {
        saves += 1;
        return true;
      },
      debounce: const Duration(milliseconds: 500),
    );
    addTearDown(autoSave.dispose);

    await tester.pumpWidget(
      zhMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open_auto_save_page'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => AutoSavePopScope(
                      autoSave: autoSave,
                      child: const Scaffold(
                        body: Center(child: Text('自动保存编辑页')),
                      ),
                    ),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_auto_save_page')));
    await tester.pumpAndSettle();
    autoSave.schedule();
    expect(saves, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(find.byKey(const Key('open_auto_save_page')), findsOneWidget);
  });

  testWidgets('冲刷失败时询问放弃修改后离开', (WidgetTester tester) async {
    final autoSave = AutoSave(
      save: () async => false,
      debounce: const Duration(milliseconds: 500),
    );
    addTearDown(autoSave.dispose);

    await tester.pumpWidget(
      zhMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open_failing_auto_save_page'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => AutoSavePopScope(
                      autoSave: autoSave,
                      child: const Scaffold(
                        body: Center(child: Text('自动保存编辑页')),
                      ),
                    ),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_failing_auto_save_page')));
    await tester.pumpAndSettle();
    autoSave.schedule();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('放弃修改并离开'), findsOneWidget);
    expect(find.text('自动保存编辑页'), findsOneWidget);

    await tester.tap(find.text('放弃修改并离开'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('open_failing_auto_save_page')),
      findsOneWidget,
    );
  });
}
