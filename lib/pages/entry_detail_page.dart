import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../app/ai/ai_entry_parser.dart';
import '../app/app_theme.dart';
import '../app/attachment_picker.dart';
import '../app/category_suggest.dart';
import '../app/category_tree.dart';
import '../app/common_widgets.dart';
import '../app/currency_catalog.dart';
import '../app/currency_math.dart';
import '../app/entry_currency_draft.dart';
import '../app/feedback.dart';
import '../app/model_lookup.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'attachments_editor.dart';
import 'sheets.dart';

class EntryDetailPage extends StatefulWidget {
  const EntryDetailPage({
    super.key,
    required this.initialAmount,
    this.initialAccountId,
    this.initialDraft,
  }) : draftEntry = null,
       draftExtraAccounts = null,
       draftExtraCategories = null,
       draftExtraTags = null;

  /// 草稿编辑模式：编辑一条已有交易（如导入预览里的条目），保存时**不落库**，
  /// 而是通过 `Navigator.pop` 返回修改后的 [LedgerEntry] 供上层处理。
  /// [extraAccounts]/[extraCategories]/[extraTags] 是尚未落库的临时账户/分类/标签
  /// （如导入将新建的），合并进选择器与展示，保证草稿引用到它们时能正确解析、不被回退。
  EntryDetailPage.draft({
    super.key,
    required LedgerEntry entry,
    List<Account> extraAccounts = const <Account>[],
    List<Category> extraCategories = const <Category>[],
    List<Tag> extraTags = const <Tag>[],
  }) : draftEntry = entry,
       draftExtraAccounts = extraAccounts,
       draftExtraCategories = extraCategories,
       draftExtraTags = extraTags,
       initialAmount = entry.amount,
       initialAccountId = null,
       initialDraft = null;

  final double initialAmount;
  final String? initialAccountId;

  /// AI 解析出的草稿：非空时预填表单并显示复核提示，供用户确认/修改后落账。
  final AiEntryDraft? initialDraft;

  /// 草稿编辑模式下要编辑的交易；非空即进入「返回草稿不落库」模式。
  final LedgerEntry? draftEntry;

  /// 草稿模式下额外可选的临时账户 / 分类 / 标签（未落库，如导入待新建项）。
  final List<Account>? draftExtraAccounts;
  final List<Category>? draftExtraCategories;
  final List<Tag>? draftExtraTags;

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

enum _EntryConversionTarget { account, toAccount, base }

class _EntryDetailPageState extends State<EntryDetailPage> {
  late double _amount = widget.initialAmount;
  EntryType _type = EntryType.expense;
  String _categoryId = 'dining';
  late String _accountId = widget.initialAccountId ?? '';
  // 「无账户」：只记金额、不计入任何账户余额（仅收支有效，转账必须选账户）。
  bool _noAccount = false;
  String? _toAccountId;
  DateTime _occurredAt = DateTime.now();
  double _fee = 0;
  String? _currencyCode;
  double? _accountAmount;
  double? _toAccountAmount;
  double? _baseAmount;
  ConversionSource _conversionSource = ConversionSource.identity;
  bool _currencyTouched = false;
  bool _accountAmountTouched = false;
  bool _toAccountAmountTouched = false;
  bool _baseAmountTouched = false;
  bool _rememberRate = false;
  bool _moneyInitialized = false;
  Set<String> _missingRateCodes = <String>{};
  ConvertedCurrencyAmount? _accountConversion;
  ConvertedCurrencyAmount? _toAccountConversion;
  ConvertedCurrencyAmount? _baseConversion;
  // 支出可标记「待报销」；新建时不涉及回款冲抵，退款金额建后在编辑页填写。
  bool _reimbursable = false;
  List<String> _tagIds = <String>[];
  // 新增交易时先缓存附件 data URL，保存后再按新交易 id 落库。
  final List<String> _pendingAttachments = <String>[];
  final TextEditingController _noteController = TextEditingController();

  // 自动识别：用户未手动改动某字段前，按历史（金额/备注/时段）自动填充类型、分类、
  // 标签、备注；某字段一旦被用户改过就不再覆盖它。AI 草稿模式（initialDraft）下整体
  // 关闭自动识别，尊重草稿。
  bool _typeTouched = false;
  bool _categoryTouched = false;
  bool _tagsTouched = false;
  bool _noteTouched = false;
  // 防重复提交：极快双击「保存」可能在 pop 生效前触发两次、落两条交易。
  bool _saving = false;
  bool _saved = false;
  late final String _entryId =
      widget.draftEntry?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
  LedgerEntry? _initialEntryDraft;
  List<String>? _initialAttachmentDataUrls;
  LedgerEntry? _savedResult;
  final EditorExitController _exitController = EditorExitController();
  // 程序化写入备注时置真，令备注监听忽略这次（不误判为用户输入）。
  bool _applyingSuggestion = false;
  bool _didInitialSuggest = false;
  // 草稿编辑模式（导入预览）与 AI 草稿一样关闭自动识别，尊重传入数据。
  late final bool _draftFree =
      widget.initialDraft == null && widget.draftEntry == null;

  /// 自动识别是否生效：非草稿模式，且用户没在设置里关掉总开关
  /// （`controller.autoSuggestEnabled`，全局偏好、进备份）。
  bool get _autoSuggestEnabled =>
      _draftFree && VeriFinScope.of(context).autoSuggestEnabled;

  bool get _isDraft => widget.draftEntry != null;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteChanged);
    final editing = widget.draftEntry;
    if (editing != null) {
      _type = editing.type;
      if (editing.categoryId.isNotEmpty) {
        _categoryId = editing.categoryId;
      }
      if (editing.type != EntryType.transfer && editing.accountId.isEmpty) {
        _noAccount = true;
        _accountId = '';
      } else {
        _accountId = editing.accountId;
      }
      _toAccountId = editing.toAccountId;
      _occurredAt = editing.occurredAt;
      _fee = editing.fee;
      _currencyCode = editing.currencyCode;
      _accountAmount = editing.accountAmount;
      _toAccountAmount = editing.toAccountAmount;
      _baseAmount = editing.baseAmount;
      _conversionSource = editing.conversionSource;
      _reimbursable = editing.reimbursable;
      _tagIds = List<String>.of(editing.tagIds);
      _applyingSuggestion = true;
      _noteController.text = editing.note;
      _applyingSuggestion = false;
    }
    final draft = widget.initialDraft;
    if (draft != null) {
      _type = draft.type;
      if (draft.categoryId.isNotEmpty) {
        _categoryId = draft.categoryId;
      }
      // 转账必须落到账户；收支允许「无账户」（空 accountId）。AI 没识别到账户时，
      // 若配置了默认付款账户（initialAccountId）就用它，否则记为「无账户」。
      if (draft.type != EntryType.transfer && draft.accountId.isEmpty) {
        final fallback = widget.initialAccountId ?? '';
        if (fallback.isNotEmpty) {
          _accountId = fallback;
        } else {
          _noAccount = true;
          _accountId = '';
        }
      } else {
        _accountId = draft.accountId;
      }
      _toAccountId = draft.toAccountId;
      _occurredAt = draft.occurredAt;
      _currencyCode = draft.currencyCode;
      _applyingSuggestion = true;
      _noteController.text = draft.note;
      _applyingSuggestion = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_moneyInitialized) {
      _initializeCurrencyAmounts();
    }
    // 开屏（金额已确定、备注为空）先按金额习惯识别一次。
    if (_autoSuggestEnabled && !_didInitialSuggest) {
      _didInitialSuggest = true;
      _recomputeSuggestion();
    }
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  List<Account> _availableAccounts(VeriFinController controller) {
    final values = _isDraft
        ? <Account>[...controller.accounts, ...widget.draftExtraAccounts!]
        : controller.accounts;
    return values.where((account) => !account.hidden).toList();
  }

