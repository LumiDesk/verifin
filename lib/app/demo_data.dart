import 'package:flutter/material.dart';

import 'models.dart';

const List<AccountGroup> defaultAccountGroups = <AccountGroup>[];

const List<Account> defaultAccounts = <Account>[];

const UserProfile defaultUserProfile = UserProfile(
  nickname: 'Veri Fin',
  bio: '完全免费 · 数据自主',
  avatarDataUrl: '',
);

final List<LedgerBook> defaultLedgerBooks = <LedgerBook>[
  LedgerBook(
    id: defaultLedgerBookId,
    name: '日常账本',
    createdAt: DateTime(2026),
    isDefault: true,
  ),
];

const List<String> accountIconCodes = <String>[
  'wallet',
  'alipay',
  'wechat',
  'credit',
  'bank',
  'cash',
  'investment',
  'savings',
  'card',
  'folder',
];

IconData iconForCode(String code) {
  switch (code) {
    case 'alipay':
      return Icons.account_balance_wallet;
    case 'wechat':
      return Icons.chat_bubble_outline;
    case 'credit':
      return Icons.credit_card;
    case 'bank':
      return Icons.account_balance;
    case 'cash':
      return Icons.payments;
    case 'investment':
      return Icons.trending_up;
    case 'savings':
      return Icons.savings;
    case 'card':
      return Icons.payment;
    case 'folder':
      return Icons.folder_outlined;
    case 'wallet':
    default:
      return Icons.account_balance_wallet_outlined;
  }
}

String iconLabelForCode(String code) {
  switch (code) {
    case 'alipay':
      return '支付';
    case 'wechat':
      return '微信';
    case 'credit':
      return '信用';
    case 'bank':
      return '银行';
    case 'cash':
      return '现金';
    case 'investment':
      return '投资';
    case 'savings':
      return '储蓄';
    case 'card':
      return '卡片';
    case 'folder':
      return '分组';
    case 'wallet':
    default:
      return '钱包';
  }
}

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
    id: 'balance_adjust_expense',
    label: '余额调整',
    type: EntryType.expense,
    icon: Icons.tune,
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
    id: 'balance_adjust_income',
    label: '余额调整',
    type: EntryType.income,
    icon: Icons.tune,
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
