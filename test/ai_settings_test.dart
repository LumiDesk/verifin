import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_capabilities.dart';
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
        toolCallMode: AiToolCallMode.native,
      );
      final decoded = AiSettings.decode(settings.encode());
      expect(decoded, settings);
    });

    test('decode handles null and garbage', () {
      expect(AiSettings.decode(null), const AiSettings());
      expect(AiSettings.decode('not json'), const AiSettings());
    });

    test('old and unknown tool call modes safely default to auto', () {
      final oldSettings = AiSettings.decode(
        '{"baseUrl":"https://x/v1","apiKey":"k","model":"m"}',
      );
      final unknownMode = AiSettings.decode(
        '{"baseUrl":"https://x/v1","apiKey":"k","model":"m",'
        '"toolCallMode":"future"}',
      );

      expect(oldSettings.toolCallMode, AiToolCallMode.auto);
      expect(unknownMode.toolCallMode, AiToolCallMode.auto);
      expect(
        oldSettings.copyWith(toolCallMode: AiToolCallMode.prompt).toolCallMode,
        AiToolCallMode.prompt,
      );
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

    test(
      'ai settings stay out of JSON backup, but fab mode is included',
      () async {
        final controller = await makeController();
        controller.setFabActionMode(FabActionMode.ai);
        controller.setAiSettings(
          const AiSettings(baseUrl: 'https://x/v1', apiKey: 'k', model: 'm'),
        );
        final json = controller.exportDataJson();
        // FAB 行为已纳入备份（2026-07-12 起）。
        expect(json, contains('fabActionMode'));
        // AI 设置（含明文密钥）仍是设备本地、不进备份。
        expect(json, isNot(contains('apiKey')));
        expect(json, isNot(contains('https://x/v1')));
        controller.dispose();
      },
    );

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

    test(
      'capability cache persists and invalidates with endpoint identity',
      () async {
        final store = LocalKeyValueStore();
        final controller = await makeController(store);
        const settings = AiSettings(
          baseUrl: 'https://x/v1',
          apiKey: 'k',
          model: 'm',
        );
        controller.setAiSettings(settings);
        controller.setAiCapabilityProfile(
          AiCapabilityProfile.forSettings(
            settings: settings,
            nativeToolCalls: AiNativeToolCapability.supported,
            checkedAt: DateTime.utc(2026, 8, 6),
          ),
        );
        controller.dispose();

        final restarted = await makeController(store);
        expect(
          restarted.aiCapabilityProfile?.nativeToolCalls,
          AiNativeToolCapability.supported,
        );
        restarted.setAiSettings(
          settings.copyWith(toolCallMode: AiToolCallMode.prompt),
        );
        expect(restarted.aiCapabilityProfile, isNotNull);
        restarted.setAiSettings(settings.copyWith(model: 'other'));
        expect(restarted.aiCapabilityProfile, isNull);
        restarted.dispose();
      },
    );
  });
}
