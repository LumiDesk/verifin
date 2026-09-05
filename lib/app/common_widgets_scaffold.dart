part of 'common_widgets.dart';

// 页面骨架域：VeriPage/VeriCard/VeriHeader 与头部动作、区块标题、空态。

class VeriPage extends StatelessWidget {
  const VeriPage({
    super.key,
    required this.child,
    this.compact = veriUnifiedDesignPreview,
  });

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: veriUnifiedDesignPreview ? (compact ? 2 : 6) : 0,
      ),
      decoration: BoxDecoration(
        color: veriUnifiedDesignPreview
            ? Theme.of(context).scaffoldBackgroundColor
            : null,
        gradient: veriUnifiedDesignPreview
            ? null
            : LinearGradient(
                colors: Theme.of(context).brightness == Brightness.dark
                    ? const <Color>[Color(0xFF0B0F15), Color(0xFF111722)]
                    : const <Color>[Color(0xFFF5F8FC), Color(0xFFEFF4FB)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: veriPageMaxWidth),
          child: veriGlassDesignPreview ? BackdropGroup(child: child) : child,
        ),
      ),
    );
  }
}

class VeriCard extends StatelessWidget {
  const VeriCard({
    super.key,
    required this.child,
    this.onTap,
    this.quietTap = false,
    this.compact = veriUnifiedDesignPreview,
    EdgeInsetsGeometry? padding,
  }) : padding =
           padding ??
           (compact
               ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
               : const EdgeInsets.all(veriUnifiedDesignPreview ? 18 : 13));

  final Widget child;
  final VoidCallback? onTap;
  final bool quietTap;
  final bool compact;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (veriGlassDesignPreview) {
      return VeriGlassSurface(
        radius: compact ? veriCompactCardRadius : veriCardRadius,
        child: onTap != null && quietTap
            ? Semantics(
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  onLongPress: () {},
                  child: Padding(padding: padding, child: child),
                ),
              )
            : Material(
                color: Colors.transparent,
                child: onTap == null
                    ? Padding(padding: padding, child: child)
                    : InkWell(
                        onTap: onTap,
                        child: Padding(padding: padding, child: child),
                      ),
              ),
      );
    }
    final borderRadius = BorderRadius.circular(
      compact ? veriCompactCardRadius : veriCardRadius,
    );
    final decoration = BoxDecoration(
      color: veriContentSurfaceColor(Theme.of(context).brightness),
      borderRadius: borderRadius,
      border: Border.all(
        color: veriUnifiedDesignPreview
            ? (isDark ? Colors.white : veriInk).withValues(alpha: 0.045)
            : isDark
            ? Colors.white.withValues(alpha: 0.10)
            : veriLine,
      ),
      boxShadow: <BoxShadow>[
        if (!isDark && !veriUnifiedDesignPreview)
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.045),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
      ],
    );

    if (onTap != null && quietTap) {
      return Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: () {},
          child: Container(
            padding: padding,
            decoration: decoration,
            child: child,
          ),
        ),
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
    }

    return Container(padding: padding, decoration: decoration, child: child);
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.compact = veriUnifiedDesignPreview,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return VeriHeader(
      compact: compact,
      title: title,
      subtitle: subtitle,
      actions: trailing == null ? null : [trailing!],
    );
  }
}

class VeriHeader extends StatelessWidget {
  const VeriHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.actions,
    this.compact = veriUnifiedDesignPreview,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final actionWidgets = actions ?? const <Widget>[];
    return SizedBox(
      height: compact ? veriCompactHeaderHeight : veriHeaderHeight,
      child: Row(
        children: <Widget>[
          if (showBack) ...<Widget>[
            IconButton(
              tooltip: AppLocalizations.of(context).commonBack,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 2),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: veriUnifiedDesignPreview
                        ? FontWeight.w700
                        : FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: veriUnifiedDesignPreview ? 0.62 : 0.48,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionWidgets.isNotEmpty) ...<Widget>[
            const SizedBox(width: 8),
            ...actionWidgets,
          ],
        ],
      ),
    );
  }
}

class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final baseColor = destructive
        ? veriExpense
        : Theme.of(context).colorScheme.onSurface;
    final color = baseColor.withValues(alpha: onPressed == null ? 0.32 : 0.82);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color),
    );
  }
}

/// 全屏编辑页统一的保存动作。
///
/// 固定使用软碟语义图标，避免各页面把“保存”混用成对勾或“完成”。
class SaveHeaderAction extends StatelessWidget {
  const SaveHeaderAction({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return HeaderAction(
      icon: Icons.save_outlined,
      tooltip: AppLocalizations.of(context).commonSave,
      onPressed: onPressed,
    );
  }
}

/// Shared header actions for explicit list-sorting sessions.
///
/// Normal mode exposes a sort entry point. Sorting mode replaces it with
/// cancel and the standard floppy save action so a drag never implies
/// persistence by itself.
class SortModeHeaderActions extends StatelessWidget {
  const SortModeHeaderActions({
    super.key,
    required this.sorting,
    required this.canSort,
    required this.dirty,
    required this.onStart,
    required this.onCancel,
    required this.onSave,
  });

  final bool sorting;
  final bool canSort;
  final bool dirty;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    if (!sorting) {
      return HeaderAction(
        icon: Icons.swap_vert,
        tooltip: AppLocalizations.of(context).sortLabel,
        onPressed: canSort ? onStart : null,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HeaderAction(
          icon: Icons.close,
          tooltip: AppLocalizations.of(context).commonCancel,
          onPressed: onCancel,
        ),
        SaveHeaderAction(onPressed: dirty ? onSave : null),
      ],
    );
  }
}

class HeaderTextAction extends StatelessWidget {
  const HeaderTextAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}

class HeaderInline extends StatelessWidget {
  const HeaderInline({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: veriRoyal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(veriRadiusMd),
                  border: Border.all(color: veriRoyal.withValues(alpha: 0.10)),
                ),
                child: Icon(icon, size: 24, color: veriRoyal),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
