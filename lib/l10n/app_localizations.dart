import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// 应用名称
  ///
  /// In zh, this message translates to:
  /// **'Veri Fin'**
  String get appTitle;

  /// 导入的备份文件格式无效/为空时的提示
  ///
  /// In zh, this message translates to:
  /// **'备份文件无效或已损坏'**
  String get backupInvalidFile;

  /// 所选文件为空时的提示
  ///
  /// In zh, this message translates to:
  /// **'文件为空'**
  String get fileEmptyError;

  /// 数据库打开失败错误页标题
  ///
  /// In zh, this message translates to:
  /// **'无法打开数据'**
  String get dbErrorTitle;

  /// 数据库打开失败错误页正文
  ///
  /// In zh, this message translates to:
  /// **'你的账目数据很可能仍完好保存在本机，请不要清除应用数据或卸载应用。'**
  String get dbErrorBody;

  /// 数据库打开失败错误页提示
  ///
  /// In zh, this message translates to:
  /// **'如果你刚刚降级了应用版本，请重新安装最新版本后再打开。若问题持续，可截图此页面反馈。'**
  String get dbErrorHint;

  /// 数据库打开失败错误页技术详情标题
  ///
  /// In zh, this message translates to:
  /// **'错误详情'**
  String get dbErrorDetail;

  /// 底部导航:首页
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get tabHome;

  /// 底部导航:资产
  ///
  /// In zh, this message translates to:
  /// **'资产'**
  String get tabAssets;

  /// 底部导航:看板
  ///
  /// In zh, this message translates to:
  /// **'看板'**
  String get tabReports;

  /// 底部导航:我的
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabProfile;

  /// 快速记账入口(FAB 提示与数字键盘标题)
  ///
  /// In zh, this message translates to:
  /// **'快速记账'**
  String get quickEntry;

  /// 首页按返回键时的退出提示
  ///
  /// In zh, this message translates to:
  /// **'再次返回退出程序'**
  String get pressBackAgainToExit;

  /// 设置页:语言入口标题
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// 语言选择弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'选择语言'**
  String get languagePickerTitle;

  /// 语言选项:跟随系统语言
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get localeFollowSystem;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get commonConfirm;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// 页头返回按钮 tooltip
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// 耗时任务加载对话框默认文案
  ///
  /// In zh, this message translates to:
  /// **'正在处理…'**
  String get commonProcessing;

  /// 交易行徽标:已被退款/报销冲抵
  ///
  /// In zh, this message translates to:
  /// **'已退'**
  String get badgeRefunded;

  /// 交易行徽标:标记待报销
  ///
  /// In zh, this message translates to:
  /// **'待报销'**
  String get badgeReimbursable;

  /// No description provided for @reimbursementFilterName.
  ///
  /// In zh, this message translates to:
  /// **'报销'**
  String get reimbursementFilterName;

  /// No description provided for @reimbursementFilterTitle.
  ///
  /// In zh, this message translates to:
  /// **'报销状态'**
  String get reimbursementFilterTitle;

  /// No description provided for @reimbursementStatusAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get reimbursementStatusAll;

  /// No description provided for @reimbursementReimbursed.
  ///
  /// In zh, this message translates to:
  /// **'已报销'**
  String get reimbursementReimbursed;

  /// No description provided for @calendarTitle.
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get calendarTitle;

  /// No description provided for @calendarPrevMonth.
  ///
  /// In zh, this message translates to:
  /// **'上个月'**
  String get calendarPrevMonth;

  /// No description provided for @calendarNextMonth.
  ///
  /// In zh, this message translates to:
  /// **'下个月'**
  String get calendarNextMonth;

  /// 日历星期表头(短)
  ///
  /// In zh, this message translates to:
  /// **'一'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In zh, this message translates to:
  /// **'二'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In zh, this message translates to:
  /// **'三'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In zh, this message translates to:
  /// **'四'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In zh, this message translates to:
  /// **'五'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In zh, this message translates to:
  /// **'六'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get weekdaySun;

  /// 记账表单标签行为空时的占位提示
  ///
  /// In zh, this message translates to:
  /// **'添加标签'**
  String get entryAddTags;

  /// 账户图标选择弹窗:内置图标分组名
  ///
  /// In zh, this message translates to:
  /// **'通用图标'**
  String get iconGroupGeneric;

  /// No description provided for @accountIconPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择账户图标'**
  String get accountIconPickerTitle;

  /// No description provided for @accountHandleTitle.
  ///
  /// In zh, this message translates to:
  /// **'处理此账户？'**
  String get accountHandleTitle;

  /// 删除有交易的账户时的确认说明
  ///
  /// In zh, this message translates to:
  /// **'账户「{name}」已有 {count} 笔相关交易。你可以隐藏账户，或删除账户并同步删除这些交易记录。'**
  String accountHandleMessage(String name, int count);

  /// No description provided for @accountHide.
  ///
  /// In zh, this message translates to:
  /// **'隐藏账户'**
  String get accountHide;

  /// No description provided for @accountDeleteWithEntries.
  ///
  /// In zh, this message translates to:
  /// **'删除账户和交易'**
  String get accountDeleteWithEntries;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除此账户？'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'账户「{name}」删除后无法恢复。'**
  String accountDeleteMessage(String name);

  /// No description provided for @accountRecurringRulesDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已停用 {count} 条引用该账户的周期记账并清空其账户，请前往复查'**
  String accountRecurringRulesDisabled(int count);

  /// No description provided for @tagCreateTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建标签'**
  String get tagCreateTitle;

  /// No description provided for @tagNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'标签名称'**
  String get tagNameLabel;

  /// No description provided for @entryTypeExpense.
  ///
  /// In zh, this message translates to:
  /// **'支出'**
  String get entryTypeExpense;

  /// No description provided for @entryTypeIncome.
  ///
  /// In zh, this message translates to:
  /// **'收入'**
  String get entryTypeIncome;

  /// No description provided for @entryTypeTransfer.
  ///
  /// In zh, this message translates to:
  /// **'转账'**
  String get entryTypeTransfer;

  /// No description provided for @entryTypeRefund.
  ///
  /// In zh, this message translates to:
  /// **'退款'**
  String get entryTypeRefund;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @accountTypeOnlinePayment.
  ///
  /// In zh, this message translates to:
  /// **'网络支付'**
  String get accountTypeOnlinePayment;

  /// No description provided for @accountTypeCreditAccount.
  ///
  /// In zh, this message translates to:
  /// **'信用账户'**
  String get accountTypeCreditAccount;

  /// No description provided for @accountTypeCreditCard.
  ///
  /// In zh, this message translates to:
  /// **'信用卡'**
  String get accountTypeCreditCard;

  /// No description provided for @accountTypeDebitCard.
  ///
  /// In zh, this message translates to:
  /// **'储蓄卡'**
  String get accountTypeDebitCard;

  /// No description provided for @accountTypeInvestment.
  ///
  /// In zh, this message translates to:
  /// **'投资账户'**
  String get accountTypeInvestment;

  /// No description provided for @accountTypeCash.
  ///
  /// In zh, this message translates to:
  /// **'现金'**
  String get accountTypeCash;

  /// No description provided for @assetViewGroup.
  ///
  /// In zh, this message translates to:
  /// **'分类视图'**
  String get assetViewGroup;

  /// No description provided for @assetViewType.
  ///
  /// In zh, this message translates to:
  /// **'类型视图'**
  String get assetViewType;

  /// No description provided for @assetViewToggleToType.
  ///
  /// In zh, this message translates to:
  /// **'切换为类型视图'**
  String get assetViewToggleToType;

  /// No description provided for @assetViewToggleToGroup.
  ///
  /// In zh, this message translates to:
  /// **'切换为分类视图'**
  String get assetViewToggleToGroup;

  /// No description provided for @recurringDaily.
  ///
  /// In zh, this message translates to:
  /// **'每天'**
  String get recurringDaily;

  /// No description provided for @recurringWeekly.
  ///
  /// In zh, this message translates to:
  /// **'每周'**
  String get recurringWeekly;

  /// No description provided for @recurringMonthly.
  ///
  /// In zh, this message translates to:
  /// **'每月'**
  String get recurringMonthly;

  /// No description provided for @recurringYearly.
  ///
  /// In zh, this message translates to:
  /// **'每年'**
  String get recurringYearly;

  /// No description provided for @genderUnset.
  ///
  /// In zh, this message translates to:
  /// **'不设置'**
  String get genderUnset;

  /// No description provided for @genderMale.
  ///
  /// In zh, this message translates to:
  /// **'男'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In zh, this message translates to:
  /// **'女'**
  String get genderFemale;

  /// No description provided for @panelTrendLabel.
  ///
  /// In zh, this message translates to:
  /// **'支出走势'**
  String get panelTrendLabel;

  /// No description provided for @panelTrendDesc.
  ///
  /// In zh, this message translates to:
  /// **'可自定义展示的数据与走势曲线'**
  String get panelTrendDesc;

  /// No description provided for @trendCustomizeTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义走势卡片'**
  String get trendCustomizeTitle;

  /// No description provided for @trendCustomizeEntry.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get trendCustomizeEntry;

  /// No description provided for @trendCustomizeDisplayData.
  ///
  /// In zh, this message translates to:
  /// **'展示数据'**
  String get trendCustomizeDisplayData;

  /// No description provided for @trendCustomizeChart.
  ///
  /// In zh, this message translates to:
  /// **'曲线'**
  String get trendCustomizeChart;

  /// No description provided for @trendCustomizeTitleField.
  ///
  /// In zh, this message translates to:
  /// **'卡片标题'**
  String get trendCustomizeTitleField;

  /// No description provided for @trendCustomizeTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则显示「概览」'**
  String get trendCustomizeTitleHint;

  /// No description provided for @trendDefaultTitle.
  ///
  /// In zh, this message translates to:
  /// **'概览'**
  String get trendDefaultTitle;

  /// No description provided for @trendSlotBig.
  ///
  /// In zh, this message translates to:
  /// **'大数字'**
  String get trendSlotBig;

  /// No description provided for @trendSlotPill.
  ///
  /// In zh, this message translates to:
  /// **'结余位'**
  String get trendSlotPill;

  /// No description provided for @trendSlotCard1.
  ///
  /// In zh, this message translates to:
  /// **'小卡片 1'**
  String get trendSlotCard1;

  /// No description provided for @trendSlotCard2.
  ///
  /// In zh, this message translates to:
  /// **'小卡片 2'**
  String get trendSlotCard2;

  /// No description provided for @trendSlotCard3.
  ///
  /// In zh, this message translates to:
  /// **'小卡片 3'**
  String get trendSlotCard3;

  /// No description provided for @trendSlotChart.
  ///
  /// In zh, this message translates to:
  /// **'曲线数据'**
  String get trendSlotChart;

  /// No description provided for @trendResetTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认走势卡片？'**
  String get trendResetTitle;

  /// No description provided for @trendResetMessage.
  ///
  /// In zh, this message translates to:
  /// **'会把卡片标题与各处展示的数据恢复为默认。'**
  String get trendResetMessage;

  /// No description provided for @trendResetConfirm.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get trendResetConfirm;

  /// No description provided for @pickMetricTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择展示数据'**
  String get pickMetricTitle;

  /// No description provided for @pickChartSeriesTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择曲线数据'**
  String get pickChartSeriesTitle;

  /// No description provided for @metricSeriesNet.
  ///
  /// In zh, this message translates to:
  /// **'结余'**
  String get metricSeriesNet;

  /// No description provided for @metricGroupMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get metricGroupMonth;

  /// No description provided for @metricGroupToday.
  ///
  /// In zh, this message translates to:
  /// **'今日'**
  String get metricGroupToday;

  /// No description provided for @metricGroupWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get metricGroupWeek;

  /// No description provided for @metricGroupYear.
  ///
  /// In zh, this message translates to:
  /// **'本年'**
  String get metricGroupYear;

  /// No description provided for @metricGroupTotal.
  ///
  /// In zh, this message translates to:
  /// **'总额'**
  String get metricGroupTotal;

  /// No description provided for @metricGroupAssets.
  ///
  /// In zh, this message translates to:
  /// **'资产'**
  String get metricGroupAssets;

  /// No description provided for @metricGroupReimburse.
  ///
  /// In zh, this message translates to:
  /// **'报销'**
  String get metricGroupReimburse;

  /// No description provided for @metricMonthExpense.
  ///
  /// In zh, this message translates to:
  /// **'本月支出'**
  String get metricMonthExpense;

  /// No description provided for @metricMonthIncome.
  ///
  /// In zh, this message translates to:
  /// **'本月收入'**
  String get metricMonthIncome;

  /// No description provided for @metricMonthNet.
  ///
  /// In zh, this message translates to:
  /// **'本月结余'**
  String get metricMonthNet;

  /// No description provided for @metricDailyAvgExpense.
  ///
  /// In zh, this message translates to:
  /// **'日均消费'**
  String get metricDailyAvgExpense;

  /// No description provided for @metricDailyAvgIncome.
  ///
  /// In zh, this message translates to:
  /// **'日均收入'**
  String get metricDailyAvgIncome;

  /// No description provided for @metricTodayExpense.
  ///
  /// In zh, this message translates to:
  /// **'今日支出'**
  String get metricTodayExpense;

  /// No description provided for @metricTodayIncome.
  ///
  /// In zh, this message translates to:
  /// **'今日收入'**
  String get metricTodayIncome;

  /// No description provided for @metricTodayNet.
  ///
  /// In zh, this message translates to:
  /// **'今日结余'**
  String get metricTodayNet;

  /// No description provided for @metricWeekExpense.
  ///
  /// In zh, this message translates to:
  /// **'本周支出'**
  String get metricWeekExpense;

  /// No description provided for @metricWeekIncome.
  ///
  /// In zh, this message translates to:
  /// **'本周收入'**
  String get metricWeekIncome;

  /// No description provided for @metricWeekNet.
  ///
  /// In zh, this message translates to:
  /// **'本周结余'**
  String get metricWeekNet;

  /// No description provided for @metricYearExpense.
  ///
  /// In zh, this message translates to:
  /// **'本年支出'**
  String get metricYearExpense;

  /// No description provided for @metricYearIncome.
  ///
  /// In zh, this message translates to:
  /// **'本年收入'**
  String get metricYearIncome;

  /// No description provided for @metricTotalExpense.
  ///
  /// In zh, this message translates to:
  /// **'总支出'**
  String get metricTotalExpense;

  /// No description provided for @metricTotalIncome.
  ///
  /// In zh, this message translates to:
  /// **'总收入'**
  String get metricTotalIncome;

  /// No description provided for @metricTotalNet.
  ///
  /// In zh, this message translates to:
  /// **'总结余'**
  String get metricTotalNet;

  /// No description provided for @metricTotalAssets.
  ///
  /// In zh, this message translates to:
  /// **'总资产'**
  String get metricTotalAssets;

  /// No description provided for @metricTotalLiabilities.
  ///
  /// In zh, this message translates to:
  /// **'负资产'**
  String get metricTotalLiabilities;

  /// No description provided for @metricNetAssets.
  ///
  /// In zh, this message translates to:
  /// **'净资产'**
  String get metricNetAssets;

  /// No description provided for @metricReimbursablePending.
  ///
  /// In zh, this message translates to:
  /// **'待报销'**
  String get metricReimbursablePending;

  /// No description provided for @metricReimbursed.
  ///
  /// In zh, this message translates to:
  /// **'已报销'**
  String get metricReimbursed;

  /// No description provided for @panelRecentLabel.
  ///
  /// In zh, this message translates to:
  /// **'最近交易'**
  String get panelRecentLabel;

  /// No description provided for @panelRecentDesc.
  ///
  /// In zh, this message translates to:
  /// **'展示最近 5 条交易记录'**
  String get panelRecentDesc;

  /// No description provided for @panelBudgetLabel.
  ///
  /// In zh, this message translates to:
  /// **'月度预算'**
  String get panelBudgetLabel;

  /// No description provided for @panelBudgetDesc.
  ///
  /// In zh, this message translates to:
  /// **'本月预算进度与分类超支提醒'**
  String get panelBudgetDesc;

  /// No description provided for @panelCalendarDesc.
  ///
  /// In zh, this message translates to:
  /// **'按日历查看每天的收支情况'**
  String get panelCalendarDesc;

  /// No description provided for @panelBudgetExecutionLabel.
  ///
  /// In zh, this message translates to:
  /// **'预算执行'**
  String get panelBudgetExecutionLabel;

  /// No description provided for @panelBudgetExecutionDesc.
  ///
  /// In zh, this message translates to:
  /// **'本月预算、支出与分类预算执行情况'**
  String get panelBudgetExecutionDesc;

  /// No description provided for @panelCategoryRingLabel.
  ///
  /// In zh, this message translates to:
  /// **'分类统计'**
  String get panelCategoryRingLabel;

  /// No description provided for @panelCategoryRingDesc.
  ///
  /// In zh, this message translates to:
  /// **'本月支出分类占比环形图'**
  String get panelCategoryRingDesc;

  /// No description provided for @panelCategoryRankLabel.
  ///
  /// In zh, this message translates to:
  /// **'分类明细'**
  String get panelCategoryRankLabel;

  /// No description provided for @panelCategoryRankDesc.
  ///
  /// In zh, this message translates to:
  /// **'本月支出分类排行与占比'**
  String get panelCategoryRankDesc;

  /// No description provided for @panelTagStatsLabel.
  ///
  /// In zh, this message translates to:
  /// **'标签统计'**
  String get panelTagStatsLabel;

  /// No description provided for @panelTagStatsDesc.
  ///
  /// In zh, this message translates to:
  /// **'本月各标签的支出金额与占比'**
  String get panelTagStatsDesc;

  /// No description provided for @panelDailyTrendLabel.
  ///
  /// In zh, this message translates to:
  /// **'日趋势'**
  String get panelDailyTrendLabel;

  /// No description provided for @panelDailyTrendDesc.
  ///
  /// In zh, this message translates to:
  /// **'近 7 天每日支出趋势'**
  String get panelDailyTrendDesc;

  /// No description provided for @panelMonthlyStructureLabel.
  ///
  /// In zh, this message translates to:
  /// **'月度收支'**
  String get panelMonthlyStructureLabel;

  /// No description provided for @panelMonthlyStructureDesc.
  ///
  /// In zh, this message translates to:
  /// **'今年每月支出结构柱状图'**
  String get panelMonthlyStructureDesc;

  /// 面板管理入口:开启数量
  ///
  /// In zh, this message translates to:
  /// **'{count}个{page}面板'**
  String panelCountLabel(int count, String page);

  /// No description provided for @panelPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'{page}面板'**
  String panelPageTitle(String page);

  /// No description provided for @panelSortHint.
  ///
  /// In zh, this message translates to:
  /// **'拖动手柄调整顺序'**
  String get panelSortHint;

  /// No description provided for @panelToggleHint.
  ///
  /// In zh, this message translates to:
  /// **'开关与排序'**
  String get panelToggleHint;

  /// No description provided for @panelSortDone.
  ///
  /// In zh, this message translates to:
  /// **'完成排序'**
  String get panelSortDone;

  /// No description provided for @panelSortStart.
  ///
  /// In zh, this message translates to:
  /// **'排序面板'**
  String get panelSortStart;

  /// No description provided for @panelResetTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认{page}面板？'**
  String panelResetTitle(String page);

  /// No description provided for @panelResetMessage.
  ///
  /// In zh, this message translates to:
  /// **'将恢复默认顺序并开启全部面板。'**
  String get panelResetMessage;

  /// No description provided for @panelResetConfirm.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get panelResetConfirm;

  /// No description provided for @panelKeepOneMessage.
  ///
  /// In zh, this message translates to:
  /// **'至少保留一个开启的{page}面板'**
  String panelKeepOneMessage(String page);

  /// No description provided for @iconLabelCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get iconLabelCategory;

  /// No description provided for @iconLabelDining.
  ///
  /// In zh, this message translates to:
  /// **'餐饮'**
  String get iconLabelDining;

  /// No description provided for @iconLabelTransport.
  ///
  /// In zh, this message translates to:
  /// **'交通'**
  String get iconLabelTransport;

  /// No description provided for @iconLabelShopping.
  ///
  /// In zh, this message translates to:
  /// **'购物'**
  String get iconLabelShopping;

  /// No description provided for @iconLabelHousing.
  ///
  /// In zh, this message translates to:
  /// **'居住'**
  String get iconLabelHousing;

  /// No description provided for @iconLabelEntertainment.
  ///
  /// In zh, this message translates to:
  /// **'娱乐'**
  String get iconLabelEntertainment;

  /// No description provided for @iconLabelMedical.
  ///
  /// In zh, this message translates to:
  /// **'医疗'**
  String get iconLabelMedical;

  /// No description provided for @iconLabelSalary.
  ///
  /// In zh, this message translates to:
  /// **'收入'**
  String get iconLabelSalary;

  /// No description provided for @iconLabelInterest.
  ///
  /// In zh, this message translates to:
  /// **'利息'**
  String get iconLabelInterest;

  /// No description provided for @iconLabelBonus.
  ///
  /// In zh, this message translates to:
  /// **'奖励'**
  String get iconLabelBonus;

  /// No description provided for @iconLabelWork.
  ///
  /// In zh, this message translates to:
  /// **'工作'**
  String get iconLabelWork;

  /// No description provided for @iconLabelTransferOut.
  ///
  /// In zh, this message translates to:
  /// **'转出'**
  String get iconLabelTransferOut;

  /// No description provided for @iconLabelTransferIn.
  ///
  /// In zh, this message translates to:
  /// **'转入'**
  String get iconLabelTransferIn;

  /// No description provided for @iconLabelRepayment.
  ///
  /// In zh, this message translates to:
  /// **'还款'**
  String get iconLabelRepayment;

  /// No description provided for @iconLabelAdjust.
  ///
  /// In zh, this message translates to:
  /// **'调整'**
  String get iconLabelAdjust;

  /// No description provided for @iconLabelPay.
  ///
  /// In zh, this message translates to:
  /// **'支付'**
  String get iconLabelPay;

  /// No description provided for @iconLabelWechat.
  ///
  /// In zh, this message translates to:
  /// **'微信'**
  String get iconLabelWechat;

  /// No description provided for @iconLabelCredit.
  ///
  /// In zh, this message translates to:
  /// **'信用'**
  String get iconLabelCredit;

  /// No description provided for @iconLabelBank.
  ///
  /// In zh, this message translates to:
  /// **'银行'**
  String get iconLabelBank;

  /// No description provided for @iconLabelCash.
  ///
  /// In zh, this message translates to:
  /// **'现金'**
  String get iconLabelCash;

  /// No description provided for @iconLabelInvestment.
  ///
  /// In zh, this message translates to:
  /// **'投资'**
  String get iconLabelInvestment;

  /// No description provided for @iconLabelSavings.
  ///
  /// In zh, this message translates to:
  /// **'储蓄'**
  String get iconLabelSavings;

  /// No description provided for @iconLabelCard.
  ///
  /// In zh, this message translates to:
  /// **'卡片'**
  String get iconLabelCard;

  /// No description provided for @iconLabelFolder.
  ///
  /// In zh, this message translates to:
  /// **'分组'**
  String get iconLabelFolder;

  /// No description provided for @iconLabelWallet.
  ///
  /// In zh, this message translates to:
  /// **'钱包'**
  String get iconLabelWallet;

  /// No description provided for @iconGroupCredit.
  ///
  /// In zh, this message translates to:
  /// **'信用账户'**
  String get iconGroupCredit;

  /// No description provided for @iconGroupPayment.
  ///
  /// In zh, this message translates to:
  /// **'支付平台'**
  String get iconGroupPayment;

  /// No description provided for @iconGroupBank.
  ///
  /// In zh, this message translates to:
  /// **'银行'**
  String get iconGroupBank;

  /// 调整余额时自动生成交易的备注
  ///
  /// In zh, this message translates to:
  /// **'余额调整'**
  String get balanceAdjustNote;

  /// No description provided for @commonNone.
  ///
  /// In zh, this message translates to:
  /// **'暂无'**
  String get commonNone;

  /// No description provided for @commonDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get commonDone;

  /// No description provided for @homeNoEntriesTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有交易'**
  String get homeNoEntriesTitle;

  /// No description provided for @homeNoEntriesDesc.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角加号开始第一笔记账。'**
  String get homeNoEntriesDesc;

  /// No description provided for @trendNet.
  ///
  /// In zh, this message translates to:
  /// **'结余 {amount}'**
  String trendNet(String amount);

  /// No description provided for @homeDaysTracked.
  ///
  /// In zh, this message translates to:
  /// **'记账日'**
  String get homeDaysTracked;

  /// No description provided for @daysCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}天'**
  String daysCount(int count);

  /// No description provided for @homeDailyAvgExpense.
  ///
  /// In zh, this message translates to:
  /// **'日均支出'**
  String get homeDailyAvgExpense;

  /// 图表气泡等处的「几月几日」短日期
  ///
  /// In zh, this message translates to:
  /// **'{date}'**
  String dateMonthDay(DateTime date);

  /// 首页预算卡标题(某月预算)
  ///
  /// In zh, this message translates to:
  /// **'{month}预算'**
  String monthBudgetTitle(DateTime month);

  /// No description provided for @budgetRemaining.
  ///
  /// In zh, this message translates to:
  /// **'剩余'**
  String get budgetRemaining;

  /// No description provided for @budgetDailyRemaining.
  ///
  /// In zh, this message translates to:
  /// **'剩余日均'**
  String get budgetDailyRemaining;

  /// No description provided for @budgetTotalLabel.
  ///
  /// In zh, this message translates to:
  /// **'预算 {amount}'**
  String budgetTotalLabel(String amount);

  /// No description provided for @incomeExpenseTitle.
  ///
  /// In zh, this message translates to:
  /// **'收支统计'**
  String get incomeExpenseTitle;

  /// No description provided for @homeNoStatsTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无统计'**
  String get homeNoStatsTitle;

  /// No description provided for @homeNoStatsDesc.
  ///
  /// In zh, this message translates to:
  /// **'当前月份没有对应记录。'**
  String get homeNoStatsDesc;

  /// No description provided for @statTypeTitle.
  ///
  /// In zh, this message translates to:
  /// **'统计类型'**
  String get statTypeTitle;

  /// No description provided for @statPeriodWeek.
  ///
  /// In zh, this message translates to:
  /// **'周'**
  String get statPeriodWeek;

  /// No description provided for @statPeriodMonth.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get statPeriodMonth;

  /// No description provided for @statPeriodQuarter.
  ///
  /// In zh, this message translates to:
  /// **'季'**
  String get statPeriodQuarter;

  /// No description provided for @statPeriodYear.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get statPeriodYear;

  /// No description provided for @statQuarterRange.
  ///
  /// In zh, this message translates to:
  /// **'{year}年第{quarter}季度'**
  String statQuarterRange(int year, int quarter);

  /// No description provided for @budgetCatOver.
  ///
  /// In zh, this message translates to:
  /// **'{category}超出 {amount}'**
  String budgetCatOver(String category, String amount);

  /// No description provided for @budgetCatUsed.
  ///
  /// In zh, this message translates to:
  /// **'{category}已用 {percent}%'**
  String budgetCatUsed(String category, String percent);

  /// No description provided for @entriesCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}笔'**
  String entriesCount(int count);

  /// No description provided for @categoryAll.
  ///
  /// In zh, this message translates to:
  /// **'全部分类'**
  String get categoryAll;

  /// No description provided for @tagPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择标签'**
  String get tagPickerTitle;

  /// No description provided for @coverBlueCity.
  ///
  /// In zh, this message translates to:
  /// **'蓝色城市'**
  String get coverBlueCity;

  /// No description provided for @coverAurora.
  ///
  /// In zh, this message translates to:
  /// **'极光夜色'**
  String get coverAurora;

  /// No description provided for @coverFinanceOffice.
  ///
  /// In zh, this message translates to:
  /// **'金融办公'**
  String get coverFinanceOffice;

  /// No description provided for @coverDeepBlue.
  ///
  /// In zh, this message translates to:
  /// **'深蓝渐层'**
  String get coverDeepBlue;

  /// No description provided for @assetsUngrouped.
  ///
  /// In zh, this message translates to:
  /// **'未分组'**
  String get assetsUngrouped;

  /// No description provided for @netAssets.
  ///
  /// In zh, this message translates to:
  /// **'净资产'**
  String get netAssets;

  /// No description provided for @assetsActions.
  ///
  /// In zh, this message translates to:
  /// **'资产操作'**
  String get assetsActions;

  /// No description provided for @assetsChangeCover.
  ///
  /// In zh, this message translates to:
  /// **'更换资产卡片背景'**
  String get assetsChangeCover;

  /// No description provided for @assetsAmount.
  ///
  /// In zh, this message translates to:
  /// **'资产 {amount}'**
  String assetsAmount(String amount);

  /// No description provided for @liabilitiesAmount.
  ///
  /// In zh, this message translates to:
  /// **'负债 {amount}'**
  String liabilitiesAmount(String amount);

  /// No description provided for @netAssetsAmount.
  ///
  /// In zh, this message translates to:
  /// **'净资产 {amount}'**
  String netAssetsAmount(String amount);

  /// 按月份序号的短月份标签(图表气泡/坐标)
  ///
  /// In zh, this message translates to:
  /// **'{month}月'**
  String monthNumber(int month);

  /// No description provided for @assetsEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有资产账户'**
  String get assetsEmptyTitle;

  /// No description provided for @assetsEmptyDesc.
  ///
  /// In zh, this message translates to:
  /// **'请先点击右上角添加资产，之后可以在这里按类型或分组查看资产。'**
  String get assetsEmptyDesc;

  /// No description provided for @assetsSortHint.
  ///
  /// In zh, this message translates to:
  /// **'拖动右侧手柄调整分组顺序'**
  String get assetsSortHint;

  /// No description provided for @hiddenAccountsCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}个隐藏账户'**
  String hiddenAccountsCount(int count);

  /// No description provided for @assetsCoverTitle.
  ///
  /// In zh, this message translates to:
  /// **'资产卡片背景'**
  String get assetsCoverTitle;

  /// No description provided for @coverUseOnline.
  ///
  /// In zh, this message translates to:
  /// **'使用线上图片'**
  String get coverUseOnline;

  /// No description provided for @coverEnterUrl.
  ///
  /// In zh, this message translates to:
  /// **'输入图片链接'**
  String get coverEnterUrl;

  /// No description provided for @coverPickLocal.
  ///
  /// In zh, this message translates to:
  /// **'选择本地图片'**
  String get coverPickLocal;

  /// No description provided for @coverClear.
  ///
  /// In zh, this message translates to:
  /// **'清除背景图片'**
  String get coverClear;

  /// No description provided for @coverPickOnlineTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择线上图片'**
  String get coverPickOnlineTitle;

  /// No description provided for @coverCustomTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义图片'**
  String get coverCustomTitle;

  /// No description provided for @coverUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'图片链接'**
  String get coverUrlLabel;

  /// No description provided for @coverCropTitle.
  ///
  /// In zh, this message translates to:
  /// **'裁剪资产背景'**
  String get coverCropTitle;

  /// No description provided for @coverGenerating.
  ///
  /// In zh, this message translates to:
  /// **'正在生成背景图…'**
  String get coverGenerating;

  /// No description provided for @accountAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加账户'**
  String get accountAdd;

  /// No description provided for @groupManage.
  ///
  /// In zh, this message translates to:
  /// **'管理分组'**
  String get groupManage;

  /// No description provided for @sectionSort.
  ///
  /// In zh, this message translates to:
  /// **'排序分组'**
  String get sectionSort;

  /// No description provided for @sectionSortNeedTwo.
  ///
  /// In zh, this message translates to:
  /// **'至少有 2 个分组才能排序'**
  String get sectionSortNeedTwo;

  /// No description provided for @sortLabel.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get sortLabel;

  /// No description provided for @hiddenAccountsTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐藏账户'**
  String get hiddenAccountsTitle;

  /// No description provided for @hiddenAccountsEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无隐藏账户'**
  String get hiddenAccountsEmptyTitle;

  /// No description provided for @hiddenAccountsEmptyDesc.
  ///
  /// In zh, this message translates to:
  /// **'隐藏账户会在这里集中展示。'**
  String get hiddenAccountsEmptyDesc;

  /// No description provided for @accountGroupsTitle.
  ///
  /// In zh, this message translates to:
  /// **'账户分组'**
  String get accountGroupsTitle;

  /// No description provided for @groupAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增分组'**
  String get groupAdd;

  /// No description provided for @groupsEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有账户分组'**
  String get groupsEmptyTitle;

  /// No description provided for @groupsEmptyDesc.
  ///
  /// In zh, this message translates to:
  /// **'点击右上角加号创建分组，用来整理不同账户。'**
  String get groupsEmptyDesc;

  /// No description provided for @accountsCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}个账户'**
  String accountsCount(int count);

  /// No description provided for @commonRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get commonRename;

  /// No description provided for @commonIcon.
  ///
  /// In zh, this message translates to:
  /// **'图标'**
  String get commonIcon;

  /// No description provided for @groupRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名分组'**
  String get groupRenameTitle;

  /// No description provided for @groupNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'分组名称'**
  String get groupNameLabel;

  /// No description provided for @groupIconPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择分组图标'**
  String get groupIconPickerTitle;

  /// No description provided for @accountIconLabel.
  ///
  /// In zh, this message translates to:
  /// **'账户图标'**
  String get accountIconLabel;

  /// No description provided for @accountSaveTooltip.
  ///
  /// In zh, this message translates to:
  /// **'保存账户'**
  String get accountSaveTooltip;

  /// No description provided for @accountTypeLabel.
  ///
  /// In zh, this message translates to:
  /// **'账户类型'**
  String get accountTypeLabel;

  /// No description provided for @accountNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'账户名称'**
  String get accountNameLabel;

  /// No description provided for @accountNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'账户名称必填'**
  String get accountNameRequired;

  /// No description provided for @cardLast4Label.
  ///
  /// In zh, this message translates to:
  /// **'卡号后四位'**
  String get cardLast4Label;

  /// No description provided for @cardLast4Invalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1-4 位数字'**
  String get cardLast4Invalid;

  /// No description provided for @cardLabel.
  ///
  /// In zh, this message translates to:
  /// **'卡号'**
  String get cardLabel;

  /// No description provided for @cardNumberLabel.
  ///
  /// In zh, this message translates to:
  /// **'完整卡号（选填）'**
  String get cardNumberLabel;

  /// No description provided for @cardNumberTitle.
  ///
  /// In zh, this message translates to:
  /// **'完整卡号'**
  String get cardNumberTitle;

  /// No description provided for @cardLast4Follow.
  ///
  /// In zh, this message translates to:
  /// **'跟随卡号'**
  String get cardLast4Follow;

  /// No description provided for @cardCopyTooltip.
  ///
  /// In zh, this message translates to:
  /// **'复制卡号'**
  String get cardCopyTooltip;

  /// No description provided for @copiedToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copiedToClipboard;

  /// No description provided for @accountSectionBasic.
  ///
  /// In zh, this message translates to:
  /// **'基本信息'**
  String get accountSectionBasic;

  /// No description provided for @accountSectionCard.
  ///
  /// In zh, this message translates to:
  /// **'卡片信息'**
  String get accountSectionCard;

  /// No description provided for @accountSectionCredit.
  ///
  /// In zh, this message translates to:
  /// **'信用'**
  String get accountSectionCredit;

  /// No description provided for @accountSectionDisplay.
  ///
  /// In zh, this message translates to:
  /// **'展示与记账'**
  String get accountSectionDisplay;

  /// No description provided for @accountSectionDanger.
  ///
  /// In zh, this message translates to:
  /// **'危险操作'**
  String get accountSectionDanger;

  /// No description provided for @accountBalanceLabel.
  ///
  /// In zh, this message translates to:
  /// **'账户余额'**
  String get accountBalanceLabel;

  /// No description provided for @accountBalanceHint.
  ///
  /// In zh, this message translates to:
  /// **'不填默认为 0'**
  String get accountBalanceHint;

  /// No description provided for @accountNoteLabel.
  ///
  /// In zh, this message translates to:
  /// **'账户备注'**
  String get accountNoteLabel;

  /// No description provided for @accountGroupLabel.
  ///
  /// In zh, this message translates to:
  /// **'账户分组'**
  String get accountGroupLabel;

  /// No description provided for @accountTypePickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择账户类型'**
  String get accountTypePickerTitle;

  /// No description provided for @accountGroupPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择账户分组'**
  String get accountGroupPickerTitle;

  /// No description provided for @balanceAdjustTooltip.
  ///
  /// In zh, this message translates to:
  /// **'调整余额'**
  String get balanceAdjustTooltip;

  /// No description provided for @currentBalance.
  ///
  /// In zh, this message translates to:
  /// **'当前余额'**
  String get currentBalance;

  /// No description provided for @balanceTrend.
  ///
  /// In zh, this message translates to:
  /// **'余额趋势'**
  String get balanceTrend;

  /// No description provided for @dayShort.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get dayShort;

  /// No description provided for @monthShort.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get monthShort;

  /// No description provided for @balanceAmount.
  ///
  /// In zh, this message translates to:
  /// **'余额 {amount}'**
  String balanceAmount(String amount);

  /// No description provided for @viewReport.
  ///
  /// In zh, this message translates to:
  /// **'查看报告'**
  String get viewReport;

  /// No description provided for @addEntryTooltip.
  ///
  /// In zh, this message translates to:
  /// **'记一笔'**
  String get addEntryTooltip;

  /// No description provided for @noEntriesTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无交易'**
  String get noEntriesTitle;

  /// No description provided for @accountNoEntriesDesc.
  ///
  /// In zh, this message translates to:
  /// **'该账户还没有交易记录。'**
  String get accountNoEntriesDesc;

  /// No description provided for @accountEntriesTitle.
  ///
  /// In zh, this message translates to:
  /// **'{name}交易'**
  String accountEntriesTitle(String name);

  /// No description provided for @allEntries.
  ///
  /// In zh, this message translates to:
  /// **'所有交易'**
  String get allEntries;

  /// No description provided for @includeInAssets.
  ///
  /// In zh, this message translates to:
  /// **'计入资产'**
  String get includeInAssets;

  /// No description provided for @commonType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get commonType;

  /// No description provided for @commonName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get commonName;

  /// No description provided for @notSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get notSet;

  /// No description provided for @clearOption.
  ///
  /// In zh, this message translates to:
  /// **'不设置'**
  String get clearOption;

  /// No description provided for @statementDay.
  ///
  /// In zh, this message translates to:
  /// **'账单日'**
  String get statementDay;

  /// No description provided for @dueDay.
  ///
  /// In zh, this message translates to:
  /// **'还款日'**
  String get dueDay;

  /// No description provided for @creditLimitLabel.
  ///
  /// In zh, this message translates to:
  /// **'信用额度'**
  String get creditLimitLabel;

  /// No description provided for @creditLimitEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置信用额度'**
  String get creditLimitEditTitle;

  /// No description provided for @creditUsedLabel.
  ///
  /// In zh, this message translates to:
  /// **'已用'**
  String get creditUsedLabel;

  /// No description provided for @creditAvailableLabel.
  ///
  /// In zh, this message translates to:
  /// **'可用额度'**
  String get creditAvailableLabel;

  /// No description provided for @currentBillLabel.
  ///
  /// In zh, this message translates to:
  /// **'本期账单'**
  String get currentBillLabel;

  /// No description provided for @creditRepayTitle.
  ///
  /// In zh, this message translates to:
  /// **'还款'**
  String get creditRepayTitle;

  /// No description provided for @creditRepayAction.
  ///
  /// In zh, this message translates to:
  /// **'还款'**
  String get creditRepayAction;

  /// No description provided for @creditRepayAmountLabel.
  ///
  /// In zh, this message translates to:
  /// **'还款金额'**
  String get creditRepayAmountLabel;

  /// No description provided for @creditRepayFromAccount.
  ///
  /// In zh, this message translates to:
  /// **'扣款账户'**
  String get creditRepayFromAccount;

  /// No description provided for @creditRepayNoAccountLabel.
  ///
  /// In zh, this message translates to:
  /// **'无账户（代还）'**
  String get creditRepayNoAccountLabel;

  /// No description provided for @creditRepayNoAccountHint.
  ///
  /// In zh, this message translates to:
  /// **'他人代还，不从你的账户扣款'**
  String get creditRepayNoAccountHint;

  /// No description provided for @creditRepayDefaultNote.
  ///
  /// In zh, this message translates to:
  /// **'还款'**
  String get creditRepayDefaultNote;

  /// No description provided for @creditRepaySuccess.
  ///
  /// In zh, this message translates to:
  /// **'已记录还款'**
  String get creditRepaySuccess;

  /// No description provided for @monthlyDayLabel.
  ///
  /// In zh, this message translates to:
  /// **'每月 {day} 日'**
  String monthlyDayLabel(int day);

  /// No description provided for @commonCurrency.
  ///
  /// In zh, this message translates to:
  /// **'货币'**
  String get commonCurrency;

  /// No description provided for @currencyCny.
  ///
  /// In zh, this message translates to:
  /// **'人民币'**
  String get currencyCny;

  /// No description provided for @commonNote.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get commonNote;

  /// No description provided for @commonNoneShort.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get commonNoneShort;

  /// No description provided for @commonGroup.
  ///
  /// In zh, this message translates to:
  /// **'分组'**
  String get commonGroup;

  /// No description provided for @accountDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除账户'**
  String get accountDelete;

  /// No description provided for @deletableLabel.
  ///
  /// In zh, this message translates to:
  /// **'可删除'**
  String get deletableLabel;

  /// No description provided for @hasEntriesLabel.
  ///
  /// In zh, this message translates to:
  /// **'已有交易'**
  String get hasEntriesLabel;

  /// No description provided for @balanceEditConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'是否确认修改余额？'**
  String get balanceEditConfirmTitle;

  /// No description provided for @balanceEditConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'将把「{name}」的余额调整为 {amount}。'**
  String balanceEditConfirmMessage(String name, String amount);

  /// No description provided for @balanceEditRecord.
  ///
  /// In zh, this message translates to:
  /// **'计入收支'**
  String get balanceEditRecord;

  /// No description provided for @balanceEditRecordDesc.
  ///
  /// In zh, this message translates to:
  /// **'生成一笔余额调整交易；不勾选则直接修改账户初始余额，不影响收支统计。'**
  String get balanceEditRecordDesc;

  /// No description provided for @accountNameEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑账户名称'**
  String get accountNameEditTitle;

  /// No description provided for @cardLast4EditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑卡号后四位'**
  String get cardLast4EditTitle;

  /// No description provided for @pickDueDay.
  ///
  /// In zh, this message translates to:
  /// **'选择还款日'**
  String get pickDueDay;

  /// No description provided for @pickStatementDay.
  ///
  /// In zh, this message translates to:
  /// **'选择账单日'**
  String get pickStatementDay;

  /// No description provided for @accountNoteEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑账户备注'**
  String get accountNoteEditTitle;

  /// No description provided for @accountReportTitle.
  ///
  /// In zh, this message translates to:
  /// **'账户报告'**
  String get accountReportTitle;

  /// No description provided for @thisMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get thisMonth;

  /// No description provided for @dueToday.
  ///
  /// In zh, this message translates to:
  /// **'就是今天'**
  String get dueToday;

  /// No description provided for @dueInDays.
  ///
  /// In zh, this message translates to:
  /// **'还有 {days} 天'**
  String dueInDays(int days);

  /// No description provided for @monthlyRepayLine.
  ///
  /// In zh, this message translates to:
  /// **'每月 {day} 日还款'**
  String monthlyRepayLine(int day);

  /// No description provided for @attachTakePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get attachTakePhoto;

  /// No description provided for @attachFromGallery.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择'**
  String get attachFromGallery;

  /// No description provided for @attachTitle.
  ///
  /// In zh, this message translates to:
  /// **'图片附件'**
  String get attachTitle;

  /// No description provided for @attachCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 张'**
  String attachCount(int count);

  /// No description provided for @attachUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前平台不支持添加图片附件'**
  String get attachUnsupported;

  /// No description provided for @attachDeleteTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除这张'**
  String get attachDeleteTooltip;

  /// No description provided for @entryDetailSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'记账详情'**
  String get entryDetailSubtitle;

  /// No description provided for @commonCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get commonCategory;

  /// No description provided for @allLabel.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get allLabel;

  /// No description provided for @transferOutAccount.
  ///
  /// In zh, this message translates to:
  /// **'转出账户'**
  String get transferOutAccount;

  /// No description provided for @transferInAccount.
  ///
  /// In zh, this message translates to:
  /// **'转入账户'**
  String get transferInAccount;

  /// No description provided for @pleaseSelect.
  ///
  /// In zh, this message translates to:
  /// **'请选择'**
  String get pleaseSelect;

  /// No description provided for @feeLabel.
  ///
  /// In zh, this message translates to:
  /// **'手续费'**
  String get feeLabel;

  /// No description provided for @feeNoneTapToFill.
  ///
  /// In zh, this message translates to:
  /// **'无（点击填写）'**
  String get feeNoneTapToFill;

  /// No description provided for @accountLabel.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get accountLabel;

  /// No description provided for @noAccountLabel.
  ///
  /// In zh, this message translates to:
  /// **'无账户'**
  String get noAccountLabel;

  /// No description provided for @noAccountHint.
  ///
  /// In zh, this message translates to:
  /// **'只记一笔金额，不计入任何账户余额'**
  String get noAccountHint;

  /// No description provided for @noUsableAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有可用账户'**
  String get noUsableAccountTitle;

  /// No description provided for @noUsableAccountDesc.
  ///
  /// In zh, this message translates to:
  /// **'请先在资产页添加或取消隐藏一个账户。'**
  String get noUsableAccountDesc;

  /// No description provided for @noteHint.
  ///
  /// In zh, this message translates to:
  /// **'点击添加备注'**
  String get noteHint;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @amountEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改金额'**
  String get amountEditTitle;

  /// No description provided for @transferFeeTitle.
  ///
  /// In zh, this message translates to:
  /// **'转账手续费'**
  String get transferFeeTitle;

  /// No description provided for @pickTransferOutAccount.
  ///
  /// In zh, this message translates to:
  /// **'选择转出账户'**
  String get pickTransferOutAccount;

  /// No description provided for @pickAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择账户'**
  String get pickAccountTitle;

  /// No description provided for @pickTransferInAccount.
  ///
  /// In zh, this message translates to:
  /// **'选择转入账户'**
  String get pickTransferInAccount;

  /// No description provided for @timeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部时间'**
  String get timeAll;

  /// No description provided for @timeYear.
  ///
  /// In zh, this message translates to:
  /// **'本年'**
  String get timeYear;

  /// No description provided for @timeQuarter.
  ///
  /// In zh, this message translates to:
  /// **'本季'**
  String get timeQuarter;

  /// No description provided for @timeWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get timeWeek;

  /// No description provided for @timeLast12Months.
  ///
  /// In zh, this message translates to:
  /// **'近12个月'**
  String get timeLast12Months;

  /// No description provided for @timeLast30Days.
  ///
  /// In zh, this message translates to:
  /// **'近30天'**
  String get timeLast30Days;

  /// No description provided for @timeLast6Weeks.
  ///
  /// In zh, this message translates to:
  /// **'近6周'**
  String get timeLast6Weeks;

  /// No description provided for @sortDateDesc.
  ///
  /// In zh, this message translates to:
  /// **'日期降序'**
  String get sortDateDesc;

  /// No description provided for @sortDateAsc.
  ///
  /// In zh, this message translates to:
  /// **'日期升序'**
  String get sortDateAsc;

  /// No description provided for @sortAmountDesc.
  ///
  /// In zh, this message translates to:
  /// **'金额降序'**
  String get sortAmountDesc;

  /// No description provided for @sortAmountAsc.
  ///
  /// In zh, this message translates to:
  /// **'金额升序'**
  String get sortAmountAsc;

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 项'**
  String selectedCount(int count);

  /// No description provided for @dayEntriesTitle.
  ///
  /// In zh, this message translates to:
  /// **'当日交易'**
  String get dayEntriesTitle;

  /// No description provided for @entriesListTitle.
  ///
  /// In zh, this message translates to:
  /// **'交易明细'**
  String get entriesListTitle;

  /// No description provided for @exitMultiSelect.
  ///
  /// In zh, this message translates to:
  /// **'退出多选'**
  String get exitMultiSelect;

  /// No description provided for @multiSelect.
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get multiSelect;

  /// No description provided for @entriesCountFull.
  ///
  /// In zh, this message translates to:
  /// **'{count} 笔交易'**
  String entriesCountFull(int count);

  /// No description provided for @netLabel.
  ///
  /// In zh, this message translates to:
  /// **'结余'**
  String get netLabel;

  /// No description provided for @noMatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配交易'**
  String get noMatchTitle;

  /// No description provided for @noMatchDesc.
  ///
  /// In zh, this message translates to:
  /// **'换一个关键词、账户或分类再试。'**
  String get noMatchDesc;

  /// No description provided for @emptyEntriesDesc.
  ///
  /// In zh, this message translates to:
  /// **'保存交易后会在这里按日期展示。'**
  String get emptyEntriesDesc;

  /// No description provided for @filterTimeTitle.
  ///
  /// In zh, this message translates to:
  /// **'筛选时间'**
  String get filterTimeTitle;

  /// No description provided for @sortTitle.
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get sortTitle;

  /// No description provided for @filterAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'筛选账户'**
  String get filterAccountTitle;

  /// No description provided for @allAccounts.
  ///
  /// In zh, this message translates to:
  /// **'全部账户'**
  String get allAccounts;

  /// No description provided for @filterCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'筛选分类'**
  String get filterCategoryTitle;

  /// No description provided for @filterTagTitle.
  ///
  /// In zh, this message translates to:
  /// **'筛选标签'**
  String get filterTagTitle;

  /// No description provided for @allTags.
  ///
  /// In zh, this message translates to:
  /// **'全部标签'**
  String get allTags;

  /// No description provided for @unknownTag.
  ///
  /// In zh, this message translates to:
  /// **'未知标签'**
  String get unknownTag;

  /// No description provided for @tagLabel.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tagLabel;

  /// No description provided for @deleteEntriesTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除 {count} 笔交易？'**
  String deleteEntriesTitle(int count);

  /// No description provided for @deleteEntriesMessage.
  ///
  /// In zh, this message translates to:
  /// **'删除后无法恢复，相关图片附件也会一并移除。'**
  String get deleteEntriesMessage;

  /// No description provided for @changeCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'改分类（仅改同类型交易）'**
  String get changeCategoryTitle;

  /// No description provided for @changedCategoryCount.
  ///
  /// In zh, this message translates to:
  /// **'已修改 {count} 笔交易的分类'**
  String changedCategoryCount(int count);

  /// No description provided for @changeAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'改账户'**
  String get changeAccountTitle;

  /// No description provided for @changedAccountCount.
  ///
  /// In zh, this message translates to:
  /// **'已修改 {count} 笔交易的账户'**
  String changedAccountCount(int count);

  /// No description provided for @yearLabel.
  ///
  /// In zh, this message translates to:
  /// **'{year}年'**
  String yearLabel(int year);

  /// No description provided for @quarterLabel.
  ///
  /// In zh, this message translates to:
  /// **'季度{quarter}'**
  String quarterLabel(int quarter);

  /// No description provided for @weekNumber.
  ///
  /// In zh, this message translates to:
  /// **'{week}周'**
  String weekNumber(int week);

  /// No description provided for @yearWeek.
  ///
  /// In zh, this message translates to:
  /// **'{year}年{week}周'**
  String yearWeek(int year, int week);

  /// No description provided for @prevRange.
  ///
  /// In zh, this message translates to:
  /// **'上一段'**
  String get prevRange;

  /// No description provided for @nextRange.
  ///
  /// In zh, this message translates to:
  /// **'下一段'**
  String get nextRange;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索备注、分类、账户或金额'**
  String get searchHint;

  /// No description provided for @clearFilters.
  ///
  /// In zh, this message translates to:
  /// **'清空筛选'**
  String get clearFilters;

  /// No description provided for @prevDay.
  ///
  /// In zh, this message translates to:
  /// **'前一天'**
  String get prevDay;

  /// No description provided for @nextDay.
  ///
  /// In zh, this message translates to:
  /// **'后一天'**
  String get nextDay;

  /// No description provided for @entryMissing.
  ///
  /// In zh, this message translates to:
  /// **'交易不存在'**
  String get entryMissing;

  /// No description provided for @deleteEntryTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除交易'**
  String get deleteEntryTooltip;

  /// No description provided for @saveEntryTooltip.
  ///
  /// In zh, this message translates to:
  /// **'保存交易'**
  String get saveEntryTooltip;

  /// No description provided for @amountLabel.
  ///
  /// In zh, this message translates to:
  /// **'金额'**
  String get amountLabel;

  /// No description provided for @dateLabel.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get dateLabel;

  /// No description provided for @timeLabel.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get timeLabel;

  /// No description provided for @markReimbursable.
  ///
  /// In zh, this message translates to:
  /// **'标记待报销'**
  String get markReimbursable;

  /// No description provided for @refundLabel.
  ///
  /// In zh, this message translates to:
  /// **'退款 / 报销回款'**
  String get refundLabel;

  /// No description provided for @refundedAmountLabel.
  ///
  /// In zh, this message translates to:
  /// **'已冲抵 {amount}'**
  String refundedAmountLabel(String amount);

  /// No description provided for @refundAmountTitle.
  ///
  /// In zh, this message translates to:
  /// **'退款 / 报销回款金额'**
  String get refundAmountTitle;

  /// No description provided for @refundRecordsTitle.
  ///
  /// In zh, this message translates to:
  /// **'退款'**
  String get refundRecordsTitle;

  /// No description provided for @refundAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加退款'**
  String get refundAdd;

  /// No description provided for @refundEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑退款'**
  String get refundEditTitle;

  /// No description provided for @refundStatusSettled.
  ///
  /// In zh, this message translates to:
  /// **'已到账'**
  String get refundStatusSettled;

  /// No description provided for @refundStatusPending.
  ///
  /// In zh, this message translates to:
  /// **'待到账'**
  String get refundStatusPending;

  /// No description provided for @refundToAccountLabel.
  ///
  /// In zh, this message translates to:
  /// **'到账账户'**
  String get refundToAccountLabel;

  /// No description provided for @refundArrivalDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'到账日期'**
  String get refundArrivalDateLabel;

  /// No description provided for @refundInitiatedDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'发起日期'**
  String get refundInitiatedDateLabel;

  /// No description provided for @refundAmountShort.
  ///
  /// In zh, this message translates to:
  /// **'退款金额'**
  String get refundAmountShort;

  /// No description provided for @refundIsSettledLabel.
  ///
  /// In zh, this message translates to:
  /// **'已到账（钱已退回账户）'**
  String get refundIsSettledLabel;

  /// No description provided for @refundMarkSettled.
  ///
  /// In zh, this message translates to:
  /// **'标记已到账'**
  String get refundMarkSettled;

  /// No description provided for @refundEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无退款，点下方添加'**
  String get refundEmpty;

  /// No description provided for @refundDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除这笔退款吗？删除后原支出净额会恢复。'**
  String get refundDeleteConfirm;

  /// No description provided for @refundRemainingLabel.
  ///
  /// In zh, this message translates to:
  /// **'剩余可退 {amount}'**
  String refundRemainingLabel(String amount);

  /// No description provided for @refundOverCapNotice.
  ///
  /// In zh, this message translates to:
  /// **'退款不能超过剩余可退，已按上限 {amount} 记入'**
  String refundOverCapNotice(String amount);

  /// No description provided for @refundNetLabel.
  ///
  /// In zh, this message translates to:
  /// **'净支出 {amount}'**
  String refundNetLabel(String amount);

  /// No description provided for @refundSummaryLine.
  ///
  /// In zh, this message translates to:
  /// **'已退 {count} 笔 · 净支出 {net}'**
  String refundSummaryLine(int count, String net);

  /// No description provided for @refundPendingTotal.
  ///
  /// In zh, this message translates to:
  /// **'待到账 {amount}'**
  String refundPendingTotal(String amount);

  /// No description provided for @pendingRefundsTitle.
  ///
  /// In zh, this message translates to:
  /// **'待退款'**
  String get pendingRefundsTitle;

  /// No description provided for @pendingRefundsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'已申请、还没到账的退款'**
  String get pendingRefundsSubtitle;

  /// No description provided for @pendingRefundsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有待到账的退款'**
  String get pendingRefundsEmpty;

  /// No description provided for @pendingRefundsCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 笔在路上'**
  String pendingRefundsCount(int count);

  /// No description provided for @pickTypeTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择类型'**
  String get pickTypeTitle;

  /// No description provided for @noteEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑备注'**
  String get noteEditTitle;

  /// No description provided for @transferNeedsTwoAccounts.
  ///
  /// In zh, this message translates to:
  /// **'转账需要两个不同的账户,请先添加转入账户。'**
  String get transferNeedsTwoAccounts;

  /// No description provided for @deleteEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除此交易？'**
  String get deleteEntryTitle;

  /// No description provided for @deleteEntryMessage.
  ///
  /// In zh, this message translates to:
  /// **'删除后无法恢复，本地保存的这笔记录会被移除。'**
  String get deleteEntryMessage;

  /// No description provided for @todayLabel.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get todayLabel;

  /// No description provided for @yesterdayLabel.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get yesterdayLabel;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @changeCategoryShort.
  ///
  /// In zh, this message translates to:
  /// **'改分类'**
  String get changeCategoryShort;

  /// No description provided for @changeAccountShort.
  ///
  /// In zh, this message translates to:
  /// **'改账户'**
  String get changeAccountShort;

  /// No description provided for @budgetSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'预算设置'**
  String get budgetSettingsTitle;

  /// 年月标签(如 2026年7月)
  ///
  /// In zh, this message translates to:
  /// **'{month}'**
  String yearMonth(DateTime month);

  /// No description provided for @budgetUsed.
  ///
  /// In zh, this message translates to:
  /// **'已用'**
  String get budgetUsed;

  /// No description provided for @budgetOverspentThisMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月已超支'**
  String get budgetOverspentThisMonth;

  /// No description provided for @budgetAvailableThisMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月可用预算'**
  String get budgetAvailableThisMonth;

  /// No description provided for @budgetMonthExpense.
  ///
  /// In zh, this message translates to:
  /// **'本月支出'**
  String get budgetMonthExpense;

  /// No description provided for @budgetOverAmountLabel.
  ///
  /// In zh, this message translates to:
  /// **'超出预算'**
  String get budgetOverAmountLabel;

  /// No description provided for @budgetRemainingQuota.
  ///
  /// In zh, this message translates to:
  /// **'剩余额度'**
  String get budgetRemainingQuota;

  /// No description provided for @budgetAmountLabel.
  ///
  /// In zh, this message translates to:
  /// **'预算金额'**
  String get budgetAmountLabel;

  /// No description provided for @categoryBudgetTitle.
  ///
  /// In zh, this message translates to:
  /// **'分类预算'**
  String get categoryBudgetTitle;

  /// No description provided for @monthExpenseCategories.
  ///
  /// In zh, this message translates to:
  /// **'本月支出分类'**
  String get monthExpenseCategories;

  /// No description provided for @noExpenseCategories.
  ///
  /// In zh, this message translates to:
  /// **'还没有支出分类'**
  String get noExpenseCategories;

  /// No description provided for @setMonthBudgetTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置本月预算'**
  String get setMonthBudgetTitle;

  /// No description provided for @monthBudgetAmountLabel.
  ///
  /// In zh, this message translates to:
  /// **'月份预算金额'**
  String get monthBudgetAmountLabel;

  /// No description provided for @dailyBudgetTitle.
  ///
  /// In zh, this message translates to:
  /// **'按日预算'**
  String get dailyBudgetTitle;

  /// No description provided for @dailyBudgetNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置每日上限，点击设置'**
  String get dailyBudgetNotSet;

  /// No description provided for @dailyBudgetLimitLabel.
  ///
  /// In zh, this message translates to:
  /// **'每日上限 {amount}'**
  String dailyBudgetLimitLabel(String amount);

  /// No description provided for @dailyBudgetTodaySpent.
  ///
  /// In zh, this message translates to:
  /// **'今日已花'**
  String get dailyBudgetTodaySpent;

  /// No description provided for @dailyBudgetTodayLeft.
  ///
  /// In zh, this message translates to:
  /// **'今日剩余'**
  String get dailyBudgetTodayLeft;

  /// No description provided for @dailyBudgetTodayOver.
  ///
  /// In zh, this message translates to:
  /// **'今日超支'**
  String get dailyBudgetTodayOver;

  /// No description provided for @setDailyBudgetTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置每日预算'**
  String get setDailyBudgetTitle;

  /// No description provided for @dailyBudgetAmountLabel.
  ///
  /// In zh, this message translates to:
  /// **'每日预算金额'**
  String get dailyBudgetAmountLabel;

  /// No description provided for @setCategoryBudgetTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置{category}预算'**
  String setCategoryBudgetTitle(String category);

  /// No description provided for @categoryBudgetAmountLabel.
  ///
  /// In zh, this message translates to:
  /// **'分类预算金额'**
  String get categoryBudgetAmountLabel;

  /// No description provided for @budgetHistoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'预算历史'**
  String get budgetHistoryTitle;

  /// No description provided for @last12MonthsSub.
  ///
  /// In zh, this message translates to:
  /// **'最近 12 个月'**
  String get last12MonthsSub;

  /// No description provided for @monthSummary.
  ///
  /// In zh, this message translates to:
  /// **'月份汇总'**
  String get monthSummary;

  /// No description provided for @last6MonthsTrend.
  ///
  /// In zh, this message translates to:
  /// **'近 6 月趋势'**
  String get last6MonthsTrend;

  /// No description provided for @budgetLegend.
  ///
  /// In zh, this message translates to:
  /// **'预算'**
  String get budgetLegend;

  /// No description provided for @expenseAmountLabel.
  ///
  /// In zh, this message translates to:
  /// **'支出 {amount}'**
  String expenseAmountLabel(String amount);

  /// No description provided for @historyCompare.
  ///
  /// In zh, this message translates to:
  /// **'历史对比'**
  String get historyCompare;

  /// No description provided for @lastMonthExpense.
  ///
  /// In zh, this message translates to:
  /// **'上月支出'**
  String get lastMonthExpense;

  /// No description provided for @noExpenseYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无支出'**
  String get noExpenseYet;

  /// No description provided for @compareBaseline.
  ///
  /// In zh, this message translates to:
  /// **'对比基准'**
  String get compareBaseline;

  /// No description provided for @budgetUsageLine.
  ///
  /// In zh, this message translates to:
  /// **'预算使用率 {percent}%，较上月 {delta}'**
  String budgetUsageLine(String percent, String delta);

  /// No description provided for @notSetBudget.
  ///
  /// In zh, this message translates to:
  /// **'未设置预算'**
  String get notSetBudget;

  /// No description provided for @overBy.
  ///
  /// In zh, this message translates to:
  /// **'超出 {amount}'**
  String overBy(String amount);

  /// No description provided for @remainingAmount.
  ///
  /// In zh, this message translates to:
  /// **'剩余 {amount}'**
  String remainingAmount(String amount);

  /// No description provided for @budgetHistoryLine.
  ///
  /// In zh, this message translates to:
  /// **'预算 {budget} · 支出 {expense} · 已用 {percent}%'**
  String budgetHistoryLine(String budget, String expense, String percent);

  /// No description provided for @categoryBudgetOk.
  ///
  /// In zh, this message translates to:
  /// **'分类预算正常'**
  String get categoryBudgetOk;

  /// No description provided for @categoryOverspent.
  ///
  /// In zh, this message translates to:
  /// **'{category}已超支'**
  String categoryOverspent(String category);

  /// No description provided for @categoryNearBudget.
  ///
  /// In zh, this message translates to:
  /// **'{category}接近预算'**
  String categoryNearBudget(String category);

  /// No description provided for @categoryBudgetOkDesc.
  ///
  /// In zh, this message translates to:
  /// **'已设置 {count} 个分类预算，当前没有临近超支的分类。'**
  String categoryBudgetOkDesc(int count);

  /// No description provided for @categoryOverspentDesc.
  ///
  /// In zh, this message translates to:
  /// **'已超出 {amount}，本月已用 {percent}%。'**
  String categoryOverspentDesc(String amount, String percent);

  /// No description provided for @categoryNearDesc.
  ///
  /// In zh, this message translates to:
  /// **'剩余 {amount}，本月已用 {percent}%。'**
  String categoryNearDesc(String amount, String percent);

  /// No description provided for @catNoBudgetLine.
  ///
  /// In zh, this message translates to:
  /// **'未设置预算 · 本月支出 {amount}'**
  String catNoBudgetLine(String amount);

  /// No description provided for @catRemainLine.
  ///
  /// In zh, this message translates to:
  /// **'剩余 {amount} · 已用 {percent}%'**
  String catRemainLine(String amount, String percent);

  /// No description provided for @catOverLine.
  ///
  /// In zh, this message translates to:
  /// **'超出 {amount} · 已用 {percent}%'**
  String catOverLine(String amount, String percent);

  /// No description provided for @lastMonthNone.
  ///
  /// In zh, this message translates to:
  /// **'上月无支出'**
  String get lastMonthNone;

  /// No description provided for @lastMonthAmount.
  ///
  /// In zh, this message translates to:
  /// **'上月 {amount}'**
  String lastMonthAmount(String amount);

  /// No description provided for @setLabel.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get setLabel;

  /// No description provided for @monthEnded.
  ///
  /// In zh, this message translates to:
  /// **'月份已结束'**
  String get monthEnded;

  /// No description provided for @remainingDaysInclToday.
  ///
  /// In zh, this message translates to:
  /// **'含今天还剩 {days} 天'**
  String remainingDaysInclToday(int days);

  /// No description provided for @monthTotalDays.
  ///
  /// In zh, this message translates to:
  /// **'本月共 {days} 天'**
  String monthTotalDays(int days);

  /// No description provided for @budgetTipNoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有设置预算'**
  String get budgetTipNoneTitle;

  /// No description provided for @budgetTipNoneDesc.
  ///
  /// In zh, this message translates to:
  /// **'设置本月预算后，首页和这里会同步展示预算进度、剩余额度和剩余日均。'**
  String get budgetTipNoneDesc;

  /// No description provided for @budgetTipOverTitle.
  ///
  /// In zh, this message translates to:
  /// **'预算已经超出'**
  String get budgetTipOverTitle;

  /// No description provided for @budgetTipOverDesc.
  ///
  /// In zh, this message translates to:
  /// **'本月支出已超过预算 {amount}，后续支出会继续计入本月统计。'**
  String budgetTipOverDesc(String amount);

  /// No description provided for @budgetTipNearTitle.
  ///
  /// In zh, this message translates to:
  /// **'预算接近用完'**
  String get budgetTipNearTitle;

  /// No description provided for @budgetTipNearDesc.
  ///
  /// In zh, this message translates to:
  /// **'本月预算已使用 {percent}%，剩余 {amount}。'**
  String budgetTipNearDesc(String percent, String amount);

  /// No description provided for @budgetTipOkTitle.
  ///
  /// In zh, this message translates to:
  /// **'预算状态正常'**
  String get budgetTipOkTitle;

  /// No description provided for @budgetTipOkDesc.
  ///
  /// In zh, this message translates to:
  /// **'按当前预算，本月剩余每天约可支出 {amount}。'**
  String budgetTipOkDesc(String amount);

  /// No description provided for @budgetTipEndedTitle.
  ///
  /// In zh, this message translates to:
  /// **'本月预算已结算'**
  String get budgetTipEndedTitle;

  /// No description provided for @budgetTipEndedDesc.
  ///
  /// In zh, this message translates to:
  /// **'这个月份已结束，可切换到其他月份继续查看或调整预算。'**
  String get budgetTipEndedDesc;

  /// No description provided for @deltaFlatVsLastMonth.
  ///
  /// In zh, this message translates to:
  /// **'与上月持平'**
  String get deltaFlatVsLastMonth;

  /// No description provided for @deltaMoreVsLastMonth.
  ///
  /// In zh, this message translates to:
  /// **'比上月多 {amount}'**
  String deltaMoreVsLastMonth(String amount);

  /// No description provided for @deltaLessVsLastMonth.
  ///
  /// In zh, this message translates to:
  /// **'比上月少 {amount}'**
  String deltaLessVsLastMonth(String amount);

  /// No description provided for @usageFlat.
  ///
  /// In zh, this message translates to:
  /// **'持平'**
  String get usageFlat;

  /// No description provided for @usageUp.
  ///
  /// In zh, this message translates to:
  /// **'增加 {points} 个点'**
  String usageUp(String points);

  /// No description provided for @usageDown.
  ///
  /// In zh, this message translates to:
  /// **'降低 {points} 个点'**
  String usageDown(String points);

  /// No description provided for @statAnalysisTitle.
  ///
  /// In zh, this message translates to:
  /// **'统计分析'**
  String get statAnalysisTitle;

  /// No description provided for @pickTimeRange.
  ///
  /// In zh, this message translates to:
  /// **'选择时间范围'**
  String get pickTimeRange;

  /// No description provided for @okLabel.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get okLabel;

  /// No description provided for @customRange.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get customRange;

  /// No description provided for @overviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'收支概览'**
  String get overviewTitle;

  /// No description provided for @yoyMomTitle.
  ///
  /// In zh, this message translates to:
  /// **'同比 · 环比'**
  String get yoyMomTitle;

  /// No description provided for @yoyMomDesc.
  ///
  /// In zh, this message translates to:
  /// **'较上月为环比，较去年同期为同比'**
  String get yoyMomDesc;

  /// No description provided for @momLabel.
  ///
  /// In zh, this message translates to:
  /// **'环比'**
  String get momLabel;

  /// No description provided for @yoyLabel.
  ///
  /// In zh, this message translates to:
  /// **'同比'**
  String get yoyLabel;

  /// No description provided for @monthlyTrendTitle.
  ///
  /// In zh, this message translates to:
  /// **'月度趋势'**
  String get monthlyTrendTitle;

  /// No description provided for @categoryRank.
  ///
  /// In zh, this message translates to:
  /// **'分类排行'**
  String get categoryRank;

  /// No description provided for @rankGroupCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get rankGroupCategory;

  /// No description provided for @rankGroupSubCategory.
  ///
  /// In zh, this message translates to:
  /// **'子分类'**
  String get rankGroupSubCategory;

  /// No description provided for @rankGroupTag.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get rankGroupTag;

  /// No description provided for @tagRank.
  ///
  /// In zh, this message translates to:
  /// **'标签排行'**
  String get tagRank;

  /// No description provided for @tagRankOverlapNote.
  ///
  /// In zh, this message translates to:
  /// **'同一笔可带多个标签，各标签占比之和可能超过 100%'**
  String get tagRankOverlapNote;

  /// No description provided for @subCategoryOf.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」的子分类'**
  String subCategoryOf(String name);

  /// No description provided for @noDimData.
  ///
  /// In zh, this message translates to:
  /// **'暂无{dim}数据'**
  String noDimData(String dim);

  /// No description provided for @noDimDesc.
  ///
  /// In zh, this message translates to:
  /// **'该时间范围内没有{dim}记录。'**
  String noDimDesc(String dim);

  /// No description provided for @reportsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'数据看板'**
  String get reportsSubtitle;

  /// No description provided for @noCategoryData.
  ///
  /// In zh, this message translates to:
  /// **'暂无分类数据'**
  String get noCategoryData;

  /// No description provided for @noCategoryDesc.
  ///
  /// In zh, this message translates to:
  /// **'保存支出记录后会在这里显示分类排行。'**
  String get noCategoryDesc;

  /// No description provided for @thisYearLabel.
  ///
  /// In zh, this message translates to:
  /// **'今年'**
  String get thisYearLabel;

  /// No description provided for @noTagData.
  ///
  /// In zh, this message translates to:
  /// **'暂无标签数据'**
  String get noTagData;

  /// No description provided for @noTagDesc.
  ///
  /// In zh, this message translates to:
  /// **'给交易打上标签后，会在这里按标签汇总支出。'**
  String get noTagDesc;

  /// No description provided for @overBudgetLabel.
  ///
  /// In zh, this message translates to:
  /// **'已超预算'**
  String get overBudgetLabel;

  /// No description provided for @remainingBudgetLabel.
  ///
  /// In zh, this message translates to:
  /// **'剩余预算'**
  String get remainingBudgetLabel;

  /// No description provided for @expenseOnlyNote.
  ///
  /// In zh, this message translates to:
  /// **'仅记录支出'**
  String get expenseOnlyNote;

  /// No description provided for @usedPercent.
  ///
  /// In zh, this message translates to:
  /// **'已用 {percent}%'**
  String usedPercent(String percent);

  /// No description provided for @monthBudgetLabel.
  ///
  /// In zh, this message translates to:
  /// **'本月预算'**
  String get monthBudgetLabel;

  /// No description provided for @countItems.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个'**
  String countItems(int count);

  /// No description provided for @overCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个超支'**
  String overCountLabel(int count);

  /// No description provided for @normalLabel.
  ///
  /// In zh, this message translates to:
  /// **'正常'**
  String get normalLabel;

  /// No description provided for @othersLabel.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get othersLabel;

  /// No description provided for @tagShareOfExpense.
  ///
  /// In zh, this message translates to:
  /// **'占支出 {percent}%'**
  String tagShareOfExpense(String percent);

  /// No description provided for @bookkeepingDays.
  ///
  /// In zh, this message translates to:
  /// **'记账天数'**
  String get bookkeepingDays;

  /// No description provided for @bookkeepingYears.
  ///
  /// In zh, this message translates to:
  /// **'记账年数'**
  String get bookkeepingYears;

  /// No description provided for @reminderPickTime.
  ///
  /// In zh, this message translates to:
  /// **'选择提醒时间'**
  String get reminderPickTime;

  /// No description provided for @reminderTitle.
  ///
  /// In zh, this message translates to:
  /// **'记账提醒'**
  String get reminderTitle;

  /// No description provided for @reminderDaily.
  ///
  /// In zh, this message translates to:
  /// **'每日提醒'**
  String get reminderDaily;

  /// No description provided for @reminderTimeLabel.
  ///
  /// In zh, this message translates to:
  /// **'提醒时间'**
  String get reminderTimeLabel;

  /// No description provided for @reminderDescSupported.
  ///
  /// In zh, this message translates to:
  /// **'开启后每天到点会收到一条本地通知，提醒你记录当天收支。若长时间未收到，请在系统设置中确认已允许通知。'**
  String get reminderDescSupported;

  /// No description provided for @reminderDescUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前平台不支持本地通知，此设置仅在 Android / iOS 手机上生效。'**
  String get reminderDescUnsupported;

  /// No description provided for @reminderDailyAt.
  ///
  /// In zh, this message translates to:
  /// **'每日 {time}'**
  String reminderDailyAt(String time);

  /// No description provided for @recurringTitle.
  ///
  /// In zh, this message translates to:
  /// **'周期记账'**
  String get recurringTitle;

  /// No description provided for @recurringSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打开应用时自动补记到期交易'**
  String get recurringSubtitle;

  /// No description provided for @recurringAddTooltip.
  ///
  /// In zh, this message translates to:
  /// **'新增规则'**
  String get recurringAddTooltip;

  /// No description provided for @recurringEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有周期规则，点击右上角新增\n例如每月房租、每月工资'**
  String get recurringEmpty;

  /// No description provided for @nextRun.
  ///
  /// In zh, this message translates to:
  /// **'下次 {date}'**
  String nextRun(String date);

  /// No description provided for @recurringNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新增周期规则'**
  String get recurringNewTitle;

  /// No description provided for @recurringEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑周期规则'**
  String get recurringEditTitle;

  /// No description provided for @recurringDeleteTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除规则'**
  String get recurringDeleteTooltip;

  /// No description provided for @tapToFill.
  ///
  /// In zh, this message translates to:
  /// **'点击填写'**
  String get tapToFill;

  /// No description provided for @addAccountFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先添加账户'**
  String get addAccountFirst;

  /// No description provided for @frequencyLabel.
  ///
  /// In zh, this message translates to:
  /// **'频率'**
  String get frequencyLabel;

  /// No description provided for @startDateLabel.
  ///
  /// In zh, this message translates to:
  /// **'开始日期'**
  String get startDateLabel;

  /// No description provided for @pickFrequencyTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择频率'**
  String get pickFrequencyTitle;

  /// No description provided for @skipLabel.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get skipLabel;

  /// No description provided for @startBookkeeping.
  ///
  /// In zh, this message translates to:
  /// **'开始记账'**
  String get startBookkeeping;

  /// No description provided for @nextStep.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get nextStep;

  /// No description provided for @onboardWelcomeTitle.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 Veri Fin'**
  String get onboardWelcomeTitle;

  /// No description provided for @onboardWelcomeDesc.
  ///
  /// In zh, this message translates to:
  /// **'一款完全免费、数据自主、本地优先的记账应用。\n\n你的账目只保存在本机，不上传服务器；可随时导出 JSON 备份或加密上传到自己的 WebDAV。\n\n下面用几步帮你快速开始。'**
  String get onboardWelcomeDesc;

  /// No description provided for @onboardAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建第一个账户'**
  String get onboardAccountTitle;

  /// No description provided for @onboardAccountDesc.
  ///
  /// In zh, this message translates to:
  /// **'账户是记账的基础，比如「现金」「工资卡」。填写名称与当前余额即可，也可以稍后在「资产」页添加。'**
  String get onboardAccountDesc;

  /// No description provided for @onboardAccountNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'账户名称（可选）'**
  String get onboardAccountNameLabel;

  /// No description provided for @onboardAccountNameHint.
  ///
  /// In zh, this message translates to:
  /// **'如：现金 / 工资卡'**
  String get onboardAccountNameHint;

  /// No description provided for @onboardBalanceLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前余额（可选）'**
  String get onboardBalanceLabel;

  /// No description provided for @onboardBudgetDesc.
  ///
  /// In zh, this message translates to:
  /// **'设定每月预算后，首页与看板会展示预算执行进度，帮你控制支出。留空则暂不设预算，之后可在首页预算卡随时修改。'**
  String get onboardBudgetDesc;

  /// No description provided for @onboardBudgetLabel.
  ///
  /// In zh, this message translates to:
  /// **'本月预算（可选）'**
  String get onboardBudgetLabel;

  /// No description provided for @onboardBudgetHint.
  ///
  /// In zh, this message translates to:
  /// **'如：3000'**
  String get onboardBudgetHint;

  /// No description provided for @onboardDoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'一切就绪'**
  String get onboardDoneTitle;

  /// No description provided for @onboardDoneDesc.
  ///
  /// In zh, this message translates to:
  /// **'点击首页右下角的「+」即可快速记一笔。\n\n在「我的」页可以管理账本、分类、标签、周期记账，查看统计分析，设置记账提醒与数据备份。\n\n祝你记账愉快！'**
  String get onboardDoneDesc;

  /// No description provided for @legalUpdated.
  ///
  /// In zh, this message translates to:
  /// **'更新日期：{date}'**
  String legalUpdated(String date);

  /// No description provided for @privacyAndTerms.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策与用户协议'**
  String get privacyAndTerms;

  /// No description provided for @agreeContinue.
  ///
  /// In zh, this message translates to:
  /// **'同意并继续'**
  String get agreeContinue;

  /// No description provided for @disagreeExit.
  ///
  /// In zh, this message translates to:
  /// **'不同意并退出'**
  String get disagreeExit;

  /// No description provided for @legalPrivacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get legalPrivacyPolicy;

  /// No description provided for @legalUserAgreement.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get legalUserAgreement;

  /// No description provided for @profileCenterSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'个人中心'**
  String get profileCenterSubtitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTooltip;

  /// No description provided for @entryCountStat.
  ///
  /// In zh, this message translates to:
  /// **'交易笔数'**
  String get entryCountStat;

  /// No description provided for @bookkeepingMgmt.
  ///
  /// In zh, this message translates to:
  /// **'记账管理'**
  String get bookkeepingMgmt;

  /// No description provided for @ledgerLabel.
  ///
  /// In zh, this message translates to:
  /// **'账本'**
  String get ledgerLabel;

  /// No description provided for @categoryMgmt.
  ///
  /// In zh, this message translates to:
  /// **'分类管理'**
  String get categoryMgmt;

  /// No description provided for @tagMgmt.
  ///
  /// In zh, this message translates to:
  /// **'标签管理'**
  String get tagMgmt;

  /// No description provided for @countRules.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String countRules(int count);

  /// No description provided for @dataAndTools.
  ///
  /// In zh, this message translates to:
  /// **'数据与工具'**
  String get dataAndTools;

  /// No description provided for @reportShort.
  ///
  /// In zh, this message translates to:
  /// **'报表'**
  String get reportShort;

  /// No description provided for @notEnabled.
  ///
  /// In zh, this message translates to:
  /// **'未开启'**
  String get notEnabled;

  /// No description provided for @dataManagement.
  ///
  /// In zh, this message translates to:
  /// **'数据管理'**
  String get dataManagement;

  /// No description provided for @backupRestoreShort.
  ///
  /// In zh, this message translates to:
  /// **'备份 / 恢复'**
  String get backupRestoreShort;

  /// No description provided for @currentBookLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前：{name}'**
  String currentBookLabel(String name);

  /// No description provided for @bookAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增账本'**
  String get bookAdd;

  /// No description provided for @bookNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'账本名称'**
  String get bookNameLabel;

  /// No description provided for @defaultBookLabel.
  ///
  /// In zh, this message translates to:
  /// **'默认账本'**
  String get defaultBookLabel;

  /// No description provided for @bookActions.
  ///
  /// In zh, this message translates to:
  /// **'账本操作'**
  String get bookActions;

  /// No description provided for @defaultBookUndeletable.
  ///
  /// In zh, this message translates to:
  /// **'默认账本不可删除'**
  String get defaultBookUndeletable;

  /// No description provided for @bookRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名账本'**
  String get bookRenameTitle;

  /// No description provided for @bookDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除账本？'**
  String get bookDeleteTitle;

  /// No description provided for @bookDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'账本「{name}」及其中交易会被删除，此操作无法恢复。'**
  String bookDeleteMessage(String name);

  /// No description provided for @categoryMgmtSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'支持多级分类，用于记账和统计'**
  String get categoryMgmtSubtitle;

  /// No description provided for @addTopCategory.
  ///
  /// In zh, this message translates to:
  /// **'新增顶级分类'**
  String get addTopCategory;

  /// No description provided for @addCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'新增{type}分类'**
  String addCategoryTitle(String type);

  /// No description provided for @addSubCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'在「{parent}」下新增子分类'**
  String addSubCategoryTitle(String parent);

  /// No description provided for @categoryNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'分类名称'**
  String get categoryNameLabel;

  /// No description provided for @changeIcon.
  ///
  /// In zh, this message translates to:
  /// **'更换图标'**
  String get changeIcon;

  /// No description provided for @addSubCategory.
  ///
  /// In zh, this message translates to:
  /// **'新增子分类'**
  String get addSubCategory;

  /// No description provided for @moveTo.
  ///
  /// In zh, this message translates to:
  /// **'移动到…'**
  String get moveTo;

  /// No description provided for @deleteCategory.
  ///
  /// In zh, this message translates to:
  /// **'删除分类'**
  String get deleteCategory;

  /// No description provided for @noMoveTarget.
  ///
  /// In zh, this message translates to:
  /// **'没有可移动到的目标'**
  String get noMoveTarget;

  /// No description provided for @moveCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'移动「{name}」到'**
  String moveCategoryTitle(String name);

  /// No description provided for @topCategory.
  ///
  /// In zh, this message translates to:
  /// **'顶级分类'**
  String get topCategory;

  /// No description provided for @cannotMoveHere.
  ///
  /// In zh, this message translates to:
  /// **'该分类无法移动到此处'**
  String get cannotMoveHere;

  /// No description provided for @mergeCategory.
  ///
  /// In zh, this message translates to:
  /// **'合并到其他分类'**
  String get mergeCategory;

  /// No description provided for @mergeCategoryPickTitle.
  ///
  /// In zh, this message translates to:
  /// **'把「{name}」合并到'**
  String mergeCategoryPickTitle(String name);

  /// No description provided for @mergeCategoryConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'合并分类？'**
  String get mergeCategoryConfirmTitle;

  /// No description provided for @mergeCategoryConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'「{source}」的 {count} 笔交易将并入「{target}」，合并后「{source}」会被删除，且不可撤销。'**
  String mergeCategoryConfirmMessage(String source, int count, String target);

  /// No description provided for @mergeCategoryConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'合并'**
  String get mergeCategoryConfirmButton;

  /// No description provided for @mergedCategoryResult.
  ///
  /// In zh, this message translates to:
  /// **'已把 {count} 笔交易并入「{target}」'**
  String mergedCategoryResult(int count, String target);

  /// No description provided for @mergeCategoryFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法合并该分类'**
  String get mergeCategoryFailed;

  /// No description provided for @renameCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名分类'**
  String get renameCategoryTitle;

  /// No description provided for @pickIconTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择图标'**
  String get pickIconTitle;

  /// No description provided for @iconSectionBuiltin.
  ///
  /// In zh, this message translates to:
  /// **'内置图标'**
  String get iconSectionBuiltin;

  /// No description provided for @iconSectionEmoji.
  ///
  /// In zh, this message translates to:
  /// **'Emoji'**
  String get iconSectionEmoji;

  /// No description provided for @iconEmojiHint.
  ///
  /// In zh, this message translates to:
  /// **'输入或粘贴一个 emoji'**
  String get iconEmojiHint;

  /// No description provided for @iconEmojiUse.
  ///
  /// In zh, this message translates to:
  /// **'使用'**
  String get iconEmojiUse;

  /// No description provided for @systemCategoryUndeletable.
  ///
  /// In zh, this message translates to:
  /// **'系统分类不能删除'**
  String get systemCategoryUndeletable;

  /// No description provided for @categoryInUse.
  ///
  /// In zh, this message translates to:
  /// **'已有 {count} 笔交易使用该分类，不能删除'**
  String categoryInUse(int count);

  /// No description provided for @categoryUsedByRecurring.
  ///
  /// In zh, this message translates to:
  /// **'该分类正被 {count} 条周期记账使用，请先修改或删除相关规则'**
  String categoryUsedByRecurring(int count);

  /// No description provided for @moveSubFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先移动或删除其子分类'**
  String get moveSubFirst;

  /// No description provided for @keepOneCategory.
  ///
  /// In zh, this message translates to:
  /// **'至少需要保留一个分类'**
  String get keepOneCategory;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除分类？'**
  String get deleteCategoryTitle;

  /// No description provided for @deleteCategoryMessage.
  ///
  /// In zh, this message translates to:
  /// **'分类「{name}」删除后无法恢复。'**
  String deleteCategoryMessage(String name);

  /// No description provided for @categoryUndeletable.
  ///
  /// In zh, this message translates to:
  /// **'该分类暂时不能删除'**
  String get categoryUndeletable;

  /// No description provided for @catSubChildren.
  ///
  /// In zh, this message translates to:
  /// **'{type} · {children} 个子分类 · {count} 笔'**
  String catSubChildren(String type, int children, int count);

  /// No description provided for @catSubPlain.
  ///
  /// In zh, this message translates to:
  /// **'{type} · {count} 笔交易'**
  String catSubPlain(String type, int count);

  /// No description provided for @tagMgmtSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'记账时可给交易打多个标签'**
  String get tagMgmtSubtitle;

  /// No description provided for @tagAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增标签'**
  String get tagAdd;

  /// No description provided for @tagsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有标签，点击右上角新增'**
  String get tagsEmpty;

  /// No description provided for @deleteTag.
  ///
  /// In zh, this message translates to:
  /// **'删除标签'**
  String get deleteTag;

  /// No description provided for @tagRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名标签'**
  String get tagRenameTitle;

  /// No description provided for @tagDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除标签？'**
  String get tagDeleteTitle;

  /// No description provided for @tagDeleteInUse.
  ///
  /// In zh, this message translates to:
  /// **'标签「{name}」正被 {count} 笔交易使用，删除后会从这些交易上移除。'**
  String tagDeleteInUse(String name, int count);

  /// No description provided for @tagDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'标签「{name}」删除后无法恢复。'**
  String tagDeleteMessage(String name);

  /// No description provided for @personalInfo.
  ///
  /// In zh, this message translates to:
  /// **'个人信息'**
  String get personalInfo;

  /// No description provided for @nicknameLabel.
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get nicknameLabel;

  /// No description provided for @nicknameEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'未设置昵称'**
  String get nicknameEmptyTitle;

  /// No description provided for @nicknameEmptyMessage.
  ///
  /// In zh, this message translates to:
  /// **'未设置昵称，将使用默认昵称「Veri Fin」。是否继续保存？'**
  String get nicknameEmptyMessage;

  /// No description provided for @bioLabel.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get bioLabel;

  /// No description provided for @genderLabel.
  ///
  /// In zh, this message translates to:
  /// **'性别'**
  String get genderLabel;

  /// No description provided for @birthdayLabel.
  ///
  /// In zh, this message translates to:
  /// **'生日'**
  String get birthdayLabel;

  /// No description provided for @cityLabel.
  ///
  /// In zh, this message translates to:
  /// **'城市'**
  String get cityLabel;

  /// No description provided for @occupationLabel.
  ///
  /// In zh, this message translates to:
  /// **'职业'**
  String get occupationLabel;

  /// No description provided for @pickGenderTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择性别'**
  String get pickGenderTitle;

  /// No description provided for @cropAvatarTitle.
  ///
  /// In zh, this message translates to:
  /// **'裁剪头像'**
  String get cropAvatarTitle;

  /// No description provided for @avatarGenerating.
  ///
  /// In zh, this message translates to:
  /// **'正在生成头像…'**
  String get avatarGenerating;

  /// No description provided for @profileDefaultBio.
  ///
  /// In zh, this message translates to:
  /// **'完全免费 · 数据自主'**
  String get profileDefaultBio;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionBookkeeping.
  ///
  /// In zh, this message translates to:
  /// **'记账'**
  String get settingsSectionBookkeeping;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsSectionAbout;

  /// No description provided for @themeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeMode;

  /// No description provided for @hapticsLabel.
  ///
  /// In zh, this message translates to:
  /// **'触感反馈'**
  String get hapticsLabel;

  /// Settings toggle: always show amounts with two decimal places
  ///
  /// In zh, this message translates to:
  /// **'金额保留两位小数'**
  String get amountTwoDecimalsLabel;

  /// Subtitle explaining the two-decimals toggle
  ///
  /// In zh, this message translates to:
  /// **'开启后金额始终显示两位小数（如 12 显示为 12.00）'**
  String get amountTwoDecimalsDesc;

  /// No description provided for @appLockLabel.
  ///
  /// In zh, this message translates to:
  /// **'应用锁'**
  String get appLockLabel;

  /// No description provided for @enabledLabel.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get enabledLabel;

  /// No description provided for @checkUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdate;

  /// No description provided for @viewLabel.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get viewLabel;

  /// No description provided for @themePickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择主题模式'**
  String get themePickerTitle;

  /// No description provided for @dataMgmtSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复本地数据'**
  String get dataMgmtSubtitle;

  /// No description provided for @exportData.
  ///
  /// In zh, this message translates to:
  /// **'导出为文件'**
  String get exportData;

  /// No description provided for @jsonBackup.
  ///
  /// In zh, this message translates to:
  /// **'另存到系统下载目录'**
  String get jsonBackup;

  /// No description provided for @importData.
  ///
  /// In zh, this message translates to:
  /// **'从文件恢复'**
  String get importData;

  /// No description provided for @restoreFromFile.
  ///
  /// In zh, this message translates to:
  /// **'选择备份文件导入'**
  String get restoreFromFile;

  /// No description provided for @importFromSheets.
  ///
  /// In zh, this message translates to:
  /// **'导入账单'**
  String get importFromSheets;

  /// No description provided for @dataSectionLocalBackup.
  ///
  /// In zh, this message translates to:
  /// **'本地备份'**
  String get dataSectionLocalBackup;

  /// No description provided for @dataSectionMaintenance.
  ///
  /// In zh, this message translates to:
  /// **'应用维护'**
  String get dataSectionMaintenance;

  /// No description provided for @downloadCsvTemplate.
  ///
  /// In zh, this message translates to:
  /// **'下载 CSV 模板'**
  String get downloadCsvTemplate;

  /// No description provided for @excelHint.
  ///
  /// In zh, this message translates to:
  /// **'Excel 可另存为 CSV'**
  String get excelHint;

  /// No description provided for @importBillFile.
  ///
  /// In zh, this message translates to:
  /// **'导入账单文件'**
  String get importBillFile;

  /// No description provided for @importBillFileHint.
  ///
  /// In zh, this message translates to:
  /// **'支付宝 / 微信 / 薄荷'**
  String get importBillFileHint;

  /// No description provided for @selectBillSource.
  ///
  /// In zh, this message translates to:
  /// **'选择账单来源'**
  String get selectBillSource;

  /// No description provided for @selectBillSourceHint.
  ///
  /// In zh, this message translates to:
  /// **'先选平台，再选对应导出的文件，避免格式识别出错'**
  String get selectBillSourceHint;

  /// No description provided for @platformAlipay.
  ///
  /// In zh, this message translates to:
  /// **'支付宝'**
  String get platformAlipay;

  /// No description provided for @platformAlipayHint.
  ///
  /// In zh, this message translates to:
  /// **'交易明细 CSV'**
  String get platformAlipayHint;

  /// No description provided for @platformWechat.
  ///
  /// In zh, this message translates to:
  /// **'微信'**
  String get platformWechat;

  /// No description provided for @platformWechatHint.
  ///
  /// In zh, this message translates to:
  /// **'支付账单 xlsx'**
  String get platformWechatHint;

  /// No description provided for @platformMint.
  ///
  /// In zh, this message translates to:
  /// **'薄荷记账'**
  String get platformMint;

  /// No description provided for @platformMintHint.
  ///
  /// In zh, this message translates to:
  /// **'账单 CSV'**
  String get platformMintHint;

  /// No description provided for @platformYimuBill.
  ///
  /// In zh, this message translates to:
  /// **'一木记账 · 账单'**
  String get platformYimuBill;

  /// No description provided for @platformYimuBillHint.
  ///
  /// In zh, this message translates to:
  /// **'账单导出（.xls）'**
  String get platformYimuBillHint;

  /// No description provided for @platformYimuTransfer.
  ///
  /// In zh, this message translates to:
  /// **'一木记账 · 转账还款'**
  String get platformYimuTransfer;

  /// No description provided for @platformYimuTransferHint.
  ///
  /// In zh, this message translates to:
  /// **'转账还款导出（.xls）'**
  String get platformYimuTransferHint;

  /// No description provided for @platformTally.
  ///
  /// In zh, this message translates to:
  /// **'Tally 记账'**
  String get platformTally;

  /// No description provided for @platformTallyHint.
  ///
  /// In zh, this message translates to:
  /// **'备份 zip'**
  String get platformTallyHint;

  /// No description provided for @platformGenericCsv.
  ///
  /// In zh, this message translates to:
  /// **'其他 CSV'**
  String get platformGenericCsv;

  /// No description provided for @platformGenericCsvHint.
  ///
  /// In zh, this message translates to:
  /// **'钱迹 / 随手记 / 模板'**
  String get platformGenericCsvHint;

  /// No description provided for @billImportGuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'如何导出{source}账单'**
  String billImportGuideTitle(String source);

  /// No description provided for @alipayImportGuide.
  ///
  /// In zh, this message translates to:
  /// **'支付宝 App →「我的」→「账单」→ 右上角「…」→「开具交易流水证明」→「用于个人对账」→ 选择时间范围，通过邮箱收到 CSV 文件，下载到手机后在此选择。\n\n还款、理财、转账等「不计收支」记录会自动跳过，避免重复记账。菜单以实际 App 版本为准。'**
  String get alipayImportGuide;

  /// No description provided for @wechatImportGuide.
  ///
  /// In zh, this message translates to:
  /// **'微信 →「我」→「服务」→「钱包」→「账单」→ 右上「常见问题」→「下载账单」→「用于个人对账」→ 选择时间范围，通过邮箱收到 xlsx 文件，下载到手机后在此选择。\n\n提现、理财、还款等「中性交易」会自动跳过。菜单以实际 App 版本为准。'**
  String get wechatImportGuide;

  /// No description provided for @mintImportGuide.
  ///
  /// In zh, this message translates to:
  /// **'薄荷记账 App →「我的」→ 账本/数据设置 → 导出账单（CSV），保存到本机后在此选择。菜单以实际 App 版本为准。'**
  String get mintImportGuide;

  /// No description provided for @yimuBillImportGuide.
  ///
  /// In zh, this message translates to:
  /// **'一木记账 App →「我的」→「导入/导出」→「数据导出」→「账单导出」，选择 Excel（.xls）保存到本机后在此选择。\n\n只导入收支账单，分类按二级分类。转账请用另一个入口「一木记账 · 转账还款」。菜单以实际 App 版本为准。'**
  String get yimuBillImportGuide;

  /// No description provided for @yimuTransferImportGuide.
  ///
  /// In zh, this message translates to:
  /// **'一木记账 App →「我的」→「导入/导出」→「数据导出」→「转账还款导出」，选择 Excel（.xls）保存到本机后在此选择。\n\n导入转账记录，保留转出/转入账户与手续费。收支账单请用另一个入口「一木记账 · 账单」。菜单以实际 App 版本为准。'**
  String get yimuTransferImportGuide;

  /// No description provided for @tallyImportGuide.
  ///
  /// In zh, this message translates to:
  /// **'Tally 记账 App →「设置」→ 数据备份与恢复 →「导出备份」，得到 Tally 开头的 .zip 文件，保存到本机后在此选择。\n\n请选「备份 zip」而非 CSV「账单」导出：备份保留精确到秒的交易时间，收入/支出/转账、一级/二级分类、账户与备注都会一并导入（分类按二级分类）。菜单以实际 App 版本为准。'**
  String get tallyImportGuide;

  /// No description provided for @genericCsvImportGuide.
  ///
  /// In zh, this message translates to:
  /// **'支持钱迹、随手记等导出的 CSV，或本页「下载 CSV 模板」填好后导入。文件需含 日期、类型、金额、账户 列。'**
  String get genericCsvImportGuide;

  /// No description provided for @billImportCommonNote.
  ///
  /// In zh, this message translates to:
  /// **'交易会追加到当前账本，匹配不到的账户与分类按名称自动新建，不会删除现有数据。'**
  String get billImportCommonNote;

  /// No description provided for @backupToLocalDir.
  ///
  /// In zh, this message translates to:
  /// **'备份到本地目录'**
  String get backupToLocalDir;

  /// No description provided for @backupDirLabel.
  ///
  /// In zh, this message translates to:
  /// **'备份目录'**
  String get backupDirLabel;

  /// No description provided for @notChosen.
  ///
  /// In zh, this message translates to:
  /// **'未选择'**
  String get notChosen;

  /// No description provided for @backupNow.
  ///
  /// In zh, this message translates to:
  /// **'立即备份'**
  String get backupNow;

  /// No description provided for @clearBackupDir.
  ///
  /// In zh, this message translates to:
  /// **'清除备份目录'**
  String get clearBackupDir;

  /// No description provided for @stopLocalBackup.
  ///
  /// In zh, this message translates to:
  /// **'停止本地备份'**
  String get stopLocalBackup;

  /// No description provided for @autoBackup.
  ///
  /// In zh, this message translates to:
  /// **'自动备份'**
  String get autoBackup;

  /// No description provided for @backupFrequencyLabel.
  ///
  /// In zh, this message translates to:
  /// **'备份频率'**
  String get backupFrequencyLabel;

  /// No description provided for @backupIntervalLabel.
  ///
  /// In zh, this message translates to:
  /// **'备份间隔'**
  String get backupIntervalLabel;

  /// No description provided for @everyNHoursLabel.
  ///
  /// In zh, this message translates to:
  /// **'每 {n} 小时'**
  String everyNHoursLabel(int n);

  /// No description provided for @retentionLabel.
  ///
  /// In zh, this message translates to:
  /// **'保留份数'**
  String get retentionLabel;

  /// No description provided for @latestNCopies.
  ///
  /// In zh, this message translates to:
  /// **'最近 {n} 份'**
  String latestNCopies(int n);

  /// No description provided for @backupEncryption.
  ///
  /// In zh, this message translates to:
  /// **'备份加密'**
  String get backupEncryption;

  /// No description provided for @encryptionKey.
  ///
  /// In zh, this message translates to:
  /// **'加密密钥'**
  String get encryptionKey;

  /// No description provided for @clearEncryptionKey.
  ///
  /// In zh, this message translates to:
  /// **'清除加密密钥'**
  String get clearEncryptionKey;

  /// No description provided for @noEncryptHint.
  ///
  /// In zh, this message translates to:
  /// **'后续备份不加密'**
  String get noEncryptHint;

  /// No description provided for @webdavSection.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 云备份'**
  String get webdavSection;

  /// No description provided for @webdavServer.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 服务器'**
  String get webdavServer;

  /// No description provided for @configuredLabel.
  ///
  /// In zh, this message translates to:
  /// **'已配置'**
  String get configuredLabel;

  /// No description provided for @notConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get notConfigured;

  /// No description provided for @uploadToWebdav.
  ///
  /// In zh, this message translates to:
  /// **'上传到 WebDAV'**
  String get uploadToWebdav;

  /// No description provided for @uploadNow.
  ///
  /// In zh, this message translates to:
  /// **'立即上传'**
  String get uploadNow;

  /// No description provided for @restoreFromWebdav.
  ///
  /// In zh, this message translates to:
  /// **'从 WebDAV 恢复'**
  String get restoreFromWebdav;

  /// No description provided for @chooseBackup.
  ///
  /// In zh, this message translates to:
  /// **'选择备份'**
  String get chooseBackup;

  /// No description provided for @autoUploadWebdav.
  ///
  /// In zh, this message translates to:
  /// **'自动上传到 WebDAV'**
  String get autoUploadWebdav;

  /// No description provided for @clearWebdav.
  ///
  /// In zh, this message translates to:
  /// **'清除 WebDAV 配置'**
  String get clearWebdav;

  /// No description provided for @disconnectLabel.
  ///
  /// In zh, this message translates to:
  /// **'断开连接'**
  String get disconnectLabel;

  /// No description provided for @resetData.
  ///
  /// In zh, this message translates to:
  /// **'初始化数据'**
  String get resetData;

  /// No description provided for @deleteAllLocal.
  ///
  /// In zh, this message translates to:
  /// **'删除所有本地数据'**
  String get deleteAllLocal;

  /// No description provided for @neverBackedUp.
  ///
  /// In zh, this message translates to:
  /// **'尚未备份'**
  String get neverBackedUp;

  /// No description provided for @lastBackupAt.
  ///
  /// In zh, this message translates to:
  /// **'上次 {time}'**
  String lastBackupAt(String time);

  /// No description provided for @chosenBackupDir.
  ///
  /// In zh, this message translates to:
  /// **'已选择备份目录：{label}'**
  String chosenBackupDir(String label);

  /// No description provided for @backedUpFile.
  ///
  /// In zh, this message translates to:
  /// **'已备份：{name}'**
  String backedUpFile(String name);

  /// No description provided for @backupFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'备份操作失败，请稍后再试'**
  String get backupFailedRetry;

  /// No description provided for @backupVerifyFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份写入后校验未通过（文件可能已损坏），请重试或更换备份目录'**
  String get backupVerifyFailed;

  /// No description provided for @pickBackupFrequency.
  ///
  /// In zh, this message translates to:
  /// **'选择自动备份频率'**
  String get pickBackupFrequency;

  /// No description provided for @backupIntervalTitle.
  ///
  /// In zh, this message translates to:
  /// **'每隔多久备份一次'**
  String get backupIntervalTitle;

  /// No description provided for @retentionTitle.
  ///
  /// In zh, this message translates to:
  /// **'保留最近几份备份'**
  String get retentionTitle;

  /// No description provided for @encryptedSuffix.
  ///
  /// In zh, this message translates to:
  /// **'（已加密）'**
  String get encryptedSuffix;

  /// No description provided for @exportedTo.
  ///
  /// In zh, this message translates to:
  /// **'已导出本地数据备份{hint}，位置：下载目录'**
  String exportedTo(String hint);

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败，请稍后再试'**
  String get exportFailed;

  /// No description provided for @enterBackupKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入备份密钥'**
  String get enterBackupKeyTitle;

  /// No description provided for @enterBackupKeyMessage.
  ///
  /// In zh, this message translates to:
  /// **'该备份已加密，请输入导出时设置的密钥。'**
  String get enterBackupKeyMessage;

  /// No description provided for @backupKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'备份密钥'**
  String get backupKeyLabel;

  /// No description provided for @changeKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改加密密钥'**
  String get changeKeyTitle;

  /// No description provided for @setKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置加密密钥'**
  String get setKeyTitle;

  /// No description provided for @setKeyMessage.
  ///
  /// In zh, this message translates to:
  /// **'设置后，导出与备份文件会用该密钥加密；导入时需要输入相同密钥。密钥仅存于本机，忘记只能清除后重设。'**
  String get setKeyMessage;

  /// No description provided for @keyMinLabel.
  ///
  /// In zh, this message translates to:
  /// **'密钥（至少 4 位）'**
  String get keyMinLabel;

  /// No description provided for @keyRepeatLabel.
  ///
  /// In zh, this message translates to:
  /// **'再次输入密钥'**
  String get keyRepeatLabel;

  /// No description provided for @keyTooShort.
  ///
  /// In zh, this message translates to:
  /// **'密钥至少 4 位'**
  String get keyTooShort;

  /// No description provided for @keyMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入不一致'**
  String get keyMismatch;

  /// No description provided for @keySet.
  ///
  /// In zh, this message translates to:
  /// **'已设置备份加密密钥'**
  String get keySet;

  /// No description provided for @clearKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除加密密钥？'**
  String get clearKeyTitle;

  /// No description provided for @clearKeyMessage.
  ///
  /// In zh, this message translates to:
  /// **'清除后新的导出与备份将不再加密。已经用旧密钥加密的备份文件，导入时仍需输入当时的密钥。'**
  String get clearKeyMessage;

  /// No description provided for @clearLabel.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clearLabel;

  /// No description provided for @webdavUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'服务器目录地址'**
  String get webdavUrlLabel;

  /// No description provided for @webdavUserLabel.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get webdavUserLabel;

  /// No description provided for @webdavPassLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get webdavPassLabel;

  /// No description provided for @testingConnection.
  ///
  /// In zh, this message translates to:
  /// **'正在测试连接...'**
  String get testingConnection;

  /// No description provided for @connectionOk.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get connectionOk;

  /// No description provided for @connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{error}'**
  String connectionFailed(String error);

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @fillServerUrl.
  ///
  /// In zh, this message translates to:
  /// **'请填写服务器地址'**
  String get fillServerUrl;

  /// No description provided for @webdavSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存 WebDAV 配置'**
  String get webdavSaved;

  /// No description provided for @fabActionTitle.
  ///
  /// In zh, this message translates to:
  /// **'记一笔按钮'**
  String get fabActionTitle;

  /// No description provided for @fabActionPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'记一笔按钮行为'**
  String get fabActionPickerTitle;

  /// No description provided for @fabModeManual.
  ///
  /// In zh, this message translates to:
  /// **'手动记账'**
  String get fabModeManual;

  /// No description provided for @fabModeAi.
  ///
  /// In zh, this message translates to:
  /// **'AI 记账'**
  String get fabModeAi;

  /// No description provided for @fabModeManualTapAiLongPress.
  ///
  /// In zh, this message translates to:
  /// **'点击手动 · 长按 AI'**
  String get fabModeManualTapAiLongPress;

  /// No description provided for @defaultAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'默认账户'**
  String get defaultAccountTitle;

  /// No description provided for @defaultAccountPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'默认付款账户'**
  String get defaultAccountPickerTitle;

  /// No description provided for @defaultAccountNone.
  ///
  /// In zh, this message translates to:
  /// **'无默认账户'**
  String get defaultAccountNone;

  /// No description provided for @defaultAccountNoneHint.
  ///
  /// In zh, this message translates to:
  /// **'记账时不预选账户'**
  String get defaultAccountNoneHint;

  /// No description provided for @setAsDefaultAccount.
  ///
  /// In zh, this message translates to:
  /// **'设为默认账户'**
  String get setAsDefaultAccount;

  /// No description provided for @setAsDefaultAccountHint.
  ///
  /// In zh, this message translates to:
  /// **'记账时默认用此账户付款'**
  String get setAsDefaultAccountHint;

  /// No description provided for @calcIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'算式不完整'**
  String get calcIncomplete;

  /// No description provided for @numberPadMax.
  ///
  /// In zh, this message translates to:
  /// **'最多 {amount}'**
  String numberPadMax(String amount);

  /// No description provided for @aiSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 记账设置'**
  String get aiSettingsTitle;

  /// No description provided for @aiConfigured.
  ///
  /// In zh, this message translates to:
  /// **'已配置'**
  String get aiConfigured;

  /// No description provided for @aiNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get aiNotConfigured;

  /// No description provided for @aiChatTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 助手'**
  String get aiChatTitle;

  /// No description provided for @aiChatClearHistory.
  ///
  /// In zh, this message translates to:
  /// **'清空聊天记录'**
  String get aiChatClearHistory;

  /// No description provided for @aiChatClearMessage.
  ///
  /// In zh, this message translates to:
  /// **'将删除当前所有对话，无法恢复。'**
  String get aiChatClearMessage;

  /// No description provided for @aiChatClearConfirm.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get aiChatClearConfirm;

  /// No description provided for @aiChatThinking.
  ///
  /// In zh, this message translates to:
  /// **'思考中…'**
  String get aiChatThinking;

  /// No description provided for @aiChatQuerying.
  ///
  /// In zh, this message translates to:
  /// **'正在查询…'**
  String get aiChatQuerying;

  /// No description provided for @aiChatUnconfiguredHint.
  ///
  /// In zh, this message translates to:
  /// **'先配置 AI，才能开始对话查询账目'**
  String get aiChatUnconfiguredHint;

  /// No description provided for @aiChatGoConfigure.
  ///
  /// In zh, this message translates to:
  /// **'去配置 AI'**
  String get aiChatGoConfigure;

  /// No description provided for @aiChatEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'问问 AI 你的账目'**
  String get aiChatEmptyTitle;

  /// No description provided for @aiChatInputHint.
  ///
  /// In zh, this message translates to:
  /// **'问问你的账目…'**
  String get aiChatInputHint;

  /// No description provided for @aiChatHintTopCategory.
  ///
  /// In zh, this message translates to:
  /// **'这个月花最多的是哪些分类？'**
  String get aiChatHintTopCategory;

  /// No description provided for @aiChatHintLargeExpense.
  ///
  /// In zh, this message translates to:
  /// **'最近三个月有哪些大额支出？'**
  String get aiChatHintLargeExpense;

  /// No description provided for @aiChatHintMonthSummary.
  ///
  /// In zh, this message translates to:
  /// **'本月收支情况怎么样？'**
  String get aiChatHintMonthSummary;

  /// No description provided for @aiChatNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get aiChatNoData;

  /// No description provided for @aiChatNoMatchingTx.
  ///
  /// In zh, this message translates to:
  /// **'无匹配交易'**
  String get aiChatNoMatchingTx;

  /// No description provided for @aiClearConfig.
  ///
  /// In zh, this message translates to:
  /// **'清空配置'**
  String get aiClearConfig;

  /// No description provided for @aiClearConfigMessage.
  ///
  /// In zh, this message translates to:
  /// **'将清空请求地址、API Key 与模型。清空后需重新填写才能使用 AI 功能。'**
  String get aiClearConfigMessage;

  /// No description provided for @aiConfigCleared.
  ///
  /// In zh, this message translates to:
  /// **'配置已清空'**
  String get aiConfigCleared;

  /// No description provided for @aiSettingsIntro.
  ///
  /// In zh, this message translates to:
  /// **'填写任意 OpenAI 兼容服务的请求地址、API Key 与模型。你的输入只会发送到这里配置的服务，配置只存本机、不进备份。'**
  String get aiSettingsIntro;

  /// No description provided for @aiBaseUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'请求地址（Base URL）'**
  String get aiBaseUrlLabel;

  /// No description provided for @aiBaseUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'如 https://api.openai.com/v1'**
  String get aiBaseUrlHint;

  /// No description provided for @aiApiKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get aiApiKeyLabel;

  /// No description provided for @aiModelLabel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get aiModelLabel;

  /// No description provided for @aiModelHint.
  ///
  /// In zh, this message translates to:
  /// **'如 gpt-4o-mini'**
  String get aiModelHint;

  /// No description provided for @aiFillAllFields.
  ///
  /// In zh, this message translates to:
  /// **'请填写请求地址、API Key 与模型'**
  String get aiFillAllFields;

  /// No description provided for @aiSettingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'保存成功'**
  String get aiSettingsSaved;

  /// No description provided for @aiPrivacyNotice.
  ///
  /// In zh, this message translates to:
  /// **'AI 记账会把你输入的文字发送到你配置的第三方服务进行解析，请勿输入敏感信息。'**
  String get aiPrivacyNotice;

  /// No description provided for @aiEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 记账'**
  String get aiEntryTitle;

  /// No description provided for @aiEntryInputHint.
  ///
  /// In zh, this message translates to:
  /// **'用一句话描述，例如「昨天打车 32」'**
  String get aiEntryInputHint;

  /// No description provided for @aiEntryParse.
  ///
  /// In zh, this message translates to:
  /// **'解析'**
  String get aiEntryParse;

  /// No description provided for @aiEntryParsing.
  ///
  /// In zh, this message translates to:
  /// **'正在解析…'**
  String get aiEntryParsing;

  /// No description provided for @aiEntryEmptyInput.
  ///
  /// In zh, this message translates to:
  /// **'请先输入一句话'**
  String get aiEntryEmptyInput;

  /// No description provided for @aiEntryNotConfiguredTitle.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置 AI'**
  String get aiEntryNotConfiguredTitle;

  /// No description provided for @aiEntryNotConfiguredBody.
  ///
  /// In zh, this message translates to:
  /// **'请先在「我的 → AI 记账设置」中填写请求地址、API Key 与模型。'**
  String get aiEntryNotConfiguredBody;

  /// No description provided for @aiEntryGoToSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get aiEntryGoToSettings;

  /// No description provided for @aiEntryReviewHint.
  ///
  /// In zh, this message translates to:
  /// **'已由 AI 解析为草稿，确认或修改后保存'**
  String get aiEntryReviewHint;

  /// No description provided for @aiEntryNoResult.
  ///
  /// In zh, this message translates to:
  /// **'AI 未返回可识别的结果，请换种说法再试'**
  String get aiEntryNoResult;

  /// No description provided for @aiEntryNoAmount.
  ///
  /// In zh, this message translates to:
  /// **'未能识别金额，请在描述中说明金额，例如「打车 32」'**
  String get aiEntryNoAmount;

  /// No description provided for @aiWarningCategoryUnmatched.
  ///
  /// In zh, this message translates to:
  /// **'分类未匹配，已用默认分类，请确认'**
  String get aiWarningCategoryUnmatched;

  /// No description provided for @aiWarningAccountUnmatched.
  ///
  /// In zh, this message translates to:
  /// **'账户未匹配，已置为无账户，请确认'**
  String get aiWarningAccountUnmatched;

  /// No description provided for @screenshotEntryButton.
  ///
  /// In zh, this message translates to:
  /// **'截图识账'**
  String get screenshotEntryButton;

  /// No description provided for @screenshotEntryUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持图片文字识别'**
  String get screenshotEntryUnsupported;

  /// No description provided for @screenshotEntryNoText.
  ///
  /// In zh, this message translates to:
  /// **'没有从图片里识别到文字，请换一张更清晰的截图'**
  String get screenshotEntryNoText;

  /// No description provided for @captureEntryRecognizing.
  ///
  /// In zh, this message translates to:
  /// **'正在识别账单内容…'**
  String get captureEntryRecognizing;

  /// No description provided for @captureEntryNoTransaction.
  ///
  /// In zh, this message translates to:
  /// **'没有识别到交易，请确认内容是账单截图或账单文本'**
  String get captureEntryNoTransaction;

  /// No description provided for @captureEntryFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'识别失败'**
  String get captureEntryFailedTitle;

  /// No description provided for @captureEntryPrivacyNotice.
  ///
  /// In zh, this message translates to:
  /// **'识别在本机完成，图片不会上传；识别出的文字会发送到你配置的 AI 服务解析。'**
  String get captureEntryPrivacyNotice;

  /// No description provided for @uploadingWebdav.
  ///
  /// In zh, this message translates to:
  /// **'正在上传到 WebDAV...'**
  String get uploadingWebdav;

  /// No description provided for @uploadedFile.
  ///
  /// In zh, this message translates to:
  /// **'已上传：{name}'**
  String uploadedFile(String name);

  /// No description provided for @uploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'上传失败：{error}'**
  String uploadFailed(String error);

  /// No description provided for @readFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取失败：{error}'**
  String readFailed(String error);

  /// No description provided for @noWebdavBackups.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 上没有找到备份文件'**
  String get noWebdavBackups;

  /// No description provided for @chooseRestoreBackup.
  ///
  /// In zh, this message translates to:
  /// **'选择要恢复的备份'**
  String get chooseRestoreBackup;

  /// No description provided for @restoreFromThisTitle.
  ///
  /// In zh, this message translates to:
  /// **'从此备份恢复？'**
  String get restoreFromThisTitle;

  /// No description provided for @restoreFromThisMessage.
  ///
  /// In zh, this message translates to:
  /// **'将用「{name}」替换当前本地数据，建议先备份当前数据。'**
  String restoreFromThisMessage(String name);

  /// No description provided for @restoreLabel.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restoreLabel;

  /// No description provided for @restoredFromWebdav.
  ///
  /// In zh, this message translates to:
  /// **'已从 WebDAV 恢复数据'**
  String get restoredFromWebdav;

  /// No description provided for @restoreFailedFormat.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败：备份文件格式不正确'**
  String get restoreFailedFormat;

  /// No description provided for @restoreFailedError.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败：{error}'**
  String restoreFailedError(String error);

  /// No description provided for @clearWebdavTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除 WebDAV 配置？'**
  String get clearWebdavTitle;

  /// No description provided for @clearWebdavMessage.
  ///
  /// In zh, this message translates to:
  /// **'清除后将停止自动上传，服务器上已有的备份文件不会被删除。'**
  String get clearWebdavMessage;

  /// No description provided for @csvTemplateSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存 CSV 模板，位置：下载目录'**
  String get csvTemplateSaved;

  /// No description provided for @csvTemplateSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存模板失败，请稍后再试'**
  String get csvTemplateSaveFailed;

  /// No description provided for @chooseFile.
  ///
  /// In zh, this message translates to:
  /// **'选择文件'**
  String get chooseFile;

  /// No description provided for @importedEntries.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 笔交易'**
  String importedEntries(int count);

  /// No description provided for @skippedRows.
  ///
  /// In zh, this message translates to:
  /// **'，{count} 行跳过'**
  String skippedRows(int count);

  /// No description provided for @importFailedWithMessage.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{message}'**
  String importFailedWithMessage(String message);

  /// No description provided for @importFailedCheckFile.
  ///
  /// In zh, this message translates to:
  /// **'导入失败，请检查文件后重试'**
  String get importFailedCheckFile;

  /// No description provided for @lineError.
  ///
  /// In zh, this message translates to:
  /// **'第 {line} 行：{message}'**
  String lineError(int line, String message);

  /// No description provided for @moreLines.
  ///
  /// In zh, this message translates to:
  /// **'\n… 其余 {count} 行'**
  String moreLines(int count);

  /// No description provided for @importDoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入完成（成功 {count} 笔）'**
  String importDoneTitle(int count);

  /// No description provided for @allImported.
  ///
  /// In zh, this message translates to:
  /// **'全部导入成功。'**
  String get allImported;

  /// No description provided for @skippedFollowing.
  ///
  /// In zh, this message translates to:
  /// **'以下行被跳过：\n{lines}'**
  String skippedFollowing(String lines);

  /// No description provided for @gotIt.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get gotIt;

  /// No description provided for @importPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入预览'**
  String get importPreviewTitle;

  /// No description provided for @importPreviewHint.
  ///
  /// In zh, this message translates to:
  /// **'点按可排除 / 恢复某笔，长按可编辑'**
  String get importPreviewHint;

  /// No description provided for @importPreviewSelectedOf.
  ///
  /// In zh, this message translates to:
  /// **'将导入 {selected} / {total} 笔'**
  String importPreviewSelectedOf(int selected, int total);

  /// No description provided for @importPreviewNewAccounts.
  ///
  /// In zh, this message translates to:
  /// **'新建账户 {count}'**
  String importPreviewNewAccounts(int count);

  /// No description provided for @importPreviewNewCategories.
  ///
  /// In zh, this message translates to:
  /// **'新建分类 {count}'**
  String importPreviewNewCategories(int count);

  /// No description provided for @importPreviewSkipped.
  ///
  /// In zh, this message translates to:
  /// **'{count} 行无法解析'**
  String importPreviewSkipped(int count);

  /// No description provided for @importPreviewSkippedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已跳过的行'**
  String get importPreviewSkippedTitle;

  /// No description provided for @importPreviewSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get importPreviewSelectAll;

  /// No description provided for @importPreviewDeselectAll.
  ///
  /// In zh, this message translates to:
  /// **'全不选'**
  String get importPreviewDeselectAll;

  /// No description provided for @importPreviewConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认导入（{count}）'**
  String importPreviewConfirm(int count);

  /// No description provided for @importPreviewConfirmAccountsOnly.
  ///
  /// In zh, this message translates to:
  /// **'确认导入（{count} 个账户）'**
  String importPreviewConfirmAccountsOnly(int count);

  /// No description provided for @importPreviewNothingToImport.
  ///
  /// In zh, this message translates to:
  /// **'没有可导入的数据'**
  String get importPreviewNothingToImport;

  /// No description provided for @importedAccounts.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 个账户'**
  String importedAccounts(int count);

  /// No description provided for @importAccountMapping.
  ///
  /// In zh, this message translates to:
  /// **'导入账户'**
  String get importAccountMapping;

  /// No description provided for @importCategoryMapping.
  ///
  /// In zh, this message translates to:
  /// **'导入分类'**
  String get importCategoryMapping;

  /// No description provided for @mappingSummary.
  ///
  /// In zh, this message translates to:
  /// **'新建 {newCount} · 映射 {mappedCount}'**
  String mappingSummary(int newCount, int mappedCount);

  /// No description provided for @mappingRowNew.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get mappingRowNew;

  /// No description provided for @mappingRowRenamed.
  ///
  /// In zh, this message translates to:
  /// **'新建 · 改名为「{name}」'**
  String mappingRowRenamed(String name);

  /// No description provided for @mappingRowMapped.
  ///
  /// In zh, this message translates to:
  /// **'映射到「{name}」'**
  String mappingRowMapped(String name);

  /// No description provided for @mappingAccountSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'账户「{name}」'**
  String mappingAccountSheetTitle(String name);

  /// No description provided for @mappingCategorySheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'分类「{name}」'**
  String mappingCategorySheetTitle(String name);

  /// No description provided for @mappingKeepNewAccount.
  ///
  /// In zh, this message translates to:
  /// **'新建此账户'**
  String get mappingKeepNewAccount;

  /// No description provided for @mappingKeepNewCategory.
  ///
  /// In zh, this message translates to:
  /// **'新建此分类'**
  String get mappingKeepNewCategory;

  /// No description provided for @mappingMapToExistingAccount.
  ///
  /// In zh, this message translates to:
  /// **'映射到现有账户'**
  String get mappingMapToExistingAccount;

  /// No description provided for @mappingMapToExistingCategory.
  ///
  /// In zh, this message translates to:
  /// **'映射到现有分类'**
  String get mappingMapToExistingCategory;

  /// No description provided for @mappingRenameAccount.
  ///
  /// In zh, this message translates to:
  /// **'重命名新账户'**
  String get mappingRenameAccount;

  /// No description provided for @mappingRenameCategory.
  ///
  /// In zh, this message translates to:
  /// **'重命名新分类'**
  String get mappingRenameCategory;

  /// No description provided for @mappingRenameTooltip.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get mappingRenameTooltip;

  /// No description provided for @mappingNewNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'新名称'**
  String get mappingNewNameLabel;

  /// No description provided for @importLocalTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入本地备份？'**
  String get importLocalTitle;

  /// No description provided for @importLocalMessage.
  ///
  /// In zh, this message translates to:
  /// **'导入会替换当前本地交易、账户、账本、预算、个人信息和设置。建议先导出当前数据。'**
  String get importLocalMessage;

  /// No description provided for @importedLocal.
  ///
  /// In zh, this message translates to:
  /// **'已导入本地数据'**
  String get importedLocal;

  /// No description provided for @importFailedFormat.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：备份文件格式不正确'**
  String get importFailedFormat;

  /// No description provided for @resetAllTitle.
  ///
  /// In zh, this message translates to:
  /// **'初始化所有数据？'**
  String get resetAllTitle;

  /// No description provided for @resetAllMessage.
  ///
  /// In zh, this message translates to:
  /// **'这会删除本地交易、账户、账本、预算、个人信息和主题偏好，操作无法恢复。'**
  String get resetAllMessage;

  /// No description provided for @continueLabel.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get continueLabel;

  /// No description provided for @resetConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'再次确认初始化'**
  String get resetConfirmTitle;

  /// No description provided for @resetConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确认后会立即清空所有本地数据，并恢复默认状态。此操作不能撤销。'**
  String get resetConfirmMessage;

  /// No description provided for @resetConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'确认初始化'**
  String get resetConfirmAction;

  /// No description provided for @currentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get currentVersion;

  /// No description provided for @latestVersion.
  ///
  /// In zh, this message translates to:
  /// **'最新版本'**
  String get latestVersion;

  /// No description provided for @checkingLabel.
  ///
  /// In zh, this message translates to:
  /// **'检查中...'**
  String get checkingLabel;

  /// No description provided for @queryingGithub.
  ///
  /// In zh, this message translates to:
  /// **'正在查询 GitHub Release...'**
  String get queryingGithub;

  /// No description provided for @updateCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败，请稍后再试。'**
  String get updateCheckFailed;

  /// No description provided for @downloadingPercent.
  ///
  /// In zh, this message translates to:
  /// **'下载中 {percent}%'**
  String downloadingPercent(int percent);

  /// No description provided for @downloadingLabel.
  ///
  /// In zh, this message translates to:
  /// **'正在下载...'**
  String get downloadingLabel;

  /// No description provided for @closeLabel.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get closeLabel;

  /// No description provided for @retryLabel.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retryLabel;

  /// No description provided for @downloadingShort.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloadingShort;

  /// No description provided for @downloadNewVersion.
  ///
  /// In zh, this message translates to:
  /// **'下载新版本'**
  String get downloadNewVersion;

  /// No description provided for @includePrereleaseLabel.
  ///
  /// In zh, this message translates to:
  /// **'包含预发布版本（Beta）'**
  String get includePrereleaseLabel;

  /// No description provided for @prereleaseNoticeInline.
  ///
  /// In zh, this message translates to:
  /// **'这是预发布（测试）版本，可能存在不稳定或缺陷。'**
  String get prereleaseNoticeInline;

  /// No description provided for @prereleaseWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载预发布版本？'**
  String get prereleaseWarningTitle;

  /// No description provided for @prereleaseWarningMessage.
  ///
  /// In zh, this message translates to:
  /// **'预发布版本可能存在不稳定、功能缺陷或数据异常等问题，建议仅在了解风险时使用。确定继续下载并安装吗？'**
  String get prereleaseWarningMessage;

  /// No description provided for @prereleaseDownloadAnyway.
  ///
  /// In zh, this message translates to:
  /// **'仍要下载'**
  String get prereleaseDownloadAnyway;

  /// No description provided for @backupFreqManual.
  ///
  /// In zh, this message translates to:
  /// **'仅手动'**
  String get backupFreqManual;

  /// No description provided for @backupFreqOnOpen.
  ///
  /// In zh, this message translates to:
  /// **'每次打开应用'**
  String get backupFreqOnOpen;

  /// No description provided for @backupFreqOnEntry.
  ///
  /// In zh, this message translates to:
  /// **'每次记账后'**
  String get backupFreqOnEntry;

  /// No description provided for @backupFreqEveryN.
  ///
  /// In zh, this message translates to:
  /// **'每隔一段时间'**
  String get backupFreqEveryN;

  /// No description provided for @patternTooShort.
  ///
  /// In zh, this message translates to:
  /// **'至少连接 {count} 个点'**
  String patternTooShort(int count);

  /// No description provided for @bioUnlockReason.
  ///
  /// In zh, this message translates to:
  /// **'验证生物识别以解锁 Veri Fin'**
  String get bioUnlockReason;

  /// No description provided for @verifyFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'验证失败，请重试'**
  String get verifyFailedRetry;

  /// No description provided for @enterPassword.
  ///
  /// In zh, this message translates to:
  /// **'输入密码'**
  String get enterPassword;

  /// No description provided for @drawPatternUnlock.
  ///
  /// In zh, this message translates to:
  /// **'请绘制图案解锁'**
  String get drawPatternUnlock;

  /// No description provided for @enterPinUnlock.
  ///
  /// In zh, this message translates to:
  /// **'请输入 6 位数字密码解锁'**
  String get enterPinUnlock;

  /// No description provided for @bioUnlock.
  ///
  /// In zh, this message translates to:
  /// **'生物解锁'**
  String get bioUnlock;

  /// No description provided for @patternMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次图案不一致，请重新绘制'**
  String get patternMismatch;

  /// No description provided for @pinMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入不一致，请重新设置'**
  String get pinMismatch;

  /// No description provided for @drawAgainConfirm.
  ///
  /// In zh, this message translates to:
  /// **'再次绘制以确认'**
  String get drawAgainConfirm;

  /// No description provided for @drawPatternHint.
  ///
  /// In zh, this message translates to:
  /// **'绘制解锁图案（至少 4 个点）'**
  String get drawPatternHint;

  /// No description provided for @enterAgainConfirm.
  ///
  /// In zh, this message translates to:
  /// **'再次输入以确认'**
  String get enterAgainConfirm;

  /// No description provided for @setPinHint.
  ///
  /// In zh, this message translates to:
  /// **'设置 6 位数字密码'**
  String get setPinHint;

  /// No description provided for @setPatternTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置图案'**
  String get setPatternTitle;

  /// No description provided for @setPinTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置密码'**
  String get setPinTitle;

  /// No description provided for @verifyPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'验证密码'**
  String get verifyPasswordTitle;

  /// No description provided for @drawCurrentPattern.
  ///
  /// In zh, this message translates to:
  /// **'请绘制当前解锁图案'**
  String get drawCurrentPattern;

  /// No description provided for @enterCurrentPin.
  ///
  /// In zh, this message translates to:
  /// **'请输入当前 6 位数字密码'**
  String get enterCurrentPin;

  /// No description provided for @appLockSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'启动和回到前台时校验'**
  String get appLockSubtitle;

  /// No description provided for @lockMethodAndPassword.
  ///
  /// In zh, this message translates to:
  /// **'锁定方式与密码'**
  String get lockMethodAndPassword;

  /// No description provided for @appLockHelp.
  ///
  /// In zh, this message translates to:
  /// **'支持 6 位数字密码或 3×3 图案。密钥仅以加盐哈希保存在本机，不会上传，也无法找回；忘记时可在设置页初始化数据后重新设置。生物解锁调用系统生物识别（指纹 / 人脸，以设备支持为准），本应用不保存任何生物特征数据；系统生物信息变化后需重新验证。'**
  String get appLockHelp;

  /// No description provided for @bioEnableReason.
  ///
  /// In zh, this message translates to:
  /// **'验证生物识别以开启生物解锁'**
  String get bioEnableReason;

  /// No description provided for @bioNotPassed.
  ///
  /// In zh, this message translates to:
  /// **'生物识别未通过，未开启'**
  String get bioNotPassed;

  /// No description provided for @closeAppLockTitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭应用锁'**
  String get closeAppLockTitle;

  /// No description provided for @changeAppLockTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改应用锁'**
  String get changeAppLockTitle;

  /// No description provided for @appLockUpdated.
  ///
  /// In zh, this message translates to:
  /// **'应用锁已更新'**
  String get appLockUpdated;

  /// No description provided for @pinSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'6 位数字'**
  String get pinSubtitle;

  /// No description provided for @patternSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'3×3 连线图案'**
  String get patternSubtitle;

  /// No description provided for @lockKindPin.
  ///
  /// In zh, this message translates to:
  /// **'数字密码'**
  String get lockKindPin;

  /// No description provided for @lockKindPattern.
  ///
  /// In zh, this message translates to:
  /// **'图案密码'**
  String get lockKindPattern;

  /// No description provided for @bioSignInTitle.
  ///
  /// In zh, this message translates to:
  /// **'生物解锁'**
  String get bioSignInTitle;

  /// No description provided for @bioHint.
  ///
  /// In zh, this message translates to:
  /// **'验证身份'**
  String get bioHint;

  /// No description provided for @bioNotRecognized.
  ///
  /// In zh, this message translates to:
  /// **'未能识别，请重试'**
  String get bioNotRecognized;

  /// No description provided for @bioRequiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要生物识别'**
  String get bioRequiredTitle;

  /// No description provided for @bioSuccess.
  ///
  /// In zh, this message translates to:
  /// **'验证成功'**
  String get bioSuccess;

  /// No description provided for @bioSetupDescription.
  ///
  /// In zh, this message translates to:
  /// **'请在系统设置中录入生物识别'**
  String get bioSetupDescription;

  /// No description provided for @bioGoToSettings.
  ///
  /// In zh, this message translates to:
  /// **'前往设置'**
  String get bioGoToSettings;

  /// No description provided for @bioGoToSettingsDesc.
  ///
  /// In zh, this message translates to:
  /// **'尚未录入生物识别，请在系统设置中添加'**
  String get bioGoToSettingsDesc;

  /// No description provided for @widgetTodayExpense.
  ///
  /// In zh, this message translates to:
  /// **'今日支出'**
  String get widgetTodayExpense;

  /// No description provided for @widgetBudgetAvailable.
  ///
  /// In zh, this message translates to:
  /// **'本月可用预算'**
  String get widgetBudgetAvailable;

  /// No description provided for @widgetBudgetOverspent.
  ///
  /// In zh, this message translates to:
  /// **'本月已超支'**
  String get widgetBudgetOverspent;

  /// No description provided for @widgetNetWorth.
  ///
  /// In zh, this message translates to:
  /// **'资产总额'**
  String get widgetNetWorth;

  /// No description provided for @widgetGalleryTitle.
  ///
  /// In zh, this message translates to:
  /// **'桌面小组件'**
  String get widgetGalleryTitle;

  /// No description provided for @widgetGallerySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'把常看的数据放到手机桌面'**
  String get widgetGallerySubtitle;

  /// No description provided for @widgetGalleryShort.
  ///
  /// In zh, this message translates to:
  /// **'预览与添加'**
  String get widgetGalleryShort;

  /// No description provided for @widgetAddToHome.
  ///
  /// In zh, this message translates to:
  /// **'添加到桌面'**
  String get widgetAddToHome;

  /// No description provided for @widgetPinRequested.
  ///
  /// In zh, this message translates to:
  /// **'已发起添加，请在系统弹窗中确认'**
  String get widgetPinRequested;

  /// No description provided for @widgetPinUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前桌面不支持一键添加，请按下方说明手动添加'**
  String get widgetPinUnsupported;

  /// No description provided for @widgetHowToAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'如何手动添加'**
  String get widgetHowToAddTitle;

  /// No description provided for @widgetHowToAddDesc.
  ///
  /// In zh, this message translates to:
  /// **'长按桌面空白处 → 选择「小组件」→ 找到 Veri Fin → 拖动想要的小组件到桌面。'**
  String get widgetHowToAddDesc;

  /// No description provided for @widgetQuickEntryName.
  ///
  /// In zh, this message translates to:
  /// **'今日支出 + 记一笔'**
  String get widgetQuickEntryName;

  /// No description provided for @widgetQuickEntryDesc.
  ///
  /// In zh, this message translates to:
  /// **'查看今日支出，点按快速记一笔'**
  String get widgetQuickEntryDesc;

  /// No description provided for @widgetBudgetName.
  ///
  /// In zh, this message translates to:
  /// **'本月可用预算'**
  String get widgetBudgetName;

  /// No description provided for @widgetBudgetDesc.
  ///
  /// In zh, this message translates to:
  /// **'当前账本本月还能花多少'**
  String get widgetBudgetDesc;

  /// No description provided for @widgetNetWorthName.
  ///
  /// In zh, this message translates to:
  /// **'资产总额'**
  String get widgetNetWorthName;

  /// No description provided for @widgetNetWorthDesc.
  ///
  /// In zh, this message translates to:
  /// **'所有可见账户余额合计'**
  String get widgetNetWorthDesc;

  /// No description provided for @reminderNotifBody.
  ///
  /// In zh, this message translates to:
  /// **'别忘了记录今天的收支～'**
  String get reminderNotifBody;

  /// No description provided for @reminderChannelDesc.
  ///
  /// In zh, this message translates to:
  /// **'每日记账提醒通知'**
  String get reminderChannelDesc;

  /// No description provided for @backupFileTypeLabel.
  ///
  /// In zh, this message translates to:
  /// **'备份文件'**
  String get backupFileTypeLabel;

  /// No description provided for @cropAdjustHint.
  ///
  /// In zh, this message translates to:
  /// **'调整图片位置'**
  String get cropAdjustHint;

  /// No description provided for @cropDone.
  ///
  /// In zh, this message translates to:
  /// **'完成裁剪'**
  String get cropDone;

  /// No description provided for @zoomLabel.
  ///
  /// In zh, this message translates to:
  /// **'缩放'**
  String get zoomLabel;

  /// No description provided for @horizontalLabel.
  ///
  /// In zh, this message translates to:
  /// **'水平'**
  String get horizontalLabel;

  /// No description provided for @verticalLabel.
  ///
  /// In zh, this message translates to:
  /// **'垂直'**
  String get verticalLabel;

  /// No description provided for @resetLabel.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get resetLabel;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试'**
  String get saveFailed;

  /// No description provided for @appLog.
  ///
  /// In zh, this message translates to:
  /// **'软件日志'**
  String get appLog;

  /// No description provided for @appLogSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'记录错误与关键事件，反馈问题时可复制发给开发者'**
  String get appLogSubtitle;

  /// No description provided for @appLogEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志记录'**
  String get appLogEmpty;

  /// No description provided for @appLogCopyAll.
  ///
  /// In zh, this message translates to:
  /// **'复制全部'**
  String get appLogCopyAll;

  /// No description provided for @appLogCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get appLogCopied;

  /// No description provided for @appLogClear.
  ///
  /// In zh, this message translates to:
  /// **'清空日志'**
  String get appLogClear;

  /// No description provided for @appLogClearConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空全部日志吗？'**
  String get appLogClearConfirm;

  /// No description provided for @appLogCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条记录'**
  String appLogCount(int count);

  /// No description provided for @cleartextWarnTitle.
  ///
  /// In zh, this message translates to:
  /// **'明文传输风险'**
  String get cleartextWarnTitle;

  /// No description provided for @cleartextWarnBody.
  ///
  /// In zh, this message translates to:
  /// **'该地址使用未加密的 http，你的密钥/账号密码会以明文发送，可能被同一网络或链路上的第三方窃取。仅在你信任该网络（如本地/自建服务）时继续。'**
  String get cleartextWarnBody;

  /// No description provided for @cleartextWarnContinue.
  ///
  /// In zh, this message translates to:
  /// **'仍要保存'**
  String get cleartextWarnContinue;

  /// No description provided for @reminderPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'通知权限被拒，提醒将不会显示。请在系统设置中允许通知后重试。'**
  String get reminderPermissionDenied;

  /// No description provided for @backingUp.
  ///
  /// In zh, this message translates to:
  /// **'备份中…'**
  String get backingUp;

  /// No description provided for @aiErrNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'AI 未配置：请先填写请求地址、API Key 与模型'**
  String get aiErrNotConfigured;

  /// No description provided for @aiErrNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'当前平台不支持 AI 请求'**
  String get aiErrNotSupported;

  /// No description provided for @aiErrTimeout.
  ///
  /// In zh, this message translates to:
  /// **'请求超时，请检查网络或稍后重试'**
  String get aiErrTimeout;

  /// No description provided for @aiErrNetwork.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到服务器'**
  String get aiErrNetwork;

  /// No description provided for @aiErrTls.
  ///
  /// In zh, this message translates to:
  /// **'TLS 握手失败，请检查请求地址是否为 https'**
  String get aiErrTls;

  /// No description provided for @aiErrBadUrl.
  ///
  /// In zh, this message translates to:
  /// **'请求地址无效，请检查基础地址格式'**
  String get aiErrBadUrl;

  /// No description provided for @aiErrAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'API Key 无效或无权访问，请检查密钥'**
  String get aiErrAuthFailed;

  /// No description provided for @aiErrNotFound.
  ///
  /// In zh, this message translates to:
  /// **'接口不存在，请检查请求地址与模型名'**
  String get aiErrNotFound;

  /// No description provided for @aiErrRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'请求过于频繁或额度不足'**
  String get aiErrRateLimited;

  /// No description provided for @aiErrServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器返回错误'**
  String get aiErrServer;

  /// No description provided for @aiErrBadResponse.
  ///
  /// In zh, this message translates to:
  /// **'无法解析服务器响应'**
  String get aiErrBadResponse;

  /// No description provided for @aiErrUpstream.
  ///
  /// In zh, this message translates to:
  /// **'服务器返回错误'**
  String get aiErrUpstream;

  /// No description provided for @aiErrUnknown.
  ///
  /// In zh, this message translates to:
  /// **'请求失败'**
  String get aiErrUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
