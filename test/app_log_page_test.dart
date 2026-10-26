import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/logging/app_logger.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/app_log_page.dart';

import 'support/in_memory_ledger_repository.dart';
import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<({AppLogger logger, VeriFinController controller})> pumpLogPage(
    WidgetTester tester,
  ) async {
    final store = LocalKeyValueStore();
    final logger = AppLogger(store);
    logger.error(
      'boom',
      source: 'flutter',
      error: StateError('exploded'),
      stackTrace: StackTrace.fromString(
        '#0      main (package:verifin/main.dart:1:1)',
      ),
    );
    final controller = await createTestController(
      store,
      repository: InMemoryLedgerRepository(),
      logger: logger,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const AppLogPage()),
      ),
    );
    await tester.pumpAndSettle();
    return (logger: logger, controller: controller);
  }

  testWidgets('默认只显示消息，展开后显示堆栈', (tester) async {
    await pumpLogPage(tester);

    expect(find.textContaining('boom: Bad state: exploded'), findsOneWidget);
    expect(find.textContaining('main.dart:1:1'), findsNothing);

    await tester.tap(find.textContaining('boom: Bad state: exploded'));
    await tester.pumpAndSettle();

    expect(find.textContaining('main.dart:1:1'), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('可以单独复制一条带堆栈的日志', (tester) async {
    await pumpLogPage(tester);

    await tester.tap(find.byTooltip('复制这条'));
    await tester.pump();
    await tester.pump();

    expect(find.text('已复制到剪贴板'), findsOneWidget);
  });
}
