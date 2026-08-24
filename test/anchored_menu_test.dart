import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';

void main() {
  testWidgets('renders icon title subtitle divider and selected state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _MenuTestApp(
        entries: <VeriMenuEntry>[
          const VeriMenuItem(
            id: 'view',
            icon: Icons.grid_view_rounded,
            title: '切换视图',
            subtitle: '卡片视图',
            children: <VeriMenuEntry>[
              VeriMenuItem(id: 'list', title: '列表视图', onPressed: _noop),
              VeriMenuItem(
                id: 'card',
                title: '卡片视图',
                selected: true,
                onPressed: _noop,
              ),
            ],
          ),
          const VeriMenuDivider(),
          const VeriMenuItem(
            id: 'settings',
            icon: Icons.settings_rounded,
            title: '设置',
            onPressed: _noop,
          ),
        ],
      ),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    expect(find.text('切换视图'), findsOneWidget);
    expect(find.text('卡片视图'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    final panel = find.byType(SingleChildScrollView).last;
    expect(tester.getSize(panel).width, 224);
    final rootItemInk = find
        .ancestor(of: find.text('切换视图'), matching: find.byType(InkWell))
        .first;
    expect(tester.getSize(rootItemInk).width, 208);
    final settingsInk = find
        .ancestor(of: find.text('设置'), matching: find.byType(InkWell))
        .first;
    final panelRect = tester.getRect(panel);
    final firstItemRect = tester.getRect(rootItemInk);
    final lastItemRect = tester.getRect(settingsInk);
    expect(firstItemRect.left - panelRect.left, 8);
    expect(panelRect.right - firstItemRect.right, 8);
    expect(firstItemRect.top - panelRect.top, 9);
    expect(panelRect.bottom - lastItemRect.bottom, 9);
    expect(tester.getSize(settingsInk).height, 44);
    expect(
      tester.widget<InkWell>(rootItemInk).borderRadius,
      BorderRadius.circular(veriRadiusLg),
    );
    expect(tester.widget<Text>(find.text('切换视图')).style?.fontSize, 13);
    expect(tester.widget<Text>(find.text('卡片视图')).style?.fontSize, 11);

    await tester.tap(find.text('切换视图'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
    final panelMaterials = tester
        .widgetList<Material>(find.byType(Material))
        .map((material) => material.color)
        .whereType<Color>();
    expect(
      panelMaterials,
      contains(Color.lerp(veriSurfaceLight, Colors.black, 0.28 * 0.62)),
    );
    expect(find.text('列表视图'), findsOneWidget);
    expect(find.text('卡片视图'), findsNWidgets(3));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    final submenuPanelRect = tester.getRect(
      find.byType(SingleChildScrollView).last,
    );
    final plainTextRect = tester.getRect(find.text('列表视图'));
    expect(plainTextRect.left - submenuPanelRect.left, 20);
    final selectedText = tester.widget<Text>(find.text('卡片视图').last);
    expect(selectedText.style?.color, veriRoyal.withValues(alpha: 0.92));
  });

  testWidgets('submenu selection closes menu and invokes action', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      _MenuTestApp(
        entries: <VeriMenuEntry>[
          VeriMenuItem(
            id: 'view',
            title: '视图',
            children: <VeriMenuEntry>[
              VeriMenuItem(
                id: 'card',
                title: '卡片',
                onPressed: () => selected = true,
              ),
            ],
          ),
        ],
      ),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('视图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('卡片'));
    await tester.pumpAndSettle();

    expect(selected, isTrue);
    expect(find.text('卡片'), findsNothing);
  });

  testWidgets('back closes submenu before closing the whole menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _MenuTestApp(
        entries: <VeriMenuEntry>[
          VeriMenuItem(
            id: 'sort',
            title: '排序方式',
            children: <VeriMenuEntry>[
              VeriMenuItem(id: 'updated', title: '更新时间', onPressed: _noop),
            ],
          ),
          VeriMenuItem(id: 'settings', title: '设置', onPressed: _noop),
        ],
      ),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('排序方式'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('更新时间'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsNothing);
  });

  testWidgets('outside tap dismisses the menu', (tester) async {
    await tester.pumpWidget(
      const _MenuTestApp(
        entries: <VeriMenuEntry>[
          VeriMenuItem(id: 'settings', title: '设置', onPressed: _noop),
        ],
      ),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);

    await tester.tapAt(const Offset(20, 500));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('设置'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsNothing);
  });

  testWidgets('uses the actual route constraints on a resized viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(460, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const _MenuTestApp(
        width: 208,
        entries: <VeriMenuEntry>[
          VeriMenuItem(id: 'settings', title: '设置', onPressed: _noop),
        ],
      ),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    final panelRect = tester.getRect(find.byType(SingleChildScrollView).last);
    expect(panelRect.left, greaterThanOrEqualTo(0));
    expect(panelRect.right, lessThanOrEqualTo(460));
  });

  testWidgets('submenu expands from the selected row and supports widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _MenuTestApp(
        width: 206,
        submenuWidth: 198,
        entries: <VeriMenuEntry>[
          VeriMenuItem(id: 'view', title: '视图', onPressed: _noop),
          VeriMenuItem(id: 'sort', title: '排序', onPressed: _noop),
          VeriMenuItem(
            id: 'filter',
            title: '筛选',
            subtitle: '全部',
            submenuWidth: 184,
            children: <VeriMenuEntry>[
              VeriMenuItem(id: 'all', title: '全部', onPressed: _noop),
              VeriMenuItem(id: 'mine', title: '我的', onPressed: _noop),
            ],
          ),
        ],
      ),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SingleChildScrollView).last).width, 206);
    final originalRow = find
        .ancestor(of: find.text('筛选'), matching: find.byType(InkWell))
        .first;
    final originalTop = tester.getRect(originalRow).top;

    await tester.tap(find.text('筛选'));
    await tester.pump();
    final sharedRows = find.ancestor(
      of: find.text('筛选'),
      matching: find.byType(InkWell),
    );
    expect(sharedRows, findsNWidgets(2));
    expect(tester.getRect(sharedRows.last).top, originalTop);

    await tester.pumpAndSettle();
    final panelWidths = find
        .byType(SingleChildScrollView)
        .evaluate()
        .map((element) => tester.getSize(find.byWidget(element.widget)).width);
    expect(panelWidths, containsAll(<double>[206, 184]));
  });

  testWidgets('supports four levels and reverses one level at a time', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _MenuTestApp(
        entries: <VeriMenuEntry>[
          VeriMenuItem(
            id: 'level-1',
            title: '一级',
            children: <VeriMenuEntry>[
              VeriMenuItem(
                id: 'level-2',
                icon: Icons.layers_outlined,
                title: '二级',
                children: <VeriMenuEntry>[
                  VeriMenuItem(
                    id: 'level-3',
                    title: '三级',
                    children: <VeriMenuEntry>[
                      VeriMenuItem(
                        id: 'level-4-leaf',
                        icon: Icons.flag_outlined,
                        title: '四级叶子',
                        onPressed: _noop,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    final levelOneTop = tester.getRect(find.text('一级')).top;
    await tester.tap(find.text('一级'));
    await tester.pump();
    expect(tester.getRect(find.text('一级').last).top, levelOneTop);
    await tester.pumpAndSettle();
    final levelTwoTop = tester.getRect(find.text('二级').last).top;
    await tester.tap(find.text('二级').last);
    await tester.pump();
    expect(tester.getRect(find.text('二级').last).top, levelTwoTop);
    await tester.pumpAndSettle();
    final levelThreeTop = tester.getRect(find.text('三级').last).top;
    await tester.tap(find.text('三级').last);
    await tester.pump();
    expect(tester.getRect(find.text('三级').last).top, levelThreeTop);
    await tester.pumpAndSettle();
    expect(find.text('四级叶子'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNWidgets(4));
    expect(find.text('一级'), findsWidgets);
    expect(find.text('二级'), findsWidgets);
    expect(find.text('三级'), findsWidgets);
    final rootLayer = tester.widget<Transform>(
      find.byKey(const ValueKey<String>('veri_menu_layer_0')),
    );
    final middleLayer = tester.widget<Transform>(
      find.byKey(const ValueKey<String>('veri_menu_layer_1')),
    );
    final parentLayer = tester.widget<Transform>(
      find.byKey(const ValueKey<String>('veri_menu_layer_2')),
    );
    expect(
      rootLayer.transform.storage[0],
      lessThan(middleLayer.transform.storage[0]),
    );
    expect(
      middleLayer.transform.storage[0],
      lessThan(parentLayer.transform.storage[0]),
    );
    expect(parentLayer.transform.storage[0], lessThan(1));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('四级叶子'), findsNothing);
    expect(find.text('三级'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('三级'), findsNothing);
    expect(find.text('二级'), findsWidgets);
  });
}

void _noop() {}

class _MenuTestApp extends StatelessWidget {
  const _MenuTestApp({
    required this.entries,
    this.width = 224,
    this.submenuWidth = 232,
  });

  final List<VeriMenuEntry> entries;
  final double width;
  final double submenuWidth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildVeriFinTheme(Brightness.light),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: VeriAnchoredMenuButton(
              icon: Icons.more_vert,
              tooltip: '更多',
              entries: entries,
              width: width,
              submenuWidth: submenuWidth,
            ),
          ),
        ),
      ),
    );
  }
}
