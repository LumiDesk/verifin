import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'demo_data.dart';
import 'ledger_math.dart';
import 'models.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile(this.entry, {super.key, required this.accounts});

  final LedgerEntry entry;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final category = categoryById(entry.categoryId);
    final account = accountById(accounts, entry.accountId);
    final amountColor = entry.type == EntryType.income ? veriMint : null;

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 36,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: colorForType(entry.type).withValues(alpha: 0.16),
        child: Icon(category.icon, size: 18, color: colorForType(entry.type)),
      ),
      title: Text(category.label),
      subtitle: Text(
        '${formatTime(entry.occurredAt)} · ${account.name}'
        '${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
      ),
      trailing: Text(
        formatSignedAmount(signedAmount(entry)),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: amountColor,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? const <Color>[Color(0xFF101216), Color(0xFF141A24)]
              : const <Color>[Color(0xFFF6FBFC), Color(0xFFEFF5FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      ),
    );
  }
}

class VeriCard extends StatelessWidget {
  const VeriCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0F12) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE8EEF4),
        ),
        boxShadow: <BoxShadow>[
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: child,
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
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
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: Theme.of(context).textTheme.titleMedium),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 40, color: veriBlue),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(description, textAlign: TextAlign.center),
        ],
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
          const SizedBox(height: 12),
          ...accounts.map(
            (account) => Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                contentPadding: EdgeInsets.zero,
                onTap: onAccountTap == null
                    ? null
                    : () => onAccountTap!(account),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: veriBlue.withValues(alpha: 0.16),
                  child: Icon(iconForCode(account.iconCode), color: veriBlue),
                ),
                title: Text(account.name),
                trailing: Text(
                  formatAmount(balances[account] ?? 0),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: (balances[account] ?? 0) < 0
                        ? const Color(0xFFE84D6A)
                        : veriMint,
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
  const CalendarPreview({super.key, required this.entries});

  final List<LedgerEntry> entries;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '日历视图',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${_visibleMonth.month}月'),
              IconButton(
                tooltip: '下个月',
                onPressed: () => setState(() {
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month + 1,
                  );
                }),
                icon: const Icon(Icons.chevron_right),
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
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: leadingBlanks + days,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) {
                return const SizedBox.shrink();
              }
              final day = index - leadingBlanks + 1;
              final dayTotal = widget.entries
                  .where(
                    (entry) =>
                        entry.occurredAt.year == _visibleMonth.year &&
                        entry.occurredAt.month == _visibleMonth.month &&
                        entry.occurredAt.day == day,
                  )
                  .fold<double>(0, (sum, entry) => sum + signedAmount(entry));
              final hasEntry = dayTotal != 0;

              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      day == now.day &&
                          _visibleMonth.year == now.year &&
                          _visibleMonth.month == now.month
                      ? veriBlue.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('$day'),
                    if (hasEntry)
                      Text(
                        formatSignedAmount(dayTotal),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: dayTotal >= 0
                              ? veriMint
                              : const Color(0xFFE84D6A),
                        ),
                      ),
                  ],
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
        style: Theme.of(context).textTheme.labelSmall,
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
        Icon(icon, color: veriBlue),
        const SizedBox(height: 8),
        Text(label),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      trailing: Text(trailing),
    );
  }
}
