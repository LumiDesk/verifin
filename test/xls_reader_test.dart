import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/backup/xls_reader.dart';

// ---------------------------------------------------------------------------
// BIFF8 记录构造小工具：记录 = 2 字节类型 + 2 字节长度 + payload（小端）。
// ---------------------------------------------------------------------------

List<int> _u16(int v) => <int>[v & 0xFF, (v >> 8) & 0xFF];

List<int> _u32(int v) => <int>[
  v & 0xFF,
  (v >> 8) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 24) & 0xFF,
];

List<int> _f64(double v) =>
    (ByteData(8)..setFloat64(0, v, Endian.little)).buffer.asUint8List();

List<int> _rec(int type, List<int> payload) => <int>[
  ..._u16(type),
  ..._u16(payload.length),
  ...payload,
];

/// BOF：dt=0x0010 为工作表子流，0x0005 为全局（Workbook Globals）子流。
List<int> _bof({required bool worksheet}) => _rec(0x0809, <int>[
  ..._u16(0x0600),
  ..._u16(worksheet ? 0x0010 : 0x0005),
  ...List<int>.filled(12, 0),
]);

List<int> get _eof => _rec(0x000A, const <int>[]);

/// LABELSST 单元格：row + col + xf + SST 索引。
List<int> _labelSst(int row, int col, int isst) =>
    _rec(0x00FD, <int>[..._u16(row), ..._u16(col), ..._u16(0), ..._u32(isst)]);

/// NUMBER 单元格：IEEE754 双精度。
List<int> _number(int row, int col, double value) =>
    _rec(0x0203, <int>[..._u16(row), ..._u16(col), ..._u16(0), ..._f64(value)]);

/// RK 单元格。
List<int> _rkCell(int row, int col, int rk) =>
    _rec(0x027E, <int>[..._u16(row), ..._u16(col), ..._u16(0), ..._u32(rk)]);

/// MULRK：同一行内从 [colFirst] 起连续多个 RK（每个 xf(2)+rk(4)，末尾 colLast(2)）。
List<int> _mulRk(int row, int colFirst, List<int> rks) => _rec(0x00BD, <int>[
  ..._u16(row),
  ..._u16(colFirst),
  for (final rk in rks) ...<int>[..._u16(0), ..._u32(rk)],
  ..._u16(colFirst + rks.length - 1),
]);

/// 旧式 LABEL 内联字符串单元格（不走 SST）。压缩模式只能放 Latin-1 字符。
List<int> _label(int row, int col, String text, {bool utf16 = false}) =>
    _rec(0x0204, <int>[
      ..._u16(row),
      ..._u16(col),
      ..._u16(0),
      ..._u16(text.length),
      utf16 ? 0x01 : 0x00,
      if (utf16) ...text.codeUnits.expand(_u16) else ...text.codeUnits,
    ]);

/// 整数编码 RK（bit1=1）：值存高 30 位；[div100] 置 bit0（解码后再除以 100）。
int _rkInt(int value, {bool div100 = false}) =>
    ((value << 2) & 0xFFFFFFFF) | 0x02 | (div100 ? 0x01 : 0x00);

/// 浮点编码 RK（bit1=0）：取 IEEE754 高 32 位、低 2 位清零作标志位。
int _rkDouble(double value, {bool div100 = false}) {
  final bd = ByteData(8)..setFloat64(0, value, Endian.little);
  return (bd.getUint32(4, Endian.little) & 0xFFFFFFFC) | (div100 ? 0x01 : 0x00);
}

/// SST 内单个不跨界字符串体：cch(2) + grbit(1) + 字符。
List<int> _sstString(String text, {bool utf16 = false}) => <int>[
  ..._u16(text.length),
  utf16 ? 0x01 : 0x00,
  if (utf16) ...text.codeUnits.expand(_u16) else ...text.codeUnits,
];

/// 单记录 SST（无 CONTINUE）：total(4) + unique(4) + 字符串体列表。
List<int> _sst(List<List<int>> strings) => _rec(0x00FC, <int>[
  ..._u32(strings.length),
  ..._u32(strings.length),
  for (final s in strings) ...s,
]);

