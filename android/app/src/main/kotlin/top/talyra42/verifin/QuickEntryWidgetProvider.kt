package top.talyra42.verifin

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
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
        appWidgetIds.forEach { renderWidget(context, appWidgetManager, it) }
        // 每次重绘顺带把下一次午夜刷新闹钟对齐好（跨天自愈的触发源）。
        WidgetRefreshScheduler.scheduleNextMidnight(context)
    }

    companion object {
        private fun renderWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
        ) {
            // 跨天自愈：已过午夜则展示归零值，不必等应用打开重新推送。
            val (amount, label) = WidgetData.todayForToday(context)
            val quickEntryLabel = WidgetData.read(
                context,
                WidgetData.KEY_QUICK_ENTRY_LABEL,
                "记一笔",
            )

            val views = RemoteViews(context.packageName, R.layout.quick_entry_widget)
            views.setTextViewText(R.id.widget_amount, amount)
            views.setTextViewText(R.id.widget_label, label)
            views.setTextViewText(R.id.widget_add_button, quickEntryLabel)

            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

            // 「记一笔」按钮：走快速记账 intent。
            val quickIntent = Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_QUICK_ENTRY
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
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    PendingIntent.getActivity(context, 2, openIntent, flags),
                )
            }

            manager.updateAppWidget(widgetId, views)
        }
    }
}
