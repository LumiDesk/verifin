import '../l10n/app_localizations.dart';

const List<String> genericAccountIconCodes = <String>[
  'wallet',
  'credit',
  'bank',
  'cash',
  'investment',
  'savings',
  'card',
];

const Map<String, String> genericAccountIconAssetPaths = <String, String>{
  'wallet': 'assets/account_icons/generic_wallet.svg',
  'credit': 'assets/account_icons/generic_credit.svg',
  'bank': 'assets/account_icons/generic_bank.svg',
  'cash': 'assets/account_icons/generic_cash.svg',
  'investment': 'assets/account_icons/generic_investment.svg',
  'savings': 'assets/account_icons/generic_savings.svg',
  'card': 'assets/account_icons/generic_card.svg',
};

class AccountIconOption {
  const AccountIconOption({
    required this.code,
    required this.label,
    required this.groupKey,
    required this.assetPath,
    this.searchTerms = const <String>[],
  });

  final String code;

  /// 品牌/银行名是专有名词，不随语言切换。
  final String label;

  /// 分组标识（credit/payment/bank），显示名经 [groupLabel] 从 ARB 解析。
  final String groupKey;
  final String assetPath;

  /// 用户常输入的中文简称、英文名或机构缩写。搜索与账户名自动推荐共用。
  final List<String> searchTerms;

  String groupLabel(AppLocalizations l10n) {
    switch (groupKey) {
      case 'credit':
        return l10n.iconGroupCredit;
      case 'payment':
        return l10n.iconGroupPayment;
      case 'bank':
        return l10n.iconGroupBank;
    }
    return groupKey;
  }
}

const List<AccountIconOption> accountAssetIconOptions = <AccountIconOption>[
  AccountIconOption(
    code: 'asset:credit_001',
    label: '白条',
    groupKey: 'credit',
    assetPath: 'assets/account_icons/credit_001.svg',
    searchTerms: <String>['京东白条', 'jd', 'baitiao'],
  ),
  AccountIconOption(
    code: 'asset:credit_002',
    label: '花呗',
    groupKey: 'credit',
    assetPath: 'assets/account_icons/credit_002.svg',
    searchTerms: <String>['huabei', 'ant credit pay'],
  ),
  AccountIconOption(
    code: 'asset:payment_001',
    label: 'Mastercard',
    groupKey: 'payment',
    assetPath: 'assets/account_icons/payment_001.svg',
    searchTerms: <String>['master card', '万事达'],
  ),
  AccountIconOption(
    code: 'asset:payment_002',
    label: 'PayPal',
    groupKey: 'payment',
    assetPath: 'assets/account_icons/payment_002.svg',
    searchTerms: <String>['贝宝'],
  ),
  AccountIconOption(
    code: 'asset:payment_003',
    label: 'Stripe',
    groupKey: 'payment',
    assetPath: 'assets/account_icons/payment_003.svg',
  ),
  AccountIconOption(
    code: 'asset:payment_004',
    label: '微信支付',
    groupKey: 'payment',
    assetPath: 'assets/account_icons/payment_004.svg',
    searchTerms: <String>['微信', 'wechat', 'weixin', 'wx'],
  ),
  AccountIconOption(
    code: 'asset:payment_005',
    label: '银联',
    groupKey: 'payment',
    assetPath: 'assets/account_icons/payment_005.svg',
    searchTerms: <String>['unionpay', 'china unionpay'],
  ),
  AccountIconOption(
    code: 'asset:payment_006',
    label: '支付宝',
    groupKey: 'payment',
    assetPath: 'assets/account_icons/payment_006.svg',
    searchTerms: <String>['alipay', 'zfb'],
  ),
  AccountIconOption(
    code: 'asset:bank_001',
    label: '上海银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_001.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_002',
    label: '上饶银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_002.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_003',
    label: '中信银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_003.svg',
    searchTerms: <String>['中信', 'citic'],
  ),
  AccountIconOption(
    code: 'asset:bank_004',
    label: '中国民生银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_004.svg',
    searchTerms: <String>['民生', 'cmbc'],
  ),
  AccountIconOption(
    code: 'asset:bank_005',
    label: '中国邮政储蓄银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_005.svg',
    searchTerms: <String>['邮储', 'psbc'],
  ),
  AccountIconOption(
    code: 'asset:bank_006',
    label: '中国银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_006.svg',
    searchTerms: <String>['中行', 'boc'],
  ),
  AccountIconOption(
    code: 'asset:bank_007',
    label: '乌鲁木齐市商业银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_007.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_008',
    label: '交通银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_008.svg',
    searchTerms: <String>['交通', '交行', 'bocom'],
  ),
  AccountIconOption(
    code: 'asset:bank_009',
    label: '兴业银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_009.svg',
    searchTerms: <String>['兴业', 'cib'],
  ),
  AccountIconOption(
    code: 'asset:bank_010',
    label: '农业银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_010.svg',
    searchTerms: <String>['农业', '农行', 'abc'],
  ),
  AccountIconOption(
    code: 'asset:bank_011',
    label: '北京银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_011.svg',
    searchTerms: <String>['bob'],
  ),
  AccountIconOption(
    code: 'asset:bank_012',
    label: '华夏银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_012.svg',
    searchTerms: <String>['华夏', 'hxb'],
  ),
  AccountIconOption(
    code: 'asset:bank_013',
    label: '嘉兴银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_013.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_014',
    label: '四川天府银行南充市商业银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_014.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_015',
    label: '工商银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_015.svg',
    searchTerms: <String>['工商', '工行', 'icbc'],
  ),
  AccountIconOption(
    code: 'asset:bank_016',
    label: '平安银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_016.svg',
    searchTerms: <String>['平安', 'pab'],
  ),
  AccountIconOption(
    code: 'asset:bank_017',
    label: '广发银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_017.svg',
    searchTerms: <String>['广发', 'cgb'],
  ),
  AccountIconOption(
    code: 'asset:bank_018',
    label: '建设银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_018.svg',
    searchTerms: <String>['建设', '建行', 'ccb'],
  ),
  AccountIconOption(
    code: 'asset:bank_019',
    label: '张家口市商业银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_019.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_020',
    label: '张家港农村商业银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_020.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_021',
    label: '招商银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_021.svg',
    searchTerms: <String>['招商', '招行', 'cmb'],
  ),
  AccountIconOption(
    code: 'asset:bank_022',
    label: '江苏银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_022.svg',
    searchTerms: <String>['jsb'],
  ),
  AccountIconOption(
    code: 'asset:bank_023',
    label: '泰安银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_023.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_024',
    label: '浦发银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_024.svg',
    searchTerms: <String>['上海浦东发展银行', 'spdb'],
  ),
  AccountIconOption(
    code: 'asset:bank_025',
    label: '温州银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_025.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_026',
    label: '潍坊银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_026.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_027',
    label: '绍兴银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_027.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_028',
    label: '苏州银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_028.svg',
    searchTerms: <String>['bosz'],
  ),
  AccountIconOption(
    code: 'asset:bank_029',
    label: '营口银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_029.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_030',
    label: '邢台银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_030.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_031',
    label: '郑州银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_031.svg',
  ),
  AccountIconOption(
    code: 'asset:bank_032',
    label: '青岛银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_032.svg',
    searchTerms: <String>['qdccb'],
  ),
  AccountIconOption(
    code: 'asset:bank_033',
    label: '顺德农村商业银行',
    groupKey: 'bank',
    assetPath: 'assets/account_icons/bank_033.svg',
  ),
];

