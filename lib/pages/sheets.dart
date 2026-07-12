import 'package:flutter/material.dart';

import '../app/account_icon_assets.dart';
import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
import '../app/entry_sheets.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/net_security.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';

/// 若 [url] 会以明文 http 把凭证发往公网主机，弹确认对话框让用户知情后再继续；
/// 非风险地址（https / 本机 / 内网）直接返回 true。用户取消返回 false。
Future<bool> confirmCleartextIfRisky(BuildContext context, String url) async {
  if (!isCleartextCredentialRisk(url)) return true;
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.cleartextWarnTitle),
      content: Text(l10n.cleartextWarnBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.cleartextWarnContinue),
        ),
      ],
    ),
  );
  return confirmed == true;
}

Future<T?> showOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> values,
  required T selected,
  required String Function(T value) labelOf,
  bool showSelectedMarker = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final value in values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: showSelectedMarker && value == selected
                                ? veriRoyal.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(veriRadiusSm),
                            child: ListTile(
                              minTileHeight: 44,
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  veriRadiusSm,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              title: Text(
                                labelOf(value),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight:
                                          showSelectedMarker &&
                                              value == selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                              ),
                              trailing: showSelectedMarker && value == selected
                                  ? const Icon(
                                      Icons.check,
                                      color: veriRoyal,
                                      size: 18,
                                    )
                                  : null,
                              onTap: () => Navigator.of(context).pop(value),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 数字键盘弹窗:统一的金额输入入口(四则算式 + 结果预览)。触感偏好由内部从
/// [VeriFinScope] 取,调用方不用手传。返回所输金额;取消返回 null。
/// [allowNegative] 允许负数,[allowZero] 允许 0(如清除预算 / 手续费)。
Future<double?> showNumberPadSheet(
  BuildContext context, {
  required String title,
  double? initialAmount,
  bool allowNegative = false,
  bool allowZero = false,
  double? maxAmount,
}) {
  final hapticsEnabled = VeriFinScope.of(context).hapticsEnabled;
  return showModalBottomSheet<double>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => NumberPadSheet(
      title: title,
      initialAmount: initialAmount,
      allowNegative: allowNegative,
      allowZero: allowZero,
      hapticsEnabled: hapticsEnabled,
      maxAmount: maxAmount,
    ),
  );
}

/// 多级分类选择弹窗:统一的分类选择入口(带图标、可折叠父子层级)。返回所选分类
/// id;取消返回 null。[allLabel] 非空时顶部加「全部」项(筛选用)→ 返回
/// [categoryPickerAll];[topLevelLabel] 非空时加「移到顶级」→ 返回
/// [categoryPickerTopLevel]。[categories] 由调用方按类型过滤后传入(筛选场景可传全部)。
Future<String?> showCategoryPickerSheet(
  BuildContext context, {
  required List<Category> categories,
  required String selectedId,
  String? title,
  String? topLevelLabel,
  String? allLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (_) => CategoryPickerSheet(
      categories: categories,
      selectedId: selectedId,
      title: title,
      topLevelLabel: topLevelLabel,
      allLabel: allLabel,
    ),
  );
}