  Account? _accountFor(List<Account> accounts, String? id) {
    if (id == null || id.isEmpty) return null;
    return accounts.where((account) => account.id == id).firstOrNull;
  }

  void _initializeCurrencyAmounts() {
    final controller = VeriFinScope.of(context);
    final accounts = _availableAccounts(controller);
    if (!_noAccount &&
        accounts.isNotEmpty &&
        !accounts.any((account) => account.id == _accountId)) {
      _accountId = accounts.first.id;
    }
    _normalizeTransferAccounts(accounts);
    _currencyCode ??=
        _accountFor(accounts, _accountId)?.currencyCode ??
        controller.activeBook.baseCurrencyCode;
    _moneyInitialized = true;
    if (widget.draftEntry == null) {
      _refreshCurrencyAmounts(
        controller,
        accounts,
        forceAccount: true,
        forceToAccount: true,
        forceBase: true,
      );
    } else {
      _refreshMissingRateCodes(controller, accounts);
    }
  }

  double? _convertAmount(
    VeriFinController controller, {
    required double amount,
    required String sourceCode,
    required String targetCode,
    required _EntryConversionTarget target,
  }) {
    final result = controller.convertAmount(
      amount: amount,
      sourceCurrencyCode: sourceCode,
      targetCurrencyCode: targetCode,
      date: _occurredAt,
    );
    if (result is ConvertedCurrencyAmount) {
      switch (target) {
        case _EntryConversionTarget.account:
          _accountConversion = result;
        case _EntryConversionTarget.toAccount:
          _toAccountConversion = result;
        case _EntryConversionTarget.base:
          _baseConversion = result;
      }
      return result.amount;
    }
    switch (target) {
      case _EntryConversionTarget.account:
        _accountConversion = null;
      case _EntryConversionTarget.toAccount:
        _toAccountConversion = null;
      case _EntryConversionTarget.base:
        _baseConversion = null;
    }
    if (result is MissingCurrencyRate) {
      _missingRateCodes.addAll(result.currencyCodes);
    }
    return null;
  }

  void _refreshCurrencyAmounts(
    VeriFinController controller,
    List<Account> accounts, {
    bool forceAccount = false,
    bool forceToAccount = false,
    bool forceBase = false,
  }) {
    _missingRateCodes = <String>{};
    final baseCode = controller.activeBook.baseCurrencyCode;
    final account = _noAccount ? null : _accountFor(accounts, _accountId);
    final toAccount = _accountFor(accounts, _toAccountId);

    if (_type == EntryType.transfer) {
      _accountConversion = null;
      _baseConversion = null;
      if (account != null) {
        _currencyCode = account.currencyCode;
        _amount = normalizeCurrencyAmount(_amount, account.currencyCode);
        _accountAmount = _amount;
      }
      _baseAmount = 0;
      if (toAccount == null) {
        _toAccountAmount = null;
        _toAccountConversion = null;
      } else if (account != null &&
          toAccount.currencyCode == account.currencyCode) {
        _toAccountAmount = normalizeCurrencyAmount(
          _amount,
          toAccount.currencyCode,
        );
        _toAccountAmountTouched = false;
        _toAccountConversion = null;
      } else if (forceToAccount || !_toAccountAmountTouched) {
        _toAccountAmount = _convertAmount(
          controller,
          amount: _amount,
          sourceCode: _currencyCode!,
          targetCode: toAccount.currencyCode,
          target: _EntryConversionTarget.toAccount,
        );
      }
      _conversionSource = _toAccountAmountTouched
          ? ConversionSource.manual
          : account != null &&
                toAccount != null &&
                account.currencyCode != toAccount.currencyCode
          ? ConversionSource.rateTable
          : ConversionSource.identity;
      _refreshMissingRateCodes(controller, accounts);
      return;
    }

    final code = _currencyCode ?? baseCode;
    if (account == null) {
      _accountAmount = null;
      _accountConversion = null;
    } else if (code == account.currencyCode) {
      _accountAmount = normalizeCurrencyAmount(_amount, account.currencyCode);
      _accountAmountTouched = false;
      _accountConversion = null;
    } else if (forceAccount || !_accountAmountTouched) {
      _accountAmount = _convertAmount(
        controller,
        amount: _amount,
        sourceCode: code,
        targetCode: account.currencyCode,
        target: _EntryConversionTarget.account,
      );
    }

    if (code == baseCode) {
      _baseAmount = normalizeCurrencyAmount(_amount, baseCode);
      _baseAmountTouched = false;
      _baseConversion = null;
    } else if (account?.currencyCode == baseCode && _accountAmount != null) {
      _baseAmount = normalizeCurrencyAmount(_accountAmount!, baseCode);
      _baseAmountTouched = _accountAmountTouched;
      _baseConversion = null;
    } else if (forceBase || !_baseAmountTouched) {
      _baseAmount = _convertAmount(
        controller,
        amount: _amount,
        sourceCode: code,
        targetCode: baseCode,
        target: _EntryConversionTarget.base,
      );
    }
    _conversionSource = _accountAmountTouched || _baseAmountTouched
        ? ConversionSource.manual
        : code == baseCode &&
              (account == null || account.currencyCode == baseCode)
        ? ConversionSource.identity
        : ConversionSource.rateTable;
    _refreshMissingRateCodes(controller, accounts);
  }

  void _refreshMissingRateCodes(
    VeriFinController controller,
    List<Account> accounts,
  ) {
    final missing = <String>{};
    final code = _currencyCode ?? controller.activeBook.baseCurrencyCode;
    final account = _noAccount ? null : _accountFor(accounts, _accountId);
    final toAccount = _accountFor(accounts, _toAccountId);
    if (_type == EntryType.transfer) {
      if (toAccount != null &&
          toAccount.currencyCode != code &&
          _toAccountAmount == null) {
        final result = controller.convertAmount(
          amount: _amount,
          sourceCurrencyCode: code,
          targetCurrencyCode: toAccount.currencyCode,
          date: _occurredAt,
        );
        if (result is MissingCurrencyRate) missing.addAll(result.currencyCodes);
      }
    } else {
      if (account != null &&
          account.currencyCode != code &&
          _accountAmount == null) {
        final result = controller.convertAmount(
          amount: _amount,
          sourceCurrencyCode: code,
          targetCurrencyCode: account.currencyCode,
          date: _occurredAt,
        );
        if (result is MissingCurrencyRate) missing.addAll(result.currencyCodes);
      }
      if (code != controller.activeBook.baseCurrencyCode &&
          _baseAmount == null) {
        final result = controller.convertAmount(
          amount: _amount,
          sourceCurrencyCode: code,
          targetCurrencyCode: controller.activeBook.baseCurrencyCode,
          date: _occurredAt,
        );
        if (result is MissingCurrencyRate) missing.addAll(result.currencyCodes);
      }
    }
    _missingRateCodes = missing;
  }

  List<DateTime> get _usedRateDates {
    final dates = <DateTime>{};
    for (final conversion in <ConvertedCurrencyAmount?>[
      _accountConversion,
      _toAccountConversion,
      _baseConversion,
    ]) {
      if (conversion?.sourceRateDate != null) {
        dates.add(conversion!.sourceRateDate!);
      }
      if (conversion?.targetRateDate != null) {
        dates.add(conversion!.targetRateDate!);
      }
    }
    return dates.toList()..sort();
  }

