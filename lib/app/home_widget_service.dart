import 'l10n_outside_context.dart';
import 'currency_math.dart';
import 'ledger_math.dart';
import 'models.dart';
import 'platform_bridge.dart';
import 'veri_fin_controller.dart';
import 'widget_config.dart';
import 'widget_presentation.dart';

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
  final nextCycleStart = addCalendarDays(budgetWindow.end, 1);
  final nextBudgetKeyMonth = controller.budgetKeyMonthFor(nextCycleStart);
  final nextBudgetWindow = controller.budgetWindow(nextBudgetKeyMonth);
  final nextBudget = controller.monthlyBudget(nextBudgetKeyMonth);
  final nextCycleExpense = sumByType(
    entriesInWindow(entries, nextBudgetWindow),
    EntryType.expense,
  );
  final nextRemaining = nextBudget - nextCycleExpense;
  final baseCurrencyCode = controller.activeBook.baseCurrencyCode;
  final accountValuation = controller.accountBalancesInBase(
    accounts: controller.accounts.where(
      (account) => account.includeInAssets && !account.hidden,
    ),
    date: now,
  );

  // 轻量趋势快照交给原生组件绘制 sparkline；默认展示最近 30 个自然日的支出。
  final trendPoints = <double>[];
  for (var offset = 29; offset >= 0; offset--) {
    final day = addCalendarDays(dateOnly(now), -offset);
    trendPoints.add(dayExpenseTotal(entries, day));
  }
  final trendTotal = trendPoints.fold<double>(0, (sum, value) => sum + value);

  await AppWidgetBridge.syncWidgetBooks(
    controller.ledgerBooks
        .map((book) => <String, Object?>{'id': book.id, 'name': book.name})
        .toList(growable: false),
  );
  final widgetSnapshots = <String, Map<String, Map<String, Object?>>>{};
  for (final book in controller.ledgerBooks) {
    final snapshot = controller.widgetLedgerSnapshot(book.id, now);
    if (snapshot == null) continue;
    final metrics = <String, Map<String, Object?>>{};
    for (final metric in WidgetMetric.values) {
      final definition = UserWidgetDefinition(
        id: 'native_${book.id}_${metric.name}',
        name: 'VeriFin',
        template: WidgetTemplate.trend,
        bookId: book.id,
        primaryMetric: metric,
        chartMetric: WidgetChartMetric.expense,
      );
      final data = buildWidgetPresentation(
        definition: definition,
        snapshot: snapshot,
        now: now,
      );
      metrics[metric.name] = {
        'amount': data.primary.formatted(data.currencyCode),
        'label': widgetMetricLabel(l10n, metric),
        'points': data.series.join(','),
      };
    }
    widgetSnapshots[book.id] = metrics;
  }
  await AppWidgetBridge.syncWidgetSnapshots(widgetSnapshots);

  // 用户设计的小组件由 Android 进程独立渲染。除了账本快照外，还要把每个设计
  // 当前可直接展示的结果一并推过去；桌面启动器渲染时 Flutter 进程可能并未运行，
  // 不能依赖 SharedPreferences 里的 Dart 定义或内存中的 Controller。
  final userDefinitions = <Map<String, Object?>>[];
  for (final definition in controller.userWidgetDefinitions) {
    final snapshot = controller.widgetLedgerSnapshot(definition.bookId, now);
    final WidgetPresentation? presentation = snapshot == null
        ? null
        : buildWidgetPresentation(
            definition: definition,
            snapshot: snapshot,
            now: now,
          );
    final primary = presentation?.primary;
    final secondary = presentation == null
        ? const <String>[]
        : presentation.secondary
              .map(
                (value) =>
                    '${widgetMetricLabel(l10n, value.metric)}  '
                    '${value.formatted(presentation.currencyCode, hidden: definition.hideAmounts)}',
              )
              .toList(growable: false);
    final payload = <String, Object?>{
      ...definition.toJson(),
      'presentation': <String, Object?>{
        'amount': primary == null || presentation == null
            ? '—'
            : primary.formatted(
                presentation.currencyCode,
                hidden: definition.hideAmounts,
              ),
        'label': primary == null || presentation == null
            ? l10n.widgetRefreshRequired
            : widgetMetricLabel(l10n, primary.metric),
        'secondary': secondary,
        'points': presentation == null
            ? const <double>[]
            : presentation.series.whereType<double>().toList(growable: false),
        if (presentation?.budgetUsage case final usage? when usage.isFinite)
          'budgetUsage': usage,
        'quickEntryLabel': l10n.addEntryTooltip,
      },
    };
    userDefinitions.add(payload);
  }
  await AppWidgetBridge.syncUserWidgetDefinitions(userDefinitions);

  String two(int n) => n.toString().padLeft(2, '0');

  await AppWidgetBridge.updateWidgetData(
    todayAmount: formatUserMoney(todayTotal, baseCurrencyCode),
    todayLabel: l10n.widgetTodayExpense,
    quickEntryLabel: l10n.addEntryTooltip,
    budgetAmount: formatUserMoney(remaining.abs(), baseCurrencyCode),
    budgetLabel: remaining < 0 ? overspentLabel : availableLabel,
    netWorthAmount: accountValuation.completeTotal == null
        ? '—'
        : formatUserMoney(accountValuation.completeTotal!, baseCurrencyCode),
    netWorthLabel: accountValuation.completeTotal == null
        ? '${l10n.widgetNetWorth} · ${l10n.widgetRateMissing}'
        : l10n.widgetNetWorth,
    trendAmount: formatUserMoney(trendTotal, baseCurrencyCode),
    trendLabel: l10n.widgetMetricPeriodExpense,
    trendPoints: trendPoints.map((value) => value.toStringAsFixed(2)).join(','),
    trendRangeLabel: l10n.widgetRange30d,
    // 跨天/跨期锚点：原生据此判断展示值是否过期。跨天后「今日支出」归零，
    // 过了预算周期截止日后「可用预算」回到整期预算（新周期尚无支出）。
    todayDate: '${now.year}-${two(now.month)}-${two(now.day)}',
    todayZeroAmount: formatUserMoney(0, baseCurrencyCode),
    todayStaleAmount: '—',
    todayStaleLabel: l10n.widgetRefreshRequired,
    budgetExpiry:
        '${budgetWindow.end.year}-${two(budgetWindow.end.month)}-${two(budgetWindow.end.day)}',
    budgetFullAmount: formatUserMoney(monthBudget, baseCurrencyCode),
    budgetFullLabel: availableLabel,
    budgetNextExpiry:
        '${nextBudgetWindow.end.year}-${two(nextBudgetWindow.end.month)}-${two(nextBudgetWindow.end.day)}',
    budgetNextAmount: formatUserMoney(nextRemaining.abs(), baseCurrencyCode),
    budgetNextLabel: nextRemaining < 0 ? overspentLabel : availableLabel,
    budgetStaleLabel: l10n.widgetRefreshRequired,
  );
}
