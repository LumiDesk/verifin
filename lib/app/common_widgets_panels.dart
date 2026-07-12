part of 'common_widgets.dart';

// 面板域：资产分组卡、日历预览、工具入口、区块标签。

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
                                        (Theme.of(
                                              context,
                                            ).textTheme.titleMedium?.fontSize ??
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

/// 分组小标题（设置页 / 账户详情页等分区卡片上方的灰色标签）。
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