/// 账户选择弹窗:与资产页账户列表一致,展示账户图标、名称(含卡号后四位)和余额。
/// 账户选择弹窗。返回所选账户；用户取消返回 null。
/// 传入 [noneLabel] 时，列表顶部额外提供「无账户」选项，选它返回 id 为空串的
/// 哨兵 [Account]（调用方用 `selected.id.isEmpty` 判别「只记金额、不计入账户」）。
Future<Account?> showAccountPickerSheet({
  required BuildContext context,
  required String title,
  required List<Account> accounts,
  required String? selectedId,
  required double Function(Account account) balanceOf,
  String? noneLabel,
  String? noneHint,
}) {
  return showModalBottomSheet<Account>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      if (noneLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _NoneAccountRow(
                            label: noneLabel,
                            hint: noneHint,
                            selected: (selectedId ?? '').isEmpty,
                          ),
                        ),
                      for (final account in accounts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _AccountPickerRow(
                            account: account,
                            balance: balanceOf(account),
                            selected: account.id == selectedId,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AccountPickerRow extends StatelessWidget {
  const _AccountPickerRow({
    required this.account,
    required this.balance,
    required this.selected,
  });

  final Account account;
  final double balance;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? veriRoyal.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: ListTile(
        minTileHeight: 48,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(veriRadiusSm),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: AccountIconBox(iconCode: account.iconCode, size: 32),
        title: Text.rich(
          TextSpan(
            text: account.name,
            children: <TextSpan>[
              if (account.cardLast4.isNotEmpty &&
                  account.type.supportsCardLast4)
                TextSpan(
                  text: ' (${account.cardLast4})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.42),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              formatAmount(balance),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: accountBalanceColor(context, account, balance),
                fontWeight: FontWeight.w800,
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: 6),
              const Icon(Icons.check, color: veriRoyal, size: 18),
            ],
          ],
        ),
        onTap: () => Navigator.of(context).pop(account),
      ),
    );
  }
}

/// 「无账户」选项：选它记一笔纯金额、不计入任何账户余额。返回 id 为空的哨兵账户。
class _NoneAccountRow extends StatelessWidget {
  const _NoneAccountRow({
    required this.label,
    required this.hint,
    required this.selected,
  });

  final String label;
  final String? hint;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? veriRoyal.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: ListTile(
        minTileHeight: 48,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(veriRadiusSm),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: VeriIconBox(
          icon: Icons.money_off_csred_outlined,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          size: 32,
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        subtitle: hint == null
            ? null
            : Text(
                hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
        trailing: selected
            ? const Icon(Icons.check, color: veriRoyal, size: 18)
            : null,
        onTap: () => Navigator.of(context).pop(
          const Account(
            id: '',
            bookId: '',
            name: '',
            type: AccountType.cash,
            groupId: null,
            initialBalance: 0,
            iconCode: 'wallet',
            note: '',
            includeInAssets: false,
            hidden: false,
          ),
        ),
      ),
    );
  }
}

/// 账户 / 账户分组图标选择器：每行带 [AccountIconBox] 预览。[includeAssetIcons] 为
/// false 时只列通用图标（账户分组用——分组图标以 `iconForCode` 渲染，不支持银行等
/// 资产图标），[title] 可覆盖标题（分组用「选择分组图标」）。
Future<String?> showAccountIconSheet({
  required BuildContext context,
  required String selected,
  String? title,
  bool includeAssetIcons = true,
}) {
  final l10n = AppLocalizations.of(context);
  final choices = <AccountIconChoice>[
    for (final code in accountIconCodes)
      AccountIconChoice(
        code: code,
        label: iconLabelForCode(l10n, code),
        group: l10n.iconGroupGeneric,
      ),
    if (includeAssetIcons) ...<AccountIconChoice>[
      for (final option in accountAssetIconOptions)
        AccountIconChoice(
          code: option.code,
          label: option.label,
          group: option.groupLabel(l10n),
        ),
    ],
  ];

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.sizeOf(context).height * 0.74;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title ?? l10n.accountIconPickerTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: choices.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      final choice = choices[index];
                      final isSelected = choice.code == selected;
                      return Material(
                        color: isSelected
                            ? veriRoyal.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(veriRadiusSm),
                        child: ListTile(
                          minTileHeight: 48,
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: AccountIconBox(
                            iconCode: choice.code,
                            size: 34,
                          ),
                          title: Text(
                            choice.label,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                          ),
                          subtitle: Text(choice.group),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: veriRoyal,
                                  size: 18,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(choice.code),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class AccountIconChoice {
  const AccountIconChoice({
    required this.code,
    required this.label,
    required this.group,
  });

  final String code;
  final String label;
  final String group;
}

/// 分类图标常用 emoji 快选（覆盖餐饮/出行/居家/娱乐/人情/理财等常见分类）。
const List<String> categoryEmojiChoices = <String>[
  '🍜',
  '🍔',
  '🍚',
  '🥗',
  '🍎',
  '☕',
  '🍺',
  '🍷',
  '🧋',
  '🍰',
  '🍦',
  '🛒',
  '🛍️',
  '👕',
  '👗',
  '👟',
  '💄',
  '✂️',
  '🚌',
  '🚗',
  '🚕',
  '⛽',
  '🚉',
  '✈️',
  '🅿️',
  '🚲',
  '🏠',
  '🔑',
  '💡',
  '💧',
  '📱',
  '📶',
  '🔧',
  '🛋️',
  '🧺',
  '🎮',
  '🎬',
  '🎵',
  '⚽',
  '🏋️',
  '📚',
  '🎓',
  '🐱',
  '🐶',
  '🍼',
  '🎁',
  '🧧',
  '❤️',
  '💊',
  '🏥',
  '💰',
  '💵',
  '💳',
  '🧾',
  '📈',
  '💼',
  '🎉',
  '⭐',
  '🔥',
  '🏦',
];

/// 分类图标选择器：内置图标网格 + 常用 emoji 快选 + 自由输入 emoji。
/// 返回选中的 iconCode（内置 code 或 `emoji:` 前缀的自定义 emoji）；取消返回 null。
Future<String?> showCategoryIconPickerSheet({
  required BuildContext context,
  required String selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (context) => _CategoryIconPickerBody(selected: selected),
  );
}

class _CategoryIconPickerBody extends StatefulWidget {
  const _CategoryIconPickerBody({required this.selected});

  final String selected;

  @override
  State<_CategoryIconPickerBody> createState() =>
      _CategoryIconPickerBodyState();
}

class _CategoryIconPickerBodyState extends State<_CategoryIconPickerBody> {
  final TextEditingController _emojiController = TextEditingController();

  @override
  void dispose() {
    _emojiController.dispose();
    super.dispose();
  }

  void _submitEmoji() {
    final text = _emojiController.text.trim();
    if (text.isEmpty) {
      return;
    }
    // 取首个字形簇，兼容多码位 emoji（如带肤色/ZWJ 的组合）。
    Navigator.of(context).pop(emojiIconCode(text.characters.first));
  }

  /// 自适应列数的图标网格：按可用宽度均匀铺满，避免右侧留白不均。
  Widget _iconGrid(List<Widget> cells) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 56,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: cells.length,
      itemBuilder: (context, index) => cells[index],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.pickIconTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _sectionTitle(l10n.iconSectionBuiltin),
                      _iconGrid(<Widget>[
                        for (final code in categoryIconCodes)
                          _IconChoiceCell(
                            selected: widget.selected == code,
                            onTap: () => Navigator.of(context).pop(code),
                            child: CategoryIconBox(iconCode: code, size: 36),
                          ),
                      ]),
                      _sectionTitle(l10n.iconSectionEmoji),
                      _iconGrid(<Widget>[
                        for (final emoji in categoryEmojiChoices)
                          _IconChoiceCell(
                            selected: widget.selected == emojiIconCode(emoji),
                            onTap: () =>
                                Navigator.of(context).pop(emojiIconCode(emoji)),
                            child: CategoryIconBox(
                              iconCode: emojiIconCode(emoji),
                              size: 36,
                            ),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _emojiController,
                              decoration: InputDecoration(
                                hintText: l10n.iconEmojiHint,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _submitEmoji(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _submitEmoji,
                            child: Text(l10n.iconEmojiUse),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 图标选择格子：统一尺寸 + 选中态描边。
class _IconChoiceCell extends StatelessWidget {
  const _IconChoiceCell({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(veriRadiusMd),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(veriRadiusMd),
          border: Border.all(
            color: selected
                ? veriRoyal
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.10),
            width: selected ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  required String label,
  String initialValue = '',
  bool allowEmpty = false,
  TextInputType? keyboardType,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(AppLocalizations.of(context).commonConfirm),
        ),
      ],
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  final trimmed = result?.trim();
  if (trimmed == null || (!allowEmpty && trimmed.isEmpty)) {
    return null;
  }
  return trimmed;
}

/// 编辑完整卡号 + 后四位（含「后四位跟随卡号」开关）。确认返回归一化后的两值与开关态，
/// 取消返回 null。开关态由调用方持久化（`Account.cardLast4Follows`），不再靠反推。
Future<({String number, String last4, bool follows})?> showCardNumberDialog({
  required BuildContext context,
  required String initialNumber,
  required String initialLast4,
  required bool initialFollows,
}) async {
  final numberController = TextEditingController(text: initialNumber);
  final last4Controller = TextEditingController(text: initialLast4);
  var follows = initialFollows;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(AppLocalizations.of(context).cardNumberTitle),
        content: SingleChildScrollView(
          child: CardNumberFields(
            numberController: numberController,
            last4Controller: last4Controller,
            follows: follows,
            onFollowsChanged: (value) => setState(() => follows = value),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).commonConfirm),
          ),
        ],
      ),
    ),
  );
  final number = numberController.text.trim();
  final last4 = cardLast4Of(last4Controller.text);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    numberController.dispose();
    last4Controller.dispose();
  });
  if (confirmed != true) {
    return null;
  }
  return (number: number, last4: last4, follows: follows);
}

Future<void> confirmDeleteAccount(
  BuildContext context,
  Account account,
  List<LedgerEntry> entries,
) async {
  final controller = VeriFinScope.of(context);
  final l10n = AppLocalizations.of(context);
  // 弹层随后会 pop，提前抓住 messenger（它位于被 pop 路由之上，pop 后仍有效），
  // 用于删账户后提示被停用的周期规则。
  final messenger = ScaffoldMessenger.of(context);
  void notifyDisabledRules(int affected) {
    if (affected > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.accountRecurringRulesDisabled(affected))),
      );
    }
  }

  if (entries.isNotEmpty) {
    final action = await showDialog<AccountDeleteAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountHandleTitle),
        content: Text(l10n.accountHandleMessage(account.name, entries.length)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(AccountDeleteAction.hide),
            child: Text(l10n.accountHide),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(AccountDeleteAction.delete),
            style: FilledButton.styleFrom(backgroundColor: veriExpense),
            child: Text(l10n.accountDeleteWithEntries),
          ),
        ],
      ),
    );
    if (!context.mounted || action == null) {
      return;
    }
    if (action == AccountDeleteAction.hide) {
      controller.updateAccount(account.copyWith(hidden: true));
      Navigator.of(context).pop();
      return;
    }
    final affected = controller.deleteAccountAndRelatedEntries(account.id);
    Navigator.of(context).pop();
    notifyDisabledRules(affected);
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.accountDeleteTitle),
      content: Text(l10n.accountDeleteMessage(account.name)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  if (!context.mounted || confirmed != true) {
    return;
  }
  final affected = controller.deleteAccount(account.id);
  Navigator.of(context).pop();
  notifyDisabledRules(affected);
}

