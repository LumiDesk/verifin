import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/currency_catalog.dart';
import '../app/currency_math.dart';
import '../app/icon_catalog.dart';
import '../app/entry_sheets.dart';
import '../app/feedback.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/net_security.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'account_icon_picker.dart';

/// 保留现有 Sheet 语义，仅在材质预览中为内容加入共享玻璃层。
Future<T?> _showVeriModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool? showDragHandle,
  bool isScrollControlled = false,
  Color? backgroundColor,
  ShapeBorder? shape,
}) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: showDragHandle,
  isScrollControlled: isScrollControlled,
  backgroundColor: veriGlassDesignPreview
      ? Colors.transparent
      : backgroundColor,
  shape: shape,
  builder: (context) => VeriGlassSurface(
    grouped: false,
    radius: veriRadiusXl,
    child: builder(context),
  ),
);

/// 若 [url] 会以明文 http 把凭证发往公网主机，弹确认对话框让用户知情后再继续；
/// 非风险地址（https / 本机 / 内网）直接返回 true。用户取消返回 false。
Future<bool> confirmCleartextIfRisky(BuildContext context, String url) async {
  if (!isCleartextCredentialRisk(url)) return true;
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.cleartextWarnTitle),
      content: Text(l10n.cleartextWarnBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.cleartextWarnContinue),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// 通用单选底部弹窗。[sectionOf] 非空时按其返回的分区标题给选项加小标题分组