/// 组装最小 Workbook 流：全局子流（可带 SST 记录字节）+ 首个工作表子流。
List<int> _workbook({
  List<int> sstBytes = const <int>[],
  required List<int> sheetCells,
}) => <int>[
  ..._bof(worksheet: false),
  ...sstBytes,
  ..._eof,
  ..._bof(worksheet: true),
  ...sheetCells,
  ..._eof,
];

// ---------------------------------------------------------------------------
// 最小 OLE2 复合文档容器。
// ---------------------------------------------------------------------------

void _writeOle2Header(
  Uint8List bytes,
  ByteData bd, {
  required int miniCutoff,
  required int miniFatStart,
}) {
  bytes.setAll(0, const <int>[0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]);
  bd.setUint16(0x1E, 9, Endian.little); // 512 字节扇区
  bd.setUint16(0x20, 6, Endian.little); // 64 字节迷你扇区
  bd.setUint32(0x30, 1, Endian.little); // 目录从扇区 1 开始
  bd.setUint32(0x38, miniCutoff, Endian.little);
  bd.setUint32(0x3C, miniFatStart, Endian.little);
  bd.setUint32(0x44, 0xFFFFFFFE, Endian.little); // 无 DIFAT 扩展链
  bd.setUint32(0x48, 0, Endian.little);
  bd.setUint32(0x4C, 0, Endian.little); // DIFAT[0]：FAT 在扇区 0
  for (var i = 1; i < 109; i++) {
    bd.setUint32(0x4C + i * 4, 0xFFFFFFFF, Endian.little);
  }
}

void _writeDirEntry(
  ByteData bd,
  int off,
  String name,
  int objType,
  int start,
  int size,
) {
  for (var i = 0; i < name.length; i++) {
    bd.setUint16(off + i * 2, name.codeUnitAt(i), Endian.little);
  }
  bd.setUint16(off + 0x40, (name.length + 1) * 2, Endian.little);
  bd.setUint8(off + 0x42, objType);
  bd.setUint32(off + 0x74, start, Endian.little);
  bd.setUint32(off + 0x78, size, Endian.little);
}

/// 主 FAT 版容器：扇区 0=FAT、1=目录、2..=流本体。miniCutoff 置 0 使任意大小的
/// 流都走主 FAT 链（绕开迷你流），构造成本最低。
Uint8List _wrapOle2(List<int> workbook, {String streamName = 'Workbook'}) {
  const sectorSize = 512;
  final wbSectors = workbook.isEmpty
      ? 1
      : (workbook.length + sectorSize - 1) ~/ sectorSize;
  final bytes = Uint8List(512 + (2 + wbSectors) * sectorSize);
  final bd = ByteData.sublistView(bytes);
  _writeOle2Header(bytes, bd, miniCutoff: 0, miniFatStart: 0xFFFFFFFE);

  int base(int sector) => 512 + sector * sectorSize;

  // FAT（扇区 0）：目录单扇区结束，流扇区顺序成链。
  for (var i = 0; i < sectorSize ~/ 4; i++) {
    bd.setUint32(base(0) + i * 4, 0xFFFFFFFF, Endian.little);
  }
  bd.setUint32(base(0), 0xFFFFFFFD, Endian.little); // FAT 自身
  bd.setUint32(base(0) + 4, 0xFFFFFFFE, Endian.little); // 目录链结束
  for (var i = 0; i < wbSectors; i++) {
    final next = i == wbSectors - 1 ? 0xFFFFFFFE : 3 + i;
    bd.setUint32(base(0) + (2 + i) * 4, next, Endian.little);
  }

  // 目录（扇区 1）：Root Entry + 数据流。
  _writeDirEntry(bd, base(1), 'Root Entry', 5, 0xFFFFFFFE, 0);
  _writeDirEntry(bd, base(1) + 128, streamName, 2, 2, workbook.length);

  bytes.setAll(base(2), workbook);
  return bytes;
}