AccountIconOption? accountAssetIconByCode(String code) {
  for (final option in accountAssetIconOptions) {
    if (option.code == code) {
      return option;
    }
  }
  return null;
}

String? accountIconAssetPath(String code) {
  return genericAccountIconAssetPaths[code] ??
      accountAssetIconByCode(code)?.assetPath;
}

/// 历史账户图标只在数据边界做一次归一，渲染层不保留兼容分支。
String normalizeAccountIconCode(String? code) {
  final normalized = switch (code) {
    'alipay' => 'asset:payment_006',
    'wechat' => 'asset:payment_004',
    'folder' => 'wallet',
    final String value when value.isNotEmpty => value,
    _ => 'wallet',
  };
  return accountIconAssetPath(normalized) == null ? 'wallet' : normalized;
}

String normalizeAccountIconSearch(String value) {
  final buffer = StringBuffer();
  for (final rune in value.trim().toLowerCase().runes) {
    if (rune == 0x20 || rune == 0x3000 || (rune >= 0x09 && rune <= 0x0D)) {
      continue;
    }
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      buffer.writeCharCode(rune - 0xFEE0);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

bool accountAssetIconMatches(AccountIconOption option, String query) {
  final normalized = normalizeAccountIconSearch(query);
  if (normalized.isEmpty) {
    return true;
  }
  return <String>[
    option.label,
    option.code,
    ...option.searchTerms,
  ].any((term) => normalizeAccountIconSearch(term).contains(normalized));
}

String? suggestedAccountIconCode(String accountName) {
  final normalized = normalizeAccountIconSearch(accountName);
  if (normalized.isEmpty) {
    return null;
  }
  for (final option in accountAssetIconOptions) {
    final terms = <String>[option.label, ...option.searchTerms];
    if (terms.any(
      (term) => normalized.contains(normalizeAccountIconSearch(term)),
    )) {
      return option.code;
    }
  }
  return null;
}
