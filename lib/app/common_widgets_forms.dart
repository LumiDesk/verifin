part of 'common_widgets.dart';

// 表单域：设置行、选择字段、紧凑开关行、交易标签选择、卡号输入组。

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    required this.trailing,
    this.onTap,
    this.trailingIcon,
    this.contentColor,
  }) : assert(icon != null || leading != null, '需要提供 icon 或 leading');

  final IconData? icon;
  final Widget? leading;
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
          leading ?? VeriIconBox(icon: icon!, size: 28, color: iconColor),
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
    this.suffixIcon,
    required this.onTap,
  }) : assert(icon != null || leading != null, '需要提供 icon 或 leading');

  final String label;
  final String value;
  final IconData? icon;

  /// 自定义前置组件(如账户图标);提供时优先于 [icon]。
  final Widget? leading;

  /// 自定义尾部操作；未提供时显示默认下拉箭头。
  final Widget? suffixIcon;
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
            suffixIcon: suffixIcon ?? const Icon(Icons.keyboard_arrow_down),
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

/// 统一的只读说明对话框：正文 + 单个“知道了”按钮。
Future<void> showInfoDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? closeLabel,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(closeLabel ?? l10n.gotIt),
        ),
      ],
    ),
  );
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

  /// null 表示当前平台/状态不可用，同时保留 Switch 的禁用语义。
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 整行可点：开关被缩到 0.82 后有效点击区不足 44dp，只点开关很难命中。
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: Padding(
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
              ? FilledButton.styleFrom(
                  backgroundColor: veriSemantic(context, veriExpense),
                )
              : null,
          child: Text(confirmLabel ?? l10n.commonConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// 编辑页存在未保存修改时，用户对退出请求作出的决定。
enum EditorExitDecision { save, discard, cancel }

/// Lets an editor's explicit save action request the same guarded exit path
/// used by back navigation, without relying on a rebuild to clear dirty first.
class EditorExitController {
  void Function(Object? Function()? resultBuilder)? _exit;

  void exit({Object? Function()? result}) {
    _exit?.call(result);
  }
}

/// 统一的未保存修改对话框。
///
/// 点击遮罩或系统返回等价于 [EditorExitDecision.cancel]，不会隐式丢弃草稿。
Future<EditorExitDecision> showUnsavedChangesDialog({
  required BuildContext context,
}) async {
  final l10n = AppLocalizations.of(context);
  final decision = await showDialog<EditorExitDecision>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.unsavedChangesTitle),
      content: Text(l10n.unsavedChangesMessage),
      actions: <Widget>[
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(EditorExitDecision.cancel),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(EditorExitDecision.discard),
          style: TextButton.styleFrom(
            foregroundColor: veriSemantic(context, veriExpense),
          ),
          child: Text(l10n.discardChanges),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(EditorExitDecision.save),
          child: Text(l10n.commonSave),
        ),
      ],
    ),
  );
  return decision ?? EditorExitDecision.cancel;
}

/// 统一拦截编辑页的 Header 返回、Android 返回与预测性返回。
///
/// [onSave] 仅在实际写入成功时返回 true；校验或持久化失败返回 false，页面会保留
/// 草稿并继续停留。无修改时不拦截。调用方不得在 [onSave] 内自行 pop。
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.isDirty,
    required this.onSave,
    required this.child,
    this.onDiscard,
    this.popResult,
    this.exitController,
  });

  final bool isDirty;
  final Future<bool> Function() onSave;
  final VoidCallback? onDiscard;
  final Object? Function()? popResult;
  final EditorExitController? exitController;
  final Widget child;

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _handlingPop = false;
  bool _allowNextPop = false;

  @override
  void initState() {
    super.initState();
    widget.exitController?._exit = _exitPage;
  }

  @override
  void didUpdateWidget(UnsavedChangesGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exitController != widget.exitController) {
      if (oldWidget.exitController?._exit == _exitPage) {
        oldWidget.exitController?._exit = null;
      }
      widget.exitController?._exit = _exitPage;
    }
  }

  @override
  void dispose() {
    if (widget.exitController?._exit == _exitPage) {
      widget.exitController?._exit = null;
    }
    super.dispose();
  }

  Future<void> _handleBlockedPop() async {
    if (_handlingPop) {
      return;
    }
    setState(() => _handlingPop = true);
    try {
      final decision = await showUnsavedChangesDialog(context: context);
      if (!mounted) {
        return;
      }
      switch (decision) {
        case EditorExitDecision.save:
          if (await widget.onSave() && mounted) {
            _exitPage(null);
          }
          break;
        case EditorExitDecision.discard:
          widget.onDiscard?.call();
          _exitPage(null);
          break;
        case EditorExitDecision.cancel:
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _handlingPop = false);
      }
    }
  }

  void _exitPage(Object? Function()? resultBuilder) {
    final navigator = Navigator.of(context);
    final result = (resultBuilder ?? widget.popResult)?.call();
    setState(() => _allowNextPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        navigator.maybePop(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !widget.isDirty || _allowNextPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_handleBlockedPop());
        }
      },
      child: widget.child,
    );
  }
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

