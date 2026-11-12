part of 'common_widgets.dart';

// 页面骨架域：VeriPage/VeriCard/VeriHeader 与头部动作、区块标题、空态。

/// 「缺汇率」提示：说明有多少账户缺率、缺哪些币种，点按可去维护汇率。
///
/// 外层容器由调用方决定，两种情况都只写这一份实现：
/// - 裸用（看板资产汇总卡的缺率态）传 [onTap]，组件自带点击区与 8dp 纵向内边距；
/// - 已经放在可点卡片里（资产页缺率卡）不要传 [onTap]，避免嵌套点击区。
class AssetMissingRateNotice extends StatelessWidget {
  const AssetMissingRateNotice({
    super.key,
    required this.affectedAccountCount,
    required this.currencyCodes,
    this.onTap,
  });

  /// 受影响（缺率）的账户数量。
  final int affectedAccountCount;

  /// 缺失汇率的币种代码，展示时按字典序拼接。
  final Set<String> currencyCodes;

  /// 非 null 时整块可点（一般跳 [CurrencyRatesPage]）。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final codes = (currencyCodes.toList()..sort()).join(', ');
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.currency_exchange,
          color: veriSemantic(context, veriWarning),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.assetValuationMissing(affectedAccountCount),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.assetValuationMissingDesc(codes),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(veriRadiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: content,
      ),
    );
  }
}

