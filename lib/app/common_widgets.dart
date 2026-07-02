import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'demo_data.dart';
import 'ledger_math.dart';
import 'models.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile(
    this.entry, {
    super.key,
    required this.accounts,
    this.onTap,
  });

  final LedgerEntry entry;
  final List<Account> accounts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final category = categoryById(entry.categoryId);
    final account = accountById(accounts, entry.accountId);
    final amountColor = colorForType(entry.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(veriRadiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              VeriIconBox(icon: category.icon, color: amountColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatTime(entry.occurredAt)} · '
                      '${entry.note.isEmpty ? account.name : entry.note}',
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
                    formatSignedAmount(signedAmount(entry)),
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
                      account.name,
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

class TransactionListCard extends StatelessWidget {
  const TransactionListCard({
    super.key,
    required this.entries,
    required this.accounts,
    this.onEntryTap,
  });

  final List<LedgerEntry> entries;
  final List<Account> accounts;
  final ValueChanged<LedgerEntry>? onEntryTap;

  @override
  Widget build(BuildContext context) {
    return VeriCard(
      child: Column(
        children: <Widget>[
          for (final item in entries.indexed) ...<Widget>[
            TransactionTile(
              item.$2,
              accounts: accounts,
              onTap: onEntryTap == null ? null : () => onEntryTap!(item.$2),
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
  });

  final String label;
  final String value;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                  color: textColor.withValues(alpha: placeholder ? 0.32 : 0.88),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Divider(color: textColor.withValues(alpha: 0.07)),
      ],
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
              tooltip: '返回',
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
    this.onAccountTap,
  });

  final String title;
  final List<Account> accounts;
  final Map<Account, double> balances;
  final ValueChanged<Account>? onAccountTap;

  @override
  Widget build(BuildContext context) {
    final total = accounts.fold<double>(
      0,
      (sum, account) => sum + (balances[account] ?? 0),
    );

    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(title: title, trailing: formatAmount(total)),
          const SizedBox(height: 10),
          ...accounts.map(
            (account) => Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(veriRadiusSm),
                onTap: onAccountTap == null
                    ? null
                    : () => onAccountTap!(account),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: <Widget>[
                      VeriIconBox(icon: iconForCode(account.iconCode)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatAmount(balances[account] ?? 0),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: (balances[account] ?? 0) < 0
                                  ? veriExpense
                                  : veriIncome,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
                  '日历',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: '上个月',
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
                tooltip: '下个月',
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
          const Row(
            children: <Widget>[
              _WeekdayLabel('一'),
              _WeekdayLabel('二'),
              _WeekdayLabel('三'),
              _WeekdayLabel('四'),
              _WeekdayLabel('五'),
              _WeekdayLabel('六'),
              _WeekdayLabel('日'),
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
                  padding: const EdgeInsets.symmetric(vertical: 3),
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
                        height: 17,
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
                        height: 13,
                        child: expense <= 0
                            ? const SizedBox.shrink()
                            : Text(
                                '-${formatCompactAmount(expense)}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: veriExpense, fontSize: 9),
                              ),
                      ),
                      SizedBox(
                        height: 13,
                        child: income <= 0
                            ? const SizedBox.shrink()
                            : Text(
                                '+${formatCompactAmount(income)}',
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
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          VeriIconBox(icon: icon, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              trailing,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
