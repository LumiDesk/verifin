import 'dart:typed_data';

/// 最小的老式 Excel（.xls / BIFF8）读取：解析 OLE2 复合文档取出 `Workbook`
/// 流，再按 BIFF8 记录还原首个工作表为字符串二维表。
///
/// pub.dev 上没有能读 BIFF8 的 Dart 库（`excel`/`spreadsheet_decoder` 等只支持
/// xlsx=zip+XML），故沿用仓库「手写二进制/XML 解析」的做法（如 WebDAV、xlsx），
/// 不引入原生依赖，纯 Dart 离线可用。
///
/// 只实现读取账单所需的最小记录集：SST（含 CONTINUE 跨记录拆分）、LABELSST、
/// NUMBER、RK、MULRK、BLANK/MULBLANK；数字单元格转文本，日期在一木导出里本就是
/// 文本字符串，无需处理 Excel 日期序列号。解析失败抛 [FormatException]。
List<List<String>> parseXls(Uint8List bytes) {
  final workbook = _extractWorkbookStream(bytes);
  return _parseWorkbook(workbook);
}

// OLE2 特殊扇区值。
const int _endOfChain = 0xFFFFFFFE;
const int _freeSect = 0xFFFFFFFF;

// ---------------------------------------------------------------------------
// OLE2 复合文档：取出 Workbook / Book 流
// ---------------------------------------------------------------------------