/// （相邻同分区归为一组、分区变化处插入小标题），供筛选场景把「快捷项」与
/// 「具体项」分区展示（如标签筛选的「快捷筛选 / 标签」两组）。
Future<T?> showOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> values,
  required T selected,
  required String Function(T value) labelOf,
  bool showSelectedMarker = true,
  String Function(T value)? sectionOf,
}) {
  return _showVeriModalSheet<T>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
      final headerColor = Theme.of(context).colorScheme.onSurfaceVariant;
      final children = <Widget>[];
      String? currentSection;
      for (final value in values) {
        if (sectionOf != null) {
          final section = sectionOf(value);
          if (section != currentSection) {
            currentSection = section;
            children.add(
              Padding(
                padding: EdgeInsets.only(
                  left: 10,
                  right: 10,
                  top: children.isEmpty ? 2 : 12,
                  bottom: 4,
                ),
                child: Text(
                  section,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: headerColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            );
          }
        }
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: showSelectedMarker && value == selected
                  ? veriRoyal.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(veriRadiusSm),
              child: ListTile(
                minTileHeight: 44,
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(veriRadiusSm),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                title: Text(
                  labelOf(value),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: showSelectedMarker && value == selected
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
                trailing: showSelectedMarker && value == selected
                    ? const Icon(Icons.check, color: veriRoyal, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(value),
              ),
            ),
          ),
        );
      }
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(child: ListView(shrinkWrap: true, children: children)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 可搜索的离线 ISO 4217 法定货币选择器。列表按常用币种、调用方提供的
/// [preferredCodes] 与代码顺序排列；取消返回 null。
Future<CurrencyDefinition?> showCurrencyPickerSheet({
  required BuildContext context,
  required String title,
  String? selectedCode,
  Iterable<String> preferredCodes = const <String>[],
  Iterable<String> excludedCodes = const <String>[],
}) {
  return _showVeriModalSheet<CurrencyDefinition>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (context) => _CurrencyPickerSheet(
      title: title,
      selectedCode: selectedCode?.toUpperCase(),
      preferredCodes: preferredCodes.map((code) => code.toUpperCase()).toList(),
      excludedCodes: excludedCodes.map((code) => code.toUpperCase()).toSet(),
    ),
  );
}

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({
    required this.title,
    required this.selectedCode,
    required this.preferredCodes,
    required this.excludedCodes,
  });

  final String title;
  final String? selectedCode;
  final List<String> preferredCodes;
  final Set<String> excludedCodes;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CurrencyDefinition> get _currencies {
    final result = CurrencyCatalog.search(
      _query,
    ).where((item) => !widget.excludedCodes.contains(item.code)).toList();
    if (_query.trim().isNotEmpty || widget.preferredCodes.isEmpty) {
      return result;
    }
    final preferredRank = <String, int>{
      for (final item in widget.preferredCodes.indexed) item.$2: item.$1,
    };
    result.sort((a, b) {
      final aRank = preferredRank[a.code];
      final bRank = preferredRank[b.code];
      if (aRank != null || bRank != null) {
        return (aRank ?? preferredRank.length).compareTo(
          bRank ?? preferredRank.length,
        );
      }
      final aCommon = CurrencyCatalog.commonCodes.indexOf(a.code);
      final bCommon = CurrencyCatalog.commonCodes.indexOf(b.code);
      if (aCommon != -1 || bCommon != -1) {
        return (aCommon == -1 ? CurrencyCatalog.commonCodes.length : aCommon)
            .compareTo(
              bCommon == -1 ? CurrencyCatalog.commonCodes.length : bCommon,
            );
      }
      return a.code.compareTo(b.code);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final currencies = _currencies;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('currency_search_field'),
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.currencySearchHint,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.commonClear,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: currencies.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        title: l10n.currencySearchEmpty,
                        description: l10n.currencySearchEmptyDesc,
                      )
                    : ListView.separated(
                        itemCount: currencies.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final currency = currencies[index];
                          final selected = currency.code == widget.selectedCode;
                          return ListTile(
                            key: Key('currency_option_${currency.code}'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            leading: SizedBox(
                              width: 48,
                              child: Text(
                                currency.code,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            title: Text(currency.nameForLocale(localeName)),
                            subtitle: Text(
                              l10n.currencyPickerMeta(
                                currency.symbol,
                                currency.minorUnit,
                              ),
                            ),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: veriRoyal,
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(currency),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 新建账本表单，同时收集名称与本位币。
Future<({String name, String currencyCode})?> showLedgerBookEditorSheet({
  required BuildContext context,
  required String initialCurrencyCode,
}) {
  return _showVeriModalSheet<({String name, String currencyCode})>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        _LedgerBookEditorSheet(initialCurrencyCode: initialCurrencyCode),
  );
}

class _LedgerBookEditorSheet extends StatefulWidget {
  const _LedgerBookEditorSheet({required this.initialCurrencyCode});

  final String initialCurrencyCode;

  @override
  State<_LedgerBookEditorSheet> createState() => _LedgerBookEditorSheetState();
}

class _LedgerBookEditorSheetState extends State<_LedgerBookEditorSheet> {
  final TextEditingController _nameController = TextEditingController();
  late String _currencyCode = widget.initialCurrencyCode;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = CurrencyCatalog.require(_currencyCode);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.bookAdd,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ledger_book_name_field'),
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.bookNameLabel),
            ),
            const SizedBox(height: 10),
            SelectField(
              label: l10n.ledgerBaseCurrency,
              value:
                  '${currency.code} · ${currency.nameForLocale(Localizations.localeOf(context).toLanguageTag())}',
              icon: Icons.currency_exchange,
              onTap: _pickCurrency,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.ledgerBaseCurrencyDesc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('ledger_book_save_button'),
                onPressed: _nameController.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop((
                        name: _nameController.text.trim(),
                        currencyCode: _currencyCode,
                      )),
                child: Text(l10n.commonConfirm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCurrency() async {
    final selected = await showCurrencyPickerSheet(
      context: context,
      title: AppLocalizations.of(context).selectBaseCurrency,
      selectedCode: _currencyCode,
    );
    if (selected != null && mounted) {
      setState(() => _currencyCode = selected.code);
    }
  }
}

enum _LegacyCurrencyAction { confirmCurrent, chooseAnother }

/// 旧单币种账本的一次性确认流程。返回 true 表示账本已完成确认；取消或失败返回 false。
Future<bool> confirmLegacyLedgerCurrency({
  required BuildContext context,
  required LedgerBook book,
}) async {
  if (book.currencySetupStatus == CurrencySetupStatus.confirmed) return true;
  final l10n = AppLocalizations.of(context);
  final action = await showOptionSheet<_LegacyCurrencyAction>(
    context: context,
    title: l10n.legacyCurrencySetupTitle,
    values: _LegacyCurrencyAction.values,
    selected: _LegacyCurrencyAction.confirmCurrent,
    showSelectedMarker: false,
    labelOf: (value) => switch (value) {
      _LegacyCurrencyAction.confirmCurrent => l10n.legacyCurrencyConfirmCurrent(
        book.baseCurrencyCode,
      ),
      _LegacyCurrencyAction.chooseAnother => l10n.legacyCurrencyChooseAnother,
    },
  );
  if (!context.mounted || action == null) return false;

  var code = book.baseCurrencyCode;
  if (action == _LegacyCurrencyAction.chooseAnother) {
    final selected = await showCurrencyPickerSheet(
      context: context,
      title: l10n.selectBaseCurrency,
      selectedCode: code,
    );
    if (!context.mounted || selected == null) return false;
    code = selected.code;
  }

  final controller = VeriFinScope.of(context);
  final impact = controller.currencyReinterpretImpact(book.id);
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.legacyCurrencyConfirmTitle(code),
    message: l10n.legacyCurrencyConfirmMessage(
      impact.accounts,
      impact.entries,
      impact.recurringRules,
      impact.budgetSettings,
      code,
    ),
    confirmLabel: l10n.legacyCurrencyApply,
  );
  if (!context.mounted || !confirmed) return false;
  final saved = await controller.reinterpretLegacyLedgerBookCurrency(
    book.id,
    code,
  );
  if (!context.mounted) return saved;
  unawaited(
    VeriFeedbackHost.of(context).showMessage(
      message: saved ? l10n.legacyCurrencySaved(code) : l10n.saveFailed,
      tone: saved ? VeriFeedbackTone.success : VeriFeedbackTone.error,
      duration: saved
          ? VeriFeedbackDuration.standard
          : VeriFeedbackDuration.long,
      priority: saved ? VeriFeedbackPriority.normal : VeriFeedbackPriority.high,
      dedupeKey: saved ? null : 'legacy-currency-save',
    ),
  );
  return saved;
}

enum _BudgetOverrideAction { edit, clear }

/// 总预算的单期覆盖入口。默认值在预算设置页管理；此处只修改或清除所选键月的
/// 覆盖值。自然月显示「本月」，自定义预算周期显示「本期」。
Future<void> showMonthlyBudgetOverrideSheet({
  required BuildContext context,
  required DateTime month,
}) async {
  final controller = VeriFinScope.of(context);
  await _showBudgetOverrideSheet(
    context: context,
    month: month,
    subject: AppLocalizations.of(context).budgetTitle,
    isOverride: controller.monthlyBudgetIsOverride(month),
    defaultBudget: controller.defaultMonthlyBudget,
    currentBudget: controller.monthlyBudget(month),
    setOverride: (amount) => controller.setMonthlyBudget(month, amount),
    clearOverride: () => controller.clearMonthlyBudgetOverride(month),
  );
}

/// 分类预算的单期覆盖入口。用于预算总览的分类行；分类默认预算仍由预算设置页
/// 管理，清除覆盖后回落默认值（没有默认值时回落 0）。
Future<void> showCategoryBudgetOverrideSheet({
  required BuildContext context,
  required DateTime month,
  required Category category,
}) async {
  final controller = VeriFinScope.of(context);
  await _showBudgetOverrideSheet(
    context: context,
    month: month,
    subject: category.label,
    isOverride: controller.categoryBudgetIsOverride(month, category.id),
    defaultBudget: controller.defaultCategoryBudget(category.id),
    currentBudget: controller.categoryBudget(month, category.id),
    setOverride: (amount) =>
        controller.setCategoryBudget(month, category.id, amount),
    clearOverride: () =>
        controller.clearCategoryBudgetOverride(month, category.id),
  );
}

/// 总预算与分类预算共用的单期覆盖流程，统一动作菜单、周期文案和数字键盘。
Future<void> _showBudgetOverrideSheet({
  required BuildContext context,
  required DateTime month,
  required String subject,
  required bool isOverride,
  required double defaultBudget,
  required double currentBudget,
  required ValueChanged<double> setOverride,
  required VoidCallback clearOverride,
}) async {
  final controller = VeriFinScope.of(context);
  final l10n = AppLocalizations.of(context);
  final customPeriod = controller.budgetCycleIsCustom;
  final scope = customPeriod
      ? l10n.budgetOverrideScopePeriod
      : l10n.budgetOverrideScopeMonth;
  final window = controller.budgetWindow(month);
  final periodLabel = customPeriod
      ? l10n.budgetCycleRange(window.start, window.end)
      : l10n.yearMonth(month);
  final actions = <_BudgetOverrideAction>[
    _BudgetOverrideAction.edit,
    if (isOverride) _BudgetOverrideAction.clear,
  ];

  final action = await showOptionSheet<_BudgetOverrideAction>(
    context: context,
    title: l10n.budgetOverrideSheetTitle(subject, periodLabel),
    values: actions,
    selected: _BudgetOverrideAction.edit,
    showSelectedMarker: false,
    labelOf: (value) => switch (value) {
      _BudgetOverrideAction.edit =>
        isOverride
            ? l10n.budgetOverrideAdjustAmount(scope)
            : l10n.budgetOverrideSetAmount(scope),
      _BudgetOverrideAction.clear =>
        defaultBudget > 0
            ? l10n.budgetOverrideRestore(formatAmount(defaultBudget))
            : l10n.budgetOverrideClear(scope),
    },
  );
  if (!context.mounted || action == null) {
    return;
  }
  if (action == _BudgetOverrideAction.clear) {
    clearOverride();
    return;
  }

  final amount = await showNumberPadSheet(
    context,
    title: l10n.budgetOverrideAmountTitle(scope),
    initialAmount: currentBudget > 0 ? currentBudget : null,
    allowZero: true,
    currencyCode: VeriFinScope.of(context).activeBook.baseCurrencyCode,
  );
  if (amount != null && context.mounted) {
    setOverride(amount);
  }
}

/// 数字键盘弹窗:统一的金额输入入口(四则算式 + 结果预览)。触感偏好由内部从
/// [VeriFinScope] 取,调用方不用手传。返回所输金额;取消返回 null。
/// [allowNegative] 允许负数,[allowZero] 允许 0(如清除预算 / 手续费)。
Future<double?> showNumberPadSheet(
  BuildContext context, {
  required String title,
  double? initialAmount,
  bool allowNegative = false,
  bool allowZero = false,
  double? maxAmount,
  int? maxFractionDigits,
  String? currencyCode,
}) {
  final hapticsEnabled = VeriFinScope.of(context).hapticsEnabled;
  final resolvedFractionDigits =
      maxFractionDigits ??
      (currencyCode == null
          ? 2
          : CurrencyCatalog.require(currencyCode).minorUnit);
  return _showVeriModalSheet<double>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => NumberPadSheet(
      title: title,
      initialAmount: initialAmount,
      allowNegative: allowNegative,
      allowZero: allowZero,
      hapticsEnabled: hapticsEnabled,
      maxAmount: maxAmount,
      maxFractionDigits: resolvedFractionDigits,
      currencyCode: currencyCode,
    ),
  );
}

/// 多级分类选择弹窗:统一的分类选择入口(带图标、可折叠父子层级)。返回所选分类
/// id;取消返回 null。[allLabel] 非空时顶部加「全部」项(筛选用)→ 返回
/// [categoryPickerAll];[topLevelLabel] 非空时加「移到顶级」→ 返回
/// [categoryPickerTopLevel]。[categories] 由调用方按类型过滤后传入(筛选场景可传全部)。
Future<String?> showCategoryPickerSheet(
  BuildContext context, {
  required List<Category> categories,
  required String selectedId,
  String? title,
  String? topLevelLabel,
  String? allLabel,
}) {
  return _showVeriModalSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (_) => CategoryPickerSheet(
      categories: categories,
      selectedId: selectedId,
      title: title,
      topLevelLabel: topLevelLabel,
      allLabel: allLabel,
    ),
  );
}

/// 选「全部账户」（筛选场景）时返回的哨兵 [Account]，其 id 为 [accountPickerAllId]。
const String accountPickerAllId = '__account_picker_all__';
const Account _accountPickerAllSentinel = Account(
  id: accountPickerAllId,
  bookId: '',
  name: '',
  type: AccountType.cash,
  groupId: null,
  initialBalance: 0,
  iconCode: 'wallet',
  note: '',
  includeInAssets: false,
  hidden: false,
);

/// 账户选择弹窗:与资产页账户列表一致,展示账户图标、名称(含卡号后四位)和余额,并
/// **按当前资产视图模式分区**（类型视图→按账户类型；分组视图→按用户分组+未分组），
/// 分区顺序与区内账户顺序都与资产页一致。返回所选账户；用户取消返回 null。
/// 传入 [noneLabel] 时，列表顶部额外提供「无账户」选项，选它返回 id 为空串的
/// 哨兵 [Account]（调用方用 `selected.id.isEmpty` 判别「只记金额、不计入账户」）。
/// 传入 [allLabel] 时（筛选场景），列首额外提供「全部」项，选它返回 id 为
/// [accountPickerAllId] 的哨兵 [Account]（调用方用 `selected.id == accountPickerAllId` 判别）。
Future<Account?> showAccountPickerSheet({
  required BuildContext context,
  required String title,
  required List<Account> accounts,
  required String? selectedId,
  required double Function(Account account) balanceOf,
  String? noneLabel,
  String? noneHint,
  String? allLabel,
}) {
  return _showVeriModalSheet<Account>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (context) {
      final controller = VeriFinScope.of(context);
      final l10n = AppLocalizations.of(context);
      final sections = _accountPickerSections(controller, l10n, accounts);
      final headerColor = Theme.of(context).colorScheme.onSurfaceVariant;
      final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

      final children = <Widget>[];
      if (noneLabel != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _NoneAccountRow(
              label: noneLabel,
              hint: noneHint,
              selected: (selectedId ?? '').isEmpty,
            ),
          ),
        );
      }
      if (allLabel != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _AllAccountsRow(
              label: allLabel,
              selected: selectedId == accountPickerAllId,
            ),
          ),
        );
      }
      for (var s = 0; s < sections.length; s++) {
        final section = sections[s];
        children.add(
          Padding(
            padding: EdgeInsets.only(
              left: 10,
              right: 10,
              top: s == 0 && children.isEmpty ? 2 : 12,
              bottom: 4,
            ),
            child: Text(
              section.title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: headerColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        );
        for (final account in section.accounts) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _AccountPickerRow(
                account: account,
                balance: balanceOf(account),
                selected: account.id == selectedId,
              ),
            ),
          );
        }
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(child: ListView(shrinkWrap: true, children: children)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 账户选择器分区：按当前资产视图模式（类型/分组）把 [accounts] 分区并排序，顺序与
/// 资产页完全一致——复用 controller 的 `sortedAssetSections` / `sortedAccountsForAssetSection`
/// （这两处排序偏好随备份还原，见导出的 `assetAccountOrders`/`assetSectionOrders`）。空区剔除。
List<({String title, List<Account> accounts})> _accountPickerSections(
  VeriFinController controller,
  AppLocalizations l10n,
  List<Account> accounts,
) {
  final mode = controller.assetAccountViewMode;
  final result = <({String title, List<Account> accounts})>[];
  if (mode == AssetAccountViewMode.group) {
    final ordered = controller.sortedAssetSections<AccountGroup>(
      mode: mode,
      sections: <AccountGroup>[
        ...controller.accountGroups,
        AccountGroup(
          id: 'ungrouped',
          bookId: controller.activeBook.id,
          name: l10n.assetsUngrouped,
          sortOrder: 999,
        ),
      ],
      idOf: (group) => group.id,
    );
    for (final group in ordered) {
      final inGroup = controller.sortedAccountsForAssetSection(
        mode: mode,
        sectionId: group.id,
        accounts: accounts.where(
          (account) => (account.groupId ?? 'ungrouped') == group.id,
        ),
      );
      if (inGroup.isNotEmpty) {
        result.add((title: group.name, accounts: inGroup));
      }
    }
  } else {
    final ordered = controller.sortedAssetSections<AccountType>(
      mode: mode,
      sections: AccountType.values,
      idOf: (type) => type.name,
    );
    for (final type in ordered) {
      final inType = controller.sortedAccountsForAssetSection(
        mode: mode,
        sectionId: type.name,
        accounts: accounts.where((account) => account.type == type),
      );
      if (inType.isNotEmpty) {
        result.add((title: type.label(l10n), accounts: inType));
      }
    }
  }
  return result;
}

class _AccountPickerRow extends StatelessWidget {
  const _AccountPickerRow({
    required this.account,
    required this.balance,
    required this.selected,
  });

  final Account account;
  final double balance;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? veriRoyal.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: ListTile(
        minTileHeight: 48,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(veriRadiusSm),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: AccountIconBox(iconCode: account.iconCode, size: 32),
        title: Text.rich(
          TextSpan(
            text: account.name,
            children: <TextSpan>[
              if (account.cardLast4.isNotEmpty &&
                  account.type.supportsCardLast4)
                TextSpan(
                  text: ' (${account.cardLast4})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.42),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              formatUserMoney(balance, account.currencyCode),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: accountBalanceColor(context, account, balance),
                fontWeight: FontWeight.w800,
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: 6),
              const Icon(Icons.check, color: veriRoyal, size: 18),
            ],
          ],
        ),
        onTap: () => Navigator.of(context).pop(account),
      ),
    );
  }
}

/// 「无账户」选项：选它记一笔纯金额、不计入任何账户余额。返回 id 为空的哨兵账户。
class _NoneAccountRow extends StatelessWidget {
  const _NoneAccountRow({
    required this.label,
    required this.hint,
    required this.selected,
  });

  final String label;
  final String? hint;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? veriRoyal.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: ListTile(
        minTileHeight: 48,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(veriRadiusSm),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: VeriIconBox(
          icon: Icons.money_off_csred_outlined,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          size: 32,
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        subtitle: hint == null
            ? null
            : Text(
                hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
        trailing: selected
            ? const Icon(Icons.check, color: veriRoyal, size: 18)
            : null,
        onTap: () => Navigator.of(context).pop(
          const Account(
            id: '',
            bookId: '',
            name: '',
            type: AccountType.cash,
            groupId: null,
            initialBalance: 0,
            iconCode: 'wallet',
            note: '',
            includeInAssets: false,
            hidden: false,
          ),
        ),
      ),
    );
  }
}

/// 「全部账户」选项（筛选场景）：中性图标、选中返回 [_accountPickerAllSentinel]。
class _AllAccountsRow extends StatelessWidget {
  const _AllAccountsRow({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? veriRoyal.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: ListTile(
        minTileHeight: 48,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(veriRadiusSm),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: VeriIconBox(
          icon: Icons.select_all,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 32,
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check, color: veriRoyal, size: 18)
            : null,
        onTap: () => Navigator.of(context).pop(_accountPickerAllSentinel),
      ),
    );
  }
}

/// 账户图标选择器稳定入口；具体分组、搜索与网格实现在
/// `account_icon_picker.dart`，页面仍只从 `sheets.dart` 调用。
Future<String?> showAccountIconSheet({
  required BuildContext context,
  required String selected,
}) {
  return showAccountIconPickerSheet(context: context, selected: selected);
}

/// 分类图标常用 emoji 快选（覆盖餐饮/出行/居家/娱乐/人情/理财等常见分类）。
const List<String> categoryEmojiChoices = <String>[
  '🍜',
  '🍔',
  '🍚',
  '🥗',
  '🍎',
  '☕',
  '🍺',
  '🍷',
  '🧋',
  '🍰',
  '🍦',
  '🛒',
  '🛍️',
  '👕',
  '👗',
  '👟',
  '💄',
  '✂️',
  '🚌',
  '🚗',
  '🚕',
  '⛽',
  '🚉',
  '✈️',
  '🅿️',
  '🚲',
  '🏠',
  '🔑',
  '💡',
  '💧',
  '📱',
  '📶',
  '🔧',
  '🛋️',
  '🧺',
  '🎮',
  '🎬',
  '🎵',
  '⚽',
  '🏋️',
  '📚',
  '🎓',
  '🐱',
  '🐶',
  '🍼',
  '🎁',
  '🧧',
  '❤️',
  '💊',
  '🏥',
  '💰',
  '💵',
  '💳',
  '🧾',
  '📈',
  '💼',
  '🎉',
  '⭐',
  '🔥',
  '🏦',
];

/// 分类图标选择器：内置图标网格 + 常用 emoji 快选 + 自由输入 emoji。
/// 返回选中的 iconCode（内置 code 或 `emoji:` 前缀的自定义 emoji）；取消返回 null。
Future<String?> showCategoryIconPickerSheet({
  required BuildContext context,
  required String selected,
}) {
  return _showVeriModalSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (context) => _CategoryIconPickerBody(selected: selected),
  );
}

class _CategoryIconPickerBody extends StatefulWidget {
  const _CategoryIconPickerBody({required this.selected});

  final String selected;

  @override
  State<_CategoryIconPickerBody> createState() =>
      _CategoryIconPickerBodyState();
}

class _CategoryIconPickerBodyState extends State<_CategoryIconPickerBody> {
  final TextEditingController _emojiController = TextEditingController();

  @override
  void dispose() {
    _emojiController.dispose();
    super.dispose();
  }

  void _submitEmoji() {
    final text = _emojiController.text.trim();
    if (text.isEmpty) {
      return;
    }
    // 取首个字形簇，兼容多码位 emoji（如带肤色/ZWJ 的组合）。
    Navigator.of(context).pop(emojiIconCode(text.characters.first));
  }

  /// 自适应列数的图标网格：按可用宽度均匀铺满，避免右侧留白不均。
  Widget _iconGrid(List<Widget> cells) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 56,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: cells.length,
      itemBuilder: (context, index) => cells[index],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.pickIconTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _sectionTitle(l10n.iconSectionBuiltin),
                      _iconGrid(<Widget>[
                        for (final code in categoryIconCodes)
                          _IconChoiceCell(
                            selected: widget.selected == code,
                            onTap: () => Navigator.of(context).pop(code),
                            child: CategoryIconBox(iconCode: code, size: 36),
                          ),
                      ]),
                      _sectionTitle(l10n.iconSectionEmoji),
                      _iconGrid(<Widget>[
                        for (final emoji in categoryEmojiChoices)
                          _IconChoiceCell(
                            selected: widget.selected == emojiIconCode(emoji),
                            onTap: () =>
                                Navigator.of(context).pop(emojiIconCode(emoji)),
                            child: CategoryIconBox(
                              iconCode: emojiIconCode(emoji),
                              size: 36,
                            ),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _emojiController,
                              decoration: InputDecoration(
                                hintText: l10n.iconEmojiHint,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _submitEmoji(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _submitEmoji,
                            child: Text(l10n.iconEmojiUse),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 图标选择格子：统一尺寸 + 选中态描边。
class _IconChoiceCell extends StatelessWidget {
  const _IconChoiceCell({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(veriRadiusMd),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(veriRadiusMd),
          border: Border.all(
            color: selected
                ? veriRoyal
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.10),
            width: selected ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  required String label,
  String initialValue = '',
  bool allowEmpty = false,
  TextInputType? keyboardType,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(AppLocalizations.of(context).commonConfirm),
        ),
      ],
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  final trimmed = result?.trim();
  if (trimmed == null || (!allowEmpty && trimmed.isEmpty)) {
    return null;
  }
  return trimmed;
}

/// 编辑完整卡号 + 后四位（含「后四位跟随卡号」开关）。确认返回归一化后的两值与开关态，
/// 取消返回 null。开关态由调用方持久化（`Account.cardLast4Follows`），不再靠反推。
Future<({String number, String last4, bool follows})?> showCardNumberDialog({
  required BuildContext context,
  required String initialNumber,
  required String initialLast4,
  required bool initialFollows,
}) async {
  final numberController = TextEditingController(text: initialNumber);
  final last4Controller = TextEditingController(text: initialLast4);
  var follows = initialFollows;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(AppLocalizations.of(context).cardNumberTitle),
        content: SingleChildScrollView(
          child: CardNumberFields(
            numberController: numberController,
            last4Controller: last4Controller,
            follows: follows,
            onFollowsChanged: (value) => setState(() => follows = value),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).commonConfirm),
          ),
        ],
      ),
    ),
  );
  final number = numberController.text.trim();
  final last4 = cardLast4Of(last4Controller.text);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    numberController.dispose();
    last4Controller.dispose();
  });
  if (confirmed != true) {
    return null;
  }
  return (number: number, last4: last4, follows: follows);
}

