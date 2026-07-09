import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';

import '../ledger_math.dart';
import '../models.dart';
import 'transaction_import.dart';
import 'xls_reader.dart';

/// 支付平台 / 记账软件账单来源。用户在导入前显式选择，避免仅靠表头猜测出错。
///
/// 每种来源的表头与字段解析都基于用户提供的**真实导出样例**：
/// - [alipay] 支付宝「交易明细」CSV：GBK 编码、前置多行说明、含「不计收支」。
/// - [wechat] 微信「支付账单」xlsx：二进制表格、日期为 Excel 序列号、含「中性交易」。
/// - [mint] 薄荷记账 CSV：UTF-16LE 编码、**制表符分隔**、支出金额为负。
/// - [yimuBill] / [yimuTransfer] 一木记账 xls：老式 BIFF8 二进制 Excel。一木把
///   「账单导出（收支）」与「转账还款导出」做成两个不同表头的文件，且还有其他导出，
///   故拆成两个入口由用户显式选择、各认自己的表头（选错即报错，绝不猜测）。
/// - [tally] Tally 记账「备份」导出：zip 内含 `backup_data.json`（Gson 全量数据）。
///   相较其 CSV「账单」导出无损——交易时间精确到毫秒（epoch），故导 zip 而非 CSV。
///   转账（type=2、category「资产互转」）的转出/转入账户编码在 note（"转出 -> 转入"）里。
/// - [genericCsv] 通用 CSV（Veri Fin 模板 / 钱迹 / 随手记）：UTF-8 逗号分隔，走别名识别。
enum ImportPlatform {
  alipay,
  wechat,
  mint,
  yimuBill,
  yimuTransfer,
  tally,
  genericCsv;

  /// 该来源可选择的文件扩展名（用于文件选择器过滤）。
  List<String> get fileExtensions => switch (this) {
    ImportPlatform.wechat => const <String>['xlsx'],
    ImportPlatform.yimuBill => const <String>['xls'],
    ImportPlatform.yimuTransfer => const <String>['xls'],
    ImportPlatform.tally => const <String>['zip'],
    _ => const <String>['csv', 'txt'],
  };
}