Uint8List _extractWorkbookStream(Uint8List data) {
  if (data.length < 512 ||
      data[0] != 0xD0 ||
      data[1] != 0xCF ||
      data[2] != 0x11 ||
      data[3] != 0xE0) {
    throw const FormatException('不是有效的 .xls 文件（缺少 OLE2 文件头）');
  }
  final header = ByteData.sublistView(data, 0, 512);
  final sectorSize = 1 << header.getUint16(0x1E, Endian.little);
  final miniSectorSize = 1 << header.getUint16(0x20, Endian.little);
  final miniCutoff = header.getUint32(0x38, Endian.little);
  final dirStart = header.getUint32(0x30, Endian.little);
  final miniFatStart = header.getUint32(0x3C, Endian.little);
  final difatStart = header.getUint32(0x44, Endian.little);
  final difatCount = header.getUint32(0x48, Endian.little);

  if (sectorSize <= 0 || sectorSize > 0x10000) {
    throw const FormatException('.xls 扇区大小异常');
  }

  int sectorOffset(int sector) => (sector + 1) * sectorSize;

  // DIFAT：头部内置 109 个 FAT 扇区号，超出部分在 DIFAT 扇区链里续接。
  final fatSectors = <int>[];
  for (var i = 0; i < 109; i++) {
    final v = header.getUint32(0x4C + i * 4, Endian.little);
    if (v == _freeSect || v == _endOfChain) {
      continue;
    }
    fatSectors.add(v);
  }
  var difatSector = difatStart;
  var difatGuard = 0;
  while (difatCount > 0 &&
      difatSector != _endOfChain &&
      difatSector != _freeSect &&
      difatGuard < difatCount + 8) {
    difatGuard++;
    final base = sectorOffset(difatSector);
    if (base + sectorSize > data.length) {
      break;
    }
    final view = ByteData.sublistView(data, base, base + sectorSize);
    final perSector = sectorSize ~/ 4;
    for (var i = 0; i < perSector - 1; i++) {
      final v = view.getUint32(i * 4, Endian.little);
      if (v != _freeSect && v != _endOfChain) {
        fatSectors.add(v);
      }
    }
    difatSector = view.getUint32((perSector - 1) * 4, Endian.little);
  }

  // FAT：把所有 FAT 扇区拼成「下一扇区」查找表。
  final fat = <int>[];
  for (final sector in fatSectors) {
    final base = sectorOffset(sector);
    if (base < 0 || base + sectorSize > data.length) {
      continue;
    }
    final view = ByteData.sublistView(data, base, base + sectorSize);
    for (var i = 0; i < sectorSize ~/ 4; i++) {
      fat.add(view.getUint32(i * 4, Endian.little));
    }
  }

  // 沿 FAT 链读取一个流的原始字节。
  Uint8List readChain(int start, {required int limit}) {
    final builder = BytesBuilder();
    var sector = start;
    final seen = <int>{};
    while (sector != _endOfChain &&
        sector >= 0 &&
        sector < fat.length &&
        builder.length < limit) {
      if (!seen.add(sector)) {
        break; // 防环。
      }
      final base = sectorOffset(sector);
      if (base < 0 || base + sectorSize > data.length) {
        break;
      }
      builder.add(data.sublist(base, base + sectorSize));
      sector = fat[sector];
    }
    return builder.toBytes();
  }

  // 目录流：解析条目，找 Root Entry（迷你流）与 Workbook/Book 流。
  final dir = readChain(dirStart, limit: 1 << 30);
  int? wbStart;
  var wbSize = 0;
  var rootStart = 0;
  var rootSize = 0;
  for (var off = 0; off + 128 <= dir.length; off += 128) {
    final entry = ByteData.sublistView(dir, off, off + 128);
    final nameLen = entry.getUint16(0x40, Endian.little);
    final objType = entry.getUint8(0x42);
    if (objType == 0 || nameLen < 2) {
      continue;
    }
    final name = _utf16Name(dir, off, nameLen);
    final start = entry.getUint32(0x74, Endian.little);
    final size = entry.getUint32(0x78, Endian.little);
    if (objType == 5) {
      rootStart = start;
      rootSize = size;
    } else if (objType == 2 && (name == 'Workbook' || name == 'Book')) {
      wbStart = start;
      wbSize = size;
    }
  }
  if (wbStart == null) {
    throw const FormatException('.xls 缺少 Workbook 数据流');
  }

  if (wbSize >= miniCutoff) {
    final raw = readChain(wbStart, limit: wbSize);
    return raw.length <= wbSize ? raw : Uint8List.sublistView(raw, 0, wbSize);
  }

  // 小流走迷你 FAT：先读出整个迷你流（存在 Root Entry 的主 FAT 链里），再按迷你
  // 扇区链拼出目标流。
  final miniStream = readChain(rootStart, limit: rootSize);
  final miniFat = <int>[];
  final miniFatRaw = readChain(miniFatStart, limit: 1 << 30);
  final miniFatView = ByteData.sublistView(miniFatRaw);
  for (var i = 0; i + 4 <= miniFatRaw.length; i += 4) {
    miniFat.add(miniFatView.getUint32(i, Endian.little));
  }
  final builder = BytesBuilder();
  var sector = wbStart;
  final seen = <int>{};
  while (sector != _endOfChain &&
      sector >= 0 &&
      sector < miniFat.length &&
      builder.length < wbSize) {
    if (!seen.add(sector)) {
      break;
    }
    final base = sector * miniSectorSize;
    if (base + miniSectorSize > miniStream.length) {
      break;
    }
    builder.add(miniStream.sublist(base, base + miniSectorSize));
    sector = miniFat[sector];
  }
  final raw = builder.toBytes();
  return raw.length <= wbSize ? raw : Uint8List.sublistView(raw, 0, wbSize);
}

String _utf16Name(Uint8List dir, int off, int nameLen) {
  // 名称是 UTF-16LE，nameLen 含结尾的 0 终止符（2 字节）。
  final chars = <int>[];
  for (var i = 0; i + 1 < nameLen - 2; i += 2) {
    chars.add(dir[off + i] | (dir[off + i + 1] << 8));
  }
  return String.fromCharCodes(chars);
}

// ---------------------------------------------------------------------------
// BIFF8 记录解析
// ---------------------------------------------------------------------------

// 记录类型。
const int _recBof = 0x0809;
const int _recEof = 0x000A;
const int _recSst = 0x00FC;
const int _recContinue = 0x003C;
const int _recLabelSst = 0x00FD;
const int _recNumber = 0x0203;
const int _recRk = 0x027E;
const int _recMulRk = 0x00BD;
const int _recLabel = 0x0204;

