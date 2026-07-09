import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
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
    final name = await showTextInputDialog(
      context: context,
      title: AppLocalizations.of(context).bookAdd,
      label: AppLocalizations.of(context).bookNameLabel,
    );
    if (!context.mounted || name == null) {
      return;
    }
    VeriFinScope.of(context).addLedgerBook(name);
  }
}

class _LedgerBookRow extends StatelessWidget {
  const _LedgerBookRow({required this.book});

  final LedgerBook book;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final selected = controller.activeBook.id == book.id;
    final entryCount = controller.entryCountForBook(book.id);

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
                      '${AppLocalizations.of(context).entriesCountFull(entryCount)}',
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
              PopupMenuButton<String>(
                tooltip: AppLocalizations.of(context).bookActions,
                onSelected: (value) {
                  if (value == 'rename') {
                    _renameBook(context);
                  }
                  if (value == 'delete') {
                    _deleteBook(context);
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'rename',
                    child: Text(AppLocalizations.of(context).commonRename),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    enabled: !book.isDefault,
                    child: Text(
                      book.isDefault
                          ? AppLocalizations.of(context).defaultBookUndeletable
                          : AppLocalizations.of(context).commonDelete,
                    ),
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
