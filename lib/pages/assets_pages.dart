import 'dart:async';

import 'package:anchored_menu/anchored_menu.dart';
import 'package:flutter/material.dart';

import '../app/account_icon_assets.dart';
import '../app/app_theme.dart';
import '../app/auto_save.dart';
import '../app/avatar_picker.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/currency_catalog.dart';
import '../app/currency_math.dart';
import '../app/haptics.dart';
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
import 'currency_rates_page.dart';

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
    final assetTrend = _baseCurrencyAssetTrend(
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
    // 单币种账本按偏好隐藏单位时整条副标题省略，不留「本位币 」这种残句。
    final baseUnit = optionalCurrencyUnit(baseCurrencyCode);
    return VeriPage(
      child: ListView(
        padding: veriRootPageListPadding(context),
        children: <Widget>[
          PageHeader(
            title: AppLocalizations.of(context).tabAssets,
            subtitle: baseUnit == null
                ? null
                : AppLocalizations.of(
                    context,
                  ).baseCurrencyAmountLabel(baseUnit),
            trailing: AnchoredMenuButton(
              icon: Icons.add,
              tooltip: AppLocalizations.of(context).assetsActions,
              entries: _assetActionMenuEntries(context),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('asset_cover_card'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: hasAssetCover
                  ? null
                  : veriContentSurfaceColor(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(veriCardRadius),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.045),
              ),
              image: !hasAssetCover
                  ? null
                  : DecorationImage(
                      image: imageProviderForSource(controller.assetCoverUrl),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
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
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).assetsAmount(
                                assets == null
                                    ? '—'
                                    : formatUserMoney(assets, baseCurrencyCode),
                              ),
                              style: TextStyle(color: assetCardTextColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).liabilitiesAmount(
                                liabilities == null
                                    ? '—'
                                    : formatUserMoney(
                                        liabilities.abs(),
                                        baseCurrencyCode,
                                      ),
                              ),
                              style: TextStyle(color: assetCardTextColor),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (oldestValuationRateDate != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).assetValuationRateTrace(
                            // 用年月而不是「月日」：估值汇率可能跨年，年份是判断
                            // 是否过期的关键信息。
                            AppLocalizations.of(
                              context,
                            ).yearMonth(oldestValuationRateDate),
                            valuation.staleAccountIds.isEmpty
                                ? ''
                                : ' · ${AppLocalizations.of(context).exchangeRateStale}',
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: assetCardMutedColor),
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (assetTrend.hasNoData)
                        SizedBox(
                          height: 112,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).assetTrendMissingRate,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: assetCardMutedColor),
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: () => _openCurrencyRates(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: assetCardTextColor,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).exchangeRateSetAction,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 112,
                          child: InteractiveTrendChart(
                            color: assetCardTextColor,
                            values: assetTrend.values,
                            missingIndexes: assetTrend.missingIndexes,
                            xLabels: yearMonthAxisLabels(),
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
                                          assetTrend.values[index],
                                          baseCurrencyCode,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (assetTrend.missingIndexes.isNotEmpty &&
                          !assetTrend.hasNoData) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                ).assetTrendPartialMissing(
                                  (assetTrend.missingCurrencyCodes.toList()
                                        ..sort())
                                      .join(', '),
                                  assetTrend.missingIndexes
                                      .map(
                                        (index) => AppLocalizations.of(
                                          context,
                                        ).monthNumber(index + 1),
                                      )
                                      .join('、'),
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: assetCardMutedColor),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openCurrencyRates(context),
                              style: TextButton.styleFrom(
                                foregroundColor: assetCardTextColor,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                ).exchangeRateSetAction,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!valuation.isComplete) ...<Widget>[
            VeriCard(
              // 只告知「缺汇率」而不给入口，用户没有任何可操作的去处。
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const CurrencyRatesPage(),
                ),
              ),
              // 点击区在外层卡片，提示本体不再自带点击。
              child: AssetMissingRateNotice(
                affectedAccountCount: valuation.affectedAccountIds.length,
                currencyCodes: valuation.missingCurrencyCodes,
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
                // 空状态只说明原因不给出口，用户会卡在死路上。
                action: FilledButton.icon(
                  onPressed: () => unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const AddAccountPage(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    AppLocalizations.of(context).assetsEmptyAddAction,
                  ),
                ),
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
                  collapsed: controller.isAssetSectionCollapsed(
                    mode: viewMode,
                    sectionId: section.id,
                  ),
                  onToggleCollapsed: () =>
                      controller.toggleAssetSectionCollapsed(
                        mode: viewMode,
                        sectionId: section.id,
                      ),
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

  List<AnchoredMenuEntry> _assetActionMenuEntries(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <AnchoredMenuEntry>[
      AnchoredMenuItem(
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
      AnchoredMenuItem(
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
      AnchoredMenuItem(
        id: 'asset_display_settings',
        icon: Icons.tune_rounded,
        title: l10n.assetDisplaySettingsTitle,
        onPressed: () => _openDisplaySettings(context),
      ),
    ];
  }
}

void _openCurrencyRates(BuildContext context) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CurrencyRatesPage()),
    ),
  );
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

class _AssetTrendData {
  const _AssetTrendData({
    required this.values,
    required this.missingIndexes,
    required this.missingCurrencyCodes,
  });

  final List<double> values;
  final Set<int> missingIndexes;
  final Set<String> missingCurrencyCodes;

  bool get hasNoData => missingIndexes.length == values.length;
}

_AssetTrendData _baseCurrencyAssetTrend({
  required List<Account> accounts,
  required List<LedgerEntry> entries,
  required _AssetCurrencyConverter convert,
}) {
  final nativeSeries = accountMonthlyBalanceSeriesBatch(accounts, entries);
  final now = DateTime.now();
  final result = List<double>.filled(12, 0);
  final missingIndexes = <int>{};
  final missingCurrencyCodes = <String>{};
  for (var monthIndex = 0; monthIndex < 12; monthIndex += 1) {
    final monthEnd = DateTime(now.year, monthIndex + 2, 0);
    var total = 0.0;
    var complete = true;
    for (final account in accounts) {
      final nativeBalance = nativeSeries[account.id]![monthIndex];
      // 零余额不需要汇率：任何币种的 0 折算后仍是 0。这里与
      // convertAccountBalancesToBase 的零余额口径保持一致，避免新加的空外币账户
      // 把整条历史走势误判为缺率。
      if (isZeroCurrencyAmount(nativeBalance, account.currencyCode)) {
        continue;
      }
      final conversion = convert(
        amount: nativeBalance,
        currencyCode: account.currencyCode,
        date: monthEnd,
      );
      if (conversion is ConvertedCurrencyAmount) {
        total += conversion.amount;
      } else {
        complete = false;
        if (conversion is MissingCurrencyRate) {
          missingCurrencyCodes.addAll(conversion.currencyCodes);
        }
      }
    }
    if (complete) {
      result[monthIndex] = total;
    } else {
      missingIndexes.add(monthIndex);
    }
  }
  return _AssetTrendData(
    values: result,
    missingIndexes: missingIndexes,
    missingCurrencyCodes: missingCurrencyCodes,
  );
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
