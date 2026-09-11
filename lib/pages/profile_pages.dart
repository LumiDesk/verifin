import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/currency_math.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/root_navigation.dart';
import '../app/series_math.dart';
import '../app/veri_fin_scope.dart';
import 'ai_chat_page.dart';
import 'budget_pages.dart';
import 'category_management_page.dart';
import 'currency_rates_page.dart';
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
export 'currency_rates_page.dart';
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
    // 首页预算面板可被用户在面板管理里关掉，宫格入口按当前账本的预算周期
    // （含自定义起始日）打开总览，不能固定传自然月。
    final budgetKeyMonth = controller.budgetKeyMonthFor(DateTime.now());
    final profileTags = _profileSummaryTags(
      profile,
      AppLocalizations.of(context),
    );
    final valuedAccounts = controller.accounts.where(
      (account) => account.includeInAssets && !account.hidden,
    );
    final accountValuation = controller.accountBalancesInBase(
      accounts: valuedAccounts,
    );

    return VeriPage(
      child: ListView(
        padding: veriRootPageListPadding(context),
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
                          value: accountValuation.completeTotal == null
                              ? '—'
                              : formatUserMoney(
                                  accountValuation.completeTotal!,
                                  controller.activeBook.baseCurrencyCode,
                                ),
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
                color: veriSemantic(context, veriBlue),
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
                color: veriSemantic(context, veriWarning),
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
                color: veriSemantic(context, veriBlue),
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
              _FeatureTileData(
                icon: Icons.currency_exchange,
                color: veriCyan,
                label: AppLocalizations.of(context).currencyRatesTitle,
                // 单币种账本隐藏单位时不留币种代码；空串保住宫格的行高一致。
                subtitle:
                    optionalCurrencyUnit(
                      controller.activeBook.baseCurrencyCode,
                    ) ??
                    '',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const CurrencyRatesPage(),
                  ),
                ),
              ),
              // 新增入口一律追加在组末：已有入口的位置不变，避免用户改掉肌肉记忆。
              _FeatureTileData(
                icon: Icons.savings_outlined,
                color: veriSemantic(context, veriIncome),
                label: AppLocalizations.of(context).budgetTitle,
                subtitle: AppLocalizations.of(
                  context,
                ).yearMonth(budgetKeyMonth),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        BudgetOverviewPage(initialMonth: budgetKeyMonth),
                  ),
                ),
              ),
              _FeatureTileData(
                icon: Icons.smart_toy_outlined,
                color: veriIndigo,
                label: AppLocalizations.of(context).aiChatTitle,
                subtitle: controller.aiSettings.isConfigured
                    ? AppLocalizations.of(context).aiConfigured
                    : AppLocalizations.of(context).aiNotConfigured,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const AiChatPage(),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final textScaler = MediaQuery.textScalerOf(context);
              final labelStyle =
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ) ??
                  const TextStyle();
              // 用最长的一个「词」量一次宽度：标签可以换行，但单个词放不下就只能
              // 省略。据此决定列数——常规字号的中文仍是四列，长英文或大字号自动
              // 降列，不裁切标签。
              final longestWord = tiles
                  .expand((data) => data.label.split(' '))
                  .fold<String>('', (a, b) => b.length > a.length ? b : a);
              final painter = TextPainter(
                text: TextSpan(text: longestWord, style: labelStyle),
                textScaler: textScaler,
                textDirection: Directionality.of(context),
                maxLines: 1,
              )..layout();
              final needed = painter.width + 8;
              final columns = math.min(
                4,
                math.max(2, (constraints.maxWidth / needed).floor()),
              );
              final cellWidth =
                  (constraints.maxWidth - (columns - 1) * 4) / columns;
              final tileTextWidth = math.max(0.0, cellWidth - 4);
              final subtitleStyle =
                  Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                  ) ??
                  const TextStyle();
              double measuredHeight(
                String text,
                TextStyle style,
                int maxLines,
              ) {
                return (TextPainter(
                  text: TextSpan(text: text, style: style),
                  textScaler: textScaler,
                  textDirection: Directionality.of(context),
                  maxLines: maxLines,
                  ellipsis: '…',
                )..layout(maxWidth: tileTextWidth)).size.height;
              }

              final maxLabelHeight = tiles
                  .map((data) => measuredHeight(data.label, labelStyle, 2))
                  .fold<double>(0, math.max);
              final maxSubtitleHeight = tiles
                  .map(
                    (data) => measuredHeight(data.subtitle, subtitleStyle, 1),
                  )
                  .fold<double>(0, math.max);
              // Padding、图标、间距和文字高度，只保留 2dp 的字体度量余量，
              // 避免短标签卡在最后一行留下明显空洞。
              final rowExtent = math
                  .max(
                    90,
                    16 + 42 + 7 + maxLabelHeight + 1 + maxSubtitleHeight + 2,
                  )
                  .toDouble();
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                mainAxisExtent: rowExtent,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: tiles
                    .map((data) => _FeatureTile(data: data))
                    .toList(growable: false),
              );
            },
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
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            VeriIconBox(icon: data.icon, color: data.color, size: 42),
            const SizedBox(height: 7),
            Text(
              data.label,
              // 允许两行：英文标签（Currencies & rates 等）在四列宽度里一行放不下。
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
                fontWeight: FontWeight.w400,
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
