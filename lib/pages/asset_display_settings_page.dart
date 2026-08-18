part of 'assets_pages.dart';

class AssetDisplaySettingsPage extends StatefulWidget {
  const AssetDisplaySettingsPage({super.key});

  @override
  State<AssetDisplaySettingsPage> createState() =>
      _AssetDisplaySettingsPageState();
}

class _AssetDisplaySettingsPageState extends State<AssetDisplaySettingsPage> {
  final EditorExitController _exitController = EditorExitController();
  final Set<String> _collapsedSections = <String>{};
  late AssetAccountViewMode _viewMode;
  late String _coverUrl;
  late Map<AssetAccountViewMode, List<String>> _sectionOrders;
  late Map<AssetAccountViewMode, Map<String, List<String>>> _accountOrders;
  late String _initialFingerprint;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    final controller = VeriFinScope.of(context);
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
    }
    _initialFingerprint = _fingerprint;
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
          iconCode: 'folder',
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

  String get _fingerprint => jsonEncode(<String, Object?>{
    'viewMode': _viewMode.name,
    'coverUrl': _coverUrl.trim(),
    'sectionOrders': <String, Object?>{
      for (final entry in _sectionOrders.entries) entry.key.name: entry.value,
    },
    'accountOrders': <String, Object?>{
      for (final modeEntry in _accountOrders.entries)
        modeEntry.key.name: <String, Object?>{
          for (final sectionEntry in modeEntry.value.entries)
            sectionEntry.key: sectionEntry.value,
        },
    },
  });

  bool get _isDirty => _initialized && _fingerprint != _initialFingerprint;

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

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      exitController: _exitController,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: l10n.assetDisplaySettingsTitle,
                  showBack: true,
                  actions: <Widget>[
                    SaveHeaderAction(onPressed: _isDirty ? _saveAndExit : null),
                  ],
                ),
                const SizedBox(height: 10),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      SelectField(
                        label: l10n.assetViewModeLabel,
                        value: _viewMode.label(l10n),
                        icon: Icons.view_agenda_outlined,
                        onTap: _pickViewMode,
                      ),
                      SettingsRow(
                        icon: Icons.photo_size_select_actual_outlined,
                        title: l10n.assetsCoverTitle,
                        trailing: _coverUrl.isEmpty
                            ? l10n.notSet
                            : l10n.configuredLabel,
                        onTap: _changeCover,
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
                        child: AccountGroupCard(
                          title: section.title,
                          accounts: section.accounts,
                          balances: balances,
                          totalText: _assetSectionTotalText(
                            accounts: section.accounts,
                            valuation: valuation,
                            baseCurrencyCode:
                                controller.activeBook.baseCurrencyCode,
                          ),
                          collapsed: _collapsedSections.contains(section.id),
                          sectionDragIndex: index,
                          sectionDragImmediate: true,
                          hapticsEnabled: controller.hapticsEnabled,
                          onToggleCollapsed: () => setState(() {
                            if (!_collapsedSections.add(section.id)) {
                              _collapsedSections.remove(section.id);
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

  Future<void> _pickViewMode() async {
    final selected = await showOptionSheet<AssetAccountViewMode>(
      context: context,
      title: AppLocalizations.of(context).assetViewModeLabel,
      values: AssetAccountViewMode.values,
      selected: _viewMode,
      labelOf: (mode) => mode.label(AppLocalizations.of(context)),
    );
    if (selected != null && mounted) {
      setState(() {
        _viewMode = selected;
        _collapsedSections.clear();
      });
    }
  }

  void _reorderSections(int oldIndex, int newIndex) {
    final visible = _visibleSections(VeriFinScope.of(context));
    if (oldIndex < 0 ||
        oldIndex >= visible.length ||
        newIndex < 0 ||
        newIndex > visible.length) {
      return;
    }
    setState(() {
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
    setState(() {
      final moved = order.removeAt(oldIndex);
      order.insert(newIndex, moved);
    });
  }

  Future<void> _changeCover() async {
    final l10n = AppLocalizations.of(context);
    final action = await showOptionSheet<String>(
      context: context,
      title: l10n.assetsCoverTitle,
      values: const <String>['online', 'custom_url', 'local', 'clear'],
      selected: 'online',
      labelOf: (value) => switch (value) {
        'online' => l10n.coverUseOnline,
        'custom_url' => l10n.coverEnterUrl,
        'local' => l10n.coverPickLocal,
        'clear' => l10n.coverClear,
        _ => value,
      },
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case 'online':
        final presets = _AssetsPageState._coverPresets;
        final selected = await showOptionSheet<_AssetCoverPreset>(
          context: context,
          title: l10n.coverPickOnlineTitle,
          values: presets,
          selected: presets.firstWhere(
            (item) => item.url == _coverUrl,
            orElse: () => presets.first,
          ),
          labelOf: (value) => value.label(l10n),
        );
        if (selected != null && mounted) {
          setState(() => _coverUrl = selected.url);
        }
      case 'custom_url':
        final url = await showTextInputDialog(
          context: context,
          title: l10n.coverCustomTitle,
          label: l10n.coverUrlLabel,
          initialValue: _coverUrl.startsWith('http') ? _coverUrl : '',
        );
        if (url != null && mounted) {
          setState(() => _coverUrl = url);
        }
      case 'local':
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
          setState(() => _coverUrl = dataUrl);
        }
      case 'clear':
        setState(() => _coverUrl = '');
    }
  }

  Future<bool> _save() async {
    if (_saving) {
      return false;
    }
    _saving = true;
    final saved = await VeriFinScope.of(context).saveAssetDisplayDraft(
      viewMode: _viewMode,
      coverUrl: _coverUrl,
      sectionOrders: _sectionOrders,
      accountOrders: _accountOrders,
    );
    if (mounted) {
      _saving = false;
    }
    return saved;
  }

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(() => _initialFingerprint = _fingerprint);
      _exitController.exit();
    }
  }
}
