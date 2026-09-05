import 'dart:ui' show FrameTiming;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('原机玻璃菜单表面与文字连续进入退出', (tester) async {
    final timings = <FrameTiming>[];
    void record(List<FrameTiming> frames) => timings.addAll(frames);
    binding.addTimingsCallback(record);
    addTearDown(() => binding.removeTimingsCallback(record));
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildVeriFinTheme(brightness),
          builder: (_, child) => VeriMaterialScope(
            advanced: true,
            child: VeriGlassBackdrop(child: child!),
          ),
          home: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: VeriAnchoredMenuButton(
                      tooltip: '菜单检查',
                      icon: Icons.more_vert,
                      entries: [
                        VeriMenuItem(
                          id: 'close',
                          title: '关闭菜单',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const VeriCard(
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: Text('背景内容 12345'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 首次绘制先暖机，单点计时不能包含 shader/字体首次准备成本。
      await tester.tap(find.byTooltip('菜单检查'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭菜单'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('菜单检查'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final opening = tester
            .widgetList<VeriGlassSurface>(find.byType(VeriGlassSurface))
            .singleWhere((s) => !s.grouped)
            .reveal;
        expect(opening, inExclusiveRange(0.0, 1.0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('关闭菜单'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final closing = tester
            .widgetList<VeriGlassSurface>(find.byType(VeriGlassSurface))
            .singleWhere((s) => !s.grouped)
            .reveal;
        expect(closing, inExclusiveRange(0.0, 1.0));
        expect(find.text('关闭菜单'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('关闭菜单'), findsNothing);
      }
    }
    final raster = timings.map((f) => f.rasterDuration.inMicroseconds).toList()
      ..sort();
    if (raster.isNotEmpty) {
      debugPrint(
        'MENU_TIMINGS frames=${raster.length} raster_p90_us=${raster[(raster.length * 0.9).floor()]}',
      );
    }
  });
}
