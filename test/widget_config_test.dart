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

  test('用户小组件设计与桌面绑定可往返并兼容旧实例', () async {
    final store = LocalKeyValueStore();
    const definition = UserWidgetDefinition(
      id: 'design-1',
      name: '本月趋势',
      template: WidgetTemplate.trend,
      size: WidgetSize.fourByTwo,
      primaryMetric: WidgetMetric.periodExpense,
      chartMetric: WidgetChartMetric.expense,
      background: WidgetBackground(
        kind: WidgetBackgroundKind.solid,
        value: '#FF102030',
        overlayOpacity: .25,
      ),
    );
    await WidgetConfigStore.saveDefinitions(store, [definition]);
    await WidgetConfigStore.savePlacements(store, const [
      WidgetPlacement(appWidgetId: 99, definitionId: 'design-1'),
    ]);
    expect(WidgetConfigStore.loadDefinitions(store).single.name, '本月趋势');
    expect(
      WidgetConfigStore.loadDefinitions(store).single.size,
      WidgetSize.twoByFour,
    );
    expect(
      WidgetConfigStore.loadPlacements(store).single.definitionId,
      'design-1',
    );
  });

  test('旧实例配置会惰性迁移成用户设计和绑定', () async {
    final store = LocalKeyValueStore();
    const config = WidgetInstanceConfig(
      appWidgetId: 8,
      template: WidgetTemplate.budget,
      primaryMetric: WidgetMetric.budgetRemaining,
    );
    await WidgetConfigStore.save(store, [config]);
    expect(WidgetConfigStore.loadDefinitions(store).single.id, 'legacy_8');
    expect(
      WidgetConfigStore.loadPlacements(store).single.definitionId,
      'legacy_8',
    );
  });
}
