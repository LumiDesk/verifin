import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/chart_painters.dart';
import 'package:verifin/app/common_widgets.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/sheets.dart';

import 'support/test_harness.dart';

// 看板顶部按统计口径分 Tab：日常 / 月统计 / 年统计。
//
// 默认落在「日常」，每个 Tab 各自持有一份面板清单。当前 Tab 不做持久化。
void main() {
  useTestDatabases();

  testWidgets('看板 Tab 切换：默认日常，月统计与年统计各有面板', (tester) async {
    await pumpApp(tester, LocalKeyValueStore());
    await tapBottomTab(tester, 2); // 看板
    await tester.pumpAndSettle();

    final dailyEntry = find.byKey(
      const Key('panel_settings_entry_reportsDaily'),
    );
    final monthlyEntry = find.byKey(
      const Key('panel_settings_entry_reportsMonthly'),
    );
    Finder tabLabel(String label) => find.text(label).first;
    Finder selectedTab(String name) =>
        find.byKey(Key('reports_tab_selected_$name'));

    // 三个 Tab 都在。
    for (final label in <String>['日常', '月统计', '年统计']) {
      expect(find.text(label), findsWidgets, reason: '缺少 Tab：$label');
    }
    // 默认选中日常，且日常已有面板（先不滚动：滚到底部会回收顶部 Tab 条）。
    expect(selectedTab('daily'), findsOneWidget);
    expect(find.text('近7日统计'), findsOneWidget);
    expect(monthlyEntry, findsNothing);

    // 年统计：有本年收支 / 收支统计 / 收支热力 / 排行四个面板。
    await tester.tap(tabLabel('年统计'));
    await tester.pumpAndSettle();
    expect(selectedTab('yearly'), findsOneWidget);
    expect(find.text('近7日统计'), findsNothing);
    expect(dailyEntry, findsNothing);
    expect(monthlyEntry, findsNothing);
    expect(find.text('本年收支'), findsOneWidget);

    // 月统计：内容与改动前一致（摘要面板 + 其余面板 + 管理入口）。
    // 列表是懒加载的，滚到底部后顶部 Tab 条会被回收，所以先切 Tab 再滚动。
    await tester.tap(tabLabel('月统计'));
    await tester.pumpAndSettle();
    expect(selectedTab('monthly'), findsOneWidget);
    expect(dailyEntry, findsNothing);
    await tester.scrollUntilVisible(
      monthlyEntry,
      200,
      scrollable: firstVerticalScrollable(),
    );
    expect(monthlyEntry, findsOneWidget);
    expect(find.text('5个月统计面板'), findsOneWidget);
  });

  testWidgets('日常面板：时间范围与收支口径可切换', (tester) async {
    await pumpApp(tester, LocalKeyValueStore());
    await tapBottomTab(tester, 2); // 看板
    await tester.pumpAndSettle();

    expect(find.text('近7日统计'), findsOneWidget);
    expect(find.byKey(const Key('dimension_toggle_expense')), findsOneWidget);
    // 底部始终同时给出支出与收入的总计 / 日均。
    expect(find.textContaining('总支出：'), findsOneWidget);
    expect(find.textContaining('总收入：'), findsOneWidget);

    // 标题旁的小图标按钮切换口径，标题跟着换成「本周统计」。
    await tester.tap(find.byKey(const Key('recent_daily_range_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('本周统计'), findsOneWidget);
    expect(find.text('近7日统计'), findsNothing);
    await tester.tap(find.byKey(const Key('recent_daily_range_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('近7日统计'), findsOneWidget);

    // 页面上「收入」还出现在图例里，这里只点口径切换控件里的那一个。
    await tester.tap(
      find
          .descendant(
            of: find.byType(VeriEntryTypeToggle),
            matching: find.text('收入'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dimension_toggle_income')), findsOneWidget);
  });

  testWidgets('日常面板：口径切换用紧凑档，柱子按收支语义色绘制', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    controller
      ..addEntry(
        LedgerEntry(
          id: 'daily-expense',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 80,
          categoryId: 'dining',
          accountId: '',
          note: '',
          occurredAt: now,
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'daily-income',
          bookId: controller.activeBook.id,
          type: EntryType.income,
          amount: 500,
          categoryId: 'salary',
          accountId: '',
          note: '',
          occurredAt: now,
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 2); // 看板 · 日常
    await tester.pumpAndSettle();

    // 右上角口径切换与资产汇总卡的那一个同为紧凑档（30dp），不再是 40dp 的大号。
    final toggle = find.byType(VeriEntryTypeToggle);
    final assetSummaryToggle = find
        .ancestor(
          of: find.byKey(const Key('asset_summary_side_positive')),
          matching: find.byWidgetPredicate(
            (widget) => widget is VeriSegmentedControl,
          ),
        )
        .first;
    expect(
      tester.getSize(toggle).height,
      tester.getSize(assetSummaryToggle).height,
    );

    // 柱子颜色跟着口径走：支出语义红、收入语义青。
    final brightness = Theme.of(
      tester.element(find.byType(InteractiveBarChart)),
    ).brightness;
    Color chartColor() => tester
        .widget<InteractiveBarChart>(find.byType(InteractiveBarChart))
        .color!;
    expect(chartColor(), veriSemanticFor(brightness, veriExpense));

    await tester.tap(
      find.descendant(of: toggle, matching: find.text('收入')).first,
    );
    await tester.pumpAndSettle();
    expect(chartColor(), veriSemanticFor(brightness, veriIncome));
  });

  testWidgets('排行卡：支出/收入在标题右上角，分组口径移到下方且同为紧凑档', (tester) async {
    await pumpApp(tester, LocalKeyValueStore());
    await openReportsMonthlyTab(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('分类 · 标签排行'),
      200,
      scrollable: firstVerticalScrollable(),
    );
    await tester.pumpAndSettle();

    final typeToggle = find.byType(VeriEntryTypeToggle);
    final groupingToggle = find
        .ancestor(
          of: find.byKey(const Key('ranking_group_topCategory')),
          matching: find.byWidgetPredicate(
            (widget) => widget is VeriSegmentedControl,
          ),
        )
        .first;
    final title = find.text('分类 · 标签排行');

    // 支出 / 收入在标题行右侧，分组口径在它下面一行。
    expect(
      tester.getCenter(typeToggle).dx,
      greaterThan(tester.getCenter(title).dx),
    );
    expect(
      tester.getCenter(typeToggle).dy,
      lessThan(tester.getCenter(groupingToggle).dy),
    );
    expect(tester.getSize(typeToggle).height, 30);
    expect(tester.getSize(groupingToggle).height, 30);
  });

  testWidgets('资产汇总面板：正/负资产可切换，中心可切换口径', (tester) async {
    await pumpApp(tester, LocalKeyValueStore());
    await tapBottomTab(tester, 2); // 看板 · 日常
    await tester.pumpAndSettle();

    expect(find.text('资产汇总'), findsOneWidget);
    expect(
      find.byKey(const Key('asset_summary_side_positive')),
      findsOneWidget,
    );
    // 新账本账户余额为 0：正资产侧没有可展示的账户，给出空态而不是空环。
    expect(find.textContaining('暂无'), findsWidgets);

    await tester.tap(find.text('负资产').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('asset_summary_side_negative')),
      findsOneWidget,
    );
  });

  testWidgets('年统计面板：本年摘要、月度收支与排行卡', (tester) async {
    await pumpApp(tester, LocalKeyValueStore());
    await tapBottomTab(tester, 2); // 看板
    await tester.pumpAndSettle();

    await tester.tap(find.text('年统计').first);
    await tester.pumpAndSettle();

    expect(find.text('本年收支'), findsOneWidget);
    // 排行卡与月统计共用同一组件，只是取数窗口换成整年。
    await tester.scrollUntilVisible(
      find.text('分类 · 标签排行'),
      250,
      scrollable: firstVerticalScrollable(),
    );
    expect(find.text('分类 · 标签排行'), findsOneWidget);
  });

  testWidgets('排行卡在窄屏（360dp）不溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.reset);

    await pumpApp(tester, LocalKeyValueStore());
    await openReportsMonthlyTab(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('分类 · 标签排行'),
      200,
      scrollable: firstVerticalScrollable(),
    );
    await tester.pumpAndSettle();

    // 标题行（标题 + 右上角口径切换）与分组切换行各自成行，卡片宽度再窄也不溢出
    // （溢出会直接抛错让用例失败）。
    expect(find.byKey(const Key('dimension_toggle_expense')), findsOneWidget);
    expect(find.byKey(const Key('ranking_group_topCategory')), findsOneWidget);
    expect(tester.getSize(find.byType(VeriEntryTypeToggle)).height, 30);
  });

  testWidgets('年统计热力图在窄屏（360dp）不溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.reset);
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    controller.addEntry(
      LedgerEntry(
        id: 'heat-narrow',
        bookId: controller.activeBook.id,
        type: EntryType.expense,
        amount: 100,
        categoryId: 'dining',
        accountId: 'cash',
        note: '',
        occurredAt: DateTime(now.year, 2, 3),
      ),
    );
    controller.dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 2); // 看板
    await tester.pumpAndSettle();
    await tester.tap(find.text('年统计').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(VeriCalendarHeatmap),
      300,
      scrollable: firstVerticalScrollable(),
    );
    expect(find.byType(VeriCalendarHeatmap), findsOneWidget);
    // 布局溢出会在构建时抛异常，这里要求整页渲染无异常。
    expect(tester.takeException(), isNull);
  });
  testWidgets('年统计的收支热力卡：标题、支出/收入切换与月份网格', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    controller.addEntry(
      LedgerEntry(
        id: 'heat-entry',
        bookId: controller.activeBook.id,
        type: EntryType.expense,
        amount: 42,
        categoryId: 'dining',
        accountId: 'cash',
        note: '',
        occurredAt: DateTime(now.year, 3, 5),
      ),
    );
    controller.dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 2); // 看板
    await tester.pumpAndSettle();
    await tester.tap(find.text('年统计').first);
    await tester.pumpAndSettle();

    // 卡片标题与右上角口径切换。
    await tester.scrollUntilVisible(
      find.text('收支热力'),
      300,
      scrollable: firstVerticalScrollable(),
    );
    expect(find.text('收支热力'), findsOneWidget);
    expect(find.byKey(const Key('dimension_toggle_expense')), findsWidgets);
    // 12 个月都有格子。
    for (final month in <int>[1, 3, 12]) {
      expect(find.text('$month月'), findsOneWidget);
    }

    // 页面上「收入」还出现在图例里，这里只点口径切换控件里的那一个。
    await tester.tap(
      find
          .descendant(
            of: find.byType(VeriEntryTypeToggle),
            matching: find.text('收入'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    // 这个账本只有支出：切到「收入」后热力图应变成空态。
    expect(find.text('暂无收入数据'), findsOneWidget);
  });

  testWidgets('资产汇总：环内空白处点击也能切换金额 / 占比', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2600);
    addTearDown(tester.view.reset);
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    await controller.addAccountDraft(
      Account(
        id: 'acc_tap',
        bookId: controller.activeBook.id,
        name: '现金',
        type: AccountType.onlinePayment,
        groupId: null,
        initialBalance: 500,
        iconCode: 'wallet',
        note: '',
        includeInAssets: true,
        hidden: false,
        currencyCode: controller.activeBook.baseCurrencyCode,
      ),
    );
    controller.dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 2); // 看板 · 日常
    await tester.pumpAndSettle();
    expect(find.text('资产金额'), findsOneWidget);

    // 点在中心区域偏下（避开文字本身），仍应命中可点的中心。
    final center = tester.getCenter(find.byType(VeriDonutChart));
    await tester.tapAt(center + const Offset(0, 32));
    await tester.pumpAndSettle();
    expect(find.text('资产占比'), findsOneWidget);
  });

  testWidgets('资产汇总：负资产显示负数，账户超过 5 个可展开', (tester) async {
    // 面板较高，给一个足够大的视口，避免展开/切换按钮落到屏幕外点不中。
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2600);
    addTearDown(tester.view.reset);
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    Future<void> add(String id, String name, double balance) => controller
        .addAccountDraft(
          Account(
            id: id,
            bookId: controller.activeBook.id,
            name: name,
            type: AccountType.onlinePayment,
            groupId: null,
            initialBalance: balance,
            iconCode: 'wallet',
            note: '',
            includeInAssets: true,
            hidden: false,
            currencyCode: controller.activeBook.baseCurrencyCode,
          ),
        )
        .then((_) {});
    for (var i = 1; i <= 6; i++) {
      await add('acc_$i', '资产账户$i', 100.0 * i);
    }
    // 负债账户：负资产侧必须显示成负数。
    await add('acc_negative', '信用卡负债', -123.11);
    controller.dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 2); // 看板 · 日常
    await tester.pumpAndSettle();

    // 默认只列前 5 个账户（其余并入「其他」），并提供展开入口。
    final expandToggle = find.byKey(const Key('asset_summary_expand_toggle'));
    expect(expandToggle, findsOneWidget);
    expect(find.textContaining('展开全部'), findsOneWidget);

    await tester.tap(expandToggle);
    await tester.pumpAndSettle();
    // 展开后第 6 个账户（金额最小的）也出现在图例里。
    expect(find.text('资产账户1'), findsOneWidget);

    // 负资产侧：中心与图例都显示负数。
    await tester.tap(find.text('负资产').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('-123.11'), findsWidgets);
  });

  testWidgets('资产汇总：负资产超过 5 个时折叠态并入「其他」而不是丢掉', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2600);
    addTearDown(tester.view.reset);
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    Future<void> add(String id, String name, double balance) => controller
        .addAccountDraft(
          Account(
            id: id,
            bookId: controller.activeBook.id,
            name: name,
            type: AccountType.onlinePayment,
            groupId: null,
            initialBalance: balance,
            iconCode: 'wallet',
            note: '',
            includeInAssets: true,
            hidden: false,
            currencyCode: controller.activeBook.baseCurrencyCode,
          ),
        )
        .then((_) {});
    for (var i = 1; i <= 6; i++) {
      await add('debt_$i', '负债账户$i', -100.0 * i);
    }
    controller.dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 2); // 看板 · 日常
    await tester.pumpAndSettle();
    await tester.tap(find.text('负资产').first);
    await tester.pumpAndSettle();

    // 图例按绝对值降序，折叠态只列前 5 个（绝对额最大的），余额最小的那个
    // 必须并入「其他」：
    // 负资产侧各项与合计都是负数，判定写成 `otherAmount > 0` 会让这一行消失，
    // 图例各行之和与中心总额对不上（回归保护）。
    expect(find.text('其他'), findsOneWidget);
    expect(find.text('负债账户1'), findsNothing);

    await tester.tap(find.byKey(const Key('asset_summary_expand_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('负债账户1'), findsOneWidget);
    expect(find.text('其他'), findsNothing);
  });

  testWidgets('月统计期间栏：翻到上个月后摘要卡换口径，可一键回本月', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    controller
      ..addEntry(
        LedgerEntry(
          id: 'period-last-month',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 120,
          categoryId: 'dining',
          accountId: '',
          note: '',
          occurredAt: DateTime(lastMonth.year, lastMonth.month, 12),
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await openReportsMonthlyTab(tester);
    await tester.pumpAndSettle();

    final thisMonthLabel = '${now.year}年${now.month}月';
    final lastMonthLabel = '${lastMonth.year}年${lastMonth.month}月';

    // 默认停在本月：往前可以翻，往后不能（未来没有数据）；回跳入口常显但置灰。
    expect(find.byKey(const Key('reports_period_label')), findsOneWidget);
    expect(find.text(thisMonthLabel), findsOneWidget);
    expect(periodArrow(tester, '上个月').onPressed, isNotNull);
    expect(periodArrow(tester, '下个月').onPressed, isNull);
    expect(jumpToCurrentEnabled(tester), isFalse);
    expect(find.text('本月收支'), findsOneWidget);

    await tester.tap(find.byTooltip('上个月'));
    await tester.pumpAndSettle();

    // 期间栏与摘要卡标题同时切到上个月，指标不再写「本月」。
    expect(find.text(lastMonthLabel), findsNWidgets(2));
    expect(find.text('本月收支'), findsNothing);
    expect(find.text('本月收入'), findsNothing);
    expect(find.text('收入'), findsWidgets);
    expect(jumpToCurrentEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key('reports_period_jump')));
    await tester.pumpAndSettle();
    expect(find.text(thisMonthLabel), findsOneWidget);
    expect(find.text('本月收支'), findsOneWidget);
    expect(jumpToCurrentEnabled(tester), isFalse);
  });

  testWidgets('月统计期间栏：点标签打开系统日期选择器，切换月份只取年月', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    final target = DateTime(now.year, now.month - 2);
    final lastMonth = DateTime(now.year, now.month - 1);
    controller
      ..addEntry(
        LedgerEntry(
          id: 'period-picked',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 88,
          categoryId: 'dining',
          accountId: '',
          note: '',
          occurredAt: DateTime(target.year, target.month, 3),
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await openReportsMonthlyTab(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reports_period_label')));
    await tester.pumpAndSettle();
    // 月份对话框只列 1–12 月：不再要求用户选具体哪一天。
    expect(find.text('选择月份'), findsOneWidget);

    await tester.tap(find.text('${lastMonth.month}月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('选择月份'), findsNothing);
    expect(
      find.text('${lastMonth.year}年${lastMonth.month}月'),
      findsNWidgets(2),
    );
  });

  testWidgets('年统计期间栏：退到上一年、年份弹层可选、可回今年', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store);
    final now = DateTime.now();
    final lastYear = now.year - 1;
    final firstYear = now.year - 2;
    controller
      ..addEntry(
        LedgerEntry(
          id: 'year-entry',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 66,
          categoryId: 'dining',
          accountId: '',
          note: '',
          occurredAt: DateTime(lastYear, 5, 20),
        ),
      )
      ..addEntry(
        LedgerEntry(
          id: 'year-entry-oldest',
          bookId: controller.activeBook.id,
          type: EntryType.expense,
          amount: 33,
          categoryId: 'dining',
          accountId: '',
          note: '',
          occurredAt: DateTime(firstYear, 3, 10),
        ),
      )
      ..dispose();

    await pumpApp(tester, store);
    await tapBottomTab(tester, 2); // 看板
    await tester.pumpAndSettle();
    await tester.tap(find.text('年统计').first);
    await tester.pumpAndSettle();

    expect(find.text('${now.year}年'), findsOneWidget);
    expect(periodArrow(tester, '上一年').onPressed, isNotNull);
    expect(periodArrow(tester, '下一年').onPressed, isNull);
    expect(find.text('本年收支'), findsOneWidget);
    expect(jumpToCurrentEnabled(tester), isFalse);

    await tester.tap(find.byTooltip('上一年'));
    await tester.pumpAndSettle();

    // 摘要卡标题去掉「本」写成「年收支」，年份改挂到右上角角标；指标换中性口径。
    expect(find.text('年收支'), findsOneWidget);
    expect(find.text('本年收支'), findsNothing);
    expect(find.text('本年收入'), findsNothing);
    // 年份出现在三处：期间栏、摘要卡角标、收支统计卡角标。
    expect(find.text('$lastYear年'), findsNWidgets(3));
    // 「收支统计」的角标不再是「今年」而是当前看的年份。
    expect(
      tester
          .widget<SectionTitle>(
            find
                .ancestor(
                  of: find.text('收支统计'),
                  matching: find.byType(SectionTitle),
                )
                .first,
          )
          .trailing,
      '$lastYear年',
    );
    expect(jumpToCurrentEnabled(tester), isTrue);

    // 年份对话框只列年份，点一年不会再掉进月份 / 日期。
    await tester.tap(find.byKey(const Key('reports_period_label')));
    await tester.pumpAndSettle();
    expect(find.text('选择年份'), findsOneWidget);
    // 年份按钮内部有一份用于滑动动画的重复渲染，取最后一个（可见的那一份）。
    await tester.tap(find.text('$firstYear年').last);
    await tester.pumpAndSettle();
    // 选完年份仍在年份对话框里（不会跳去选月份 / 日期）。
    expect(find.text('选择年份'), findsOneWidget);
    expect(find.text('选择月份'), findsNothing);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('$firstYear年'), findsNWidgets(3));
    // 到最早一年后不再往前翻。
    expect(periodArrow(tester, '上一年').onPressed, isNull);

    await tester.tap(find.byKey(const Key('reports_period_jump')));
    await tester.pumpAndSettle();
    expect(find.text('本年收支'), findsOneWidget);
    expect(find.text('${now.year}年'), findsOneWidget);
    expect(jumpToCurrentEnabled(tester), isFalse);
  });

  testWidgets('期间选择入口：只回传年月 / 年份，焦点早于下界也不出错', (tester) async {
    DateTime? pickedMonth;
    int? pickedYear;
    // 焦点月份早于首笔记账日：入口必须把它夹回可选范围，否则对话框会显示一个越界的初始月。
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextButton(
                    onPressed: () async {
                      pickedMonth = await showMonthPickerSheet(
                        context: context,
                        selected: DateTime(2023, 1),
                        firstDate: DateTime(2023, 3, 12),
                        today: DateTime(2024, 9, 5),
                      );
                    },
                    child: const Text('open-month'),
                  ),
                  TextButton(
                    onPressed: () async {
                      pickedYear = await showYearPickerSheet(
                        context: context,
                        selected: 2023,
                        firstDate: DateTime(2023, 3, 12),
                        today: DateTime(2024, 9, 5),
                      );
                    },
                    child: const Text('open-year'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-month'));
    await tester.pumpAndSettle();
    expect(find.text('选择月份'), findsOneWidget);
    // 焦点被夹到 2023-03：头部显示的就是被夹回来的月份。
    expect(find.text('2023年3月'), findsOneWidget);
    expect(find.text('5月'), findsOneWidget);
    await tester.tap(find.text('5月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(pickedMonth!.year, 2023);
    expect(pickedMonth!.month, 5);

    await tester.tap(find.text('open-year'));
    await tester.pumpAndSettle();
    expect(find.text('选择年份'), findsOneWidget);
    expect(find.text('2023年'), findsWidgets);
    await tester.tap(find.text('2024年').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(pickedYear, 2024);
  });
}

/// 回跳按钮当前是否可点（也就是说：是不是已经离开本期）。
bool jumpToCurrentEnabled(WidgetTester tester) =>
    tester
        .widget<TextButton>(find.byKey(const Key('reports_period_jump')))
        .onPressed !=
    null;

/// 期间栏箭头：按 tooltip 取到 [IconButton]，`onPressed` 为 null 即到边界禁用。
IconButton periodArrow(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ),
    );
