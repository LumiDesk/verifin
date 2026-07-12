import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/xls_reader.dart';

void main() {
  test('dump fixtures', () {
    for (final name in <String>[
      'yimu_transactions.xls',
      'yimu_transfers.xls',
      'yimu_subcategory_tags.xls',
      'yimu_refund.xls',
    ]) {
      final bytes = File('test/fixtures/$name').readAsBytesSync();
      final grid = parseXls(Uint8List.fromList(bytes));
      // ignore: avoid_print
      print('=== $name: ${grid.length} rows x ${grid.isEmpty ? 0 : grid.first.length} cols');
      for (var r = 0; r < grid.length; r++) {
        // ignore: avoid_print
        print('row $r: ${jsonEncode(grid[r])}');
      }
    }
  });
}
