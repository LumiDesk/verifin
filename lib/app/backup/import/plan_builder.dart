import '../../category_tree.dart';
import '../../currency_catalog.dart';
import '../../currency_math.dart';
import '../../ledger_math.dart';
import '../../models.dart';
import 'raw_import.dart';

/// 导入计划：待新增的交易，以及为匹配名称需要新建的账户/分类/标签，和逐行错误。
class ImportPlan {
  const ImportPlan({
    required this.entries,
    required this.newAccounts,
    required this.newCategories,
    required this.errors,
    this.newTags = const <Tag>[],
    this.standaloneAccountIds = const <String>{},
    this.conversionIssues = const <ImportConversionIssue>[],
    this.exchangeRateCandidates = const <ImportExchangeRateCandidate>[],
  });

  final List<LedgerEntry> entries;
  final List<Account> newAccounts;
  final List<Category> newCategories;

  /// 为匹配交易里的标签名需要新建的标签（去重后）。标签全局共享、不分账本。
  final List<Tag> newTags;
  final List<ImportRowError> errors;
  final List<ImportConversionIssue> conversionIssues;
  final List<ImportExchangeRateCandidate> exchangeRateCandidates;

  /// 待新建账户中「即使没有交易引用也要创建」的 id 集合。默认空——普通导入的账户都由
  /// 交易派生、被排除后不应留下空账户；仅 Tally 这类携带账户余额/类型的来源，会把源账本
  /// 里的资产账户（含零余额、无流水的账户）标记为独立账户一并落库。
  final Set<String> standaloneAccountIds;

  /// 用户在预览页看到并确认的根交易数；关联退款随原支出一起导入，不单独计数。
  int get importedCount =>
      entries.where((entry) => entry.type != EntryType.refund).length;
  int get errorCount => errors.length + conversionIssues.length;
  bool get isEmpty =>
      entries.isEmpty && errors.isEmpty && conversionIssues.isEmpty;
}

class ImportExchangeRateCandidate {
  const ImportExchangeRateCandidate({
    required this.rate,
    required this.entryIds,
  });

  final ExchangeRate rate;
  final Set<String> entryIds;
}

class ImportConversionIssue {
  const ImportConversionIssue({
    required this.line,
    required this.currencyCode,
    required this.message,
    required this.record,
  });

  final int line;
  final String currencyCode;
  final String message;
  final RawImportRecord record;
}

