part of 'common_widgets.dart';

// 表单域：设置行、选择字段、紧凑开关行、交易标签选择、卡号输入组。

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
    this.trailingIcon,
    this.contentColor,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final VoidCallback? onTap;
  final IconData? trailingIcon;
  final Color? contentColor;

  @override
  Widget build(BuildContext context) {
    final iconColor = contentColor ?? veriRoyal;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          VeriIconBox(icon: icon, size: 28, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: contentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trailing,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    contentColor ??
                    Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ),
          if (trailingIcon != null) ...<Widget>[
            const SizedBox(width: 4),
            Icon(
              trailingIcon,
              size: 18,
              color:
                  contentColor ??
                  Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.42),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.leading,
    required this.onTap,
  }) : assert(icon != null || leading != null, '需要提供 icon 或 leading');

  final String label;
  final String value;
  final IconData? icon;

  /// 自定义前置组件(如账户图标);提供时优先于 [icon]。
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusMd),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: leading == null
                ? Icon(icon)
                : Center(widthFactor: 1, heightFactor: 1, child: leading),
            suffixIcon: const Icon(Icons.keyboard_arrow_down),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class CompactSwitchRow extends StatelessWidget {
  const CompactSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          VeriIconBox(icon: icon, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DefaultTextStyle.merge(
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  child: title,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.82,
            alignment: Alignment.centerRight,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// 在执行耗时任务期间显示不可关闭的加载对话框,任务结束后自动关闭并返回结果。
/// 用于图片裁剪等短时重计算,避免用户以为程序卡死。
Future<T> runWithLoadingDialog<T>({
  required BuildContext context,
  required Future<T> Function() task,
  String? message,
}) async {
  final resolvedMessage =
      message ?? AppLocalizations.of(context).commonProcessing;
  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogOpen = true;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: <Widget>[
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(resolvedMessage)),
            ],
          ),
        ),
      ),
    ).whenComplete(() => dialogOpen = false),
  );
  try {
    return await task();
  } finally {
    if (dialogOpen && navigator.mounted) {
      navigator.pop();
    }
  }
}

/// 记账表单里的「标签」行：展示已选标签 chip（空时提示点击添加），整行可点击打开多选。
class EntryTagField extends StatelessWidget {
  const EntryTagField({
    super.key,
    required this.tagIds,
    required this.tagLabelOf,
    required this.onTap,
  });

  final List<String> tagIds;

  /// 由 id 取标签名；返回 null 表示标签已被删除，忽略展示。
  final String? Function(String id) tagLabelOf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      for (final id in tagIds)
        if (tagLabelOf(id) case final String label) label,
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.label_outline,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: labels.isEmpty
                    ? Text(
                        AppLocalizations.of(context).entryAddTags,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final label in labels)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: veriRoyal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                label,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: veriRoyal,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                        ],
                      ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 统一的确认对话框：取消 + 确认两个按钮，返回用户是否确认（取消 / 点外部关闭
/// 均返回 false）。[destructive] 为 true 时确认按钮用红色（删除 / 清空 / 重置等
/// 破坏性操作），使全应用的危险操作视觉一致。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel ?? l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: veriExpense)
              : null,
          child: Text(confirmLabel ?? l10n.commonConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// 「完整卡号 + 后四位」输入组，含「后四位跟随完整卡号」开关（仅信用卡/储蓄卡使用）。
/// 开关打开时后四位只读、自动取完整卡号末四位；关闭后可手填、独立于完整卡号。
/// **受控组件**：开关状态由调用方以 [follows] 传入、经 [onFollowsChanged] 回传持久化
/// （见 `Account.cardLast4Follows`），组件不自行反推。调用方读两控制器取值，后四位建议以
/// [cardLast4Of] 归一化后落库。
class CardNumberFields extends StatefulWidget {
  const CardNumberFields({
    super.key,
    required this.numberController,
    required this.last4Controller,
    required this.follows,
    required this.onFollowsChanged,
  });

  final TextEditingController numberController;
  final TextEditingController last4Controller;
  final bool follows;
  final ValueChanged<bool> onFollowsChanged;

  @override
  State<CardNumberFields> createState() => _CardNumberFieldsState();
}

class _CardNumberFieldsState extends State<CardNumberFields> {
  @override
  void initState() {
    super.initState();
    widget.numberController.addListener(_onNumberChanged);
  }

  @override
  void dispose() {
    widget.numberController.removeListener(_onNumberChanged);
    super.dispose();
  }

  void _onNumberChanged() {
    if (!widget.follows) {
      return;
    }
    final derived = cardLast4Of(widget.numberController.text);
    if (widget.last4Controller.text != derived) {
      widget.last4Controller.text = derived;
    }
  }

  void _toggleFollows(bool value) {
    widget.onFollowsChanged(value);
    if (value) {
      widget.last4Controller.text = cardLast4Of(widget.numberController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextFormField(
          controller: widget.numberController,
          keyboardType: TextInputType.number,
          maxLength: 32,
          decoration: InputDecoration(
            labelText: l10n.cardNumberLabel,
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: widget.last4Controller,
                enabled: !widget.follows,
                maxLength: 4,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.cardLast4Label,
                  counterText: '',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return null;
                  }
                  if (!RegExp(r'^\d{1,4}$').hasMatch(text)) {
                    return l10n.cardLast4Invalid;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.cardLast4Follow,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Switch(value: widget.follows, onChanged: _toggleFollows),
          ],
        ),
      ],
    );
  }
}
