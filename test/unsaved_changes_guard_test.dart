import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/common_widgets.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('未修改时返回直接退出', (tester) async {
    await tester.pumpWidget(
      zhMaterialApp(home: _Launcher(page: const _GuardPage(isDirty: false))),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('保存修改？'), findsNothing);
  });

  testWidgets('修改后取消退出会保留编辑页', (tester) async {
    await tester.pumpWidget(
      zhMaterialApp(home: _Launcher(page: const _GuardPage(isDirty: true))),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('保存修改？'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('不保存'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('编辑页'), findsOneWidget);
  });

  testWidgets('修改后可以不保存并退出', (tester) async {
    await tester.pumpWidget(
      zhMaterialApp(home: _Launcher(page: const _GuardPage(isDirty: true))),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('不保存'));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
  });

  testWidgets('修改后保存成功才退出', (tester) async {
    var saveCount = 0;
    await tester.pumpWidget(
      zhMaterialApp(
        home: _Launcher(
          page: _GuardPage(
            isDirty: true,
            onSave: () async {
              saveCount += 1;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saveCount, 1);
    expect(find.text('首页'), findsOneWidget);
  });

  testWidgets('保存失败时留在编辑页', (tester) async {
    await tester.pumpWidget(
      zhMaterialApp(
        home: _Launcher(
          page: _GuardPage(isDirty: true, onSave: () async => false),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('编辑页'), findsOneWidget);
  });

  testWidgets('保存动作统一使用软碟图标且禁用态可用', (tester) async {
    await tester.pumpWidget(
      zhMaterialApp(
        home: const Scaffold(body: SaveHeaderAction(onPressed: null)),
      ),
    );

    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byTooltip('保存'), findsOneWidget);
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
  });
}

class _Launcher extends StatelessWidget {
  const _Launcher({required this.page});

  final Widget page;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const Text('首页'),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => page)),
            child: const Text('打开'),
          ),
        ],
      ),
    );
  }
}

class _GuardPage extends StatelessWidget {
  const _GuardPage({required this.isDirty, this.onSave});

  final bool isDirty;
  final Future<bool> Function()? onSave;

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      isDirty: isDirty,
      onSave: onSave ?? () async => true,
      child: Scaffold(
        body: SafeArea(child: VeriHeader(title: '编辑页', showBack: true)),
      ),
    );
  }
}
