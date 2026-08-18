import '../models.dart';
import 'import/csv_template.dart';
import 'import/plan_builder.dart';

// 导入子系统的公共 facade（历史入口，外部只 import 本文件与 payment_import.dart）：
// 类型与实现拆在 import/ 子目录，这里统一 re-export，并保留 CSV 行→计划的兼容入口。
export 'import/csv_template.dart'
    show
        csvTemplateColumns,
        transactionCsvTemplate,
        transactionCsvExport,
        transactionCsvExportColumns,
        validateCsvTemplateHeader;
export 'import/plan_builder.dart'
    show ImportConversionIssue, ImportExchangeRateCandidate, ImportPlan;
export 'import/raw_import.dart' show ImportRowError;
export 'import/text_format.dart' show parseCsv;

/// 兼容入口：由已分词的 CSV 行（首行为表头）构建导入计划。内部走「CSV 模板」记录解析
/// （[parseCsvTemplateRows]）+ 共享 [buildImportPlanFromRecords]。缺必需列抛
/// [FormatException]。**不做**「CSV 模板」入口的白名单表头校验——那只属于用户文件导入路径
/// （见 [validateCsvTemplateHeader]）。
ImportPlan buildImportPlan({
  required List<List<String>> rows,
  required String bookId,
  required List<Account> existingAccounts,
  required List<Category> existingCategories,
  required DateTime now,
  String baseCurrencyCode = defaultCurrencyCode,
  List<ExchangeRate> exchangeRates = const <ExchangeRate>[],
  List<Tag> existingTags = const <Tag>[],
  bool seedEnglish = false,
}) {
  return buildImportPlanFromRecords(
    parsed: parseCsvTemplateRows(rows),
    bookId: bookId,
    existingAccounts: existingAccounts,
    existingCategories: existingCategories,
    now: now,
    baseCurrencyCode: baseCurrencyCode,
    exchangeRates: exchangeRates,
    existingTags: existingTags,
    seedEnglish: seedEnglish,
  );
}
