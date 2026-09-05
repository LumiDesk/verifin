import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../app/account_icon_assets.dart';
import '../app/app_theme.dart';
import '../app/avatar_picker.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/currency_catalog.dart';
import '../app/currency_math.dart';
import '../app/icon_catalog.dart';
import '../app/image_cropper.dart';
import '../app/image_sources.dart';
import '../app/models.dart';
import '../app/root_navigation.dart';
import '../app/series_math.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';
import 'account_detail_page.dart';

part 'account_group_pages.dart';
part 'add_account_page.dart';
part 'asset_display_settings_page.dart';

const double assetCoverAspectRatio = 1200 / 760;

const int assetCoverTargetWidth = 1200;

const int assetCoverTargetHeight = 760;

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  static const List<_AssetCoverPreset> _coverPresets = <_AssetCoverPreset>[
    _AssetCoverPreset(
      id: 'blue_city',
      url:
          'https://images.unsplash.com/photo-1480714378408-67cf0d13bc1f?auto=format&fit=crop&w=1200&q=80',
    ),
    _AssetCoverPreset(
      id: 'aurora',
      url:
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
    ),
    _AssetCoverPreset(
      id: 'finance_office',
      url:
          'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1200&q=80',
    ),
    _AssetCoverPreset(
      id: 'deep_blue',
      url:
          'https://images.unsplash.com/photo-1557682250-33bd709cbe85?auto=format&fit=crop&w=1200&q=80',
    ),
  ];

  // 普通浏览时的展开/折叠仅是临时 UI 状态，不再静默持久化。
  final Set<String> _collapsedSections = <String>{};

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final accounts = _sortedAccounts(controller.accounts);
    final groups = controller.accountGroups;
    final balances = <Account, double>{
      for (final account in accounts)
        account: controller.accountBalance(account),
    };
    final valuedAccounts = accounts
        .where((account) => account.includeInAssets && !account.hidden)
        .toList(growable: false);
    final valuation = controller.accountBalancesInBase(
      accounts: valuedAccounts,
    );
    final baseCurrencyCode = controller.activeBook.baseCurrencyCode;
    final valuationRateDates = valuation.rateDatesByAccountId.values.toList()
      ..sort();
    final oldestValuationRateDate = valuationRateDates.firstOrNull;
    final assets = valuation.isComplete
        ? valuedAccounts
              .map((account) => valuation.amountsByAccountId[account.id] ?? 0)
              .where((value) => value > 0)
              .fold<double>(0, (sum, value) => sum + value)
        : null;
    final liabilities = valuation.isComplete
        ? valuedAccounts
              .map((account) => valuation.amountsByAccountId[account.id] ?? 0)
              .where((value) => value < 0)
              .fold<double>(0, (sum, value) => sum + value)
        : null;
    final assetTrendValues = _baseCurrencyAssetTrend(
      accounts: valuedAccounts,
      entries: controller.entries,
      convert: ({required amount, required currencyCode, required date}) =>
          controller.convertAmount(
            amount: amount,
            sourceCurrencyCode: currencyCode,
            targetCurrencyCode: baseCurrencyCode,
            date: date,
          ),
    );
    final hasAssetCover = controller.assetCoverUrl.isNotEmpty;
    final assetCardTextColor = hasAssetCover
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final assetCardMutedColor = assetCardTextColor.withValues(
      alpha: hasAssetCover ? 0.72 : 0.54,
    );
    final hiddenAccounts = accounts
        .where((account) => account.hidden)
        .toList(growable: false);
    final viewMode = controller.assetAccountViewMode;
    final visibleGroups = <AccountGroup>[
      ...groups,
      AccountGroup(
        id: 'ungrouped',
        bookId: controller.activeBook.id,
        name: AppLocalizations.of(context).assetsUngrouped,
        sortOrder: 999,
      ),
    ];
    final assetSections = controller.sortedAssetSections<_AssetAccountSection>(
      mode: viewMode,
      sections: viewMode == AssetAccountViewMode.group
          ? visibleGroups
                .map(
                  (group) => _AssetAccountSection(
                    id: group.id,
                    title: group.name,
                    accounts: controller.sortedAccountsForAssetSection(
                      mode: viewMode,
                      sectionId: group.id,
                      accounts: accounts.where(
                        (account) =>
                            _effectiveGroupId(account) == group.id &&
                            !account.hidden,
                      ),
                    ),
                  ),
                )
                .toList()
          : AccountType.values
                .map(
                  (type) => _AssetAccountSection(
                    id: type.name,
                    title: type.label(AppLocalizations.of(context)),
                    accounts: controller.sortedAccountsForAssetSection(
                      mode: viewMode,
                      sectionId: type.name,
                      accounts: accounts.where(
                        (account) => account.type == type && !account.hidden,
                      ),
                    ),
                  ),
                )
                .toList(),
      idOf: (section) => section.id,
    );
    final visibleAssetSections = assetSections
        .where((section) => section.accounts.isNotEmpty)
        .toList(growable: false);
    return VeriPage(
      child: ListView(
        padding: veriRootPageListPadding(context),
        children: <Widget>[
          PageHeader(
            title: AppLocalizations.of(context).tabAssets,
            subtitle: AppLocalizations.of(
              context,
            ).baseCurrencyAmountLabel(displayCurrencyUnit(baseCurrencyCode)),
            trailing: VeriAnchoredMenuButton(
              icon: Icons.add,
              tooltip: AppLocalizations.of(context).assetsActions,
              width: 208,
              entries: _assetActionMenuEntries(context),
            ),
          ),
          const SizedBox(height: 10),
          VeriGlassSurface(
            enabled: !hasAssetCover,
            child: Container(
              key: const Key('asset_cover_card'),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: hasAssetCover
                    ? null
                    : veriGlassDesignPreview
                    ? Colors.transparent
                    : veriContentSurfaceColor(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(veriCardRadius),
                border: Border.all(
                  color: veriGlassDesignPreview && !hasAssetCover
                      ? Colors.transparent
                      : veriUnifiedDesignPreview
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.045)
                      : Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.10)
                      : veriLine,
                ),
                image: !hasAssetCover
                    ? null
                    : DecorationImage(
                        image: imageProviderForSource(controller.assetCoverUrl),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                boxShadow: <BoxShadow>[
                  if (!veriUnifiedDesignPreview &&
                      Theme.of(context).brightness == Brightness.light)
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.045),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  if (hasAssetCover)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.28),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context).netAssets,
                                style: TextStyle(color: assetCardMutedColor),
                              ),
                            ),
                            IconButton(
                              tooltip: AppLocalizations.of(
                                context,
                              ).assetsChangeCover,
                              onPressed: () => _openDisplaySettings(context),
                              style: IconButton.styleFrom(
                                fixedSize: const Size(32, 32),
                                minimumSize: const Size(32, 32),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(
                                Icons.photo_size_select_actual_outlined,
                                color: assetCardMutedColor,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          assets == null || liabilities == null
                              ? '—'
                              : formatUserMoney(
                                  assets + liabilities,
                                  baseCurrencyCode,
                                ),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: assetCardTextColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              AppLocalizations.of(context).assetsAmount(
                                assets == null
                                    ? '—'
                                    : formatUserMoney(assets, baseCurrencyCode),
                              ),
                              style: TextStyle(color: assetCardTextColor),
                            ),
                            Text(
                              AppLocalizations.of(context).liabilitiesAmount(
                                liabilities == null
                                    ? '—'
                                    : formatUserMoney(
                                        liabilities.abs(),
                                        baseCurrencyCode,
                                      ),
                              ),
                              style: TextStyle(color: assetCardTextColor),
                            ),
                          ],
                        ),
                        if (oldestValuationRateDate != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).assetValuationRateTrace(
                              currencyDateKey(oldestValuationRateDate),
                              valuation.staleAccountIds.isEmpty
                                  ? ''
                                  : ' · ${AppLocalizations.of(context).exchangeRateStale}',
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: assetCardMutedColor),
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (assetTrendValues == null)
                          SizedBox(
                            height: 112,
                            child: Center(
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                ).assetTrendMissingRate,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: assetCardMutedColor),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 112,
                            child: InteractiveTrendChart(
                              color: assetCardTextColor,
                              values: assetTrendValues,
                              xLabels: evenMonthAxisLabels(),
                              labelColor: assetCardMutedColor,
                              tooltipOf: (index) => ChartTooltip(
                                title: AppLocalizations.of(
                                  context,
                                ).monthNumber(index + 1),
                                lines: <ChartTooltipLine>[
                                  ChartTooltipLine(
                                    text: AppLocalizations.of(context)
                                        .netAssetsAmount(
                                          formatUserMoney(
                                            assetTrendValues[index],
                                            baseCurrencyCode,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!valuation.isComplete) ...<Widget>[
            VeriCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.currency_exchange, color: veriWarning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppLocalizations.of(context).assetValuationMissing(
                            valuation.affectedAccountIds.length,
                          ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).assetValuationMissingDesc(
                            (valuation.missingCurrencyCodes.toList()..sort())
                                .join(', '),
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.62),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (visibleAssetSections.isEmpty) ...[
            VeriCard(
              child: EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: AppLocalizations.of(context).assetsEmptyTitle,
                description: AppLocalizations.of(context).assetsEmptyDesc,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (visibleAssetSections.isNotEmpty) ...<Widget>[
            for (final section in visibleAssetSections)
              Padding(
                key: ValueKey<String>('asset_section_${section.id}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: AccountSectionCard(
                  title: section.title,
                  accounts: section.accounts,
                  balances: balances,
                  totalText: _assetSectionTotalText(
                    accounts: section.accounts,
                    valuation: valuation,
                    baseCurrencyCode: baseCurrencyCode,
                  ),
                  collapsed: _collapsedSections.contains(
                    '${viewMode.name}:${section.id}',
                  ),
                  hapticsEnabled: controller.hapticsEnabled,
                  onToggleCollapsed: () => setState(() {
                    final key = '${viewMode.name}:${section.id}';
                    if (!_collapsedSections.add(key)) {
                      _collapsedSections.remove(key);
                    }
                  }),
                  onAccountTap: (account) {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            AccountDetailPage(account: account),
                      ),
                    );
                  },
                ),
              ),
          ],
          if (hiddenAccounts.isNotEmpty) ...<Widget>[
            VeriCard(
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => const HiddenAccountsPage(),
                  ),
                );
              },
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.42),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).hiddenAccountsCount(hiddenAccounts.length),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.52),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.36),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  void _openDisplaySettings(BuildContext context) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const AssetDisplaySettingsPage(),
        ),
      ),
    );
  }

  List<VeriMenuEntry> _assetActionMenuEntries(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <VeriMenuEntry>[
      VeriMenuItem(
        id: 'asset_add_account',
        icon: Icons.add_card_outlined,
        title: l10n.accountAdd,
        onPressed: () => unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => const AddAccountPage(),
            ),
          ),
        ),
      ),
      VeriMenuItem(
        id: 'asset_manage_groups',
        icon: Icons.folder_outlined,
        title: l10n.groupManage,
        onPressed: () => unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => const AccountGroupsPage(),
            ),
          ),
        ),
      ),
      VeriMenuItem(
        id: 'asset_display_settings',
        icon: Icons.tune_rounded,
        title: l10n.assetDisplaySettingsTitle,
        onPressed: () => _openDisplaySettings(context),
      ),
    ];
  }
}

