/// 按 id 的查询/展示回退纯函数：悬空分类回「已删除分类」占位（绝不冒名首个
/// 分类）、空账户 id 显示「无账户」文案。展示层取账户名一律走
/// [accountDisplayName]，勿直接 [accountById]（空 id 会误回退首个账户）。
library;

import 'demo_data.dart';
import 'models.dart';

List<Category> categoriesFor(EntryType type, [List<Category>? categories]) {
  return (categories ?? defaultCategories)
      .where((category) => category.type == type)
      .toList(growable: false);
}

Category categoryById(String id, [List<Category>? categories]) {
  return categoryByIdFrom(categories ?? defaultCategories, id);
}

/// 未知 / 已删除分类的展示占位（id 以 `id` 参数回填，保证不同的悬空 id 仍可各自成行）。
/// 仿 [accountById] 对缺失账户返回「已删除账户」——**绝不回退成列表首个分类**，否则
/// 交易的悬空/孤儿分类引用会被冒名成第一个分类（默认为「餐饮」），在分类排行里渲染出
/// 与真分类同名的「幽灵分类」（历史 bug）。
Category _deletedCategoryPlaceholder(String id) => Category(
  id: id,
  label: '已删除分类',
  type: EntryType.expense,
  iconCode: 'category',
);

Category categoryByIdFrom(List<Category> categories, String id) {
  final source = categories.isEmpty ? defaultCategories : categories;
  return source.firstWhere(
    (category) => category.id == id,
    orElse: () => _deletedCategoryPlaceholder(id),
  );
}

/// 交易账户显示名：空 id 表示「无账户」（只记金额、不计入任何账户余额）。
/// 展示层用它替代直接 [accountById]——后者对空/未知 id 会回退到首个账户而误显示。
String accountDisplayName(List<Account> accounts, String id, String noneLabel) {
  return id.isEmpty ? noneLabel : accountById(accounts, id).name;
}

Account accountById(List<Account> accounts, String id) {
  return accounts.firstWhere(
    (account) => account.id == id,
    orElse: () => accounts.isEmpty
        ? const Account(
            id: 'missing',
            bookId: defaultLedgerBookId,
            name: '已删除账户',
            type: AccountType.cash,
            groupId: null,
            initialBalance: 0,
            iconCode: 'wallet',
            note: '',
            includeInAssets: false,
            hidden: true,
          )
        : accounts.first,
  );
}
