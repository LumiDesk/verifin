import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/currency_catalog.dart';
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
  final TextEditingController _accountBalance = TextEditingController();
  final TextEditingController _budget = TextEditingController();

  int _page = 0;
  String? _baseCurrencyCode;
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
    _accountBalance.dispose();
    _budget.dispose();
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
    final controller = VeriFinScope.of(context);
    final desiredBase =
        _baseCurrencyCode ?? controller.activeBook.baseCurrencyCode;
    if (desiredBase != controller.activeBook.baseCurrencyCode) {
      await controller.changeEmptyLedgerBookBaseCurrency(
        controller.activeBook.id,
        desiredBase,
      );
    }
    // 建首个账户（填了名称才建）。
    final name = _accountName.text.trim();
    if (name.isNotEmpty) {
      controller.addAccount(
        Account(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          bookId: controller.activeBook.id,
          name: name,
          type: AccountType.cash,
          groupId: null,
          initialBalance: double.tryParse(_accountBalance.text.trim()) ?? 0,
          iconCode: 'wallet',
          note: '',
          includeInAssets: true,
          hidden: false,
          currencyCode: controller.activeBook.baseCurrencyCode,
        ),
      );
    }
    // 设默认月预算（填了正数才设）：作为每月自动沿用的默认值，而非只设当月。
    final budget = double.tryParse(_budget.text.trim());
    if (budget != null && budget > 0) {
      controller.setDefaultMonthlyBudget(budget);
    }
    controller.completeOnboarding();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
                    balanceController: _accountBalance,
                    baseCurrencyCode: _baseCurrencyCode ?? 'CNY',
                    onPickBaseCurrency: _pickBaseCurrency,
                  ),
                  _BudgetStep(budgetController: _budget),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 8),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: veriRoyal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(veriRadiusLg),
            ),
            child: Icon(icon, size: 34, color: veriRoyal),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
          if (child != null) ...<Widget>[const SizedBox(height: 24), child!],
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
    required this.balanceController,
    required this.baseCurrencyCode,
    required this.onPickBaseCurrency,
  });

  final TextEditingController nameController;
  final TextEditingController balanceController;
  final String baseCurrencyCode;
  final VoidCallback onPickBaseCurrency;

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
          TextField(
            key: const Key('onboarding_account_balance'),
            controller: balanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(
                context,
              ).accountBalanceCurrencyLabel(baseCurrencyCode),
              hintText: '0',
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetStep extends StatelessWidget {
  const _BudgetStep({required this.budgetController});

  final TextEditingController budgetController;

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      icon: Icons.pie_chart_outline,
      title: AppLocalizations.of(context).setMonthBudgetTitle,
      description: AppLocalizations.of(context).onboardBudgetDesc,
      child: TextField(
        key: const Key('onboarding_budget'),
        controller: budgetController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).onboardBudgetLabel,
          hintText: AppLocalizations.of(context).onboardBudgetHint,
        ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < count; i += 1)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == index
                  ? veriRoyal
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
