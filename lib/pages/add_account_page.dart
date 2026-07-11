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
  bool _iconManuallySelected = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_suggestIconFromName);
  }

  @override
  void dispose() {
    _nameController.removeListener(_suggestIconFromName);
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

    return Scaffold(
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
                    HeaderAction(
                      icon: Icons.check,
                      tooltip: AppLocalizations.of(context).accountSaveTooltip,
                      onPressed: _save,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SelectField(
                  label: AppLocalizations.of(context).accountTypeLabel,
                  value: _type.label(AppLocalizations.of(context)),
                  icon: Icons.category_outlined,
                  onTap: _pickAccountType,
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
                    // key 随类型变化，切换账户类型时重置内部跟随开关状态。
                    key: ValueKey<AccountType>(_type),
                    numberController: _cardNumberController,
                    last4Controller: _cardLast4Controller,
                  ),
                  const SizedBox(height: 10),
                ],
                TextFormField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).accountBalanceLabel,
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
    );
  }

  Future<void> _pickAccountType() async {
    final selected = await showOptionSheet<AccountType>(
      context: context,
      title: AppLocalizations.of(context).accountTypePickerTitle,
      values: AccountType.values,
      selected: _type,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null) {
      setState(() {
        _type = selected;
        if (!_type.supportsCardLast4) {
          _cardLast4Controller.clear();
          _cardNumberController.clear();
        }
      });
    }
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

  void _suggestIconFromName() {
    if (_iconManuallySelected) {
      return;
    }
    final suggested = suggestedAccountIconCode(_nameController.text);
    if (suggested == null || suggested == _iconCode) {
      return;
    }
    setState(() => _iconCode = suggested);
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

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final controller = VeriFinScope.of(context);
    controller.addAccount(
      Account(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bookId: controller.activeBook.id,
        name: _nameController.text.trim(),
        type: _type,
        groupId: _groupId,
        initialBalance: double.tryParse(_balanceController.text.trim()) ?? 0,
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
      ),
    );
    Navigator.of(context).pop();
  }
}
