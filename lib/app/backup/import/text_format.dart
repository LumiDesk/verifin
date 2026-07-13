import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';

/// 导入子系统的**格式级**共享工具：字节解码、CSV/TSV 分词、Excel 序列号→日期、
/// 表头定位等。只做「字节/文本 → 二维字符串表 / 基础类型」的搬运，不含任何领域语义
/// （账户/分类/交易概念都在 raw_import.dart 与 plan_builder.dart）。各平台 parser
/// 复用这些原语，再各自映射成 [RawImportRecord]。

// ---------------------------------------------------------------------------
// 字节解码
// ---------------------------------------------------------------------------

String decodeUtf8Bytes(Uint8List bytes) {
  var data = bytes;
  // 去掉 UTF-8 BOM。
  if (data.length >= 3 &&
      data[0] == 0xEF &&
      data[1] == 0xBB &&
      data[2] == 0xBF) {
    data = data.sublist(3);
  }
  return utf8.decode(data);
}

String decodeGbkBytes(Uint8List bytes) => gbk.decode(bytes);

String decodeUtf16Bytes(Uint8List bytes) => utf16.decode(bytes);

// ---------------------------------------------------------------------------
// CSV / TSV 分词
// ---------------------------------------------------------------------------

/// 解析 CSV（兼容引号包裹、字段内逗号与换行、双引号转义、CRLF）。
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  var fieldStarted = false;
  var rowHasContent = false;

  void endField() {
    row.add(field.toString());
    field = StringBuffer();
    fieldStarted = false;
  }

  void endRow() {
    endField();
    // 忽略完全空白的行。
    if (rowHasContent) {
      rows.add(row);
    }
    row = <String>[];
    rowHasContent = false;
  }

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(char);
        rowHasContent = true;
      }
      continue;
    }
    switch (char) {
      case '"':
        inQuotes = true;
        fieldStarted = true;
        rowHasContent = true;
        break;
      case ',':
        endField();
        break;
      case '\r':
        break;
      case '\n':
        endRow();
        break;
      default:
        field.write(char);
        if (char.trim().isNotEmpty) {
          rowHasContent = true;
        }
        fieldStarted = true;
        break;
    }
  }
  // 处理最后一行（无结尾换行）。
  if (fieldStarted || row.isNotEmpty || rowHasContent) {
    endRow();
  }
  return rows;
}

/// 简单制表符分隔解析（薄荷记账导出以 \t 分隔、字段无引号包裹）。
List<List<String>> parseTsv(String input) {
  final rows = <List<String>>[];
  for (final rawLine in input.split('\n')) {
    final line = rawLine.replaceAll('\r', '');
    if (line.trim().isEmpty) {
      continue;
    }
    rows.add(line.split('\t'));
  }
  return rows;
}

// ---------------------------------------------------------------------------
// 表头定位与取值
// ---------------------------------------------------------------------------

/// 在前若干行中定位包含全部 [mustHave] 列名的表头行；找不到返回 null。
int? findHeaderRow(List<List<String>> rows, {required List<String> mustHave}) {
  final limit = rows.length < 60 ? rows.length : 60;
  for (var i = 0; i < limit; i++) {
    final cells = rows[i].map((c) => c.trim()).toSet();
    if (mustHave.every(cells.contains)) {
      return i;
    }
  }
  return null;
}

/// 表头文本 → 列索引（去空白）。同名列取首次出现。
Map<String, int> columnIndex(List<String> header) {
  final map = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    map.putIfAbsent(header[i].trim(), () => i);
  }
  return map;
}

/// 按优先级取第一个存在的列索引，容忍同一字段在不同来源/版本里的**列名别名**
/// （如一木不同版本的子分类列：6.5.7「二级分类」、5.9.1「子类」，见 issue #12）。
/// 全部别名都不存在时返回 null（`cellAt` 遇 null 返回空串）。
int? columnOf(Map<String, int> cols, List<String> names) {
  for (final name in names) {
    final idx = cols[name];
    if (idx != null) {
      return idx;
    }
  }
  return null;
}

/// 安全取一行的某列（越界/空索引返回空串，去首尾空白）。
String cellAt(List<String> row, int? index) {
  if (index == null || index < 0 || index >= row.length) {
    return '';
  }
  return row[index].trim();
}

/// 取「招商银行储蓄卡(0966)&红包」「花呗&花呗青春特惠」的第一段作账户名。
String firstSegment(String raw) {
  final value = raw.trim();
  final amp = value.indexOf('&');
  return amp >= 0 ? value.substring(0, amp).trim() : value;
}

/// 拼备注：去重、去空、取有效文本段，避免重复与噪音（'/' 视为空）。
String joinNote(List<String> parts) {
  final seen = <String>{};
  final kept = <String>[];
  for (final part in parts) {
    final value = part.trim();
    if (value.isEmpty || value == '/' || !seen.add(value)) {
      continue;
    }
    kept.add(value);
  }
  return kept.join(' ');
}

// ---------------------------------------------------------------------------
// Excel 序列号 → 日期（微信 xlsx 的「交易时间」为 1900 日期系统序列号）
// ---------------------------------------------------------------------------

/// Excel 序列号（1900 日期系统）→ [DateTime]；非数字返回 null。
///
/// 直接产出强类型 [DateTime]，不经字符串中转——二进制来源无需「序列号→字符串→再解析」。
DateTime? excelSerialToDateTime(String raw) {
  final serial = double.tryParse(raw.trim());
  if (serial == null) {
    return null;
  }
  // Excel 1900 系统以 1899-12-30 为 0（含 1900 闰年 bug 的偏移）。
  final whole = serial.floor();
  final fraction = serial - whole;
  final seconds = (fraction * 86400).round();
  // 用 DateTime 构造器做墙钟日期运算（而非叠加绝对 Duration），避免 DST 地区跨夏令时
  // 偏移一小时把时间推到相邻日；构造器会自动归一化天/秒溢出。
  return DateTime(1899, 12, 30 + whole, 0, 0, seconds);
}
