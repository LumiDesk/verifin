import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/category_suggest.dart';
import 'package:verifin/app/models.dart';

LedgerEntry _e({
  required EntryType type,
  required String categoryId,
  required String note,
  double amount = 30,
  String currencyCode = 'CNY',
  int hour = 12,
  List<String> tagIds = const <String>[],
}) {
  return LedgerEntry(
    id: 'e-$categoryId-$note-$hour-$amount-${tagIds.join()}',
    bookId: 'default',
    type: type,
    amount: amount,
    currencyCode: currencyCode,
    categoryId: categoryId,
    accountId: 'cash',
    note: note,
    occurredAt: DateTime(2026, 7, 5, hour, 0),
    tagIds: tagIds,
  );
}

const _expenseIds = <String>{'dining', 'transport', 'coffee', 'grocery'};
const _incomeIds = <String>{'salary', 'redpacket', 'interest'};

EntrySuggestion _suggest({
  required List<LedgerEntry> history,
  String note = '',
  required double amount,
  String currencyCode = 'CNY',
  int hour = 12,
  EntryType? forcedType,
}) {
  return suggestEntry(
    history: history,
    expenseCategoryIds: _expenseIds,
    incomeCategoryIds: _incomeIds,
    note: note,
    amount: amount,
    currencyCode: currencyCode,
    hour: hour,
    forcedType: forcedType,
  );
}

void main() {
  group('suggestEntry', () {
    test('same numeric amount in another currency is not a strong match', () {
      final suggestion = _suggest(
        history: <LedgerEntry>[
          _e(
            type: EntryType.expense,
            categoryId: 'coffee',
            note: '',
            amount: 100,
            currencyCode: 'JPY',
          ),
        ],
        amount: 100,
        currencyCode: 'CNY',
      );

      expect(suggestion.isEmpty, isTrue);
    });

    test('exact amount carries type, category, tags and note', () {
      final history = <LedgerEntry>[
        _e(
          type: EntryType.expense,
          categoryId: 'coffee',
          note: '水',
          amount: 2.8,
          tagIds: <String>['tag-drink'],
        ),
      ];
      // 再次输入 2.8：应带出支出 + 咖啡分类 + 标签 + 备注「水」。
      final s = _suggest(history: history, amount: 2.8);
      expect(s.type, EntryType.expense);
      expect(s.categoryId, 'coffee');
      expect(s.tagIds, <String>['tag-drink']);
      expect(s.note, '水');
    });

    test('tiny amount recorded as income is inferred as income', () {
      final history = <LedgerEntry>[
        _e(
          type: EntryType.income,
          categoryId: 'redpacket',
          note: '红包',
          amount: 0.01,
        ),
      ];
      final s = _suggest(history: history, amount: 0.01);
      expect(s.type, EntryType.income);
      expect(s.categoryId, 'redpacket');
    });

    test('note keyword drives the category', () {
      final history = <LedgerEntry>[
        _e(type: EntryType.expense, categoryId: 'transport', note: '打车回家'),
      ];
      final s = _suggest(history: history, note: '打车去公司', amount: 25);
      expect(s.type, EntryType.expense);
      expect(s.categoryId, 'transport');
    });

    test('no relevant history yields an empty suggestion', () {
      final history = <LedgerEntry>[
        _e(
          type: EntryType.expense,
          categoryId: 'dining',
          note: '午饭',
          amount: 40,
        ),
      ];
      // 金额与备注都对不上 → 不猜。
      final s = _suggest(history: history, amount: 7, note: '不相关');
      expect(s.isEmpty, isTrue);
    });

    test('a single non-exact loose amount match does not flip type', () {
      final history = <LedgerEntry>[
        // 唯一一笔 ~50 是收入，但金额并非精确复现（当前 55）。
        _e(type: EntryType.income, categoryId: 'salary', note: '', amount: 50),
      ];
      final s = _suggest(history: history, amount: 55);
      // 单笔且非精确 → 不敢定类型。
      expect(s.type, isNull);
    });

    test('forcedType keeps type and suggests category within it', () {
      final history = <LedgerEntry>[
        _e(type: EntryType.income, categoryId: 'salary', note: '', amount: 50),
        _e(type: EntryType.expense, categoryId: 'dining', note: '', amount: 50),
        _e(type: EntryType.expense, categoryId: 'dining', note: '', amount: 50),
      ];
      // 用户已选定支出：即便历史里也有 50 的收入，也只在支出内识别。
      final s = _suggest(
        history: history,
        amount: 50,
        forcedType: EntryType.expense,
      );
      expect(s.type, EntryType.expense);
      expect(s.categoryId, 'dining');
    });

    // issue #26：退款条目也在 `controller.entries` 里，此前会被投票成主导类型，
    // 记账页随即拿不到退款分类而崩溃白屏。退款历史必须整条不参与识别。
    test('refund history never drives the suggestion', () {
      final history = <LedgerEntry>[
        _e(
          type: EntryType.refund,
          categoryId: '',
          note: '退款到账',
          amount: 4.85,
          tagIds: <String>['tag-refund'],
        ),
        _e(
          type: EntryType.refund,
          categoryId: '',
          note: '退款到账',
          amount: 4.9,
          tagIds: <String>['tag-refund'],
        ),
      ];
      final s = _suggest(history: history, amount: 4.85);
      expect(s.type, isNull);
      // 备注/标签同样不该从退款条目带出。
      expect(s.note, isNull);
      expect(s.tagIds, isNull);
      expect(s.isEmpty, isTrue);
    });

    test('refund history does not outvote matching expense history', () {
      final history = <LedgerEntry>[
        _e(type: EntryType.refund, categoryId: '', note: '退款', amount: 4.85),
        _e(type: EntryType.refund, categoryId: '', note: '退款', amount: 4.85),
        _e(type: EntryType.refund, categoryId: '', note: '退款', amount: 4.85),
        _e(
          type: EntryType.expense,
          categoryId: 'coffee',
          note: '',
          amount: 4.85,
        ),
        _e(
          type: EntryType.expense,
          categoryId: 'coffee',
          note: '',
          amount: 4.85,
        ),
      ];
      // 退款笔数更多，但只有支出参与投票。
      final s = _suggest(history: history, amount: 4.85);
      expect(s.type, EntryType.expense);
      expect(s.categoryId, 'coffee');
    });

    // 转账不计入收支统计，仅凭金额接近就自动翻成转账错得隐蔽（金额从统计里消失）。
    test('transfer history is not auto-inferred as the type', () {
      final history = <LedgerEntry>[
        _e(type: EntryType.transfer, categoryId: '', note: '还信用卡', amount: 200),
        _e(type: EntryType.transfer, categoryId: '', note: '还信用卡', amount: 200),
      ];
      final s = _suggest(history: history, amount: 200);
      expect(s.type, isNull);
      expect(s.isEmpty, isTrue);
    });

    test('forcedType transfer still learns within transfer history', () {
      final history = <LedgerEntry>[
        _e(
          type: EntryType.transfer,
          categoryId: '',
          note: '还信用卡',
          amount: 200,
          tagIds: <String>['tag-card'],
        ),
        _e(type: EntryType.transfer, categoryId: '', note: '还信用卡', amount: 200),
      ];
      // 用户手动选了转账：仍在转账内带出备注/标签（不受自动推断白名单限制）。
      final s = _suggest(
        history: history,
        amount: 200,
        forcedType: EntryType.transfer,
      );
      expect(s.type, EntryType.transfer);
      expect(s.note, '还信用卡');
      expect(s.tagIds, <String>['tag-card']);
    });
  });
}
