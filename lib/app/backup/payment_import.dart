import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';

import '../models.dart';
import 'transaction_import.dart';
import 'xls_reader.dart';

/// 支付平台 / 记账软件账单来源。用户在导入前显式选择，避免仅靠表头猜测出错。
///
/// 每种来源的表头与字段解析都基于用户提供的**真实导出样例**：
/// - [alipay] 支付宝「交易明细」CSV：GBK 编码、前置多行说明、含「不计收支」。
/// - [wechat] 微信「支付账单」xlsx：二进制表格、日期为 Excel 序列号、含「中性交易」。
/// - [mint] 薄荷记账 CSV：UTF-16LE 编码、**制表符分隔**、支出金额为负。
/// - [yimu] 一木记账 xls：老式 BIFF8 二进制 Excel，金额带符号、含一/二级分类。
/// - [genericCsv] 通用 CSV（Veri Fin 模板 / 钱迹 / 随手记）：UTF-8 逗号分隔，走别名识别。
enum ImportPlatform {
  alipay,
  wechat,
  mint,
  yimu,
  genericCsv;

  /// 该来源可选择的文件扩展名（用于文件选择器过滤）。
  List<String> get fileExtensions => switch (this) {
    ImportPlatform.wechat => const <String>['xlsx'],
    ImportPlatform.yimu => const <String>['xls'],
    _ => const <String>['csv', 'txt'],
  };
}

/// Veri Fin 规范列头：各平台归一化后统一转成这套列，再复用 [buildImportPlan]。
const List<String> _canonicalHeader = <String>[
  '日期',
  '类型',
  '金额',
  '分类',
  '账户',
  '转入账户',
  '备注',
];

/// 解析所选平台的账单文件字节，构建导入计划（纯函数，便于测试）。
///
/// 各平台先归一化为 Veri Fin 规范列，再交给 [buildImportPlan] 统一建账户/分类、
/// 生成交易与逐行错误。解析不出有效表头时抛 [FormatException]。
ImportPlan buildPlatformImportPlan({
  required ImportPlatform platform,
  required Uint8List bytes,
  required String bookId,
  required List<Account> existingAccounts,
  required List<Category> existingCategories,
  required DateTime now,
}) {
  final rows = switch (platform) {
    ImportPlatform.alipay => _normalizeAlipay(_decodeGbk(bytes)),
    ImportPlatform.wechat => _normalizeWechat(parseXlsx(bytes)),
    ImportPlatform.mint => _normalizeMint(_decodeUtf16(bytes)),
    ImportPlatform.yimu => _normalizeYimu(parseXls(bytes)),
    ImportPlatform.genericCsv => parseCsv(_decodeUtf8(bytes)),
  };
  return buildImportPlan(
    rows: rows,
    bookId: bookId,
    existingAccounts: existingAccounts,
    existingCategories: existingCategories,
    now: now,
  );
}

// ---------------------------------------------------------------------------
// 编码解码
// ---------------------------------------------------------------------------

String _decodeUtf8(Uint8List bytes) {
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

String _decodeGbk(Uint8List bytes) => gbk.decode(bytes);

String _decodeUtf16(Uint8List bytes) => utf16.decode(bytes);

// ---------------------------------------------------------------------------
// 支付宝：GBK CSV，前置说明行，表头含「交易时间 / 收/支 / 金额 / 交易分类」。
// ---------------------------------------------------------------------------

List<List<String>> _normalizeAlipay(String content) {
  final rows = parseCsv(content);
  final headerIndex = _findHeaderRow(
    rows,
    mustHave: const <String>['交易时间', '收/支'],
  );
  if (headerIndex == null) {
    throw const FormatException('未找到支付宝账单表头（交易时间/收/支），请确认选择的是支付宝导出的 CSV');
  }
  final cols = _columnIndex(rows[headerIndex]);
  final out = <List<String>>[_canonicalHeader];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    final direction = _at(row, cols['收/支']).trim();
    // 「不计收支」（花呗还款、余额宝转入、理财收益等）为账户内部资金流转，跳过以免重复记账。
    if (direction != '支出' && direction != '收入') {
      continue;
    }
    final account = _firstSegment(_at(row, cols['收/付款方式']));
    final note = _joinNote(<String>[
      _at(row, cols['商品说明']),
      _at(row, cols['交易对方']),
    ]);
    out.add(<String>[
      _at(row, cols['交易时间']),
      direction,
      _at(row, cols['金额']),
      _at(row, cols['交易分类']),
      account.isEmpty ? '支付宝' : account,
      '',
      note,
    ]);
  }
  return out;
}