/// Executes the explicit hide/delete command and returns whether the account
/// detail editor should exit. The caller owns page navigation so an unsaved
/// changes guard cannot reinterpret this completed command as a back action.
Future<bool> confirmDeleteAccount(
  BuildContext context,
  Account account,
  List<LedgerEntry> entries,
) async {
  final controller = VeriFinScope.of(context);
  final l10n = AppLocalizations.of(context);
  // 弹层随后会 pop，提前抓住根级反馈控制器，确保路由退出后仍能提示被停用的规则。
  // 用于删账户后提示被停用的周期规则。
  final feedback = VeriFeedbackHost.of(context);
  void notifyDisabledRules(int affected) {
    if (affected > 0) {
      unawaited(
        feedback.showMessage(
          message: l10n.accountRecurringRulesDisabled(affected),
          tone: VeriFeedbackTone.warning,
          duration: VeriFeedbackDuration.long,
        ),
      );
    }
  }

  if (entries.isNotEmpty) {
    final action = await showDialog<AccountDeleteAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountHandleTitle),
        content: Text(l10n.accountHandleMessage(account.name, entries.length)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(AccountDeleteAction.hide),
            child: Text(l10n.accountHide),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(AccountDeleteAction.delete),
            style: FilledButton.styleFrom(backgroundColor: veriExpense),
            child: Text(l10n.accountDeleteWithEntries),
          ),
        ],
      ),
    );
    if (!context.mounted || action == null) {
      return false;
    }
    if (action == AccountDeleteAction.hide) {
      return controller.saveAccountDraft(account.copyWith(hidden: true));
    }
    final affected = await controller.deleteAccountAndRelatedEntries(
      account.id,
    );
    if (!context.mounted || affected == null) {
      return false;
    }
    notifyDisabledRules(affected);
    return true;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.accountDeleteTitle),
      content: Text(l10n.accountDeleteMessage(account.name)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  if (!context.mounted || confirmed != true) {
    return false;
  }
  final affected = await controller.deleteAccount(account.id);
  if (!context.mounted || affected == null) {
    return false;
  }
  notifyDisabledRules(affected);
  return true;
}