/// 迷你流版容器：miniCutoff 取标准 4096，流小于它时存进 Root Entry 的迷你流、
/// 经迷你 FAT（64 字节迷你扇区）读取。扇区 0=FAT、1=目录、2=迷你 FAT、3..=迷你流容器。
Uint8List _wrapOle2MiniStream(List<int> workbook) {
  const sectorSize = 512;
  const miniSectorSize = 64;
  assert(workbook.isNotEmpty && workbook.length < 4096);
  final miniCount = (workbook.length + miniSectorSize - 1) ~/ miniSectorSize;
  final containerSize = miniCount * miniSectorSize;
  final containerSectors = (containerSize + sectorSize - 1) ~/ sectorSize;
  final bytes = Uint8List(512 + (3 + containerSectors) * sectorSize);
  final bd = ByteData.sublistView(bytes);
  _writeOle2Header(bytes, bd, miniCutoff: 4096, miniFatStart: 2);

  int base(int sector) => 512 + sector * sectorSize;

  // FAT（扇区 0）：目录、迷你 FAT 各单扇区，容器扇区顺序成链。
  for (var i = 0; i < sectorSize ~/ 4; i++) {
    bd.setUint32(base(0) + i * 4, 0xFFFFFFFF, Endian.little);
  }
  bd.setUint32(base(0), 0xFFFFFFFD, Endian.little);
  bd.setUint32(base(0) + 4, 0xFFFFFFFE, Endian.little); // 目录
  bd.setUint32(base(0) + 8, 0xFFFFFFFE, Endian.little); // 迷你 FAT
  for (var i = 0; i < containerSectors; i++) {
    final next = i == containerSectors - 1 ? 0xFFFFFFFE : 4 + i;
    bd.setUint32(base(0) + (3 + i) * 4, next, Endian.little);
  }

  // 目录（扇区 1）：Root Entry 持迷你流容器（主 FAT 链），Workbook 的 start 是
  // 迷你扇区号。
  _writeDirEntry(bd, base(1), 'Root Entry', 5, 3, containerSize);
  _writeDirEntry(bd, base(1) + 128, 'Workbook', 2, 0, workbook.length);

  // 迷你 FAT（扇区 2）：迷你扇区 0→1→…→END。
  for (var i = 0; i < sectorSize ~/ 4; i++) {
    bd.setUint32(base(2) + i * 4, 0xFFFFFFFF, Endian.little);
  }
  for (var i = 0; i < miniCount; i++) {
    final next = i == miniCount - 1 ? 0xFFFFFFFE : i + 1;
    bd.setUint32(base(2) + i * 4, next, Endian.little);
  }

  bytes.setAll(base(3), workbook);
  return bytes;
}

Uint8List _fixture(String name) =>
    File('test/fixtures/$name').readAsBytesSync();

