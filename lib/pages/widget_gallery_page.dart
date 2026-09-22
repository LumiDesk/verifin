import 'package:flutter/material.dart';

import '../app/common_widgets.dart';
import '../l10n/app_localizations.dart';

/// In-app guide for the native home_widget/Glance templates. The launcher is
/// the source of truth for the actual widget preview and placement flow.
class WidgetGalleryPage extends StatelessWidget {
  const WidgetGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <(String, String, String)>[
      (l10n.widgetQuickEntryName, l10n.widgetQuickEntryDesc, 'quick'),
      (l10n.widgetBudgetName, l10n.widgetBudgetDesc, 'budget'),
      (l10n.widgetNetWorthName, l10n.widgetNetWorthDesc, 'assets'),
      (l10n.widgetTrendName, l10n.widgetTrendDesc, 'trend'),
    ];
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              VeriHeader(
                title: l10n.widgetGalleryTitle,
                subtitle: l10n.widgetGallerySubtitle,
                showBack: true,
              ),
              const SizedBox(height: 12),
              Text(l10n.widgetHowToAddDesc),
              const SizedBox(height: 16),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _WidgetGuideCard(
                    title: item.$1,
                    description: item.$2,
                    kind: item.$3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidgetGuideCard extends StatelessWidget {
  const _WidgetGuideCard({
    required this.title,
    required this.description,
    required this.kind,
  });

  final String title;
  final String description;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 92,
            height: 68,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  kind == 'quick' ? '+' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '0',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