  void _onNoteChanged() {
    // 先看哨兵/挂载：initState 里程序化写备注也会触发本监听，那时不能查
    // InheritedWidget（_autoSuggestEnabled 要读 controller）。
    if (_applyingSuggestion || !mounted) {
      return;
    }
    if (!_autoSuggestEnabled) {
      setState(() {});
      return;
    }
    // 用户真的在输备注：标记已改（不再回填备注），并按新备注重算类型/分类/标签。
    _noteTouched = true;
    _recomputeSuggestion();
  }

  /// 按当前金额/备注/时段从历史识别，并填充「用户尚未改过」的字段。
  void _recomputeSuggestion() {
    if (!mounted || !_autoSuggestEnabled) {
      return;
    }
    final controller = VeriFinScope.of(context);
    final suggestion = suggestEntry(
      history: controller.entries,
      expenseCategoryIds: controller
          .categoriesForType(EntryType.expense)
          .map((c) => c.id)
          .toSet(),
      incomeCategoryIds: controller
          .categoriesForType(EntryType.income)
          .map((c) => c.id)
          .toSet(),
      note: _noteController.text,
      amount: _amount,
      currencyCode: _currencyCode ?? controller.activeBook.baseCurrencyCode,
      hour: _occurredAt.hour,
      // 用户已手动选过类型：不再翻转类型，只在该类型内识别分类/标签/备注。
      forcedType: _typeTouched ? _type : null,
    );
    if (suggestion.isEmpty) {
      return;
    }
    setState(() {
      if (!_typeTouched && suggestion.type != null) {
        _type = suggestion.type!;
      }
      if (!_categoryTouched && suggestion.categoryId != null) {
        _categoryId = suggestion.categoryId!;
      }
      if (!_tagsTouched && _tagIds.isEmpty && suggestion.tagIds != null) {
        _tagIds = List<String>.of(suggestion.tagIds!);
      }
      if (!_noteTouched &&
          _noteController.text.isEmpty &&
          suggestion.note != null) {
        _applyingSuggestion = true;
        _noteController.text = suggestion.note!;
        _applyingSuggestion = false;
      }
    });
  }

  /// 指定类型的可选分类：草稿模式下把传入的临时分类（未落库，如导入将新建的）
  /// 追加到账本现有分类之后，保证草稿引用到它们时能被解析、不被回退。
  List<Category> _categoriesForType(
    VeriFinController controller,
    EntryType type,
  ) {
    final base = controller.categoriesForType(type);
    if (!_isDraft) {
      return base;
    }
    return <Category>[
      ...base,
      ...widget.draftExtraCategories!.where(
        (category) => category.type == type,
      ),
    ];
  }

