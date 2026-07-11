import 'package:flutter/material.dart';

import '../app/common_widgets.dart';
import '../app/ledger_math.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 周期记账规则列表：新增 / 编辑 / 启停 / 删除。
class RecurringRulesPage extends StatelessWidget {
  const RecurringRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final rules = controller.recurringRules;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).recurringTitle,
                subtitle: AppLocalizations.of(context).recurringSubtitle,
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.add,
                    tooltip: AppLocalizations.of(context).recurringAddTooltip,
                    onPressed: () => _openEditor(context, null),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (rules.isEmpty)
                VeriCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).recurringEmpty,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                )
              else
                VeriCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      for (final rule in rules)
                        _RecurringRow(
                          rule: rule,
                          category: controller.categoryById(rule.categoryId),
                          onTap: () => _openEditor(context, rule),
                          onToggle: (value) =>
                              controller.setRecurringRuleActive(rule.id, value),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, RecurringRule? rule) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => RecurringRuleEditPage(rule: rule),
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({
    required this.rule,
    required this.category,
    required this.onTap,
    required this.onToggle,
  });

  final RecurringRule rule;
  final Category category;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final sign = switch (rule.type) {
      EntryType.expense => '-',
      EntryType.income => '+',
      EntryType.transfer => '',
      // 周期规则不产生退款，仅作穷尽兜底。
      EntryType.refund => '+',
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: <Widget>[
            CategoryIconBox(
              iconCode: category.iconCode,
              color: colorForType(rule.type),
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    rule.note.isEmpty ? category.label : rule.note,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${rule.frequency.label(AppLocalizations.of(context))} · $sign${formatAmount(rule.amount)}'
                    ' · ${AppLocalizations.of(context).nextRun(AppLocalizations.of(context).dateMonthDay(rule.nextRunDate))}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: rule.active, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

/// 周期规则新增 / 编辑表单。
class RecurringRuleEditPage extends StatefulWidget {
  const RecurringRuleEditPage({super.key, this.rule});

  final RecurringRule? rule;

  @override
  State<RecurringRuleEditPage> createState() => _RecurringRuleEditPageState();
}

class _RecurringRuleEditPageState extends State<RecurringRuleEditPage> {
  late EntryType _type;
  late double _amount;
  late String _categoryId;
  late String _accountId;
  String? _toAccountId;
  late RecurringFrequency _frequency;
  late DateTime _startDate;
  late final TextEditingController _noteController;
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    final controller = VeriFinScope.of(context);
    final rule = widget.rule;
    if (rule != null) {
      _type = rule.type;
      _amount = rule.amount;
      _categoryId = rule.categoryId;
      _accountId = rule.accountId;
      _toAccountId = rule.toAccountId;
      _frequency = rule.frequency;
      _startDate = rule.startDate;
      _noteController = TextEditingController(text: rule.note);
    } else {
      _type = EntryType.expense;
      _amount = 0;
      _categoryId = controller.categoriesForType(EntryType.expense).first.id;
      _accountId = controller.accounts.isEmpty
          ? ''
          : controller.accounts.first.id;
      _frequency = RecurringFrequency.monthly;
      _startDate = dateOnly(DateTime.now());
      _noteController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final accounts = controller.accounts;
    final category = controller.categoryById(_categoryId);
    final account = accounts.where((a) => a.id == _accountId).firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: widget.rule == null
                    ? AppLocalizations.of(context).recurringNewTitle
                    : AppLocalizations.of(context).recurringEditTitle,
                showBack: true,
                actions: <Widget>[
                  if (widget.rule != null)
                    HeaderAction(
                      icon: Icons.delete_outline,
                      tooltip: AppLocalizations.of(
                        context,
                      ).recurringDeleteTooltip,
                      destructive: true,
                      onPressed: _delete,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<EntryType>(
                segments: EntryType.userSelectable
                    .map(
                      (type) => ButtonSegment<EntryType>(
                        value: type,
                        label: Text(type.label(AppLocalizations.of(context))),
                      ),
                    )
                    .toList(),
                selected: <EntryType>{_type},
                onSelectionChanged: (selection) {
                  setState(() {
                    _type = selection.first;
                    _categoryId = controller.categoriesForType(_type).first.id;
                  });
                },
              ),
              const SizedBox(height: 12),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    DetailInfoRow(
                      label: AppLocalizations.of(context).amountLabel,
                      value: _amount > 0
                          ? formatAmount(_amount)
                          : AppLocalizations.of(context).tapToFill,
                      placeholder: _amount <= 0,
                      onTap: _editAmount,
                    ),
                    DetailInfoRow(
                      label: AppLocalizations.of(context).commonCategory,
                      value: category.label,
                      onTap: _pickCategory,
                    ),
                    DetailInfoRow(
                      label: _type == EntryType.transfer
                          ? AppLocalizations.of(context).transferOutAccount
                          : AppLocalizations.of(context).accountLabel,
                      value: accounts.isEmpty
                          ? AppLocalizations.of(context).addAccountFirst
                          : _accountId.isEmpty
                          ? AppLocalizations.of(context).noAccountLabel
                          : account?.name ??
                                AppLocalizations.of(context).noAccountLabel,
                      placeholder: accounts.isEmpty,
                      onTap: accounts.isEmpty
                          ? null
                          : () => _pickAccount(false),
                    ),
                    if (_type == EntryType.transfer)
                      DetailInfoRow(
                        label: AppLocalizations.of(context).transferInAccount,
                        value:
                            accounts
                                .where((a) => a.id == _toAccountId)
                                .firstOrNull
                                ?.name ??
                            AppLocalizations.of(context).pleaseSelect,
                        placeholder: _toAccountId == null,
                        onTap: accounts.length < 2
                            ? null
                            : () => _pickAccount(true),
                      ),
                    DetailInfoRow(
                      label: AppLocalizations.of(context).frequencyLabel,
                      value: _frequency.label(AppLocalizations.of(context)),
                      onTap: _pickFrequency,
                    ),
                    DetailInfoRow(
                      label: AppLocalizations.of(context).startDateLabel,
                      value: AppLocalizations.of(
                        context,
                      ).dateMonthDay(_startDate),
                      onTap: _pickStartDate,
                    ),
                    DetailInfoRow(
                      label: AppLocalizations.of(context).commonNote,
                      value: _noteController.text.trim().isEmpty
                          ? AppLocalizations.of(context).noteHint
                          : _noteController.text.trim(),
                      placeholder: _noteController.text.trim().isEmpty,
                      onTap: _editNote,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _canSave(accounts) ? _save : null,
                  child: Text(AppLocalizations.of(context).commonSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canSave(List<Account> accounts) {
    if (_amount <= 0) {
      return false;
    }
    if (_type == EntryType.transfer) {
      // 转账两端都需具体账户，且不能相同。
      if (accounts.length < 2 || _accountId.isEmpty) {
        return false;
      }
      if (_toAccountId == null || _toAccountId == _accountId) {
        return false;
      }
      return true;
    }
    // 收支：选了具体账户或「无账户」都可保存（与记账页一致）。
    return true;
  }

  Future<void> _editAmount() async {
    final amount = await showNumberPadSheet(
      context,
      title: AppLocalizations.of(context).amountLabel,
      initialAmount: _amount > 0 ? _amount : null,
    );
    if (amount == null || amount <= 0 || !mounted) {
      return;
    }
    setState(() => _amount = amount);
  }

  Future<void> _pickCategory() async {
    final controller = VeriFinScope.of(context);
    final selected = await showCategoryPickerSheet(
      context,
      categories: controller.categoriesForType(_type),
      selectedId: _categoryId,
    );
    if (selected != null && mounted) {
      setState(() => _categoryId = selected);
    }
  }

  Future<void> _pickAccount(bool toAccount) async {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final accounts = controller.accounts;
    // 兜底：无账户时不弹选择器。调用点也各有守卫，这里再挡一层。
    if (accounts.isEmpty) {
      return;
    }
    final isTransfer = _type == EntryType.transfer;
    // 转入账户不能与转出账户相同。
    final pickable = toAccount
        ? accounts.where((a) => a.id != _accountId).toList()
        : accounts;
    if (pickable.isEmpty) {
      return;
    }
    // 与记账 / 编辑交易用同一个账户选择器：带账户图标、余额、卡号后四位；收支的
    // 转出账户可选「无账户」，转账两端都需具体账户故不提供。
    final selected = await showAccountPickerSheet(
      context: context,
      title: toAccount
          ? l10n.pickTransferInAccount
          : (isTransfer ? l10n.pickTransferOutAccount : l10n.pickAccountTitle),
      accounts: pickable,
      selectedId: toAccount ? _toAccountId : _accountId,
      balanceOf: controller.accountBalance,
      noneLabel: (toAccount || isTransfer) ? null : l10n.noAccountLabel,
      noneHint: (toAccount || isTransfer) ? null : l10n.noAccountHint,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      if (toAccount) {
        _toAccountId = selected.id;
      } else {
        // 选到「无账户」时 selected.id 为空串，正是 RecurringRule 表达无账户的方式。
        _accountId = selected.id;
      }
    });
  }

  Future<void> _pickFrequency() async {
    final selected = await showOptionSheet<RecurringFrequency>(
      context: context,
      title: AppLocalizations.of(context).pickFrequencyTitle,
      values: RecurringFrequency.values,
      selected: _frequency,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null && mounted) {
      setState(() => _frequency = selected);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = dateOnly(picked));
    }
  }

  Future<void> _editNote() async {
    final note = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).commonNote,
      label: AppLocalizations.of(context).commonNote,
      initialValue: _noteController.text,
      allowEmpty: true,
    );
    if (note != null && mounted) {
      setState(() => _noteController.text = note);
    }
  }

  void _save() {
    final controller = VeriFinScope.of(context);
    final existing = widget.rule;
    if (existing == null) {
      controller.addRecurringRule(
        RecurringRule(
          id: 'recur_${DateTime.now().microsecondsSinceEpoch}',
          bookId: controller.activeBook.id,
          type: _type,
          amount: _amount,
          categoryId: _categoryId,
          accountId: _accountId,
          toAccountId: _type == EntryType.transfer ? _toAccountId : null,
          note: _noteController.text.trim(),
          frequency: _frequency,
          startDate: _startDate,
          nextRunDate: _startDate,
        ),
      );
    } else {
      controller.updateRecurringRule(
        existing.copyWith(
          type: _type,
          amount: _amount,
          categoryId: _categoryId,
          accountId: _accountId,
          toAccountId: _type == EntryType.transfer ? _toAccountId : null,
          clearToAccountId: _type != EntryType.transfer,
          note: _noteController.text.trim(),
          frequency: _frequency,
          startDate: _startDate,
        ),
      );
    }
    // 立即补记已到期的交易。
    controller.applyDueRecurring(DateTime.now());
    Navigator.of(context).pop();
  }

  void _delete() {
    VeriFinScope.of(context).deleteRecurringRule(widget.rule!.id);
    Navigator.of(context).pop();
  }
}
