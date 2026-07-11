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
  String get backupInvalidFile => '备份文件无效或已损坏';

  @override
  String get fileEmptyError => '文件为空';

  @override
  String get dbErrorTitle => '无法打开数据';

  @override
  String get dbErrorBody => '你的账目数据很可能仍完好保存在本机，请不要清除应用数据或卸载应用。';

  @override
  String get dbErrorHint => '如果你刚刚降级了应用版本，请重新安装最新版本后再打开。若问题持续，可截图此页面反馈。';

  @override
  String get dbErrorDetail => '错误详情';

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
  String get reimbursementFilterName => '报销';

  @override
  String get reimbursementFilterTitle => '报销状态';

  @override
  String get reimbursementStatusAll => '全部';

  @override
  String get reimbursementReimbursed => '已报销';

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
  String accountRecurringRulesDisabled(int count) {
    return '已停用 $count 条引用该账户的周期记账并清空其账户，请前往复查';
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
  String get accountTypeCreditAccount => '信用账户';

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
  String get panelTrendDesc => '可自定义展示的数据与走势曲线';

  @override
  String get trendCustomizeTitle => '自定义走势卡片';

  @override
  String get trendCustomizeEntry => '自定义';

  @override
  String get trendCustomizeDisplayData => '展示数据';

  @override
  String get trendCustomizeChart => '曲线';

  @override
  String get trendCustomizeTitleField => '卡片标题';

  @override
  String get trendCustomizeTitleHint => '留空则显示「概览」';

  @override
  String get trendDefaultTitle => '概览';

  @override
  String get trendSlotBig => '大数字';

  @override
  String get trendSlotPill => '结余位';

  @override
  String get trendSlotCard1 => '小卡片 1';

  @override
  String get trendSlotCard2 => '小卡片 2';

  @override
  String get trendSlotCard3 => '小卡片 3';

  @override
  String get trendSlotChart => '曲线数据';

  @override
  String get trendResetTitle => '恢复默认走势卡片？';

  @override
  String get trendResetMessage => '会把卡片标题与各处展示的数据恢复为默认。';

  @override
  String get trendResetConfirm => '恢复默认';

  @override
  String get pickMetricTitle => '选择展示数据';

  @override
  String get pickChartSeriesTitle => '选择曲线数据';

  @override
  String get metricSeriesNet => '结余';

  @override
  String get metricGroupMonth => '本月';

  @override
  String get metricGroupToday => '今日';

  @override
  String get metricGroupWeek => '本周';

  @override
  String get metricGroupYear => '本年';

  @override
  String get metricGroupTotal => '总额';

  @override
  String get metricGroupAssets => '资产';

  @override
  String get metricGroupReimburse => '报销';

  @override
  String get metricMonthExpense => '本月支出';

  @override
  String get metricMonthIncome => '本月收入';

  @override
  String get metricMonthNet => '本月结余';

  @override
  String get metricDailyAvgExpense => '日均消费';

  @override
  String get metricDailyAvgIncome => '日均收入';

  @override
  String get metricTodayExpense => '今日支出';

  @override
  String get metricTodayIncome => '今日收入';

  @override
  String get metricTodayNet => '今日结余';

  @override
  String get metricWeekExpense => '本周支出';

  @override
  String get metricWeekIncome => '本周收入';

  @override
  String get metricWeekNet => '本周结余';

  @override
  String get metricYearExpense => '本年支出';

  @override
  String get metricYearIncome => '本年收入';

  @override
  String get metricTotalExpense => '总支出';

  @override
  String get metricTotalIncome => '总收入';

  @override
  String get metricTotalNet => '总结余';

  @override
  String get metricTotalAssets => '总资产';

  @override
  String get metricTotalLiabilities => '负资产';

  @override
  String get metricNetAssets => '净资产';

  @override
  String get metricReimbursablePending => '待报销';

  @override
  String get metricReimbursed => '已报销';

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
  String get statPeriodWeek => '周';

  @override
  String get statPeriodMonth => '月';

  @override
  String get statPeriodQuarter => '季';

  @override
  String get statPeriodYear => '年';

  @override
  String statQuarterRange(int year, int quarter) {
    return '$year年第$quarter季度';
  }

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
  String get noAccountLabel => '无账户';

  @override
  String get noAccountHint => '只记一笔金额，不计入任何账户余额';

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
    return '$count 笔交易';
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
  String get dailyBudgetTitle => '按日预算';

  @override
  String get dailyBudgetNotSet => '未设置每日上限，点击设置';

  @override
  String dailyBudgetLimitLabel(String amount) {
    return '每日上限 $amount';
  }

  @override
  String get dailyBudgetTodaySpent => '今日已花';

  @override
  String get dailyBudgetTodayLeft => '今日剩余';

  @override
  String get dailyBudgetTodayOver => '今日超支';

  @override
  String get setDailyBudgetTitle => '设置每日预算';

  @override
  String get dailyBudgetAmountLabel => '每日预算金额';

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

  @override
  String get statAnalysisTitle => '统计分析';

  @override
  String get pickTimeRange => '选择时间范围';

  @override
  String get okLabel => '确定';

  @override
  String get customRange => '自定义';

  @override
  String get overviewTitle => '收支概览';

  @override
  String get yoyMomTitle => '同比 · 环比';

  @override
  String get yoyMomDesc => '较上月为环比，较去年同期为同比';

  @override
  String get momLabel => '环比';

  @override
  String get yoyLabel => '同比';

  @override
  String get monthlyTrendTitle => '月度趋势';

  @override
  String get categoryRank => '分类排行';

  @override
  String get rankGroupCategory => '分类';

  @override
  String get rankGroupSubCategory => '子分类';

  @override
  String get rankGroupTag => '标签';

  @override
  String get tagRank => '标签排行';

  @override
  String get tagRankOverlapNote => '同一笔可带多个标签，各标签占比之和可能超过 100%';

  @override
  String subCategoryOf(String name) {
    return '「$name」的子分类';
  }

  @override
  String noDimData(String dim) {
    return '暂无$dim数据';
  }

  @override
  String noDimDesc(String dim) {
    return '该时间范围内没有$dim记录。';
  }

  @override
  String get reportsSubtitle => '数据看板';

  @override
  String get noCategoryData => '暂无分类数据';

  @override
  String get noCategoryDesc => '保存支出记录后会在这里显示分类排行。';

  @override
  String get thisYearLabel => '今年';

  @override
  String get noTagData => '暂无标签数据';

  @override
  String get noTagDesc => '给交易打上标签后，会在这里按标签汇总支出。';

  @override
  String get overBudgetLabel => '已超预算';

  @override
  String get remainingBudgetLabel => '剩余预算';

  @override
  String get expenseOnlyNote => '仅记录支出';

  @override
  String usedPercent(String percent) {
    return '已用 $percent%';
  }

  @override
  String get monthBudgetLabel => '本月预算';

  @override
  String countItems(int count) {
    return '$count 个';
  }

  @override
  String overCountLabel(int count) {
    return '$count 个超支';
  }

  @override
  String get normalLabel => '正常';

  @override
  String get othersLabel => '其他';

  @override
  String tagShareOfExpense(String percent) {
    return '占支出 $percent%';
  }

  @override
  String get bookkeepingDays => '记账天数';

  @override
  String get bookkeepingYears => '记账年数';

  @override
  String get reminderPickTime => '选择提醒时间';

  @override
  String get reminderTitle => '记账提醒';

  @override
  String get reminderDaily => '每日提醒';

  @override
  String get reminderTimeLabel => '提醒时间';

  @override
  String get reminderDescSupported =>
      '开启后每天到点会收到一条本地通知，提醒你记录当天收支。若长时间未收到，请在系统设置中确认已允许通知。';

  @override
  String get reminderDescUnsupported =>
      '当前平台不支持本地通知，此设置仅在 Android / iOS 手机上生效。';

  @override
  String reminderDailyAt(String time) {
    return '每日 $time';
  }

  @override
  String get recurringTitle => '周期记账';

  @override
  String get recurringSubtitle => '打开应用时自动补记到期交易';

  @override
  String get recurringAddTooltip => '新增规则';

  @override
  String get recurringEmpty => '还没有周期规则，点击右上角新增\n例如每月房租、每月工资';

  @override
  String nextRun(String date) {
    return '下次 $date';
  }

  @override
  String get recurringNewTitle => '新增周期规则';

  @override
  String get recurringEditTitle => '编辑周期规则';

  @override
  String get recurringDeleteTooltip => '删除规则';

  @override
  String get tapToFill => '点击填写';

  @override
  String get addAccountFirst => '请先添加账户';

  @override
  String get frequencyLabel => '频率';

  @override
  String get startDateLabel => '开始日期';

  @override
  String get pickFrequencyTitle => '选择频率';

  @override
  String get skipLabel => '跳过';

  @override
  String get startBookkeeping => '开始记账';

  @override
  String get nextStep => '下一步';

  @override
  String get onboardWelcomeTitle => '欢迎使用 Veri Fin';

  @override
  String get onboardWelcomeDesc =>
      '一款完全免费、数据自主、本地优先的记账应用。\n\n你的账目只保存在本机，不上传服务器；可随时导出 JSON 备份或加密上传到自己的 WebDAV。\n\n下面用几步帮你快速开始。';

  @override
  String get onboardAccountTitle => '创建第一个账户';

  @override
  String get onboardAccountDesc =>
      '账户是记账的基础，比如「现金」「工资卡」。填写名称与当前余额即可，也可以稍后在「资产」页添加。';

  @override
  String get onboardAccountNameLabel => '账户名称（可选）';

  @override
  String get onboardAccountNameHint => '如：现金 / 工资卡';

  @override
  String get onboardBalanceLabel => '当前余额（可选）';

  @override
  String get onboardBudgetDesc =>
      '设定每月预算后，首页与看板会展示预算执行进度，帮你控制支出。留空则暂不设预算，之后可在首页预算卡随时修改。';

  @override
  String get onboardBudgetLabel => '本月预算（可选）';

  @override
  String get onboardBudgetHint => '如：3000';

  @override
  String get onboardDoneTitle => '一切就绪';

  @override
  String get onboardDoneDesc =>
      '点击首页右下角的「+」即可快速记一笔。\n\n在「我的」页可以管理账本、分类、标签、周期记账，查看统计分析，设置记账提醒与数据备份。\n\n祝你记账愉快！';

  @override
  String legalUpdated(String date) {
    return '更新日期：$date';
  }

  @override
  String get privacyAndTerms => '隐私政策与用户协议';

  @override
  String get agreeContinue => '同意并继续';

  @override
  String get disagreeExit => '不同意并退出';

  @override
  String get legalPrivacyPolicy => '隐私政策';

  @override
  String get legalUserAgreement => '用户协议';

  @override
  String get profileCenterSubtitle => '个人中心';

  @override
  String get settingsTooltip => '设置';

  @override
  String get entryCountStat => '交易笔数';

  @override
  String get bookkeepingMgmt => '记账管理';

  @override
  String get ledgerLabel => '账本';

  @override
  String get categoryMgmt => '分类管理';

  @override
  String get tagMgmt => '标签管理';

  @override
  String countRules(int count) {
    return '$count 条';
  }

  @override
  String get dataAndTools => '数据与工具';

  @override
  String get reportShort => '报表';

  @override
  String get notEnabled => '未开启';

  @override
  String get dataManagement => '数据管理';

  @override
  String get backupRestoreShort => '备份 / 恢复';

  @override
  String currentBookLabel(String name) {
    return '当前：$name';
  }

  @override
  String get bookAdd => '新增账本';

  @override
  String get bookNameLabel => '账本名称';

  @override
  String get defaultBookLabel => '默认账本';

  @override
  String get bookActions => '账本操作';

  @override
  String get defaultBookUndeletable => '默认账本不可删除';

  @override
  String get bookRenameTitle => '重命名账本';

  @override
  String get bookDeleteTitle => '删除账本？';

  @override
  String bookDeleteMessage(String name) {
    return '账本「$name」及其中交易会被删除，此操作无法恢复。';
  }

  @override
  String get categoryMgmtSubtitle => '支持多级分类，用于记账和统计';

  @override
  String get addTopCategory => '新增顶级分类';

  @override
  String addCategoryTitle(String type) {
    return '新增$type分类';
  }

  @override
  String addSubCategoryTitle(String parent) {
    return '在「$parent」下新增子分类';
  }

  @override
  String get categoryNameLabel => '分类名称';

  @override
  String get changeIcon => '更换图标';

  @override
  String get addSubCategory => '新增子分类';

  @override
  String get moveTo => '移动到…';

  @override
  String get deleteCategory => '删除分类';

  @override
  String get noMoveTarget => '没有可移动到的目标';

  @override
  String moveCategoryTitle(String name) {
    return '移动「$name」到';
  }

  @override
  String get topCategory => '顶级分类';

  @override
  String get cannotMoveHere => '该分类无法移动到此处';

  @override
  String get mergeCategory => '合并到其他分类';

  @override
  String mergeCategoryPickTitle(String name) {
    return '把「$name」合并到';
  }

  @override
  String get mergeCategoryConfirmTitle => '合并分类？';

  @override
  String mergeCategoryConfirmMessage(String source, int count, String target) {
    return '「$source」的 $count 笔交易将并入「$target」，合并后「$source」会被删除，且不可撤销。';
  }

  @override
  String get mergeCategoryConfirmButton => '合并';

  @override
  String mergedCategoryResult(int count, String target) {
    return '已把 $count 笔交易并入「$target」';
  }

  @override
  String get mergeCategoryFailed => '无法合并该分类';

  @override
  String get renameCategoryTitle => '重命名分类';

  @override
  String get pickIconTitle => '选择图标';

  @override
  String get iconSectionBuiltin => '内置图标';

  @override
  String get iconSectionEmoji => 'Emoji';

  @override
  String get iconEmojiHint => '输入或粘贴一个 emoji';

  @override
  String get iconEmojiUse => '使用';

  @override
  String get systemCategoryUndeletable => '系统分类不能删除';

  @override
  String categoryInUse(int count) {
    return '已有 $count 笔交易使用该分类，不能删除';
  }

  @override
  String categoryUsedByRecurring(int count) {
    return '该分类正被 $count 条周期记账使用，请先修改或删除相关规则';
  }

  @override
  String get moveSubFirst => '请先移动或删除其子分类';

  @override
  String get keepOneCategory => '至少需要保留一个分类';

  @override
  String get deleteCategoryTitle => '删除分类？';

  @override
  String deleteCategoryMessage(String name) {
    return '分类「$name」删除后无法恢复。';
  }

  @override
  String get categoryUndeletable => '该分类暂时不能删除';

  @override
  String catSubChildren(String type, int children, int count) {
    return '$type · $children 个子分类 · $count 笔';
  }

  @override
  String catSubPlain(String type, int count) {
    return '$type · $count 笔交易';
  }

  @override
  String get tagMgmtSubtitle => '记账时可给交易打多个标签';

  @override
  String get tagAdd => '新增标签';

  @override
  String get tagsEmpty => '还没有标签，点击右上角新增';

  @override
  String get deleteTag => '删除标签';

  @override
  String get tagRenameTitle => '重命名标签';

  @override
  String get tagDeleteTitle => '删除标签？';

  @override
  String tagDeleteInUse(String name, int count) {
    return '标签「$name」正被 $count 笔交易使用，删除后会从这些交易上移除。';
  }

  @override
  String tagDeleteMessage(String name) {
    return '标签「$name」删除后无法恢复。';
  }

  @override
  String get personalInfo => '个人信息';

  @override
  String get nicknameLabel => '昵称';

  @override
  String get nicknameEmptyTitle => '未设置昵称';

  @override
  String get nicknameEmptyMessage => '未设置昵称，将使用默认昵称「Veri Fin」。是否继续保存？';

  @override
  String get bioLabel => '简介';

  @override
  String get genderLabel => '性别';

  @override
  String get birthdayLabel => '生日';

  @override
  String get cityLabel => '城市';

  @override
  String get occupationLabel => '职业';

  @override
  String get pickGenderTitle => '选择性别';

  @override
  String get cropAvatarTitle => '裁剪头像';

  @override
  String get avatarGenerating => '正在生成头像…';

  @override
  String get profileDefaultBio => '完全免费 · 数据自主';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsSectionBookkeeping => '记账';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get themeMode => '主题模式';

  @override
  String get hapticsLabel => '触感反馈';

  @override
  String get amountTwoDecimalsLabel => '金额保留两位小数';

  @override
  String get amountTwoDecimalsDesc => '开启后金额始终显示两位小数（如 12 显示为 12.00）';

  @override
  String get appLockLabel => '应用锁';

  @override
  String get enabledLabel => '已开启';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get viewLabel => '查看';

  @override
  String get themePickerTitle => '选择主题模式';

  @override
  String get dataMgmtSubtitle => '备份与恢复本地数据';

  @override
  String get exportData => '导出为文件';

  @override
  String get jsonBackup => '另存到系统下载目录';

  @override
  String get importData => '从文件恢复';

  @override
  String get restoreFromFile => '选择备份文件导入';

  @override
  String get importFromSheets => '导入账单';

  @override
  String get dataSectionLocalBackup => '本地备份';

  @override
  String get dataSectionMaintenance => '应用维护';

  @override
  String get downloadCsvTemplate => '下载 CSV 模板';

  @override
  String get excelHint => 'Excel 可另存为 CSV';

  @override
  String get importBillFile => '导入账单文件';

  @override
  String get importBillFileHint => '支付宝 / 微信 / 薄荷';

  @override
  String get selectBillSource => '选择账单来源';

  @override
  String get selectBillSourceHint => '先选平台，再选对应导出的文件，避免格式识别出错';

  @override
  String get platformAlipay => '支付宝';

  @override
  String get platformAlipayHint => '交易明细 CSV';

  @override
  String get platformWechat => '微信';

  @override
  String get platformWechatHint => '支付账单 xlsx';

  @override
  String get platformMint => '薄荷记账';

  @override
  String get platformMintHint => '账单 CSV';

  @override
  String get platformYimuBill => '一木记账 · 账单';

  @override
  String get platformYimuBillHint => '账单导出（.xls）';

  @override
  String get platformYimuTransfer => '一木记账 · 转账还款';

  @override
  String get platformYimuTransferHint => '转账还款导出（.xls）';

  @override
  String get platformTally => 'Tally 记账';

  @override
  String get platformTallyHint => '备份 zip';

  @override
  String get platformGenericCsv => '其他 CSV';

  @override
  String get platformGenericCsvHint => '钱迹 / 随手记 / 模板';

  @override
  String billImportGuideTitle(String source) {
    return '如何导出$source账单';
  }

  @override
  String get alipayImportGuide =>
      '支付宝 App →「我的」→「账单」→ 右上角「…」→「开具交易流水证明」→「用于个人对账」→ 选择时间范围，通过邮箱收到 CSV 文件，下载到手机后在此选择。\n\n还款、理财、转账等「不计收支」记录会自动跳过，避免重复记账。菜单以实际 App 版本为准。';

  @override
  String get wechatImportGuide =>
      '微信 →「我」→「服务」→「钱包」→「账单」→ 右上「常见问题」→「下载账单」→「用于个人对账」→ 选择时间范围，通过邮箱收到 xlsx 文件，下载到手机后在此选择。\n\n提现、理财、还款等「中性交易」会自动跳过。菜单以实际 App 版本为准。';

  @override
  String get mintImportGuide =>
      '薄荷记账 App →「我的」→ 账本/数据设置 → 导出账单（CSV），保存到本机后在此选择。菜单以实际 App 版本为准。';

  @override
  String get yimuBillImportGuide =>
      '一木记账 App →「我的」→「导入/导出」→「数据导出」→「账单导出」，选择 Excel（.xls）保存到本机后在此选择。\n\n只导入收支账单，分类按二级分类。转账请用另一个入口「一木记账 · 转账还款」。菜单以实际 App 版本为准。';

  @override
  String get yimuTransferImportGuide =>
      '一木记账 App →「我的」→「导入/导出」→「数据导出」→「转账还款导出」，选择 Excel（.xls）保存到本机后在此选择。\n\n导入转账记录，保留转出/转入账户与手续费。收支账单请用另一个入口「一木记账 · 账单」。菜单以实际 App 版本为准。';

  @override
  String get tallyImportGuide =>
      'Tally 记账 App →「设置」→ 数据备份与恢复 →「导出备份」，得到 Tally 开头的 .zip 文件，保存到本机后在此选择。\n\n请选「备份 zip」而非 CSV「账单」导出：备份保留精确到秒的交易时间，收入/支出/转账、一级/二级分类、账户与备注都会一并导入（分类按二级分类）。菜单以实际 App 版本为准。';

  @override
  String get genericCsvImportGuide =>
      '支持钱迹、随手记等导出的 CSV，或本页「下载 CSV 模板」填好后导入。文件需含 日期、类型、金额、账户 列。';

  @override
  String get billImportCommonNote => '交易会追加到当前账本，匹配不到的账户与分类按名称自动新建，不会删除现有数据。';

  @override
  String get backupToLocalDir => '备份到本地目录';

  @override
  String get backupDirLabel => '备份目录';

  @override
  String get notChosen => '未选择';

  @override
  String get backupNow => '立即备份';

  @override
  String get clearBackupDir => '清除备份目录';

  @override
  String get stopLocalBackup => '停止本地备份';

  @override
  String get autoBackup => '自动备份';

  @override
  String get backupFrequencyLabel => '备份频率';

  @override
  String get backupIntervalLabel => '备份间隔';

  @override
  String everyNHoursLabel(int n) {
    return '每 $n 小时';
  }

  @override
  String get retentionLabel => '保留份数';

  @override
  String latestNCopies(int n) {
    return '最近 $n 份';
  }

  @override
  String get backupEncryption => '备份加密';

  @override
  String get encryptionKey => '加密密钥';

  @override
  String get clearEncryptionKey => '清除加密密钥';

  @override
  String get noEncryptHint => '后续备份不加密';

  @override
  String get webdavSection => 'WebDAV 云备份';

  @override
  String get webdavServer => 'WebDAV 服务器';

  @override
  String get configuredLabel => '已配置';

  @override
  String get notConfigured => '未配置';

  @override
  String get uploadToWebdav => '上传到 WebDAV';

  @override
  String get uploadNow => '立即上传';

  @override
  String get restoreFromWebdav => '从 WebDAV 恢复';

  @override
  String get chooseBackup => '选择备份';

  @override
  String get autoUploadWebdav => '自动上传到 WebDAV';

  @override
  String get clearWebdav => '清除 WebDAV 配置';

  @override
  String get disconnectLabel => '断开连接';

  @override
  String get resetData => '初始化数据';

  @override
  String get deleteAllLocal => '删除所有本地数据';

  @override
  String get neverBackedUp => '尚未备份';

  @override
  String lastBackupAt(String time) {
    return '上次 $time';
  }

  @override
  String chosenBackupDir(String label) {
    return '已选择备份目录：$label';
  }

  @override
  String backedUpFile(String name) {
    return '已备份：$name';
  }

  @override
  String get backupFailedRetry => '备份操作失败，请稍后再试';

  @override
  String get backupVerifyFailed => '备份写入后校验未通过（文件可能已损坏），请重试或更换备份目录';

  @override
  String get pickBackupFrequency => '选择自动备份频率';

  @override
  String get backupIntervalTitle => '每隔多久备份一次';

  @override
  String get retentionTitle => '保留最近几份备份';

  @override
  String get encryptedSuffix => '（已加密）';

  @override
  String exportedTo(String hint) {
    return '已导出本地数据备份$hint，位置：下载目录';
  }

  @override
  String get exportFailed => '导出失败，请稍后再试';

  @override
  String get enterBackupKeyTitle => '输入备份密钥';

  @override
  String get enterBackupKeyMessage => '该备份已加密，请输入导出时设置的密钥。';

  @override
  String get backupKeyLabel => '备份密钥';

  @override
  String get changeKeyTitle => '修改加密密钥';

  @override
  String get setKeyTitle => '设置加密密钥';

  @override
  String get setKeyMessage =>
      '设置后，导出与备份文件会用该密钥加密；导入时需要输入相同密钥。密钥仅存于本机，忘记只能清除后重设。';

  @override
  String get keyMinLabel => '密钥（至少 4 位）';

  @override
  String get keyRepeatLabel => '再次输入密钥';

  @override
  String get keyTooShort => '密钥至少 4 位';

  @override
  String get keyMismatch => '两次输入不一致';

  @override
  String get keySet => '已设置备份加密密钥';

  @override
  String get clearKeyTitle => '清除加密密钥？';

  @override
  String get clearKeyMessage => '清除后新的导出与备份将不再加密。已经用旧密钥加密的备份文件，导入时仍需输入当时的密钥。';

  @override
  String get clearLabel => '清除';

  @override
  String get webdavUrlLabel => '服务器目录地址';

  @override
  String get webdavUserLabel => '账号';

  @override
  String get webdavPassLabel => '密码';

  @override
  String get testingConnection => '正在测试连接...';

  @override
  String get connectionOk => '连接成功';

  @override
  String connectionFailed(String error) {
    return '连接失败：$error';
  }

  @override
  String get testConnection => '测试连接';

  @override
  String get fillServerUrl => '请填写服务器地址';

  @override
  String get webdavSaved => '已保存 WebDAV 配置';

  @override
  String get fabActionTitle => '记一笔按钮';

  @override
  String get fabActionPickerTitle => '记一笔按钮行为';

  @override
  String get fabModeManual => '手动记账';

  @override
  String get fabModeAi => 'AI 记账';

  @override
  String get fabModeManualTapAiLongPress => '点击手动 · 长按 AI';

  @override
  String get defaultAccountTitle => '默认账户';

  @override
  String get defaultAccountPickerTitle => '默认付款账户';

  @override
  String get defaultAccountNone => '无默认账户';

  @override
  String get defaultAccountNoneHint => '记账时不预选账户';

  @override
  String get setAsDefaultAccount => '设为默认账户';

  @override
  String get setAsDefaultAccountHint => '记账时默认用此账户付款';

  @override
  String get calcIncomplete => '算式不完整';

  @override
  String get aiSettingsTitle => 'AI 记账设置';

  @override
  String get aiConfigured => '已配置';

  @override
  String get aiNotConfigured => '未配置';

  @override
  String get aiSettingsIntro =>
      '填写任意 OpenAI 兼容服务的请求地址、API Key 与模型。你的输入只会发送到这里配置的服务，配置只存本机、不进备份。';

  @override
  String get aiBaseUrlLabel => '请求地址（Base URL）';

  @override
  String get aiBaseUrlHint => '如 https://api.openai.com/v1';

  @override
  String get aiApiKeyLabel => 'API Key';

  @override
  String get aiModelLabel => '模型';

  @override
  String get aiModelHint => '如 gpt-4o-mini';

  @override
  String get aiFillAllFields => '请填写请求地址、API Key 与模型';

  @override
  String get aiSettingsSaved => '保存成功';

  @override
  String get aiPrivacyNotice => 'AI 记账会把你输入的文字发送到你配置的第三方服务进行解析，请勿输入敏感信息。';

  @override
  String get aiEntryTitle => 'AI 记账';

  @override
  String get aiEntryInputHint => '用一句话描述，例如「昨天打车 32」';

  @override
  String get aiEntryParse => '解析';

  @override
  String get aiEntryParsing => '正在解析…';

  @override
  String get aiEntryEmptyInput => '请先输入一句话';

  @override
  String get aiEntryNotConfiguredTitle => '尚未配置 AI';

  @override
  String get aiEntryNotConfiguredBody =>
      '请先在「我的 → AI 记账设置」中填写请求地址、API Key 与模型。';

  @override
  String get aiEntryGoToSettings => '去设置';

  @override
  String get aiEntryReviewHint => '已由 AI 解析为草稿，确认或修改后保存';

  @override
  String get aiEntryNoResult => 'AI 未返回可识别的结果，请换种说法再试';

  @override
  String get aiEntryNoAmount => '未能识别金额，请在描述中说明金额，例如「打车 32」';

  @override
  String get aiWarningCategoryUnmatched => '分类未匹配，已用默认分类，请确认';

  @override
  String get aiWarningAccountUnmatched => '账户未匹配，已置为无账户，请确认';

  @override
  String get screenshotEntryButton => '截图识账';

  @override
  String get screenshotEntryUnsupported => '当前设备不支持图片文字识别';

  @override
  String get screenshotEntryNoText => '没有从图片里识别到文字，请换一张更清晰的截图';

  @override
  String get captureEntryRecognizing => '正在识别账单内容…';

  @override
  String get captureEntryNoTransaction => '没有识别到交易，请确认内容是账单截图或账单文本';

  @override
  String get captureEntryFailedTitle => '识别失败';

  @override
  String get captureEntryPrivacyNotice =>
      '识别在本机完成，图片不会上传；识别出的文字会发送到你配置的 AI 服务解析。';

  @override
  String get uploadingWebdav => '正在上传到 WebDAV...';

  @override
  String uploadedFile(String name) {
    return '已上传：$name';
  }

  @override
  String uploadFailed(String error) {
    return '上传失败：$error';
  }

  @override
  String readFailed(String error) {
    return '读取失败：$error';
  }

  @override
  String get noWebdavBackups => 'WebDAV 上没有找到备份文件';

  @override
  String get chooseRestoreBackup => '选择要恢复的备份';

  @override
  String get restoreFromThisTitle => '从此备份恢复？';

  @override
  String restoreFromThisMessage(String name) {
    return '将用「$name」替换当前本地数据，建议先备份当前数据。';
  }

  @override
  String get restoreLabel => '恢复';

  @override
  String get restoredFromWebdav => '已从 WebDAV 恢复数据';

  @override
  String get restoreFailedFormat => '恢复失败：备份文件格式不正确';

  @override
  String restoreFailedError(String error) {
    return '恢复失败：$error';
  }

  @override
  String get clearWebdavTitle => '清除 WebDAV 配置？';

  @override
  String get clearWebdavMessage => '清除后将停止自动上传，服务器上已有的备份文件不会被删除。';

  @override
  String get csvTemplateSaved => '已保存 CSV 模板，位置：下载目录';

  @override
  String get csvTemplateSaveFailed => '保存模板失败，请稍后再试';

  @override
  String get chooseFile => '选择文件';

  @override
  String importedEntries(int count) {
    return '已导入 $count 笔交易';
  }

  @override
  String skippedRows(int count) {
    return '，$count 行跳过';
  }

  @override
  String importFailedWithMessage(String message) {
    return '导入失败：$message';
  }

  @override
  String get importFailedCheckFile => '导入失败，请检查文件后重试';

  @override
  String lineError(int line, String message) {
    return '第 $line 行：$message';
  }

  @override
  String moreLines(int count) {
    return '\n… 其余 $count 行';
  }

  @override
  String importDoneTitle(int count) {
    return '导入完成（成功 $count 笔）';
  }

  @override
  String get allImported => '全部导入成功。';

  @override
  String skippedFollowing(String lines) {
    return '以下行被跳过：\n$lines';
  }

  @override
  String get gotIt => '知道了';

  @override
  String get importPreviewTitle => '导入预览';

  @override
  String get importPreviewHint => '点按可排除 / 恢复某笔，长按可编辑';

  @override
  String importPreviewSelectedOf(int selected, int total) {
    return '将导入 $selected / $total 笔';
  }

  @override
  String importPreviewNewAccounts(int count) {
    return '新建账户 $count';
  }

  @override
  String importPreviewNewCategories(int count) {
    return '新建分类 $count';
  }

  @override
  String importPreviewSkipped(int count) {
    return '$count 行无法解析';
  }

  @override
  String get importPreviewSkippedTitle => '已跳过的行';

  @override
  String get importPreviewSelectAll => '全选';

  @override
  String get importPreviewDeselectAll => '全不选';

  @override
  String importPreviewConfirm(int count) {
    return '确认导入（$count）';
  }

  @override
  String importPreviewConfirmAccountsOnly(int count) {
    return '确认导入（$count 个账户）';
  }

  @override
  String get importPreviewNothingToImport => '没有可导入的数据';

  @override
  String importedAccounts(int count) {
    return '已导入 $count 个账户';
  }

  @override
  String get importAccountMapping => '导入账户';

  @override
  String get importCategoryMapping => '导入分类';

  @override
  String mappingSummary(int newCount, int mappedCount) {
    return '新建 $newCount · 映射 $mappedCount';
  }

  @override
  String get mappingRowNew => '新建';

  @override
  String mappingRowRenamed(String name) {
    return '新建 · 改名为「$name」';
  }

  @override
  String mappingRowMapped(String name) {
    return '映射到「$name」';
  }

  @override
  String mappingAccountSheetTitle(String name) {
    return '账户「$name」';
  }

  @override
  String mappingCategorySheetTitle(String name) {
    return '分类「$name」';
  }

  @override
  String get mappingKeepNewAccount => '新建此账户';

  @override
  String get mappingKeepNewCategory => '新建此分类';

  @override
  String get mappingMapToExistingAccount => '映射到现有账户';

  @override
  String get mappingMapToExistingCategory => '映射到现有分类';

  @override
  String get mappingRenameAccount => '重命名新账户';

  @override
  String get mappingRenameCategory => '重命名新分类';

  @override
  String get mappingRenameTooltip => '重命名';

  @override
  String get mappingNewNameLabel => '新名称';

  @override
  String get importLocalTitle => '导入本地备份？';

  @override
  String get importLocalMessage => '导入会替换当前本地交易、账户、账本、预算、个人信息和设置。建议先导出当前数据。';

  @override
  String get importedLocal => '已导入本地数据';

  @override
  String get importFailedFormat => '导入失败：备份文件格式不正确';

  @override
  String get resetAllTitle => '初始化所有数据？';

  @override
  String get resetAllMessage => '这会删除本地交易、账户、账本、预算、个人信息和主题偏好，操作无法恢复。';

  @override
  String get continueLabel => '继续';

  @override
  String get resetConfirmTitle => '再次确认初始化';

  @override
  String get resetConfirmMessage => '确认后会立即清空所有本地数据，并恢复默认状态。此操作不能撤销。';

  @override
  String get resetConfirmAction => '确认初始化';

  @override
  String get currentVersion => '当前版本';

  @override
  String get latestVersion => '最新版本';

  @override
  String get checkingLabel => '检查中...';

  @override
  String get queryingGithub => '正在查询 GitHub Release...';

  @override
  String get updateCheckFailed => '检查更新失败，请稍后再试。';

  @override
  String downloadingPercent(int percent) {
    return '下载中 $percent%';
  }

  @override
  String get downloadingLabel => '正在下载...';

  @override
  String get closeLabel => '关闭';

  @override
  String get retryLabel => '重试';

  @override
  String get downloadingShort => '下载中';

  @override
  String get downloadNewVersion => '下载新版本';

  @override
  String get includePrereleaseLabel => '包含预发布版本（Beta）';

  @override
  String get prereleaseNoticeInline => '这是预发布（测试）版本，可能存在不稳定或缺陷。';

  @override
  String get prereleaseWarningTitle => '下载预发布版本？';

  @override
  String get prereleaseWarningMessage =>
      '预发布版本可能存在不稳定、功能缺陷或数据异常等问题，建议仅在了解风险时使用。确定继续下载并安装吗？';

  @override
  String get prereleaseDownloadAnyway => '仍要下载';

  @override
  String get backupFreqManual => '仅手动';

  @override
  String get backupFreqOnOpen => '每次打开应用';

  @override
  String get backupFreqOnEntry => '每次记账后';

  @override
  String get backupFreqEveryN => '每隔一段时间';

  @override
  String patternTooShort(int count) {
    return '至少连接 $count 个点';
  }

  @override
  String get bioUnlockReason => '验证生物识别以解锁 Veri Fin';

  @override
  String get verifyFailedRetry => '验证失败，请重试';

  @override
  String get enterPassword => '输入密码';

  @override
  String get drawPatternUnlock => '请绘制图案解锁';

  @override
  String get enterPinUnlock => '请输入 6 位数字密码解锁';

  @override
  String get bioUnlock => '生物解锁';

  @override
  String get patternMismatch => '两次图案不一致，请重新绘制';

  @override
  String get pinMismatch => '两次输入不一致，请重新设置';

  @override
  String get drawAgainConfirm => '再次绘制以确认';

  @override
  String get drawPatternHint => '绘制解锁图案（至少 4 个点）';

  @override
  String get enterAgainConfirm => '再次输入以确认';

  @override
  String get setPinHint => '设置 6 位数字密码';

  @override
  String get setPatternTitle => '设置图案';

  @override
  String get setPinTitle => '设置密码';

  @override
  String get verifyPasswordTitle => '验证密码';

  @override
  String get drawCurrentPattern => '请绘制当前解锁图案';

  @override
  String get enterCurrentPin => '请输入当前 6 位数字密码';

  @override
  String get appLockSubtitle => '启动和回到前台时校验';

  @override
  String get lockMethodAndPassword => '锁定方式与密码';

  @override
  String get appLockHelp =>
      '支持 6 位数字密码或 3×3 图案。密钥仅以加盐哈希保存在本机，不会上传，也无法找回；忘记时可在设置页初始化数据后重新设置。生物解锁调用系统生物识别（指纹 / 人脸，以设备支持为准），本应用不保存任何生物特征数据；系统生物信息变化后需重新验证。';

  @override
  String get bioEnableReason => '验证生物识别以开启生物解锁';

  @override
  String get bioNotPassed => '生物识别未通过，未开启';

  @override
  String get closeAppLockTitle => '关闭应用锁';

  @override
  String get changeAppLockTitle => '修改应用锁';

  @override
  String get appLockUpdated => '应用锁已更新';

  @override
  String get pinSubtitle => '6 位数字';

  @override
  String get patternSubtitle => '3×3 连线图案';

  @override
  String get lockKindPin => '数字密码';

  @override
  String get lockKindPattern => '图案密码';

  @override
  String get bioSignInTitle => '生物解锁';

  @override
  String get bioHint => '验证身份';

  @override
  String get bioNotRecognized => '未能识别，请重试';

  @override
  String get bioRequiredTitle => '需要生物识别';

  @override
  String get bioSuccess => '验证成功';

  @override
  String get bioSetupDescription => '请在系统设置中录入生物识别';

  @override
  String get bioGoToSettings => '前往设置';

  @override
  String get bioGoToSettingsDesc => '尚未录入生物识别，请在系统设置中添加';

  @override
  String get widgetTodayExpense => '今日支出';

  @override
  String get widgetBudgetAvailable => '本月可用预算';

  @override
  String get widgetBudgetOverspent => '本月已超支';

  @override
  String get widgetNetWorth => '资产总额';

  @override
  String get widgetGalleryTitle => '桌面小组件';

  @override
  String get widgetGallerySubtitle => '把常看的数据放到手机桌面';

  @override
  String get widgetGalleryShort => '预览与添加';

  @override
  String get widgetAddToHome => '添加到桌面';

  @override
  String get widgetPinRequested => '已发起添加，请在系统弹窗中确认';

  @override
  String get widgetPinUnsupported => '当前桌面不支持一键添加，请按下方说明手动添加';

  @override
  String get widgetHowToAddTitle => '如何手动添加';

  @override
  String get widgetHowToAddDesc =>
      '长按桌面空白处 → 选择「小组件」→ 找到 Veri Fin → 拖动想要的小组件到桌面。';

  @override
  String get widgetQuickEntryName => '今日支出 + 记一笔';

  @override
  String get widgetQuickEntryDesc => '查看今日支出，点按快速记一笔';

  @override
  String get widgetBudgetName => '本月可用预算';

  @override
  String get widgetBudgetDesc => '当前账本本月还能花多少';

  @override
  String get widgetNetWorthName => '资产总额';

  @override
  String get widgetNetWorthDesc => '所有可见账户余额合计';

  @override
  String get reminderNotifBody => '别忘了记录今天的收支～';

  @override
  String get reminderChannelDesc => '每日记账提醒通知';

  @override
  String get backupFileTypeLabel => '备份文件';

  @override
  String get cropAdjustHint => '调整图片位置';

  @override
  String get cropDone => '完成裁剪';

  @override
  String get zoomLabel => '缩放';

  @override
  String get horizontalLabel => '水平';

  @override
  String get verticalLabel => '垂直';

  @override
  String get resetLabel => '重置';

  @override
  String get saveFailed => '保存失败，请重试';

  @override
  String get appLog => '软件日志';

  @override
  String get appLogSubtitle => '记录错误与关键事件，反馈问题时可复制发给开发者';

  @override
  String get appLogEmpty => '暂无日志记录';

  @override
  String get appLogCopyAll => '复制全部';

  @override
  String get appLogCopied => '已复制到剪贴板';

  @override
  String get appLogClear => '清空日志';

  @override
  String get appLogClearConfirm => '确定要清空全部日志吗？';

  @override
  String appLogCount(int count) {
    return '共 $count 条记录';
  }

  @override
  String get cleartextWarnTitle => '明文传输风险';

  @override
  String get cleartextWarnBody =>
      '该地址使用未加密的 http，你的密钥/账号密码会以明文发送，可能被同一网络或链路上的第三方窃取。仅在你信任该网络（如本地/自建服务）时继续。';

  @override
  String get cleartextWarnContinue => '仍要保存';

  @override
  String get reminderPermissionDenied => '通知权限被拒，提醒将不会显示。请在系统设置中允许通知后重试。';

  @override
  String get backingUp => '备份中…';

  @override
  String get aiErrNotConfigured => 'AI 未配置：请先填写请求地址、API Key 与模型';

  @override
  String get aiErrNotSupported => '当前平台不支持 AI 请求';

  @override
  String get aiErrTimeout => '请求超时，请检查网络或稍后重试';

  @override
  String get aiErrNetwork => '无法连接到服务器';

  @override
  String get aiErrTls => 'TLS 握手失败，请检查请求地址是否为 https';

  @override
  String get aiErrBadUrl => '请求地址无效，请检查基础地址格式';

  @override
  String get aiErrAuthFailed => 'API Key 无效或无权访问，请检查密钥';

  @override
  String get aiErrNotFound => '接口不存在，请检查请求地址与模型名';

  @override
  String get aiErrRateLimited => '请求过于频繁或额度不足';

  @override
  String get aiErrServer => '服务器返回错误';

  @override
  String get aiErrBadResponse => '无法解析服务器响应';

  @override
  String get aiErrUpstream => '服务器返回错误';

  @override
  String get aiErrUnknown => '请求失败';
}