// ---------------------------------------------------------------------------
// 微信：xlsx，日期为 Excel 序列号，表头含「交易时间 / 收/支 / 金额(元) / 支付方式」。
// ---------------------------------------------------------------------------

List<List<String>> _normalizeWechat(List<List<String>> rows) {
  final headerIndex = _findHeaderRow(
    rows,
    mustHave: const <String>['交易时间', '收/支'],
  );
  if (headerIndex == null) {
    throw const FormatException('未找到微信账单表头（交易时间/收/支），请确认选择的是微信导出的 xlsx');
  }
  final cols = _columnIndex(rows[headerIndex]);
  final out = <List<String>>[_canonicalHeader];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    final direction = _at(row, cols['收/支']).trim();
    // 「中性交易」（提现、理财通、零钱通存取、信用卡还款等）为资金流转，跳过。
    if (direction != '支出' && direction != '收入') {
      continue;
    }
    final rawMethod = _at(row, cols['支付方式']).trim();
    final account = (rawMethod.isEmpty || rawMethod == '/') ? '微信' : rawMethod;
    final counterparty = _at(row, cols['交易对方']);
    final product = _at(row, cols['商品']);
    // 「商品」列常是「商户订单号：…」这类无意义内容，仅在可读时并入备注。
    final usefulProduct = product.startsWith('商户订单号') || product == '/'
        ? ''
        : product;
    out.add(<String>[
      _excelSerialToDate(_at(row, cols['交易时间'])),
      direction,
      _at(row, cols['金额(元)']),
      '',
      account,
      '',
      _joinNote(<String>[counterparty, usefulProduct]),
    ]);
  }
  return out;
}

// ---------------------------------------------------------------------------
// 薄荷记账：UTF-16 制表符分隔，类型为 收入/支出/转账，支出金额为负。
// ---------------------------------------------------------------------------

