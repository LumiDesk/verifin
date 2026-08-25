import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/currency_catalog.dart';
import '../app/feedback.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import 'sheets.dart';

class LedgerBooksPage extends StatelessWidget {
  const LedgerBooksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final books = controller.ledgerBooks;

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).ledgerLabel,
                subtitle: AppLocalizations.of(
                  context,
                ).currentBookLabel(controller.activeBook.name),
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.add,
                    tooltip: AppLocalizations.of(context).bookAdd,
                    onPressed: () => _createBook(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Column(
                  children: <Widget>[
                    for (final item in books.indexed) ...<Widget>[
                      _LedgerBookRow(book: item.$2),
                      if (item.$1 != books.length - 1) const Divider(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createBook(BuildContext context) async {
    final controller = VeriFinScope.of(context);
    final draft = await showLedgerBookEditorSheet(
      context: context,
      initialCurrencyCode: controller.activeBook.baseCurrencyCode,
    );
    if (!context.mounted || draft == null) {
      return;
    }
    controller.addLedgerBook(draft.name, baseCurrencyCode: draft.currencyCode);
  }
}

class _LedgerBookRow extends StatelessWidget {
  const _LedgerBookRow({required this.book});

  final LedgerBook book;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final selected = controller.activeBook.id == book.id;
    final entryCount = controller.entryCountForBook(book.id);
    final currencyLocked =
        book.currencySetupStatus != CurrencySetupStatus.legacyUnconfirmed &&
        controller.ledgerBookHasFinancialData(book.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(veriRadiusSm),
        onTap: () => controller.switchLedgerBook(book.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              VeriIconBox(
                icon: book.isDefault ? Icons.book : Icons.book_outlined,
                color: selected
                    ? veriRoyal
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      book.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${book.isDefault ? '${AppLocalizations.of(context).defaultBookLabel} · ' : ''}'
                      '${AppLocalizations.of(context).entriesCountFull(entryCount)} · '
                      '${book.baseCurrencyCode}',
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
              if (selected)
                const Icon(Icons.check_circle, color: veriRoyal, size: 18),
              VeriAnchoredMenuButton(
                icon: Icons.more_vert,
                tooltip: l10n.bookActions,
                width: 216,
                entries: <VeriMenuEntry>[
                  VeriMenuItem(
                    id: 'book_rename',
                    icon: Icons.drive_file_rename_outline,
                    title: l10n.commonRename,
                    onPressed: () async => _renameBook(context),
                  ),
                  VeriMenuItem(
                    id: 'book_currency',
                    icon: Icons.currency_exchange_outlined,
                    title: l10n.ledgerBaseCurrency,
                    subtitle: currencyLocked
                        ? l10n.ledgerCurrencyLockedShort
                        : book.baseCurrencyCode,
                    enabled: !currencyLocked,
                    onPressed: () async => _editBookCurrency(context),
                  ),
                  const VeriMenuDivider(),
                  VeriMenuItem(
                    id: 'book_delete',
                    icon: Icons.delete_outline,
                    title: l10n.commonDelete,
                    subtitle: book.isDefault
                        ? l10n.defaultBookUndeletable
                        : null,
                    enabled: !book.isDefault,
                    foregroundColor: Theme.of(context).colorScheme.error,
                    onPressed: () async => _deleteBook(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameBook(BuildContext context) async {
    final name = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).bookRenameTitle,
      label: AppLocalizations.of(context).bookNameLabel,
      initialValue: book.name,
    );
    if (!context.mounted || name == null) {
      return;
    }
    VeriFinScope.of(context).renameLedgerBook(book.id, name);
  }

  Future<void> _editBookCurrency(BuildContext context) async {
    final controller = VeriFinScope.of(context);
    if (book.currencySetupStatus == CurrencySetupStatus.legacyUnconfirmed) {
      await confirmLegacyLedgerCurrency(context: context, book: book);
      return;
    }
    if (controller.ledgerBookHasFinancialData(book.id)) {
      unawaited(
        VeriFeedbackHost.of(context).showMessage(
          message: AppLocalizations.of(context).ledgerCurrencyLocked,
          tone: VeriFeedbackTone.warning,
        ),
      );
      return;
    }
    final selected = await showCurrencyPickerSheet(
      context: context,
      title: AppLocalizations.of(context).selectBaseCurrency,
      selectedCode: book.baseCurrencyCode,
    );
    if (!context.mounted ||
        selected == null ||
        selected.code == book.baseCurrencyCode) {
      return;
    }
    final currency = CurrencyCatalog.require(selected.code);
    final confirmed = await showConfirmDialog(
      context,
      title: AppLocalizations.of(context).ledgerCurrencyChangeTitle,
      message: AppLocalizations.of(context).ledgerCurrencyChangeMessage(
        currency.code,
        currency.nameForLocale(Localizations.localeOf(context).toLanguageTag()),
      ),
    );
    if (!context.mounted || !confirmed) return;
    final saved = await controller.changeEmptyLedgerBookBaseCurrency(
      book.id,
      selected.code,
    );
    if (!context.mounted || saved) return;
    unawaited(
      VeriFeedbackHost.of(context).showMessage(
        message: AppLocalizations.of(context).saveFailed,
        tone: VeriFeedbackTone.error,
        duration: VeriFeedbackDuration.long,
        priority: VeriFeedbackPriority.high,
        dedupeKey: 'ledger-currency-save',
      ),
    );
  }

  Future<void> _deleteBook(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: AppLocalizations.of(context).bookDeleteTitle,
      message: AppLocalizations.of(context).bookDeleteMessage(book.name),
      confirmLabel: AppLocalizations.of(context).commonDelete,
      destructive: true,
    );
    if (!context.mounted || !confirmed) {
      return;
    }
    VeriFinScope.of(context).deleteLedgerBook(book.id);
  }
}
