import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_localizations.dart';
import 'account_icon_assets.dart';
import 'app_theme.dart';
import 'credit_card.dart';
import 'demo_data.dart';
import 'ledger_math.dart';
import 'models.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile(
    this.entry, {
    super.key,
    required this.accounts,
    required this.categories,
    this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  final LedgerEntry entry;
  final List<Account> accounts;
  final List<Category> categories;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 多选模式：行首展示勾选圈，命中项高亮。
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final category = categoryById(entry.categoryId, categories);
    final noneLabel = AppLocalizations.of(context).noAccountLabel;
    final amountColor = colorForType(entry.type);
    final amountText = entry.type == EntryType.transfer
        ? formatAmount(entry.amount)
        : formatSignedAmount(signedAmount(entry));
    // 空 accountId / null toAccountId 表示「无账户」，不能用 accountById（会误回退首个账户）。
    final fromName = accountDisplayName(accounts, entry.accountId, noneLabel);
    final accountLabel = entry.type == EntryType.transfer
        ? '$fromName → ${accountDisplayName(accounts, entry.toAccountId ?? '', noneLabel)}'
        : fromName;

    return Material(
      color: selected ? veriRoyal.withValues(alpha: 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(veriRadiusSm),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(veriRadiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: <Widget>[
              if (selectionMode) ...<Widget>[
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected
                      ? veriRoyal
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 10),
              ],
              CategoryIconBox(
                iconCode: category.iconCode,
                color: amountColor,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (entry.refundedAmount > 0)
                          _EntryBadge(
                            text: AppLocalizations.of(context).badgeRefunded,
                            color: veriIncome,
                          )
                        else if (entry.reimbursable)
                          _EntryBadge(
                            text: AppLocalizations.of(
                              context,
                            ).badgeReimbursable,
                            color: veriRoyal,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatTime(entry.occurredAt)} · '
                      '${entry.note.isEmpty ? fromName : entry.note}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.46),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    amountText,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: amountColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.14),
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      accountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.46),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 交易行上的小徽标（待报销 / 已退款）。
class _EntryBadge extends StatelessWidget {
  const _EntryBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 同一天的交易分组（按日期倒序展示交易列表时用）。
class DateEntryGroup {
  const DateEntryGroup({required this.date, required this.entries});

  final DateTime date;
  final List<LedgerEntry> entries;
}

/// 把交易按「occurredAt 的日期」分组，日期从新到旧。
List<DateEntryGroup> groupEntriesByDate(List<LedgerEntry> entries) {
  final groups = <DateTime, List<LedgerEntry>>{};
  for (final entry in entries) {
    final date = DateTime(
      entry.occurredAt.year,
      entry.occurredAt.month,
      entry.occurredAt.day,
    );
    groups.putIfAbsent(date, () => <LedgerEntry>[]).add(entry);
  }
  return groups.entries
      .map((entry) => DateEntryGroup(date: entry.key, entries: entry.value))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

/// 相对今天的日期说明（今天 / 昨天，其余为空）。
String relativeDay(AppLocalizations l10n, DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) {
    return l10n.todayLabel;
  }
  if (diff == 1) {
    return l10n.yesterdayLabel;
  }
  return '';
}

/// 交易列表的日期分组小标题（日期 + 今天/昨天 + 当日合计）。
class DateGroupHeader extends StatelessWidget {
  const DateGroupHeader({super.key, required this.date, required this.entries});

  final DateTime date;
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final dayTotal = entries.fold<double>(
      0,
      (sum, entry) => sum + signedAmount(entry),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '${AppLocalizations.of(context).dateMonthDay(date)}  ${relativeDay(AppLocalizations.of(context), date)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.42),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            formatSignedAmount(dayTotal),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.35),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionListCard extends StatelessWidget {
  const TransactionListCard({
    super.key,
    required this.entries,
    required this.accounts,
    required this.categories,
    this.onEntryTap,
    this.onEntryLongPress,
    this.selectionMode = false,
    this.selectedIds = const <String>{},
  });

  final List<LedgerEntry> entries;
  final List<Account> accounts;
  final List<Category> categories;
  final ValueChanged<LedgerEntry>? onEntryTap;
  final ValueChanged<LedgerEntry>? onEntryLongPress;
  final bool selectionMode;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context) {
    return VeriCard(
      child: Column(
        children: <Widget>[
          for (final item in entries.indexed) ...<Widget>[
            TransactionTile(
              item.$2,
              accounts: accounts,
              categories: categories,
              selectionMode: selectionMode,
              selected: selectedIds.contains(item.$2.id),
              onTap: onEntryTap == null ? null : () => onEntryTap!(item.$2),
              onLongPress: onEntryLongPress == null
                  ? null
                  : () => onEntryLongPress!(item.$2),
            ),
            if (item.$1 != entries.length - 1)
              Divider(
                indent: 19,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }
}

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

class VeriPage extends StatelessWidget {
  const VeriPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
    this.padding = const EdgeInsets.all(13),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool quietTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(veriRadiusMd);
    final decoration = BoxDecoration(
      color: isDark ? veriSurfaceDark : veriSurfaceLight,
      borderRadius: borderRadius,
      border: Border.all(
        color: isDark ? Colors.white.withValues(alpha: 0.10) : veriLine,
      ),
      boxShadow: <BoxShadow>[
        if (!isDark)
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
    return SizedBox(
      height: veriHeaderHeight,
      child: Row(
        children: <Widget>[
          if (showBack) ...<Widget>[
            IconButton(
              tooltip: AppLocalizations.of(context).commonBack,
              onPressed: onBack ?? () => Navigator.of(context).pop(),
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
                      ).colorScheme.onSurface.withValues(alpha: 0.48),
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
    final color = destructive
        ? veriExpense
        : Theme.of(context).colorScheme.onSurface;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color.withValues(alpha: 0.82)),
    );
  }
}

class HeaderPopupAction<T> extends StatelessWidget {
  const HeaderPopupAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onSelected,
    required this.itemBuilder,
  });

  final String tooltip;
  final IconData icon;
  final PopupMenuItemSelected<T> onSelected;
  final PopupMenuItemBuilder<T> itemBuilder;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      icon: Icon(icon),
      onSelected: onSelected,
      itemBuilder: itemBuilder,
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

class AccountGroupCard extends StatelessWidget {
  const AccountGroupCard({
    super.key,
    required this.title,
    required this.accounts,
    required this.balances,
    this.collapsed = false,
    this.sectionDragIndex,
    this.sectionDragImmediate = false,
    this.onToggleCollapsed,
    this.onReorderAccounts,
    this.onAccountTap,
    this.hapticsEnabled = true,
  });

  final String title;
  final List<Account> accounts;
  final Map<Account, double> balances;
  final bool collapsed;
  final int? sectionDragIndex;
  final bool sectionDragImmediate;
  final VoidCallback? onToggleCollapsed;
  final ReorderCallback? onReorderAccounts;
  final ValueChanged<Account>? onAccountTap;
  final bool hapticsEnabled;

  @override
  Widget build(BuildContext context) {
    final total = accounts.fold<double>(
      0,
      (sum, account) =>
          account.includeInAssets ? sum + (balances[account] ?? 0) : sum,
    );

    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(veriRadiusSm),
            onTap: onToggleCollapsed == null
                ? null
                : () {
                    if (hapticsEnabled) {
                      HapticFeedback.selectionClick();
                    }
                    onToggleCollapsed?.call();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (sectionDragIndex != null) ...<Widget>[
                    const SizedBox(width: 6),
                    _buildSectionDragHandle(context),
                  ],
                  const SizedBox(width: 4),
                  Text(
                    formatAmount(total),
                    key: Key('account_group_total_$title'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.58),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: collapsed ? 0 : 0.5,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.42),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: collapsed
                ? const SizedBox.shrink()
                : Column(
                    children: <Widget>[
                      const SizedBox(height: 10),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        proxyDecorator: (child, _, _) => Material(
                          color: Colors.transparent,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(veriRadiusSm),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: child,
                          ),
                        ),
                        itemCount: accounts.length,
                        onReorderStart: (_) {
                          if (hapticsEnabled) {
                            HapticFeedback.selectionClick();
                          }
                        },
                        onReorderEnd: (_) {
                          if (hapticsEnabled) {
                            HapticFeedback.selectionClick();
                          }
                        },
                        onReorderItem: (oldIndex, newIndex) {
                          if (hapticsEnabled) {
                            HapticFeedback.selectionClick();
                          }
                          (onReorderAccounts ?? (_, _) {})(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final account = accounts[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey<String>('account_${account.id}'),
                            index: index,
                            child: _AccountRow(
                              account: account,
                              balance: balances[account] ?? 0,
                              onTap: onAccountTap == null
                                  ? null
                                  : () => onAccountTap!(account),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDragHandle(BuildContext context) {
    final handle = Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(
        Icons.drag_indicator,
        size: 18,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.34),
      ),
    );
    if (sectionDragImmediate) {
      return ReorderableDragStartListener(
        index: sectionDragIndex!,
        child: handle,
      );
    }
    return ReorderableDelayedDragStartListener(
      index: sectionDragIndex!,
      child: handle,
    );
  }
}

/// 资产列表中的余额颜色:不计入资产的账户用弱化色,负余额红色,其余青绿色。
Color accountBalanceColor(
  BuildContext context,
  Account account,
  double balance,
) {
  if (!account.includeInAssets) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.42);
  }
  return balance < 0 ? veriExpense : veriIncome;
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.balance,
    required this.onTap,
  });

  final Account account;
  final double balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              AccountIconBox(iconCode: account.iconCode),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text.rich(
                      TextSpan(
                        text: account.name,
                        children: <TextSpan>[
                          if (account.cardLast4.isNotEmpty &&
                              account.type.supportsCardLast4)
                            TextSpan(
                              text: ' (${account.cardLast4})',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.42),
                                    fontSize:
                                        (Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.fontSize ??
                                                16) *
                                        0.82,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (account.type.supportsCredit &&
                        account.creditLimit != null)
                      Text(
                        '${AppLocalizations.of(context).creditAvailableLabel} '
                        '${formatAmount(availableCredit(account.creditLimit, balance) ?? 0)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatAmount(balance),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: accountBalanceColor(context, account, balance),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalendarPreview extends StatefulWidget {
  const CalendarPreview({super.key, required this.entries, this.onDayTap});

  final List<LedgerEntry> entries;
  final ValueChanged<DateTime>? onDayTap;

  @override
  State<CalendarPreview> createState() => _CalendarPreviewState();
}

class _CalendarPreviewState extends State<CalendarPreview> {
  late DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = DateUtils.getDaysInMonth(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    final leadingBlanks =
        DateTime(_visibleMonth.year, _visibleMonth.month).weekday - 1;

    return VeriCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppLocalizations.of(context).calendarTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).calendarPrevMonth,
                onPressed: () => setState(() {
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month - 1,
                  );
                }),
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 64),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? veriSurfaceAltDark
                      : veriSurfaceAltLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : veriLine,
                  ),
                ),
                child: Text(
                  '${_visibleMonth.year}.${_visibleMonth.month.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).calendarNextMonth,
                onPressed: () => setState(() {
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month + 1,
                  );
                }),
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _WeekdayLabel(AppLocalizations.of(context).weekdayMon),
              _WeekdayLabel(AppLocalizations.of(context).weekdayTue),
              _WeekdayLabel(AppLocalizations.of(context).weekdayWed),
              _WeekdayLabel(AppLocalizations.of(context).weekdayThu),
              _WeekdayLabel(AppLocalizations.of(context).weekdayFri),
              _WeekdayLabel(AppLocalizations.of(context).weekdaySat),
              _WeekdayLabel(AppLocalizations.of(context).weekdaySun),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 4,
              mainAxisExtent: 50,
            ),
            itemCount: leadingBlanks + days,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) {
                return const SizedBox.shrink();
              }
              final day = index - leadingBlanks + 1;
              final dayEntries = widget.entries
                  .where(
                    (entry) =>
                        entry.occurredAt.year == _visibleMonth.year &&
                        entry.occurredAt.month == _visibleMonth.month &&
                        entry.occurredAt.day == day,
                  )
                  .toList();
              final income = sumByType(dayEntries, EntryType.income);
              final expense = sumByType(dayEntries, EntryType.expense);
              final date = DateTime(
                _visibleMonth.year,
                _visibleMonth.month,
                day,
              );

              return InkWell(
                borderRadius: BorderRadius.circular(veriRadiusSm),
                onTap: widget.onDayTap == null
                    ? null
                    : () => widget.onDayTap!(date),
                child: Container(
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        day == now.day &&
                            _visibleMonth.year == now.year &&
                            _visibleMonth.month == now.month
                        ? veriRoyal.withValues(alpha: 0.12)
                        : Colors.transparent,
                    border: Border.all(
                      color:
                          day == now.day &&
                              _visibleMonth.year == now.year &&
                              _visibleMonth.month == now.month
                          ? veriRoyal.withValues(alpha: 0.16)
                          : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(veriRadiusSm),
                  ),
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: 16,
                        child: Text(
                          '$day',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color:
                                    day == now.day &&
                                        _visibleMonth.year == now.year &&
                                        _visibleMonth.month == now.month
                                    ? veriRoyal
                                    : null,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      SizedBox(
                        height: 12,
                        child: expense <= 0
                            ? const SizedBox.shrink()
                            : Text(
                                '-${formatCompactAmount(AppLocalizations.of(context), expense)}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: veriExpense, fontSize: 9),
                              ),
                      ),
                      SizedBox(
                        height: 12,
                        child: income <= 0
                            ? const SizedBox.shrink()
                            : Text(
                                '+${formatCompactAmount(AppLocalizations.of(context), income)}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: veriIncome, fontSize: 9),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.42),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ToolEntry extends StatelessWidget {
  const ToolEntry({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, color: veriBlue, size: 24),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

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
/// 开关打开时后四位只读、自动取完整卡号末四位；关闭后可手填、独立于完整卡号。开关初始态
/// 由 [initialCardLast4Follows] 从两控制器当前值反推，不额外持久化。调用方读两控制器取值，
/// 后四位建议以 [cardLast4Of] 归一化后落库。
class CardNumberFields extends StatefulWidget {
  const CardNumberFields({
    super.key,
    required this.numberController,
    required this.last4Controller,
  });

  final TextEditingController numberController;
  final TextEditingController last4Controller;

  @override
  State<CardNumberFields> createState() => _CardNumberFieldsState();
}

class _CardNumberFieldsState extends State<CardNumberFields> {
  late bool _follows;

  @override
  void initState() {
    super.initState();
    _follows = initialCardLast4Follows(
      widget.numberController.text,
      widget.last4Controller.text,
    );
    widget.numberController.addListener(_onNumberChanged);
  }

  @override
  void dispose() {
    widget.numberController.removeListener(_onNumberChanged);
    super.dispose();
  }

  void _onNumberChanged() {
    if (!_follows) {
      return;
    }
    final derived = cardLast4Of(widget.numberController.text);
    if (widget.last4Controller.text != derived) {
      widget.last4Controller.text = derived;
    }
  }

  void _toggleFollows(bool value) {
    setState(() => _follows = value);
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
                enabled: !_follows,
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
            Switch(value: _follows, onChanged: _toggleFollows),
          ],
        ),
      ],
    );
  }
}
