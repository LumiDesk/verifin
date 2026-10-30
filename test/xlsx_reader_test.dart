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

/// 构造带 workbook + rels 的多工作表 xlsx。每张表用 inlineStr，避免测试依赖
/// sharedStrings 的索引排列。
Uint8List _buildWorkbook(
  List<({String name, String rowsXml, int file})> sheets,
) {
  final workbook = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets>',
    );
  final rels = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );
  final archive = Archive();
  for (var i = 0; i < sheets.length; i++) {
    final id = i + 1;
    final item = sheets[i];
    workbook.write(
      '<sheet name="${item.name.replaceAll('&', '&amp;')}" '
      'sheetId="$id" r:id="rId$id"/>',
    );
    rels.write(
      '<Relationship Id="rId$id" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet${item.file}.xml"/>',
    );
    archive.addFile(
      ArchiveFile.string(
        'xl/worksheets/sheet${item.file}.xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '<sheetData>${item.rowsXml}</sheetData></worksheet>',
      ),
    );
  }
  workbook.write('</sheets></workbook>');
  rels.write('</Relationships>');
  archive
    ..addFile(ArchiveFile.string('xl/workbook.xml', workbook.toString()))
    ..addFile(
      ArchiveFile.string('xl/_rels/workbook.xml.rels', rels.toString()),
    );
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

  test('按 workbook 顺序读取全部工作表，关系表决定文件映射', () {
    final bytes = _buildWorkbook(<({String name, String rowsXml, int file})>[
      (
        name: '收入',
        file: 2,
        rowsXml:
            '<row r="1"><c r="A1" t="inlineStr"><is><t>收入标题</t></is></c></row>',
      ),
      (
        name: '支出',
        file: 1,
        rowsXml:
            '<row r="1"><c r="A1" t="inlineStr"><is><t>支出标题</t></is></c></row>',
      ),
    ]);

    final sheets = parseXlsxSheets(bytes);
    expect(sheets.map((sheet) => sheet.name), <String>['收入', '支出']);
    expect(sheets[0].rows.single, <String>['收入标题']);
    expect(sheets[1].rows.single, <String>['支出标题']);

    // 旧的单表入口仍读 sheet1.xml，不因 workbook 顺序变化而改变微信等既有来源的行为。
    expect(parseXlsx(bytes).single, <String>['支出标题']);
  });

  test('工作表名中的 XML 实体会被还原', () {
    final bytes = _buildWorkbook(<({String name, String rowsXml, int file})>[
      (
        name: '收入&支出',
        file: 1,
        rowsXml:
            '<row r="1"><c r="A1" t="inlineStr"><is><t>值</t></is></c></row>',
      ),
    ]);

    expect(parseXlsxSheets(bytes).single.name, '收入&支出');
  });
}