class VeriPage extends StatelessWidget {
  const VeriPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 页面容器补 2dp：加上页面自己的 14dp 横向内边距，有效页边距即 16dp。
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: veriPageMaxWidth),
          child: child,
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
    EdgeInsetsGeometry? padding,
  }) : padding =
           padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12);

  final Widget child;
  final VoidCallback? onTap;
  final bool quietTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(veriCardRadius);
    final decoration = BoxDecoration(
      color: veriContentSurfaceColor(Theme.of(context).brightness),
      borderRadius: borderRadius,
      border: Border.all(
        color: (isDark ? Colors.white : veriInk).withValues(alpha: 0.045),
      ),
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
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return VeriHeader(
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
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final actionWidgets = actions ?? const <Widget>[];
    // 最小高度而非固定高度：系统字号放大时标题/副标题两行不能被裁掉。
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: veriHeaderHeight),
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
                    fontWeight: FontWeight.w800,
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.62),
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
        ? veriSemantic(context, veriExpense)
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
  const SectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.trailingWidget,
    this.titleSuffix,
  });

  final String title;
  final String? trailing;

  /// 右侧槽位放自定义控件（如紧凑分段控件）时使用，优先于 [trailing]。
  final Widget? trailingWidget;

  /// 紧跟标题文字之后的小控件（如切换口径的小图标按钮）。
  final Widget? titleSuffix;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
    if (trailing == null && trailingWidget == null && titleSuffix == null) {
      return titleText;
    }
    // 标题自然宽度靠左，trailing 占满剩余槽位后内部右对齐，贴到内容区右端。
    //
    // 两个细节缺一不可：
    // 1) mainAxisSize.max + 外层 SizedBox(width: infinity)——调用方的 Column 多是
    //    CrossAxisAlignment.start，Row 会被松约束，只收缩到子项自然宽度；那样
    //    spaceBetween 也无处可推，trailing 会停在卡片中间（看板各面板曾如此）。
    // 2) trailing 必须是 Flexible(fit: tight)——只给「最大宽度」的话 Text 会缩回
    //    自然宽度，textAlign: end 就在自己的窄盒子里生效，同样到不了右端。
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          if (titleSuffix == null)
            Flexible(child: titleText)
          else
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(child: titleText),
                  const SizedBox(width: 2),
                  titleSuffix!,
                ],
              ),
            ),
          const SizedBox(width: 10),
          Flexible(
            fit: FlexFit.tight,
            child: trailingWidget != null
                ? Align(alignment: Alignment.centerRight, child: trailingWidget)
                : Text(
                    trailing!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  /// 插画镜片里的语义图标，用来说明「空的是什么」。
  final IconData icon;
  final String title;
  final String description;

  /// 可选的操作入口（如「添加账户」）。空状态只说原因不给出口时，用户会卡在死路上。
  final Widget? action;

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
              _EmptyStateArt(
                key: const Key('empty_state_illustration'),
                icon: icon,
              ),
              const SizedBox(height: 12),
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
              if (action != null) ...<Widget>[
                const SizedBox(height: 14),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 空状态插画：一张倾斜的数据卡片，右下角压着放大镜，镜片里是调用方的语义图标。
///
/// 用原生绘制而不是外部素材：插画跟随 `colorScheme.primary` 与浅/深主题自动适配，
/// 不需要为素材登记许可证，也不占用 APK 体积。系统开启「减少动态效果」时只保留
/// 静态插画，不启动循环动画。
class _EmptyStateArt extends StatelessWidget {
  const _EmptyStateArt({super.key, required this.icon});

  final IconData icon;

  /// 插画画布边长（逻辑像素）。设计尺寸固定为 96，绘制时按此等比缩放。
  static const double extent = 96;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: extent,
        // 只做一次入场：空状态不需要常驻动画，减少动态效果时直接到位。
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, entrance, _) => CustomPaint(
            size: const Size.square(_EmptyStateArt.extent),
            painter: _EmptyStateArtPainter(
              entrance: entrance,
              icon: icon,
              primary: theme.colorScheme.primary,
              surface: veriContentSurfaceColor(theme.brightness),
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStateArtPainter extends CustomPainter {
  const _EmptyStateArtPainter({
    required this.entrance,
    required this.icon,
    required this.primary,
    required this.surface,
    required this.onSurface,
  });

  /// 入场进度（0→1）：整体轻微放大并上移、放大镜再往下落到位，避免空状态「砰」地跳出来。
  final double entrance;
  final IconData icon;
  final Color primary;
  final Color surface;
  final Color onSurface;

  static const double _design = _EmptyStateArt.extent;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _design;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale * (0.94 + 0.06 * entrance));
    canvas.translate(-_design / 2, -_design / 2 + (1 - entrance) * 6);
    _paintBackdrop(canvas);
    _paintCard(canvas);
    _paintLens(canvas);
    canvas.restore();
  }

  /// 底色圆：给插画一个柔和的落点，用主题色的极低透明度实色，不是渐变。
  void _paintBackdrop(Canvas canvas) {
    canvas.drawCircle(
      const Offset(48, 48),
      37,
      Paint()..color = primary.withValues(alpha: 0.07),
    );
  }

  void _paintCard(Canvas canvas) {
    canvas.save();
    canvas.translate(42, 45);
    canvas.rotate(-8 * math.pi / 180);
    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 44, height: 54),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..color = Color.alphaBlend(primary.withValues(alpha: 0.12), surface),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = primary.withValues(alpha: 0.34),
    );
    // 三条宽度递减的占位行：看得出是一份「还没有内容」的记录。
    const lineWidths = <double>[24, 19, 13];
    const lineAlphas = <double>[0.34, 0.26, 0.18];
    for (var i = 0; i < lineWidths.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-12, -11.5 + i * 9.4, lineWidths[i], 3.6),
          const Radius.circular(1.8),
        ),
        Paint()..color = onSurface.withValues(alpha: lineAlphas[i]),
      );
    }
    canvas.restore();
  }

  void _paintLens(Canvas canvas) {
    canvas.save();
    // 镜片比卡片晚一点落位，入场时有一点点「跟上来」的感觉。
    canvas.translate(0, (1 - entrance) * 7);
    const center = Offset(65, 65);
    const radius = 15.5;
    // 手柄先画、镜片后画：手柄内端被镜片盖住，看起来是从镜片伸出去的。
    canvas.drawLine(
      center + const Offset(radius * 0.72, radius * 0.72),
      const Offset(87, 87),
      Paint()
        ..color = primary
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Color.alphaBlend(primary.withValues(alpha: 0.18), surface),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..color = primary,
    );
    _paintIcon(canvas, center);
    canvas.restore();
  }

  void _paintIcon(Canvas canvas, Offset center) {
    final glyph = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 15,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: primary,
        ),
      ),
    )..layout();
    glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));
  }

  @override
  bool shouldRepaint(_EmptyStateArtPainter oldDelegate) =>
      oldDelegate.entrance != entrance ||
      oldDelegate.icon != icon ||
      oldDelegate.primary != primary ||
      oldDelegate.surface != surface ||
      oldDelegate.onSurface != onSurface;
}