class _AssetAccountSection {
  const _AssetAccountSection({
    required this.id,
    required this.title,
    required this.accounts,
  });

  final String id;
  final String title;
  final List<Account> accounts;
}

typedef _AssetCurrencyConverter =
    CurrencyConversionResult Function({
      required num amount,
      required String currencyCode,
      required DateTime date,
    });

List<double>? _baseCurrencyAssetTrend({
  required List<Account> accounts,
  required List<LedgerEntry> entries,
  required _AssetCurrencyConverter convert,
}) {
  final nativeSeries = <Account, List<double>>{
    for (final account in accounts)
      account: accountMonthlyBalanceSeries(account, entries),
  };
  final now = DateTime.now();
  final result = <double>[];
  for (var monthIndex = 0; monthIndex < 12; monthIndex += 1) {
    final monthEnd = DateTime(now.year, monthIndex + 2, 0);
    var total = 0.0;
    for (final account in accounts) {
      final conversion = convert(
        amount: nativeSeries[account]![monthIndex],
        currencyCode: account.currencyCode,
        date: monthEnd,
      );
      if (conversion is! ConvertedCurrencyAmount) return null;
      total += conversion.amount;
    }
    result.add(total);
  }
  return result;
}

String _assetSectionTotalText({
  required List<Account> accounts,
  required ConvertedAccountBalances valuation,
  required String baseCurrencyCode,
}) {
  var total = 0.0;
  for (final account in accounts.where((account) => account.includeInAssets)) {
    final value = valuation.amountsByAccountId[account.id];
    if (value == null) return '—';
    total += value;
  }
  return formatUserMoney(total, baseCurrencyCode);
}

