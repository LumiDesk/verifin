import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/category_suggest.dart';
import 'package:verifin/app/models.dart';

LedgerEntry _e({
  required String categoryId,
  required String note,
  double amount = 30,
  int hour = 12,
}) {
  return LedgerEntry(
    id: 'e-$categoryId-$note-$hour-$amount',
    bookId: 'default',
    type: EntryType.expense,
    amount: amount,
    categoryId: categoryId,
    accountId: 'cash',
    note: note,
    occurredAt: DateTime(2026, 7, 5, hour, 0),
  );
}

const _candidates = <String>{'dining', 'transport', 'coffee', 'grocery'};

void main() {
  group('suggestCategoryId', () {
    test('note keyword matches a past entry category', () {
      final history = <LedgerEntry>[
        _e(categoryId: 'transport', note: '打车回家'),
        _e(categoryId: 'grocery', note: '超市买菜'),
        _e(categoryId: 'dining', note: '午饭'),
      ];
      final suggestion = suggestCategoryId(
        history: history,
        candidateIds: _candidates,
        note: '打车去公司',
        amount: 25,
        hour: 9,
      );
      expect(suggestion, 'transport');
    });

    test('habit: same hour and amount points to a category without a note', () {
      final history = <LedgerEntry>[
        // 早 8 点、~15 元，稳定是早餐（dining）。
        for (var i = 0; i < 6; i++)
          _e(categoryId: 'dining', note: '', amount: 15, hour: 8),
        // 其他分类在别的时段/金额。
        for (var i = 0; i < 6; i++)
          _e(categoryId: 'transport', note: '', amount: 100, hour: 18),
      ];
      final suggestion = suggestCategoryId(
        history: history,
        candidateIds: _candidates,
        note: '',
        amount: 16,
        hour: 8,
      );
      expect(suggestion, 'dining');
    });

    test('returns null when there is no usable history', () {
      final suggestion = suggestCategoryId(
        history: const <LedgerEntry>[],
        candidateIds: _candidates,
        note: '随便写点',
        amount: 42,
        hour: 10,
      );
      expect(suggestion, isNull);
    });

    test('returns null when signals are evenly split (low confidence)', () {
      final history = <LedgerEntry>[
        _e(categoryId: 'dining', note: '', amount: 30, hour: 12),
        _e(categoryId: 'transport', note: '', amount: 30, hour: 12),
      ];
      final suggestion = suggestCategoryId(
        history: history,
        candidateIds: _candidates,
        note: '',
        amount: 30,
        hour: 12,
      );
      expect(suggestion, isNull);
    });

    test('ignores categories outside the candidate set', () {
      final history = <LedgerEntry>[
        // 历史里全是已删除/异类分类，无一在候选集内。
        _e(categoryId: 'legacy-cat', note: '打车'),
        _e(categoryId: 'legacy-cat', note: '打车'),
      ];
      final suggestion = suggestCategoryId(
        history: history,
        candidateIds: _candidates,
        note: '打车',
        amount: 25,
        hour: 9,
      );
      expect(suggestion, isNull);
    });

    test('strong note match wins over a more frequent other category', () {
      final history = <LedgerEntry>[
        // dining 很常见，但都与「咖啡」无关。
        for (var i = 0; i < 20; i++)
          _e(categoryId: 'dining', note: '午饭', amount: 40, hour: 12),
        // coffee 只有一笔，但备注高度吻合。
        _e(categoryId: 'coffee', note: '瑞幸咖啡', amount: 18, hour: 15),
      ];
      final suggestion = suggestCategoryId(
        history: history,
        candidateIds: _candidates,
        note: '瑞幸咖啡',
        amount: 18,
        hour: 15,
      );
      expect(suggestion, 'coffee');
    });
  });
}