List<List<String>> _normalizeMint(String content) {
  final rows = _parseTsv(content);
  final headerIndex = _findHeaderRow(
    rows,
    mustHave: const <String>['类型', '金额', '账户'],
  );
  if (headerIndex == null) {
    throw const FormatException('未找到薄荷记账表头（类型/金额/账户），请确认选择的是薄荷记账导出的 CSV');
  }
  final cols = _columnIndex(rows[headerIndex]);
  final out = <List<String>>[_canonicalHeader];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    final type = _at(row, cols['类型']).trim();
    final note = _joinNote(<String>[
      _at(row, cols['备注']),
      _at(row, cols['项目']),
    ]);
    if (type == '转账') {
      out.add(<String>[
        _at(row, cols['日期']),
        type,
        _at(row, cols['金额']),
        '',
        _at(row, cols['付款']),
        _at(row, cols['收款']),
        note,
      ]);
    } else {
      out.add(<String>[
        _at(row, cols['日期']),
        type,
        _at(row, cols['金额']),
        _at(row, cols['分类']),
        _at(row, cols['账户']),
        '',
        note,
      ]);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// 一木记账：BIFF8 .xls，列含 日期/收支类型/金额(带符号)/类别/二级分类/账户。
// 金额符号仅表方向（管线取绝对值），分类取二级分类（用户实际选择的叶子），
// 为空回退一级类别；转账无「转入账户」列，仅记转出账户。
// ---------------------------------------------------------------------------

List<List<String>> _normalizeYimu(List<List<String>> rows) {
  final headerIndex = _findHeaderRow(
    rows,
    mustHave: const <String>['日期', '收支类型', '金额'],
  );
  if (headerIndex == null) {
    throw const FormatException('未找到一木记账表头（日期/收支类型/金额），请确认选择的是一木记账导出的 xls');
  }
  final cols = _columnIndex(rows[headerIndex]);
  final out = <List<String>>[_canonicalHeader];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    final type = _at(row, cols['收支类型']).trim();
    if (type != '支出' && type != '收入' && type != '转账') {
      continue;
    }
    final level1 = _at(row, cols['类别']);
    final level2 = _at(row, cols['二级分类']);
    final category = level2.isNotEmpty ? level2 : level1;
    final account = _at(row, cols['账户']);
    final note = _at(row, cols['备注']);
    if (type == '转账') {
      out.add(<String>[
        _at(row, cols['日期']),
        type,
        _at(row, cols['金额']),
        '',
        account,
        '',
        note,
      ]);
    } else {
      out.add(<String>[
        _at(row, cols['日期']),
        type,
        _at(row, cols['金额']),
        category,
        account,
        '',
        note,
      ]);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// 通用辅助
// ---------------------------------------------------------------------------

/// 在前若干行中定位包含全部 [mustHave] 列名的表头行；找不到返回 null。
int? _findHeaderRow(List<List<String>> rows, {required List<String> mustHave}) {
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
Map<String, int> _columnIndex(List<String> header) {
  final map = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    map.putIfAbsent(header[i].trim(), () => i);
  }
  return map;
}

String _at(List<String> row, int? index) {
  if (index == null || index < 0 || index >= row.length) {
    return '';
  }
  return row[index].trim();
}

/// 取「招商银行储蓄卡(0966)&红包」「花呗&花呗青春特惠」的第一段作账户名。
String _firstSegment(String raw) {
  final value = raw.trim();
  final amp = value.indexOf('&');
  return amp >= 0 ? value.substring(0, amp).trim() : value;
}

/// 拼备注：去重、去空、取前两段有效文本，避免过长。
String _joinNote(List<String> parts) {
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

/// 简单制表符分隔解析（薄荷记账导出以 \t 分隔、字段无引号包裹）。
List<List<String>> _parseTsv(String input) {
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

/// Excel 序列号（1900 日期系统）→ "YYYY-MM-DD HH:MM:SS"。非数字原样返回。
String _excelSerialToDate(String raw) {
  final serial = double.tryParse(raw.trim());
  if (serial == null) {
    return raw.trim();
  }
  // Excel 1900 系统以 1899-12-30 为 0（含 1900 闰年 bug 的偏移）。
  final whole = serial.floor();
  final fraction = serial - whole;
  final seconds = (fraction * 86400).round();
  // 用 DateTime 构造器做墙钟日期运算（而非叠加绝对 Duration），避免 DST 地区跨夏令时
  // 偏移一小时把时间推到相邻日；构造器会自动归一化天/秒溢出。
  final date = DateTime(1899, 12, 30 + whole, 0, 0, seconds);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
}

// ---------------------------------------------------------------------------
// 最小 xlsx 读取：解压 zip，正则解析 sharedStrings + 首个 worksheet。
// 沿用仓库「手写 XML 正则解析」（如 WebDAV PROPFIND）的做法，不引入 xlsx 依赖。
// ---------------------------------------------------------------------------

/// 解析 xlsx 首个工作表为字符串二维表。数字单元格保留原文（如日期序列号），
/// 由各平台归一化按列语义再转换。解析失败抛 [FormatException]。
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
final RegExp _cellRe = RegExp(r'<c\b([^>]*)(?:/>|>(.*?)</c>)', dotAll: true);
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
