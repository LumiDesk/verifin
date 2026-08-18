import 'l10n_outside_context.dart';
import 'currency_math.dart';
import 'ledger_math.dart';
import 'models.dart';
import 'platform_bridge.dart';
import 'veri_fin_controller.dart';

/// 把当前账本的桌面小组件数据（今日支出 / 本月可用预算 / 资产总额）推送到 Android。
/// 非 Android 平台由 [AppWidgetBridge] 静默忽略；在打开应用、回前台、记账后调用。
Future<void> pushWidgetData(VeriFinController controller) async {
  final l10n = l10nForPreference(controller.localePreference);
  final now = DateTime.now();
  final entries = controller.entries;

  final todayTotal = dayExpenseTotal(entries, dateOnly(now));

  // 预算按周期取数（键月 + 周期窗口）；自定义周期时标签用「本期」措辞。
  final budgetKeyMonth = controller.budgetKeyMonthFor(now);
  final budgetWindow = controller.budgetWindow(budgetKeyMonth);
  final monthBudget = controller.monthlyBudget(budgetKeyMonth);
  final cycleExpense = sumByType(
    entriesInWindow(entries, budgetWindow),
    EntryType.expense,
  );
  final remaining = monthBudget - cycleExpense;
  final cyclic = controller.budgetCycleIsCustom;
  final availableLabel = cyclic
      ? l10n.widgetPeriodBudgetAvailable
      : l10n.widgetBudgetAvailable;
  final overspentLabel = cyclic
      ? l10n.widgetPeriodBudgetOverspent
      : l10n.widgetBudgetOverspent;
  final baseCurrencyCode = controller.activeBook.baseCurrencyCode;
  final accountValuation = controller.accountBalancesInBase(
    accounts: controller.accounts.where(
      (account) => account.includeInAssets && !account.hidden,
    ),
    date: now,
  );

  String two(int n) => n.toString().padLeft(2, '0');

  await AppWidgetBridge.updateWidgetData(
    todayAmount: formatUserMoney(todayTotal, baseCurrencyCode),
    todayLabel: l10n.widgetTodayExpense,
    budgetAmount: formatUserMoney(remaining.abs(), baseCurrencyCode),
    budgetLabel: remaining < 0 ? overspentLabel : availableLabel,
    netWorthAmount: accountValuation.completeTotal == null
        ? '—'
        : formatUserMoney(accountValuation.completeTotal!, baseCurrencyCode),
    netWorthLabel: accountValuation.completeTotal == null
        ? '${l10n.widgetNetWorth} · ${l10n.widgetRateMissing}'
        : l10n.widgetNetWorth,
    // 跨天/跨期锚点：原生据此判断展示值是否过期。跨天后「今日支出」归零，
    // 过了预算周期截止日后「可用预算」回到整期预算（新周期尚无支出）。
    todayDate: '${now.year}-${two(now.month)}-${two(now.day)}',
    todayZeroAmount: formatUserMoney(0, baseCurrencyCode),
    budgetExpiry:
        '${budgetWindow.end.year}-${two(budgetWindow.end.month)}-${two(budgetWindow.end.day)}',
    budgetFullAmount: formatUserMoney(monthBudget, baseCurrencyCode),
    budgetFullLabel: availableLabel,
  );
}
