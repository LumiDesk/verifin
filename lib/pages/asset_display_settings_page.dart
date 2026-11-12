part of 'assets_pages.dart';

class AssetDisplaySettingsPage extends StatefulWidget {
  const AssetDisplaySettingsPage({super.key});

  @override
  State<AssetDisplaySettingsPage> createState() =>
      _AssetDisplaySettingsPageState();
}

class _AssetDisplaySettingsPageState extends State<AssetDisplaySettingsPage> {
  late final AutoSave _autoSave;
  final Set<String> _collapsedSections = <String>{};
  late AssetAccountViewMode _viewMode;
  late String _coverUrl;
  late Map<AssetAccountViewMode, List<String>> _sectionOrders;
  late Map<AssetAccountViewMode, Map<String, List<String>>> _accountOrders;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    final controller = VeriFinScope.of(context);
    _autoSave = AutoSave(save: _save, logger: controller.logger);
    _viewMode = controller.assetAccountViewMode;
    _coverUrl = controller.assetCoverUrl;
    _sectionOrders = <AssetAccountViewMode, List<String>>{};
    _accountOrders = <AssetAccountViewMode, Map<String, List<String>>>{};
    for (final mode in AssetAccountViewMode.values) {
      final definitions = _baseSections(controller, mode);
      final ordered = controller.sortedAssetSections<_AssetAccountSection>(
        mode: mode,
        sections: definitions,
        idOf: (section) => section.id,
      );
      _sectionOrders[mode] = ordered.map((section) => section.id).toList();
      _accountOrders[mode] = <String, List<String>>{
        for (final section in definitions)
          section.id: controller
              .sortedAccountsForAssetSection(
                mode: mode,
                sectionId: section.id,
                accounts: section.accounts,
              )
              .map((account) => account.id)
              .toList(),
      };
      for (final section in definitions) {
        if (controller.isAssetSectionCollapsed(
          mode: mode,
          sectionId: section.id,
        )) {
          _collapsedSections.add('${mode.name}:${section.id}');
        }
      }
    }
  }

  @override
  void dispose() {
    _autoSave.dispose();
    super.dispose();
  }

  void _apply(VoidCallback update) {
    setState(update);
    _autoSave.schedule(immediate: true);
  }

  List<_AssetAccountSection> _baseSections(
    VeriFinController controller,
    AssetAccountViewMode mode,
  ) {
    final accounts = controller.accounts
        .where((account) => !account.hidden)
        .toList();
    if (mode == AssetAccountViewMode.group) {
      final groups = <AccountGroup>[
        ...controller.accountGroups,
        AccountGroup(
          id: 'ungrouped',
          bookId: controller.activeBook.id,
          name: AppLocalizations.of(context).assetsUngrouped,
          sortOrder: 999,
        ),
      ];
      return <_AssetAccountSection>[
        for (final group in groups)
          _AssetAccountSection(
            id: group.id,
            title: group.name,
            accounts: accounts
                .where((account) => _effectiveGroupId(account) == group.id)
                .toList(),
          ),
      ];
    }
    return <_AssetAccountSection>[
      for (final type in AccountType.values)
        _AssetAccountSection(
          id: type.name,
          title: type.label(AppLocalizations.of(context)),
          accounts: accounts.where((account) => account.type == type).toList(),
        ),
    ];
  }

  List<_AssetAccountSection> _visibleSections(VeriFinController controller) {
    final definitions = _baseSections(controller, _viewMode);
    final byId = <String, _AssetAccountSection>{
      for (final section in definitions) section.id: section,
    };
    return <_AssetAccountSection>[
      for (final id in _sectionOrders[_viewMode]!)
        if (byId[id] case final _AssetAccountSection definition)
          if (definition.accounts.isNotEmpty)
            _AssetAccountSection(
              id: definition.id,
              title: definition.title,
              accounts: _orderedAccounts(definition),
            ),
    ];
  }

  List<Account> _orderedAccounts(_AssetAccountSection definition) {
    final byId = <String, Account>{
      for (final account in definition.accounts) account.id: account,
    };
    final result = <Account>[
      for (final id in _accountOrders[_viewMode]![definition.id]!)
        if (byId.remove(id) case final Account account) account,
    ];
    result.addAll(byId.values);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final sections = _visibleSections(controller);
    final balances = <Account, double>{
      for (final account in controller.accounts)
        account: controller.accountBalance(account),
    };
    final valuation = controller.accountBalancesInBase(
      accounts: controller.accounts.where(
        (account) => account.includeInAssets && !account.hidden,
      ),
    );

    return AutoSavePopScope(
      autoSave: _autoSave,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: l10n.assetDisplaySettingsTitle,
                  showBack: true,
                ),
                const SizedBox(height: 10),
                AutoSaveFailureBanner(autoSave: _autoSave),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      AnchoredMenuAnchor(
                        entries: _viewModeMenuEntries(l10n),
                        semanticLabel: l10n.assetViewModeLabel,
                        builder: (context, openMenu, menuOpen) => SelectField(
                          label: l10n.assetViewModeLabel,
                          value: _viewMode.label(l10n),
                          icon: Icons.view_agenda_outlined,
                          onTap: openMenu,
                        ),
                      ),
                      AnchoredMenuAnchor(
                        entries: _coverMenuEntries(l10n),
                        semanticLabel: l10n.assetsCoverTitle,
                        builder: (context, openMenu, menuOpen) => SettingsRow(
                          icon: Icons.photo_size_select_actual_outlined,
                          title: l10n.assetsCoverTitle,
                          trailing: _coverUrl.isEmpty
                              ? l10n.notSet
                              : l10n.configuredLabel,
                          trailingIcon: Icons.keyboard_arrow_down,
                          onTap: openMenu,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    l10n.assetOrderHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (sections.isEmpty)
                  VeriCard(
                    child: EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: l10n.assetsEmptyTitle,
                      description: l10n.assetsEmptyDesc,
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: sections.length,
                    onReorderItem: _reorderSections,
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      return Padding(
                        key: ValueKey<String>('asset_setting_${section.id}'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AccountSectionCard(
                          title: section.title,
                          accounts: section.accounts,
                          balances: balances,
                          totalText: _assetSectionTotalText(
                            accounts: section.accounts,
                            valuation: valuation,
                            baseCurrencyCode:
                                controller.activeBook.baseCurrencyCode,
                          ),
                          collapsed: _collapsedSections.contains(
                            '${_viewMode.name}:${section.id}',
                          ),
                          sectionDragIndex: index,
                          sectionDragImmediate: true,
                          hapticsEnabled: controller.hapticsEnabled,
                          onToggleCollapsed: () => _apply(() {
                            final key = '${_viewMode.name}:${section.id}';
                            if (!_collapsedSections.add(key)) {
                              _collapsedSections.remove(key);
                            }
                          }),
                          onReorderAccounts: (oldIndex, newIndex) =>
                              _reorderAccounts(section.id, oldIndex, newIndex),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<AnchoredMenuEntry> _viewModeMenuEntries(AppLocalizations l10n) {
    return <AnchoredMenuEntry>[
      for (final mode in AssetAccountViewMode.values)
        AnchoredMenuItem(
          id: 'asset_view_${mode.name}',
          icon: switch (mode) {
            AssetAccountViewMode.group => Icons.folder_outlined,
            AssetAccountViewMode.type => Icons.account_balance_wallet_outlined,
          },
          title: mode.label(l10n),
          selected: _viewMode == mode,
          onPressed: () => _selectViewMode(mode),
        ),
    ];
  }

  void _selectViewMode(AssetAccountViewMode mode) {
    if (_viewMode == mode) return;
    _apply(() {
      _viewMode = mode;
      _collapsedSections.clear();
    });
  }

  void _reorderSections(int oldIndex, int newIndex) {
    final visible = _visibleSections(VeriFinScope.of(context));
    if (oldIndex < 0 ||
        oldIndex >= visible.length ||
        newIndex < 0 ||
        newIndex > visible.length) {
      return;
    }
    _apply(() {
      final visibleIds = visible.map((section) => section.id).toList();
      final moved = visibleIds.removeAt(oldIndex);
      visibleIds.insert(newIndex.clamp(0, visibleIds.length), moved);
      var visibleIndex = 0;
      final all = _sectionOrders[_viewMode]!;
      for (var index = 0; index < all.length; index++) {
        if (visible.any((section) => section.id == all[index])) {
          all[index] = visibleIds[visibleIndex++];
        }
      }
    });
  }

  void _reorderAccounts(String sectionId, int oldIndex, int newIndex) {
    final order = _accountOrders[_viewMode]![sectionId]!;
    if (oldIndex < 0 ||
        oldIndex >= order.length ||
        newIndex < 0 ||
        newIndex >= order.length) {
      return;
    }
    _apply(() {
      final moved = order.removeAt(oldIndex);
      order.insert(newIndex, moved);
    });
  }

  List<AnchoredMenuEntry> _coverMenuEntries(AppLocalizations l10n) {
    return <AnchoredMenuEntry>[
      AnchoredMenuItem(
        id: 'asset_cover_online',
        icon: Icons.public_outlined,
        title: l10n.coverUseOnline,
        children: <AnchoredMenuEntry>[
          for (final preset in _AssetsPageState._coverPresets)
            AnchoredMenuItem(
              id: 'asset_cover_preset_${preset.id}',
              title: preset.label(l10n),
              selected: preset.url == _coverUrl,
              onPressed: () => _apply(() => _coverUrl = preset.url),
            ),
        ],
      ),
      AnchoredMenuItem(
        id: 'asset_cover_custom_url',
        icon: Icons.link_outlined,
        title: l10n.coverEnterUrl,
        onPressed: () async => _enterCustomCoverUrl(),
      ),
      AnchoredMenuItem(
        id: 'asset_cover_local',
        icon: Icons.photo_library_outlined,
        title: l10n.coverPickLocal,
        onPressed: () async => _pickLocalCover(),
      ),
      const AnchoredMenuDivider(),
      AnchoredMenuItem(
        id: 'asset_cover_clear',
        icon: Icons.hide_image_outlined,
        title: l10n.coverClear,
        enabled: _coverUrl.isNotEmpty,
        foregroundColor: Theme.of(context).colorScheme.error,
        onPressed: () => _apply(() => _coverUrl = ''),
      ),
    ];
  }

  Future<void> _enterCustomCoverUrl() async {
    final l10n = AppLocalizations.of(context);
    final url = await showTextInputDialog(
      context: context,
      title: l10n.coverCustomTitle,
      label: l10n.coverUrlLabel,
      initialValue: _coverUrl.startsWith('http') ? _coverUrl : '',
    );
    if (url != null && mounted) {
      _apply(() => _coverUrl = url);
    }
  }

  Future<void> _pickLocalCover() async {
    final l10n = AppLocalizations.of(context);
    final rawImage = await pickRawImageDataUrl();
    if (rawImage == null || !mounted) {
      return;
    }
    final crop = await showImageCropper(
      context: context,
      imageDataUrl: rawImage,
      title: l10n.coverCropTitle,
      aspectRatio: assetCoverAspectRatio,
    );
    if (crop == null || !mounted) {
      return;
    }
    final dataUrl = await runWithLoadingDialog<String?>(
      context: context,
      message: l10n.coverGenerating,
      task: () => cropImageDataUrl(
        sourceDataUrl: rawImage,
        targetWidth: assetCoverTargetWidth,
        targetHeight: assetCoverTargetHeight,
        zoom: crop.zoom,
        offsetX: crop.offsetX,
        offsetY: crop.offsetY,
      ),
    );
    if (dataUrl != null && mounted) {
      _apply(() => _coverUrl = dataUrl);
    }
  }

  Future<bool> _save() => VeriFinScope.of(context).saveAssetDisplayDraft(
    viewMode: _viewMode,
    coverUrl: _coverUrl,
    sectionOrders: _sectionOrders,
    accountOrders: _accountOrders,
    collapsedSections: _collapsedSections,
  );
}
