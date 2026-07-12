import 'dart:typed_data';

import '../models.dart';
import 'import/alipay.dart';
import 'import/csv_template.dart';
import 'import/mint.dart';
import 'import/plan_builder.dart';
import 'import/qianji.dart';
import 'import/raw_import.dart';
import 'import/tally.dart';
import 'import/wechat.dart';
import 'import/yimu.dart';

export 'import/plan_builder.dart' show ImportPlan;
export 'import/raw_import.dart' show ImportRowError;

/// 支付平台 / 记账软件账单来源。用户在导入前显式选择，避免仅靠表头猜测出错。
///
/// **解耦约定**：每个来源有自己的 parser（`import/<来源>.dart`，`Uint8List → ParsedImport`），
/// 各认自己的格式、互不共用表头识别；账户/分类/标签解析等通用领域逻辑统一在
/// [buildImportPlanFromRecords]（唯一一份、不复制）。**新增导入平台 = 写个 parser 文件 +
/// 在 [parsePlatformBytes] 注册一行**。各解析均基于用户真实导出样例，禁止编造格式。
enum ImportPlatform {
  alipay,
  wechat,
  mint,
  yimuBill,
  yimuTransfer,
  qianji,
  tally,
  csvTemplate;

  /// 该来源可选择的文件扩展名（用于文件选择器过滤）。
  List<String> get fileExtensions => switch (this) {
    ImportPlatform.wechat => const <String>['xlsx'],
    ImportPlatform.yimuBill => const <String>['xls'],
    ImportPlatform.yimuTransfer => const <String>['xls'],
    ImportPlatform.tally => const <String>['zip'],
    _ => const <String>['csv', 'txt'],
  };
}

/// 来源注册表：把所选平台的账单字节交给对应 parser，得到强类型 [ParsedImport]。
ParsedImport parsePlatformBytes(ImportPlatform platform, Uint8List bytes) =>
    switch (platform) {
      ImportPlatform.alipay => parseAlipay(bytes),
      ImportPlatform.wechat => parseWechat(bytes),
      ImportPlatform.mint => parseMint(bytes),
      ImportPlatform.yimuBill => parseYimuBill(bytes),
      ImportPlatform.yimuTransfer => parseYimuTransfer(bytes),
      ImportPlatform.qianji => parseQianji(bytes),
      ImportPlatform.tally => parseTally(bytes),
      ImportPlatform.csvTemplate => parseCsvTemplate(bytes),
    };

/// 解析所选平台的账单文件字节，构建导入计划：先经 [parsePlatformBytes] 得到强类型记录，
/// 再交给共享的 [buildImportPlanFromRecords] 统一建账户/分类/标签、生成交易与逐行错误。
/// 解析不出有效数据时由各 parser 抛 [FormatException]。
///
/// **不按现有标签去重**：账单里的标签一律当作「待新建候选」（`plan.newTags`），是否复用
/// 现有同名标签交由导入预览页映射、并由 `applyImportEntries` 按 id 过滤——保持预览流程能
/// 展示并映射每个标签。故这里不接收 existingTags。
ImportPlan buildPlatformImportPlan({
  required ImportPlatform platform,
  required Uint8List bytes,
  required String bookId,
  required List<Account> existingAccounts,
  required List<Category> existingCategories,
  required DateTime now,
}) {
  return buildImportPlanFromRecords(
    parsed: parsePlatformBytes(platform, bytes),
    bookId: bookId,
    existingAccounts: existingAccounts,
    existingCategories: existingCategories,
    now: now,
  );
}
