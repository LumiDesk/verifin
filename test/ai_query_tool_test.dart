import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/ai/ai_query_tool.dart';
import 'package:verifin/app/models.dart';

LedgerEntry _e({
  required String id,
  EntryType type = EntryType.expense,
  double amount = 100,
  String categoryId = 'food',
  String note = '',
  List<String> tagIds = const <String>[],
  DateTime? at,
}) {
  return LedgerEntry(
    id: id,
    bookId: 'b',
    type: type,
    amount: amount,
    categoryId: categoryId,
    accountId: 'acc',
    note: note,
    occurredAt: at ?? DateTime(2026, 6, 15),
    tagIds: tagIds,
  );
}

AiToolContext _ctx(
  List<LedgerEntry> entries, {
  List<Category> categories = const <Category>[],
  List<Tag> tags = const <Tag>[],
  DateTime? now,
}) {
  return AiToolContext(
    entries: entries,
    accounts: const <Account>[],
    categories: categories,
    tags: tags,
    balanceOf: (_) => 0,
    now: now ?? DateTime(2026, 6, 20),
  );
}

Category _cat(String id, String label) =>
    Category(id: id, label: label, type: EntryType.expense, iconCode: 'food');

AiQueryTool _tool(String name) =>
    buildAiQueryTools().firstWhere((t) => t.name == name);

void main() {
  test('注册表工具名唯一且非空', () {
    final tools = buildAiQueryTools();
    final names = tools.map((t) => t.name).toList();
    expect(names.toSet().length, names.length, reason: '工具名不应重复');
    for (final t in tools) {
      expect(t.name.trim(), isNotEmpty);
      expect(t.description.trim(), isNotEmpty);
    }
  });

  test('summary 汇总当月收支净额', () {
    final ctx = _ctx(<LedgerEntry>[
      _e(id: 'x', type: EntryType.expense, amount: 300),
      _e(id: 'i', type: EntryType.income, amount: 1000),
      _e(
        id: 'old',
        type: EntryType.expense,
        amount: 999,
        at: DateTime(2026, 5, 1),
      ),
    ]);
    final r = _tool(
      'summary',
    ).run(ctx, <String, Object?>{'range': 'thisMonth'});
    final d = r.display as AiStatDisplay;
    expect(d.items.firstWhere((i) => i.label == '支出').value, 300);
    expect(d.items.firstWhere((i) => i.label == '收入').value, 1000);
    expect(d.items.firstWhere((i) => i.label == '净额').value, 700);
  });

  test('categoryRanking 按顶级分类降序、支持 limit', () {
    final ctx = _ctx(
      <LedgerEntry>[
        _e(id: 'a', amount: 100, categoryId: 'food'),
        _e(id: 'b', amount: 400, categoryId: 'travel'),
        _e(id: 'c', amount: 50, categoryId: 'fun'),
      ],
      categories: <Category>[
        _cat('food', '餐饮'),
        _cat('travel', '出行'),
        _cat('fun', '娱乐'),
      ],
    );
    final r = _tool(
      'categoryRanking',
    ).run(ctx, <String, Object?>{'range': 'thisMonth', 'limit': 2});
    final d = r.display as AiRankingDisplay;
    expect(d.rows.length, 2);
    expect(d.rows.first.label, '出行');
    expect(d.rows.first.amount, 400);
  });

  test('largestTransactions 取最大若干笔并返回 entryIds', () {
    final ctx = _ctx(<LedgerEntry>[
      _e(id: 'small', amount: 30),
      _e(id: 'big', amount: 900),
      _e(id: 'mid', amount: 300),
    ]);
    final r = _tool(
      'largestTransactions',
    ).run(ctx, <String, Object?>{'range': 'all', 'limit': 2});
    final d = r.display as AiTransactionsDisplay;
    expect(d.entryIds, <String>['big', 'mid']);
  });

  test('queryTransactions 按关键词与金额筛选', () {
    final ctx = _ctx(<LedgerEntry>[
      _e(id: 'a', amount: 200, note: '星巴克咖啡'),
      _e(id: 'b', amount: 20, note: '星巴克咖啡'),
      _e(id: 'c', amount: 200, note: '午饭'),
    ]);
    final r = _tool('queryTransactions').run(ctx, <String, Object?>{
      'range': 'all',
      'keyword': '星巴克',
      'minAmount': 50,
    });
    final d = r.display as AiTransactionsDisplay;
    expect(d.entryIds, <String>['a']);
  });

  test('缺省 / 非法参数优雅降级不抛异常', () {
    final ctx = _ctx(<LedgerEntry>[_e(id: 'a', amount: 100)]);
    for (final tool in buildAiQueryTools()) {
      expect(
        () =>
            tool.run(ctx, <String, Object?>{'range': 'nonsense', 'limit': 'x'}),
        returnsNormally,
        reason: '${tool.name} 应对非法参数降级',
      );
    }
  });

  group('AiResultDisplay 序列化往返', () {
    void roundTrip(AiResultDisplay original) {
      final restored = aiResultDisplayFromJson(original.toJson());
      expect(restored.runtimeType, original.runtimeType);
    }

    test('stat', () {
      const d = AiStatDisplay(
        title: '汇总',
        items: <AiStatItem>[
          AiStatItem(label: '支出', value: 300),
          AiStatItem(label: '净额', value: 700, emphasize: true),
        ],
      );
      roundTrip(d);
      final r = aiResultDisplayFromJson(d.toJson())! as AiStatDisplay;
      expect(r.items.last.emphasize, isTrue);
      expect(r.items.first.value, 300);
    });

    test('ranking / trend / transactions / table', () {
      roundTrip(
        const AiRankingDisplay(
          title: '排行',
          rows: <AiRankingRow>[
            AiRankingRow(label: '餐饮', amount: 400, percent: 0.8, count: 3),
          ],
        ),
      );
      roundTrip(
        const AiTrendDisplay(
          title: '趋势',
          values: <double>[1, 2, 3],
          labels: <String>['一', '二', '三'],
        ),
      );
      roundTrip(
        const AiTransactionsDisplay(title: '明细', entryIds: <String>['a', 'b']),
      );
      final table = aiResultDisplayFromJson(
        const AiTableDisplay(
          title: '表',
          headers: <String>['名称', '金额'],
          rows: <List<String>>[
            <String>['餐饮', '400'],
          ],
        ).toJson(),
      );
      expect((table! as AiTableDisplay).rows.first, <String>['餐饮', '400']);
    });

    test('未知 kind 返回 null', () {
      expect(aiResultDisplayFromJson(<String, Object?>{'kind': 'zzz'}), isNull);
    });
  });
}
