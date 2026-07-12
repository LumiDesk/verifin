import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/account_icon_assets.dart';
import '../app/app_theme.dart';
import '../app/avatar_picker.dart';
import '../app/chart_painters.dart';
import '../app/common_widgets.dart';
import '../app/icon_catalog.dart';
import '../app/image_cropper.dart';
import '../app/image_sources.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/series_math.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';
import 'account_detail_page.dart';

part 'account_group_pages.dart';
part 'add_account_page.dart';

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

  bool _sortingSections = false;
  // 当前可见分组数，供「资产操作」菜单里的「排序分组」判断能否进入排序模式
  // （<2 个分组无从排序）。在 build 中同步。
  int _visibleSectionCount = 0;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final accounts = _sortedAccounts(controller.accounts);
    final groups = controller.accountGroups;
    final balances = <Account, double>{
      for (final account in accounts)
        account: controller.accountBalance(account),
    };
    final assetBalances = balances.entries
        .where((entry) => entry.key.includeInAssets && !entry.key.hidden)
        .map((entry) => entry.value);
    final assets = assetBalances
        .where((value) => value > 0)
        .fold<double>(0, (sum, value) => sum + value);
    final liabilities = assetBalances
        .where((value) => value < 0)
        .fold<double>(0, (sum, value) => sum + value);
    final assetTrendValues = monthlyNetAssetSeries(
      accounts,
      controller.entries,
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
        iconCode: 'folder',
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
    final canSortSections = visibleAssetSections.length >= 2;
    final sortingSections = _sortingSections && canSortSections;
    _visibleSectionCount = visibleAssetSections.length;

    return VeriPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 82),
        children: <Widget>[
          PageHeader(
            title: AppLocalizations.of(context).tabAssets,
            subtitle: AppLocalizations.of(context).netAssets,
            trailing: HeaderAction(
              icon: Icons.add,
              tooltip: AppLocalizations.of(context).assetsActions,
              onPressed: () => _showAssetActions(context),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('asset_cover_card'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: hasAssetCover
                  ? null
                  : Theme.of(context).brightness == Brightness.dark
                  ? veriSurfaceDark
                  : veriSurfaceLight,
              borderRadius: BorderRadius.circular(veriRadiusMd),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
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
                if (Theme.of(context).brightness == Brightness.light)
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
                            onPressed: () =>
                                _changeAssetCover(context, controller),
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
                        formatAmount(assets + liabilities),
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
                            AppLocalizations.of(
                              context,
                            ).assetsAmount(formatAmount(assets)),
                            style: TextStyle(color: assetCardTextColor),
                          ),
                          Text(
                            AppLocalizations.of(context).liabilitiesAmount(
                              formatAmount(liabilities.abs()),
                            ),
                            style: TextStyle(color: assetCardTextColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
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
                                      formatAmount(assetTrendValues[index]),
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
          const SizedBox(height: 12),
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
            // 「排序」按钮常驻分组列表上方（就算只有 1 个分组也显示，保证可发现，
            // 点击时不足 2 个分组会提示）；「资产操作」菜单里保留同一入口。
            // 进入排序模式后变为提示 + 「完成」。
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: sortingSections
                        ? Text(
                            AppLocalizations.of(context).assetsSortHint,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.52),
                                  fontWeight: FontWeight.w700,
                                ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  _SectionSortButton(
                    sorting: sortingSections,
                    onTap: sortingSections
                        ? () => setState(() => _sortingSections = false)
                        : () => _enterSectionSorting(context),
                  ),
                ],
              ),
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              proxyDecorator: (_, index, _) {
                final section = visibleAssetSections[index];
                return Material(
                  color: Colors.transparent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(veriRadiusMd),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: AccountGroupCard(
                      title: section.title,
                      accounts: section.accounts,
                      balances: balances,
                      collapsed: true,
                      sectionDragIndex: index,
                      hapticsEnabled: controller.hapticsEnabled,
                    ),
                  ),
                );
              },
              onReorderStart: (_) => _triggerSelectionHaptic(controller),
              onReorderEnd: (_) => _triggerSelectionHaptic(controller),
              onReorderItem: (oldIndex, newIndex) {
                _triggerSelectionHaptic(controller);
                controller.reorderAssetSections<_AssetAccountSection>(
                  mode: viewMode,
                  sections: visibleAssetSections,
                  idOf: (section) => section.id,
                  oldIndex: oldIndex,
                  newIndex: newIndex,
                );
              },
              itemCount: visibleAssetSections.length,
              itemBuilder: (context, index) {
                final section = visibleAssetSections[index];
                return Padding(
                  key: ValueKey<String>('asset_section_${section.id}'),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AccountGroupCard(
                    title: section.title,
                    accounts: section.accounts,
                    balances: balances,
                    collapsed:
                        sortingSections ||
                        controller.isAssetSectionCollapsed(
                          mode: viewMode,
                          sectionId: section.id,
                        ),
                    sectionDragIndex: sortingSections ? index : null,
                    sectionDragImmediate: true,
                    hapticsEnabled: controller.hapticsEnabled,
                    onToggleCollapsed: sortingSections
                        ? null
                        : () => controller.toggleAssetSectionCollapsed(
                            mode: viewMode,
                            sectionId: section.id,
                          ),
                    onReorderAccounts: (oldIndex, newIndex) =>
                        controller.reorderAssetAccounts(
                          mode: viewMode,
                          sectionId: section.id,
                          accounts: section.accounts,
                          oldIndex: oldIndex,
                          newIndex: newIndex,
                        ),
                    onAccountTap: sortingSections
                        ? null
                        : (account) {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    AccountDetailPage(account: account),
                              ),
                            );
                          },
                  ),
                );
              },
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

  void _triggerSelectionHaptic(VeriFinController controller) {
    if (controller.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _changeAssetCover(
    BuildContext context,
    VeriFinController controller,
  ) async {
    final action = await showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).assetsCoverTitle,
      values: const <String>['online', 'custom_url', 'local', 'clear'],
      selected: 'online',
      labelOf: (value) {
        return switch (value) {
          'online' => AppLocalizations.of(context).coverUseOnline,
          'custom_url' => AppLocalizations.of(context).coverEnterUrl,
          'local' => AppLocalizations.of(context).coverPickLocal,
          'clear' => AppLocalizations.of(context).coverClear,
          _ => value,
        };
      },
    );
    if (action == null || !context.mounted) {
      return;
    }

    switch (action) {
      case 'online':
        final selected = await showOptionSheet<_AssetCoverPreset>(
          context: context,
          title: AppLocalizations.of(context).coverPickOnlineTitle,
          values: _coverPresets,
          selected: _coverPresets.firstWhere(
            (item) => item.url == controller.assetCoverUrl,
            orElse: () => _coverPresets.first,
          ),
          labelOf: (value) => value.label(AppLocalizations.of(context)),
        );
        if (selected != null) {
          controller.setAssetCoverUrl(selected.url);
        }
      case 'custom_url':
        final url = await showTextInputDialog(
          context: context,
          title: AppLocalizations.of(context).coverCustomTitle,
          label: AppLocalizations.of(context).coverUrlLabel,
          initialValue: controller.assetCoverUrl.startsWith('http')
              ? controller.assetCoverUrl
              : '',
        );
        if (url != null) {
          controller.setAssetCoverUrl(url);
        }
      case 'local':
        final rawImage = await pickRawImageDataUrl();
        if (rawImage == null || !context.mounted) {
          return;
        }
        final crop = await showImageCropper(
          context: context,
          imageDataUrl: rawImage,
          title: AppLocalizations.of(context).coverCropTitle,
          aspectRatio: assetCoverAspectRatio,
        );
        if (crop == null || !context.mounted) {
          return;
        }
        final dataUrl = await runWithLoadingDialog<String?>(
          context: context,
          message: AppLocalizations.of(context).coverGenerating,
          task: () => cropImageDataUrl(
            sourceDataUrl: rawImage,
            targetWidth: assetCoverTargetWidth,
            targetHeight: assetCoverTargetHeight,
            zoom: crop.zoom,
            offsetX: crop.offsetX,
            offsetY: crop.offsetY,
          ),
        );
        if (dataUrl != null) {
          controller.setAssetCoverUrl(dataUrl);
        }
      case 'clear':
        controller.setAssetCoverUrl('');
    }
  }

  Future<void> _showAssetActions(BuildContext context) async {
    final controller = VeriFinScope.of(context);
    final selected = await showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).assetsActions,
      values: const <String>[
        'add_account',
        'manage_groups',
        'switch_view',
        'sort_sections',
      ],
      selected: 'add_account',
      labelOf: (value) {
        return switch (value) {
          'add_account' => AppLocalizations.of(context).accountAdd,
          'manage_groups' => AppLocalizations.of(context).groupManage,
          'switch_view' => controller.assetAccountViewMode.toggleLabel(
            AppLocalizations.of(context),
          ),
          'sort_sections' => AppLocalizations.of(context).sectionSort,
          _ => value,
        };
      },
    );
    if (selected == null || !context.mounted) {
      return;
    }
    if (selected == 'add_account') {
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (context) => const AddAccountPage()),
        ),
      );
    }
    if (selected == 'manage_groups') {
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => const AccountGroupsPage(),
          ),
        ),
      );
    }
    if (selected == 'switch_view') {
      controller.toggleAssetAccountViewMode();
    }
    if (selected == 'sort_sections') {
      _enterSectionSorting(context);
    }
  }

  void _enterSectionSorting(BuildContext context) {
    if (_visibleSectionCount >= 2) {
      setState(() => _sortingSections = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).sectionSortNeedTwo),
        ),
      );
    }
  }
}

class _SectionSortButton extends StatelessWidget {
  const _SectionSortButton({required this.sorting, required this.onTap});

  final bool sorting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(sorting ? Icons.check : Icons.swap_vert, size: 16),
      label: Text(
        sorting
            ? AppLocalizations.of(context).commonDone
            : AppLocalizations.of(context).sortLabel,
      ),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: sorting
            ? veriRoyal
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        textStyle: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
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
