import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/widget_config.dart';
import 'package:verifin/local_storage/local_storage.dart';

void main() {
  test('小组件配置往返保留账本、指标、图表和筛选', () {
    const config = WidgetInstanceConfig(
      appWidgetId: 42,
      template: WidgetTemplate.trend,
      bookId: 'book-2',
      primaryMetric: WidgetMetric.periodExpense,
      secondaryMetrics: [WidgetMetric.periodIncome, WidgetMetric.savingsRate],
      chartMetric: WidgetChartMetric.net,
      dateRange: WidgetDateRange.ninetyDays,
      accountId: 'account-1',
      categoryId: 'category-1',
      tagId: 'tag-1',
      hideAmounts: true,
    );

    final restored = WidgetInstanceConfig.fromJson(config.toJson());
    expect(restored.appWidgetId, 42);
    expect(restored.template, WidgetTemplate.trend);
    expect(restored.bookId, 'book-2');
    expect(restored.primaryMetric, WidgetMetric.periodExpense);
    expect(restored.secondaryMetrics, [
      WidgetMetric.periodIncome,
      WidgetMetric.savingsRate,
    ]);
    expect(restored.chartMetric, WidgetChartMetric.net);
    expect(restored.dateRange, WidgetDateRange.ninetyDays);
    expect(restored.accountId, 'account-1');
    expect(restored.categoryId, 'category-1');
    expect(restored.tagId, 'tag-1');
    expect(restored.hideAmounts, isTrue);
  });

  test('小组件配置只保存到设备偏好，不进入账本数据', () async {
    final store = LocalKeyValueStore();
    const config = WidgetInstanceConfig(
      appWidgetId: 7,
      template: WidgetTemplate.budget,
      primaryMetric: WidgetMetric.budgetRemaining,
    );
    await WidgetConfigStore.save(store, [config]);
    expect(
      WidgetConfigStore.load(store).single.primaryMetric,
      WidgetMetric.budgetRemaining,
    );
  });
}
