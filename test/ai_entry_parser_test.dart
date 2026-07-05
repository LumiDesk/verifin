import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_client.dart';
import 'package:verifin/app/ai/ai_entry_parser.dart';
import 'package:verifin/app/models.dart';

AiEntryContext _context() => AiEntryContext(
  expenseCategories: const <AiOption>[
    AiOption(id: 'dining', label: '餐饮'),
    AiOption(id: 'transport', label: '交通'),
    AiOption(id: 'coffee', label: '餐饮 / 咖啡'),
  ],
  incomeCategories: const <AiOption>[AiOption(id: 'salary', label: '工资')],
  accounts: const <AiOption>[
    AiOption(id: 'cash', label: '现金'),
    AiOption(id: 'card', label: '招商银行'),
  ],
  today: DateTime(2026, 7, 5, 9, 30),
  bookId: 'default',
);

void main() {
  group('buildAiEntryPrompt', () {
    test('includes category ids, accounts and today date', () {
      final prompt = buildAiEntryPrompt(_context());
      expect(prompt, contains('2026-07-05'));
      expect(prompt, contains('dining'));
      expect(prompt, contains('transport'));
      expect(prompt, contains('salary'));
      expect(prompt, contains('card'));
    });
  });

  group('extractJsonObject', () {
    test('extracts JSON wrapped in code fence and prose', () {
      const content =
          '好的，这是结果：\n```json\n{"type":"expense","amount":12}\n```\n谢谢';
      final json = extractJsonObject(content);
      expect(json, isNotNull);
      expect(json!['type'], 'expense');
      expect(json['amount'], 12);
    });

    test('returns null when no object present', () {
      expect(extractJsonObject('no json here'), isNull);
    });
  });

  group('parseAiEntryDraft', () {
    test('parses a valid expense with matched category and account', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":32,"categoryId":"transport",'
        '"accountId":"cash","toAccountId":null,"note":"打车","date":"2026-07-04"}',
        _context(),
      );
      expect(draft.type, EntryType.expense);
      expect(draft.amount, 32);
      expect(draft.categoryId, 'transport');
      expect(draft.accountId, 'cash');
      expect(draft.note, '打车');
      expect(draft.occurredAt.year, 2026);
      expect(draft.occurredAt.month, 7);
      expect(draft.occurredAt.day, 4);
      expect(draft.warnings, isEmpty);
    });

    test('income picks from income categories', () {
      final draft = parseAiEntryDraft(
        '{"type":"income","amount":8000,"categoryId":"salary","accountId":"card"}',
        _context(),
      );
      expect(draft.type, EntryType.income);
      expect(draft.categoryId, 'salary');
      expect(draft.accountId, 'card');
    });

    test('transfer keeps both accounts and empty category', () {
      final draft = parseAiEntryDraft(
        '{"type":"transfer","amount":500,"categoryId":"",'
        '"accountId":"cash","toAccountId":"card"}',
        _context(),
      );
      expect(draft.type, EntryType.transfer);
      expect(draft.accountId, 'cash');
      expect(draft.toAccountId, 'card');
      expect(draft.categoryId, '');
    });

    test('unknown category falls back to first and warns', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":10,"categoryId":"nope","accountId":"cash"}',
        _context(),
      );
      expect(draft.categoryId, 'dining');
      expect(draft.warnings, contains(AiDraftWarning.categoryUnmatched));
    });

    test('unknown account becomes no-account and warns', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":10,"categoryId":"dining","accountId":"???"}',
        _context(),
      );
      expect(draft.accountId, '');
      expect(draft.warnings, contains(AiDraftWarning.accountUnmatched));
    });

    test('missing account stays empty without warning', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":10,"categoryId":"dining","accountId":""}',
        _context(),
      );
      expect(draft.accountId, '');
      expect(draft.warnings, isEmpty);
    });

    test('amount as string is parsed and made positive', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":"-32.5","categoryId":"dining"}',
        _context(),
      );
      expect(draft.amount, 32.5);
    });

    test('missing date defaults to today', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":10,"categoryId":"dining"}',
        _context(),
      );
      expect(draft.occurredAt.year, 2026);
      expect(draft.occurredAt.month, 7);
      expect(draft.occurredAt.day, 5);
    });

    test('no amount throws noAmount', () {
      expect(
        () => parseAiEntryDraft(
          '{"type":"expense","amount":0,"categoryId":"dining"}',
          _context(),
        ),
        throwsA(
          isA<AiEntryException>().having(
            (e) => e.error,
            'error',
            AiEntryError.noAmount,
          ),
        ),
      );
    });

    test('no json throws emptyResult', () {
      expect(
        () => parseAiEntryDraft('抱歉我不明白', _context()),
        throwsA(
          isA<AiEntryException>().having(
            (e) => e.error,
            'error',
            AiEntryError.emptyResult,
          ),
        ),
      );
    });
  });

  group('AiException', () {
    test('carries a readable message', () {
      final ex = AiException('boom');
      expect(ex.message, 'boom');
      expect(ex.toString(), 'boom');
    });
  });
}
