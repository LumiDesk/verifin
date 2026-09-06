package top.talyra42.verifin

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/// 「一行标签 + 大数值」型只读小组件的基类：本月预算、资产总额等复用同一布局
/// [R.layout.stat_widget]，只是读取的字段不同、点击整体打开应用。数值由 Flutter 侧
/// 经 [WidgetData] 写入。
abstract class StatWidgetProvider : AppWidgetProvider() {
    /// 该小组件在 [WidgetData] 中读取的数值 / 标签键，与缺省文案。
    protected abstract val amountKey: String
    protected abstract val labelKey: String
    protected abstract val defaultLabelRes: Int

    /// 解析展示的数值与标签；默认直接读取推送值。需要跨天/跨月自愈的子类（如预算）覆写。
    protected open fun resolveAmountLabel(context: Context): Pair<String, String> {
        return WidgetData.read(context, amountKey, "0") to
            WidgetData.read(context, labelKey, context.getString(defaultLabelRes))
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { render(context, appWidgetManager, it) }
        // 每次重绘顺带把下一次午夜刷新闹钟对齐好（跨天/跨月自愈的触发源）。
        WidgetRefreshScheduler.scheduleNextMidnight(context)
    }

    private fun render(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val (amount, label) = resolveAmountLabel(context)

        val views = RemoteViews(context.packageName, R.layout.stat_widget)
        views.setTextViewText(R.id.stat_widget_label, label)
        views.setTextViewText(R.id.stat_widget_value, amount)

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val openIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        if (openIntent != null) {
            views.setOnClickPendingIntent(
                R.id.stat_widget_root,
                // requestCode 随类名区分，避免不同小组件的 PendingIntent 相互覆盖。
                PendingIntent.getActivity(
                    context,
                    javaClass.name.hashCode(),
                    openIntent,
                    flags,
                ),
            )
        }
        manager.updateAppWidget(widgetId, views)
    }
}

/// 本月预算小组件：展示当前账本本月「可用预算 / 已超支」金额。
class BudgetWidgetProvider : StatWidgetProvider() {
    override val amountKey = WidgetData.KEY_BUDGET_AMOUNT
    override val labelKey = WidgetData.KEY_BUDGET_LABEL
    override val defaultLabelRes = R.string.widget_budget_available

    // 跨月自愈：进入新月后展示整月预算与「可用」文案。
    override fun resolveAmountLabel(context: Context) =
        WidgetData.budgetForMonth(context)
}

/// 资产总额小组件：展示所有可见账户余额合计。
class NetWorthWidgetProvider : StatWidgetProvider() {
    override val amountKey = WidgetData.KEY_NET_WORTH_AMOUNT
    override val labelKey = WidgetData.KEY_NET_WORTH_LABEL
    override val defaultLabelRes = R.string.widget_net_worth
}
