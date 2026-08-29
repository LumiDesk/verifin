part of 'assets_pages.dart';

class HiddenAccountsPage extends StatelessWidget {
  const HiddenAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final accounts = controller.accounts
        .where((account) => account.hidden)
        .toList(growable: false);
    final balances = <Account, double>{
      for (final account in accounts)
        account: controller.accountBalance(account),
    };

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).hiddenAccountsTitle,
                showBack: true,
              ),
              const SizedBox(height: 10),
              if (accounts.isEmpty)
                VeriCard(
                  child: EmptyState(
                    icon: Icons.visibility_off_outlined,
                    title: AppLocalizations.of(
                      context,
                    ).hiddenAccountsEmptyTitle,
                    description: AppLocalizations.of(
                      context,
                    ).hiddenAccountsEmptyDesc,
                  ),
                )
              else
                AccountSectionCard(
                  title: AppLocalizations.of(context).hiddenAccountsTitle,
                  accounts: _sortedAccounts(accounts),
                  balances: balances,
                  onAccountTap: (account) {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            AccountDetailPage(account: account),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountGroupsPage extends StatefulWidget {
  const AccountGroupsPage({super.key});

  @override
  State<AccountGroupsPage> createState() => _AccountGroupsPageState();
}

class _AccountGroupsPageState extends State<AccountGroupsPage> {
  bool _sorting = false;
  bool _savingOrder = false;
  List<AccountGroup> _draftGroups = <AccountGroup>[];
  List<String> _initialOrder = <String>[];

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final groups = _sorting ? _draftGroups : controller.accountGroups;
    final accounts = controller.accounts;

    return UnsavedChangesGuard(
      isDirty: _isOrderDirty,
      onSave: _saveOrder,
      onDiscard: _discardOrder,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: VeriHeader(
                    title: AppLocalizations.of(context).accountGroupsTitle,
                    showBack: true,
                    actions: <Widget>[
                      if (!_sorting)
                        HeaderAction(
                          icon: Icons.add,
                          tooltip: AppLocalizations.of(context).groupAdd,
                          onPressed: () => _showGroupNameDialog(context),
                        ),
                      SortModeHeaderActions(
                        sorting: _sorting,
                        canSort: groups.length >= 2,
                        dirty: _isOrderDirty,
                        onStart: () => _startSorting(controller),
                        onCancel: _cancelSorting,
                        onSave: _saveOrderAndFinish,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: groups.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 86),
                          children: <Widget>[
                            VeriCard(
                              child: EmptyState(
                                icon: Icons.folder_open_outlined,
                                title: AppLocalizations.of(
                                  context,
                                ).groupsEmptyTitle,
                                description: AppLocalizations.of(
                                  context,
                                ).groupsEmptyDesc,
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 86),
                          children: <Widget>[
                            VeriCard(
                              padding: EdgeInsets.zero,
                              child: ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                buildDefaultDragHandles: false,
                                itemCount: groups.length,
                                onReorderItem: _reorderDraft,
                                itemBuilder: (context, index) {
                                  final group = groups[index];
                                  final accountCount = accounts
                                      .where(
                                        (account) =>
                                            _effectiveGroupId(account) ==
                                            group.id,
                                      )
                                      .length;
                                  final Widget row;
                                  if (_sorting) {
                                    row = _AccountGroupManageRow(
                                      index: index,
                                      group: group,
                                      accountCount: accountCount,
                                      sorting: true,
                                    );
                                  } else {
                                    row = VeriAnchoredMenuAnchor(
                                      entries: _groupMenuEntries(
                                        group,
                                        accountCount,
                                      ),
                                      semanticLabel: group.name,
                                      width: 188,
                                      builder: (context, openMenu, menuOpen) =>
                                          _AccountGroupManageRow(
                                            index: index,
                                            group: group,
                                            accountCount: accountCount,
                                            sorting: false,
                                            onTap: openMenu,
                                            onActions: openMenu,
                                          ),
                                    );
                                  }
                                  return Column(
                                    key: ValueKey(group.id),
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      row,
                                      if (index < groups.length - 1)
                                        const Divider(height: 1),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _isOrderDirty =>
      _sorting &&
      !listEquals(
        _draftGroups.map((group) => group.id).toList(),
        _initialOrder,
      );

  void _startSorting(VeriFinController controller) {
    setState(() {
      _sorting = true;
      _draftGroups = List<AccountGroup>.of(controller.accountGroups);
      _initialOrder = _draftGroups.map((group) => group.id).toList();
    });
  }

  void _reorderDraft(int oldIndex, int newIndex) {
    if (!_sorting ||
        oldIndex < 0 ||
        oldIndex >= _draftGroups.length ||
        newIndex < 0 ||
        newIndex > _draftGroups.length) {
      return;
    }
    setState(() {
      final moved = _draftGroups.removeAt(oldIndex);
      _draftGroups.insert(newIndex.clamp(0, _draftGroups.length), moved);
    });
  }

  Future<bool> _saveOrder() async {
    if (_savingOrder || !_isOrderDirty) {
      return !_isOrderDirty;
    }
    _savingOrder = true;
    final saved = await VeriFinScope.of(context).saveAccountGroupOrderDraft(
      _draftGroups.map((group) => group.id).toList(),
    );
    _savingOrder = false;
    return saved;
  }

  Future<void> _saveOrderAndFinish() async {
    if (await _saveOrder() && mounted) {
      setState(_discardOrder);
    }
  }

  void _discardOrder() {
    _sorting = false;
    _draftGroups = <AccountGroup>[];
    _initialOrder = <String>[];
  }

  Future<void> _cancelSorting() async {
    if (!_isOrderDirty) {
      setState(_discardOrder);
      return;
    }
    final decision = await showUnsavedChangesDialog(context: context);
    if (!mounted) {
      return;
    }
    switch (decision) {
      case EditorExitDecision.save:
        await _saveOrderAndFinish();
      case EditorExitDecision.discard:
        setState(_discardOrder);
      case EditorExitDecision.cancel:
        break;
    }
  }

  Future<void> _showGroupNameDialog(
    BuildContext context, {
    String? groupId,
  }) async {
    final controller = VeriFinScope.of(context);
    final editingGroup = groupId == null
        ? null
        : controller.accountGroups.firstWhere((group) => group.id == groupId);
    final l10n = AppLocalizations.of(context);
    final name = await showTextInputDialog(
      context: context,
      title: groupId == null ? l10n.groupAdd : l10n.groupRenameTitle,
      label: l10n.groupNameLabel,
      initialValue: editingGroup?.name ?? '',
    );
    if (!context.mounted || name == null) {
      return;
    }
    if (groupId == null) {
      await controller.addAccountGroup(name);
    } else {
      await controller.renameAccountGroup(groupId, name);
    }
  }

  List<VeriMenuEntry> _groupMenuEntries(AccountGroup group, int accountCount) {
    final l10n = AppLocalizations.of(context);
    return <VeriMenuEntry>[
      VeriMenuItem(
        id: 'account_group_rename',
        icon: Icons.drive_file_rename_outline,
        title: l10n.commonRename,
        onPressed: () async => _showGroupNameDialog(context, groupId: group.id),
      ),
      const VeriMenuDivider(),
      VeriMenuItem(
        id: 'account_group_delete',
        icon: Icons.delete_outline,
        title: l10n.commonDelete,
        foregroundColor: Theme.of(context).colorScheme.error,
        onPressed: () async => _deleteGroup(group, accountCount),
      ),
    ];
  }

  Future<void> _deleteGroup(AccountGroup group, int accountCount) async {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.groupDeleteTitle,
      message: accountCount == 0
          ? l10n.groupDeleteMessage(group.name)
          : l10n.groupDeleteInUseMessage(group.name, accountCount),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!mounted || !confirmed) {
      return;
    }
    await controller.deleteAccountGroup(group.id);
  }
}

class _AccountGroupManageRow extends StatelessWidget {
  const _AccountGroupManageRow({
    required this.index,
    required this.group,
    required this.accountCount,
    required this.sorting,
    this.onTap,
    this.onActions,
  });

  final int index;
  final AccountGroup group;
  final int accountCount;
  final bool sorting;
  final VoidCallback? onTap;
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: sorting ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.folder_outlined,
                size: 24,
                color: veriRoyal.withValues(alpha: 0.78),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppLocalizations.of(context).accountsCount(accountCount),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.48),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (sorting)
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_handle,
                      size: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: group.name,
                  onPressed: onActions,
                  icon: const Icon(Icons.more_vert),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