  /// 分类快捷区展示的前若干个顶级分类；若当前选中项所属的顶级分类不在前 8 个里，则把它
  /// 置顶插入，保证被选中/推荐分类所在的分支始终可见（可展开选到具体子分类）。
  List<Category> _visibleTopChips(List<Category> roots, String selectedTopId) {
    final shown = roots.take(8).toList();
    if (!shown.any((c) => c.id == selectedTopId)) {
      final idx = roots.indexWhere((c) => c.id == selectedTopId);
      if (idx >= 0) {
        shown.insert(0, roots[idx]);
        if (shown.length > 8) {
          shown.removeLast();
        }
      }
    }
    return shown;
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    // 本页只能表达用户可选的类型：退款不在此选择（只能从「原支出 → 添加退款」创建），
    // 且没有退款分类。任何来路（自动识别、草稿）带进来的非可选类型都归一化回支出，
    // 否则下方分类列表为空、类型选择器也会选不中任何一段（issue #26）。
    if (!EntryType.userSelectable.contains(_type)) {
      _type = EntryType.expense;
    }
    // 草稿模式下把临时账户（未落库，如导入将新建的）并入可选列表。
    final accounts = _availableAccounts(controller);
    final hasAccounts = accounts.isNotEmpty;
    // 转账必须落到具体账户，不允许「无账户」。
    if (_type == EntryType.transfer) {
      _noAccount = false;
    }
    if (hasAccounts &&
        !_noAccount &&
        !accounts.any((account) => account.id == _accountId)) {
      _accountId = accounts.first.id;
    }
    _normalizeTransferAccounts(accounts);
    final categories = _categoriesForType(controller, _type);
    if (!categories.any((category) => category.id == _categoryId)) {
      // 兜底而非 `categories.first`：某类型一个分类都没有时，宁可先留空（保存前
      // 由用户选，最坏也只是一条无分类交易）也不能让整页 build 抛异常白屏。
      // 上面的类型归一化 + 「不许删光某类型最后一个分类」的保护已让空列表不可达，
      // 这里只是最后一道防线。
      _categoryId = categories.isEmpty ? '' : categories.first.id;
    }
    // 分类快捷区：顶级分类使用三列紧凑胶囊；选中分支有子分类时，右下角
    // 的省略号进入现有多级分类选择器，不把子分类常驻铺在主页面。
    final rootCategoriesForType = categories
        .where((category) => category.parentId == null)
        .toList();
    final selectedAncestors = ancestorIds(categories, _categoryId);
    final selectedTopId = selectedAncestors.isEmpty
        ? _categoryId
        : selectedAncestors.last;
    final selectedCategory = categories
        .where((category) => category.id == _categoryId)
        .firstOrNull;
    // 大金额颜色跟随类型:支出红、收入青绿、转账保持蓝色。
    final amountColor = switch (_type) {
      EntryType.expense => veriExpense,
      EntryType.income => veriIncome,
      EntryType.transfer => veriBlue,
      // 退款不在此页手动选择，仅作穷尽兜底（正向流入用青绿）。
      EntryType.refund => veriIncome,
    };
    final amountNumber = formatCurrencyNumber(
      _amount,
      _currencyCode ?? controller.activeBook.baseCurrencyCode,
    );
    final amountText = switch (_type) {
      EntryType.expense => '− $amountNumber',
      EntryType.income => '+ $amountNumber',
      EntryType.transfer => amountNumber,
      EntryType.refund => '+ $amountNumber',
    };
    _captureInitialSnapshot();

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      popResult: () => _savedResult,
      exitController: _exitController,
      child: Scaffold(
        bottomNavigationBar: _EntryBottomSaveBar(
          enabled: _isDirty && _canSave(accounts),
          onPressed: _saveAndExit,
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  children: <Widget>[
                    VeriHeader(
                      // 标题展示当前账本名（此前误为固定文案）。
                      title: controller.activeBook.name,
                      subtitle: AppLocalizations.of(
                        context,
                      ).entryDetailSubtitle,
                      showBack: true,
                    ),
                    if (widget.initialDraft != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _AiReviewBanner(draft: widget.initialDraft!),
                    ],
                    const SizedBox(height: 12),
                    _EntryTypeSelector(
                      key: const Key('entry_type_segmented_button'),
                      selected: _type,
                      onChanged: (type) {
                        setState(() {
                          _type = type;
                          _typeTouched = true;
                          // 同上：空列表时留空，不取 `.first` 以免抛异常白屏。
                          final next = _categoriesForType(controller, _type);
                          _categoryId = next.isEmpty ? '' : next.first.id;
                          _normalizeTransferAccounts(accounts);
                          if (_type == EntryType.transfer) {
                            _currencyTouched = false;
                          }
                          _refreshCurrencyAmounts(
                            controller,
                            accounts,
                            forceAccount: true,
                            forceToAccount: true,
                            forceBase: true,
                          );
                        });
                        // 用户改了类型后，在该类型内重新识别分类/标签/备注。
                        _recomputeSuggestion();
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      key: const Key('detail_amount_button'),
                      borderRadius: BorderRadius.circular(veriRadiusMd),
                      onTap: _editAmount,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          amountText,
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                color: amountColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).commonCategory,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _EntryCategoryGrid(
                      categories: _visibleTopChips(
                        rootCategoriesForType,
                        selectedTopId,
                      ),
                      selectedTopId: selectedTopId,
                      selectedLabel: selectedCategory?.label,
                      accent: amountColor,
                      hasChildren: (category) => categories.any(
                        (candidate) => candidate.parentId == category.id,
                      ),
                      onSelected: (category) {
                        final hasKids = categories.any(
                          (candidate) => candidate.parentId == category.id,
                        );
                        if (selectedTopId == category.id && hasKids) {
                          unawaited(_showCategoryBranch(category, categories));
                          return;
                        }
                        setState(() {
                          _categoryId = category.id;
                          _categoryTouched = true;
                        });
                      },
                      onOpenBranch: (category) =>
                          unawaited(_showCategoryBranch(category, categories)),
                      onOpenAll: () => unawaited(_showAllCategories()),
                      allLabel: AppLocalizations.of(context).allLabel,
                    ),
                    const SizedBox(height: 18),
                    if (hasAccounts && _type == EntryType.transfer) ...<Widget>[
                      SelectField(
                        key: const Key('account_dropdown'),
                        label: AppLocalizations.of(context).transferOutAccount,
                        value:
                            '${accountById(accounts, _accountId).name} (${formatUserMoney(controller.accountBalance(accountById(accounts, _accountId)), accountById(accounts, _accountId).currencyCode)})',
                        leading: AccountIconBox(
                          iconCode: accountById(accounts, _accountId).iconCode,
                          size: 26,
                        ),
                        onTap: () => _pickAccount(accounts),
                      ),
                      const SizedBox(height: 10),
                      SelectField(
                        key: const Key('to_account_dropdown'),
                        label: AppLocalizations.of(context).transferInAccount,
                        value: _toAccountId == null
                            ? AppLocalizations.of(context).pleaseSelect
                            : '${accountById(accounts, _toAccountId!).name} (${formatUserMoney(controller.accountBalance(accountById(accounts, _toAccountId!)), accountById(accounts, _toAccountId!).currencyCode)})',
                        icon: _toAccountId == null ? Icons.call_received : null,
                        leading: _toAccountId == null
                            ? null
                            : AccountIconBox(
                                iconCode: accountById(
                                  accounts,
                                  _toAccountId!,
                                ).iconCode,
                                size: 26,
                              ),
                        onTap: accounts.length < 2
                            ? null
                            : () => _pickToAccount(accounts),
                      ),
                      const SizedBox(height: 10),
                      SelectField(
                        key: const Key('fee_field'),
                        label: AppLocalizations.of(context).feeLabel,
                        value: _fee > 0
                            ? formatUserMoney(
                                _fee,
                                _currencyCode ??
                                    controller.activeBook.baseCurrencyCode,
                              )
                            : AppLocalizations.of(context).feeNoneTapToFill,
                        icon: Icons.paid_outlined,
                        onTap: _editFee,
                      ),
                    ] else if (hasAccounts)
                      SelectField(
                        key: const Key('account_dropdown'),
                        label: AppLocalizations.of(context).accountLabel,
                        value: _noAccount
                            ? AppLocalizations.of(context).noAccountLabel
                            : '${accountById(accounts, _accountId).name} (${formatUserMoney(controller.accountBalance(accountById(accounts, _accountId)), accountById(accounts, _accountId).currencyCode)})',
                        icon: _noAccount
                            ? Icons.money_off_csred_outlined
                            : null,
                        leading: _noAccount
                            ? null
                            : AccountIconBox(
                                iconCode: accountById(
                                  accounts,
                                  _accountId,
                                ).iconCode,
                                size: 26,
                              ),
                        onTap: () => _pickAccount(accounts),
                      )
                    else
                      EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: AppLocalizations.of(
                          context,
                        ).noUsableAccountTitle,
                        description: AppLocalizations.of(
                          context,
                        ).noUsableAccountDesc,
                      ),
                    ..._buildCurrencyAmountFields(controller, accounts),
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('entry_note_field'),
                      controller: _noteController,
                      maxLines: 1,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).commonNote,
                        hintText: AppLocalizations.of(context).noteHint,
                        prefixIcon: const Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppLocalizations.of(context).entryMoreInfo,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.48),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      key: const Key('entry_metadata_chips'),
                      spacing: 7,
                      runSpacing: 7,
                      children: <Widget>[
                        _EntryMetadataChip(
                          chipKey: const Key('entry_metadata_date'),
                          icon: Icons.calendar_today_outlined,
                          label: Text(
                            AppLocalizations.of(
                              context,
                            ).dateMonthDay(_occurredAt),
                          ),
                          onTap: _pickDate,
                        ),
                        _EntryMetadataChip(
                          chipKey: const Key('entry_metadata_time'),
                          icon: Icons.schedule_rounded,
                          label: Text(formatTime(_occurredAt)),
                          onTap: _pickTime,
                        ),
                        _EntryMetadataChip(
                          chipKey: const Key('entry_metadata_tags'),
                          icon: Icons.sell_outlined,
                          label: Text(
                            _tagIds.isEmpty
                                ? AppLocalizations.of(context).tagLabel
                                : AppLocalizations.of(
                                    context,
                                  ).entryTagCount(_tagIds.length),
                          ),
                          selected: _tagIds.isNotEmpty,
                          onTap: _pickTags,
                        ),
                        if (_type == EntryType.expense)
                          _EntryMetadataChip(
                            chipKey: const Key('entry_metadata_reimbursable'),
                            icon: Icons.receipt_long_outlined,
                            label: Text(
                              AppLocalizations.of(context).badgeReimbursable,
                            ),
                            selected: _reimbursable,
                            onTap: () =>
                                setState(() => _reimbursable = !_reimbursable),
                          ),
                        if (!_isDraft)
                          VeriAnchoredMenuAnchor(
                            entries: <VeriMenuEntry>[
                              VeriMenuItem(
                                id: 'entry_attachment_camera',
                                icon: Icons.photo_camera_outlined,
                                title: AppLocalizations.of(
                                  context,
                                ).attachTakePhoto,
                                enabled: attachmentPickingSupported,
                                onPressed: () =>
                                    unawaited(_addAttachment(fromCamera: true)),
                              ),
                              VeriMenuItem(
                                id: 'entry_attachment_gallery',
                                icon: Icons.photo_library_outlined,
                                title: AppLocalizations.of(
                                  context,
                                ).attachFromGallery,
                                enabled: attachmentPickingSupported,
                                onPressed: () => unawaited(
                                  _addAttachment(fromCamera: false),
                                ),
                              ),
                            ],
                            semanticLabel: AppLocalizations.of(
                              context,
                            ).attachTitle,
                            width: 196,
                            builder: (context, openMenu, menuOpen) =>
                                _EntryMetadataChip(
                                  chipKey: const Key(
                                    'entry_metadata_attachments',
                                  ),
                                  icon: Icons.add_photo_alternate_outlined,
                                  label: Text(
                                    _pendingAttachments.isEmpty
                                        ? AppLocalizations.of(
                                            context,
                                          ).attachTitle
                                        : AppLocalizations.of(
                                            context,
                                          ).entryAttachmentCount(
                                            _pendingAttachments.length,
                                          ),
                                  ),
                                  selected:
                                      _pendingAttachments.isNotEmpty ||
                                      menuOpen,
                                  onTap: attachmentPickingSupported
                                      ? openMenu
                                      : null,
                                ),
                          ),
                        _EntryMetadataChip(
                          chipKey: const Key('entry_currency_button'),
                          icon: Icons.currency_exchange_rounded,
                          label: Text(
                            _currencyCode ??
                                controller.activeBook.baseCurrencyCode,
                          ),
                          selected:
                              (_currencyCode ??
                                  controller.activeBook.baseCurrencyCode) !=
                              controller.activeBook.baseCurrencyCode,
                          onTap: _type == EntryType.transfer
                              ? null
                              : _pickCurrency,
                        ),
                      ],
                    ),
                    if (!_isDraft &&
                        _pendingAttachments.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      AttachmentsEditor(
                        dataUrls: _pendingAttachments,
                        onAddDataUrl: (dataUrl) =>
                            setState(() => _pendingAttachments.add(dataUrl)),
                        onRemoveIndex: (index) =>
                            setState(() => _pendingAttachments.removeAt(index)),
                        showHeader: false,
                        showAddButton: false,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCurrencyAmountFields(
    VeriFinController controller,
    List<Account> accounts,
  ) {
    final l10n = AppLocalizations.of(context);
    final code = _currencyCode ?? controller.activeBook.baseCurrencyCode;
    final baseCode = controller.activeBook.baseCurrencyCode;
    final account = _noAccount ? null : _accountFor(accounts, _accountId);
    final toAccount = _accountFor(accounts, _toAccountId);
    final fields = <Widget>[];
    if (_type == EntryType.transfer) {
      if (toAccount != null && toAccount.currencyCode != code) {
        fields.addAll(<Widget>[
          const SizedBox(height: 12),
          VeriCard(
            child: Column(
              children: <Widget>[
                CurrencyAmountField(
                  key: const Key('entry_to_account_amount'),
                  label: l10n.entryTransferInAmount,
                  currencyCode: toAccount.currencyCode,
                  amount: _toAccountAmount,
                  missingText: l10n.exchangeRateNotSet,
                  onTap: () => _editToAccountAmount(toAccount.currencyCode),
                ),
                DetailInfoRow(
                  label: l10n.entryRateLabel,
                  value: _toAccountAmount == null || _amount <= 0
                      ? l10n.exchangeRateNotSet
                      : l10n.entryRateEquation(
                          code,
                          formatRateValue(_toAccountAmount! / _amount),
                          toAccount.currencyCode,
                        ),
                  placeholder: _toAccountAmount == null,
                  onTap: () => _editDerivedRate(
                    sourceCode: code,
                    targetCode: toAccount.currencyCode,
                    transfer: true,
                  ),
                ),
              ],
            ),
          ),
        ]);
      }
    } else {
      final needsAccountAmount =
          account != null && account.currencyCode != code;
      final needsBaseAmount = code != baseCode;
      if (needsAccountAmount || needsBaseAmount) {
        fields.addAll(<Widget>[
          const SizedBox(height: 12),
          VeriCard(
            child: Column(
              children: <Widget>[
                if (needsAccountAmount)
                  CurrencyAmountField(
                    key: const Key('entry_account_amount'),
                    label: _type == EntryType.expense
                        ? l10n.entryAccountAmountExpense
                        : l10n.entryAccountAmountIncome,
                    currencyCode: account.currencyCode,
                    amount: _accountAmount,
                    missingText: l10n.exchangeRateNotSet,
                    onTap: () => _editAccountAmount(account.currencyCode),
                  ),
                if (needsBaseAmount)
                  CurrencyAmountField(
                    key: const Key('entry_base_amount'),
                    label: l10n.entryLedgerAmountLabel,
                    currencyCode: baseCode,
                    amount: _baseAmount,
                    missingText: l10n.exchangeRateNotSet,
                    onTap: () => _editBaseAmount(baseCode),
                  ),
                if (needsBaseAmount)
                  DetailInfoRow(
                    label: l10n.entryRateLabel,
                    value: _baseAmount == null || _amount <= 0
                        ? l10n.exchangeRateNotSet
                        : l10n.entryRateEquation(
                            code,
                            formatRateValue(_baseAmount! / _amount),
                            baseCode,
                          ),
                    placeholder: _baseAmount == null,
                    onTap: () => _editDerivedRate(
                      sourceCode: code,
                      targetCode: baseCode,
                      transfer: false,
                    ),
                  ),
                if (needsBaseAmount && _baseAmount != null)
                  CompactSwitchRow(
                    icon: Icons.bookmark_add_outlined,
                    title: Text(l10n.entryRememberRate),
                    subtitle: Text(l10n.entryRememberRateHint),
                    value: _rememberRate,
                    onChanged: (value) => setState(() => _rememberRate = value),
                  ),
              ],
            ),
          ),
        ]);
      }
    }
    if (_missingRateCodes.isNotEmpty) {
      fields.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.entryMissingRate(
              (_missingRateCodes.toList()..sort()).join(', '),
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: veriWarning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    } else if (fields.isNotEmpty) {
      final rateDates = _usedRateDates;
      final stale = rateDates.any(
        (date) => calendarDaysBetween(date, _occurredAt) > 30,
      );
      fields.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _conversionSource == ConversionSource.manual
                ? l10n.entryConversionSourceManual
                : rateDates.isEmpty
                ? l10n.entryConversionSourceRateTable
                : l10n.entryConversionRateTrace(
                    rateDates.map(currencyDateKey).join(' / '),
                    stale ? ' · ${l10n.exchangeRateStale}' : '',
                  ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    }
    return fields;
  }

  Future<void> _pickCurrency() async {
    final controller = VeriFinScope.of(context);
    final selected = await showCurrencyPickerSheet(
      context: context,
      title: AppLocalizations.of(context).entryCurrencyPickTitle,
      selectedCode: _currencyCode,
      preferredCodes: <String>[
        controller.activeBook.baseCurrencyCode,
        for (final account in controller.accounts) account.currencyCode,
      ],
    );
    if (!mounted || selected == null || selected.code == _currencyCode) return;
    setState(() {
      _currencyCode = selected.code;
      _currencyTouched = true;
      _amount = normalizeCurrencyAmount(_amount, selected.code);
      _accountAmountTouched = false;
      _baseAmountTouched = false;
      _rememberRate = false;
      _refreshCurrencyAmounts(
        controller,
        _availableAccounts(controller),
        forceAccount: true,
        forceBase: true,
      );
    });
  }

  Future<void> _editAmount() async {
    final code =
        _currencyCode ?? VeriFinScope.of(context).activeBook.baseCurrencyCode;
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).entryAmountInputTitle(
        AppLocalizations.of(context).entryOriginalAmountLabel,
        code,
      ),
      initialAmount: _amount,
      maxFractionDigits: CurrencyCatalog.require(code).minorUnit,
    );

    if (!mounted || amount == null || amount <= 0) {
      return;
    }

    setState(() {
      final previousAmount = _amount;
      _amount = normalizeCurrencyAmount(amount, code);
      final controller = VeriFinScope.of(context);
      final accounts = _availableAccounts(controller);
      if (_conversionSource == ConversionSource.manual ||
          _conversionSource == ConversionSource.imported ||
          _conversionSource == ConversionSource.legacy) {
        final accountCode = _accountFor(accounts, _accountId)?.currencyCode;
        final toAccountCode = _accountFor(accounts, _toAccountId)?.currencyCode;
        if (accountCode != null) {
          _accountAmount = scaleDependentCurrencyAmount(
            dependentAmount: _accountAmount,
            previousOriginalAmount: previousAmount,
            nextOriginalAmount: _amount,
            targetCurrencyCode: accountCode,
          );
          _accountAmountTouched = true;
        }
        if (toAccountCode != null) {
          _toAccountAmount = scaleDependentCurrencyAmount(
            dependentAmount: _toAccountAmount,
            previousOriginalAmount: previousAmount,
            nextOriginalAmount: _amount,
            targetCurrencyCode: toAccountCode,
          );
          _toAccountAmountTouched = true;
        }
        _baseAmount = scaleDependentCurrencyAmount(
          dependentAmount: _baseAmount,
          previousOriginalAmount: previousAmount,
          nextOriginalAmount: _amount,
          targetCurrencyCode: controller.activeBook.baseCurrencyCode,
        );
        _baseAmountTouched = true;
        _refreshMissingRateCodes(controller, accounts);
      } else {
        _refreshCurrencyAmounts(controller, accounts);
      }
    });
    // 金额变了，按新金额重新识别。
    _recomputeSuggestion();
  }

  Future<void> _editFee() async {
    final code =
        _currencyCode ?? VeriFinScope.of(context).activeBook.baseCurrencyCode;
    final fee = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).transferFeeTitle,
      initialAmount: _fee > 0 ? _fee : null,
      allowZero: true,
      maxFractionDigits: CurrencyCatalog.require(code).minorUnit,
    );
    if (!mounted || fee == null || fee < 0) {
      return;
    }
    setState(() => _fee = normalizeCurrencyAmount(fee, code));
  }

  Future<void> _editAccountAmount(String currencyCode) async {
    final l10n = AppLocalizations.of(context);
    final value = await showNumberPadSheet(
      context,
      title: l10n.entryAmountInputTitle(
        _type == EntryType.expense
            ? l10n.entryAccountAmountExpense
            : l10n.entryAccountAmountIncome,
        currencyCode,
      ),
      initialAmount: _accountAmount,
      maxFractionDigits: CurrencyCatalog.require(currencyCode).minorUnit,
    );
    if (!mounted || value == null || value <= 0) return;
    setState(() {
      _accountAmount = normalizeCurrencyAmount(value, currencyCode);
      _accountAmountTouched = true;
      if (currencyCode ==
          VeriFinScope.of(context).activeBook.baseCurrencyCode) {
        _baseAmount = _accountAmount;
        _baseAmountTouched = true;
      }
      _conversionSource = ConversionSource.manual;
      _refreshMissingRateCodes(
        VeriFinScope.of(context),
        _availableAccounts(VeriFinScope.of(context)),
      );
    });
  }

  Future<void> _editToAccountAmount(String currencyCode) async {
    final l10n = AppLocalizations.of(context);
    final value = await showNumberPadSheet(
      context,
      title: l10n.entryAmountInputTitle(
        l10n.entryTransferInAmount,
        currencyCode,
      ),
      initialAmount: _toAccountAmount,
      maxFractionDigits: CurrencyCatalog.require(currencyCode).minorUnit,
    );
    if (!mounted || value == null || value <= 0) return;
    setState(() {
      _toAccountAmount = normalizeCurrencyAmount(value, currencyCode);
      _toAccountAmountTouched = true;
      _conversionSource = ConversionSource.manual;
      _refreshMissingRateCodes(
        VeriFinScope.of(context),
        _availableAccounts(VeriFinScope.of(context)),
      );
    });
  }

  Future<void> _editBaseAmount(String currencyCode) async {
    final l10n = AppLocalizations.of(context);
    final value = await showNumberPadSheet(
      context,
      title: l10n.entryAmountInputTitle(
        l10n.entryLedgerAmountLabel,
        currencyCode,
      ),
      initialAmount: _baseAmount,
      maxFractionDigits: CurrencyCatalog.require(currencyCode).minorUnit,
    );
    if (!mounted || value == null || value <= 0) return;
    setState(() {
      _baseAmount = normalizeCurrencyAmount(value, currencyCode);
      _baseAmountTouched = true;
      final account = _accountFor(
        _availableAccounts(VeriFinScope.of(context)),
        _accountId,
      );
      if (!_noAccount && account?.currencyCode == currencyCode) {
        _accountAmount = _baseAmount;
        _accountAmountTouched = true;
      }
      _conversionSource = ConversionSource.manual;
      _refreshMissingRateCodes(
        VeriFinScope.of(context),
        _availableAccounts(VeriFinScope.of(context)),
      );
    });
  }

  Future<void> _editDerivedRate({
    required String sourceCode,
    required String targetCode,
    required bool transfer,
  }) async {
    final currentTarget = transfer ? _toAccountAmount : _baseAmount;
    final value = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(
        context,
      ).entryRateEditTitle(sourceCode, targetCode),
      initialAmount: currentTarget == null || _amount <= 0
          ? null
          : currentTarget / _amount,
      maxFractionDigits: 10,
    );
    if (!mounted || value == null || value <= 0) return;
    setState(() {
      final targetAmount = normalizeCurrencyAmount(_amount * value, targetCode);
      if (transfer) {
        _toAccountAmount = targetAmount;
        _toAccountAmountTouched = true;
      } else {
        _baseAmount = targetAmount;
        _baseAmountTouched = true;
        final account = _accountFor(
          _availableAccounts(VeriFinScope.of(context)),
          _accountId,
        );
        if (!_noAccount && account?.currencyCode == targetCode) {
          _accountAmount = targetAmount;
          _accountAmountTouched = true;
        }
      }
      _conversionSource = ConversionSource.manual;
      _refreshMissingRateCodes(
        VeriFinScope.of(context),
        _availableAccounts(VeriFinScope.of(context)),
      );
    });
  }

