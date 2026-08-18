import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/currency_catalog.dart';
import '../app/currency_math.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

class CurrencyRatesPage extends StatefulWidget {
  const CurrencyRatesPage({super.key});

  @override
  State<CurrencyRatesPage> createState() => _CurrencyRatesPageState();
}

class _CurrencyRatesPageState extends State<CurrencyRatesPage> {
  bool _offeredLegacySetup = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final book = VeriFinScope.of(context).activeBook;
    if (!_offeredLegacySetup &&
        book.currencySetupStatus == CurrencySetupStatus.legacyUnconfirmed) {
      _offeredLegacySetup = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          confirmLegacyLedgerCurrency(context: context, book: book);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final book = controller.activeBook;
    final base = CurrencyCatalog.require(book.baseCurrencyCode);
    final codes = <String>{
      for (final account in controller.accounts)
        if (account.currencyCode != book.baseCurrencyCode) account.currencyCode,
      for (final entry in controller.entries)
        if (entry.currencyCode != book.baseCurrencyCode) entry.currencyCode,
      for (final rate in controller.exchangeRates) rate.currencyCode,
    }.toList()..sort();

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: l10n.currencyRatesTitle,
                subtitle: l10n.currentBookLabel(book.name),
                showBack: true,
                actions: <Widget>[
                  if (book.currencySetupStatus == CurrencySetupStatus.confirmed)
                    HeaderAction(
                      icon: Icons.add,
                      tooltip: l10n.exchangeRateAdd,
                      onPressed: _addRate,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              VeriCard(
                child: Row(
                  children: <Widget>[
                    const VeriIconBox(
                      icon: Icons.account_balance_wallet_outlined,
                      color: veriRoyal,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.ledgerBaseCurrency,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${base.code} · ${base.nameForLocale(Localizations.localeOf(context).toLanguageTag())}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (book.currencySetupStatus ==
                  CurrencySetupStatus.legacyUnconfirmed)
                _LegacySetupCard(book: book)
              else ...<Widget>[
                VeriCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.offline_bolt_outlined, color: veriRoyal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.currencyRatesOfflineDesc,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionLabel(l10n.exchangeRateCurrencies),
                if (codes.isEmpty)
                  VeriCard(
                    child: EmptyState(
                      icon: Icons.currency_exchange,
                      title: l10n.exchangeRateEmpty,
                      description: l10n.exchangeRateEmptyDesc,
                    ),
                  )
                else
                  VeriCard(
                    child: Column(
                      children: <Widget>[
                        for (final item in codes.indexed) ...<Widget>[
                          _CurrencyRateRow(currencyCode: item.$2),
                          if (item.$1 != codes.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addRate() async {
    final controller = VeriFinScope.of(context);
    final selected = await showCurrencyPickerSheet(
      context: context,
      title: AppLocalizations.of(context).selectRateCurrency,
      excludedCodes: <String>[controller.activeBook.baseCurrencyCode],
      preferredCodes: <String>[
        ...controller.accounts.map((account) => account.currencyCode),
        ...controller.exchangeRates.map((rate) => rate.currencyCode),
      ],
    );
    if (!mounted || selected == null) return;
    await editExchangeRate(context: context, currencyCode: selected.code);
  }
}

class _LegacySetupCard extends StatelessWidget {
  const _LegacySetupCard({required this.book});

  final LedgerBook book;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VeriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.legacyCurrencySetupTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(l10n.legacyCurrencySetupDesc),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () =>
                  confirmLegacyLedgerCurrency(context: context, book: book),
              child: Text(l10n.legacyCurrencyStart),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyRateRow extends StatelessWidget {
  const _CurrencyRateRow({required this.currencyCode});

  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final currency = CurrencyCatalog.require(currencyCode);
    final rates = controller.exchangeRates
        .where((rate) => rate.currencyCode == currencyCode)
        .toList();
    final latest = rates.isEmpty ? null : rates.first;
    final stale = latest != null && isExchangeRateStale(latest, DateTime.now());
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: Key('currency_rate_$currencyCode'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: SizedBox(
          width: 44,
          child: Text(
            currencyCode,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          latest == null
              ? currency.nameForLocale(
                  Localizations.localeOf(context).toLanguageTag(),
                )
              : l10n.exchangeRateEquation(
                  currencyCode,
                  formatRateValue(latest.rateToBase),
                  controller.activeBook.baseCurrencyCode,
                ),
        ),
        subtitle: Text(
          latest == null
              ? l10n.exchangeRateNotSet
              : l10n.exchangeRateDateAndStatus(
                  l10n.dateMonthDay(latest.effectiveDate),
                  stale
                      ? l10n.exchangeRateStale
                      : exchangeRateSourceLabel(l10n, latest.source),
                ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) =>
                CurrencyRateHistoryPage(currencyCode: currencyCode),
          ),
        ),
      ),
    );
  }
}

class CurrencyRateHistoryPage extends StatelessWidget {
  const CurrencyRateHistoryPage({super.key, required this.currencyCode});

  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final l10n = AppLocalizations.of(context);
    final rates = controller.exchangeRates
        .where((rate) => rate.currencyCode == currencyCode)
        .toList();
    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: l10n.exchangeRateHistory(currencyCode),
                subtitle: l10n.exchangeRateAgainst(
                  controller.activeBook.baseCurrencyCode,
                ),
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.add,
                    tooltip: l10n.exchangeRateAdd,
                    onPressed: () => editExchangeRate(
                      context: context,
                      currencyCode: currencyCode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (rates.isEmpty)
                VeriCard(
                  child: EmptyState(
                    icon: Icons.history,
                    title: l10n.exchangeRateHistoryEmpty,
                    description: l10n.exchangeRateHistoryEmptyDesc,
                  ),
                )
              else
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      for (final item in rates.indexed) ...<Widget>[
                        _RateHistoryRow(rate: item.$2),
                        if (item.$1 != rates.length - 1)
                          const Divider(height: 1),
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
}

class _RateHistoryRow extends StatelessWidget {
  const _RateHistoryRow({required this.rate});

  final ExchangeRate rate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stale = isExchangeRateStale(rate, DateTime.now());
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(
          l10n.exchangeRateEquation(
            rate.currencyCode,
            formatRateValue(rate.rateToBase),
            rate.baseCurrencyCode,
          ),
        ),
        subtitle: Text(
          l10n.exchangeRateDateAndStatus(
            l10n.dateMonthDay(rate.effectiveDate),
            stale
                ? l10n.exchangeRateStale
                : exchangeRateSourceLabel(l10n, rate.source),
          ),
        ),
        onTap: () => editExchangeRate(
          context: context,
          currencyCode: rate.currencyCode,
          existing: rate,
        ),
        trailing: PopupMenuButton<String>(
          tooltip: l10n.bookActions,
          onSelected: (value) async {
            if (value != 'delete') return;
            final confirmed = await showConfirmDialog(
              context,
              title: l10n.exchangeRateDeleteTitle,
              message: l10n.exchangeRateDeleteMessage,
              confirmLabel: l10n.commonDelete,
              destructive: true,
            );
            if (!context.mounted || !confirmed) return;
            final deleted = await VeriFinScope.of(
              context,
            ).deleteExchangeRate(rate.id);
            if (!context.mounted || deleted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
          },
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'delete',
              child: Text(l10n.commonDelete),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> editExchangeRate({
  required BuildContext context,
  required String currencyCode,
  ExchangeRate? existing,
}) async {
  final l10n = AppLocalizations.of(context);
  final initialDate = existing?.effectiveDate ?? DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(1970),
    lastDate: DateTime(2100),
    helpText: l10n.exchangeRateEffectiveDate,
  );
  if (!context.mounted || date == null) return;
  final controller = VeriFinScope.of(context);
  final amount = await showNumberPadSheet(
    context,
    title: l10n.exchangeRateInputTitle(
      currencyCode,
      controller.activeBook.baseCurrencyCode,
    ),
    initialAmount: existing?.rateToBase,
    maxFractionDigits: 10,
  );
  if (!context.mounted || amount == null) return;
  final saved = await controller.saveExchangeRateDraft(
    id: existing?.id,
    currencyCode: currencyCode,
    effectiveDate: date,
    rateToBase: amount,
    source: existing?.source ?? ExchangeRateSource.manual,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(saved ? l10n.exchangeRateSaved : l10n.saveFailed)),
  );
}

String formatRateValue(double value) {
  final fixed = value.toStringAsFixed(10);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String exchangeRateSourceLabel(
  AppLocalizations l10n,
  ExchangeRateSource source,
) {
  return switch (source) {
    ExchangeRateSource.manual => l10n.exchangeRateSourceManual,
    ExchangeRateSource.imported => l10n.exchangeRateSourceImported,
  };
}