enum AccountDeleteAction { hide, delete }

/// 打开标签多选弹窗，返回用户选定的标签 id 列表（取消返回 null）。
/// 新建标签直接写入 controller（标签全局共享，即时生效）。
Future<List<String>?> pickEntryTags({
  required BuildContext context,
  required List<String> selectedIds,
  List<Tag> extraTags = const <Tag>[],
}) {
  final controller = VeriFinScope.of(context);
  // 合并 controller 已落库标签与临时标签（导入草稿待新建、尚未落库），临时标签
  // 排在后面、去重按 id，保证草稿里既能看到又能勾选它们。
  final existingIds = controller.tags.map((tag) => tag.id).toSet();
  final tags = <Tag>[
    ...controller.tags,
    ...extraTags.where((tag) => !existingIds.contains(tag.id)),
  ];
  return _showVeriModalSheet<List<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
        ),
        child: TagSelectorSheet(
          tags: tags,
          selectedIds: selectedIds,
          onCreateTag: () async {
            final l10n = AppLocalizations.of(sheetContext);
            final label = await showTextInputDialog(
              context: sheetContext,
              title: l10n.tagCreateTitle,
              label: l10n.tagNameLabel,
            );
            if (label == null) {
              return null;
            }
            final id = controller.addTag(label);
            return id == null ? null : controller.tagById(id);
          },
        ),
      ),
    ),
  );
}
