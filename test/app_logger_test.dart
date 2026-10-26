import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/logging/app_logger.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/in_memory_ledger_repository.dart';
import 'support/test_harness.dart';

/// 载入与首启动播种正常、但保存月度预算时抛错的仓储（预算保存不在播种路径上），
/// 用于验证落库失败的错误处理。
class _ThrowingOnBudgetSaveRepository extends InMemoryLedgerRepository {
  @override
  Future<void> saveMonthlyBudgets(Map<String, double> budgets) async {
    throw StateError('disk full');
  }
}

void main() {
  useTestDatabases();

  test('记录后最新在前，并持久化到 KV、跨实例可恢复', () {
    final store = LocalKeyValueStore();
    final logger = AppLogger(store);
    logger.info('first');
    logger.error(
      'boom',
      source: 'persist',
      error: StateError('disk full'),
      stackTrace: StackTrace.fromString(
        '#0      persist (package:verifin/controller.dart:42:9)',
      ),
    );

    expect(logger.records.length, 2);
    expect(logger.records.first.level, AppLogLevel.error);
    expect(logger.records.first.message, contains('disk full'));
    expect(logger.records.first.stack, contains('controller.dart:42:9'));
    expect(
      logger.exportText(),
      contains('#0      persist (package:verifin/controller.dart:42:9)'),
    );
    expect(logger.records.last.message, 'first');

    // 新实例从同一 KV 恢复。
    final restored = AppLogger(store);
    expect(restored.records.length, 2);
    expect(restored.records.first.message, contains('boom'));
    expect(restored.records.first.stack, contains('controller.dart:42:9'));
  });

  test('旧日志没有 stack 字段时仍可恢复', () {
    final store = LocalKeyValueStore();
    store.write(
      'verifin.logs.v1',
      '[{"time":"2026-10-01T12:00:00.000","level":"error",'
          '"message":"legacy","source":"flutter"}]',
    );

    final restored = AppLogger(store);
    expect(restored.records.single.message, 'legacy');
    expect(restored.records.single.stack, isNull);
  });

  test('超过上限时丢弃最旧记录', () {
    final store = LocalKeyValueStore();
    final logger = AppLogger(store);
    for (var i = 0; i < 250; i++) {
      logger.info('log $i');
    }
    expect(logger.records.length, 200);
    expect(logger.records.first.message, 'log 249');
    expect(logger.records.any((r) => r.message == 'log 0'), isFalse);
  });

  test('clear 清空并持久化', () {
    final store = LocalKeyValueStore();
    final logger = AppLogger(store);
    logger.info('x');
    logger.clear();
    expect(logger.isEmpty, isTrue);
    expect(AppLogger(store).isEmpty, isTrue);
  });

  test('组件配置引擎的日志在下次启动时合并进主日志并清理旁路键', () {
    final store = LocalKeyValueStore();
    final configLogger = AppLogger.widgetConfiguration(store);
    configLogger.error('config failed', source: 'widgets');
    expect(store.read(AppLogger.widgetConfigStorageKey), isNotNull);
    expect(
      store.read('verifin.logs.v1'),
      isNull,
      reason: '配置引擎不能写主日志键，否则与主引擎互相覆盖',
    );

    final main = AppLogger(store);
    expect(
      main.records.any((record) => record.message.contains('config failed')),
      isTrue,
    );
    expect(store.read(AppLogger.widgetConfigStorageKey), isNull);

    // 合并结果已持久化到主日志键，下次启动仍能看到。
    expect(
      AppLogger(
        store,
      ).records.any((record) => record.message.contains('config failed')),
      isTrue,
    );
  });

  test('合并旁路日志时按内容去重', () {
    final store = LocalKeyValueStore();
    final record = AppLogRecord(
      time: DateTime(2026, 1, 1, 9),
      level: AppLogLevel.error,
      message: 'duplicated',
      source: 'widgets',
    );
    final encoded = jsonEncode(<Object?>[record.toJson()]);
    store.write('verifin.logs.v1', encoded);
    store.write(AppLogger.widgetConfigStorageKey, encoded);

    final main = AppLogger(store);

    expect(
      main.records.where((item) => item.message == 'duplicated').length,
      1,
    );
    expect(store.read(AppLogger.widgetConfigStorageKey), isNull);
  });

  test('落库失败触发 onPersistError 并记入日志', () async {
    final store = LocalKeyValueStore();
    final logger = AppLogger(store);
    final controller = await createTestController(
      store,
      repository: _ThrowingOnBudgetSaveRepository(),
      logger: logger,
    );
    Object? reported;
    controller.onPersistError = (error) => reported = error;

    controller.setMonthlyBudget(DateTime(2026, 7), 1000);
    final succeeded = await controller.waitForPendingWritesSucceeded();

    expect(succeeded, isFalse);
    expect(reported, isNotNull);
    expect(logger.records.any((r) => r.source == 'persist'), isTrue);
    controller.dispose();
  });

  test('交易保存校验失败记录错误码且不写入账目内容', () async {
    final store = LocalKeyValueStore();
    final logger = AppLogger(store);
    final controller = await createTestController(
      store,
      repository: InMemoryLedgerRepository(),
      logger: logger,
    );
    logger.clear();
    final categoryId = controller.categoriesForType(EntryType.expense).first.id;

    final result = await controller.saveEntryAggregateDraftResult(
      entry: LedgerEntry(
        id: 'invalid-normalization',
        bookId: controller.activeBook.id,
        type: EntryType.expense,
        amount: 10.001,
        baseAmount: 10.001,
        categoryId: categoryId,
        accountId: '',
        note: 'private note',
        occurredAt: DateTime(2026, 7, 4),
      ),
      isNew: true,
    );

    expect(result, isA<EntrySaveValidationFailure>());
    expect(
      (result as EntrySaveValidationFailure).code,
      EntryValidationCode.invalidAmounts,
    );
    final record = logger.records.single;
    expect(record.level, AppLogLevel.warning);
    expect(record.source, 'entry_save');
    expect(record.message, contains('invalidAmounts'));
    expect(record.message, contains('ledger: invalidAmount'));
    expect(record.message, isNot(contains('private note')));
    expect(record.message, isNot(contains('10.001')));
    controller.dispose();
  });
}
