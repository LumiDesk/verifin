import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/ledger_math.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/series_math.dart';
import '../app/veri_fin_scope.dart';
import 'category_management_page.dart';
import 'data_management_page.dart';
import 'ledger_books_page.dart';
import 'profile_info_page.dart';
import 'profile_widgets.dart';
import 'recurring_page.dart';
import 'reminder_settings_page.dart';
import 'report_analysis_page.dart';
import 'settings_page.dart';
import 'tag_management_page.dart';
import 'widget_gallery_page.dart';

// 「我的」页由多个子页面组成；各子页面拆到独立文件，这里作为聚合入口统一导出，
// 以便既有 import 'profile_pages.dart' 的调用点无需改动（阶段 4.3 工程化拆分）。
export 'category_management_page.dart';
export 'ledger_books_page.dart';
export 'profile_info_page.dart';
export 'profile_widgets.dart';
export 'settings_page.dart';
export 'tag_management_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final profile = controller.profile;
    final profileTags = _profileSummaryTags(
      profile,
      AppLocalizations.of(context),
    );
    final netAssets = controller.accounts
        .where((account) => account.includeInAssets && !account.hidden)
        .fold<double>(
          0,
          (sum, account) => sum + controller.accountBalance(account),
        );

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 82),
        children: <Widget>[
          PageHeader(
            title: AppLocalizations.of(context).tabProfile,
            subtitle: AppLocalizations.of(context).profileCenterSubtitle,
            trailing: IconButton(
              tooltip: AppLocalizations.of(context).settingsTooltip,
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const SettingsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(veriRadiusMd),
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => const ProfileInfoPage(),
                ),
              );
            },
            child: VeriCard(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      ProfileAvatar(profile: profile, radius: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              profile.nickname,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (profile.bio.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                profile.bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (profileTags.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: profileTags
                                    .map((tag) => _ProfileMetaTag(label: tag))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final (value, label) = bookkeepingDurationStat(
                              AppLocalizations.of(context),
                              bookkeepingDays(controller.entries),
                            );
                            return ProfileStat(label: label, value: value);
                          },
                        ),
                      ),
                      Expanded(
                        child: ProfileStat(
                          label: AppLocalizations.of(context).entryCountStat,
                          value: '${controller.entries.length}',
                        ),
                      ),
                      Expanded(
                        child: ProfileStat(
                          label: AppLocalizations.of(context).netAssets,
                          value: formatAmount(netAssets),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _FeatureGridCard(
            title: AppLocalizations.of(context).bookkeepingMgmt,
            tiles: <_FeatureTileData>[
              _FeatureTileData(
                icon: Icons.book_outlined,
                color: veriRoyal,
                label: AppLocalizations.of(context).ledgerLabel,
                subtitle: controller.activeBook.name,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const LedgerBooksPage(),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.category_outlined,
                color: veriBlue,
                label: AppLocalizations.of(context).categoryMgmt,
                subtitle: AppLocalizations.of(
                  context,
                ).countItems(controller.categories.length),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const CategoryManagementPage(),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.label_outline,
                color: veriCyan,
                label: AppLocalizations.of(context).tagMgmt,
                subtitle: AppLocalizations.of(
                  context,
                ).countItems(controller.tags.length),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const TagManagementPage(),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.repeat,
                color: veriMint,
                label: AppLocalizations.of(context).recurringTitle,
                subtitle: AppLocalizations.of(
                  context,
                ).countRules(controller.recurringRules.length),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const RecurringRulesPage(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FeatureGridCard(
            title: AppLocalizations.of(context).dataAndTools,
            tiles: <_FeatureTileData>[
              _FeatureTileData(
                icon: Icons.insights_outlined,
                color: veriRoyal,
                label: AppLocalizations.of(context).statAnalysisTitle,
                subtitle: AppLocalizations.of(context).reportShort,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const ReportAnalysisPage(),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.notifications_active_outlined,
                color: veriWarning,
                label: AppLocalizations.of(context).reminderTitle,
                subtitle: controller.reminderSettings.enabled
                    ? controller.reminderSettings.timeLabel
                    : AppLocalizations.of(context).notEnabled,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const ReminderSettingsPage(),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.storage_outlined,
                color: veriBlue,
                label: AppLocalizations.of(context).dataManagement,
                subtitle: AppLocalizations.of(context).backupRestoreShort,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const DataManagementPage(),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.widgets_outlined,
                color: veriMint,
                label: AppLocalizations.of(context).widgetGalleryTitle,
                subtitle: AppLocalizations.of(context).widgetGalleryShort,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const WidgetGalleryPage(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 我的页功能宫格卡：标题 + 4 列图标宫格。
class _FeatureGridCard extends StatelessWidget {
  const _FeatureGridCard({required this.title, required this.tiles});

  final String title;
  final List<_FeatureTileData> tiles;

  @override
  Widget build(BuildContext context) {
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(title: title),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.82,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: tiles
                .map((data) => _FeatureTile(data: data))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _FeatureTileData {
  const _FeatureTileData({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.data});

  final _FeatureTileData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(veriRadiusMd),
      onTap: data.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            VeriIconBox(icon: data.icon, color: data.color, size: 42),
            const SizedBox(height: 7),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 1),
            Text(
              data.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.46),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _profileSummaryTags(UserProfile profile, AppLocalizations l10n) {
  final tags = <String>[];
  if (profile.gender != ProfileGender.unset) {
    tags.add(profile.gender.label(l10n));
  }
  if (profile.birthday.isNotEmpty) {
    tags.add(profile.birthday);
  }
  if (profile.city.isNotEmpty) {
    tags.add(profile.city);
  }
  if (profile.occupation.isNotEmpty) {
    tags.add(profile.occupation);
  }
  return tags;
}

class _ProfileMetaTag extends StatelessWidget {
  const _ProfileMetaTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(veriRadiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.58),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