List<List<String>> _parseWorkbook(Uint8List wb) {
  final bd = ByteData.sublistView(wb);
  final records = <_BiffRecord>[];
  var pos = 0;
  while (pos + 4 <= wb.length) {
    final type = bd.getUint16(pos, Endian.little);
    final size = bd.getUint16(pos + 2, Endian.little);
    final dataStart = pos + 4;
    if (dataStart + size > wb.length) {
      break;
    }
    records.add(_BiffRecord(type, dataStart, size));
    pos = dataStart + size;
  }

  // 先解析 SST（可能带 CONTINUE 续块）。
  List<String> sst = const <String>[];
  for (var i = 0; i < records.length; i++) {
    if (records[i].type == _recSst) {
      final segments = <_BiffRecord>[records[i]];
      var j = i + 1;
      while (j < records.length && records[j].type == _recContinue) {
        segments.add(records[j]);
        j++;
      }
      sst = _parseSst(wb, segments);
      break;
    }
  }

  // 收集首个工作表子流的单元格。
  final grid = <int, Map<int, String>>{};
  var maxRow = -1;
  var maxCol = -1;
  void put(int row, int col, String value) {
    (grid[row] ??= <int, String>{})[col] = value;
    if (row > maxRow) maxRow = row;
    if (col > maxCol) maxCol = col;
  }

  var seenWorksheet = false;
  var inSheet = false;
  for (final rec in records) {
    if (rec.type == _recBof) {
      final dt = rec.size >= 4 ? bd.getUint16(rec.start + 2, Endian.little) : 0;
      if (dt == 0x0010 && !seenWorksheet) {
        seenWorksheet = true;
        inSheet = true;
      }
      continue;
    }
    if (rec.type == _recEof) {
      if (inSheet) {
        break; // 首个工作表结束。
      }
      continue;
    }
    if (!inSheet) {
      continue;
    }
    switch (rec.type) {
      case _recLabelSst:
        final row = bd.getUint16(rec.start, Endian.little);
        final col = bd.getUint16(rec.start + 2, Endian.little);
        final isst = bd.getUint32(rec.start + 6, Endian.little);
        put(row, col, isst >= 0 && isst < sst.length ? sst[isst] : '');
        break;
      case _recNumber:
        final row = bd.getUint16(rec.start, Endian.little);
        final col = bd.getUint16(rec.start + 2, Endian.little);
        final value = bd.getFloat64(rec.start + 6, Endian.little);
        put(row, col, _formatNumber(value));
        break;
      case _recRk:
        final row = bd.getUint16(rec.start, Endian.little);
        final col = bd.getUint16(rec.start + 2, Endian.little);
        final rk = bd.getUint32(rec.start + 6, Endian.little);
        put(row, col, _formatNumber(_decodeRk(rk)));
        break;
      case _recMulRk:
        final row = bd.getUint16(rec.start, Endian.little);
        final colFirst = bd.getUint16(rec.start + 2, Endian.little);
        // 结构：row, colFirst, [xf(2) rk(4)] * n, colLast(2)。
        final count = (rec.size - 6) ~/ 6;
        for (var k = 0; k < count; k++) {
          final rk = bd.getUint32(rec.start + 4 + k * 6 + 2, Endian.little);
          put(row, colFirst + k, _formatNumber(_decodeRk(rk)));
        }
        break;
      case _recLabel:
        // 旧式内联字符串（少见）：row, col, xf, cch(2), grbit(1), chars。
        final row = bd.getUint16(rec.start, Endian.little);
        final col = bd.getUint16(rec.start + 2, Endian.little);
        put(row, col, _parseLabelString(wb, rec));
        break;
    }
  }

  if (maxRow < 0) {
    return const <List<String>>[];
  }
  final rows = <List<String>>[];
  for (var r = 0; r <= maxRow; r++) {
    final rowMap = grid[r];
    final cells = <String>[];
    for (var c = 0; c <= maxCol; c++) {
      cells.add(rowMap?[c] ?? '');
    }
    rows.add(cells);
  }
  return rows;
}

class _BiffRecord {
  const _BiffRecord(this.type, this.start, this.size);

  final int type;
  final int start; // 数据起始（不含 4 字节头）。
  final int size;
}

