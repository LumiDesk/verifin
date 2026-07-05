// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Veri Fin';

  @override
  String get tabHome => '首页';

  @override
  String get tabAssets => '资产';

  @override
  String get tabReports => '看板';

  @override
  String get tabProfile => '我的';

  @override
  String get quickEntry => '快速记账';

  @override
  String get pressBackAgainToExit => '再次返回退出程序';

  @override
  String get settingsLanguage => '语言';

  @override
  String get languagePickerTitle => '选择语言';

  @override
  String get localeFollowSystem => '跟随系统';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonDelete => '删除';

  @override
  String get commonBack => '返回';

  @override
  String get commonProcessing => '正在处理…';

  @override
  String get badgeRefunded => '已退';

  @override
  String get badgeReimbursable => '待报销';

  @override
  String get calendarTitle => '日历';

  @override
  String get calendarPrevMonth => '上个月';

  @override
  String get calendarNextMonth => '下个月';

  @override
  String get weekdayMon => '一';

  @override
  String get weekdayTue => '二';

  @override
  String get weekdayWed => '三';

  @override
  String get weekdayThu => '四';

  @override
  String get weekdayFri => '五';

  @override
  String get weekdaySat => '六';

  @override
  String get weekdaySun => '日';

  @override
  String get entryAddTags => '添加标签';

  @override
  String get iconGroupGeneric => '通用图标';

  @override
  String get accountIconPickerTitle => '选择账户图标';

  @override
  String get accountHandleTitle => '处理此账户？';

  @override
  String accountHandleMessage(String name, int count) {
    return '账户「$name」已有 $count 笔相关交易。你可以隐藏账户，或删除账户并同步删除这些交易记录。';
  }

  @override
  String get accountHide => '隐藏账户';

  @override
  String get accountDeleteWithEntries => '删除账户和交易';

  @override
  String get accountDeleteTitle => '删除此账户？';

  @override
  String accountDeleteMessage(String name) {
    return '账户「$name」删除后无法恢复。';
  }

  @override
  String get tagCreateTitle => '新建标签';

  @override
  String get tagNameLabel => '标签名称';

  @override
  String get entryTypeExpense => '支出';

  @override
  String get entryTypeIncome => '收入';

  @override
  String get entryTypeTransfer => '转账';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get accountTypeOnlinePayment => '网络支付';

  @override
  String get accountTypeCreditCard => '信用卡';

  @override
  String get accountTypeDebitCard => '储蓄卡';

  @override
  String get accountTypeInvestment => '投资账户';

  @override
  String get accountTypeCash => '现金';

  @override
  String get assetViewGroup => '分类视图';

  @override
  String get assetViewType => '类型视图';

  @override
  String get assetViewToggleToType => '切换为类型视图';

  @override
  String get assetViewToggleToGroup => '切换为分类视图';

  @override
  String get recurringDaily => '每天';

  @override
  String get recurringWeekly => '每周';

  @override
  String get recurringMonthly => '每月';

  @override
  String get recurringYearly => '每年';

  @override
  String get genderUnset => '不设置';

  @override
  String get genderMale => '男';

  @override
  String get genderFemale => '女';

  @override
  String get panelTrendLabel => '支出走势';

  @override
  String get panelTrendDesc => '按 7 天周期展示支出趋势与结余';

  @override
  String get panelRecentLabel => '最近交易';

  @override
  String get panelRecentDesc => '展示最近 5 条交易记录';

  @override
  String get panelBudgetLabel => '月度预算';

  @override
  String get panelBudgetDesc => '本月预算进度与分类超支提醒';

  @override
  String get panelCalendarDesc => '按日历查看每天的收支情况';

  @override
  String get panelBudgetExecutionLabel => '预算执行';

  @override
  String get panelBudgetExecutionDesc => '本月预算、支出与分类预算执行情况';

  @override
  String get panelCategoryRingLabel => '分类统计';

  @override
  String get panelCategoryRingDesc => '本月支出分类占比环形图';

  @override
  String get panelCategoryRankLabel => '分类明细';

  @override
  String get panelCategoryRankDesc => '本月支出分类排行与占比';

  @override
  String get panelTagStatsLabel => '标签统计';

  @override
  String get panelTagStatsDesc => '本月各标签的支出金额与占比';

  @override
  String get panelDailyTrendLabel => '日趋势';

  @override
  String get panelDailyTrendDesc => '近 7 天每日支出趋势';

  @override
  String get panelMonthlyStructureLabel => '月度收支';

  @override
  String get panelMonthlyStructureDesc => '今年每月支出结构柱状图';

  @override
  String panelCountLabel(int count, String page) {
    return '$count个$page面板';
  }

  @override
  String panelPageTitle(String page) {
    return '$page面板';
  }

  @override
  String get panelSortHint => '拖动手柄调整顺序';

  @override
  String get panelToggleHint => '开关与排序';

  @override
  String get panelSortDone => '完成排序';

  @override
  String get panelSortStart => '排序面板';

  @override
  String panelResetTitle(String page) {
    return '恢复默认$page面板？';
  }

  @override
  String get panelResetMessage => '将恢复默认顺序并开启全部面板。';

  @override
  String get panelResetConfirm => '恢复默认';

  @override
  String panelKeepOneMessage(String page) {
    return '至少保留一个开启的$page面板';
  }

  @override
  String get iconLabelCategory => '分类';

  @override
  String get iconLabelDining => '餐饮';

  @override
  String get iconLabelTransport => '交通';

  @override
  String get iconLabelShopping => '购物';

  @override
  String get iconLabelHousing => '居住';

  @override
  String get iconLabelEntertainment => '娱乐';

  @override
  String get iconLabelMedical => '医疗';

  @override
  String get iconLabelSalary => '收入';

  @override
  String get iconLabelInterest => '利息';

  @override
  String get iconLabelBonus => '奖励';

  @override
  String get iconLabelWork => '工作';

  @override
  String get iconLabelTransferOut => '转出';

  @override
  String get iconLabelTransferIn => '转入';

  @override
  String get iconLabelRepayment => '还款';

  @override
  String get iconLabelAdjust => '调整';

  @override
  String get iconLabelPay => '支付';

  @override
  String get iconLabelWechat => '微信';

  @override
  String get iconLabelCredit => '信用';

  @override
  String get iconLabelBank => '银行';

  @override
  String get iconLabelCash => '现金';

  @override
  String get iconLabelInvestment => '投资';

  @override
  String get iconLabelSavings => '储蓄';

  @override
  String get iconLabelCard => '卡片';

  @override
  String get iconLabelFolder => '分组';

  @override
  String get iconLabelWallet => '钱包';

  @override
  String get iconGroupCredit => '信用账户';

  @override
  String get iconGroupPayment => '支付平台';

  @override
  String get iconGroupBank => '银行';

  @override
  String get balanceAdjustNote => '余额调整';

  @override
  String get commonNone => '暂无';

  @override
  String get commonDone => '完成';

  @override
  String get homeNoEntriesTitle => '还没有交易';

  @override
  String get homeNoEntriesDesc => '点击右下角加号开始第一笔记账。';

  @override
  String trendNet(String amount) {
    return '结余 $amount';
  }

  @override
  String get homeDaysTracked => '记账日';

  @override
  String daysCount(int count) {
    return '$count天';
  }

  @override
  String get homeDailyAvgExpense => '日均支出';

  @override
  String dateMonthDay(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat('M月d日', localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String monthBudgetTitle(DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat('M月', localeName);
    final String monthString = monthDateFormat.format(month);

    return '$monthString预算';
  }

  @override
  String get budgetRemaining => '剩余';

  @override
  String get budgetDailyRemaining => '剩余日均';

  @override
  String budgetTotalLabel(String amount) {
    return '预算 $amount';
  }

  @override
  String get incomeExpenseTitle => '收支统计';

  @override
  String get homeNoStatsTitle => '暂无统计';

  @override
  String get homeNoStatsDesc => '当前月份没有对应记录。';

  @override
  String get statTypeTitle => '统计类型';

  @override
  String budgetCatOver(String category, String amount) {
    return '$category超出 $amount';
  }

  @override
  String budgetCatUsed(String category, String percent) {
    return '$category已用 $percent%';
  }

  @override
  String entriesCount(int count) {
    return '$count笔';
  }

  @override
  String get categoryAll => '全部分类';

  @override
  String get tagPickerTitle => '选择标签';

  @override
  String get coverBlueCity => '蓝色城市';

  @override
  String get coverAurora => '极光夜色';

  @override
  String get coverFinanceOffice => '金融办公';

  @override
  String get coverDeepBlue => '深蓝渐层';

  @override
  String get assetsUngrouped => '未分组';

  @override
  String get netAssets => '净资产';

  @override
  String get assetsActions => '资产操作';

  @override
  String get assetsChangeCover => '更换资产卡片背景';

  @override
  String assetsAmount(String amount) {
    return '资产 $amount';
  }

  @override
  String liabilitiesAmount(String amount) {
    return '负债 $amount';
  }

  @override
  String netAssetsAmount(String amount) {
    return '净资产 $amount';
  }

  @override
  String monthNumber(int month) {
    return '$month月';
  }

  @override
  String get assetsEmptyTitle => '还没有资产账户';

  @override
  String get assetsEmptyDesc => '请先点击右上角添加资产，之后可以在这里按类型或分组查看资产。';

  @override
  String get assetsSortHint => '拖动右侧手柄调整分组顺序';

  @override
  String hiddenAccountsCount(int count) {
    return '$count个隐藏账户';
  }

  @override
  String get assetsCoverTitle => '资产卡片背景';

  @override
  String get coverUseOnline => '使用线上图片';

  @override
  String get coverEnterUrl => '输入图片链接';

  @override
  String get coverPickLocal => '选择本地图片';

  @override
  String get coverClear => '清除背景图片';

  @override
  String get coverPickOnlineTitle => '选择线上图片';

  @override
  String get coverCustomTitle => '自定义图片';

  @override
  String get coverUrlLabel => '图片链接';

  @override
  String get coverCropTitle => '裁剪资产背景';

  @override
  String get coverGenerating => '正在生成背景图…';

  @override
  String get accountAdd => '添加账户';

  @override
  String get groupManage => '管理分组';

  @override
  String get sectionSort => '排序分组';

  @override
  String get sectionSortNeedTwo => '至少有 2 个分组才能排序';

  @override
  String get sortLabel => '排序';

  @override
  String get hiddenAccountsTitle => '隐藏账户';

  @override
  String get hiddenAccountsEmptyTitle => '暂无隐藏账户';

  @override
  String get hiddenAccountsEmptyDesc => '隐藏账户会在这里集中展示。';

  @override
  String get accountGroupsTitle => '账户分组';

  @override
  String get groupAdd => '新增分组';

  @override
  String get groupsEmptyTitle => '还没有账户分组';

  @override
  String get groupsEmptyDesc => '点击右上角加号创建分组，用来整理不同账户。';

  @override
  String accountsCount(int count) {
    return '$count个账户';
  }

  @override
  String get commonRename => '重命名';

  @override
  String get commonIcon => '图标';

  @override
  String get groupRenameTitle => '重命名分组';

  @override
  String get groupNameLabel => '分组名称';

  @override
  String get groupIconPickerTitle => '选择分组图标';

  @override
  String get accountIconLabel => '账户图标';

  @override
  String get accountSaveTooltip => '保存账户';

  @override
  String get accountTypeLabel => '账户类型';

  @override
  String get accountNameLabel => '账户名称';

  @override
  String get accountNameRequired => '账户名称必填';

  @override
  String get cardLast4Label => '卡号后四位';

  @override
  String get cardLast4Invalid => '请输入 1-4 位数字';

  @override
  String get accountBalanceLabel => '账户余额';

  @override
  String get accountBalanceHint => '不填默认为 0';

  @override
  String get accountNoteLabel => '账户备注';

  @override
  String get accountGroupLabel => '账户分组';

  @override
  String get accountTypePickerTitle => '选择账户类型';

  @override
  String get accountGroupPickerTitle => '选择账户分组';

  @override
  String get balanceAdjustTooltip => '调整余额';

  @override
  String get currentBalance => '当前余额';

  @override
  String get balanceTrend => '余额趋势';

  @override
  String get dayShort => '日';

  @override
  String get monthShort => '月';

  @override
  String balanceAmount(String amount) {
    return '余额 $amount';
  }

  @override
  String get viewReport => '查看报告';

  @override
  String get addEntryTooltip => '记一笔';

  @override
  String get noEntriesTitle => '暂无交易';

  @override
  String get accountNoEntriesDesc => '该账户还没有交易记录。';

  @override
  String accountEntriesTitle(String name) {
    return '$name交易';
  }

  @override
  String get allEntries => '所有交易';

  @override
  String get includeInAssets => '计入资产';

  @override
  String get commonType => '类型';

  @override
  String get commonName => '名称';

  @override
  String get notSet => '未设置';

  @override
  String get clearOption => '不设置';

  @override
  String get statementDay => '账单日';

  @override
  String get dueDay => '还款日';

  @override
  String monthlyDayLabel(int day) {
    return '每月 $day 日';
  }

  @override
  String get commonCurrency => '货币';

  @override
  String get currencyCny => '人民币';

  @override
  String get commonNote => '备注';

  @override
  String get commonNoneShort => '无';

  @override
  String get commonGroup => '分组';

  @override
  String get accountDelete => '删除账户';

  @override
  String get deletableLabel => '可删除';

  @override
  String get hasEntriesLabel => '已有交易';

  @override
  String get balanceEditConfirmTitle => '是否确认修改余额？';

  @override
  String balanceEditConfirmMessage(String name, String amount) {
    return '将把「$name」的余额调整为 $amount。';
  }

  @override
  String get balanceEditRecord => '计入收支';

  @override
  String get balanceEditRecordDesc => '生成一笔余额调整交易；不勾选则直接修改账户初始余额，不影响收支统计。';

  @override
  String get accountNameEditTitle => '编辑账户名称';

  @override
  String get cardLast4EditTitle => '编辑卡号后四位';

  @override
  String get pickDueDay => '选择还款日';

  @override
  String get pickStatementDay => '选择账单日';

  @override
  String get accountNoteEditTitle => '编辑账户备注';

  @override
  String get accountReportTitle => '账户报告';

  @override
  String get thisMonth => '本月';

  @override
  String get dueToday => '就是今天';

  @override
  String dueInDays(int days) {
    return '还有 $days 天';
  }

  @override
  String monthlyRepayLine(int day) {
    return '每月 $day 日还款';
  }

  @override
  String get attachTakePhoto => '拍照';

  @override
  String get attachFromGallery => '从相册选择';

  @override
  String get attachTitle => '图片附件';

  @override
  String attachCount(int count) {
    return '$count 张';
  }

  @override
  String get attachUnsupported => '当前平台不支持添加图片附件';

  @override
  String get attachDeleteTooltip => '删除这张';

  @override
  String get entryDetailSubtitle => '记账详情';

  @override
  String get commonCategory => '分类';

  @override
  String get allLabel => '全部';

  @override
  String get transferOutAccount => '转出账户';

  @override
  String get transferInAccount => '转入账户';

  @override
  String get pleaseSelect => '请选择';

  @override
  String get feeLabel => '手续费';

  @override
  String get feeNoneTapToFill => '无（点击填写）';

  @override
  String get accountLabel => '账户';

  @override
  String get noUsableAccountTitle => '没有可用账户';

  @override
  String get noUsableAccountDesc => '请先在资产页添加或取消隐藏一个账户。';

  @override
  String get noteHint => '点击添加备注';

  @override
  String get commonSave => '保存';

  @override
  String get amountEditTitle => '修改金额';

  @override
  String get transferFeeTitle => '转账手续费';

  @override
  String get pickTransferOutAccount => '选择转出账户';

  @override
  String get pickAccountTitle => '选择账户';

  @override
  String get pickTransferInAccount => '选择转入账户';

  @override
  String get timeAll => '全部时间';

  @override
  String get timeYear => '本年';

  @override
  String get timeQuarter => '本季';

  @override
  String get timeWeek => '本周';

  @override
  String get timeLast12Months => '近12个月';

  @override
  String get timeLast30Days => '近30天';

  @override
  String get timeLast6Weeks => '近6周';

  @override
  String get sortDateDesc => '日期降序';

  @override
  String get sortDateAsc => '日期升序';

  @override
  String get sortAmountDesc => '金额降序';

  @override
  String get sortAmountAsc => '金额升序';

  @override
  String selectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String get dayEntriesTitle => '当日交易';

  @override
  String get entriesListTitle => '交易明细';

  @override
  String get exitMultiSelect => '退出多选';

  @override
  String get multiSelect => '多选';

  @override
  String entriesCountFull(int count) {
    return '$count笔交易';
  }

  @override
  String get netLabel => '结余';

  @override
  String get noMatchTitle => '没有匹配交易';

  @override
  String get noMatchDesc => '换一个关键词、账户或分类再试。';

  @override
  String get emptyEntriesDesc => '保存交易后会在这里按日期展示。';

  @override
  String get filterTimeTitle => '筛选时间';

  @override
  String get sortTitle => '排序方式';

  @override
  String get filterAccountTitle => '筛选账户';

  @override
  String get allAccounts => '全部账户';

  @override
  String get filterCategoryTitle => '筛选分类';

  @override
  String get filterTagTitle => '筛选标签';

  @override
  String get allTags => '全部标签';

  @override
  String get unknownTag => '未知标签';

  @override
  String get tagLabel => '标签';

  @override
  String deleteEntriesTitle(int count) {
    return '删除 $count 笔交易？';
  }

  @override
  String get deleteEntriesMessage => '删除后无法恢复，相关图片附件也会一并移除。';

  @override
  String get changeCategoryTitle => '改分类（仅改同类型交易）';

  @override
  String changedCategoryCount(int count) {
    return '已修改 $count 笔交易的分类';
  }

  @override
  String get changeAccountTitle => '改账户';

  @override
  String changedAccountCount(int count) {
    return '已修改 $count 笔交易的账户';
  }

  @override
  String yearLabel(int year) {
    return '$year年';
  }

  @override
  String quarterLabel(int quarter) {
    return '季度$quarter';
  }

  @override
  String weekNumber(int week) {
    return '$week周';
  }

  @override
  String yearWeek(int year, int week) {
    return '$year年$week周';
  }

  @override
  String get prevRange => '上一段';

  @override
  String get nextRange => '下一段';

  @override
  String get searchHint => '搜索备注、分类、账户或金额';

  @override
  String get clearFilters => '清空筛选';

  @override
  String get prevDay => '前一天';

  @override
  String get nextDay => '后一天';

  @override
  String get entryMissing => '交易不存在';

  @override
  String get deleteEntryTooltip => '删除交易';

  @override
  String get saveEntryTooltip => '保存交易';

  @override
  String get amountLabel => '金额';

  @override
  String get dateLabel => '日期';

  @override
  String get timeLabel => '时间';

  @override
  String get markReimbursable => '标记待报销';

  @override
  String get refundLabel => '退款 / 报销回款';

  @override
  String refundedAmountLabel(String amount) {
    return '已冲抵 $amount';
  }

  @override
  String get refundAmountTitle => '退款 / 报销回款金额';

  @override
  String get pickTypeTitle => '选择类型';

  @override
  String get noteEditTitle => '编辑备注';

  @override
  String get transferNeedsTwoAccounts => '转账需要两个不同的账户,请先添加转入账户。';

  @override
  String get deleteEntryTitle => '删除此交易？';

  @override
  String get deleteEntryMessage => '删除后无法恢复，本地保存的这笔记录会被移除。';

  @override
  String get todayLabel => '今天';

  @override
  String get yesterdayLabel => '昨天';

  @override
  String get selectAll => '全选';

  @override
  String get changeCategoryShort => '改分类';

  @override
  String get changeAccountShort => '改账户';

  @override
  String get budgetSettingsTitle => '预算设置';

  @override
  String yearMonth(DateTime month) {
    final intl.DateFormat monthDateFormat = intl.DateFormat('y年M月', localeName);
    final String monthString = monthDateFormat.format(month);

    return '$monthString';
  }

  @override
  String get budgetUsed => '已用';

  @override
  String get budgetOverspentThisMonth => '本月已超支';

  @override
  String get budgetAvailableThisMonth => '本月可用预算';

  @override
  String get budgetMonthExpense => '本月支出';

  @override
  String get budgetOverAmountLabel => '超出预算';

  @override
  String get budgetRemainingQuota => '剩余额度';

  @override
  String get budgetAmountLabel => '预算金额';

  @override
  String get categoryBudgetTitle => '分类预算';

  @override
  String get monthExpenseCategories => '本月支出分类';

  @override
  String get noExpenseCategories => '还没有支出分类';

  @override
  String get setMonthBudgetTitle => '设置本月预算';

  @override
  String get monthBudgetAmountLabel => '月份预算金额';

  @override
  String setCategoryBudgetTitle(String category) {
    return '设置$category预算';
  }

  @override
  String get categoryBudgetAmountLabel => '分类预算金额';

  @override
  String get budgetHistoryTitle => '预算历史';

  @override
  String get last12MonthsSub => '最近 12 个月';

  @override
  String get monthSummary => '月份汇总';

  @override
  String get last6MonthsTrend => '近 6 月趋势';

  @override
  String get budgetLegend => '预算';

  @override
  String expenseAmountLabel(String amount) {
    return '支出 $amount';
  }

  @override
  String get historyCompare => '历史对比';

  @override
  String get lastMonthExpense => '上月支出';

  @override
  String get noExpenseYet => '暂无支出';

  @override
  String get compareBaseline => '对比基准';

  @override
  String budgetUsageLine(String percent, String delta) {
    return '预算使用率 $percent%，较上月 $delta';
  }

  @override
  String get notSetBudget => '未设置预算';

  @override
  String overBy(String amount) {
    return '超出 $amount';
  }

  @override
  String remainingAmount(String amount) {
    return '剩余 $amount';
  }

  @override
  String budgetHistoryLine(String budget, String expense, String percent) {
    return '预算 $budget · 支出 $expense · 已用 $percent%';
  }

  @override
  String get categoryBudgetOk => '分类预算正常';

  @override
  String categoryOverspent(String category) {
    return '$category已超支';
  }

  @override
  String categoryNearBudget(String category) {
    return '$category接近预算';
  }

  @override
  String categoryBudgetOkDesc(int count) {
    return '已设置 $count 个分类预算，当前没有临近超支的分类。';
  }

  @override
  String categoryOverspentDesc(String amount, String percent) {
    return '已超出 $amount，本月已用 $percent%。';
  }

  @override
  String categoryNearDesc(String amount, String percent) {
    return '剩余 $amount，本月已用 $percent%。';
  }

  @override
  String catNoBudgetLine(String amount) {
    return '未设置预算 · 本月支出 $amount';
  }

  @override
  String catRemainLine(String amount, String percent) {
    return '剩余 $amount · 已用 $percent%';
  }

  @override
  String catOverLine(String amount, String percent) {
    return '超出 $amount · 已用 $percent%';
  }

  @override
  String get lastMonthNone => '上月无支出';

  @override
  String lastMonthAmount(String amount) {
    return '上月 $amount';
  }

  @override
  String get setLabel => '设置';

  @override
  String get monthEnded => '月份已结束';

  @override
  String remainingDaysInclToday(int days) {
    return '含今天还剩 $days 天';
  }

  @override
  String monthTotalDays(int days) {
    return '本月共 $days 天';
  }

  @override
  String get budgetTipNoneTitle => '还没有设置预算';

  @override
  String get budgetTipNoneDesc => '设置本月预算后，首页和这里会同步展示预算进度、剩余额度和剩余日均。';

  @override
  String get budgetTipOverTitle => '预算已经超出';

  @override
  String budgetTipOverDesc(String amount) {
    return '本月支出已超过预算 $amount，后续支出会继续计入本月统计。';
  }

  @override
  String get budgetTipNearTitle => '预算接近用完';

  @override
  String budgetTipNearDesc(String percent, String amount) {
    return '本月预算已使用 $percent%，剩余 $amount。';
  }

  @override
  String get budgetTipOkTitle => '预算状态正常';

  @override
  String budgetTipOkDesc(String amount) {
    return '按当前预算，本月剩余每天约可支出 $amount。';
  }

  @override
  String get budgetTipEndedTitle => '本月预算已结算';

  @override
  String get budgetTipEndedDesc => '这个月份已结束，可切换到其他月份继续查看或调整预算。';

  @override
  String get deltaFlatVsLastMonth => '与上月持平';

  @override
  String deltaMoreVsLastMonth(String amount) {
    return '比上月多 $amount';
  }

  @override
  String deltaLessVsLastMonth(String amount) {
    return '比上月少 $amount';
  }

  @override
  String get usageFlat => '持平';

  @override
  String usageUp(String points) {
    return '增加 $points 个点';
  }

  @override
  String usageDown(String points) {
    return '降低 $points 个点';
  }
}
