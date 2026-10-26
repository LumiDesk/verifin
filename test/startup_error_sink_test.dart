import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/logging/app_logger.dart';
import 'package:verifin/app/startup/startup_error_sink.dart';
import 'package:verifin/local_storage/local_storage.dart';

void main() {
  test('logger 就绪前的记录先缓冲，attach 后按原时间回放', () {
    final sink = StartupErrorSink();
    final first = DateTime(2026, 10, 26, 8, 0, 0);
    sink.error('first failure', source: 'startup');
    sink.info('first frame', source: 'startup');

    expect(sink.pendingRecords, hasLength(2));
    expect(sink.pendingRecords.first.message, 'first failure');
    final logger = AppLogger(LocalKeyValueStore());
    sink.attach(logger);

    expect(sink.pendingRecords, isEmpty);
    expect(logger.records, hasLength(2));
    // 最新在前；时间戳来自记录本身（不为回放时刻）。
    expect(logger.records.first.message, 'first frame');
    expect(logger.records.last.message, 'first failure');
    expect(logger.records.last.time.isAfter(first), isTrue);
  });

  test('attach 之后的新记录直接写入 logger', () {
    final sink = StartupErrorSink();
    final logger = AppLogger(LocalKeyValueStore());
    sink.attach(logger);

    sink.warning('slow start', source: 'startup');

    expect(sink.pendingRecords, isEmpty);
    expect(logger.records.single.message, 'slow start');
    expect(logger.records.single.level, AppLogLevel.warning);
  });

  test('缓冲上限只保留最近的记录', () {
    final sink = StartupErrorSink(maxPending: 3);
    for (var i = 0; i < 5; i += 1) {
      sink.info('record $i');
    }
    expect(sink.pendingRecords.map((r) => r.message), <String>[
      'record 2',
      'record 3',
      'record 4',
    ]);
  });

  test('recordFlutterError 带上 context 与 informationCollector', () {
    final sink = StartupErrorSink();
    final logger = AppLogger(LocalKeyValueStore());
    sink.attach(logger);

    sink.recordFlutterError(
      FlutterErrorDetails(
        exception: StateError('boom'),
        stack: StackTrace.current,
        library: 'widgets',
        context: ErrorDescription('while building HomePage'),
        informationCollector: () => <DiagnosticsNode>[
          ErrorDescription('the relevant widget was Text'),
        ],
      ),
    );

    final record = logger.records.single;
    expect(record.level, AppLogLevel.error);
    expect(record.source, 'flutter/widgets');
    expect(record.message, contains('Bad state: boom'));
    expect(record.message, contains('Context: while building HomePage'));
    expect(record.message, contains('the relevant widget was Text'));
    expect(record.stack, isNotNull);
  });

  test('informationCollector 抛错时保留原始异常', () {
    final sink = StartupErrorSink();
    final logger = AppLogger(LocalKeyValueStore());
    sink.attach(logger);

    sink.recordFlutterError(
      FlutterErrorDetails(
        exception: StateError('boom'),
        informationCollector: () => throw StateError('collector failed'),
      ),
    );

    final record = logger.records.single;
    expect(record.message, contains('Bad state: boom'));
    expect(record.message, contains('Information collector failed'));
  });
}
