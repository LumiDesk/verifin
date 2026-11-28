import 'dart:convert';
import 'dart:typed_data';

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

  test('vision capability roundtrips and old cache reads unknown', () {
    final profile = AiCapabilityProfile.forSettings(
      settings: settings,
      nativeToolCalls: AiNativeToolCapability.supported,
      vision: AiVisionCapability.supported,
      checkedAt: DateTime.utc(2026, 8, 6),
    );
    final decoded = AiCapabilityProfile.decode(profile.encode());
    expect(decoded!.vision, AiVisionCapability.supported);

    final json = jsonDecode(profile.encode()) as Map<String, Object?>;
    json.remove('vision');
    final legacy = AiCapabilityProfile.decode(jsonEncode(json));
    expect(legacy!.vision, AiVisionCapability.unknown);
    expect(legacy.nativeToolCalls, AiNativeToolCapability.supported);
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
    expect(profile.vision, AiVisionCapability.unknown);
  });

  test(
    'vision probe marks a model that reads the digits as supported',
    () async {
      final profile = await detectAiCapabilities(
        settings: settings,
        visionProbeImageBytes: Uint8List.fromList(<int>[1, 2, 3]),
        checkedAt: DateTime.utc(2026, 8, 6),
        completeTransport: (messages, tools) async {
          if (messages.any((message) => message is AiVisionMessage)) {
            return const AiCompletionResult(
              content: '图里的数字是 7391',
              finishReason: AiFinishReason.stop,
            );
          }
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
        },
      );

      expect(profile.vision, AiVisionCapability.supported);
    },
  );

  test(
    'vision probe marks wrong digits and image rejection unsupported',
    () async {
      final wrong = await detectAiCapabilities(
        settings: settings,
        visionProbeImageBytes: Uint8List.fromList(<int>[1, 2, 3]),
        completeTransport: (messages, tools) async {
          if (messages.any((message) => message is AiVisionMessage)) {
            return const AiCompletionResult(
              content: '0000',
              finishReason: AiFinishReason.stop,
            );
          }
          if (tools.isEmpty) {
            return const AiCompletionResult(
              content: 'OK',
              finishReason: AiFinishReason.stop,
            );
          }
          return const AiCompletionResult(
            content: 'OK',
            finishReason: AiFinishReason.stop,
          );
        },
        streamTransport: (messages, tools) async* {
          yield const AiContentDelta('OK');
          yield const AiCompletionFinished(AiFinishReason.stop);
        },
      );
      expect(wrong.vision, AiVisionCapability.unsupported);

      final rejected = await detectAiCapabilities(
        settings: settings,
        visionProbeImageBytes: Uint8List.fromList(<int>[1, 2, 3]),
        completeTransport: (messages, tools) async {
          if (messages.any((message) => message is AiVisionMessage)) {
            throw AiException(
              AiErrorCode.serverError,
              detail: 'image input unsupported',
            );
          }
          if (tools.isEmpty) {
            return const AiCompletionResult(
              content: 'OK',
              finishReason: AiFinishReason.stop,
            );
          }
          return const AiCompletionResult(
            content: 'OK',
            finishReason: AiFinishReason.stop,
          );
        },
        streamTransport: (messages, tools) async* {
          yield const AiContentDelta('OK');
          yield const AiCompletionFinished(AiFinishReason.stop);
        },
      );
      expect(rejected.vision, AiVisionCapability.unsupported);
    },
  );

  test('vision probe network errors are not cached as unsupported', () async {
    await expectLater(
      detectAiCapabilities(
        settings: settings,
        visionProbeImageBytes: Uint8List.fromList(<int>[1, 2, 3]),
        completeTransport: (messages, tools) async {
          if (messages.any((message) => message is AiVisionMessage)) {
            throw AiException(AiErrorCode.network);
          }
          if (tools.isEmpty) {
            return const AiCompletionResult(
              content: 'OK',
              finishReason: AiFinishReason.stop,
            );
          }
          return const AiCompletionResult(
            content: 'OK',
            finishReason: AiFinishReason.stop,
          );
        },
        streamTransport: (messages, tools) async* {
          yield const AiContentDelta('OK');
          yield const AiCompletionFinished(AiFinishReason.stop);
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