/// 解析 SST：把 SST 记录与其后的 CONTINUE 续块拼成一段，并记录每个续块的边界；
/// 逐个还原 Unicode 字符串。字符数组跨 CONTINUE 边界时，边界处首字节是重新指定
/// 压缩标志的 grbit（BIFF8 的经典规则），据此在 8 位 / 16 位间切换。
List<String> _parseSst(Uint8List wb, List<_BiffRecord> segments) {
  final builder = BytesBuilder();
  final boundaries = <int>{};
  for (final seg in segments) {
    if (builder.length > 0) {
      boundaries.add(builder.length);
    }
    builder.add(Uint8List.sublistView(wb, seg.start, seg.start + seg.size));
  }
  final buf = builder.toBytes();
  if (buf.length < 8) {
    return const <String>[];
  }
  final bd = ByteData.sublistView(buf);
  final unique = bd.getUint32(4, Endian.little);
  var pos = 8;
  final out = <String>[];

  for (var i = 0; i < unique && pos + 3 <= buf.length; i++) {
    final cch = bd.getUint16(pos, Endian.little);
    pos += 2;
    var grbit = buf[pos];
    pos += 1;
    var highByte = (grbit & 0x01) != 0;
    final rich = (grbit & 0x08) != 0;
    final ext = (grbit & 0x04) != 0;
    var runCount = 0;
    var extSize = 0;
    if (rich) {
      runCount = bd.getUint16(pos, Endian.little);
      pos += 2;
    }
    if (ext) {
      extSize = bd.getUint32(pos, Endian.little);
      pos += 4;
    }
    // 读 cch 个字符，边界处重取 grbit。
    final sb = StringBuffer();
    var remaining = cch;
    while (remaining > 0 && pos < buf.length) {
      if (boundaries.contains(pos)) {
        grbit = buf[pos];
        pos += 1;
        highByte = (grbit & 0x01) != 0;
      }
      if (highByte) {
        if (pos + 2 > buf.length) break;
        sb.writeCharCode(bd.getUint16(pos, Endian.little));
        pos += 2;
      } else {
        sb.writeCharCode(buf[pos]);
        pos += 1;
      }
      remaining--;
    }
    // 跳过富文本格式串（每段 4 字节）与扩展/拼音数据（不重取 grbit）。
    pos += runCount * 4 + extSize;
    out.add(sb.toString());
  }
  return out;
}

String _parseLabelString(Uint8List wb, _BiffRecord rec) {
  if (rec.size < 9) {
    return '';
  }
  final bd = ByteData.sublistView(wb);
  final cch = bd.getUint16(rec.start + 6, Endian.little);
  final grbit = wb[rec.start + 8];
  final highByte = (grbit & 0x01) != 0;
  var pos = rec.start + 9;
  final end = rec.start + rec.size;
  final sb = StringBuffer();
  for (var i = 0; i < cch; i++) {
    if (highByte) {
      if (pos + 2 > end) break;
      sb.writeCharCode(bd.getUint16(pos, Endian.little));
      pos += 2;
    } else {
      if (pos + 1 > end) break;
      sb.writeCharCode(wb[pos]);
      pos += 1;
    }
  }
  return sb.toString();
}

/// RK 编码：bit0=是否除以 100，bit1=整数(1)/双精度高位(0)。
double _decodeRk(int rk) {
  final div100 = (rk & 0x01) != 0;
  final isInt = (rk & 0x02) != 0;
  double value;
  if (isInt) {
    final signed = (rk & 0x80000000) != 0 ? rk - 0x100000000 : rk;
    value = (signed >> 2).toDouble();
  } else {
    final bd = ByteData(8);
    bd.setUint32(0, 0, Endian.little);
    bd.setUint32(4, rk & 0xFFFFFFFC, Endian.little);
    value = bd.getFloat64(0, Endian.little);
  }
  return div100 ? value / 100 : value;
}

/// 数字转文本：整数去掉尾随 .0，其余用默认表示（金额随后由导入管线按 double 解析）。
String _formatNumber(double value) {
  if (value.isNaN || value.isInfinite) {
    return '';
  }
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  return value.toString();
}
