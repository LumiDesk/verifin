import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/transaction_import.dart';
import 'package:verifin/app/models.dart';

void main() {
  test('演示 CSV 使用正式模板解析，可追加 18 笔跨月交易', () {
    final rows = parseCsv(
      File('docs/dev/preview-transactions.csv').readAsStringSync(),
    );
    validateCsvTemplateHeader(rows);
    final plan = buildImportPlan(
      rows: rows,
      bookId: 'preview',
      existingAccounts: [],
      existingCategories: [],
      now: DateTime(2026, 9, 5),
    );
    expect(plan.errors, isEmpty);
    expect(plan.conversionIssues, isEmpty);
    expect(plan.importedCount, 18);
    expect(plan.newAccounts.length, 2);
    expect(plan.entries.every((entry) => entry.note.startsWith('演示：')), isTrue);
    expect(
      plan.entries.where((entry) => entry.type == EntryType.transfer).length,
      1,
    );
    expect(plan.entries.map((entry) => entry.occurredAt.month).toSet(), {8, 9});
  });
}