class _AssetCoverPreset {
  const _AssetCoverPreset({required this.id, required this.url});

  final String id;
  final String url;

  String label(AppLocalizations l10n) {
    switch (id) {
      case 'blue_city':
        return l10n.coverBlueCity;
      case 'aurora':
        return l10n.coverAurora;
      case 'finance_office':
        return l10n.coverFinanceOffice;
      case 'deep_blue':
        return l10n.coverDeepBlue;
    }
    return id;
  }
}

String _effectiveGroupId(Account account) {
  return account.groupId ?? 'ungrouped';
}

List<Account> _sortedAccounts(Iterable<Account> accounts) {
  final sorted = accounts.toList();
  sorted.sort((a, b) {
    final hiddenCompare = (a.hidden ? 1 : 0).compareTo(b.hidden ? 1 : 0);
    if (hiddenCompare != 0) {
      return hiddenCompare;
    }
    final includeCompare = (b.includeInAssets ? 1 : 0).compareTo(
      a.includeInAssets ? 1 : 0,
    );
    if (includeCompare != 0) {
      return includeCompare;
    }
    final typeCompare = a.type.index.compareTo(b.type.index);
    if (typeCompare != 0) {
      return typeCompare;
    }
    return a.name.compareTo(b.name);
  });
  return sorted;
}