/// Veri Fin 规范列头：各平台归一化后统一转成这套列，再复用 [buildImportPlan]。
/// 「手续费」仅转账用（一木转账带此列），其他来源数据行不含该列、按 0 处理。
const List<String> _canonicalHeader = <String>[
  '日期',
  '类型',
  '金额',
  '分类',
  '账户',
  '转入账户',
  '备注',
  '手续费',
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
  // Tally 备份携带账户余额与类型，走专用路径：先归一化交易，再用 assets 修正账户
  // 初始余额、补建无流水的账户（见 [_applyTallyAssets]）。
  if (platform == ImportPlatform.tally) {
    final backup = _parseTallyBackup(bytes);
    final plan = buildImportPlan(
      rows: backup.rows,
      bookId: bookId,
      existingAccounts: existingAccounts,
      existingCategories: existingCategories,
      now: now,
    );
    return _applyTallyAssets(
      plan: plan,
      assets: backup.assets,
      existingAccounts: existingAccounts,
      bookId: bookId,
      now: now,
    );
  }

  final rows = switch (platform) {
    ImportPlatform.alipay => _normalizeAlipay(_decodeGbk(bytes)),
    ImportPlatform.wechat => _normalizeWechat(parseXlsx(bytes)),
    ImportPlatform.mint => _normalizeMint(_decodeUtf16(bytes)),
    ImportPlatform.yimuBill => _normalizeYimuBill(parseXls(bytes)),
    ImportPlatform.yimuTransfer => _normalizeYimuTransfer(parseXls(bytes)),
    ImportPlatform.tally => const <List<String>>[],
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
// 一木记账「账单导出」：日期/收支类型/金额(带符号)/类别/二级分类/账户。金额符号仅表
// 方向（管线取绝对值），分类取二级分类（用户实际选择的叶子）、为空回退一级类别。
// 只认账单表头，选错文件（如转账/其他导出）即报错，不做跨类型猜测。
// ---------------------------------------------------------------------------

List<List<String>> _normalizeYimuBill(List<List<String>> rows) {
  final headerIndex = _findHeaderRow(
    rows,
    mustHave: const <String>['日期', '收支类型', '金额'],
  );
  if (headerIndex == null) {
    throw const FormatException('未找到一木「账单导出」表头（日期/收支类型/金额），请确认选择的是一木账单导出的 xls');
  }
  final cols = _columnIndex(rows[headerIndex]);
  final out = <List<String>>[_canonicalHeader];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    final type = _at(row, cols['收支类型']).trim();
    if (type != '支出' && type != '收入') {
      continue;
    }
    final level1 = _at(row, cols['类别']);
    final level2 = _at(row, cols['二级分类']);
    final category = level2.isNotEmpty ? level2 : level1;
    out.add(<String>[
      _at(row, cols['日期']),
      type,
      _at(row, cols['金额']),
      category,
      _at(row, cols['账户']),
      '',
      _at(row, cols['备注']),
    ]);
  }
  return out;
}

// ---------------------------------------------------------------------------
// 一木记账「转账还款导出」：日期/类型/转出账户/转入账户/金额/手续费/备注。含手续费，
// 映射到转账 fee。只认转账表头，选错文件即报错。
// ---------------------------------------------------------------------------

List<List<String>> _normalizeYimuTransfer(List<List<String>> rows) {
  final headerIndex = _findHeaderRow(
    rows,
    mustHave: const <String>['转出账户', '转入账户', '金额'],
  );
  if (headerIndex == null) {
    throw const FormatException(
      '未找到一木「转账还款导出」表头（转出账户/转入账户/金额），请确认选择的是一木转账还款导出的 xls',
    );
  }
  final cols = _columnIndex(rows[headerIndex]);
  final out = <List<String>>[_canonicalHeader];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    final from = _at(row, cols['转出账户']);
    final to = _at(row, cols['转入账户']);
    if (from.isEmpty && to.isEmpty) {
      continue;
    }
    out.add(<String>[
      _at(row, cols['日期']),
      '转账',
      _at(row, cols['金额']),
      '',
      from,
      to,
      _at(row, cols['备注']),
      _at(row, cols['手续费']),
    ]);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Tally 记账「备份」：zip 内含 backup_data.json（Gson 全量数据）。取 records 数组
// 逐条归一：date(epoch 毫秒)→本地时间字符串、type(0支出/1收入/2转账)、金额取绝对值、
// 分类取二级分类（叶子）为空回退一级、assetId 经 assets 数组映射为账户名。转账的两个
// 账户名编码在 note（"转出 -> 转入" 可能带 " (账单:X 优惠:Y)" 与 " | 备注: 用户备注"）。
// ---------------------------------------------------------------------------

/// Tally 资产账户：名称、（按 Veri Fin 符号约定的）当前余额、是否计入总资产、账户类型。
class _TallyAsset {
  const _TallyAsset({
    required this.name,
    required this.signedBalance,
    required this.includeInAssets,
    required this.type,
  });

  final String name;

  /// 已按符号归一：资产/借出/理财记正，负债/分期记负（与 Veri Fin「余额正负=资产/负债」一致）。
  final double signedBalance;
  final bool includeInAssets;
  final AccountType type;
}

/// Tally 备份解析结果：归一化后的交易行 + 资产账户元数据。
class _TallyBackup {
  const _TallyBackup(this.rows, this.assets);

  final List<List<String>> rows;
  final List<_TallyAsset> assets;
}

/// 把 Tally 的资产类型（0资产/1负债/2借出/3理财/4分期）映射到 Veri Fin 账户类型。
/// Veri Fin 无「负债/借出」独立类型（靠余额正负区分），故负债/分期只影响余额符号，
/// 类型上把理财归为 investment，其余用 cash（与 CSV 导入默认一致）。
AccountType _tallyAccountType(int type) =>
    type == 3 ? AccountType.investment : AccountType.cash;

_TallyBackup _parseTallyBackup(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('无法读取 Tally 备份（可能不是有效的 zip 文件）');
  }
  String? jsonText;
  for (final file in archive.files) {
    if (file.isFile &&
        (file.name == 'backup_data.json' ||
            file.name.endsWith('/backup_data.json'))) {
      jsonText = utf8.decode(file.content as List<int>);
      break;
    }
  }
  if (jsonText == null) {
    throw const FormatException(
      '未找到 Tally 备份数据 backup_data.json，请确认选择的是 Tally 导出的备份 zip',
    );
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } catch (_) {
    throw const FormatException('Tally 备份数据格式无效（JSON 解析失败）');
  }
  if (decoded is! Map) {
    throw const FormatException('Tally 备份数据格式无效');
  }

  // 资产 id → 名称（供交易账户解析），以及资产账户元数据（供余额/类型导入）。
  final assetNames = <int, String>{};
  final tallyAssets = <_TallyAsset>[];
  final assets = decoded['assets'];
  if (assets is List) {
    for (final asset in assets) {
      if (asset is! Map) {
        continue;
      }
      final id = (asset['id'] as num?)?.toInt();
      final name = asset['name']?.toString().trim() ?? '';
      if (id != null && name.isNotEmpty) {
        assetNames[id] = name;
      }
      if (name.isEmpty) {
        continue;
      }
      final rawType = (asset['type'] as num?)?.toInt() ?? 0;
      final amount = (asset['amount'] as num?)?.toDouble() ?? 0;
      // Tally 里 amount 恒为正，符号由 type 决定：负债(1)/分期(4)减少总资产、记负；
      // 资产(0)/借出(2)/理财(3)记正。isIncludedInTotal 缺省视为 true（兼容老数据）。
      final signed = (rawType == 1 || rawType == 4) ? -amount.abs() : amount.abs();
      final included = asset['isIncludedInTotal'] as bool? ?? true;
      tallyAssets.add(
        _TallyAsset(
          name: name,
          signedBalance: signed,
          includeInAssets: included,
          type: _tallyAccountType(rawType),
        ),
      );
    }
  }

  // records 可缺省 / 为空：允许「只有账户、没有流水」的备份也能导入账户余额。
  // 但一个既无 assets 又无 records 的文件基本不是 Tally 备份，视为格式错误。
  final records = decoded['records'];
  if (records is! List) {
    if (tallyAssets.isEmpty) {
      throw const FormatException('Tally 备份不含交易记录（records）');
    }
    return _TallyBackup(<List<String>>[_canonicalHeader], tallyAssets);
  }

  final out = <List<String>>[_canonicalHeader];
  for (final record in records) {
    if (record is! Map) {
      continue;
    }
    final millis = (record['date'] as num?)?.toInt();
    final amount = ((record['amount'] as num?)?.toDouble() ?? 0).abs();
    if (millis == null || amount == 0) {
      continue;
    }
    final type = (record['type'] as num?)?.toInt() ?? 0;
    final dateStr = _tallyMillisToDate(millis);
    final amountStr = _formatTallyAmount(amount);
    final assetId = (record['assetId'] as num?)?.toInt() ?? 0;
    final accountName = assetNames[assetId] ?? '';
    final noteRaw = record['note']?.toString().trim() ?? '';
    final remark = record['remark']?.toString().trim() ?? '';

    if (type == 2) {
      // 转账：从 note 拆出转出/转入账户；转出为空时回退到 assetId 对应账户。
      final transfer = _parseTallyTransferNote(noteRaw);
      final from = transfer.from.isNotEmpty ? transfer.from : accountName;
      out.add(<String>[
        dateStr,
        '转账',
        amountStr,
        '',
        from,
        transfer.to,
        transfer.note,
      ]);
      continue;
    }

    final level1 = record['category']?.toString().trim() ?? '';
    final level2 = record['subCategory']?.toString().trim() ?? '';
    final category = level2.isNotEmpty ? level2 : level1;
    out.add(<String>[
      dateStr,
      type == 1 ? '收入' : '支出',
      amountStr,
      category,
      accountName,
      '',
      _joinNote(<String>[noteRaw, remark]),
    ]);
  }
  return _TallyBackup(out, tallyAssets);
}

/// 用 Tally 资产账户元数据修正导入计划：让每个源账户导入后的**显示余额**等于 Tally
/// 存的当前余额，并补建没有流水的账户（如零余额钱包、借出/负债对象）。
///
/// Veri Fin 账户显示余额 = `initialBalance + Σ 交易增量`，故对**本次导入新建**的账户回推
/// `initialBalance = 目标余额 − Σ增量`；没有任何交易引用的资产则直接以目标余额新建，
/// 并加入 [ImportPlan.standaloneAccountIds] 使其即便无流水也会落库。已存在的同名账户
/// 不改动（避免覆盖用户既有数据）。
ImportPlan _applyTallyAssets({
  required ImportPlan plan,
  required List<_TallyAsset> assets,
  required List<Account> existingAccounts,
  required String bookId,
  required DateTime now,
}) {
  if (assets.isEmpty) {
    return plan;
  }

  // 各账户在本次导入交易中的余额增量合计（按最终账户 id 聚合）。
  final deltaByAccount = <String, double>{};
  for (final entry in plan.entries) {
    for (final id in <String?>[entry.accountId, entry.toAccountId]) {
      if (id != null && id.isNotEmpty) {
        deltaByAccount[id] =
            (deltaByAccount[id] ?? 0) + accountDeltaForEntry(entry, id);
      }
    }
  }

  final newAccounts = List<Account>.from(plan.newAccounts);
  final standalone = <String>{...plan.standaloneAccountIds};
  var counter = 0;

  for (final asset in assets) {
    final newIndex = newAccounts.indexWhere((a) => a.name == asset.name);
    if (newIndex != -1) {
      // 本次导入新建的账户：回推初始余额，使显示余额对齐 Tally；标记为独立账户。
      final account = newAccounts[newIndex];
      final delta = deltaByAccount[account.id] ?? 0;
      newAccounts[newIndex] = account.copyWith(
        initialBalance: asset.signedBalance - delta,
        includeInAssets: asset.includeInAssets,
        type: asset.type,
      );
      standalone.add(account.id);
      continue;
    }
    // 已存在的同名账户：不改动（尊重用户既有数据）。
    if (existingAccounts.any((a) => a.name == asset.name)) {
      continue;
    }
    // 没有任何流水的资产（零余额钱包、借出/负债对象等）：直接以当前余额新建。
    counter++;
    final id = 'tallyacct_${now.microsecondsSinceEpoch}_$counter';
    newAccounts.add(
      Account(
        id: id,
        bookId: bookId,
        name: asset.name,
        type: asset.type,
        groupId: null,
        initialBalance: asset.signedBalance,
        iconCode: 'wallet',
        note: '',
        includeInAssets: asset.includeInAssets,
        hidden: false,
      ),
    );
    standalone.add(id);
  }

  return ImportPlan(
    entries: plan.entries,
    newAccounts: newAccounts,
    newCategories: plan.newCategories,
    errors: plan.errors,
    source: plan.source,
    standaloneAccountIds: standalone,
  );
}

/// Tally 转账 note 拆解结果：转出账户、转入账户、剩余用户备注。
class _TallyTransfer {
  const _TallyTransfer(this.from, this.to, this.note);

  final String from;
  final String to;
  final String note;
}

/// 解析 Tally 转账 note："转出 -> 转入" 可能尾随 " (账单:X 优惠:Y)" 与 " | 备注: 备注"。
/// 只剥离带明确关键字的优惠/账单尾注与用户备注，不动账户名内部的括号（如「招商(0966)」），
/// 宁可保留货币模式下的 "(¥100.00)" 由用户在预览里改，也不误删真实账户名的括号。
_TallyTransfer _parseTallyTransferNote(String raw) {
  var base = raw;
  var userNote = '';
  const marker = ' | 备注: ';
  final markerIndex = base.indexOf(marker);
  if (markerIndex >= 0) {
    userNote = base.substring(markerIndex + marker.length).trim();
    base = base.substring(0, markerIndex);
  }
  base = base
      .replaceAll(RegExp(r'\s*\((?:账单|优惠)[^)]*\)\s*$'), '')
      .trim();
  final arrow = base.indexOf(' -> ');
  if (arrow < 0) {
    return _TallyTransfer('', '', userNote.isEmpty ? base.trim() : userNote);
  }
  return _TallyTransfer(
    base.substring(0, arrow).trim(),
    base.substring(arrow + 4).trim(),
    userNote,
  );
}

/// epoch 毫秒 → 本地 "YYYY-MM-DD HH:MM:SS"（Tally 按本地时间生成时间戳）。
String _tallyMillisToDate(int millis) {
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
}

/// 金额格式化：整数值去掉小数尾巴（100.0→100），否则原样，交给管线再校验。
String _formatTallyAmount(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
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
