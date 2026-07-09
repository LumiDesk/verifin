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

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final groups = controller.accountGroups;
    final accounts = controller.accounts;

    return Scaffold(
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
                    HeaderAction(
                      icon: Icons.add,
                      tooltip: AppLocalizations.of(context).groupAdd,
                      onPressed: () => _showGroupNameDialog(context),
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
                        // ignore: deprecated_member_use
                        onReorder: controller.reorderAccountGroup,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final groupAccounts = accounts
                              .where(
                                (account) =>
                                    _effectiveGroupId(account) == group.id,
                              )
                              .toList();
                          final total = groupAccounts.fold<double>(
                            0,
                            (sum, account) =>
                                sum + controller.accountBalance(account),
                          );
                          final selected = _selectedGroupId == group.id;

                          return Padding(
                            key: ValueKey(group.id),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(veriRadiusMd),
                              onLongPress: () =>
                                  setState(() => _selectedGroupId = group.id),
                              onTap: () => setState(() {
                                _selectedGroupId = selected ? null : group.id;
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
                                            padding: const EdgeInsets.symmetric(
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
                                      formatAmount(total),
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
      bottomNavigationBar: _selectedGroupId == null
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
                        label: Text(AppLocalizations.of(context).commonRename),
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
                        label: Text(AppLocalizations.of(context).commonDelete),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
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
