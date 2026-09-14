package top.talyra42.verifin

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews

/// 桌面小组件：展示「今日支出」并提供快速记账入口。
/// 数据由 Flutter 侧经 MethodChannel（`updateWidgetData`）写入 [WidgetData] 的
/// SharedPreferences，点「记一笔」复用 [MainActivity.ACTION_QUICK_ENTRY]，点主体打开应用。
class QuickEntryWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, createViews(context, it)) }
        // 每次重绘顺带把下一次午夜刷新闹钟对齐好（跨天自愈的触发源）。
        WidgetRefreshScheduler.scheduleNextMidnight(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        appWidgetIds.forEach { WidgetData.clearInstanceConfig(context, it) }
        super.onDeleted(context, appWidgetIds)
    }

    companion object {
        fun createViews(
            baseContext: Context,
            widgetId: Int,
            sample: Boolean = false,
        ): RemoteViews {
            val context = WidgetData.localizedContext(baseContext)
            // 跨天自愈：已过午夜则展示归零值，不必等应用打开重新推送。
            val config = WidgetData.InstanceConfig()
            val defaults = WidgetData.todayForToday(context)
            val selected = if (config.primaryMetric.isBlank()) defaults else
                WidgetData.metric(context, config.primaryMetric, defaults.first, defaults.second, config.bookId)
            val amount = if (sample) "0" else selected.first
            val quickEntryLabel = WidgetData.read(
                context,
                WidgetData.KEY_QUICK_ENTRY_LABEL,
                context.getString(R.string.quick_entry_button),
            )

            val views = RemoteViews(context.packageName, R.layout.quick_entry_widget)
            val lightSurface = !WidgetData.darkTheme(context)
            views.setInt(android.R.id.background, "setBackgroundResource", if (lightSurface) R.drawable.widget_surface_light else R.drawable.widget_surface_dark)
            views.setTextColor(R.id.widget_label, if (lightSurface) Color.rgb(107, 114, 128) else Color.rgb(184, 192, 204))
            views.setTextColor(R.id.widget_amount, if (lightSurface) Color.rgb(17, 24, 39) else Color.WHITE)
            views.setTextColor(R.id.widget_title, if (lightSurface) Color.rgb(107, 114, 128) else Color.rgb(184, 192, 204))
            views.setTextViewText(R.id.widget_title, if (sample) context.getString(R.string.widget_today_expense) else selected.second)
            views.setViewVisibility(R.id.widget_label, android.view.View.GONE)
            views.setTextViewText(R.id.widget_amount, amount)
            views.setContentDescription(R.id.widget_add_button, quickEntryLabel)

            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

            // 「记一笔」按钮：走快速记账 intent。
            val quickIntent = Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_QUICK_ENTRY
                putExtra("widgetId", widgetId)
                putExtra("widgetBookId", config.bookId)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            views.setOnClickPendingIntent(
                R.id.widget_add_button,
                PendingIntent.getActivity(context, 1, quickIntent, flags),
            )

            // 主体点击：正常打开应用。
            val openIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            if (openIntent != null) {
                openIntent.action = "top.talyra42.verifin.action.WIDGET_ROUTE"
                openIntent.putExtra("widgetRoute", config.action)
                openIntent.putExtra("widgetBookId", config.bookId)
                openIntent.putExtra("widgetId", widgetId)
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    PendingIntent.getActivity(context, 2, openIntent, flags),
                )
            }

            return views
        }
    }
}