/// 所有来源的**唯一共享落库计划生成器**：把各平台 parser 产出的强类型 [ParsedImport]
/// 变成 [ImportPlan]——按名建/复用账户、还原分类父子层级、标签去重、构造 [LedgerEntry]，
/// 并把 parser 收集的逐行错误透传。缺失分类的收支记录兜底到固定 id 的「未分类」
/// （[seedEnglish] 决定其文案语言，与种子数据同规则），绝不落空 categoryId。
/// 纯函数：不修改传入集合，id 由 [now] 与记录序派生（保证同输入可复现）。
///
/// 「不同软件解析逻辑各自独立」的边界只到 parser 为止——账户/分类/标签解析是通用领域
/// 逻辑，只应有这一份实现（复制成每平台一份必然漂移、是 bug 温床）。
ImportPlan buildImportPlanFromRecords({
  required ParsedImport parsed,
  required String bookId,
  required List<Account> existingAccounts,
  required List<Category> existingCategories,
  required DateTime now,
  String baseCurrencyCode = defaultCurrencyCode,
  List<ExchangeRate> exchangeRates = const <ExchangeRate>[],
  List<Tag> existingTags = const <Tag>[],
  bool seedEnglish = false,
}) {
  final workingCategories = List<Category>.from(existingCategories);
  final workingTags = List<Tag>.from(existingTags);
  final newAccounts = <Account>[];
  final newCategories = <Category>[];
  final newTags = <Tag>[];
  final entries = <LedgerEntry>[];
  final errors = <ImportRowError>[...parsed.errors];
  final conversionIssues = <ImportConversionIssue>[];
  var idCounter = 0;

  String nextId(String prefix) {
    idCounter++;
    return '${prefix}_${now.microsecondsSinceEpoch}_$idCounter';
  }

  // 本次导入按「去空格名 + 币种」新建账户候选；同名不同币种不得误合并。
  final accountCandidateIds = <String, String>{};

  // 解析/新建单个账户。[name] 须已去首尾空格且非空。账户名不唯一（id 才是身份），
  // 按名匹配只在**恰好一个**现有账户同名时复用；多个同名时不猜归属，转为待新建
  // 候选进预览页「导入账户」映射区，由用户显式映射到目标账户或保留新建。
  String resolveAccount(
    String name,
    String currencyCode, {
    bool allowUniqueOtherCurrency = false,
  }) {
    final key = '$currencyCode\u0000$name';
    final candidateId = accountCandidateIds[key];
    if (candidateId != null) {
      return candidateId;
    }
    final matches = existingAccounts
        .where(
          (account) =>
              account.name.trim() == name &&
              account.currencyCode == currencyCode,
        )
        .toList();
    if (matches.length == 1) {
      return matches.single.id;
    }
    if (matches.isEmpty && allowUniqueOtherCurrency) {
      final sameName = existingAccounts
          .where((account) => account.name.trim() == name)
          .toList();
      if (sameName.length == 1) {
        return sameName.single.id;
      }
    }
    final account = Account(
      id: nextId('account'),
      bookId: bookId,
      name: name,
      type: AccountType.cash,
      groupId: null,
      initialBalance: 0,
      iconCode: 'wallet',
      note: '',
      includeInAssets: true,
      hidden: false,
      currencyCode: currencyCode,
    );
    newAccounts.add(account);
    accountCandidateIds[key] = account.id;
    return account.id;
  }

  Account? accountByResolvedId(String id) {
    for (final account in <Account>[...existingAccounts, ...newAccounts]) {
      if (account.id == id) return account;
    }
    return null;
  }

  // 空分类名兜底：解析到固定 id 的「未分类」（与载入自愈同一约定，见
  // [uncategorizedCategoryId]）。绝不落空 categoryId——空 id 会被展示层回退成
  // 「已删除分类」占位、且无法筛选与批量处理（issue #16，微信账单曾全量中招）。
  // 「未分类」作为待新建候选进预览页映射区，用户可整体映射到具体分类或保留。
  String resolveUncategorized(EntryType type) {
    final id = uncategorizedCategoryId(type);
    if (workingCategories.any((category) => category.id == id)) {
      return id;
    }
    final seed = buildUncategorizedCategory(type, english: seedEnglish);
    // 用户手建过同名顶级分类（id 不同）时直接复用，避免建出与唯一索引
    // (label,type,IFNULL(parent_id,'')) 冲突的重复同名分类。
    final normalized = normalizedCategoryLabel(seed.label);
    final byLabel = workingCategories.firstWhere(
      (category) =>
          category.type == type &&
          category.parentId == null &&
          normalizedCategoryLabel(category.label) == normalized,
      orElse: () => const Category(
        id: '',
        label: '',
        type: EntryType.expense,
        iconCode: '',
      ),
    );
    if (byLabel.id.isNotEmpty) {
      return byLabel.id;
    }
    workingCategories.add(seed);
    newCategories.add(seed);
    return seed.id;
  }

  // 解析/新建单个分类；[parentId] 限定层级（顶级传 null）。名称按归一化比较（容忍
  // 大小写/首尾空白/全半角差异），且**同一父级下**同名才复用——顶级与子级同名互不误合，
  // 与唯一索引 (label,type,IFNULL(parent_id,'')) 对齐。空名兜底到「未分类」。
  String resolveCategory(String name, EntryType type, {String? parentId}) {
    if (name.isEmpty) {
      return resolveUncategorized(type);
    }
    final normalized = normalizedCategoryLabel(name);
    final match = workingCategories.firstWhere(
      (category) =>
          category.type == type &&
          category.parentId == parentId &&
          normalizedCategoryLabel(category.label) == normalized,
      orElse: () => const Category(
        id: '',
        label: '',
        type: EntryType.expense,
        iconCode: '',
      ),
    );
    if (match.id.isNotEmpty) {
      return match.id;
    }
    final category = Category(
      id: nextId('category'),
      label: name,
      type: type,
      iconCode: 'category',
      parentId: parentId,
    );
    workingCategories.add(category);
    newCategories.add(category);
    return category.id;
  }

  // 解析分类层级：一级 [parentLabel] + 二级 [subLabel]。两者都在时建/复用「父 → 子」
  // 层级、返回子分类 id；只有一个时按顶级分类处理。
  String resolveCategoryHierarchy(
    String parentLabel,
    String subLabel,
    EntryType type,
  ) {
    if (subLabel.isEmpty) {
      return resolveCategory(parentLabel, type);
    }
    if (parentLabel.isEmpty) {
      return resolveCategory(subLabel, type);
    }
    final parentId = resolveCategory(parentLabel, type);
    return resolveCategory(subLabel, type, parentId: parentId);
  }

  // 解析标签名列表：按归一化名去空去重，复用现有同名标签、否则新建，返回标签 id 列表。
  List<String> resolveTags(List<String> labels) {
    if (labels.isEmpty) {
      return const <String>[];
    }
    final ids = <String>[];
    final seen = <String>{};
    for (final label in labels) {
      if (label.isEmpty) {
        continue;
      }
      final normalized = normalizedCategoryLabel(label);
      if (!seen.add(normalized)) {
        continue;
      }
      final match = workingTags.firstWhere(
        (tag) => normalizedCategoryLabel(tag.label) == normalized,
        orElse: () => const Tag(id: '', label: ''),
      );
      if (match.id.isNotEmpty) {
        ids.add(match.id);
        continue;
      }
      final tag = Tag(id: nextId('tag'), label: label);
      workingTags.add(tag);
      newTags.add(tag);
      ids.add(tag.id);
    }
    return ids;
  }

  // 转账落到一个「转账」分类（默认「转出」），与 App 内记账、信用卡还款口径一致
  // （见 credit_repayment_page）。空 categoryId 会被交易列表按 categoryById 回退成
  // 「已删除分类」占位、且不计入分类管理的转账分类下（issue #14），故复用现有转账分类
  // 而非留空。转账分类是系统种子（transfer_out/transfer_in/repayment），不在此新建；
  // 极端情况下（用户删光了转账分类）退回空串。
  final transferCategoryId = existingCategories
      .firstWhere(
        (category) => category.type == EntryType.transfer,
        orElse: () => const Category(
          id: '',
          label: '',
          type: EntryType.transfer,
          iconCode: '',
        ),
      )
      .id;

  void addConversionIssue(
    RawImportRecord record,
    String currencyCode,
    String message,
  ) {
    conversionIssues.add(
      ImportConversionIssue(
        line: record.sourceLine ?? 0,
        currencyCode: currencyCode,
        message: message,
        record: record,
      ),
    );
  }

  final candidateRatesByKey = <String, ExchangeRate>{};
  final candidateRateEntryIds = <String, Set<String>>{};

  String rateKey(String currencyCode, DateTime date) =>
      '$currencyCode:${currencyDateKey(date)}';

  bool sameRate(double a, double b) {
    final scale = a.abs() > b.abs() ? a.abs() : b.abs();
    return (a - b).abs() <= (scale == 0 ? 1e-10 : scale * 1e-10);
  }

  List<ExchangeRate> ratesForRecord(ExchangeRate? providedRate) {
    final all = <ExchangeRate>[...exchangeRates, ...candidateRatesByKey.values];
    if (providedRate == null) return all;
    final key = rateKey(providedRate.currencyCode, providedRate.effectiveDate);
    return <ExchangeRate>[
      providedRate,
      ...all.where(
        (rate) => rateKey(rate.currencyCode, rate.effectiveDate) != key,
      ),
    ];
  }

  double? convertedRecordAmount({
    required RawImportRecord record,
    required String sourceCurrencyCode,
    required String targetCurrencyCode,
    required ExchangeRate? providedRate,
  }) {
    final result = convertCurrencyAmount(
      amount: normalizeCurrencyAmount(record.amount, sourceCurrencyCode),
      sourceCurrencyCode: sourceCurrencyCode,
      targetCurrencyCode: targetCurrencyCode,
      baseCurrencyCode: baseCurrencyCode,
      bookId: bookId,
      date: record.date,
      rates: ratesForRecord(providedRate),
    );
    return result is ConvertedCurrencyAmount ? result.amount : null;
  }

  void registerCandidateRate(ExchangeRate? rate, String? key, String entryId) {
    if (rate == null || key == null) return;
    candidateRatesByKey[key] = rate;
    candidateRateEntryIds.putIfAbsent(key, () => <String>{}).add(entryId);
  }

  for (final record in parsed.records) {
    final line = record.sourceLine ?? 0;
    final currencyCode = (record.currencyCode ?? baseCurrencyCode)
        .toUpperCase();
    if (!CurrencyCatalog.isSupported(currencyCode)) {
      errors.add(ImportRowError(line: line, message: '币种代码无法识别：$currencyCode'));
      continue;
    }
    final accountCurrencyHint = record.accountCurrencyCode?.toUpperCase();
    final toAccountCurrencyHint = record.toAccountCurrencyCode?.toUpperCase();
    final unsupportedAccountCurrency = <String?>[
      accountCurrencyHint,
      toAccountCurrencyHint,
    ].whereType<String>().where((code) => !CurrencyCatalog.isSupported(code));
    if (unsupportedAccountCurrency.isNotEmpty) {
      errors.add(
        ImportRowError(
          line: line,
          message: '账户币种代码无法识别：${unsupportedAccountCurrency.join('、')}',
        ),
      );
      continue;
    }
    if (!record.amount.isFinite || record.amount <= 0) {
      errors.add(ImportRowError(line: line, message: '金额无效（应为大于 0 的数字）'));
      continue;
    }
    if (record.rateToBase != null && !isValidExchangeRate(record.rateToBase!)) {
      errors.add(ImportRowError(line: line, message: '汇率无效（应为大于 0 的数字）'));
      continue;
    }
    if (<double?>[
          record.accountAmount,
          record.toAccountAmount,
        ].any((value) => value != null && (!value.isFinite || value <= 0)) ||
        !record.fee.isFinite ||
        record.fee < 0 ||
        record.baseAmount != null &&
            (!record.baseAmount!.isFinite || record.baseAmount! < 0)) {
      errors.add(ImportRowError(line: line, message: '换算金额无效'));
      continue;
    }
    final normalizedAmount = normalizeCurrencyAmount(
      record.amount,
      currencyCode,
    );

    ExchangeRate? providedRate;
    String? candidateRateKey;
    if (record.rateToBase != null && currencyCode != baseCurrencyCode) {
      final effectiveDate = record.rateDate ?? record.date;
      final key = rateKey(currencyCode, effectiveDate);
      final sameDayRates =
          <ExchangeRate>[...exchangeRates, ...candidateRatesByKey.values].where(
            (rate) =>
                rate.bookId == bookId &&
                rate.baseCurrencyCode == baseCurrencyCode &&
                rateKey(rate.currencyCode, rate.effectiveDate) == key,
          );
      final existingRate = sameDayRates.firstOrNull;
      if (existingRate != null) {
        if (!sameRate(existingRate.rateToBase, record.rateToBase!)) {
          addConversionIssue(record, currencyCode, '导入汇率与同日已有汇率不一致');
          continue;
        }
        providedRate = existingRate;
        if (candidateRatesByKey.containsKey(key)) {
          candidateRateKey = key;
        }
      } else {
        providedRate = ExchangeRate(
          id: 'rate_import_${now.microsecondsSinceEpoch}_${currencyCode}_${currencyDateKey(effectiveDate)}',
          bookId: bookId,
          baseCurrencyCode: baseCurrencyCode,
          currencyCode: currencyCode,
          effectiveDate: effectiveDate,
          rateToBase: record.rateToBase!,
          source: record.rateSource ?? ExchangeRateSource.imported,
          createdAt: now,
          updatedAt: now,
        );
        candidateRateKey = key;
      }
    }

    if (record.type == EntryType.transfer) {
      // 账户名按去首尾空格解析（与创建账户的 trim 规则一致），
      // 「现金 」与「现金」视为同一账户。
      final fromName = record.account.trim();
      final toName = record.toAccount.trim();
      if (fromName.isEmpty && toName.isEmpty) {
        errors.add(ImportRowError(line: line, message: '转账缺少账户'));
        continue;
      }
      if (fromName.isNotEmpty && toName == fromName) {
        errors.add(ImportRowError(line: line, message: '转出与转入账户不能相同'));
        continue;
      }
      // 标签在报错检查之后才解析：被跳过的错误行不应留下无引用的候选标签。
      final tagIds = resolveTags(record.tags);
      // 单边为空（如源账本转入/转出到未跟踪账户）仍按转账记，空的一端不计余额。
      final fromId = fromName.isEmpty
          ? ''
          : resolveAccount(
              fromName,
              accountCurrencyHint ?? currencyCode,
              allowUniqueOtherCurrency:
                  accountCurrencyHint == null && record.accountAmount != null,
            );
      final toId = toName.isEmpty
          ? null
          : resolveAccount(
              toName,
              toAccountCurrencyHint ?? currencyCode,
              allowUniqueOtherCurrency:
                  toAccountCurrencyHint == null &&
                  record.toAccountAmount != null,
            );
      final fromCurrency = fromId.isEmpty
          ? null
          : accountByResolvedId(fromId)?.currencyCode;
      final toCurrency = toId == null
          ? null
          : accountByResolvedId(toId)?.currencyCode;
      final accountAmount = fromCurrency == null
          ? null
          : record.accountAmount ??
                (fromCurrency == currencyCode
                    ? normalizedAmount
                    : convertedRecordAmount(
                        record: record,
                        sourceCurrencyCode: currencyCode,
                        targetCurrencyCode: fromCurrency,
                        providedRate: providedRate,
                      ));
      final toAccountAmount = toCurrency == null
          ? null
          : record.toAccountAmount ??
                (toCurrency == currencyCode
                    ? normalizedAmount
                    : convertedRecordAmount(
                        record: record,
                        sourceCurrencyCode: currencyCode,
                        targetCurrencyCode: toCurrency,
                        providedRate: providedRate,
                      ));
      if (fromCurrency != null && accountAmount == null) {
        addConversionIssue(record, currencyCode, '缺少转出账户实际扣款金额或可用汇率');
        continue;
      }
      if (toCurrency != null && toAccountAmount == null) {
        addConversionIssue(record, currencyCode, '缺少转入账户实际到账金额或可用汇率');
        continue;
      }
      final entry = LedgerEntry(
        id: nextId('entry'),
        bookId: bookId,
        type: EntryType.transfer,
        amount: normalizedAmount,
        currencyCode: currencyCode,
        accountAmount: accountAmount == null
            ? null
            : normalizeCurrencyAmount(accountAmount, fromCurrency!),
        toAccountAmount: toAccountAmount == null
            ? null
            : normalizeCurrencyAmount(toAccountAmount, toCurrency!),
        baseAmount: 0,
        conversionSource: ConversionSource.imported,
        categoryId: transferCategoryId,
        accountId: fromId,
        toAccountId: toId,
        note: record.note,
        occurredAt: record.date,
        fee: normalizeCurrencyAmount(record.fee, fromCurrency ?? currencyCode),
        tagIds: tagIds,
      );
      entries.add(entry);
      registerCandidateRate(providedRate, candidateRateKey, entry.id);
      continue;
    }

    final tagIds = resolveTags(record.tags);
    final accountName = record.account.trim();
    final accountId = accountName.isEmpty
        ? ''
        : resolveAccount(
            accountName,
            accountCurrencyHint ?? currencyCode,
            allowUniqueOtherCurrency:
                accountCurrencyHint == null && record.accountAmount != null,
          );
    final accountCurrency = accountId.isEmpty
        ? null
        : accountByResolvedId(accountId)?.currencyCode;
    final accountAmount = accountCurrency == null
        ? null
        : record.accountAmount ??
              (accountCurrency == currencyCode
                  ? normalizedAmount
                  : convertedRecordAmount(
                      record: record,
                      sourceCurrencyCode: currencyCode,
                      targetCurrencyCode: accountCurrency,
                      providedRate: providedRate,
                    ));
    if (accountCurrency != null && accountAmount == null) {
      addConversionIssue(record, currencyCode, '缺少账户实际金额或可用汇率');
      continue;
    }
    final convertedBaseAmount = currencyCode == baseCurrencyCode
        ? normalizeCurrencyAmount(record.amount, baseCurrencyCode)
        : convertedRecordAmount(
            record: record,
            sourceCurrencyCode: currencyCode,
            targetCurrencyCode: baseCurrencyCode,
            providedRate: providedRate,
          );
    final rawBaseAmount = record.baseAmount ?? convertedBaseAmount;
    if (rawBaseAmount == null) {
      addConversionIssue(record, currencyCode, '缺少本位币金额或可用汇率');
      continue;
    }
    if (!rawBaseAmount.isFinite || rawBaseAmount <= 0) {
      errors.add(ImportRowError(line: line, message: '本位币金额无效'));
      continue;
    }
    final baseAmount = normalizeCurrencyAmount(rawBaseAmount, baseCurrencyCode);
    if (record.baseAmount != null &&
        convertedBaseAmount != null &&
        (record.baseAmount! - convertedBaseAmount).abs() >=
            currencyAmountTolerance(baseCurrencyCode)) {
      addConversionIssue(record, currencyCode, '本位币金额与汇率换算结果不一致');
      continue;
    }
    final categoryId = resolveCategoryHierarchy(
      record.category,
      record.subCategory,
      record.type,
    );
    // 支出可带退款（部分/全额）：钳制在 [0, 金额]，使净额=金额−退款、退款回原账户
    // （与 App 内退款冲抵语义一致）。收入行忽略。
    final refundedOriginal = record.type == EntryType.expense
        ? normalizeCurrencyAmount(
            record.refunded.clamp(0, normalizedAmount),
            currencyCode,
          )
        : 0.0;
    final refundedBase = normalizedAmount == 0
        ? 0.0
        : normalizeCurrencyAmount(
            refundedOriginal / normalizedAmount * baseAmount,
            baseCurrencyCode,
          );
    final entry = LedgerEntry(
      id: nextId('entry'),
      bookId: bookId,
      type: record.type,
      amount: normalizedAmount,
      currencyCode: currencyCode,
      accountAmount: accountAmount == null
          ? null
          : normalizeCurrencyAmount(accountAmount, accountCurrency!),
      baseAmount: baseAmount,
      conversionSource: ConversionSource.imported,
      categoryId: categoryId,
      accountId: accountId,
      toAccountId: null,
      note: record.note,
      occurredAt: record.date,
      refundedBaseAmount: refundedBase,
      tagIds: tagIds,
    );
    entries.add(entry);
    if (refundedOriginal > 0) {
      final ratio = refundedOriginal / normalizedAmount;
      entries.add(
        LedgerEntry(
          id: nextId('refund'),
          bookId: bookId,
          type: EntryType.refund,
          amount: refundedOriginal,
          currencyCode: currencyCode,
          accountAmount: accountAmount == null
              ? null
              : normalizeCurrencyAmount(
                  accountAmount * ratio,
                  accountCurrency!,
                ),
          baseAmount: refundedBase,
          conversionSource: ConversionSource.imported,
          categoryId: categoryId,
          accountId: accountId,
          note: '',
          occurredAt: record.date,
          refundOf: entry.id,
          settledAt: record.date,
        ),
      );
    }
    registerCandidateRate(providedRate, candidateRateKey, entry.id);
  }

  // 携带余额/类型的账户元数据（Tally）：回推初始余额对齐来源、补建无流水账户。
  final standalone = _applyAccountMetadata(
    accounts: parsed.accounts,
    entries: entries,
    newAccounts: newAccounts,
    existingAccounts: existingAccounts,
    bookId: bookId,
    now: now,
    baseCurrencyCode: baseCurrencyCode,
  );

  return ImportPlan(
    entries: entries,
    newAccounts: newAccounts,
    newCategories: newCategories,
    newTags: newTags,
    errors: errors,
    conversionIssues: conversionIssues,
    exchangeRateCandidates: <ImportExchangeRateCandidate>[
      for (final item in candidateRatesByKey.entries)
        ImportExchangeRateCandidate(
          rate: item.value,
          entryIds: Set<String>.unmodifiable(
            candidateRateEntryIds[item.key] ?? const <String>{},
          ),
        ),
    ],
    standaloneAccountIds: standalone,
  );
}