/// 统一分段控件：中文/文字标签浮在一条中性轨道上，选中项由滑动的胶囊指示。
///
/// 取代此前散落各页的手写分段条（记账页类型切换、账户详情日/月、统计口径、
/// 时间范围、分类/周期/分组的口径切换）。这些实现原先至少有 6 种不同的轨道色、
/// 圆角和选中样式，导致同类控件在不同页面观感不一致。
///
/// - 颜色全部取自设计令牌（[veriSurfaceAltDark] / [veriSurfaceLight] / 卡片表面色），
///   调用方只能通过 [accentOf] 指定**语义强调色**（如支出红、收入青），不能自定义底板。
/// - 自带 `Semantics`：整组标注为选中项，单个选项标注为按钮，补足第三方控件缺失的语义。
/// - 标签用文字，不用图标；图标型开关仍走 [CompactSwitchRow]。
class VeriSegmentedControl<T> extends StatelessWidget {
  const VeriSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.accentOf,
    this.compact = false,
    this.semanticLabel,
    this.keyOf,
  });

  /// 选项顺序即展示顺序。
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;

  /// 为 null 时整组禁用（如管理页排序期间不接受切换口径）。
  final ValueChanged<T>? onChanged;

  /// 选中项的文字强调色；返回 null 时用常规文字色。仅影响文字，不改底板。
  final Color? Function(T value)? accentOf;

  /// 紧凑档：用于卡片标题行内的小切换（如账户详情的日/月）。
  final bool compact;

  /// 整组控件的无障碍标签（如「统计口径」）。
  final String? semanticLabel;

  /// 为每个选项生成 Key；返回 null 表示该项不挂 Key。
  /// 仅用于保持既有调用点的 Key 契约（如记账页 `entry_type_selected_*`）。
  final Key? Function(T value)? keyOf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = isDark ? veriSurfaceAltDark : veriSurfaceLight;
    // 选中胶囊用卡片表面色：在深色下比轨道亮、浅色下比轨道白，形成明确的“浮起”层次。
    final indicator = veriContentSurfaceColor(Theme.of(context).brightness);
    final height = compact ? 30.0 : 40.0;
    final radius = BorderRadius.circular(compact ? veriRadiusSm : veriRadiusMd);

    return Semantics(
      label: semanticLabel,
      value: labelOf(selected),
      container: true,
      child: AnimatedToggleSwitch<T>.rolling(
        current: selected,
        values: values,
        onChanged: onChanged,
        // onChanged 为 null 时整组禁用（如管理页排序期间）。
        active: onChanged != null,
        height: height,
        borderWidth: 0,
        spacing: 2,
        padding: const EdgeInsets.all(2),
        indicatorSize: Size.fromWidth(compact ? 58 : 92),
        animationDuration: const Duration(milliseconds: 260),
        animationCurve: Curves.easeOutCubic,
        iconOpacity: 1,
        style: ToggleStyle(
          backgroundColor: track,
          indicatorColor: indicator,
          borderRadius: radius,
          indicatorBorderRadius: BorderRadius.circular(
            (compact ? veriRadiusSm : veriRadiusMd) - 2,
          ),
          borderColor: Colors.transparent,
          indicatorBorder: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: const <BoxShadow>[],
          indicatorBoxShadow: const <BoxShadow>[],
        ),
        iconBuilder: (value, foreground) {
          final selectedNow = value == selected;
          final enabled = onChanged != null;
          final accent = accentOf?.call(value);
          final color = selectedNow
              ? (accent ?? scheme.onSurface.withValues(alpha: 0.94))
              : scheme.onSurface.withValues(alpha: foreground ? 0.94 : 0.48);
          return Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Text(
              labelOf(value),
              // rolling 会把选中项额外渲染一份用于滑动动画；Key 只挂前景副本，
              // 否则同一 Key 在一帧里出现两次（调用点的 findsOneWidget 会失败）。
              key: foreground ? keyOf?.call(value) : null,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style:
                  (compact
                          ? Theme.of(context).textTheme.labelSmall
                          : Theme.of(context).textTheme.labelLarge)
                      ?.copyWith(
                        color: color,
                        fontWeight: selectedNow
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
            ),
          );
        },
      ),
    );
  }
}
