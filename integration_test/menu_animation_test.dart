import 'dart:ui' show FrameTiming;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/common_widgets.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('菜单表面与文字连续进入退出', (tester) async {
    final timings = <FrameTiming>[];
    void record(List<FrameTiming> frames) => timings.addAll(frames);
    binding.addTimingsCallback(record);
    addTearDown(() => binding.removeTimingsCallback(record));
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildVeriFinTheme(brightness),
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
      // 不暖机：首次打开就是用户报告的故障路径。
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      for (var i = 0; i < 3; i++) {
        debugPrint('MENU_COLD_FRAME brightness=$brightness cycle=$i opening');
        await tester.tap(find.byTooltip('菜单检查'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        expect(find.text('关闭菜单'), findsOneWidget);
        await tester.pumpAndSettle();
        await tester.tap(find.text('关闭菜单'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
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