/// 用账户元数据（目前仅 Tally 提供）修正 [newAccounts]：让每个源账户导入后的**显示
/// 余额**等于来源存的当前余额，并补建没有流水的账户。就地修改 [newAccounts]，返回需要
/// 「即使无交易引用也落库」的账户 id 集合。
///
/// Veri Fin 账户显示余额 = `initialBalance + Σ 交易增量`，故对**本次导入新建**的账户回推
/// `initialBalance = 目标余额 − Σ增量`；没有任何交易引用的资产则直接以目标余额新建。
/// 已存在的同名账户不改动（避免覆盖用户既有数据）。
Set<String> _applyAccountMetadata({
  required List<RawImportAccount> accounts,
  required List<LedgerEntry> entries,
  required List<Account> newAccounts,
  required List<Account> existingAccounts,
  required String bookId,
  required DateTime now,
  required String baseCurrencyCode,
}) {
  if (accounts.isEmpty) {
    return const <String>{};
  }

  // 各账户在本次导入交易中的余额增量合计（按最终账户 id 聚合）。
  final deltaByAccount = <String, double>{};
  for (final entry in entries) {
    for (final id in <String?>[entry.accountId, entry.toAccountId]) {
      if (id != null && id.isNotEmpty) {
        deltaByAccount[id] =
            (deltaByAccount[id] ?? 0) + accountDeltaForEntry(entry, id);
      }
    }
  }

  final standalone = <String>{};
  var counter = 0;
  for (final asset in accounts) {
    // 与 resolveAccount 同一套去空格匹配规则。
    final assetName = asset.name.trim();
    if (assetName.isEmpty) {
      continue;
    }
    final currencyCode = (asset.currencyCode ?? baseCurrencyCode).toUpperCase();
    if (!CurrencyCatalog.isSupported(currencyCode)) {
      continue;
    }
    final newIndex = newAccounts.indexWhere(
      (a) => a.name == assetName && a.currencyCode == currencyCode,
    );
    if (newIndex != -1) {
      // 本次导入新建的账户：回推初始余额，使显示余额对齐来源；标记为独立账户。
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
    if (existingAccounts.any(
      (a) => a.name.trim() == assetName && a.currencyCode == currencyCode,
    )) {
      continue;
    }
    // 没有任何流水的资产（零余额钱包、借出/负债对象等）：直接以当前余额新建。
    counter++;
    final id = 'stdacct_${now.microsecondsSinceEpoch}_$counter';
    newAccounts.add(
      Account(
        id: id,
        bookId: bookId,
        name: assetName,
        type: asset.type,
        groupId: null,
        initialBalance: asset.signedBalance,
        iconCode: 'wallet',
        note: '',
        includeInAssets: asset.includeInAssets,
        hidden: false,
        currencyCode: currencyCode,
      ),
    );
    standalone.add(id);
  }
  return standalone;
}
