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
}
