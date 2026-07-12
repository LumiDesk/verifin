part of 'common_widgets.dart';

// 交易展示域：交易行、日期分组、交易列表卡。

class TransactionTile extends StatelessWidget {
  const TransactionTile(
    this.entry, {
    super.key,
    required this.accounts,
    required this.categories,
    this.tags = const <Tag>[],
    this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
    this.showDate = false,
  });

  final LedgerEntry entry;
  final List<Account> accounts;
  final List<Category> categories;

  /// 用于把 [LedgerEntry.tagIds] 解析成标签名在副行展示；为空则不显示标签。
  final List<Tag> tags;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 多选模式：行首展示勾选圈，命中项高亮。
  final bool selectionMode;
  final bool selected;

  /// 副行时间是否按「今天只给时间、其余带日期」智能展示（[formatEntryStamp]）。
  /// 仅平铺、无日期分组头的列表（如首页「最近交易」）需要开；带分组头的列表
  /// 日期已在头部，保持关（默认）。
  final bool showDate;

  /// 把 [LedgerEntry.tagIds] 按顺序解析成标签名（跳过找不到的）。
  List<String> _tagLabels() {
    if (tags.isEmpty || entry.tagIds.isEmpty) {
      return const <String>[];
    }
    final byId = <String, String>{for (final tag in tags) tag.id: tag.label};
    return entry.tagIds
        .map((id) => byId[id])
        .whereType<String>()
        .toList(growable: false);
  }

  /// 标签副行文案：最多展示前 2 个标签名（`#出差 #报销`），更多的收成 `+N`。
  /// 备注太长时整段会被 [TextOverflow.ellipsis] 截断，避免撑爆一行。
  static String _tagSuffix(List<String> labels) {
    const maxShown = 2;
    final shown = labels.take(maxShown).map((label) => '#$label').join(' ');
    final extra = labels.length - maxShown;
    return extra > 0 ? '$shown +$extra' : shown;
  }

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
    // 分类层级：父级链（由近及远反转成「祖 · 父」）作淡色前缀，末级加粗单独渲染。
    // 无父（顶级 / 转账 / 悬空占位）时 ancestors 为空、不加前缀。
    final parentPrefix = ancestorIds(
      categories,
      entry.categoryId,
    ).reversed.map((id) => categoryById(id, categories).label).join(' · ');
    // 副行时间：平铺列表（showDate）按今天/今年/往年智能展示，否则只给时分。
    final stamp = showDate
        ? formatEntryStamp(entry.occurredAt)
        : formatTime(entry.occurredAt);
    final tagLabels = _tagLabels();
    final subStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.46),
    );

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
                        if (parentPrefix.isNotEmpty) ...<Widget>[
                          Flexible(
                            flex: 3,
                            child: Text(
                              parentPrefix,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          Text(
                            ' · ',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                        Flexible(
                          flex: 7,
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
                    Row(
                      children: <Widget>[
                        Text(stamp, style: subStyle),
                        if (entry.note.isNotEmpty) ...<Widget>[
                          Text(' · ', style: subStyle),
                          Flexible(
                            child: Text(
                              entry.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: subStyle,
                            ),
                          ),
                        ],
                        if (tagLabels.isNotEmpty)
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                _tagSuffix(tagLabels),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: subStyle?.copyWith(
                                  color: veriRoyal.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
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
    this.tags = const <Tag>[],
    this.onEntryTap,
    this.onEntryLongPress,
    this.selectionMode = false,
    this.selectedIds = const <String>{},
  });

  final List<LedgerEntry> entries;
  final List<Account> accounts;
  final List<Category> categories;

  /// 透传给 [TransactionTile] 解析标签名；为空则不显示标签。
  final List<Tag> tags;
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
              tags: tags,
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
