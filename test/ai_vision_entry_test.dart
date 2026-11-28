import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:verifin/app/ai/ai_entry_parser.dart';
import 'package:verifin/app/ai/ai_error.dart';
import 'package:verifin/app/ai/ai_settings.dart';
import 'package:verifin/app/ai/ai_vision_entry.dart';

AiEntryContext _context() => AiEntryContext(
  expenseCategories: const <AiOption>[
    AiOption(id: 'dining', label: '餐饮'),
    AiOption(id: 'transport', label: '交通'),
  ],
  incomeCategories: const <AiOption>[AiOption(id: 'salary', label: '工资')],
  accounts: const <AiOption>[
    AiOption(id: 'cash', label: '现金', currencyCode: 'CNY'),
  ],
  today: DateTime(2026, 11, 28, 12, 30),
  bookId: 'default',
  baseCurrencyCode: 'CNY',
);

Future<AiSettings> _serve(
  Future<void> Function(HttpRequest request, Map<String, Object?> body) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final subscription = server.listen((request) async {
    final body =
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, Object?>;
    await handler(request, body);
  });
  addTearDown(() async {
    await subscription.cancel();
    await server.close(force: true);
  });
  return AiSettings(
    baseUrl: 'http://${server.address.address}:${server.port}/v1',
    apiKey: 'test-key',
    model: 'vision-model',
  );
}

Uint8List _testImage() {
  final image = img.Image(width: 80, height: 80, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(230, 230, 230));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('buildVisionEntryPrompt includes image rules and no OCR dependency', () {
    final prompt = buildVisionEntryPrompt(_context());
    expect(prompt, contains('dining'));
    expect(prompt, contains('2026-11-28'));
    expect(prompt, contains('图片'));
    expect(prompt, contains('余额'));
    expect(prompt, contains('只输出一个 JSON'));
    expect(prompt, isNot(contains('OCR')));
  });

  test(
    'requestVisionEntryDraft sends image_url and parses the draft',
    () async {
      Map<String, Object?>? capturedBody;
      final settings = await _serve((request, body) async {
        capturedBody = body;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'choices': <Object?>[
              <String, Object?>{
                'message': <String, Object?>{
                  'role': 'assistant',
                  'content': jsonEncode(<String, Object?>{
                    'type': 'expense',
                    'amount': 32,
                    'currencyCode': 'CNY',
                    'categoryId': 'dining',
                    'accountId': 'cash',
                    'toAccountId': null,
                    'note': '午饭',
                    'date': '2026-11-28',
                    'time': null,
                  }),
                },
                'finish_reason': 'stop',
              },
            ],
          }),
        );
        await request.response.close();
      });

      final draft = await requestVisionEntryDraft(
        settings: settings,
        imageBytes: _testImage(),
        context: _context(),
      );

      expect(draft.amount, 32);
      expect(draft.categoryId, 'dining');
      expect(draft.accountId, 'cash');
      final messages = capturedBody!['messages']! as List<Object?>;
      final content =
          (messages.last! as Map<String, Object?>)['content']! as List<Object?>;
      final imagePart = content.last! as Map<String, Object?>;
      expect(imagePart['type'], 'image_url');
      final imageUrl = imagePart['image_url']! as Map<String, Object?>;
      expect(imageUrl['url'], startsWith('data:image/jpeg;base64,'));
    },
  );

  test('image rejection is mapped to visionUnsupported', () async {
    final settings = await _serve((request, body) async {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{'message': 'image input unsupported'},
        }),
      );
      await request.response.close();
    });

    await expectLater(
      requestVisionEntryDraft(
        settings: settings,
        imageBytes: _testImage(),
        context: _context(),
      ),
      throwsA(
        isA<AiException>().having(
          (error) => error.code,
          'code',
          AiErrorCode.visionUnsupported,
        ),
      ),
    );
  });
}
