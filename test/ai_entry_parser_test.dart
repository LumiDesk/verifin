import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_client.dart';
import 'package:verifin/app/ai/ai_entry_parser.dart';
import 'package:verifin/app/models.dart';

AiEntryContext _context() => AiEntryContext(
  expenseCategories: const <AiOption>[
    AiOption(id: 'dining', label: '餐饮'),
    AiOption(id: 'transport', label: '交通'),
    AiOption(id: 'coffee', label: '餐饮 / 咖啡'),
    AiOption(id: 'shopping_online', label: '购物 / 网购'),
    AiOption(id: 'other_food', label: '餐饮 / 其他'),
    AiOption(id: 'other_shopping', label: '购物 / 其他'),
    AiOption(id: 'uncategorized_expense', label: '未分类', isUncategorized: true),
  ],
  incomeCategories: const <AiOption>[
    AiOption(id: 'salary', label: '工资'),
    AiOption(id: 'uncategorized_income', label: '未分类', isUncategorized: true),
  ],
  accounts: const <AiOption>[
    AiOption(id: 'cash', label: '现金', currencyCode: 'CNY'),
    AiOption(id: 'card', label: '招商银行', currencyCode: 'USD'),
  ],
  today: DateTime(2026, 7, 5, 9, 30),
  bookId: 'default',
  baseCurrencyCode: 'CNY',
);

void main() {
  group('buildAiEntryPrompt', () {
    test('includes category ids, accounts and today date', () {
      final prompt = buildAiEntryPrompt(_context());
      expect(prompt, contains('2026-07-05'));
      expect(prompt, contains('09:30')); // 当前时间，供解析相对时间
      expect(prompt, contains('time')); // time 字段说明
      expect(prompt, contains('dining'));
      expect(prompt, contains('transport'));
      expect(prompt, contains('salary'));
      expect(prompt, contains('card'));
      expect(prompt, contains('currencyCode'));
      expect(prompt, contains('"category"'));
      expect(prompt, contains('USD'));
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
      expect(draft.currencyCode, 'CNY');
      expect(draft.categoryId, 'transport');
      expect(draft.accountId, 'cash');
      expect(draft.note, '打车');
      expect(draft.occurredAt.year, 2026);
      expect(draft.occurredAt.month, 7);
      expect(draft.occurredAt.day, 4);
      expect(draft.warnings, isEmpty);
    });

    test('模型把字符串字段返回成数字/数组时不崩溃，降级为未识别', () {
      // categoryId 返回数字、accountId 返回数组、note 返回布尔——旧代码 as String? 会抛。
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":20,"categoryId":5,'
        '"accountId":["cash"],"note":true}',
        _context(),
      );
      expect(draft.amount, 20);
      // 非法 categoryId 落到本类型的「未分类」兜底。
      expect(draft.categoryId, 'uncategorized_expense');
      // 非法 accountId 视为空（无账户）。
      expect(draft.accountId, '');
      // 非法 note 视为空串。
      expect(draft.note, '');
    });

    test('income picks from income categories', () {
      final draft = parseAiEntryDraft(
        '{"type":"income","amount":8000,"categoryId":"salary","accountId":"card"}',
        _context(),
      );
      expect(draft.type, EntryType.income);
      expect(draft.categoryId, 'salary');
      expect(draft.accountId, 'card');
      expect(draft.currencyCode, 'USD');
    });

    test('explicit ISO currency is preserved and invalid code falls back', () {
      final foreign = parseAiEntryDraft(
        '{"type":"expense","amount":12,"currencyCode":"jpy",'
        '"categoryId":"dining","accountId":"cash"}',
        _context(),
      );
      expect(foreign.currencyCode, 'JPY');
      expect(foreign.warnings, isEmpty);

      final invalid = parseAiEntryDraft(
        '{"type":"expense","amount":12,"currencyCode":"XYZ",'
        '"categoryId":"dining","accountId":"cash"}',
        _context(),
      );
      expect(invalid.currencyCode, 'CNY');
      expect(invalid.warnings, contains(AiDraftWarning.currencyUnmatched));
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

    test('unknown category falls back to uncategorized and warns', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":10,"categoryId":"nope","accountId":"cash"}',
        _context(),
      );
      expect(draft.categoryId, 'uncategorized_expense');
      expect(draft.warnings, contains(AiDraftWarning.categoryUnmatched));
    });

    test('分类名回传时按名称解析，不再误判为未识别', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":32,"categoryId":"网购"}',
        _context(),
      );
      expect(draft.categoryId, 'shopping_online');
      expect(draft.warnings, isEmpty);
    });

    test('category 字段支持完整路径与全半角/空格差异', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":18,"categoryId":"","category":"餐饮／咖啡"}',
        _context(),
      );
      expect(draft.categoryId, 'coffee');
      expect(draft.warnings, isEmpty);
    });

    test('同名叶子分类有歧义时落到未分类并提示', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":18,"categoryId":"其他"}',
        _context(),
      );
      expect(draft.categoryId, 'uncategorized_expense');
      expect(draft.warnings, contains(AiDraftWarning.categoryUnmatched));
    });

    test('模型留空分类时直接落到未分类，不算未匹配', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":10,"accountId":"cash"}',
        _context(),
      );
      expect(draft.categoryId, 'uncategorized_expense');
      expect(draft.warnings, isEmpty);
    });

    test('收入分类未识别时落到收入的未分类，而不是支出分类', () {
      final draft = parseAiEntryDraft(
        '{"type":"income","amount":100,"categoryId":"餐饮"}',
        _context(),
      );
      expect(draft.categoryId, 'uncategorized_income');
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

    test('missing date and time default to now', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":10,"categoryId":"dining"}',
        _context(),
      );
      expect(draft.occurredAt.year, 2026);
      expect(draft.occurredAt.month, 7);
      expect(draft.occurredAt.day, 5);
      // 未提供 time → 沿用当前时刻的时分。
      expect(draft.occurredAt.hour, 9);
      expect(draft.occurredAt.minute, 30);
    });

    test('explicit time is applied on top of the date', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":58,"categoryId":"dining",'
        '"date":"2026-07-04","time":"20:00"}',
        _context(),
      );
      expect(draft.occurredAt.day, 4);
      expect(draft.occurredAt.hour, 20);
      expect(draft.occurredAt.minute, 0);
    });

    test('time without a date uses today with the given time', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":15,"categoryId":"dining","time":"7:05"}',
        _context(),
      );
      expect(draft.occurredAt.day, 5);
      expect(draft.occurredAt.hour, 7);
      expect(draft.occurredAt.minute, 5);
    });

    test('invalid time falls back to the current time', () {
      final draft = parseAiEntryDraft(
        '{"type":"expense","amount":15,"categoryId":"dining",'
        '"date":"2026-07-04","time":"25:99"}',
        _context(),
      );
      expect(draft.occurredAt.day, 4);
      expect(draft.occurredAt.hour, 9);
      expect(draft.occurredAt.minute, 30);
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
    test('carries an error code and optional detail', () {
      final ex = AiException(AiErrorCode.timeout);
      expect(ex.code, AiErrorCode.timeout);
      expect(ex.detail, isNull);

      final withDetail = AiException(AiErrorCode.upstream, detail: 'boom');
      expect(withDetail.code, AiErrorCode.upstream);
      expect(withDetail.detail, 'boom');
      expect(withDetail.toString(), contains('boom'));
    });
  });
}
