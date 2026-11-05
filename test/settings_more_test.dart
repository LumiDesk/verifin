import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/external_links.dart';

import 'support/test_harness.dart';

Future<void> _openSettings(WidgetTester tester) async {
  await tapBottomTab(tester, 3);
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

Future<void> _scrollToMore(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('GitHub 仓库'), 200);
  await tester.ensureVisible(find.text('GitHub 仓库'));
  await tester.pumpAndSettle();
}

void main() {
  useTestDatabases();
  tearDown(() => ExternalLinks.debugOpener = null);

  testWidgets('「更多」分组排在「关于」之后，含检查更新与 GitHub 仓库', (tester) async {
    await pumpApp(tester);
    await _openSettings(tester);
    await _scrollToMore(tester);

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('GitHub 仓库'), findsOneWidget);

    // 「更多」在「关于」之后；检查更新已移出关于卡片（位于「鸣谢」下方）。
    expect(
      tester.getTopLeft(find.text('更多')).dy,
      greaterThan(tester.getTopLeft(find.text('关于')).dy),
    );
    expect(
      tester.getTopLeft(find.text('检查更新')).dy,
      greaterThan(tester.getTopLeft(find.text('鸣谢')).dy),
    );
  });

  testWidgets('GitHub 仓库入口用系统浏览器打开仓库主页', (tester) async {
    final opened = <Uri>[];
    ExternalLinks.debugOpener = (url) async {
      opened.add(url);
      return true;
    };
    await pumpApp(tester);
    await _openSettings(tester);
    await _scrollToMore(tester);

    await tester.tap(find.text('GitHub 仓库'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(opened.single.toString(), ExternalLinks.verifinRepositoryUrl);
  });

  testWidgets('浏览器打不开时 GitHub 仓库入口给出错误轻提示', (tester) async {
    ExternalLinks.debugOpener = (url) async => false;
    await pumpApp(tester);
    await _openSettings(tester);
    await _scrollToMore(tester);

    await tester.tap(find.text('GitHub 仓库'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('没能打开浏览器，请稍后再试。'), findsOneWidget);
  });
}
