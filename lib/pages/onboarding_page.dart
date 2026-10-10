import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/currency_catalog.dart';
import '../app/currency_math.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 位于应用锁内部；完成引导前不构建首页，也不以转场露出首页。
class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (VeriFinScope.of(context).onboardingCompleted) return child;
    return Navigator(
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
    );
  }
}

/// 新用户引导：首启动（同意隐私政策后）出现，分步介绍并可快速建首个账户、设本月预算。
/// 完成或跳过后写入 `verifin.onboarding.v1`，只出现一次。（阶段 4.5）
///
/// 后续新增重要功能时，需回顾此处引导内容是否同步（见 TODO 4.5）。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final TextEditingController _accountName = TextEditingController();

  int _page = 0;
  String? _baseCurrencyCode;
  // 金额一律走统一数字键盘，因此只保留数值草稿，不再持有文本控制器。
  double? _accountBalance;
  double? _budget;
  // 「完成/跳过」会先 await 一次落库再建账户，期间按钮仍可点；没有这个标志，
  // 快速双击会建出两个默认账户。
  bool _finishing = false;
  static const int _lastPage = 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _baseCurrencyCode ??=
        Localizations.localeOf(context).languageCode.toLowerCase() == 'zh'
        ? 'CNY'
        : 'USD';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _accountName.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _lastPage) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_finishing) {
      return;
    }
    setState(() => _finishing = true);
    try {
      final controller = VeriFinScope.of(context);
      final l10n = AppLocalizations.of(context);
      final desiredBase =
          _baseCurrencyCode ?? controller.activeBook.baseCurrencyCode;
      if (desiredBase != controller.activeBook.baseCurrencyCode) {
        await controller.changeEmptyLedgerBookBaseCurrency(
          controller.activeBook.id,
          desiredBase,
        );
        if (!mounted) {
          return;
        }
      }
      // 建首个账户：名称为空（含「跳过」引导）时用「现金」，保证记账主路径始终
      // 有可用账户。零账户会让记账页保存按钮永远禁用，是首启的死路。
      final name = _accountName.text.trim();
      controller.addAccount(
        Account(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          bookId: controller.activeBook.id,
          name: name.isEmpty ? AccountType.cash.label(l10n) : name,
          type: AccountType.cash,
          groupId: null,
          initialBalance: _accountBalance ?? 0,
          iconCode: 'wallet',
          note: '',
          includeInAssets: true,
          hidden: false,
          currencyCode: controller.activeBook.baseCurrencyCode,
        ),
      );
      // 设默认月预算（填了正数才设）：作为每月自动沿用的默认值，而非只设当月。
      final budget = _budget;
      if (budget != null && budget > 0) {
        controller.setDefaultMonthlyBudget(budget);
      }
      controller.completeOnboarding();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } finally {
      // 成功时页面已 pop（mounted 为 false）；失败时放开，允许用户重试。
      if (mounted) {
        setState(() => _finishing = false);
      }
    }
  }

  Future<void> _pickBaseCurrency() async {
    final selected = await showCurrencyPickerSheet(
      context: context,
      title: AppLocalizations.of(context).selectBaseCurrency,
      selectedCode: _baseCurrencyCode,
      preferredCodes: <String>[_baseCurrencyCode!],
    );
    if (selected == null || !mounted) return;
    setState(() => _baseCurrencyCode = selected.code);
  }

  /// 首个账户的初始余额：可与正式的新建账户页一致地输入负数。
  Future<void> _pickAccountBalance() async {
    final code = _baseCurrencyCode ?? 'CNY';
    final value = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).accountBalanceCurrencyLabel(code),
      initialAmount: _accountBalance,
      allowNegative: true,
      allowZero: true,
      currencyCode: code,
    );
    if (value == null || !mounted) {
      return;
    }
    setState(() => _accountBalance = value);
  }

  Future<void> _pickBudget() async {
    final code = _baseCurrencyCode ?? 'CNY';
    final value = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).onboardBudgetLabel,
      initialAmount: _budget,
      allowZero: true,
      currencyCode: code,
    );
    if (value == null || !mounted) {
      return;
    }
    setState(() => _budget = value);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page >= _lastPage;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  key: const Key('onboarding_skip'),
                  onPressed: _finish,
                  child: Text(AppLocalizations.of(context).skipLabel),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _page = value),
                children: <Widget>[
                  const _WelcomeStep(),
                  _AccountStep(
                    nameController: _accountName,
                    balance: _accountBalance,
                    baseCurrencyCode: _baseCurrencyCode ?? 'CNY',
                    onPickBaseCurrency: _pickBaseCurrency,
                    onPickBalance: _pickAccountBalance,
                  ),
                  _BudgetStep(
                    budget: _budget,
                    baseCurrencyCode: _baseCurrencyCode ?? 'CNY',
                    onPickBudget: _pickBudget,
                  ),
                  const _DoneStep(),
                ],
              ),
            ),
            _Dots(count: _lastPage + 1, index: _page),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboarding_next'),
                  onPressed: _next,
                  child: Text(
                    isLast
                        ? AppLocalizations.of(context).startBookkeeping
                        : AppLocalizations.of(context).nextStep,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({
    required this.icon,
    required this.title,
    required this.description,
    this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 12),
          // 图标底板用品牌色的柔和高光而非纯色块：单屏里它是唯一的视觉焦点，
          // 需要一点层次而不是一个死板的方形色块。
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  scheme.primary.withValues(alpha: 0.22),
                  scheme.primary.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(veriRadiusXl),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, size: 38, color: scheme.primary),
          ),
          const SizedBox(height: 26),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.65,
              color: scheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          if (child != null) ...<Widget>[const SizedBox(height: 28), child!],
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      icon: Icons.savings_outlined,
      title: AppLocalizations.of(context).onboardWelcomeTitle,
      description: AppLocalizations.of(context).onboardWelcomeDesc,
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.nameController,
    required this.balance,
    required this.baseCurrencyCode,
    required this.onPickBaseCurrency,
    required this.onPickBalance,
  });

  final TextEditingController nameController;
  final double? balance;
  final String baseCurrencyCode;
  final VoidCallback onPickBaseCurrency;
  final VoidCallback onPickBalance;

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      icon: Icons.account_balance_wallet_outlined,
      title: AppLocalizations.of(context).onboardAccountTitle,
      description: AppLocalizations.of(context).onboardAccountDesc,
      child: Column(
        children: <Widget>[
          ListTile(
            key: const Key('onboarding_base_currency'),
            contentPadding: EdgeInsets.zero,
            title: Text(AppLocalizations.of(context).ledgerBaseCurrency),
            subtitle: Text(
              CurrencyCatalog.require(
                baseCurrencyCode,
              ).nameForLocale(Localizations.localeOf(context).languageCode),
            ),
            trailing: Text(baseCurrencyCode),
            onTap: onPickBaseCurrency,
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('onboarding_account_name'),
            controller: nameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).onboardAccountNameLabel,
              hintText: AppLocalizations.of(context).onboardAccountNameHint,
            ),
          ),
          const SizedBox(height: 14),
          SelectField(
            key: const Key('onboarding_account_balance'),
            label: AppLocalizations.of(
              context,
            ).accountBalanceCurrencyLabel(baseCurrencyCode),
            value: balance == null
                ? AppLocalizations.of(context).notSet
                : formatUserMoney(balance!, baseCurrencyCode),
            icon: Icons.account_balance_wallet_outlined,
            onTap: onPickBalance,
          ),
        ],
      ),
    );
  }
}

class _BudgetStep extends StatelessWidget {
  const _BudgetStep({
    required this.budget,
    required this.baseCurrencyCode,
    required this.onPickBudget,
  });

  final double? budget;
  final String baseCurrencyCode;
  final VoidCallback onPickBudget;

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      icon: Icons.pie_chart_outline,
      title: AppLocalizations.of(context).setMonthBudgetTitle,
      description: AppLocalizations.of(context).onboardBudgetDesc,
      child: SelectField(
        key: const Key('onboarding_budget'),
        label: AppLocalizations.of(context).onboardBudgetLabel,
        value: budget == null
            ? AppLocalizations.of(context).notSet
            : formatUserMoney(budget!, baseCurrencyCode),
        icon: Icons.pie_chart_outline,
        onTap: onPickBudget,
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep();

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      icon: Icons.check_circle_outline,
      title: AppLocalizations.of(context).onboardDoneTitle,
      description: AppLocalizations.of(context).onboardDoneDesc,
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final inactive = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.18);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < count; i += 1)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            // 选中项拉长成小胶囊，未选中保持圆点：比单纯变宽更容易看出当前进度。
            width: i == index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == index
                  ? Theme.of(context).colorScheme.primary
                  : inactive,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