void main() {
  group('真实一木导出：账单文件（yimu_transactions.xls）', () {
    late List<List<String>> grid;
    setUpAll(() {
      grid = parseXls(_fixture('yimu_transactions.xls'));
    });

    test('行列结构：8 行 × 23 列（每行都补齐到最大列数）', () {
      expect(grid, hasLength(8));
      for (final row in grid) {
        expect(row, hasLength(23));
      }
    });

    test('表头行原样读出', () {
      expect(grid[0], <String>[
        '日期', '收支类型', '金额', '类别', '二级分类', '账户', '账本', '退款', '优惠', '备注',
        '标签', '报销账户', '报销金额', '报销明细', '多币种', '地址', '创建用户', '其他',
        '附件1', '附件2', '附件3', '附件4', '附件5', //
      ]);
    });

    test('数据行单元格值正确（日期为文本、金额带符号）', () {
      expect(grid[1].sublist(0, 7), <String>[
        '2026-07-07 10:32', '支出', '-12', '其他', '慈善捐助', '', '日常账本', //
      ]);
      expect(grid[2].sublist(0, 7), <String>[
        '2026-07-07 10:31', '支出', '-500', '食品餐饮', '饮料酒水', '', '日常账本', //
      ]);
      expect(grid[4].sublist(0, 7), <String>[
        '2026-07-03 10:31', '收入', '200', '收入', '其他', '', '日常账本', //
      ]);
    });

    test('金额列整列读出（数字转文本、整数无尾随 .0）', () {
      expect(grid.skip(1).map((row) => row[2]).toList(), <String>[
        '-12', '-500', '-1000', '200', '-100', '-3', '200', //
      ]);
    });

    test('空单元格补为空串', () {
      expect(grid[1][5], ''); // 账户列为空。
      expect(grid[1].sublist(7), everyElement(''));
    });
  });

  group('真实一木导出：转账文件（yimu_transfers.xls）', () {
    test('整表结构与单元格值', () {
      final grid = parseXls(_fixture('yimu_transfers.xls'));
      expect(grid, <List<String>>[
        <String>[
          '日期', '类型', '转出账户', '转入账户', '金额', '手续费', '备注',
          '附件1', '附件2', '附件3', '附件4', '附件5', //
        ],
        <String>[
          '2026-07-07 11:10', '转账', '微信钱包', '支付宝', '20', '0', '',
          '', '', '', '', '', //
        ],
      ]);
    });
  });

  group('真实一木导出：子分类/标签/备注文件（yimu_subcategory_tags.xls）', () {
    late List<List<String>> grid;
    setUpAll(() {
      grid = parseXls(_fixture('yimu_subcategory_tags.xls'));
    });

    test('9 行 × 23 列，表头含二级分类与标签列', () {
      expect(grid, hasLength(9));
      expect(grid[0][4], '二级分类');
      expect(grid[0][10], '标签');
    });

    test('长中文备注与逗号分隔多标签原样读出', () {
      expect(grid[1][9], '这是备注信息，用户可以设置备注信息');
      expect(grid[1][10], '吃饭, 午饭, 休息, 多标签, 测试, 其他, 好多标签');
      expect(grid[1][3], '其他');
      expect(grid[1][4], '理财支出');
    });

    test('小数金额保留（-8.8），零金额读作 0', () {
      expect(grid[4][2], '-8.8');
      expect(grid[3][2], '0');
      expect(grid[6][2], '0');
    });

    test('收入行与其标签', () {
      expect(grid[5].sublist(0, 5), <String>[
        '2026-07-11 22:56', '收入', '100', '收入', '二手闲置', //
      ]);
      expect(grid[5][10], '标签a');
    });
  });

  group('真实一木导出：退款列文件（yimu_refund.xls）', () {
    late List<List<String>> grid;
    setUpAll(() {
      grid = parseXls(_fixture('yimu_refund.xls'));
    });

    test('退款列（第 8 列）逐行读出', () {
      expect(grid[0][7], '退款');
      expect(grid[3][7], '20'); // 全额退款：净额 0 + 退款 20。
      expect(grid[4][7], '10'); // 部分退款：净额 -5 + 退款 10。
      expect(grid[3][2], '0');
      expect(grid[4][2], '-5');
      expect(grid[3][5], '支付宝');
    });

    test('单元格内容不做修剪（前导空格原样保留）', () {
      expect(grid[2][10], ' 标签a');
    });
  });

  group('合成 BIFF8：SST 字符串与 LABELSST/LABEL', () {
    test('压缩（8 位）与非压缩（UTF-16）字符串', () {
      final wb = _workbook(
        sstBytes: _sst(<List<int>>[
          _sstString('hello'),
          _sstString('你好世界', utf16: true),
        ]),
        sheetCells: <int>[..._labelSst(0, 0, 0), ..._labelSst(0, 1, 1)],
      );
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['hello', '你好世界'],
      ]);
    });

    test('SST 索引越界的 LABELSST 回退为空串', () {
      final wb = _workbook(
        sstBytes: _sst(<List<int>>[_sstString('x')]),
        sheetCells: <int>[..._labelSst(0, 0, 0), ..._labelSst(0, 1, 9)],
      );
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['x', ''],
      ]);
    });

    test('字符数据跨 CONTINUE 记录拆分（边界重取压缩标志）', () {
      // s0 = 'hello world'（压缩）：前 6 个字符在 SST 记录里，后 5 个在 CONTINUE
      // 里（续块首字节是重新给出的 grbit）；s1 = '第二条'（UTF-16）整体在 CONTINUE 里。
      final sstPayload = <int>[
        ..._u32(2),
        ..._u32(2),
        ..._u16(11),
        0x00,
        ...'hello '.codeUnits,
      ];
      final continuePayload = <int>[
        0x00,
        ...'world'.codeUnits,
        ..._sstString('第二条', utf16: true),
      ];
      final wb = _workbook(
        sstBytes: <int>[
          ..._rec(0x00FC, sstPayload),
          ..._rec(0x003C, continuePayload),
        ],
        sheetCells: <int>[..._labelSst(0, 0, 0), ..._labelSst(0, 1, 1)],
      );
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['hello world', '第二条'],
      ]);
    });

    test('跨界时从 8 位切换到 16 位', () {
      // 'AB中文'：SST 记录里是压缩的 'AB'，CONTINUE 的 grbit=0x01 切成 UTF-16。
      final sstPayload = <int>[
        ..._u32(1),
        ..._u32(1),
        ..._u16(4),
        0x00,
        ...'AB'.codeUnits,
      ];
      final continuePayload = <int>[0x01, ...'中文'.codeUnits.expand(_u16)];
      final wb = _workbook(
        sstBytes: <int>[
          ..._rec(0x00FC, sstPayload),
          ..._rec(0x003C, continuePayload),
        ],
        sheetCells: _labelSst(0, 0, 0),
      );
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['AB中文'],
      ]);
    });

    test('跨界时从 16 位切换到 8 位', () {
      final sstPayload = <int>[
        ..._u32(1),
        ..._u32(1),
        ..._u16(4),
        0x01,
        ...'中文'.codeUnits.expand(_u16),
      ];
      final continuePayload = <int>[0x00, ...'AB'.codeUnits];
      final wb = _workbook(
        sstBytes: <int>[
          ..._rec(0x00FC, sstPayload),
          ..._rec(0x003C, continuePayload),
        ],
        sheetCells: _labelSst(0, 0, 0),
      );
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['中文AB'],
      ]);
    });

    test('富文本格式串与扩展数据被跳过、不影响后续字符串', () {
      final sstPayload = <int>[
        ..._u32(3),
        ..._u32(3),
        // s0：富文本（grbit 0x08）：runCount=1，字符 'hi'，随后 4 字节格式串。
        ..._u16(2), 0x08, ..._u16(1), ...'hi'.codeUnits, 0, 0, 0, 0,
        // s1：带扩展数据（grbit 0x04）：extSize=3，字符 'yo'，随后 3 字节扩展。
        ..._u16(2), 0x04, ..._u32(3), ...'yo'.codeUnits, 9, 9, 9,
        // s2：普通字符串（若前两者未按声明长度跳过，这里就会串位）。
        ..._sstString('ok'),
      ];
      final wb = _workbook(
        sstBytes: _rec(0x00FC, sstPayload),
        sheetCells: <int>[
          ..._labelSst(0, 0, 0),
          ..._labelSst(0, 1, 1),
          ..._labelSst(0, 2, 2),
        ],
      );
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['hi', 'yo', 'ok'],
      ]);
    });

    test('旧式 LABEL 内联字符串（压缩与 UTF-16，无 SST）', () {
      final wb = _workbook(
        sheetCells: <int>[
          ..._label(0, 0, 'inline'),
          ..._label(0, 1, '内联', utf16: true),
        ],
      );
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['inline', '内联'],
      ]);
    });
  });

  group('合成 BIFF8：数值记录（NUMBER/RK/MULRK）', () {
    test('NUMBER：小数保留、整数去掉尾随 .0', () {
      final wb = _workbook(
        sheetCells: <int>[
          ..._number(0, 0, 2.5),
          ..._number(0, 1, 123.0),
          ..._number(0, 2, -7.0),
        ],
      );
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['2.5', '123', '-7'],
      ]);
    });

    test('RK 四种编码：整数/负整数/整数×100 标志/IEEE/IEEE×100 标志', () {
      final wb = _workbook(
        sheetCells: <int>[
          ..._rkCell(0, 0, _rkInt(123)),
          ..._rkCell(0, 1, _rkInt(-5)),
          ..._rkCell(0, 2, _rkInt(12345, div100: true)),
          ..._rkCell(0, 3, _rkDouble(1.5)),
          ..._rkCell(0, 4, _rkDouble(314.0, div100: true)),
          ..._rkCell(0, 5, _rkDouble(-2.5)),
        ],
      );
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['123', '-5', '123.45', '1.5', '3.14', '-2.5'],
      ]);
    });

    test('MULRK：一条记录展开成一行多个单元格（混用两种编码）', () {
      final wb = _workbook(
        sheetCells: _mulRk(1, 1, <int>[
          _rkInt(1),
          _rkInt(250, div100: true),
          _rkDouble(-2.5),
        ]),
      );
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['', '', '', ''],
        <String>['', '1', '2.5', '-2.5'],
      ]);
    });

    test('NaN 与无穷大渲染为空串', () {
      final wb = _workbook(
        sheetCells: <int>[
          ..._number(0, 0, double.nan),
          ..._number(0, 1, double.infinity),
        ],
      );
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['', ''],
      ]);
    });
  });

  group('合成 BIFF8：工作表结构与容器变体', () {
    test('稀疏网格按最大行列补齐空串', () {
      final wb = _workbook(sheetCells: _rkCell(2, 3, _rkInt(7)));
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['', '', '', ''],
        <String>['', '', '', ''],
        <String>['', '', '', '7'],
      ]);
    });

    test('只读首个工作表，后续工作表忽略', () {
      final wb = <int>[
        ..._bof(worksheet: false),
        ..._eof,
        ..._bof(worksheet: true),
        ..._rkCell(0, 0, _rkInt(1)),
        ..._eof,
        ..._bof(worksheet: true),
        ..._rkCell(0, 0, _rkInt(2)),
        ..._eof,
      ];
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['1'],
      ]);
    });

    test('无单元格的工作表返回空表', () {
      final wb = _workbook(sheetCells: const <int>[]);
      expect(parseXls(_wrapOle2(wb)), isEmpty);
    });

    test('流名为 Book（旧版 Excel）同样识别', () {
      final wb = _workbook(sheetCells: _rkCell(0, 0, _rkInt(42)));
      expect(parseXls(_wrapOle2(wb, streamName: 'Book')), <List<String>>[
        <String>['42'],
      ]);
    });

    test('尾部残缺记录（声明长度越界）被忽略', () {
      final wb = <int>[
        ..._workbook(sheetCells: _rkCell(0, 0, _rkInt(1))),
        0x34, 0x12, 0xFF, 0xFF, // 类型 0x1234、声明 65535 字节但没有数据。
      ];
      expect(parseXls(_wrapOle2(wb)), <List<String>>[
        <String>['1'],
      ]);
    });

    test('小于 miniCutoff 的 Workbook 流经迷你 FAT/迷你流读取', () {
      final wb = _workbook(
        sheetCells: <int>[
          for (var c = 0; c < 5; c++) ..._rkCell(0, c, _rkInt(c + 1)),
        ],
      );
      // 流长 > 64（跨多个迷你扇区）且 < 4096（必须走迷你流分支）。
      expect(wb.length, greaterThan(64));
      expect(wb.length, lessThan(4096));
      expect(parseXls(_wrapOle2MiniStream(wb)), <List<String>>[
        <String>['1', '2', '3', '4', '5'],
      ]);
    });
  });

  group('错误路径', () {
    test('不足 512 字节报 OLE2 文件头错误', () {
      expect(
        () => parseXls(Uint8List(100)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('OLE2'),
          ),
        ),
      );
    });

    test('魔数不对报 OLE2 文件头错误', () {
      expect(
        () => parseXls(Uint8List.fromList(List<int>.filled(600, 0x41))),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('OLE2'),
          ),
        ),
      );
    });

    test('扇区大小异常报错', () {
      final bytes = Uint8List(512);
      bytes.setAll(0, const <int>[0xD0, 0xCF, 0x11, 0xE0]);
      bytes[0x1E] = 17; // 1 << 17 = 128KB，超出合法扇区大小。
      expect(
        () => parseXls(bytes),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('扇区'),
          ),
        ),
      );
    });

    test('缺少 Workbook/Book 数据流报错', () {
      final wb = _workbook(sheetCells: _rkCell(0, 0, _rkInt(1)));
      expect(
        () => parseXls(_wrapOle2(wb, streamName: 'NotABook')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Workbook'),
          ),
        ),
      );
    });

    test('截断的真实文件（仅剩文件头）报 FormatException 而非崩溃', () {
      final full = _fixture('yimu_transactions.xls');
      final truncated = Uint8List.sublistView(full, 0, 1024);
      expect(() => parseXls(truncated), throwsFormatException);
    });
  });
}