  Future<void> _showAllCategories() async {
    final selected = await showCategoryPickerSheet(
      context,
      categories: _categoriesForType(VeriFinScope.of(context), _type),
      selectedId: _categoryId,
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _categoryId = selected;
      _categoryTouched = true;
    });
  }

  Future<void> _showCategoryBranch(
    Category root,
    List<Category> categories,
  ) async {
    final branchIds = <String>{root.id, ...descendantIds(categories, root.id)};
    final selected = await showCategoryPickerSheet(
      context,
      categories: categories
          .where((category) => branchIds.contains(category.id))
          .toList(),
      selectedId: _categoryId,
      title: AppLocalizations.of(context).entryCategoryBranchTitle(root.label),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _categoryId = selected;
      _categoryTouched = true;
    });
  }

  Future<void> _pickAccount(List<Account> accounts) async {
    final isTransfer = _type == EntryType.transfer;
    final selected = await showAccountPickerSheet(
      context: context,
      title: isTransfer
          ? AppLocalizations.of(context).pickTransferOutAccount
          : AppLocalizations.of(context).pickAccountTitle,
      accounts: accounts,
      selectedId: _noAccount ? '' : _accountId,
      balanceOf: VeriFinScope.of(context).accountBalance,
      // 转账两端都必须是具体账户，故转出账户不提供「无账户」。
      noneLabel: isTransfer
          ? null
          : AppLocalizations.of(context).noAccountLabel,
      noneHint: isTransfer ? null : AppLocalizations.of(context).noAccountHint,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      if (selected.id.isEmpty) {
        _noAccount = true;
        if (!_currencyTouched) {
          _currencyCode = VeriFinScope.of(context).activeBook.baseCurrencyCode;
        }
      } else {
        _noAccount = false;
        _accountId = selected.id;
        if (!_currencyTouched || isTransfer) {
          _currencyCode = selected.currencyCode;
        }
      }
      _normalizeTransferAccounts(accounts);
      _accountAmountTouched = false;
      _toAccountAmountTouched = false;
      _baseAmountTouched = false;
      _rememberRate = false;
      _refreshCurrencyAmounts(
        VeriFinScope.of(context),
        accounts,
        forceAccount: true,
        forceToAccount: true,
        forceBase: true,
      );
    });
  }

  Future<void> _pickToAccount(List<Account> accounts) async {
    final selectableAccounts = accounts
        .where((account) => account.id != _accountId)
        .toList();
    if (selectableAccounts.isEmpty) {
      return;
    }
    final selected = await showAccountPickerSheet(
      context: context,
      title: AppLocalizations.of(context).pickTransferInAccount,
      accounts: selectableAccounts,
      selectedId: _toAccountId,
      balanceOf: VeriFinScope.of(context).accountBalance,
    );
    if (selected != null && mounted) {
      setState(() {
        _toAccountId = selected.id;
        _toAccountAmountTouched = false;
        _refreshCurrencyAmounts(
          VeriFinScope.of(context),
          accounts,
          forceToAccount: true,
        );
      });
    }
  }

  void _normalizeTransferAccounts(List<Account> accounts) {
    if (_type != EntryType.transfer) {
      _toAccountId = null;
      return;
    }
    if (accounts.length < 2) {
      _toAccountId = null;
      return;
    }
    if (_toAccountId == null ||
        _toAccountId == _accountId ||
        !accounts.any((account) => account.id == _toAccountId)) {
      _toAccountId = accounts
          .firstWhere((account) => account.id != _accountId)
          .id;
    }
  }

  bool _canSave(List<Account> accounts) {
    if (_type != EntryType.transfer) {
      // 无账户也可保存（只记金额）；否则需有可选账户。
      final hasAccountAmount =
          _noAccount || (_accountAmount != null && _accountAmount! > 0);
      return (_noAccount || accounts.isNotEmpty) &&
          hasAccountAmount &&
          _baseAmount != null &&
          _baseAmount! > 0;
    }
    if (accounts.isEmpty) {
      return false;
    }
    return _toAccountId != null &&
        _toAccountId != _accountId &&
        _accountAmount != null &&
        _accountAmount! > 0 &&
        _toAccountAmount != null &&
        _toAccountAmount! > 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
      _refreshCurrencyAmounts(
        VeriFinScope.of(context),
        _availableAccounts(VeriFinScope.of(context)),
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _occurredAt = DateTime(
        _occurredAt.year,
        _occurredAt.month,
        _occurredAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _addAttachment({required bool fromCamera}) async {
    final dataUrl = await pickAttachmentDataUrl(fromCamera: fromCamera);
    if (!mounted || dataUrl == null || dataUrl.isEmpty) return;
    setState(() => _pendingAttachments.add(dataUrl));
  }

  Future<void> _pickTags() async {
    final result = await pickEntryTags(
      context: context,
      selectedIds: _tagIds,
      extraTags: widget.draftExtraTags ?? const <Tag>[],
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _tagIds = result;
      _tagsTouched = true;
    });
  }

  LedgerEntry _buildDraftEntry() {
    final original = widget.draftEntry;
    final noAccount = _type != EntryType.transfer && _noAccount;
    final controller = VeriFinScope.of(context);
    final accounts = _availableAccounts(controller);
    final code =
        _currencyCode ??
        _accountFor(accounts, _accountId)?.currencyCode ??
        controller.activeBook.baseCurrencyCode;
    final accountCode = _accountFor(accounts, _accountId)?.currencyCode;
    final toAccountCode = _accountFor(accounts, _toAccountId)?.currencyCode;
    return LedgerEntry(
      id: _entryId,
      bookId: original?.bookId ?? VeriFinScope.of(context).activeBook.id,
      type: _type,
      amount: normalizeCurrencyAmount(_amount, code),
      currencyCode: code,
      accountAmount: noAccount || accountCode == null
          ? null
          : normalizeCurrencyAmount(_accountAmount ?? _amount, accountCode),
      toAccountAmount: _type != EntryType.transfer || toAccountCode == null
          ? null
          : normalizeCurrencyAmount(_toAccountAmount ?? _amount, toAccountCode),
      baseAmount: _type == EntryType.transfer
          ? 0
          : normalizeCurrencyAmount(
              _baseAmount ?? _amount,
              controller.activeBook.baseCurrencyCode,
            ),
      conversionSource: _conversionSource,
      categoryId: _categoryId,
      accountId: noAccount ? '' : _accountId,
      toAccountId: _type == EntryType.transfer ? _toAccountId : null,
      note: _noteController.text.trim(),
      occurredAt: _occurredAt,
      tagIds: List<String>.of(_tagIds),
      fee: _type == EntryType.transfer
          ? normalizeCurrencyAmount(_fee, code)
          : 0,
      reimbursable: _type == EntryType.expense && _reimbursable,
      refundedBaseAmount: original?.refundedBaseAmount ?? 0,
    );
  }

  void _captureInitialSnapshot() {
    _initialEntryDraft ??= _buildDraftEntry();
    _initialAttachmentDataUrls ??= List<String>.of(_pendingAttachments);
  }

  bool _sameDraft(LedgerEntry left, LedgerEntry right) =>
      left.type == right.type &&
      left.amount == right.amount &&
      left.currencyCode == right.currencyCode &&
      left.accountAmount == right.accountAmount &&
      left.toAccountAmount == right.toAccountAmount &&
      left.baseAmount == right.baseAmount &&
      left.conversionSource == right.conversionSource &&
      left.categoryId == right.categoryId &&
      left.accountId == right.accountId &&
      left.toAccountId == right.toAccountId &&
      left.note == right.note &&
      left.occurredAt == right.occurredAt &&
      listEquals(left.tagIds, right.tagIds) &&
      left.fee == right.fee &&
      left.reimbursable == right.reimbursable;

  bool get _isDirty {
    if (_saved) {
      return false;
    }
    // Reaching a new-entry page means the user already entered or supplied a
    // draft amount; the not-yet-created entity itself is pending work.
    if (!_isDraft) {
      return true;
    }
    final initial = _initialEntryDraft;
    final initialAttachments = _initialAttachmentDataUrls;
    if (initial == null || initialAttachments == null) {
      return false;
    }
    return !_sameDraft(initial, _buildDraftEntry()) ||
        !listEquals(initialAttachments, _pendingAttachments);
  }

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      _exitController.exit(result: () => _savedResult);
    }
  }

  Future<bool> _save() async {
    if (_saving) {
      return false;
    }
    final controller = VeriFinScope.of(context);
    final accounts =
        (_isDraft
                ? <Account>[
                    ...controller.accounts,
                    ...widget.draftExtraAccounts!,
                  ]
                : controller.accounts)
            .where((account) => !account.hidden)
            .toList();
    if (!_canSave(accounts)) {
      return false;
    }
    final draft = _buildDraftEntry();
    // 草稿编辑模式：不落库，构造修改后的交易并回传给上层（如导入预览页）。
    if (_isDraft) {
      _saving = true;
      _savedResult = draft;
      _saved = true;
      return true;
    }
    if (draft.accountId.isNotEmpty &&
        !controller.accounts
            .where((account) => !account.hidden)
            .any((account) => account.id == draft.accountId)) {
      return false;
    }
    _saving = true;
    final attachments = <Attachment>[
      for (var index = 0; index < _pendingAttachments.length; index++)
        Attachment(
          id: 'att_${_entryId}_$index',
          entryId: _entryId,
          dataUrl: _pendingAttachments[index],
        ),
    ];
    final result = await controller.saveEntryAggregateDraftResult(
      entry: draft,
      isNew: true,
      attachments: attachments,
      rememberRateCurrencyCode: _rememberRate ? draft.currencyCode : null,
      rememberRateToBase: _rememberRate
          ? draft.baseAmount / draft.amount
          : null,
      rememberRateEffectiveDate: _rememberRate ? draft.occurredAt : null,
    );
    if (!result.isSuccess) {
      _saving = false;
      if (result is EntrySaveValidationFailure && mounted) {
        unawaited(
          VeriFeedbackHost.of(context).showMessage(
            message: AppLocalizations.of(context).entrySaveValidationFailed,
            tone: VeriFeedbackTone.warning,
            duration: VeriFeedbackDuration.long,
          ),
        );
      }
      return false;
    }
    _saved = true;
    return true;
  }
}

