import 'models.dart';

const List<AccountGroup> defaultAccountGroups = <AccountGroup>[];

const List<Account> defaultAccounts = <Account>[];

const UserProfile defaultUserProfile = UserProfile(
  nickname: 'Veri Fin',
  bio: '完全免费 · 数据自主',
  avatarDataUrl: '',
);

/// 按语言取默认个人资料（首启动/初始化播种用；中文为兼容基准）。
UserProfile defaultUserProfileFor({required bool english}) => english
    ? const UserProfile(
        nickname: 'Veri Fin',
        bio: 'Completely free · Own your data',
        avatarDataUrl: '',
      )
    : defaultUserProfile;

final List<LedgerBook> defaultLedgerBooks = <LedgerBook>[
  LedgerBook(
    id: defaultLedgerBookId,
    name: '日常账本',
    createdAt: DateTime(2026),
    isDefault: true,
  ),
];

/// 按语言取默认账本（账本名是数据，播种后随用户编辑）。
List<LedgerBook> defaultLedgerBooksFor({required bool english}) => <LedgerBook>[
  LedgerBook(
    id: defaultLedgerBookId,
    name: english ? 'Daily Ledger' : '日常账本',
    createdAt: DateTime(2026),
    isDefault: true,
  ),
];

const List<Category> defaultCategories = <Category>[
  Category(
    id: 'dining',
    label: '餐饮',
    type: EntryType.expense,
    iconCode: 'dining',
  ),
  Category(
    id: 'transport',
    label: '交通',
    type: EntryType.expense,
    iconCode: 'transport',
  ),
  Category(
    id: 'shopping',
    label: '购物',
    type: EntryType.expense,
    iconCode: 'shopping',
  ),
  Category(
    id: 'housing',
    label: '居住',
    type: EntryType.expense,
    iconCode: 'housing',
  ),
  Category(
    id: 'entertainment',
    label: '娱乐',
    type: EntryType.expense,
    iconCode: 'entertainment',
  ),
  Category(
    id: 'medical',
    label: '医疗',
    type: EntryType.expense,
    iconCode: 'medical',
  ),
  Category(
    id: 'balance_adjust_expense',
    label: '余额调整',
    type: EntryType.expense,
    iconCode: 'adjust',
  ),
  Category(
    id: 'salary',
    label: '工资',
    type: EntryType.income,
    iconCode: 'salary',
  ),
  Category(
    id: 'living',
    label: '生活费',
    type: EntryType.income,
    iconCode: 'savings',
  ),
  Category(
    id: 'interest',
    label: '利息',
    type: EntryType.income,
    iconCode: 'interest',
  ),
  Category(
    id: 'investment',
    label: '投资',
    type: EntryType.income,
    iconCode: 'investment',
  ),
  Category(id: 'bonus', label: '奖金', type: EntryType.income, iconCode: 'bonus'),
  Category(
    id: 'part_time',
    label: '兼职',
    type: EntryType.income,
    iconCode: 'work',
  ),
  Category(
    id: 'balance_adjust_income',
    label: '余额调整',
    type: EntryType.income,
    iconCode: 'adjust',
  ),
  Category(
    id: 'transfer_out',
    label: '转出',
    type: EntryType.transfer,
    iconCode: 'transfer_out',
  ),
  Category(
    id: 'transfer_in',
    label: '转入',
    type: EntryType.transfer,
    iconCode: 'transfer_in',
  ),
  Category(
    id: 'repayment',
    label: '还款',
    type: EntryType.transfer,
    iconCode: 'repayment',
  ),
];

const List<Category> demoCategories = defaultCategories;

/// 英文种子分类：id/图标与中文版一一对应，仅名称不同。
const List<Category> _defaultCategoriesEn = <Category>[
  Category(
    id: 'dining',
    label: 'Dining',
    type: EntryType.expense,
    iconCode: 'dining',
  ),
  Category(
    id: 'transport',
    label: 'Transport',
    type: EntryType.expense,
    iconCode: 'transport',
  ),
  Category(
    id: 'shopping',
    label: 'Shopping',
    type: EntryType.expense,
    iconCode: 'shopping',
  ),
  Category(
    id: 'housing',
    label: 'Housing',
    type: EntryType.expense,
    iconCode: 'housing',
  ),
  Category(
    id: 'entertainment',
    label: 'Entertainment',
    type: EntryType.expense,
    iconCode: 'entertainment',
  ),
  Category(
    id: 'medical',
    label: 'Medical',
    type: EntryType.expense,
    iconCode: 'medical',
  ),
  Category(
    id: 'balance_adjust_expense',
    label: 'Balance adjustment',
    type: EntryType.expense,
    iconCode: 'adjust',
  ),
  Category(
    id: 'salary',
    label: 'Salary',
    type: EntryType.income,
    iconCode: 'salary',
  ),
  Category(
    id: 'living',
    label: 'Allowance',
    type: EntryType.income,
    iconCode: 'savings',
  ),
  Category(
    id: 'interest',
    label: 'Interest',
    type: EntryType.income,
    iconCode: 'interest',
  ),
  Category(
    id: 'investment',
    label: 'Investment',
    type: EntryType.income,
    iconCode: 'investment',
  ),
  Category(
    id: 'bonus',
    label: 'Bonus',
    type: EntryType.income,
    iconCode: 'bonus',
  ),
  Category(
    id: 'part_time',
    label: 'Part-time',
    type: EntryType.income,
    iconCode: 'work',
  ),
  Category(
    id: 'balance_adjust_income',
    label: 'Balance adjustment',
    type: EntryType.income,
    iconCode: 'adjust',
  ),
  Category(
    id: 'transfer_out',
    label: 'Transfer out',
    type: EntryType.transfer,
    iconCode: 'transfer_out',
  ),
  Category(
    id: 'transfer_in',
    label: 'Transfer in',
    type: EntryType.transfer,
    iconCode: 'transfer_in',
  ),
  Category(
    id: 'repayment',
    label: 'Repayment',
    type: EntryType.transfer,
    iconCode: 'repayment',
  ),
];

/// 按语言取默认分类（首启动/初始化播种用；分类名是数据，播种后随用户编辑）。
List<Category> defaultCategoriesFor({required bool english}) =>
    english ? _defaultCategoriesEn : defaultCategories;
