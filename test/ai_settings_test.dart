import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_settings.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/ai_settings_page.dart';

import 'support/test_harness.dart';

void main() {
  useTestDatabases();

  testWidgets('设置页「清空配置」按钮清空并落库', (tester) async {
    final store = LocalKeyValueStore();
    final controller = await makeController(store)
      ..setAiSettings(
        const AiSettings(baseUrl: 'https://x/v1', apiKey: 'k', model: 'm'),
      );
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const AiSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空配置').last);
    await tester.pumpAndSettle();

    expect(controller.aiSettings.isConfigured, isFalse);
    controller.dispose();

    // 重启后确认已落库清空。
    final restarted = await makeController(store);
    expect(restarted.aiSettings.isConfigured, isFalse);
    restarted.dispose();
  });

  group('AiSettings', () {
    test('isConfigured requires all three fields', () {
      expect(const AiSettings().isConfigured, isFalse);
      expect(const AiSettings(baseUrl: 'x', apiKey: 'y').isConfigured, isFalse);
      expect(
        const AiSettings(
          baseUrl: 'https://x/v1',
          apiKey: 'k',
          model: 'm',
        ).isConfigured,
        isTrue,
      );
    });

    test('chatCompletionsUrl appends path and tolerates trailing slash', () {
      expect(
        const AiSettings(
          baseUrl: 'https://api.openai.com/v1',
        ).chatCompletionsUrl,
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        const AiSettings(
          baseUrl: 'https://api.openai.com/v1/',
        ).chatCompletionsUrl,
        'https://api.openai.com/v1/chat/completions',
      );
    });

    test('chatCompletionsUrl keeps a full endpoint as-is', () {
      expect(
        const AiSettings(
          baseUrl: 'https://api.example.com/v1/chat/completions',
        ).chatCompletionsUrl,
        'https://api.example.com/v1/chat/completions',
      );
    });

    test('encode/decode roundtrip', () {
      const settings = AiSettings(
        baseUrl: 'https://x/v1',
        apiKey: 'secret',
        model: 'gpt-4o-mini',
      );
      final decoded = AiSettings.decode(settings.encode());
      expect(decoded, settings);
    });

    test('decode handles null and garbage', () {
      expect(AiSettings.decode(null), const AiSettings());
      expect(AiSettings.decode('not json'), const AiSettings());
    });
  });

  group('controller AI preferences', () {
    test('fab action mode and ai settings persist across restart', () async {
      final store = LocalKeyValueStore();
      final controller = await makeController(store);
      expect(controller.fabActionMode, FabActionMode.manual);
      expect(controller.aiSettings.isConfigured, isFalse);

      controller.setFabActionMode(FabActionMode.ai);
      controller.setAiSettings(
        const AiSettings(baseUrl: 'https://x/v1', apiKey: 'k', model: 'm'),
      );
      controller.dispose();

      final restarted = await makeController(store);
      expect(restarted.fabActionMode, FabActionMode.ai);
      expect(restarted.aiSettings.model, 'm');
      expect(restarted.aiSettings.isConfigured, isTrue);
      restarted.dispose();
    });

    test('ai settings and fab mode are not part of JSON backup', () async {
      final controller = await makeController();
      controller.setFabActionMode(FabActionMode.ai);
      controller.setAiSettings(
        const AiSettings(baseUrl: 'https://x/v1', apiKey: 'k', model: 'm'),
      );
      final json = controller.exportDataJson();
      expect(json, isNot(contains('fabActionMode')));
      expect(json, isNot(contains('apiKey')));
      controller.dispose();
    });

    test('clearing ai settings removes the key', () async {
      final store = LocalKeyValueStore();
      final controller = await makeController(store);
      controller.setAiSettings(
        const AiSettings(baseUrl: 'https://x/v1', apiKey: 'k', model: 'm'),
      );
      controller.setAiSettings(const AiSettings());
      controller.dispose();

      final restarted = await makeController(store);
      expect(restarted.aiSettings.isConfigured, isFalse);
      restarted.dispose();
    });
  });
}
