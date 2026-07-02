import 'package:flutter/material.dart';

import 'models.dart';

const List<Account> demoAccounts = <Account>[
  Account(
    id: 'alipay',
    name: '支付宝',
    group: '网络支付',
    initialBalance: 895.32,
    icon: Icons.account_balance_wallet,
  ),
  Account(
    id: 'wechat',
    name: '微信',
    group: '网络支付',
    initialBalance: 0,
    icon: Icons.chat_bubble_outline,
  ),
  Account(
    id: 'huabei',
    name: '花呗',
    group: '信用账户',
    initialBalance: -53.71,
    icon: Icons.credit_card,
  ),
];

const List<Category> demoCategories = <Category>[
  Category(
    id: 'dining',
    label: '餐饮',
    type: EntryType.expense,
    icon: Icons.restaurant,
  ),
  Category(
    id: 'transport',
    label: '交通',
    type: EntryType.expense,
    icon: Icons.directions_bus,
  ),
  Category(
    id: 'shopping',
    label: '购物',
    type: EntryType.expense,
    icon: Icons.shopping_bag,
  ),
  Category(
    id: 'housing',
    label: '居住',
    type: EntryType.expense,
    icon: Icons.home_work,
  ),
  Category(
    id: 'entertainment',
    label: '娱乐',
    type: EntryType.expense,
    icon: Icons.movie,
  ),
  Category(
    id: 'medical',
    label: '医疗',
    type: EntryType.expense,
    icon: Icons.local_hospital,
  ),
  Category(
    id: 'salary',
    label: '工资',
    type: EntryType.income,
    icon: Icons.payments,
  ),
  Category(
    id: 'living',
    label: '生活费',
    type: EntryType.income,
    icon: Icons.savings,
  ),
  Category(
    id: 'interest',
    label: '利息',
    type: EntryType.income,
    icon: Icons.percent,
  ),
  Category(
    id: 'investment',
    label: '投资',
    type: EntryType.income,
    icon: Icons.trending_up,
  ),
  Category(
    id: 'bonus',
    label: '奖金',
    type: EntryType.income,
    icon: Icons.emoji_events,
  ),
  Category(
    id: 'part_time',
    label: '兼职',
    type: EntryType.income,
    icon: Icons.work,
  ),
  Category(
    id: 'transfer_out',
    label: '转出',
    type: EntryType.transfer,
    icon: Icons.call_made,
  ),
  Category(
    id: 'transfer_in',
    label: '转入',
    type: EntryType.transfer,
    icon: Icons.call_received,
  ),
  Category(
    id: 'repayment',
    label: '还款',
    type: EntryType.transfer,
    icon: Icons.swap_horiz,
  ),
];

List<Category> categoriesFor(EntryType type) {
  return demoCategories
      .where((category) => category.type == type)
      .toList(growable: false);
}

Category categoryById(String id) {
  return demoCategories.firstWhere(
    (category) => category.id == id,
    orElse: () => demoCategories.first,
  );
}

Account accountById(String id) {
  return demoAccounts.firstWhere(
    (account) => account.id == id,
    orElse: () => demoAccounts.first,
  );
}
