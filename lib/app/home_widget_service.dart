import 'l10n_outside_context.dart';
import 'ledger_math.dart';
import 'platform_bridge.dart';
import 'veri_fin_controller.dart';

/// 把当前账本的「今日支出」推送到 Android 桌面小组件。
/// 非 Android 平台由 [AppPlatformBridge] 静默忽略；在打开应用、回前台、记账后调用。
Future<void> pushTodayExpenseToWidget(VeriFinController controller) async {
  final today = dateOnly(DateTime.now());
  final total = dayExpenseTotal(controller.entries, today);
  await AppPlatformBridge.updateTodayExpenseWidget(
    amount: formatAmount(total),
    label: l10nForPreference(controller.localePreference).widgetTodayExpense,
  );
}
