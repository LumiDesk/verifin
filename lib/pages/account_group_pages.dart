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
                AccountGroupCard(
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
  String? _selectedGroupId;
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
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 86),
                          itemCount: groups.length,
                          buildDefaultDragHandles: _sorting,
                          // ignore: deprecated_member_use
                          onReorder: _reorderDraft,
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            final groupAccounts = accounts
                                .where(
                                  (account) =>
                                      _effectiveGroupId(account) == group.id,
                                )
                                .toList();
                            final valuation = controller.accountBalancesInBase(
                              accounts: groupAccounts,
                            );
                            final selected = _selectedGroupId == group.id;

                            return Padding(
                              key: ValueKey(group.id),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  veriRadiusMd,
                                ),
                                onLongPress: _sorting
                                    ? null
                                    : () => setState(
                                        () => _selectedGroupId = group.id,
                                      ),
                                onTap: _sorting
                                    ? null
                                    : () => setState(() {
                                        _selectedGroupId = selected
                                            ? null
                                            : group.id;
                                      }),
                                child: VeriCard(
                                  child: Row(
                                    children: <Widget>[
                                      AccountIconBox(
                                        iconCode: group.iconCode,
                                        size: 30,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              group.name,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 5),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      veriRadiusSm,
                                                    ),
                                              ),
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                ).accountsCount(
                                                  groupAccounts.length,
                                                ),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.labelSmall,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        valuation.completeTotal == null
                                            ? '—'
                                            : formatUserMoney(
                                                valuation.completeTotal!,
                                                controller
                                                    .activeBook
                                                    .baseCurrencyCode,
                                              ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      if (selected) const SizedBox(width: 6),
                                      if (selected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: veriBlue,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _sorting || _selectedGroupId == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _showGroupNameDialog(
                            context,
                            groupId: _selectedGroupId,
                          ),
                          icon: const Icon(Icons.edit),
                          label: Text(
                            AppLocalizations.of(context).commonRename,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _showIconDialog(context),
                          icon: const Icon(Icons.palette_outlined),
                          label: Text(AppLocalizations.of(context).commonIcon),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            controller.deleteAccountGroup(_selectedGroupId!);
                            setState(() => _selectedGroupId = null);
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: Text(
                            AppLocalizations.of(context).commonDelete,
                          ),
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
      _selectedGroupId = null;
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
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final moved = _draftGroups.removeAt(oldIndex);
      _draftGroups.insert(newIndex, moved);
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
      controller.addAccountGroup(name);
    } else {
      controller.renameAccountGroup(groupId, name);
    }
  }

  Future<void> _showIconDialog(BuildContext context) async {
    final controller = VeriFinScope.of(context);
    final groupId = _selectedGroupId;
    if (groupId == null) {
      return;
    }
    final current = controller.accountGroups
        .where((group) => group.id == groupId)
        .firstOrNull;
    // 与账户图标选择用同一个组件（带图标预览）；分组图标以 iconForCode 渲染，
    // 不支持银行等资产图标，故只列通用图标。
    final iconCode = await showAccountIconSheet(
      context: context,
      selected: current?.iconCode ?? 'folder',
      title: AppLocalizations.of(context).groupIconPickerTitle,
      includeAssetIcons: false,
    );
    if (iconCode != null) {
      controller.updateAccountGroupIcon(groupId, iconCode);
    }
  }
}
