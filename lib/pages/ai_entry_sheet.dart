import 'package:flutter/material.dart';

import '../app/ai/ai_client.dart';
import '../app/ai/ai_entry_parser.dart';
import '../app/models.dart';
import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'ai_settings_page.dart';
import 'entry_detail_page.dart';

/// AI 对话记账入口：未配置则引导去设置；否则弹出自然语言输入框，解析成交易草稿，
/// 落账前 push 到记账页由用户确认/修改。
Future<void> startAiEntry(BuildContext context) async {
  final controller = VeriFinScope.of(context);
  final l10n = AppLocalizations.of(context);

  if (!controller.aiSettings.isConfigured) {
    final goToSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiEntryNotConfiguredTitle),
        content: Text(l10n.aiEntryNotConfiguredBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.aiEntryGoToSettings),
          ),
        ],
      ),
    );
    if (goToSettings == true && context.mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()),
      );
    }
    return;
  }

  final draft = await showModalBottomSheet<AiEntryDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _AiEntrySheet(),
  );

  if (draft != null && context.mounted) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            EntryDetailPage(initialAmount: draft.amount, initialDraft: draft),
      ),
    );
  }
}

AiEntryContext _buildContext(VeriFinController controller) {
  List<AiOption> optionsFor(EntryType type) => controller
      .categoriesForType(type)
      .map(
        (category) => AiOption(
          id: category.id,
          label: controller.categoryPathLabel(category.id),
        ),
      )
      .toList();
  final accounts = controller.accounts
      .where((account) => !account.hidden)
      .map((account) => AiOption(id: account.id, label: account.name))
      .toList();
  return AiEntryContext(
    expenseCategories: optionsFor(EntryType.expense),
    incomeCategories: optionsFor(EntryType.income),
    accounts: accounts,
    today: DateTime.now(),
    bookId: controller.activeBook.id,
  );
}

class _AiEntrySheet extends StatefulWidget {
  const _AiEntrySheet();

  @override
  State<_AiEntrySheet> createState() => _AiEntrySheetState();
}

class _AiEntrySheetState extends State<_AiEntrySheet> {
  final TextEditingController _inputController = TextEditingController();
  bool _parsing = false;
  String? _errorText;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final l10n = AppLocalizations.of(context);
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorText = l10n.aiEntryEmptyInput);
      return;
    }
    final controller = VeriFinScope.of(context);
    setState(() {
      _parsing = true;
      _errorText = null;
    });
    try {
      final draft = await requestAiEntryDraft(
        settings: controller.aiSettings,
        input: input,
        context: _buildContext(controller),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(draft);
    } on AiEntryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _parsing = false;
        _errorText = switch (error.error) {
          AiEntryError.emptyResult => l10n.aiEntryNoResult,
          AiEntryError.noAmount => l10n.aiEntryNoAmount,
        };
      });
    } on AiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _parsing = false;
        _errorText = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _parsing = false;
        _errorText = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.aiEntryTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputController,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: l10n.aiEntryInputHint,
              border: const OutlineInputBorder(),
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.privacy_tip_outlined, size: 14, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.aiPrivacyNotice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _parsing ? null : _parse,
              icon: _parsing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward, size: 18),
              label: Text(_parsing ? l10n.aiEntryParsing : l10n.aiEntryParse),
            ),
          ),
        ],
      ),
    );
  }
}
