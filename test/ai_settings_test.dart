import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_capabilities.dart';
import 'package:verifin/app/ai/ai_model_catalog.dart';
import 'package:verifin/app/ai/ai_provider_presets.dart';
import 'package:verifin/app/ai/ai_settings.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/local_storage/local_storage.dart';
import 'package:verifin/pages/ai_settings_page.dart';

import 'support/test_harness.dart';

Finder _textField(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

String _fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(_textField(label)).controller?.text ?? '';

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

  testWidgets('AI 配置输入停止后自动保存', (tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const AiSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      _textField('请求地址（Base URL）'),
      'https://example.com/v1',
    );
    await tester.enterText(_textField('API Key（可选）'), 'secret');
    await tester.enterText(_textField('模型'), 'model');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.byIcon(Icons.save_outlined), findsNothing);
    expect(controller.aiSettings.baseUrl, 'https://example.com/v1');
    expect(controller.aiSettings.apiKey, 'secret');
    expect(controller.aiSettings.model, 'model');
    expect(controller.aiSettings.isConfigured, isTrue);
  });

  testWidgets('选择预设渠道后 Base URL 只读，空 Key 也可保存', (tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const AiSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai_provider_current_card')));
    await tester.pumpAndSettle();
    expect(find.text('选择 AI 渠道'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_provider_option_deepseek')));
    await tester.pumpAndSettle();

    final baseField = tester.widget<TextField>(_textField('请求地址（Base URL）'));
    expect(baseField.readOnly, isTrue);
    expect(_fieldText(tester, '请求地址（Base URL）'), contains('deepseek.com'));
    expect(_fieldText(tester, 'API Key（可选）'), isEmpty);

    await tester.enterText(_textField('模型'), 'deepseek-chat');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(controller.aiSettings.providerId, 'deepseek');
    expect(controller.aiSettings.baseUrl, 'https://api.deepseek.com/v1');
    expect(controller.aiSettings.apiKey, isEmpty);
    expect(controller.aiSettings.model, 'deepseek-chat');
  });

  testWidgets('自定义渠道可编辑 Base URL 并选择获取到的模型', (tester) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(
          home: AiSettingsPage(
            debugFetchModels: (settings, provider) async {
              expect(provider.id, customAiProviderId);
              expect(settings.baseUrl, 'https://example.com/v1');
              return const <AiModelInfo>[
                AiModelInfo(id: 'model-a', ownedBy: 'Vendor A'),
                AiModelInfo(id: 'model-b', ownedBy: 'Vendor B'),
              ];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(_textField('请求地址（Base URL）')).readOnly,
      isFalse,
    );
    await tester.enterText(
      _textField('请求地址（Base URL）'),
      'https://example.com/v1',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('获取模型列表'));
    await tester.pumpAndSettle();

    expect(find.text('选择模型'), findsOneWidget);
    expect(find.text('Vendor A'), findsWidgets);
    expect(find.text('Vendor B'), findsWidgets);
    await tester.tap(find.byKey(const Key('ai_model_option_model-b')));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, '模型'), 'model-b');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(controller.aiSettings.model, 'model-b');
    expect(controller.aiSettings.isConfigured, isTrue);
  });

  testWidgets('工具调用协议使用锚点菜单并在保存后提交', (tester) async {
    final controller = await makeController()
      ..setAiSettings(
        const AiSettings(
          baseUrl: 'https://example.com/v1',
          apiKey: 'secret',
          model: 'model',
        ),
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const AiSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    final toolModeField = find.byKey(const Key('ai_tool_mode_field'));
    await tester.ensureVisible(toolModeField);
    await tester.pumpAndSettle();
    expect(find.text('自动（推荐）'), findsOneWidget);
    expect(find.text('优先使用原生协议，不支持时自动兼容'), findsNothing);
    await tester.tap(toolModeField);
    await tester.pumpAndSettle();
    expect(find.text('用于不支持原生工具调用的模型或中转服务'), findsOneWidget);
    await tester.tap(find.text('兼容模式'));
    await tester.pumpAndSettle();

    expect(controller.aiSettings.toolCallMode, AiToolCallMode.prompt);
  });

  testWidgets('连接配置使用可见输入框并隐藏多余说明', (tester) async {
    final controller = await makeController()
      ..setAiSettings(
        const AiSettings(
          baseUrl: 'https://example.com/v1',
          apiKey: 'secret',
          model: 'model',
        ),
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const AiSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      final border = field.decoration?.enabledBorder;
      expect(border, isA<OutlineInputBorder>());
      expect(
        (border! as OutlineInputBorder).borderSide.style,
        isNot(BorderStyle.none),
      );
    }
    expect(find.textContaining('选择预设渠道，或使用自定义 OpenAI 兼容端点'), findsNothing);
    expect(find.text('预设渠道地址由 VeriFin 固定'), findsNothing);
    expect(find.text('可留空；部分渠道会返回鉴权错误'), findsNothing);
    expect(find.textContaining('能力检测会发起少量测试请求'), findsNothing);
    expect(find.textContaining('AI 是可选功能'), findsNothing);
  });

  group('AiSettings', () {
    test(
      'isConfigured requires base URL and model but allows empty API key',
      () {
        expect(const AiSettings().isConfigured, isFalse);
        expect(
          const AiSettings(baseUrl: 'x', apiKey: 'y').isConfigured,
          isFalse,
        );
        expect(
          const AiSettings(
            baseUrl: 'https://x/v1',
            apiKey: 'k',
            model: 'm',
          ).isConfigured,
          isTrue,
        );
        expect(
          const AiSettings(baseUrl: 'https://x/v1', model: 'm').isConfigured,
          isTrue,
        );
      },
    );

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
        providerId: 'deepseek',
        baseUrl: 'https://x/v1',
        apiKey: 'secret',
        model: 'gpt-4o-mini',
        modelListUrl: 'https://x/v1/custom-models',
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
      expect(oldSettings.providerId, 'custom');
      expect(oldSettings.modelListUrl, isEmpty);
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
