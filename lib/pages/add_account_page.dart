part of 'assets_pages.dart';

class AddAccountPage extends StatefulWidget {
  const AddAccountPage({super.key});

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _cardLast4Controller = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _noteController = TextEditingController();
  AccountType _type = AccountType.onlinePayment;
  String _iconCode = 'wallet';
  String _groupId = 'ungrouped';
  String? _currencyCode;
  bool _iconManuallySelected = false;
  // 「后四位跟随完整卡号」开关，新账户默认打开。
  bool _cardLast4Follows = true;
  bool _saved = false;
  final EditorExitController _exitController = EditorExitController();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
    _balanceController.addListener(_handleDraftChanged);
    _cardLast4Controller.addListener(_handleDraftChanged);
    _cardNumberController.addListener(_handleDraftChanged);
    _noteController.addListener(_handleDraftChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currencyCode ??= VeriFinScope.of(context).activeBook.baseCurrencyCode;
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _balanceController.removeListener(_handleDraftChanged);
    _cardLast4Controller.removeListener(_handleDraftChanged);
    _cardNumberController.removeListener(_handleDraftChanged);
    _noteController.removeListener(_handleDraftChanged);
    _nameController.dispose();
    _balanceController.dispose();
    _cardLast4Controller.dispose();
    _cardNumberController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final groups = controller.accountGroups;
    final currencyCode =
        _currencyCode ?? controller.activeBook.baseCurrencyCode;
    final currency = CurrencyCatalog.require(currencyCode);

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      exitController: _exitController,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                children: <Widget>[
                  VeriHeader(
                    title: AppLocalizations.of(context).accountAdd,
                    showBack: true,
                    actions: <Widget>[
                      SaveHeaderAction(
                        onPressed: _isDirty ? _saveAndExit : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  VeriAnchoredChoice<AccountType>(
                    key: const Key('add_account_type_choice'),
                    values: AccountType.values,
                    selected: _type,
                    idOf: (value) => 'add_account_type_${value.name}',
                    labelOf: (value) =>
                        value.label(AppLocalizations.of(context)),
                    subtitleOf: (value) =>
                        value.capabilityHint(AppLocalizations.of(context)),
                    onSelected: (value) => setState(() => _type = value),
                    semanticLabel: AppLocalizations.of(
                      context,
                    ).accountTypePickerTitle,
                    width: 276,
                    builder: (context, openMenu, menuOpen) => SelectField(
                      label: AppLocalizations.of(context).accountTypeLabel,
                      value: _type.label(AppLocalizations.of(context)),
                      icon: Icons.category_outlined,
                      onTap: openMenu,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).accountNameLabel,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.of(context).accountNameRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_type.supportsCardLast4) ...<Widget>[
                    CardNumberFields(
                      numberController: _cardNumberController,
                      last4Controller: _cardLast4Controller,
                      follows: _cardLast4Follows,
                      onFollowsChanged: (value) =>
                          setState(() => _cardLast4Follows = value),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SelectField(
                    key: const Key('account_currency_select_field'),
                    label: AppLocalizations.of(context).commonCurrency,
                    value:
                        '${currency.code} · ${currency.nameForLocale(Localizations.localeOf(context).toLanguageTag())}',
                    icon: Icons.currency_exchange,
                    onTap: _pickCurrency,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _balanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      ).accountBalanceCurrencyLabel(currencyCode),
                      hintText: AppLocalizations.of(context).accountBalanceHint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectField(
                    key: const Key('account_icon_select_field'),
                    label: AppLocalizations.of(context).accountIconLabel,
                    value: iconLabelForCode(
                      AppLocalizations.of(context),
                      _iconCode,
                    ),
                    leading: AccountIconBox(iconCode: _iconCode, size: 28),
                    onTap: _pickAccountIcon,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteController,
                    maxLines: 1,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).accountNoteLabel,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectField(
                    label: AppLocalizations.of(context).accountGroupLabel,
                    value: _groupLabel(groups),
                    icon: Icons.folder_outlined,
                    onTap: () => _pickAccountGroup(groups),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAccountIcon() async {
    final selected = await showAccountIconSheet(
      context: context,
      selected: _iconCode,
    );
    if (selected != null) {
      setState(() {
        _iconCode = selected;
        _iconManuallySelected = true;
      });
    }
  }

  Future<void> _pickCurrency() async {
    var controller = VeriFinScope.of(context);
    if (controller.activeBook.currencySetupStatus ==
        CurrencySetupStatus.legacyUnconfirmed) {
      final confirmed = await confirmLegacyLedgerCurrency(
        context: context,
        book: controller.activeBook,
      );
      if (!mounted || !confirmed) return;
      controller = VeriFinScope.of(context);
      setState(() => _currencyCode = controller.activeBook.baseCurrencyCode);
    }
    final selected = await showCurrencyPickerSheet(
      context: context,
      title: AppLocalizations.of(context).selectAccountCurrency,
      selectedCode: _currencyCode,
      preferredCodes: controller.accounts.map(
        (account) => account.currencyCode,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _currencyCode = selected.code);
    }
  }

  void _handleNameChanged() {
    if (!_iconManuallySelected) {
      final suggested = suggestedAccountIconCode(_nameController.text);
      if (suggested != null) {
        _iconCode = suggested;
      }
    }
    _handleDraftChanged();
  }

  void _handleDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickAccountGroup(List<AccountGroup> groups) async {
    final values = <String>['ungrouped', ...groups.map((group) => group.id)];
    final selected = await showOptionSheet<String>(
      context: context,
      title: AppLocalizations.of(context).accountGroupPickerTitle,
      values: values,
      selected: _groupId,
      labelOf: (value) {
        if (value == 'ungrouped') {
          return AppLocalizations.of(context).assetsUngrouped;
        }
        return groups
            .firstWhere(
              (group) => group.id == value,
              orElse: () => AccountGroup(
                id: 'ungrouped',
                bookId: defaultLedgerBookId,
                name: AppLocalizations.of(context).assetsUngrouped,
                iconCode: 'folder',
                sortOrder: 999,
              ),
            )
            .name;
      },
    );
    if (selected != null) {
      setState(() => _groupId = selected);
    }
  }

  String _groupLabel(List<AccountGroup> groups) {
    if (_groupId == 'ungrouped') {
      return AppLocalizations.of(context).assetsUngrouped;
    }
    return groups
        .firstWhere(
          (group) => group.id == _groupId,
          orElse: () => AccountGroup(
            id: 'ungrouped',
            bookId: defaultLedgerBookId,
            name: AppLocalizations.of(context).assetsUngrouped,
            iconCode: 'folder',
            sortOrder: 999,
          ),
        )
        .name;
  }

  bool get _isDirty {
    final balanceText = _balanceController.text.trim();
    final parsedBalance = double.tryParse(balanceText);
    final balanceChanged =
        balanceText.isNotEmpty && (parsedBalance == null || parsedBalance != 0);
    return !_saved &&
        (_nameController.text.trim().isNotEmpty ||
            balanceChanged ||
            _type != AccountType.onlinePayment ||
            _iconCode != 'wallet' ||
            _groupId != 'ungrouped' ||
            _currencyCode !=
                VeriFinScope.of(context).activeBook.baseCurrencyCode ||
            _noteController.text.trim().isNotEmpty ||
            (_type.supportsCardLast4 &&
                (_cardNumberController.text.trim().isNotEmpty ||
                    cardLast4Of(_cardLast4Controller.text).isNotEmpty ||
                    !_cardLast4Follows)));
  }

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(() => _saved = true);
      _exitController.exit();
    }
  }

  Future<bool> _save() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    final controller = VeriFinScope.of(context);
    return controller.addAccountDraft(
      Account(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bookId: controller.activeBook.id,
        name: _nameController.text.trim(),
        type: _type,
        groupId: _groupId,
        initialBalance: double.tryParse(_balanceController.text.trim()) ?? 0,
        currencyCode: _currencyCode ?? controller.activeBook.baseCurrencyCode,
        iconCode: _iconCode,
        note: _noteController.text.trim(),
        includeInAssets: true,
        hidden: false,
        cardLast4: _type.supportsCardLast4
            ? cardLast4Of(_cardLast4Controller.text)
            : '',
        cardNumber: _type.supportsCardLast4
            ? _cardNumberController.text.trim()
            : '',
        cardLast4Follows: _type.supportsCardLast4 ? _cardLast4Follows : true,
      ),
    );
  }
}
