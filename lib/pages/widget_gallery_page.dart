import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/platform_bridge.dart';
import '../app/series_math.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';

/// 桌面小组件展示页：列出全部可用小组件、实时预览样式，并支持一键添加到桌面
/// （启动器支持时弹系统添加弹窗，否则回落为手动添加引导）。
class WidgetGalleryPage extends StatelessWidget {
  const WidgetGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final entries = controller.entries;

    // 预览用实时数据，让展示更贴近桌面上的真实效果。
    final today = formatAmount(dayExpenseTotal(entries, dateOnly(now)));
    final monthExpense = sumByType(
      entries.where((entry) => isInMonth(entry, now)),
      EntryType.expense,
    );
    final remaining = controller.monthlyBudget(now) - monthExpense;
    final netWorth = formatAmount(
      controller.accounts
          .where((account) => !account.hidden)
          .fold<double>(
            0,
            (sum, account) => sum + controller.accountBalance(account),
          ),
    );

    final specs = <_WidgetSpec>[
      _WidgetSpec(
        widgetKey: 'quick_entry',
        name: l10n.widgetQuickEntryName,
        description: l10n.widgetQuickEntryDesc,
        previewLabel: l10n.widgetTodayExpense,
        previewValue: today,
        showEntryButton: true,
      ),
      _WidgetSpec(
        widgetKey: 'budget',
        name: l10n.widgetBudgetName,
        description: l10n.widgetBudgetDesc,
        previewLabel: remaining < 0
            ? l10n.widgetBudgetOverspent
            : l10n.widgetBudgetAvailable,
        previewValue: formatAmount(remaining.abs()),
      ),
      _WidgetSpec(
        widgetKey: 'net_worth',
        name: l10n.widgetNetWorthName,
        description: l10n.widgetNetWorthDesc,
        previewLabel: l10n.widgetNetWorth,
        previewValue: netWorth,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: l10n.widgetGalleryTitle,
                subtitle: l10n.widgetGallerySubtitle,
                showBack: true,
              ),
              const SizedBox(height: 10),
              ...specs.map(
                (spec) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _WidgetCard(spec: spec),
                ),
              ),
              VeriCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.help_outline, size: 18, color: veriRoyal),
                        const SizedBox(width: 6),
                        Text(
                          l10n.widgetHowToAddTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.widgetHowToAddDesc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidgetSpec {
  const _WidgetSpec({
    required this.widgetKey,
    required this.name,
    required this.description,
    required this.previewLabel,
    required this.previewValue,
    this.showEntryButton = false,
  });

  final String widgetKey;
  final String name;
  final String description;
  final String previewLabel;
  final String previewValue;
  final bool showEntryButton;
}

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({required this.spec});

  final _WidgetSpec spec;

  Future<void> _addToHome(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await AppWidgetBridge.pinWidget(spec.widgetKey);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.widgetPinRequested : l10n.widgetPinUnsupported),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _WidgetPreview(spec: spec),
          const SizedBox(height: 12),
          Text(
            spec.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            spec.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _addToHome(context),
              icon: const Icon(Icons.add_to_home_screen, size: 18),
              label: Text(l10n.widgetAddToHome),
            ),
          ),
        ],
      ),
    );
  }
}

/// 应用内还原小组件在桌面上的外观：随系统深浅色切换的白/黑卡片 + 标签 + 大数值，
/// 与原生 `widget_background`（`@color/widget_surface` 等）配色保持一致。
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.spec});

  final _WidgetSpec spec;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final border = dark ? const Color(0xFF38383A) : const Color(0xFFE5E7EB);
    final labelColor = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final valueColor = dark ? const Color(0xFFF5F5F7) : const Color(0xFF111827);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  spec.previewLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: labelColor, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  spec.previewValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (spec.showEntryButton) ...<Widget>[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: veriRoyal,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.add, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
