import 'package:flutter/material.dart';

import '../app/account_icon_assets.dart';
import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/demo_data.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';

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

Future<String?> showAccountIconSheet({
  required BuildContext context,
  required String selected,
}) {
  final choices = <AccountIconChoice>[
    for (final code in accountIconCodes)
      AccountIconChoice(
        code: code,
        label: iconLabelForCode(code),
        group: '通用图标',
      ),
    for (final option in accountAssetIconOptions)
      AccountIconChoice(
        code: option.code,
        label: option.label,
        group: option.group,
      ),
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
                  '选择账户图标',
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('确认'),
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

Future<void> confirmDeleteAccount(
  BuildContext context,
  Account account,
  List<LedgerEntry> entries,
) async {
  final controller = VeriFinScope.of(context);
  if (entries.isNotEmpty) {
    final action = await showDialog<AccountDeleteAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('处理此账户？'),
        content: Text(
          '账户「${account.name}」已有 ${entries.length} 笔相关交易。你可以隐藏账户，或删除账户并同步删除这些交易记录。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(AccountDeleteAction.hide),
            child: const Text('隐藏账户'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(AccountDeleteAction.delete),
            style: FilledButton.styleFrom(backgroundColor: veriExpense),
            child: const Text('删除账户和交易'),
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
    controller.deleteAccountAndRelatedEntries(account.id);
    Navigator.of(context).pop();
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除此账户？'),
      content: Text('账户「${account.name}」删除后无法恢复。'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (!context.mounted || confirmed != true) {
    return;
  }
  controller.deleteAccount(account.id);
  Navigator.of(context).pop();
}

enum AccountDeleteAction { hide, delete }
