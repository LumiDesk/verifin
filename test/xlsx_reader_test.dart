import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/import/xlsx_reader.dart';

/// 构造最小 xlsx：只保留 sharedStrings 与首个 worksheet，单元格 XML 由调用方给出。
Uint8List _buildXlsx({
  required String sheetRowsXml,
  List<String> shared = const <String>[],
}) {
  final sst = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
  for (final value in shared) {
    sst.write('<si><t>${value.replaceAll('&', '&amp;')}</t></si>');
  }
  sst.write('</sst>');
  final sheet =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>$sheetRowsXml</sheetData></worksheet>';
  final archive = Archive()
    ..addFile(ArchiveFile.string('xl/sharedStrings.xml', sst.toString()))
    ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('自闭合空单元格不会吞掉下一格，列位置保持不变', () {
    // 随手记/WPS 的导出一律把空单元格写成 <c r="B2"/>；旧正则贪婪吃掉 `/` 后会把
    // 下一格并进当前格，导致整行右移。
    final bytes = _buildXlsx(
      shared: const <String>['名称', '备注', '现金', '午餐'],
      sheetRowsXml:
          '<row r="1">'
          '<c r="A1" t="s"><v>0</v></c>'
          '<c r="B1" t="s"><v>1</v></c>'
          '<c r="C1" t="s"><v>2</v></c>'
          '</row>'
          '<row r="2">'
          '<c r="A2" t="s"><v>3</v></c>'
          '<c r="B2"/>'
          '<c r="C2" t="s"><v>2</v></c>'
          '</row>',
    );

    expect(parseXlsx(bytes), <List<String>>[
      <String>['名称', '备注', '现金'],
      <String>['午餐', '', '现金'],
    ]);
  });

  test('行尾的连续空单元格仍按列补齐', () {
    final bytes = _buildXlsx(
      sheetRowsXml:
          '<row r="1">'
          '<c r="A1" t="inlineStr"><is><t>现金</t></is></c>'
          '<c r="B1"/>'
          '<c r="C1"/>'
          '</row>',
    );

    expect(parseXlsx(bytes), <List<String>>[
      <String>['现金', '', ''],
    ]);
  });
}
