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
  String get backupInvalidFile => 'The backup file is invalid or corrupted.';

  @override
  String get fileEmptyError => 'The file is empty.';

  @override
  String get dbErrorTitle => 'Couldn\'t open your data';

  @override
  String get dbErrorBody =>
      'Your data is most likely still safe on this device. Please do not clear the app\'s data or uninstall the app.';

  @override
  String get dbErrorHint =>
      'If you just installed an older version, please reinstall the latest version and try again. If the problem persists, take a screenshot of this page to report it.';

  @override
  String get dbErrorDetail => 'Error details';

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
  String get reimbursementFilterName => 'Reimbursement';

  @override
  String get reimbursementFilterTitle => 'Reimbursement status';

  @override
  String get reimbursementStatusAll => 'All';

  @override
  String get reimbursementReimbursed => 'Reimbursed';

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
  String accountRecurringRulesDisabled(int count) {
    return 'Disabled $count recurring rule(s) that used this account and cleared their account; please review them';
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
  String get entryTypeRefund => 'Refund';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accountTypeOnlinePayment => 'Online payment';

  @override
  String get accountTypeCreditAccount => 'Credit account';

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
  String get panelTrendDesc => 'Customizable data and trend chart';

  @override
  String get trendCustomizeTitle => 'Customize trend card';

  @override
  String get trendCustomizeEntry => 'Customize';

  @override
  String get trendCustomizeDisplayData => 'Displayed data';

  @override
  String get trendCustomizeChart => 'Chart';

  @override
  String get trendCustomizeTitleField => 'Card title';

  @override
  String get trendCustomizeTitleHint => 'Leave empty to show \"Overview\"';

  @override
  String get trendDefaultTitle => 'Overview';

  @override
  String get trendSlotBig => 'Headline number';

  @override
  String get trendSlotPill => 'Balance chip';

  @override
  String get trendSlotCard1 => 'Tile 1';

  @override
  String get trendSlotCard2 => 'Tile 2';

  @override
  String get trendSlotCard3 => 'Tile 3';

  @override
  String get trendSlotChart => 'Chart data';

  @override
  String get trendResetTitle => 'Reset trend card?';

  @override
  String get trendResetMessage =>
      'Restores the card title and all displayed data to defaults.';

  @override
  String get trendResetConfirm => 'Reset';

  @override
  String get pickMetricTitle => 'Pick data';

  @override
  String get pickChartSeriesTitle => 'Pick chart data';

  @override
  String get metricSeriesNet => 'Balance';

  @override
  String get metricGroupMonth => 'This month';

  @override
  String get metricGroupToday => 'Today';

  @override
  String get metricGroupWeek => 'This week';

  @override
  String get metricGroupYear => 'This year';

  @override
  String get metricGroupTotal => 'Total';

  @override
  String get metricGroupAssets => 'Assets';

  @override
  String get metricGroupReimburse => 'Reimbursement';

  @override
  String get metricMonthExpense => 'This month spending';

  @override
  String get metricMonthIncome => 'This month income';

  @override
  String get metricMonthNet => 'This month balance';

  @override
  String get metricDailyAvgExpense => 'Daily avg spending';

  @override
  String get metricDailyAvgIncome => 'Daily avg income';

  @override
  String get metricTodayExpense => 'Today spending';

  @override
  String get metricTodayIncome => 'Today income';

  @override
  String get metricTodayNet => 'Today balance';

  @override
  String get metricWeekExpense => 'This week spending';

  @override
  String get metricWeekIncome => 'This week income';

  @override
  String get metricWeekNet => 'This week balance';

  @override
  String get metricYearExpense => 'This year spending';

  @override
  String get metricYearIncome => 'This year income';

  @override
  String get metricTotalExpense => 'Total spending';

  @override
  String get metricTotalIncome => 'Total income';

  @override
  String get metricTotalNet => 'Total balance';

  @override
  String get metricTotalAssets => 'Total assets';

  @override
  String get metricTotalLiabilities => 'Liabilities';

  @override
  String get metricNetAssets => 'Net assets';

  @override
  String get metricReimbursablePending => 'Reimbursable';

  @override
  String get metricReimbursed => 'Reimbursed';

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
  String get statPeriodWeek => 'Week';

  @override
  String get statPeriodMonth => 'Month';

  @override
  String get statPeriodQuarter => 'Quarter';

  @override
  String get statPeriodYear => 'Year';

  @override
  String statQuarterRange(int year, int quarter) {
    return '$year Q$quarter';
  }

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

  @override
  String get coverBlueCity => 'Blue city';

  @override
  String get coverAurora => 'Aurora night';

  @override
  String get coverFinanceOffice => 'Finance office';

  @override
  String get coverDeepBlue => 'Deep blue';

  @override
  String get assetsUngrouped => 'Ungrouped';

  @override
  String get netAssets => 'Net worth';

  @override
  String get assetsActions => 'Asset actions';

  @override
  String get assetsChangeCover => 'Change card background';

  @override
  String assetsAmount(String amount) {
    return 'Assets $amount';
  }

  @override
  String liabilitiesAmount(String amount) {
    return 'Liabilities $amount';
  }

  @override
  String netAssetsAmount(String amount) {
    return 'Net worth $amount';
  }

  @override
  String monthNumber(int month) {
    return 'M$month';
  }

  @override
  String get assetsEmptyTitle => 'No accounts yet';

  @override
  String get assetsEmptyDesc =>
      'Add an account from the top right; you can then view assets by type or group here.';

  @override
  String get assetsSortHint =>
      'Drag the handles on the right to reorder sections';

  @override
  String hiddenAccountsCount(int count) {
    return '$count hidden accounts';
  }

  @override
  String get assetsCoverTitle => 'Asset card background';

  @override
  String get coverUseOnline => 'Use online image';

  @override
  String get coverEnterUrl => 'Enter image URL';

  @override
  String get coverPickLocal => 'Choose local image';

  @override
  String get coverClear => 'Clear background image';

  @override
  String get coverPickOnlineTitle => 'Choose online image';

  @override
  String get coverCustomTitle => 'Custom image';

  @override
  String get coverUrlLabel => 'Image URL';

  @override
  String get coverCropTitle => 'Crop background';

  @override
  String get coverGenerating => 'Generating background…';

  @override
  String get accountAdd => 'Add account';

  @override
  String get groupManage => 'Manage groups';

  @override
  String get sectionSort => 'Sort sections';

  @override
  String get sectionSortNeedTwo => 'Need at least 2 sections to sort';

  @override
  String get sortLabel => 'Sort';

  @override
  String get hiddenAccountsTitle => 'Hidden accounts';

  @override
  String get hiddenAccountsEmptyTitle => 'No hidden accounts';

  @override
  String get hiddenAccountsEmptyDesc => 'Hidden accounts appear here.';

  @override
  String get accountGroupsTitle => 'Account groups';

  @override
  String get groupAdd => 'New group';

  @override
  String get groupsEmptyTitle => 'No account groups yet';

  @override
  String get groupsEmptyDesc =>
      'Tap the plus at top right to create groups for organizing accounts.';

  @override
  String accountsCount(int count) {
    return '$count accounts';
  }

  @override
  String get commonRename => 'Rename';

  @override
  String get commonIcon => 'Icon';

  @override
  String get groupRenameTitle => 'Rename group';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get groupIconPickerTitle => 'Choose group icon';

  @override
  String get accountIconLabel => 'Account icon';

  @override
  String get accountSaveTooltip => 'Save account';

  @override
  String get accountTypeLabel => 'Account type';

  @override
  String get accountNameLabel => 'Account name';

  @override
  String get accountNameRequired => 'Account name is required';

  @override
  String get cardLast4Label => 'Last 4 digits';

  @override
  String get cardLast4Invalid => 'Enter 1-4 digits';

  @override
  String get cardLabel => 'Card number';

  @override
  String get cardNumberLabel => 'Full card number (optional)';

  @override
  String get cardNumberTitle => 'Full card number';

  @override
  String get cardLast4Follow => 'Follow number';

  @override
  String get cardCopyTooltip => 'Copy card number';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get accountSectionBasic => 'Basic info';

  @override
  String get accountSectionCard => 'Card details';

  @override
  String get accountSectionCredit => 'Credit';

  @override
  String get accountSectionDisplay => 'Display & bookkeeping';

  @override
  String get accountSectionDanger => 'Danger zone';

  @override
  String get accountBalanceLabel => 'Account balance';

  @override
  String get accountBalanceHint => 'Defaults to 0';

  @override
  String get accountNoteLabel => 'Account note';

  @override
  String get accountGroupLabel => 'Account group';

  @override
  String get accountTypePickerTitle => 'Choose account type';

  @override
  String get accountGroupPickerTitle => 'Choose account group';

  @override
  String get balanceAdjustTooltip => 'Adjust balance';

  @override
  String get currentBalance => 'Current balance';

  @override
  String get balanceTrend => 'Balance trend';

  @override
  String get dayShort => 'Day';

  @override
  String get monthShort => 'Month';

  @override
  String balanceAmount(String amount) {
    return 'Balance $amount';
  }

  @override
  String get viewReport => 'View report';

  @override
  String get addEntryTooltip => 'Add entry';

  @override
  String get noEntriesTitle => 'No transactions';

  @override
  String get accountNoEntriesDesc => 'This account has no transactions yet.';

  @override
  String accountEntriesTitle(String name) {
    return '$name transactions';
  }

  @override
  String get allEntries => 'All transactions';

  @override
  String get includeInAssets => 'Count in assets';

  @override
  String get commonType => 'Type';

  @override
  String get commonName => 'Name';

  @override
  String get notSet => 'Not set';

  @override
  String get clearOption => 'Don\'t set';

  @override
  String get statementDay => 'Statement day';

  @override
  String get dueDay => 'Due day';

  @override
  String get creditLimitLabel => 'Credit limit';

  @override
  String get creditLimitEditTitle => 'Set credit limit';

  @override
  String get creditUsedLabel => 'Used';

  @override
  String get creditAvailableLabel => 'Available';

  @override
  String get currentBillLabel => 'This cycle';

  @override
  String get creditRepayTitle => 'Repayment';

  @override
  String get creditRepayAction => 'Repay';

  @override
  String get creditRepayAmountLabel => 'Repayment amount';

  @override
  String get creditRepayFromAccount => 'Payment account';

  @override
  String get creditRepayNoAccountLabel => 'No account (paid by others)';

  @override
  String get creditRepayNoAccountHint =>
      'Paid by someone else; no account deducted';

  @override
  String get creditRepayDefaultNote => 'Repayment';

  @override
  String get creditRepaySuccess => 'Repayment recorded';

  @override
  String monthlyDayLabel(int day) {
    return 'Day $day of each month';
  }

  @override
  String get commonCurrency => 'Currency';

  @override
  String get currencyCny => 'CNY';

  @override
  String get commonNote => 'Note';

  @override
  String get commonNoneShort => 'None';

  @override
  String get commonGroup => 'Group';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get deletableLabel => 'Deletable';

  @override
  String get hasEntriesLabel => 'Has transactions';

  @override
  String get balanceEditConfirmTitle => 'Confirm balance change?';

  @override
  String balanceEditConfirmMessage(String name, String amount) {
    return 'This sets the balance of \"$name\" to $amount.';
  }

  @override
  String get balanceEditRecord => 'Record as entry';

  @override
  String get balanceEditRecordDesc =>
      'Creates a balance-adjustment entry; if unchecked, the initial balance is changed directly without affecting statistics.';

  @override
  String get accountNameEditTitle => 'Edit account name';

  @override
  String get cardLast4EditTitle => 'Edit last 4 digits';

  @override
  String get pickDueDay => 'Choose due day';

  @override
  String get pickStatementDay => 'Choose statement day';

  @override
  String get accountNoteEditTitle => 'Edit account note';

  @override
  String get accountReportTitle => 'Account report';

  @override
  String get thisMonth => 'This month';

  @override
  String get dueToday => 'due today';

  @override
  String dueInDays(int days) {
    return '$days days left';
  }

  @override
  String monthlyRepayLine(int day) {
    return 'Repay on day $day of each month';
  }

  @override
  String get attachTakePhoto => 'Take photo';

  @override
  String get attachFromGallery => 'Choose from gallery';

  @override
  String get attachTitle => 'Attachments';

  @override
  String attachCount(int count) {
    return '$count images';
  }

  @override
  String get attachUnsupported =>
      'Adding attachments isn\'t supported on this platform';

  @override
  String get attachDeleteTooltip => 'Remove this image';

  @override
  String get entryDetailSubtitle => 'Entry detail';

  @override
  String get commonCategory => 'Category';

  @override
  String get allLabel => 'All';

  @override
  String get transferOutAccount => 'From account';

  @override
  String get transferInAccount => 'To account';

  @override
  String get pleaseSelect => 'Select';

  @override
  String get feeLabel => 'Fee';

  @override
  String get feeNoneTapToFill => 'None (tap to set)';

  @override
  String get accountLabel => 'Account';

  @override
  String get noAccountLabel => 'No account';

  @override
  String get noAccountHint =>
      'Record just an amount; it won\'t affect any account balance';

  @override
  String get noUsableAccountTitle => 'No available account';

  @override
  String get noUsableAccountDesc =>
      'Add or unhide an account on the Assets page first.';

  @override
  String get noteHint => 'Tap to add a note';

  @override
  String get commonSave => 'Save';

  @override
  String get amountEditTitle => 'Edit amount';

  @override
  String get transferFeeTitle => 'Transfer fee';

  @override
  String get pickTransferOutAccount => 'Choose source account';

  @override
  String get pickAccountTitle => 'Choose account';

  @override
  String get pickTransferInAccount => 'Choose destination account';

  @override
  String get timeAll => 'All time';

  @override
  String get timeYear => 'This year';

  @override
  String get timeQuarter => 'This quarter';

  @override
  String get timeWeek => 'This week';

  @override
  String get timeLast12Months => 'Last 12 months';

  @override
  String get timeLast30Days => 'Last 30 days';

  @override
  String get timeLast6Weeks => 'Last 6 weeks';

  @override
  String get sortDateDesc => 'Date, newest first';

  @override
  String get sortDateAsc => 'Date, oldest first';

  @override
  String get sortAmountDesc => 'Amount, high to low';

  @override
  String get sortAmountAsc => 'Amount, low to high';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get dayEntriesTitle => 'Day\'s transactions';

  @override
  String get entriesListTitle => 'Transactions';

  @override
  String get exitMultiSelect => 'Exit multi-select';

  @override
  String get multiSelect => 'Multi-select';

  @override
  String entriesCountFull(int count) {
    return '$count transactions';
  }

  @override
  String get netLabel => 'Net';

  @override
  String get noMatchTitle => 'No matching transactions';

  @override
  String get noMatchDesc => 'Try a different keyword, account, or category.';

  @override
  String get emptyEntriesDesc => 'Saved transactions appear here by date.';

  @override
  String get filterTimeTitle => 'Filter by time';

  @override
  String get sortTitle => 'Sort order';

  @override
  String get filterAccountTitle => 'Filter by account';

  @override
  String get allAccounts => 'All accounts';

  @override
  String get filterCategoryTitle => 'Filter by category';

  @override
  String get filterTagTitle => 'Filter by tag';

  @override
  String get allTags => 'All tags';

  @override
  String get unknownTag => 'Unknown tag';

  @override
  String get tagLabel => 'Tag';

  @override
  String deleteEntriesTitle(int count) {
    return 'Delete $count transactions?';
  }

  @override
  String get deleteEntriesMessage =>
      'This cannot be undone; related attachments are removed too.';

  @override
  String get changeCategoryTitle => 'Change category (same-type entries only)';

  @override
  String changedCategoryCount(int count) {
    return 'Changed category of $count transactions';
  }

  @override
  String get changeAccountTitle => 'Change account';

  @override
  String changedAccountCount(int count) {
    return 'Changed account of $count transactions';
  }

  @override
  String yearLabel(int year) {
    return '$year';
  }

  @override
  String quarterLabel(int quarter) {
    return 'Q$quarter';
  }

  @override
  String weekNumber(int week) {
    return 'W$week';
  }

  @override
  String yearWeek(int year, int week) {
    return '$year W$week';
  }

  @override
  String get prevRange => 'Previous';

  @override
  String get nextRange => 'Next';

  @override
  String get searchHint => 'Search notes, categories, accounts, or amounts';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get prevDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get entryMissing => 'Transaction not found';

  @override
  String get deleteEntryTooltip => 'Delete transaction';

  @override
  String get saveEntryTooltip => 'Save transaction';

  @override
  String get amountLabel => 'Amount';

  @override
  String get dateLabel => 'Date';

  @override
  String get timeLabel => 'Time';

  @override
  String get markReimbursable => 'Mark reimbursable';

  @override
  String get refundLabel => 'Refund / reimbursement';

  @override
  String refundedAmountLabel(String amount) {
    return 'Offset $amount';
  }

  @override
  String get refundAmountTitle => 'Refund / reimbursement amount';

  @override
  String get refundRecordsTitle => 'Refunds';

  @override
  String get refundAdd => 'Add refund';

  @override
  String get refundEditTitle => 'Edit refund';

  @override
  String get refundStatusSettled => 'Received';

  @override
  String get refundStatusPending => 'Pending';

  @override
  String get refundToAccountLabel => 'Destination account';

  @override
  String get refundArrivalDateLabel => 'Arrival date';

  @override
  String get refundInitiatedDateLabel => 'Initiated date';

  @override
  String get refundAmountShort => 'Refund amount';

  @override
  String get refundIsSettledLabel => 'Received (money is back)';

  @override
  String get refundMarkSettled => 'Mark as received';

  @override
  String get refundEmpty => 'No refunds yet — add one below';

  @override
  String get refundDeleteConfirm =>
      'Delete this refund? The original expense\'s net will be restored.';

  @override
  String refundRemainingLabel(String amount) {
    return 'Refundable: $amount';
  }

  @override
  String refundOverCapNotice(String amount) {
    return 'Refund can\'t exceed the refundable amount; capped to $amount';
  }

  @override
  String refundNetLabel(String amount) {
    return 'Net expense $amount';
  }

  @override
  String refundSummaryLine(int count, String net) {
    return '$count refund(s) · net $net';
  }

  @override
  String refundPendingTotal(String amount) {
    return 'Pending $amount';
  }

  @override
  String get pendingRefundsTitle => 'Pending refunds';

  @override
  String get pendingRefundsSubtitle => 'Refunds requested but not yet received';

  @override
  String get pendingRefundsEmpty => 'No pending refunds';

  @override
  String pendingRefundsCount(int count) {
    return '$count on the way';
  }

  @override
  String get pickTypeTitle => 'Choose type';

  @override
  String get noteEditTitle => 'Edit note';

  @override
  String get transferNeedsTwoAccounts =>
      'Transfers need two different accounts; add a destination account first.';

  @override
  String get deleteEntryTitle => 'Delete this transaction?';

  @override
  String get deleteEntryMessage =>
      'This cannot be undone; the locally saved record will be removed.';

  @override
  String get todayLabel => 'Today';

  @override
  String get yesterdayLabel => 'Yesterday';

  @override
  String get selectAll => 'Select all';

  @override
  String get changeCategoryShort => 'Category';

  @override
  String get changeAccountShort => 'Account';

  @override
  String get budgetSettingsTitle => 'Budget settings';

  @override
  String yearMonth(DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat(
      'MMM y',
      localeName,
    );
    final String monthString = monthDateFormat.format(month);

    return '$monthString';
  }

  @override
  String get budgetUsed => 'Used';

  @override
  String get budgetOverspentThisMonth => 'Over budget this month';

  @override
  String get budgetAvailableThisMonth => 'Available this month';

  @override
  String get budgetMonthExpense => 'This month\'s spending';

  @override
  String get budgetOverAmountLabel => 'Over budget';

  @override
  String get budgetRemainingQuota => 'Remaining';

  @override
  String get budgetAmountLabel => 'Budget amount';

  @override
  String get categoryBudgetTitle => 'Category budgets';

  @override
  String get monthExpenseCategories => 'This month\'s expense categories';

  @override
  String get noExpenseCategories => 'No expense categories yet';

  @override
  String get setMonthBudgetTitle => 'Set this month\'s budget';

  @override
  String get monthBudgetAmountLabel => 'Monthly budget amount';

  @override
  String get dailyBudgetTitle => 'Daily budget';

  @override
  String get dailyBudgetNotSet => 'No daily limit set — tap to configure';

  @override
  String dailyBudgetLimitLabel(String amount) {
    return 'Daily limit $amount';
  }

  @override
  String get dailyBudgetTodaySpent => 'Spent today';

  @override
  String get dailyBudgetTodayLeft => 'Left today';

  @override
  String get dailyBudgetTodayOver => 'Over today';

  @override
  String get setDailyBudgetTitle => 'Set daily budget';

  @override
  String get dailyBudgetAmountLabel => 'Daily budget amount';

  @override
  String setCategoryBudgetTitle(String category) {
    return 'Set $category budget';
  }

  @override
  String get categoryBudgetAmountLabel => 'Category budget amount';

  @override
  String get budgetHistoryTitle => 'Budget history';

  @override
  String get last12MonthsSub => 'Last 12 months';

  @override
  String get monthSummary => 'Monthly summary';

  @override
  String get last6MonthsTrend => '6-month trend';

  @override
  String get budgetLegend => 'Budget';

  @override
  String expenseAmountLabel(String amount) {
    return 'Spent $amount';
  }

  @override
  String get historyCompare => 'History comparison';

  @override
  String get lastMonthExpense => 'Last month\'s spending';

  @override
  String get noExpenseYet => 'No spending';

  @override
  String get compareBaseline => 'Comparison baseline';

  @override
  String budgetUsageLine(String percent, String delta) {
    return 'Budget usage $percent%, $delta vs last month';
  }

  @override
  String get notSetBudget => 'No budget set';

  @override
  String overBy(String amount) {
    return 'Over by $amount';
  }

  @override
  String remainingAmount(String amount) {
    return '$amount left';
  }

  @override
  String budgetHistoryLine(String budget, String expense, String percent) {
    return 'Budget $budget · Spent $expense · $percent% used';
  }

  @override
  String get categoryBudgetOk => 'Category budgets on track';

  @override
  String categoryOverspent(String category) {
    return '$category over budget';
  }

  @override
  String categoryNearBudget(String category) {
    return '$category near budget';
  }

  @override
  String categoryBudgetOkDesc(int count) {
    return '$count category budgets set; none is close to overspending.';
  }

  @override
  String categoryOverspentDesc(String amount, String percent) {
    return 'Over by $amount; $percent% used this month.';
  }

  @override
  String categoryNearDesc(String amount, String percent) {
    return '$amount left; $percent% used this month.';
  }

  @override
  String catNoBudgetLine(String amount) {
    return 'No budget · spent $amount this month';
  }

  @override
  String catRemainLine(String amount, String percent) {
    return '$amount left · $percent% used';
  }

  @override
  String catOverLine(String amount, String percent) {
    return 'Over by $amount · $percent% used';
  }

  @override
  String get lastMonthNone => 'No spending last month';

  @override
  String lastMonthAmount(String amount) {
    return 'Last month $amount';
  }

  @override
  String get setLabel => 'Set';

  @override
  String get monthEnded => 'Month ended';

  @override
  String remainingDaysInclToday(int days) {
    return '$days days left incl. today';
  }

  @override
  String monthTotalDays(int days) {
    return '$days days this month';
  }

  @override
  String get budgetTipNoneTitle => 'No budget yet';

  @override
  String get budgetTipNoneDesc =>
      'Once you set this month\'s budget, progress, remaining quota, and daily allowance show here and on Home.';

  @override
  String get budgetTipOverTitle => 'Budget exceeded';

  @override
  String budgetTipOverDesc(String amount) {
    return 'Spending exceeds the budget by $amount; further spending still counts toward this month.';
  }

  @override
  String get budgetTipNearTitle => 'Budget nearly used up';

  @override
  String budgetTipNearDesc(String percent, String amount) {
    return '$percent% of this month\'s budget used; $amount left.';
  }

  @override
  String get budgetTipOkTitle => 'Budget on track';

  @override
  String budgetTipOkDesc(String amount) {
    return 'At the current pace, about $amount per day is available for the rest of the month.';
  }

  @override
  String get budgetTipEndedTitle => 'Month settled';

  @override
  String get budgetTipEndedDesc =>
      'This month has ended; switch months to review or adjust budgets.';

  @override
  String get deltaFlatVsLastMonth => 'Same as last month';

  @override
  String deltaMoreVsLastMonth(String amount) {
    return '$amount more than last month';
  }

  @override
  String deltaLessVsLastMonth(String amount) {
    return '$amount less than last month';
  }

  @override
  String get usageFlat => 'flat';

  @override
  String usageUp(String points) {
    return 'up $points pts';
  }

  @override
  String usageDown(String points) {
    return 'down $points pts';
  }

  @override
  String get statAnalysisTitle => 'Analytics';

  @override
  String get pickTimeRange => 'Select time range';

  @override
  String get okLabel => 'OK';

  @override
  String get customRange => 'Custom';

  @override
  String get overviewTitle => 'Overview';

  @override
  String get yoyMomTitle => 'YoY · MoM';

  @override
  String get yoyMomDesc =>
      'MoM compares to last month; YoY to the same month last year';

  @override
  String get momLabel => 'MoM';

  @override
  String get yoyLabel => 'YoY';

  @override
  String get monthlyTrendTitle => 'Monthly trend';

  @override
  String get categoryRank => 'Category ranking';

  @override
  String get rankGroupCategory => 'Category';

  @override
  String get rankGroupSubCategory => 'Subcategory';

  @override
  String get rankGroupTag => 'Tag';

  @override
  String get tagRank => 'Tag ranking';

  @override
  String get tagRankOverlapNote =>
      'An entry can carry multiple tags, so the percentages may add up to more than 100%';

  @override
  String subCategoryOf(String name) {
    return 'Subcategories of \"$name\"';
  }

  @override
  String noDimData(String dim) {
    return 'No $dim data';
  }

  @override
  String noDimDesc(String dim) {
    return 'No $dim records in this time range.';
  }

  @override
  String get reportsSubtitle => 'Dashboard';

  @override
  String get noCategoryData => 'No category data';

  @override
  String get noCategoryDesc =>
      'Expense records will show a category ranking here.';

  @override
  String get thisYearLabel => 'This year';

  @override
  String get noTagData => 'No tag data';

  @override
  String get noTagDesc =>
      'Tag your transactions to see spending summarized by tag.';

  @override
  String get overBudgetLabel => 'Over budget';

  @override
  String get remainingBudgetLabel => 'Remaining budget';

  @override
  String get expenseOnlyNote => 'Expenses only';

  @override
  String usedPercent(String percent) {
    return '$percent% used';
  }

  @override
  String get monthBudgetLabel => 'This month\'s budget';

  @override
  String countItems(int count) {
    return '$count';
  }

  @override
  String overCountLabel(int count) {
    return '$count over budget';
  }

  @override
  String get normalLabel => 'OK';

  @override
  String get othersLabel => 'Others';

  @override
  String tagShareOfExpense(String percent) {
    return '$percent% of spending';
  }

  @override
  String get bookkeepingDays => 'Days tracked';

  @override
  String get bookkeepingYears => 'Years tracked';

  @override
  String get reminderPickTime => 'Choose reminder time';

  @override
  String get reminderTitle => 'Daily reminder';

  @override
  String get reminderDaily => 'Daily reminder';

  @override
  String get reminderTimeLabel => 'Reminder time';

  @override
  String get reminderDescSupported =>
      'When enabled, a local notification arrives daily at the set time to remind you to record the day\'s spending. If it stops appearing, check that notifications are allowed in system settings.';

  @override
  String get reminderDescUnsupported =>
      'Local notifications aren\'t supported on this platform; this setting only works on Android / iOS phones.';

  @override
  String reminderDailyAt(String time) {
    return 'Daily $time';
  }

  @override
  String get recurringTitle => 'Recurring';

  @override
  String get recurringSubtitle =>
      'Due entries are recorded automatically when the app opens';

  @override
  String get recurringAddTooltip => 'New rule';

  @override
  String get recurringEmpty =>
      'No recurring rules yet. Tap + at top right to add one,\ne.g. monthly rent or salary.';

  @override
  String nextRun(String date) {
    return 'Next $date';
  }

  @override
  String get recurringNewTitle => 'New recurring rule';

  @override
  String get recurringEditTitle => 'Edit recurring rule';

  @override
  String get recurringDeleteTooltip => 'Delete rule';

  @override
  String get tapToFill => 'Tap to set';

  @override
  String get addAccountFirst => 'Add an account first';

  @override
  String get frequencyLabel => 'Frequency';

  @override
  String get startDateLabel => 'Start date';

  @override
  String get pickFrequencyTitle => 'Choose frequency';

  @override
  String get skipLabel => 'Skip';

  @override
  String get startBookkeeping => 'Start';

  @override
  String get nextStep => 'Next';

  @override
  String get onboardWelcomeTitle => 'Welcome to Veri Fin';

  @override
  String get onboardWelcomeDesc =>
      'A completely free, local-first budgeting app where your data stays yours.\n\nYour records live only on this device and are never uploaded; you can export a JSON backup anytime or encrypt and upload it to your own WebDAV.\n\nA few quick steps will get you started.';

  @override
  String get onboardAccountTitle => 'Create your first account';

  @override
  String get onboardAccountDesc =>
      'Accounts are the basis of bookkeeping, e.g. \"Cash\" or \"Salary card\". Just enter a name and current balance — you can also add accounts later on the Assets page.';

  @override
  String get onboardAccountNameLabel => 'Account name (optional)';

  @override
  String get onboardAccountNameHint => 'e.g. Cash / Salary card';

  @override
  String get onboardBalanceLabel => 'Current balance (optional)';

  @override
  String get onboardBudgetDesc =>
      'With a monthly budget set, Home and Reports show budget progress to help control spending. Leave blank to skip; you can change it anytime from the budget card on Home.';

  @override
  String get onboardBudgetLabel => 'This month\'s budget (optional)';

  @override
  String get onboardBudgetHint => 'e.g. 3000';

  @override
  String get onboardDoneTitle => 'All set';

  @override
  String get onboardDoneDesc =>
      'Tap the + button at the bottom right of Home to record an entry.\n\nOn the Me page you can manage ledgers, categories, tags and recurring entries, view analytics, and set reminders and backups.\n\nHappy budgeting!';

  @override
  String legalUpdated(String date) {
    return 'Updated: $date';
  }

  @override
  String get privacyAndTerms => 'Privacy Policy & Terms';

  @override
  String get agreeContinue => 'Agree and continue';

  @override
  String get disagreeExit => 'Disagree and exit';

  @override
  String get legalPrivacyPolicy => 'Privacy Policy';

  @override
  String get legalUserAgreement => 'Terms of Service';

  @override
  String get profileCenterSubtitle => 'Profile';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get entryCountStat => 'Transactions';

  @override
  String get bookkeepingMgmt => 'Bookkeeping';

  @override
  String get ledgerLabel => 'Ledgers';

  @override
  String get categoryMgmt => 'Categories';

  @override
  String get tagMgmt => 'Tags';

  @override
  String countRules(int count) {
    return '$count rules';
  }

  @override
  String get dataAndTools => 'Data & tools';

  @override
  String get reportShort => 'Reports';

  @override
  String get notEnabled => 'Off';

  @override
  String get dataManagement => 'Data management';

  @override
  String get backupRestoreShort => 'Backup / restore';

  @override
  String currentBookLabel(String name) {
    return 'Current: $name';
  }

  @override
  String get bookAdd => 'New ledger';

  @override
  String get bookNameLabel => 'Ledger name';

  @override
  String get defaultBookLabel => 'Default ledger';

  @override
  String get bookActions => 'Ledger actions';

  @override
  String get defaultBookUndeletable => 'Default ledger can\'t be deleted';

  @override
  String get bookRenameTitle => 'Rename ledger';

  @override
  String get bookDeleteTitle => 'Delete ledger?';

  @override
  String bookDeleteMessage(String name) {
    return 'Ledger \"$name\" and its transactions will be deleted. This cannot be undone.';
  }

  @override
  String get categoryMgmtSubtitle =>
      'Multi-level categories for entries and statistics';

  @override
  String get addTopCategory => 'New top-level category';

  @override
  String addCategoryTitle(String type) {
    return 'New $type category';
  }

  @override
  String addSubCategoryTitle(String parent) {
    return 'New subcategory under \"$parent\"';
  }

  @override
  String get categoryNameLabel => 'Category name';

  @override
  String get changeIcon => 'Change icon';

  @override
  String get addSubCategory => 'New subcategory';

  @override
  String get moveTo => 'Move to…';

  @override
  String get deleteCategory => 'Delete category';

  @override
  String get noMoveTarget => 'No available destination';

  @override
  String moveCategoryTitle(String name) {
    return 'Move \"$name\" to';
  }

  @override
  String get topCategory => 'Top level';

  @override
  String get cannotMoveHere => 'Can\'t move the category here';

  @override
  String get mergeCategory => 'Merge into another category';

  @override
  String mergeCategoryPickTitle(String name) {
    return 'Merge \"$name\" into';
  }

  @override
  String get mergeCategoryConfirmTitle => 'Merge category?';

  @override
  String mergeCategoryConfirmMessage(String source, int count, String target) {
    return '$count transactions in \"$source\" will be moved into \"$target\", then \"$source\" will be deleted. This can\'t be undone.';
  }

  @override
  String get mergeCategoryConfirmButton => 'Merge';

  @override
  String mergedCategoryResult(int count, String target) {
    return 'Moved $count transactions into \"$target\"';
  }

  @override
  String get mergeCategoryFailed => 'Can\'t merge this category';

  @override
  String get renameCategoryTitle => 'Rename category';

  @override
  String get pickIconTitle => 'Choose icon';

  @override
  String get iconSectionBuiltin => 'Built-in icons';

  @override
  String get iconSectionEmoji => 'Emoji';

  @override
  String get iconEmojiHint => 'Type or paste an emoji';

  @override
  String get iconEmojiUse => 'Use';

  @override
  String get systemCategoryUndeletable => 'System categories can\'t be deleted';

  @override
  String categoryInUse(int count) {
    return '$count transactions use this category; it can\'t be deleted';
  }

  @override
  String categoryUsedByRecurring(int count) {
    return 'This category is used by $count recurring rule(s); update or delete them first';
  }

  @override
  String get moveSubFirst => 'Move or delete its subcategories first';

  @override
  String get keepOneCategory => 'Keep at least one category';

  @override
  String get deleteCategoryTitle => 'Delete category?';

  @override
  String deleteCategoryMessage(String name) {
    return 'Category \"$name\" cannot be restored once deleted.';
  }

  @override
  String get categoryUndeletable => 'This category can\'t be deleted right now';

  @override
  String catSubChildren(String type, int children, int count) {
    return '$type · $children subcategories · $count entries';
  }

  @override
  String catSubPlain(String type, int count) {
    return '$type · $count transactions';
  }

  @override
  String get tagMgmtSubtitle => 'Add multiple tags to entries';

  @override
  String get tagAdd => 'New tag';

  @override
  String get tagsEmpty => 'No tags yet; tap + at top right';

  @override
  String get deleteTag => 'Delete tag';

  @override
  String get tagRenameTitle => 'Rename tag';

  @override
  String get tagDeleteTitle => 'Delete tag?';

  @override
  String tagDeleteInUse(String name, int count) {
    return 'Tag \"$name\" is used by $count transactions; deleting removes it from them.';
  }

  @override
  String tagDeleteMessage(String name) {
    return 'Tag \"$name\" cannot be restored once deleted.';
  }

  @override
  String get personalInfo => 'Personal info';

  @override
  String get nicknameLabel => 'Nickname';

  @override
  String get nicknameEmptyTitle => 'No nickname set';

  @override
  String get nicknameEmptyMessage =>
      'You haven\'t set a nickname. The default \"Veri Fin\" will be used. Save anyway?';

  @override
  String get bioLabel => 'Bio';

  @override
  String get genderLabel => 'Gender';

  @override
  String get birthdayLabel => 'Birthday';

  @override
  String get cityLabel => 'City';

  @override
  String get occupationLabel => 'Occupation';

  @override
  String get pickGenderTitle => 'Choose gender';

  @override
  String get cropAvatarTitle => 'Crop avatar';

  @override
  String get avatarGenerating => 'Generating avatar…';

  @override
  String get profileDefaultBio => 'Completely free · Own your data';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionBookkeeping => 'Bookkeeping';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get themeMode => 'Theme';

  @override
  String get hapticsLabel => 'Haptic feedback';

  @override
  String get amountTwoDecimalsLabel => 'Two decimal places';

  @override
  String get amountTwoDecimalsDesc =>
      'Always show amounts with two decimals (e.g. 12 becomes 12.00)';

  @override
  String get appLockLabel => 'App lock';

  @override
  String get enabledLabel => 'On';

  @override
  String get checkUpdate => 'Check for updates';

  @override
  String get viewLabel => 'View';

  @override
  String get themePickerTitle => 'Choose theme';

  @override
  String get dataMgmtSubtitle => 'Back up and restore local data';

  @override
  String get exportData => 'Export to file';

  @override
  String get jsonBackup => 'Save to system Downloads';

  @override
  String get importData => 'Restore from file';

  @override
  String get restoreFromFile => 'Pick a backup file';

  @override
  String get importFromSheets => 'Import bills';

  @override
  String get dataSectionLocalBackup => 'Local backup';

  @override
  String get dataSectionMaintenance => 'Maintenance';

  @override
  String get downloadCsvTemplate => 'Download CSV template';

  @override
  String get excelHint => 'Excel can save as CSV';

  @override
  String get importBillFile => 'Import bill file';

  @override
  String get importBillFileHint => 'Alipay / WeChat / Mint';

  @override
  String get selectBillSource => 'Choose bill source';

  @override
  String get selectBillSourceHint =>
      'Pick the platform first, then its exported file — avoids format mis-detection';

  @override
  String get platformAlipay => 'Alipay';

  @override
  String get platformAlipayHint => 'Transaction detail CSV';

  @override
  String get platformWechat => 'WeChat Pay';

  @override
  String get platformWechatHint => 'Payment bill xlsx';

  @override
  String get platformMint => 'Mint (Bohe)';

  @override
  String get platformMintHint => 'Bill CSV';

  @override
  String get platformYimuBill => 'YiMu · Bills';

  @override
  String get platformYimuBillHint => 'Bill export (.xls)';

  @override
  String get platformYimuTransfer => 'YiMu · Transfers';

  @override
  String get platformYimuTransferHint => 'Transfer export (.xls)';

  @override
  String get platformTally => 'Tally';

  @override
  String get platformTallyHint => 'Backup zip';

  @override
  String get platformGenericCsv => 'Other CSV';

  @override
  String get platformGenericCsvHint => 'Qianji / Suishouji / template';

  @override
  String billImportGuideTitle(String source) {
    return 'How to export $source bills';
  }

  @override
  String get alipayImportGuide =>
      'In Alipay: Me → Bills → top-right \"…\" → Issue transaction statement → For personal reconciliation → pick a date range. The CSV arrives by email; download it to your phone, then choose it here.\n\nNon-income/expense rows (repayments, investments, transfers) are skipped automatically to avoid double counting. Menu paths may vary by app version.';

  @override
  String get wechatImportGuide =>
      'In WeChat: Me → Services → Wallet → Bills → top-right FAQ → Download bill → For personal reconciliation → pick a date range. The xlsx arrives by email; download it to your phone, then choose it here.\n\nNeutral transactions (withdrawals, investments, repayments) are skipped automatically. Menu paths may vary by app version.';

  @override
  String get mintImportGuide =>
      'In Mint (Bohe): Me → ledger/data settings → Export bill (CSV), save it to your phone, then choose it here. Menu paths may vary by app version.';

  @override
  String get yimuBillImportGuide =>
      'In YiMu (一木记账): Me → Import/Export → Export data → Export bills, choose Excel (.xls) and save it to your phone, then choose it here.\n\nImports income/expense bills only; categories use the second-level category. For transfers, use the separate \"YiMu · Transfers\" entry. Menu paths may vary by app version.';

  @override
  String get yimuTransferImportGuide =>
      'In YiMu (一木记账): Me → Import/Export → Export data → Export transfers, choose Excel (.xls) and save it to your phone, then choose it here.\n\nImports transfer records, keeping both accounts and the fee. For income/expense bills, use the separate \"YiMu · Bills\" entry. Menu paths may vary by app version.';

  @override
  String get tallyImportGuide =>
      'In Tally (记账): Settings → Data backup & restore → Export backup, which produces a .zip file starting with \"Tally\". Save it to your phone, then choose it here.\n\nPick the backup zip rather than the CSV bill export: the backup keeps exact transaction times, and income/expense/transfers, first- and second-level categories, accounts and notes are all imported (categories use the second-level category). Menu paths may vary by app version.';

  @override
  String get genericCsvImportGuide =>
      'Supports CSV exported from Qianji, Suishouji, etc., or the Veri Fin template downloaded on this page. The file must include Date, Type, Amount and Account columns.';

  @override
  String get billImportCommonNote =>
      'Transactions are appended to the current ledger; unmatched accounts and categories are created by name. Nothing is deleted.';

  @override
  String get backupToLocalDir => 'Back up to local folder';

  @override
  String get backupDirLabel => 'Backup folder';

  @override
  String get notChosen => 'Not chosen';

  @override
  String get backupNow => 'Back up now';

  @override
  String get clearBackupDir => 'Clear backup folder';

  @override
  String get stopLocalBackup => 'Stops local backups';

  @override
  String get autoBackup => 'Auto backup';

  @override
  String get backupFrequencyLabel => 'Backup frequency';

  @override
  String get backupIntervalLabel => 'Backup interval';

  @override
  String everyNHoursLabel(int n) {
    return 'Every $n hours';
  }

  @override
  String get retentionLabel => 'Copies to keep';

  @override
  String latestNCopies(int n) {
    return 'Latest $n';
  }

  @override
  String get backupEncryption => 'Backup encryption';

  @override
  String get encryptionKey => 'Encryption key';

  @override
  String get clearEncryptionKey => 'Clear encryption key';

  @override
  String get noEncryptHint => 'Future backups unencrypted';

  @override
  String get webdavSection => 'WebDAV cloud backup';

  @override
  String get webdavServer => 'WebDAV server';

  @override
  String get configuredLabel => 'Configured';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get uploadToWebdav => 'Upload to WebDAV';

  @override
  String get uploadNow => 'Upload now';

  @override
  String get restoreFromWebdav => 'Restore from WebDAV';

  @override
  String get chooseBackup => 'Choose backup';

  @override
  String get autoUploadWebdav => 'Auto-upload to WebDAV';

  @override
  String get clearWebdav => 'Clear WebDAV config';

  @override
  String get disconnectLabel => 'Disconnect';

  @override
  String get resetData => 'Reset data';

  @override
  String get deleteAllLocal => 'Deletes all local data';

  @override
  String get neverBackedUp => 'Never backed up';

  @override
  String lastBackupAt(String time) {
    return 'Last $time';
  }

  @override
  String chosenBackupDir(String label) {
    return 'Backup folder selected: $label';
  }

  @override
  String backedUpFile(String name) {
    return 'Backed up: $name';
  }

  @override
  String get backupFailedRetry => 'Backup failed; please try again later';

  @override
  String get backupVerifyFailed =>
      'Backup verification failed after writing (the file may be corrupted); please retry or choose another folder';

  @override
  String get pickBackupFrequency => 'Choose auto-backup frequency';

  @override
  String get backupIntervalTitle => 'How often to back up';

  @override
  String get retentionTitle => 'How many backups to keep';

  @override
  String get encryptedSuffix => ' (encrypted)';

  @override
  String exportedTo(String hint) {
    return 'Exported local backup$hint to the Downloads folder';
  }

  @override
  String get exportFailed => 'Export failed; please try again later';

  @override
  String get enterBackupKeyTitle => 'Enter backup key';

  @override
  String get enterBackupKeyMessage =>
      'This backup is encrypted; enter the key set when it was exported.';

  @override
  String get backupKeyLabel => 'Backup key';

  @override
  String get changeKeyTitle => 'Change encryption key';

  @override
  String get setKeyTitle => 'Set encryption key';

  @override
  String get setKeyMessage =>
      'Exports and backups will be encrypted with this key; the same key is required to import. The key is stored only on this device — if forgotten, it can only be cleared and reset.';

  @override
  String get keyMinLabel => 'Key (at least 4 characters)';

  @override
  String get keyRepeatLabel => 'Repeat key';

  @override
  String get keyTooShort => 'Key must be at least 4 characters';

  @override
  String get keyMismatch => 'Keys don\'t match';

  @override
  String get keySet => 'Backup encryption key set';

  @override
  String get clearKeyTitle => 'Clear encryption key?';

  @override
  String get clearKeyMessage =>
      'New exports and backups will no longer be encrypted. Backups already encrypted with the old key still require it when importing.';

  @override
  String get clearLabel => 'Clear';

  @override
  String get webdavUrlLabel => 'Server folder URL';

  @override
  String get webdavUserLabel => 'Username';

  @override
  String get webdavPassLabel => 'Password';

  @override
  String get testingConnection => 'Testing connection…';

  @override
  String get connectionOk => 'Connection OK';

  @override
  String connectionFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get testConnection => 'Test connection';

  @override
  String get fillServerUrl => 'Enter the server URL';

  @override
  String get webdavSaved => 'WebDAV config saved';

  @override
  String get fabActionTitle => 'Quick-entry button';

  @override
  String get fabActionPickerTitle => 'Quick-entry button action';

  @override
  String get fabModeManual => 'Manual entry';

  @override
  String get fabModeAi => 'AI entry';

  @override
  String get fabModeManualTapAiLongPress => 'Tap: manual · Long-press: AI';

  @override
  String get defaultAccountTitle => 'Default account';

  @override
  String get defaultAccountPickerTitle => 'Default payment account';

  @override
  String get defaultAccountNone => 'No default';

  @override
  String get defaultAccountNoneHint =>
      'No account preselected when adding entries';

  @override
  String get setAsDefaultAccount => 'Set as default account';

  @override
  String get setAsDefaultAccountHint =>
      'Used as the default payment account for entries';

  @override
  String get calcIncomplete => 'Incomplete expression';

  @override
  String numberPadMax(String amount) {
    return 'Max $amount';
  }

  @override
  String get aiSettingsTitle => 'AI entry settings';

  @override
  String get aiConfigured => 'Configured';

  @override
  String get aiNotConfigured => 'Not set';

  @override
  String get aiChatTitle => 'AI Assistant';

  @override
  String get aiChatClearHistory => 'Clear chat history';

  @override
  String get aiChatClearMessage =>
      'This deletes the current conversation and cannot be undone.';

  @override
  String get aiChatClearConfirm => 'Clear';

  @override
  String get aiChatThinking => 'Thinking…';

  @override
  String get aiChatQuerying => 'Querying…';

  @override
  String get aiChatUnconfiguredHint =>
      'Configure AI first to start asking about your finances';

  @override
  String get aiChatGoConfigure => 'Configure AI';

  @override
  String get aiChatEmptyTitle => 'Ask AI about your finances';

  @override
  String get aiChatInputHint => 'Ask about your finances…';

  @override
  String get aiChatHintTopCategory =>
      'Which categories did I spend the most on this month?';

  @override
  String get aiChatHintLargeExpense =>
      'What are my large expenses in the last 3 months?';

  @override
  String get aiChatHintMonthSummary =>
      'How\'s my income and spending this month?';

  @override
  String get aiChatNoData => 'No data';

  @override
  String get aiChatNoMatchingTx => 'No matching transactions';

  @override
  String get aiSettingsIntro =>
      'Enter the request URL, API key and model of any OpenAI-compatible service. Your input is only sent to the service configured here; the config stays on this device and is not backed up.';

  @override
  String get aiBaseUrlLabel => 'Request URL (base)';

  @override
  String get aiBaseUrlHint => 'e.g. https://api.openai.com/v1';

  @override
  String get aiApiKeyLabel => 'API Key';

  @override
  String get aiModelLabel => 'Model';

  @override
  String get aiModelHint => 'e.g. gpt-4o-mini';

  @override
  String get aiFillAllFields =>
      'Please fill in the request URL, API key and model';

  @override
  String get aiSettingsSaved => 'Saved';

  @override
  String get aiPrivacyNotice =>
      'AI entry sends the text you type to the third-party service you configured for parsing. Do not enter sensitive information.';

  @override
  String get aiEntryTitle => 'AI entry';

  @override
  String get aiEntryInputHint =>
      'Describe it in one sentence, e.g. \"taxi 32 yesterday\"';

  @override
  String get aiEntryParse => 'Parse';

  @override
  String get aiEntryParsing => 'Parsing…';

  @override
  String get aiEntryEmptyInput => 'Please enter a description first';

  @override
  String get aiEntryNotConfiguredTitle => 'AI not configured';

  @override
  String get aiEntryNotConfiguredBody =>
      'Please set the request URL, API key and model in Profile → AI entry settings first.';

  @override
  String get aiEntryGoToSettings => 'Go to settings';

  @override
  String get aiEntryReviewHint =>
      'Parsed into a draft by AI — review or edit, then save';

  @override
  String get aiEntryNoResult =>
      'AI returned no recognizable result — try rephrasing';

  @override
  String get aiEntryNoAmount =>
      'Couldn\'t recognize an amount — include it, e.g. \"taxi 32\"';

  @override
  String get aiWarningCategoryUnmatched =>
      'Category not matched — a default was used, please confirm';

  @override
  String get aiWarningAccountUnmatched =>
      'Account not matched — set to no account, please confirm';

  @override
  String get screenshotEntryButton => 'Scan a screenshot';

  @override
  String get screenshotEntryUnsupported =>
      'Image text recognition is not supported on this device';

  @override
  String get screenshotEntryNoText =>
      'No text was recognized in the image — try a clearer screenshot';

  @override
  String get captureEntryRecognizing => 'Reading the bill…';

  @override
  String get captureEntryNoTransaction =>
      'No transaction was found — make sure the content is a bill screenshot or bill text';

  @override
  String get captureEntryFailedTitle => 'Recognition failed';

  @override
  String get captureEntryPrivacyNotice =>
      'Recognition runs on this device and the image is never uploaded; only the recognized text is sent to your configured AI service for parsing.';

  @override
  String get uploadingWebdav => 'Uploading to WebDAV…';

  @override
  String uploadedFile(String name) {
    return 'Uploaded: $name';
  }

  @override
  String uploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String readFailed(String error) {
    return 'Read failed: $error';
  }

  @override
  String get noWebdavBackups => 'No backups found on WebDAV';

  @override
  String get chooseRestoreBackup => 'Choose a backup to restore';

  @override
  String get restoreFromThisTitle => 'Restore from this backup?';

  @override
  String restoreFromThisMessage(String name) {
    return '\"$name\" will replace the current local data. Consider backing up first.';
  }

  @override
  String get restoreLabel => 'Restore';

  @override
  String get restoredFromWebdav => 'Data restored from WebDAV';

  @override
  String get restoreFailedFormat => 'Restore failed: invalid backup format';

  @override
  String restoreFailedError(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get clearWebdavTitle => 'Clear WebDAV config?';

  @override
  String get clearWebdavMessage =>
      'Auto-upload will stop; backups already on the server are not deleted.';

  @override
  String get csvTemplateSaved => 'CSV template saved to the Downloads folder';

  @override
  String get csvTemplateSaveFailed =>
      'Failed to save the template; try again later';

  @override
  String get chooseFile => 'Choose file';

  @override
  String importedEntries(int count) {
    return 'Imported $count transactions';
  }

  @override
  String skippedRows(int count) {
    return ', $count rows skipped';
  }

  @override
  String importFailedWithMessage(String message) {
    return 'Import failed: $message';
  }

  @override
  String get importFailedCheckFile => 'Import failed; check the file and retry';

  @override
  String lineError(int line, String message) {
    return 'Line $line: $message';
  }

  @override
  String moreLines(int count) {
    return '\n… $count more rows';
  }

  @override
  String importDoneTitle(int count) {
    return 'Import finished ($count succeeded)';
  }

  @override
  String get allImported => 'All rows imported.';

  @override
  String skippedFollowing(String lines) {
    return 'These rows were skipped:\n$lines';
  }

  @override
  String get gotIt => 'Got it';

  @override
  String get importPreviewTitle => 'Import preview';

  @override
  String get importPreviewHint =>
      'Tap to exclude / restore, long-press to edit';

  @override
  String importPreviewSelectedOf(int selected, int total) {
    return 'Importing $selected / $total';
  }

  @override
  String importPreviewNewAccounts(int count) {
    return '$count new account(s)';
  }

  @override
  String importPreviewNewCategories(int count) {
    return '$count new categor(ies)';
  }

  @override
  String importPreviewSkipped(int count) {
    return '$count row(s) couldn\'t be parsed';
  }

  @override
  String get importPreviewSkippedTitle => 'Skipped rows';

  @override
  String get importPreviewSelectAll => 'Select all';

  @override
  String get importPreviewDeselectAll => 'Deselect all';

  @override
  String importPreviewConfirm(int count) {
    return 'Import ($count)';
  }

  @override
  String importPreviewConfirmAccountsOnly(int count) {
    return 'Import ($count accounts)';
  }

  @override
  String get importPreviewNothingToImport => 'No data to import';

  @override
  String importedAccounts(int count) {
    return 'Imported $count accounts';
  }

  @override
  String get importAccountMapping => 'Import accounts';

  @override
  String get importCategoryMapping => 'Import categories';

  @override
  String mappingSummary(int newCount, int mappedCount) {
    return '$newCount new · $mappedCount mapped';
  }

  @override
  String get mappingRowNew => 'Create new';

  @override
  String mappingRowRenamed(String name) {
    return 'New · renamed to \"$name\"';
  }

  @override
  String mappingRowMapped(String name) {
    return 'Mapped to \"$name\"';
  }

  @override
  String mappingAccountSheetTitle(String name) {
    return 'Account \"$name\"';
  }

  @override
  String mappingCategorySheetTitle(String name) {
    return 'Category \"$name\"';
  }

  @override
  String get mappingKeepNewAccount => 'Create this account';

  @override
  String get mappingKeepNewCategory => 'Create this category';

  @override
  String get mappingMapToExistingAccount => 'Map to existing account';

  @override
  String get mappingMapToExistingCategory => 'Map to existing category';

  @override
  String get mappingRenameAccount => 'Rename new account';

  @override
  String get mappingRenameCategory => 'Rename new category';

  @override
  String get mappingRenameTooltip => 'Rename';

  @override
  String get mappingNewNameLabel => 'New name';

  @override
  String get importLocalTitle => 'Import local backup?';

  @override
  String get importLocalMessage =>
      'Importing replaces current local transactions, accounts, ledgers, budgets, profile and settings. Consider exporting current data first.';

  @override
  String get importedLocal => 'Local data imported';

  @override
  String get importFailedFormat => 'Import failed: invalid backup format';

  @override
  String get resetAllTitle => 'Reset all data?';

  @override
  String get resetAllMessage =>
      'This deletes local transactions, accounts, ledgers, budgets, profile and theme preference. It cannot be undone.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get resetConfirmTitle => 'Confirm reset';

  @override
  String get resetConfirmMessage =>
      'Confirming immediately clears all local data and restores defaults. This cannot be undone.';

  @override
  String get resetConfirmAction => 'Confirm reset';

  @override
  String get currentVersion => 'Current version';

  @override
  String get latestVersion => 'Latest version';

  @override
  String get checkingLabel => 'Checking…';

  @override
  String get queryingGithub => 'Querying GitHub Releases…';

  @override
  String get updateCheckFailed => 'Update check failed; try again later.';

  @override
  String downloadingPercent(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get downloadingLabel => 'Downloading…';

  @override
  String get closeLabel => 'Close';

  @override
  String get retryLabel => 'Retry';

  @override
  String get downloadingShort => 'Downloading';

  @override
  String get downloadNewVersion => 'Download update';

  @override
  String get includePrereleaseLabel => 'Include pre-release (Beta)';

  @override
  String get prereleaseNoticeInline =>
      'This is a pre-release (beta) build and may be unstable or buggy.';

  @override
  String get prereleaseWarningTitle => 'Download pre-release?';

  @override
  String get prereleaseWarningMessage =>
      'Pre-release builds may be unstable, buggy, or cause data issues. Only proceed if you understand the risks. Download and install anyway?';

  @override
  String get prereleaseDownloadAnyway => 'Download anyway';

  @override
  String get backupFreqManual => 'Manual only';

  @override
  String get backupFreqOnOpen => 'On app open';

  @override
  String get backupFreqOnEntry => 'After each entry';

  @override
  String get backupFreqEveryN => 'At intervals';

  @override
  String patternTooShort(int count) {
    return 'Connect at least $count dots';
  }

  @override
  String get bioUnlockReason => 'Verify biometrics to unlock Veri Fin';

  @override
  String get verifyFailedRetry => 'Verification failed; try again';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get drawPatternUnlock => 'Draw your pattern to unlock';

  @override
  String get enterPinUnlock => 'Enter your 6-digit PIN to unlock';

  @override
  String get bioUnlock => 'Biometric unlock';

  @override
  String get patternMismatch => 'Patterns don\'t match; draw again';

  @override
  String get pinMismatch => 'PINs don\'t match; set again';

  @override
  String get drawAgainConfirm => 'Draw again to confirm';

  @override
  String get drawPatternHint => 'Draw an unlock pattern (at least 4 dots)';

  @override
  String get enterAgainConfirm => 'Enter again to confirm';

  @override
  String get setPinHint => 'Set a 6-digit PIN';

  @override
  String get setPatternTitle => 'Set pattern';

  @override
  String get setPinTitle => 'Set PIN';

  @override
  String get verifyPasswordTitle => 'Verify password';

  @override
  String get drawCurrentPattern => 'Draw your current unlock pattern';

  @override
  String get enterCurrentPin => 'Enter your current 6-digit PIN';

  @override
  String get appLockSubtitle =>
      'Verified on launch and on return to foreground';

  @override
  String get lockMethodAndPassword => 'Lock method & password';

  @override
  String get appLockHelp =>
      'Supports a 6-digit PIN or a 3×3 pattern. The secret is stored on this device only as a salted hash — never uploaded and unrecoverable; if forgotten, reset data in Settings and set it again. Biometric unlock uses the system biometrics (fingerprint / face, as supported by the device); this app stores no biometric data, and re-verification is required after system biometrics change.';

  @override
  String get bioEnableReason => 'Verify biometrics to enable biometric unlock';

  @override
  String get bioNotPassed => 'Biometric verification failed; not enabled';

  @override
  String get closeAppLockTitle => 'Turn off app lock';

  @override
  String get changeAppLockTitle => 'Change app lock';

  @override
  String get appLockUpdated => 'App lock updated';

  @override
  String get pinSubtitle => '6-digit PIN';

  @override
  String get patternSubtitle => '3×3 pattern';

  @override
  String get lockKindPin => 'PIN';

  @override
  String get lockKindPattern => 'Pattern';

  @override
  String get bioSignInTitle => 'Biometric unlock';

  @override
  String get bioHint => 'Verify identity';

  @override
  String get bioNotRecognized => 'Not recognized; try again';

  @override
  String get bioRequiredTitle => 'Biometrics required';

  @override
  String get bioSuccess => 'Verified';

  @override
  String get bioSetupDescription => 'Enroll biometrics in system settings';

  @override
  String get bioGoToSettings => 'Go to settings';

  @override
  String get bioGoToSettingsDesc =>
      'No biometrics enrolled; add them in system settings';

  @override
  String get widgetTodayExpense => 'Today\'s spending';

  @override
  String get widgetBudgetAvailable => 'Budget left this month';

  @override
  String get widgetBudgetOverspent => 'Over budget this month';

  @override
  String get widgetNetWorth => 'Total assets';

  @override
  String get widgetGalleryTitle => 'Home widgets';

  @override
  String get widgetGallerySubtitle =>
      'Put the numbers you check most on your home screen';

  @override
  String get widgetGalleryShort => 'Preview & add';

  @override
  String get widgetAddToHome => 'Add to home screen';

  @override
  String get widgetPinRequested =>
      'Add request sent — confirm in the system dialog';

  @override
  String get widgetPinUnsupported =>
      'This launcher doesn\'t support one-tap add — add it manually as shown below';

  @override
  String get widgetHowToAddTitle => 'How to add manually';

  @override
  String get widgetHowToAddDesc =>
      'Long-press an empty spot on your home screen → choose Widgets → find Veri Fin → drag the widget you want onto the screen.';

  @override
  String get widgetQuickEntryName => 'Today\'s spending + quick entry';

  @override
  String get widgetQuickEntryDesc =>
      'See today\'s spending and tap to add an entry';

  @override
  String get widgetBudgetName => 'Budget left this month';

  @override
  String get widgetBudgetDesc => 'How much you can still spend this month';

  @override
  String get widgetNetWorthName => 'Total assets';

  @override
  String get widgetNetWorthDesc => 'Sum of all visible account balances';

  @override
  String get reminderNotifBody => 'Don\'t forget to record today\'s spending!';

  @override
  String get reminderChannelDesc => 'Daily bookkeeping reminder notifications';

  @override
  String get backupFileTypeLabel => 'Backup file';

  @override
  String get cropAdjustHint => 'Adjust image position';

  @override
  String get cropDone => 'Finish cropping';

  @override
  String get zoomLabel => 'Zoom';

  @override
  String get horizontalLabel => 'Horizontal';

  @override
  String get verticalLabel => 'Vertical';

  @override
  String get resetLabel => 'Reset';

  @override
  String get saveFailed => 'Save failed, please try again';

  @override
  String get appLog => 'App logs';

  @override
  String get appLogSubtitle =>
      'Records errors and key events; copy and send to the developer when reporting issues';

  @override
  String get appLogEmpty => 'No log records yet';

  @override
  String get appLogCopyAll => 'Copy all';

  @override
  String get appLogCopied => 'Copied to clipboard';

  @override
  String get appLogClear => 'Clear logs';

  @override
  String get appLogClearConfirm => 'Clear all logs?';

  @override
  String appLogCount(int count) {
    return '$count records';
  }

  @override
  String get cleartextWarnTitle => 'Cleartext transmission risk';

  @override
  String get cleartextWarnBody =>
      'This address uses unencrypted http; your key/username and password will be sent in cleartext and could be intercepted by a third party on the same network or link. Continue only if you trust this network (e.g. a local/self-hosted service).';

  @override
  String get cleartextWarnContinue => 'Save anyway';

  @override
  String get reminderPermissionDenied =>
      'Notification permission denied; reminders won\'t show. Please allow notifications in system settings and try again.';

  @override
  String get backingUp => 'Backing up…';

  @override
  String get aiErrNotConfigured =>
      'AI not configured: please fill in the base URL, API key and model first';

  @override
  String get aiErrNotSupported =>
      'AI requests are not supported on this platform';

  @override
  String get aiErrTimeout =>
      'Request timed out; check your network or try again later';

  @override
  String get aiErrNetwork => 'Cannot connect to the server';

  @override
  String get aiErrTls =>
      'TLS handshake failed; check whether the base URL uses https';

  @override
  String get aiErrBadUrl => 'Invalid request URL; check the base URL format';

  @override
  String get aiErrAuthFailed =>
      'Invalid API key or unauthorized; check your key';

  @override
  String get aiErrNotFound =>
      'Endpoint not found; check the base URL and model name';

  @override
  String get aiErrRateLimited => 'Too many requests or insufficient quota';

  @override
  String get aiErrServer => 'The server returned an error';

  @override
  String get aiErrBadResponse => 'Could not parse the server response';

  @override
  String get aiErrUpstream => 'The server returned an error';

  @override
  String get aiErrUnknown => 'Request failed';
}
