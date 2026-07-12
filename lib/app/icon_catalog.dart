/// 图标目录：内置图标 code → IconData/本地化名称的映射，与 emoji 自定义图标
/// 的 code 封装。渲染分类图标请走 common_widgets 的 CategoryIconBox/
/// CategoryGlyph（自动区分内置与 emoji），勿直接调 [iconForCode]。
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import 'account_icon_assets.dart';

const List<String> accountIconCodes = <String>[
  'wallet',
  'alipay',
  'credit',
  'bank',
  'cash',
  'investment',
  'savings',
  'card',
  'folder',
];

const List<String> categoryIconCodes = <String>[
  'category',
  'dining',
  'coffee',
  'drink',
  'snack',
  'cake',
  'grocery',
  'shopping',
  'clothing',
  'beauty',
  'haircut',
  'transport',
  'car',
  'taxi',
  'fuel',
  'parking',
  'train',
  'flight',
  'bike',
  'housing',
  'rent',
  'utilities',
  'water',
  'phone',
  'internet',
  'repair',
  'furniture',
  'laundry',
  'entertainment',
  'game',
  'music',
  'sports',
  'book',
  'education',
  'travel',
  'hotel',
  'medical',
  'medicine',
  'pet',
  'baby',
  'family',
  'love',
  'gift',
  'redpacket',
  'charity',
  'electronics',
  'subscription',
  'work',
  'salary',
  'bonus',
  'savings',
  'interest',
  'investment',
  'insurance',
  'tax',
  'refund',
  'repayment',
  'transfer_out',
  'transfer_in',
  'star',
  'adjust',
];

/// emoji 分类图标的存储前缀：`emoji:🍜`。以此与内置图标 code 区分。
const String emojiIconPrefix = 'emoji:';

/// 该图标 code 是否为 emoji 自定义图标。
bool isEmojiIconCode(String code) => code.startsWith(emojiIconPrefix);

/// 取出 emoji 图标的字符（非 emoji code 原样返回）。
String emojiOfIconCode(String code) =>
    isEmojiIconCode(code) ? code.substring(emojiIconPrefix.length) : code;

/// 把一个 emoji 字符封装为可存储的图标 code。
String emojiIconCode(String emoji) => '$emojiIconPrefix$emoji';

IconData iconForCode(String code) {
  switch (code) {
    case 'category':
      return Icons.category_outlined;
    case 'dining':
      return Icons.restaurant;
    case 'transport':
      return Icons.directions_bus;
    case 'shopping':
      return Icons.shopping_bag;
    case 'housing':
      return Icons.home_work;
    case 'entertainment':
      return Icons.movie;
    case 'medical':
      return Icons.local_hospital;
    case 'salary':
      return Icons.payments;
    case 'interest':
      return Icons.percent;
    case 'bonus':
      return Icons.military_tech;
    case 'work':
      return Icons.work;
    case 'transfer_out':
      return Icons.call_made;
    case 'transfer_in':
      return Icons.call_received;
    case 'repayment':
      return Icons.swap_horiz;
    case 'adjust':
      return Icons.tune;
    // ---- 扩充分类图标（与 categoryIconCodes 对应）----
    case 'coffee':
      return Icons.local_cafe;
    case 'grocery':
      return Icons.local_grocery_store;
    case 'snack':
      return Icons.icecream;
    case 'drink':
      return Icons.local_bar;
    case 'cake':
      return Icons.cake;
    case 'car':
      return Icons.directions_car;
    case 'taxi':
      return Icons.local_taxi;
    case 'fuel':
      return Icons.local_gas_station;
    case 'train':
      return Icons.train;
    case 'flight':
      return Icons.flight;
    case 'parking':
      return Icons.local_parking;
    case 'bike':
      return Icons.pedal_bike;
    case 'rent':
      return Icons.vpn_key;
    case 'utilities':
      return Icons.bolt;
    case 'water':
      return Icons.water_drop;
    case 'phone':
      return Icons.smartphone;
    case 'internet':
      return Icons.wifi;
    case 'repair':
      return Icons.build;
    case 'furniture':
      return Icons.chair;
    case 'laundry':
      return Icons.local_laundry_service;
    case 'clothing':
      return Icons.checkroom;
    case 'beauty':
      return Icons.spa;
    case 'haircut':
      return Icons.content_cut;
    case 'sports':
      return Icons.fitness_center;
    case 'game':
      return Icons.sports_esports;
    case 'music':
      return Icons.music_note;
    case 'book':
      return Icons.menu_book;
    case 'education':
      return Icons.school;
    case 'travel':
      return Icons.luggage;
    case 'hotel':
      return Icons.hotel;
    case 'pet':
      return Icons.pets;
    case 'baby':
      return Icons.child_friendly;
    case 'gift':
      return Icons.card_giftcard;
    case 'redpacket':
      return Icons.redeem;
    case 'medicine':
      return Icons.medication;
    case 'electronics':
      return Icons.devices;
    case 'subscription':
      return Icons.subscriptions;
    case 'tax':
      return Icons.receipt_long;
    case 'insurance':
      return Icons.verified_user;
    case 'charity':
      return Icons.volunteer_activism;
    case 'refund':
      return Icons.replay;
    case 'love':
      return Icons.favorite;
    case 'family':
      return Icons.family_restroom;
    case 'star':
      return Icons.star;
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

String iconLabelForCode(AppLocalizations l10n, String code) {
  final assetIcon = accountAssetIconByCode(code);
  if (assetIcon != null) {
    // 品牌/银行图标名是专有名词，不随语言切换。
    return assetIcon.label;
  }

  switch (code) {
    case 'category':
      return l10n.iconLabelCategory;
    case 'dining':
      return l10n.iconLabelDining;
    case 'transport':
      return l10n.iconLabelTransport;
    case 'shopping':
      return l10n.iconLabelShopping;
    case 'housing':
      return l10n.iconLabelHousing;
    case 'entertainment':
      return l10n.iconLabelEntertainment;
    case 'medical':
      return l10n.iconLabelMedical;
    case 'salary':
      return l10n.iconLabelSalary;
    case 'interest':
      return l10n.iconLabelInterest;
    case 'bonus':
      return l10n.iconLabelBonus;
    case 'work':
      return l10n.iconLabelWork;
    case 'transfer_out':
      return l10n.iconLabelTransferOut;
    case 'transfer_in':
      return l10n.iconLabelTransferIn;
    case 'repayment':
      return l10n.iconLabelRepayment;
    case 'adjust':
      return l10n.iconLabelAdjust;
    case 'alipay':
      return l10n.iconLabelPay;
    case 'wechat':
      return l10n.iconLabelWechat;
    case 'credit':
      return l10n.iconLabelCredit;
    case 'bank':
      return l10n.iconLabelBank;
    case 'cash':
      return l10n.iconLabelCash;
    case 'investment':
      return l10n.iconLabelInvestment;
    case 'savings':
      return l10n.iconLabelSavings;
    case 'card':
      return l10n.iconLabelCard;
    case 'folder':
      return l10n.iconLabelFolder;
    case 'wallet':
    default:
      return l10n.iconLabelWallet;
  }
}
