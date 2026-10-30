import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 最小 xlsx 读取：解压 zip，正则解析 sharedStrings + 首个 worksheet。沿用仓库「手写 XML
/// 正则解析」（如 WebDAV PROPFIND）的做法，不引入 xlsx 依赖。数字单元格保留原文（如日期
/// 序列号），由调用方按列语义再转换。解析失败抛 [FormatException]。
List<List<String>> parseXlsx(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('无法读取 xlsx 文件（可能不是有效的 Excel 文件）');
  }
  String? readEntry(String name) {
    for (final file in archive.files) {
      if (file.isFile && file.name == name) {
        return utf8.decode(file.content as List<int>);
      }
    }
    return null;
  }

  final sharedXml = readEntry('xl/sharedStrings.xml');
  final sharedStrings = sharedXml == null
      ? const <String>[]
      : _parseSharedStrings(sharedXml);

  final sheetXml =
      readEntry('xl/worksheets/sheet1.xml') ?? _firstWorksheet(archive);
  if (sheetXml == null) {
    throw const FormatException('xlsx 缺少工作表数据');
  }
  return _parseSheet(sheetXml, sharedStrings);
}

String? _firstWorksheet(Archive archive) {
  for (final file in archive.files) {
    if (file.isFile &&
        file.name.startsWith('xl/worksheets/') &&
        file.name.endsWith('.xml')) {
      return utf8.decode(file.content as List<int>);
    }
  }
  return null;
}

final RegExp _siRe = RegExp(r'<si>(.*?)</si>', dotAll: true);
final RegExp _tRe = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);
final RegExp _rowRe = RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true);
// 属性段必须惰性匹配：`<c r="I2"/>` 这类空单元格没有 `<v>`，贪婪的 `[^>]*` 会把
// `/>` 里的 `/` 一起吞掉，转而匹配到下一格，导致整行列错位（随手记导出大量使用
// 带样式的空单元格）。惰性匹配先尝试 `/>`，正常单元格再回退到 `>...</c>`。
final RegExp _cellRe = RegExp(r'<c\b([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true);
final RegExp _vRe = RegExp(r'<v>(.*?)</v>', dotAll: true);
final RegExp _isTRe = RegExp(r'<is>.*?<t[^>]*>(.*?)</t>.*?</is>', dotAll: true);
final RegExp _tAttrRe = RegExp(r't="([^"]*)"');
final RegExp _rAttrRe = RegExp(r'r="([A-Z]+)\d+"');

List<String> _parseSharedStrings(String xml) {
  return _siRe
      .allMatches(xml)
      .map(
        (m) => _tRe
            .allMatches(m.group(1)!)
            .map((t) => _unescapeXml(t.group(1)!))
            .join(),
      )
      .toList();
}

List<List<String>> _parseSheet(String xml, List<String> shared) {
  final rows = <List<String>>[];
  for (final rowMatch in _rowRe.allMatches(xml)) {
    final cells = <String>[];
    var expected = 0;
    for (final cellMatch in _cellRe.allMatches(rowMatch.group(1)!)) {
      final attrs = cellMatch.group(1) ?? '';
      final body = cellMatch.group(2) ?? '';
      // 按单元格引用（如 "C16"）的列字母对齐，补齐被跳过的空列。
      final colLetters = _rAttrRe.firstMatch(attrs)?.group(1);
      if (colLetters != null) {
        final colIndex = _columnLettersToIndex(colLetters);
        while (expected < colIndex) {
          cells.add('');
          expected++;
        }
      }
      cells.add(_cellValue(attrs, body, shared));
      expected++;
    }
    rows.add(cells);
  }
  return rows;
}

String _cellValue(String attrs, String body, List<String> shared) {
  final type = _tAttrRe.firstMatch(attrs)?.group(1);
  if (type == 's') {
    final v = _vRe.firstMatch(body)?.group(1);
    final index = int.tryParse(v ?? '');
    if (index != null && index >= 0 && index < shared.length) {
      return shared[index];
    }
    return '';
  }
  if (type == 'inlineStr') {
    return _unescapeXml(_isTRe.firstMatch(body)?.group(1) ?? '');
  }
  final v = _vRe.firstMatch(body)?.group(1);
  return v == null ? '' : _unescapeXml(v);
}

int _columnLettersToIndex(String letters) {
  var index = 0;
  for (var i = 0; i < letters.length; i++) {
    index = index * 26 + (letters.codeUnitAt(i) - 64);
  }
  return index - 1;
}

String _unescapeXml(String input) {
  if (!input.contains('&')) {
    return input;
  }
  return input
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      )
      .replaceAllMapped(
        RegExp(r'&#x([0-9A-Fa-f]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      )
      .replaceAll('&amp;', '&');
}
