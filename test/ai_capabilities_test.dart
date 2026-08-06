import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_agent_message.dart';
import 'package:verifin/app/ai/ai_capabilities.dart';
import 'package:verifin/app/ai/ai_completion_event.dart';
import 'package:verifin/app/ai/ai_error.dart';
import 'package:verifin/app/ai/ai_settings.dart';

void main() {
  const settings = AiSettings(
    baseUrl: 'HTTPS://Example.COM/v1/',
    apiKey: 'secret',
    model: 'model-a',
  );

  test('capability profile roundtrips without storing API key', () {
    final profile = AiCapabilityProfile.forSettings(
      settings: settings,
      nativeToolCalls: AiNativeToolCapability.supported,
      checkedAt: DateTime.utc(2026, 8, 6),
    );
    final encoded = profile.encode();
    final decoded = AiCapabilityProfile.decode(encoded);

    expect(decoded, profile);
    expect(encoded, isNot(contains('secret')));
    expect(profile.matches(settings), isTrue);
    expect(profile.matches(settings.copyWith(model: 'model-b')), isFalse);
    expect(profile.effectiveMode(settings), AiToolCallMode.native);
    expect(
      profile.effectiveMode(
        settings.copyWith(toolCallMode: AiToolCallMode.prompt),
      ),
      AiToolCallMode.prompt,
    );
  });

  test('detection checks completion, stream and native tools', () async {
    var completeCalls = 0;
    final profile = await detectAiCapabilities(
      settings: settings,
      checkedAt: DateTime.utc(2026, 8, 6),
      completeTransport: (messages, tools) async {
        completeCalls += 1;
        if (tools.isEmpty) {
          return const AiCompletionResult(
            content: 'OK',
            finishReason: AiFinishReason.stop,
          );
        }
        return const AiCompletionResult(
          finishReason: AiFinishReason.toolCalls,
          toolCalls: <AiNativeToolCall>[
            AiNativeToolCall(
              id: 'probe_1',
              name: 'verifinCapabilityProbe',
              arguments: '{}',
            ),
          ],
        );
      },
      streamTransport: (messages, tools) async* {
        yield const AiContentDelta('OK');
        yield const AiCompletionFinished(AiFinishReason.stop);
        yield const AiStreamDone();
      },
    );

    expect(completeCalls, 2);
    expect(profile.nativeToolCalls, AiNativeToolCapability.supported);
  });

  test('explicit tool protocol rejection is cached as unsupported', () async {
    var completeCalls = 0;
    final profile = await detectAiCapabilities(
      settings: settings,
      completeTransport: (messages, tools) async {
        completeCalls += 1;
        if (completeCalls == 1) {
          return const AiCompletionResult(
            content: 'OK',
            finishReason: AiFinishReason.stop,
          );
        }
        throw AiException(AiErrorCode.protocolUnsupported);
      },
      streamTransport: (messages, tools) async* {
        yield const AiContentDelta('OK');
        yield const AiCompletionFinished(AiFinishReason.stop);
      },
    );

    expect(profile.nativeToolCalls, AiNativeToolCapability.unsupported);
    expect(profile.effectiveMode(settings), AiToolCallMode.prompt);
  });

  test('network errors do not become unsupported capability', () async {
    await expectLater(
      detectAiCapabilities(
        settings: settings,
        completeTransport: (messages, tools) async {
          throw AiException(AiErrorCode.network);
        },
        streamTransport: (messages, tools) async* {
          yield const AiContentDelta('unused');
        },
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.code,
          'code',
          AiErrorCode.network,
        ),
      ),
    );
  });

  test(
    'agent mode keeps auto fallback unless native tools are unsupported',
    () {
      final supported = AiCapabilityProfile.forSettings(
        settings: settings,
        nativeToolCalls: AiNativeToolCapability.supported,
      );
      final unsupported = AiCapabilityProfile.forSettings(
        settings: settings,
        nativeToolCalls: AiNativeToolCapability.unsupported,
      );

      expect(
        resolveAiAgentMode(settings: settings, capability: supported),
        AiToolCallMode.auto,
      );
      expect(
        resolveAiAgentMode(settings: settings, capability: unsupported),
        AiToolCallMode.prompt,
      );
      expect(
        resolveAiAgentMode(
          settings: settings.copyWith(toolCallMode: AiToolCallMode.native),
          capability: unsupported,
        ),
        AiToolCallMode.native,
      );
    },
  );
}
