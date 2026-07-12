part of 'common_widgets.dart';

// 图标与小型展示控件：账户/分类图标盒、筛选丸、详情行、汇总指标等。

class AccountIconBox extends StatelessWidget {
  const AccountIconBox({
    super.key,
    required this.iconCode,
    this.size = 28,
    this.color,
  });

  final String iconCode;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final option = accountAssetIconByCode(iconCode);
    if (option == null) {
      return VeriIconBox(
        icon: iconForCode(iconCode),
        color: color ?? veriRoyal,
        size: size,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all((size * 0.18).clamp(4, 8).toDouble()),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(veriRadiusSm),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
        ),
      ),
      child: SvgPicture.asset(option.assetPath, fit: BoxFit.contain),
    );
  }
}

class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.showChevron = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? veriSurfaceAltDark : veriSurfaceLight,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.10) : veriLine,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 16),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
              if (showChevron) ...<Widget>[
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DetailInfoRow extends StatelessWidget {
  const DetailInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.placeholder = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textColor.withValues(alpha: 0.36),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: textColor.withValues(
                          alpha: placeholder ? 0.32 : 0.88,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: textColor.withValues(alpha: 0.30),
                ),
            ],
          ),
        ),
        Divider(color: textColor.withValues(alpha: 0.07)),
      ],
    );
    if (onTap == null) {
      return content;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

class SummaryMetric extends StatelessWidget {
  const SummaryMetric({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.detail,
  });

  final String label;
  final String value;
  final Color color;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.54),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              detail!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColor.withValues(alpha: 0.42),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class VeriIconBox extends StatelessWidget {
  const VeriIconBox({
    super.key,
    required this.icon,
    this.color = veriRoyal,
    this.size = 30,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(veriRadiusSm),
      ),
      child: Icon(icon, size: size * 0.54, color: color),
    );
  }
}

/// 分类图标盒：内置图标走 [iconForCode] 上色渲染；emoji 自定义图标（`emoji:` 前缀）
/// 以原色字符居中渲染（emoji 自带颜色，不上色）。统一分类图标的展示入口。
class CategoryIconBox extends StatelessWidget {
  const CategoryIconBox({
    super.key,
    required this.iconCode,
    this.color = veriRoyal,
    this.size = 30,
  });

  final String iconCode;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (isEmojiIconCode(iconCode)) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(veriRadiusSm),
        ),
        child: Text(
          emojiOfIconCode(iconCode),
          style: TextStyle(fontSize: size * 0.56, height: 1),
        ),
      );
    }
    return VeriIconBox(icon: iconForCode(iconCode), color: color, size: size);
  }
}

/// 分类图标的裸字形（无背景盒）：内置图标为 [Icon]，emoji 为 [Text]。
/// 用于 Chip avatar、内联小图标等不需要色块背景的场景。
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph({
    super.key,
    required this.iconCode,
    this.size = 18,
    this.color,
  });

  final String iconCode;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (isEmojiIconCode(iconCode)) {
      return Text(
        emojiOfIconCode(iconCode),
        style: TextStyle(fontSize: size, height: 1),
      );
    }
    return Icon(iconForCode(iconCode), size: size, color: color);
  }
}

class VeriSectionAction extends StatelessWidget {
  const VeriSectionAction({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(32, 32),
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        backgroundColor: veriBlue.withValues(alpha: 0.10),
        foregroundColor: veriRoyal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(veriRadiusSm),
        ),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}