/// AI 记账草稿的复核提示条：说明这是 AI 解析结果，并列出降级提示（分类/账户未匹配）。
class _AiReviewBanner extends StatelessWidget {
  const _AiReviewBanner({required this.draft});

  final AiEntryDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(veriRadiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_awesome, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.aiEntryReviewHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          for (final warning in draft.warnings) ...<Widget>[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                aiDraftWarningLabel(l10n, warning),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 把解析降级提示码本地化为一句提示文案。
String aiDraftWarningLabel(AppLocalizations l10n, AiDraftWarning warning) {
  switch (warning) {
    case AiDraftWarning.categoryUnmatched:
      return l10n.aiWarningCategoryUnmatched;
    case AiDraftWarning.accountUnmatched:
      return l10n.aiWarningAccountUnmatched;
    case AiDraftWarning.currencyUnmatched:
      return l10n.aiWarningCurrencyUnmatched;
  }
}

class _EntryBottomSaveBar extends StatelessWidget {
  const _EntryBottomSaveBar({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ColoredBox(
        key: const Key('entry_bottom_save_bar'),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          key: const Key('entry_bottom_save_padding'),
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
          child: FilledButton(
            key: const Key('save_entry_button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder(),
              textStyle: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            onPressed: enabled ? onPressed : null,
            child: Text(AppLocalizations.of(context).commonSave),
          ),
        ),
      ),
    );
  }
}

class _EntryTypeSelector extends StatelessWidget {
  const _EntryTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final EntryType selected;
  final ValueChanged<EntryType> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(veriRadiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: <Widget>[
            for (final type in EntryType.userSelectable)
              Expanded(
                child: _EntryTypeButton(
                  type: type,
                  selected: selected == type,
                  onTap: () => onChanged(type),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryTypeButton extends StatelessWidget {
  const _EntryTypeButton({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final EntryType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = switch (type) {
      EntryType.expense => veriExpense,
      EntryType.income => veriIncome,
      EntryType.transfer => veriRoyal,
      EntryType.refund => veriIncome,
    };
    return Material(
      key: selected ? Key('entry_type_selected_${type.name}') : null,
      color: selected ? scheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: InkWell(
        key: Key('entry_type_${type.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(veriRadiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            type.label(AppLocalizations.of(context)),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? accent
                  : scheme.onSurface.withValues(alpha: 0.48),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryCategoryGrid extends StatelessWidget {
  const _EntryCategoryGrid({
    required this.categories,
    required this.selectedTopId,
    required this.selectedLabel,
    required this.accent,
    required this.hasChildren,
    required this.onSelected,
    required this.onOpenBranch,
    required this.onOpenAll,
    required this.allLabel,
  });

  final List<Category> categories;
  final String selectedTopId;
  final String? selectedLabel;
  final Color accent;
  final bool Function(Category category) hasChildren;
  final ValueChanged<Category> onSelected;
  final ValueChanged<Category> onOpenBranch;
  final VoidCallback onOpenAll;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const Key('entry_category_grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 6,
        mainAxisExtent: 40,
      ),
      itemBuilder: (context, index) {
        if (index == categories.length) {
          return _EntryAllCategoryTile(label: allLabel, onTap: onOpenAll);
        }
        final category = categories[index];
        final selected = selectedTopId == category.id;
        return _EntryCategoryTile(
          category: category,
          displayLabel:
              selected && selectedLabel != null && selectedLabel!.isNotEmpty
              ? selectedLabel!
              : category.label,
          selected: selected,
          accent: accent,
          onTap: () => onSelected(category),
          onOpenBranch: selected && hasChildren(category)
              ? () => onOpenBranch(category)
              : null,
        );
      },
    );
  }
}

class _EntryCategoryTile extends StatelessWidget {
  const _EntryCategoryTile({
    required this.category,
    required this.displayLabel,
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.onOpenBranch,
  });

  final Category category;
  final String displayLabel;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onOpenBranch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Align(
          child: SizedBox(
            height: 31,
            width: double.infinity,
            child: AnimatedContainer(
              key: selected
                  ? Key('entry_category_selected_${category.id}')
                  : null,
              duration: const Duration(milliseconds: 160),
              decoration: ShapeDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.08)
                    : scheme.surfaceContainerLow,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: selected
                        ? accent.withValues(alpha: 0.50)
                        : scheme.outlineVariant.withValues(alpha: 0.58),
                  ),
                ),
              ),
              child: Material(
                key: Key('entry_category_capsule_${category.id}'),
                color: Colors.transparent,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('entry_category_${category.id}'),
                  customBorder: const StadiumBorder(),
                  onTap: onTap,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        CategoryGlyph(
                          iconCode: category.iconCode,
                          size: 16,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: selected ? accent : scheme.onSurface,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (onOpenBranch != null)
          Positioned(
            right: -1,
            bottom: 0,
            child: Material(
              color: accent,
              elevation: 1,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('entry_category_more_${category.id}'),
                customBorder: const CircleBorder(),
                onTap: onOpenBranch,
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EntryAllCategoryTile extends StatelessWidget {
  const _EntryAllCategoryTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      child: SizedBox(
        height: 31,
        width: double.infinity,
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('entry_category_all'),
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.grid_view_rounded,
                  size: 16,
                  color: scheme.onSurface.withValues(alpha: 0.48),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.56),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryMetadataChip extends StatelessWidget {
  const _EntryMetadataChip({
    required this.chipKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final Key chipKey;
  final IconData icon;
  final Widget label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? veriRoyal : scheme.onSurface;
    return Material(
      color: selected
          ? veriRoyal.withValues(alpha: 0.10)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        key: chipKey,
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: color.withValues(alpha: onTap == null ? 0.36 : 0.72),
              ),
              const SizedBox(width: 5),
              DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color.withValues(
                    alpha: onTap == null ? 0.36 : (selected ? 0.92 : 0.68),
                  ),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
                child: label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