enum AccountDeleteAction { hide, delete }

/// 打开标签多选弹窗，返回用户选定的标签 id 列表（取消返回 null）。
/// 新建标签直接写入 controller（标签全局共享，即时生效）。
Future<List<String>?> pickEntryTags({
  required BuildContext context,
  required List<String> selectedIds,
  List<Tag> extraTags = const <Tag>[],
}) {
  final controller = VeriFinScope.of(context);
  // 合并 controller 已落库标签与临时标签（导入草稿待新建、尚未落库），临时标签
  // 排在后面、去重按 id，保证草稿里既能看到又能勾选它们。
  final existingIds = controller.tags.map((tag) => tag.id).toSet();
  final tags = <Tag>[
    ...controller.tags,
    ...extraTags.where((tag) => !existingIds.contains(tag.id)),
  ];
  return showModalBottomSheet<List<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(veriRadiusLg)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
        ),
        child: TagSelectorSheet(
          tags: tags,
          selectedIds: selectedIds,
          onCreateTag: () async {
            final l10n = AppLocalizations.of(sheetContext);
            final label = await showTextInputDialog(
              context: sheetContext,
              title: l10n.tagCreateTitle,
              label: l10n.tagNameLabel,
            );
            if (label == null) {
              return null;
            }
            final id = controller.addTag(label);
            return id == null ? null : controller.tagById(id);
          },
        ),
      ),
    ),
  );
}
