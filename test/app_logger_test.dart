import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/logging/app_logger.dart';
import 'package:verifin/app/veri_fin_controller.dart';
import 'package:verifin/local_storage/local_storage.dart';

import 'support/in_memory_ledger_repository.dart';

/// 载入与首启动播种正常、但保存月度预算时抛错的仓储（预算保存不在播种路径上），
/// 用于验证落库失败的错误处理。
class _ThrowingOnBudgetSaveRepository extends InMemoryLedgerRepository {
  @override
  Future<void> saveMonthlyBudgets(Map<String, double> budgets) async {
    throw StateError('disk full');
  }
}

void main() {
  test('记录后最新在前，并持久化到 KV、跨实例可恢复', () {
    final store = LocalKeyValueStore();
    final logger = AppLogger(store);
    logger.info('first');
    logger.error('boom', source: 'persist', error: StateError('disk full'));

    expect(logger.records.length, 2);
    expect(logger.records.first.level, AppLogLevel.error);
    expect(logger.records.first.message, contains('disk full'));
    expect(logger.records.last.message, 'first');

    // 新实例从同一 KV 恢复。
    final restored = AppLogger(store);
    expect(restored.records.length, 2);
    expect(restored.records.first.message, contains('boom'));
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

  test('落库失败触发 onPersistError 并记入日志', () async {
    final store = LocalKeyValueStore();
    final logger = AppLogger(store);
    final controller = await VeriFinController.create(
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
}
