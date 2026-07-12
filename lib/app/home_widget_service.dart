import 'l10n_outside_context.dart';
import 'ledger_math.dart';
import 'models.dart';
import 'platform_bridge.dart';
import 'series_math.dart';
import 'veri_fin_controller.dart';

/// 把当前账本的桌面小组件数据（今日支出 / 本月可用预算 / 资产总额）推送到 Android。
/// 非 Android 平台由 [AppWidgetBridge] 静默忽略；在打开应用、回前台、记账后调用。
Future<void> pushWidgetData(VeriFinController controller) async {
  final l10n = l10nForPreference(controller.localePreference);
  final now = DateTime.now();
  final entries = controller.entries;

  final todayTotal = dayExpenseTotal(entries, dateOnly(now));

  final monthBudget = controller.monthlyBudget(now);
  final monthExpense = sumByType(
    entries.where((entry) => isInMonth(entry, now)),
    EntryType.expense,
  );
  final remaining = monthBudget - monthExpense;

  final netWorth = controller.accounts
      .where((account) => !account.hidden)
      .fold<double>(
        0,
        (sum, account) => sum + controller.accountBalance(account),
      );

  String two(int n) => n.toString().padLeft(2, '0');

  await AppWidgetBridge.updateWidgetData(
    todayAmount: formatAmount(todayTotal),
    todayLabel: l10n.widgetTodayExpense,
    budgetAmount: formatAmount(remaining.abs()),
    budgetLabel: remaining < 0
        ? l10n.widgetBudgetOverspent
        : l10n.widgetBudgetAvailable,
    netWorthAmount: formatAmount(netWorth),
    netWorthLabel: l10n.widgetNetWorth,
    // 跨天/跨月锚点：原生据此判断展示值是否过期。跨天后「今日支出」归零，
    // 跨月后「本月可用」回到整月预算（新月尚无支出）。
    todayDate: '${now.year}-${two(now.month)}-${two(now.day)}',
    todayZeroAmount: formatAmount(0),
    budgetMonth: '${now.year}-${two(now.month)}',
    budgetFullAmount: formatAmount(monthBudget),
    budgetFullLabel: l10n.widgetBudgetAvailable,
  );
}
