// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Veri Fin';

  @override
  String get tabHome => 'Home';

  @override
  String get tabAssets => 'Assets';

  @override
  String get tabReports => 'Reports';

  @override
  String get tabProfile => 'Me';

  @override
  String get quickEntry => 'Quick Entry';

  @override
  String get pressBackAgainToExit => 'Press back again to exit';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languagePickerTitle => 'Select language';

  @override
  String get localeFollowSystem => 'Follow system';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonBack => 'Back';

  @override
  String get commonProcessing => 'Processing…';

  @override
  String get badgeRefunded => 'Refunded';

  @override
  String get badgeReimbursable => 'Reimbursable';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarPrevMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get entryAddTags => 'Add tags';

  @override
  String get iconGroupGeneric => 'General icons';

  @override
  String get accountIconPickerTitle => 'Choose account icon';

  @override
  String get accountHandleTitle => 'Manage this account?';

  @override
  String accountHandleMessage(String name, int count) {
    return 'Account \"$name\" already has $count related transactions. You can hide the account, or delete it together with those transactions.';
  }

  @override
  String get accountHide => 'Hide account';

  @override
  String get accountDeleteWithEntries => 'Delete account & transactions';

  @override
  String get accountDeleteTitle => 'Delete this account?';

  @override
  String accountDeleteMessage(String name) {
    return 'Account \"$name\" cannot be restored once deleted.';
  }

  @override
  String get tagCreateTitle => 'New tag';

  @override
  String get tagNameLabel => 'Tag name';

  @override
  String get entryTypeExpense => 'Expense';

  @override
  String get entryTypeIncome => 'Income';

  @override
  String get entryTypeTransfer => 'Transfer';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accountTypeOnlinePayment => 'Online payment';

  @override
  String get accountTypeCreditCard => 'Credit card';

  @override
  String get accountTypeDebitCard => 'Debit card';

  @override
  String get accountTypeInvestment => 'Investment';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get assetViewGroup => 'Group view';

  @override
  String get assetViewType => 'Type view';

  @override
  String get assetViewToggleToType => 'Switch to type view';

  @override
  String get assetViewToggleToGroup => 'Switch to group view';

  @override
  String get recurringDaily => 'Daily';

  @override
  String get recurringWeekly => 'Weekly';

  @override
  String get recurringMonthly => 'Monthly';

  @override
  String get recurringYearly => 'Yearly';

  @override
  String get genderUnset => 'Not set';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get panelTrendLabel => 'Spending trend';

  @override
  String get panelTrendDesc => 'Spending trend and balance in 7-day periods';

  @override
  String get panelRecentLabel => 'Recent transactions';

  @override
  String get panelRecentDesc => 'Shows the 5 most recent transactions';

  @override
  String get panelBudgetLabel => 'Monthly budget';

  @override
  String get panelBudgetDesc =>
      'This month\'s budget progress and category overspend alerts';

  @override
  String get panelCalendarDesc =>
      'View daily income and spending on a calendar';

  @override
  String get panelBudgetExecutionLabel => 'Budget execution';

  @override
  String get panelBudgetExecutionDesc =>
      'This month\'s budget, spending and category budget execution';

  @override
  String get panelCategoryRingLabel => 'Category breakdown';

  @override
  String get panelCategoryRingDesc =>
      'Donut chart of this month\'s spending by category';

  @override
  String get panelCategoryRankLabel => 'Category details';

  @override
  String get panelCategoryRankDesc =>
      'This month\'s category ranking and share';

  @override
  String get panelTagStatsLabel => 'Tag stats';

  @override
  String get panelTagStatsDesc =>
      'Spending amount and share per tag this month';

  @override
  String get panelDailyTrendLabel => 'Daily trend';

  @override
  String get panelDailyTrendDesc => 'Daily spending trend for the last 7 days';

  @override
  String get panelMonthlyStructureLabel => 'Monthly overview';

  @override
  String get panelMonthlyStructureDesc =>
      'Bar chart of monthly spending this year';

  @override
  String panelCountLabel(int count, String page) {
    return '$count $page panels';
  }

  @override
  String panelPageTitle(String page) {
    return '$page panels';
  }

  @override
  String get panelSortHint => 'Drag the handles to reorder';

  @override
  String get panelToggleHint => 'Toggle and reorder';

  @override
  String get panelSortDone => 'Done sorting';

  @override
  String get panelSortStart => 'Reorder panels';

  @override
  String panelResetTitle(String page) {
    return 'Restore default $page panels?';
  }

  @override
  String get panelResetMessage =>
      'Restores the default order and enables all panels.';

  @override
  String get panelResetConfirm => 'Restore defaults';

  @override
  String panelKeepOneMessage(String page) {
    return 'Keep at least one $page panel enabled';
  }

  @override
  String get iconLabelCategory => 'Category';

  @override
  String get iconLabelDining => 'Dining';

  @override
  String get iconLabelTransport => 'Transport';

  @override
  String get iconLabelShopping => 'Shopping';

  @override
  String get iconLabelHousing => 'Housing';

  @override
  String get iconLabelEntertainment => 'Entertainment';

  @override
  String get iconLabelMedical => 'Medical';

  @override
  String get iconLabelSalary => 'Income';

  @override
  String get iconLabelInterest => 'Interest';

  @override
  String get iconLabelBonus => 'Bonus';

  @override
  String get iconLabelWork => 'Work';

  @override
  String get iconLabelTransferOut => 'Transfer out';

  @override
  String get iconLabelTransferIn => 'Transfer in';

  @override
  String get iconLabelRepayment => 'Repayment';

  @override
  String get iconLabelAdjust => 'Adjust';

  @override
  String get iconLabelPay => 'Payment';

  @override
  String get iconLabelWechat => 'WeChat';

  @override
  String get iconLabelCredit => 'Credit';

  @override
  String get iconLabelBank => 'Bank';

  @override
  String get iconLabelCash => 'Cash';

  @override
  String get iconLabelInvestment => 'Investment';

  @override
  String get iconLabelSavings => 'Savings';

  @override
  String get iconLabelCard => 'Card';

  @override
  String get iconLabelFolder => 'Group';

  @override
  String get iconLabelWallet => 'Wallet';

  @override
  String get iconGroupCredit => 'Credit accounts';

  @override
  String get iconGroupPayment => 'Payment platforms';

  @override
  String get iconGroupBank => 'Banks';

  @override
  String get balanceAdjustNote => 'Balance adjustment';

  @override
  String get commonNone => 'None';

  @override
  String get commonDone => 'Done';

  @override
  String get homeNoEntriesTitle => 'No transactions yet';

  @override
  String get homeNoEntriesDesc =>
      'Tap the plus button to record your first entry.';

  @override
  String trendNet(String amount) {
    return 'Net $amount';
  }

  @override
  String get homeDaysTracked => 'Days tracked';

  @override
  String daysCount(int count) {
    return '$count days';
  }

  @override
  String get homeDailyAvgExpense => 'Daily average';

  @override
  String dateMonthDay(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat('MMM d', localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String monthBudgetTitle(DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat.MMM(localeName);
    final String monthString = monthDateFormat.format(month);

    return '$monthString budget';
  }

  @override
  String get budgetRemaining => 'Remaining';

  @override
  String get budgetDailyRemaining => 'Daily remaining';

  @override
  String budgetTotalLabel(String amount) {
    return 'Budget $amount';
  }

  @override
  String get incomeExpenseTitle => 'Income & expense';

  @override
  String get homeNoStatsTitle => 'No data';

  @override
  String get homeNoStatsDesc => 'No records for this month.';

  @override
  String get statTypeTitle => 'Statistic type';

  @override
  String budgetCatOver(String category, String amount) {
    return '$category over by $amount';
  }

  @override
  String budgetCatUsed(String category, String percent) {
    return '$category used $percent%';
  }

  @override
  String entriesCount(int count) {
    return '$count entries';
  }

  @override
  String get categoryAll => 'All categories';

  @override
  String get tagPickerTitle => 'Select tags';
}
