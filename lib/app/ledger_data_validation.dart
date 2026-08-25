import 'currency_catalog.dart';
import 'currency_math.dart';
import 'models.dart';

enum LedgerDataValidationCode {
  duplicateId,
  missingBook,
  missingAccount,
  invalidCurrency,
  invalidAmount,
  invalidEntryShape,
  invalidRefund,
  refundExceedsExpense,
  staleRefundCache,
}

class LedgerDataValidationIssue {
  const LedgerDataValidationIssue(this.code, this.entityId);

  final LedgerDataValidationCode code;
  final String entityId;
}

/// 校验三层金额与跨实体引用。备份恢复可允许“账户已删除但历史交易仍保留”的既有
/// 合法场景；新建/导入交易必须要求账户引用存在。
LedgerDataValidationIssue? validateLedgerEntries({
  required Iterable<LedgerBook> books,
  required Iterable<Account> accounts,
  required Iterable<LedgerEntry> entries,
  bool allowMissingAccounts = false,
  bool requireMinorUnitNormalization = false,
}) {
  final booksById = <String, LedgerBook>{};
  for (final book in books) {
    if (book.id.isEmpty || booksById.containsKey(book.id)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.duplicateId,
        book.id,
      );
    }
    if (!CurrencyCatalog.isSupported(book.baseCurrencyCode)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.invalidCurrency,
        book.id,
      );
    }
    booksById[book.id] = book;
  }

  final accountsById = <String, Account>{};
  for (final account in accounts) {
    if (account.id.isEmpty || accountsById.containsKey(account.id)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.duplicateId,
        account.id,
      );
    }
    if (!booksById.containsKey(account.bookId)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.missingBook,
        account.id,
      );
    }
    if (!CurrencyCatalog.isSupported(account.currencyCode)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.invalidCurrency,
        account.id,
      );
    }
    accountsById[account.id] = account;
  }

  bool positive(double? value) => value != null && value.isFinite && value > 0;
  bool nonNegative(double value) => value.isFinite && value >= 0;
  bool normalized(double value, String code) =>
      value == normalizeCurrencyAmount(value, code);

  final entryList = entries.toList(growable: false);
  final entriesById = <String, LedgerEntry>{};
  for (final entry in entryList) {
    if (entry.id.isEmpty || entriesById.containsKey(entry.id)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.duplicateId,
        entry.id,
      );
    }
    final book = booksById[entry.bookId];
    if (book == null) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.missingBook,
        entry.id,
      );
    }
    if (!CurrencyCatalog.isSupported(entry.currencyCode)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.invalidCurrency,
        entry.id,
      );
    }
    final account = entry.accountId.isEmpty
        ? null
        : accountsById[entry.accountId];
    final toAccount = entry.toAccountId?.isNotEmpty == true
        ? accountsById[entry.toAccountId]
        : null;
    if (!allowMissingAccounts &&
        (entry.accountId.isNotEmpty && account == null ||
            entry.toAccountId?.isNotEmpty == true && toAccount == null)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.missingAccount,
        entry.id,
      );
    }
    if (!positive(entry.amount) || !nonNegative(entry.fee)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.invalidAmount,
        entry.id,
      );
    }
    if (entry.accountId.isEmpty
        ? entry.accountAmount != null
        : !positive(entry.accountAmount)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.invalidEntryShape,
        entry.id,
      );
    }
    if (entry.toAccountId?.isNotEmpty == true
        ? !positive(entry.toAccountAmount)
        : entry.toAccountAmount != null) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.invalidEntryShape,
        entry.id,
      );
    }
    if (entry.type == EntryType.transfer) {
      if (!isZeroCurrencyAmount(entry.baseAmount, book.baseCurrencyCode) ||
          entry.accountId.isEmpty && entry.toAccountId?.isNotEmpty != true ||
          account != null && entry.currencyCode != account.currencyCode ||
          entry.accountId.isEmpty &&
              toAccount != null &&
              entry.currencyCode != toAccount.currencyCode) {
        return LedgerDataValidationIssue(
          LedgerDataValidationCode.invalidEntryShape,
          entry.id,
        );
      }
    } else if (!positive(entry.baseAmount) ||
        entry.toAccountId != null ||
        entry.fee != 0) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.invalidEntryShape,
        entry.id,
      );
    }
    if (requireMinorUnitNormalization &&
        (!normalized(entry.amount, entry.currencyCode) ||
            entry.accountAmount != null &&
                account != null &&
                !normalized(entry.accountAmount!, account.currencyCode) ||
            entry.toAccountAmount != null &&
                toAccount != null &&
                !normalized(entry.toAccountAmount!, toAccount.currencyCode) ||
            !normalized(entry.baseAmount, book.baseCurrencyCode) ||
            !normalized(
              entry.fee,
              account?.currencyCode ?? entry.currencyCode,
            ))) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.invalidAmount,
        entry.id,
      );
    }
    entriesById[entry.id] = entry;
  }

  final refundsByExpense = <String, List<LedgerEntry>>{};
  for (final entry in entryList.where(
    (item) => item.type == EntryType.refund,
  )) {
    final expense = entriesById[entry.refundOf];
    if (expense == null ||
        expense.type != EntryType.expense ||
        expense.bookId != entry.bookId ||
        expense.currencyCode != entry.currencyCode) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.invalidRefund,
        entry.id,
      );
    }
    refundsByExpense.putIfAbsent(expense.id, () => <LedgerEntry>[]).add(entry);
  }
  for (final item in refundsByExpense.entries) {
    final expense = entriesById[item.key]!;
    final originalTotal = item.value.fold<double>(
      0,
      (sum, refund) => sum + refund.amount,
    );
    if (originalTotal >
        expense.amount + currencyAmountTolerance(expense.currencyCode)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.refundExceedsExpense,
        expense.id,
      );
    }
    final settledBase = item.value
        .where((refund) => refund.settledAt != null)
        .fold<double>(0, (sum, refund) => sum + refund.baseAmount)
        .clamp(0.0, expense.baseAmount)
        .toDouble();
    final book = booksById[expense.bookId]!;
    if ((expense.refundedBaseAmount - settledBase).abs() >=
        currencyAmountTolerance(book.baseCurrencyCode)) {
      return LedgerDataValidationIssue(
        LedgerDataValidationCode.staleRefundCache,
        expense.id,
      );
    }
  }
  return null;
}
