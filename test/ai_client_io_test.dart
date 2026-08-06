import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_agent_message.dart';
import 'package:verifin/app/ai/ai_client.dart';
import 'package:verifin/app/ai/ai_completion_event.dart';
import 'package:verifin/app/ai/ai_settings.dart';

typedef _RequestHandler = Future<void> Function(HttpRequest request);

Future<AiSettings> _serve(_RequestHandler handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final pending = <Future<void>>[];
  final subscription = server.listen((request) {
    pending.add(handler(request));
  });
  addTearDown(() async {
    await subscription.cancel();
    await server.close(force: true);
    for (final future in pending) {
      try {
        await future;
      } on HttpException {
        // 断流测试会先关闭客户端 socket，服务端收尾失败属于预期。
      }
    }
  });
  return AiSettings(
    baseUrl: 'http://${server.address.address}:${server.port}/v1',
    apiKey: 'test-key',
    model: 'test-model',
  );
}

Future<Map<String, Object?>> _requestJson(HttpRequest request) async {
  final text = await utf8.decoder.bind(request).join();
  return Map<String, Object?>.from(jsonDecode(text) as Map);
}

void _sse(HttpResponse response, Object data) {
  response.write('data: ${data is String ? data : jsonEncode(data)}\n\n');
}

void main() {
  const messages = <AiAgentMessage>[AiTextMessage.user('hello')];
  const tools = <Map<String, Object?>>[
    <String, Object?>{
      'type': 'function',
      'function': <String, Object?>{
        'name': 'summary',
        'description': 'summary',
        'parameters': <String, Object?>{'type': 'object'},
      },
    },
  ];

  test('stream parses content, reasoning and fragmented tool calls', () async {
    final requestBody = Completer<Map<String, Object?>>();
    final settings = await _serve((request) async {
      requestBody.complete(await _requestJson(request));
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      _sse(request.response, <String, Object?>{
        'choices': <Object?>[
          <String, Object?>{
            'delta': <String, Object?>{
              'reasoning_content': 'private',
              'tool_calls': <Object?>[
                <String, Object?>{
                  'index': 0,
                  'id': 'call_1',
                  'function': <String, Object?>{
                    'name': 'sum',
                    'arguments': '{"range":',
                  },
                },
              ],
            },
          },
        ],
      });
      _sse(request.response, <String, Object?>{
        'choices': <Object?>[
          <String, Object?>{
            'delta': <String, Object?>{
              'content': 'working',
              'tool_calls': <Object?>[
                <String, Object?>{
                  'index': 0,
                  'function': <String, Object?>{
                    'name': 'mary',
                    'arguments': '"thisMonth"}',
                  },
                },
              ],
            },
            'finish_reason': 'tool_calls',
          },
        ],
      });
      _sse(request.response, '[DONE]');
      await request.response.close();
    });

    final events = await aiAgentStream(
      settings: settings,
      messages: messages,
      tools: tools,
    ).toList();
    final body = await requestBody.future;

    expect(events.whereType<AiReasoningDelta>().single.text, 'private');
    expect(events.whereType<AiContentDelta>().single.text, 'working');
    expect(events.whereType<AiToolCallDelta>(), hasLength(2));
    expect(
      events.whereType<AiCompletionFinished>().single.reason,
      AiFinishReason.toolCalls,
    );
    expect(events.whereType<AiStreamDone>(), hasLength(1));
    expect(body['stream'], isTrue);
    expect(body['tool_choice'], 'auto');
    expect(body['tools'], hasLength(1));
  });

  test('stream accepts a finish reason when endpoint omits DONE', () async {
    final settings = await _serve((request) async {
      await _requestJson(request);
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      _sse(request.response, <String, Object?>{
        'choices': <Object?>[
          <String, Object?>{
            'delta': <String, Object?>{'content': 'answer'},
            'finish_reason': 'stop',
          },
        ],
      });
      await request.response.close();
    });

    final events = await aiAgentStream(
      settings: settings,
      messages: messages,
    ).toList();

    expect(events.whereType<AiContentDelta>().single.text, 'answer');
    expect(
      events.whereType<AiCompletionFinished>().single.reason,
      AiFinishReason.stop,
    );
    expect(events.whereType<AiStreamDone>(), isEmpty);
  });

  test('stream rejects a natural close without a terminal marker', () async {
    final settings = await _serve((request) async {
      await _requestJson(request);
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      _sse(request.response, <String, Object?>{
        'choices': <Object?>[
          <String, Object?>{
            'delta': <String, Object?>{'content': 'partial'},
          },
        ],
      });
      await request.response.close();
    });

    await expectLater(
      aiAgentStream(settings: settings, messages: messages),
      emitsInOrder(<Object>[
        isA<AiContentDelta>(),
        emitsError(
          isA<AiException>().having(
            (error) => error.code,
            'code',
            AiErrorCode.incompleteStream,
          ),
        ),
      ]),
    );
  });

  test('stream idle timeout is mapped without hanging', () async {
    final settings = await _serve((request) async {
      await _requestJson(request);
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      request.response.write(': keep-alive\n\n');
      await request.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await request.response.close();
    });

    await expectLater(
      aiAgentStream(
        settings: settings,
        messages: messages,
        idleTimeout: const Duration(milliseconds: 20),
      ),
      emitsError(
        isA<AiException>().having(
          (error) => error.code,
          'code',
          AiErrorCode.timeout,
        ),
      ),
    );
  });

  test('non-stream completion parses native tool calls', () async {
    final settings = await _serve((request) async {
      await _requestJson(request);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'choices': <Object?>[
            <String, Object?>{
              'message': <String, Object?>{
                'role': 'assistant',
                'content': null,
                'reasoning_content': 'private',
                'tool_calls': <Object?>[
                  <String, Object?>{
                    'id': 'call_1',
                    'type': 'function',
                    'function': <String, Object?>{
                      'name': 'summary',
                      'arguments': '{"range":"thisMonth"}',
                    },
                  },
                ],
              },
              'finish_reason': 'tool_calls',
            },
          ],
        }),
      );
      await request.response.close();
    });

    final result = await aiAgentComplete(
      settings: settings,
      messages: messages,
      tools: tools,
    );

    expect(result.finishReason, AiFinishReason.toolCalls);
    expect(result.reasoningContent, 'private');
    expect(result.toolCalls.single.name, 'summary');
    expect(result.toolCalls.single.decodeArguments(), <String, Object?>{
      'range': 'thisMonth',
    });
  });

  test('explicit unsupported tools response gets a dedicated error', () async {
    final settings = await _serve((request) async {
      await _requestJson(request);
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{
            'message': 'tools are not supported by this model',
          },
        }),
      );
      await request.response.close();
    });

    await expectLater(
      aiAgentComplete(settings: settings, messages: messages, tools: tools),
      throwsA(
        isA<AiException>().having(
          (error) => error.code,
          'code',
          AiErrorCode.protocolUnsupported,
        ),
      ),
    );
  });
}
