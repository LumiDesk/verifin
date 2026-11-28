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

  test('stream event limit stops oversized responses', () async {
    final settings = await _serve((request) async {
      await _requestJson(request);
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      for (var index = 0; index < 3; index += 1) {
        _sse(request.response, <String, Object?>{
          'choices': <Object?>[
            <String, Object?>{
              'delta': <String, Object?>{'content': '$index'},
            },
          ],
        });
      }
      _sse(request.response, '[DONE]');
      await request.response.close();
    });

    await expectLater(
      aiAgentStream(settings: settings, messages: messages, maxStreamEvents: 1),
      emitsInOrder(<Object>[
        isA<AiContentDelta>(),
        emitsError(
          isA<AiException>().having(
            (error) => error.code,
            'code',
            AiErrorCode.responseTooLarge,
          ),
        ),
      ]),
    );
  });

  test('total stream timeout stops a keep-alive response', () async {
    final settings = await _serve((request) async {
      await _requestJson(request);
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      for (var index = 0; index < 10; index += 1) {
        request.response.write(': keep-alive\n\n');
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await request.response.close();
    });

    await expectLater(
      aiAgentStream(
        settings: settings,
        messages: messages,
        idleTimeout: const Duration(seconds: 1),
        totalTimeout: const Duration(milliseconds: 25),
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

  test('non-stream response body limit is enforced', () async {
    final settings = await _serve((request) async {
      await _requestJson(request);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'choices': <Object?>[
            <String, Object?>{
              'message': <String, Object?>{
                'role': 'assistant',
                'content': 'a long enough answer',
              },
              'finish_reason': 'stop',
            },
          ],
        }),
      );
      await request.response.close();
    });

    await expectLater(
      aiAgentComplete(
        settings: settings,
        messages: messages,
        maxResponseBytes: 16,
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.code,
          'code',
          AiErrorCode.responseTooLarge,
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

  test('vision message serializes as OpenAI image content', () async {
    final requestBody = Completer<Map<String, Object?>>();
    const dataUrl = 'data:image/jpeg;base64,AQID';
    final settings = await _serve((request) async {
      requestBody.complete(await _requestJson(request));
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'choices': <Object?>[
            <String, Object?>{
              'message': <String, Object?>{
                'role': 'assistant',
                'content': 'ok',
              },
              'finish_reason': 'stop',
            },
          ],
        }),
      );
      await request.response.close();
    });

    final result = await aiAgentComplete(
      settings: settings,
      messages: const <AiAgentMessage>[
        AiVisionMessage(text: '看看这张图', imageDataUrl: dataUrl),
      ],
    );
    final body = await requestBody.future;

    expect(result.content, 'ok');
    final messages = body['messages']! as List<Object?>;
    final content =
        (messages.single! as Map<String, Object?>)['content']! as List<Object?>;
    expect((content[0]! as Map<String, Object?>)['type'], 'text');
    expect((content[0]! as Map<String, Object?>)['text'], '看看这张图');
    expect((content[1]! as Map<String, Object?>)['type'], 'image_url');
    final image = (content[1]! as Map<String, Object?>)['image_url'];
    expect((image! as Map<String, Object?>)['url'], dataUrl);
  });

  test('oversized request bodies are rejected before sending', () async {
    final settings = await _serve((request) async {
      await request.drain<void>();
    });
    await expectLater(
      aiAgentComplete(
        settings: settings,
        messages: <AiAgentMessage>[
          AiTextMessage.user('x' * (8 * 1024 * 1024 + 1)),
        ],
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.code,
          'code',
          AiErrorCode.requestTooLarge,
        ),
      ),
    );
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

  test('empty API key omits the Authorization header', () async {
    final settings = await _serve((request) async {
      await _requestJson(request);
      expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'choices': <Object?>[
            <String, Object?>{
              'message': <String, Object?>{
                'role': 'assistant',
                'content': 'OK',
              },
              'finish_reason': 'stop',
            },
          ],
        }),
      );
      await request.response.close();
    });

    final result = await aiAgentComplete(
      settings: settings.copyWith(apiKey: ''),
      messages: messages,
    );
    expect(result.content, 'OK');
  });

  test(
    'invalid UTF-8 response maps to bad response instead of bad URL',
    () async {
      final settings = await _serve((request) async {
        await _requestJson(request);
        request.response.headers.contentType = ContentType.json;
        request.response.add(const <int>[0xff, 0xfe, 0xfd]);
        await request.response.close();
      });

      await expectLater(
        aiAgentComplete(settings: settings, messages: messages),
        throwsA(
          isA<AiException>().having(
            (error) => error.code,
            'code',
            AiErrorCode.badResponse,
          ),
        ),
      );
    },
  );
}
