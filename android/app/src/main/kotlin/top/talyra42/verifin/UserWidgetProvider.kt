package top.talyra42.verifin

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews

/** Renders a saved user design. A desktop instance only stores the definition id. */
class UserWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
        WidgetRefreshScheduler.scheduleNextMidnight(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        appWidgetIds.forEach { WidgetData.clearDefinitionBinding(context, it) }
        super.onDeleted(context, appWidgetIds)
    }

    companion object {
        const val EXTRA_DEFINITION_ID = "userWidgetDefinitionId"

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val provider = android.content.ComponentName(context, UserWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(provider)
            if (ids.isNotEmpty()) manager.notifyAppWidgetViewDataChanged(ids, R.id.user_widget_root)
            ids.forEach { render(context, manager, it) }
        }

        private fun render(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val definitionId = WidgetData.readDefinitionId(context, widgetId)
            val definition = WidgetData.readDefinition(context, definitionId)
                ?: WidgetData.UserDefinition(id = "fallback")
            val views = RemoteViews(context.packageName, R.layout.user_widget)
            views.setInt(R.id.user_widget_root, "setBackgroundColor", definition.backgroundColor)
            val bitmap = definition.backgroundPath.takeIf { it.isNotBlank() }?.let {
                runCatching { BitmapFactory.decodeFile(it) }.getOrNull()
            }
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.user_widget_background, bitmap)
                views.setViewVisibility(R.id.user_widget_background, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.user_widget_background, View.GONE)
            }
            views.setTextViewText(R.id.user_widget_title, definition.name)
            val primary = WidgetData.metric(
                context,
                definition.primaryMetric,
                WidgetData.read(context, WidgetData.KEY_TODAY_AMOUNT, "0"),
                context.getString(R.string.widget_today_expense),
            )
            views.setTextViewText(R.id.user_widget_label, primary.second)
            views.setTextViewText(
                R.id.user_widget_value,
                if (definition.hideAmounts) "••••" else primary.first,
            )
            val secondaries = definition.secondaryMetrics.take(3)
            val ids = intArrayOf(R.id.user_widget_secondary_1, R.id.user_widget_secondary_2, R.id.user_widget_secondary_3)
            ids.forEachIndexed { index, viewId ->
                val metric = secondaries.getOrNull(index)
                if (metric == null) {
                    views.setViewVisibility(viewId, View.GONE)
                } else {
                    val value = WidgetData.metric(context, metric, "0", "")
                    views.setTextViewText(viewId, if (definition.hideAmounts) value.second else "${value.second}  ${value.first}")
                    views.setViewVisibility(viewId, View.VISIBLE)
                }
            }
            if (definition.chartMetric.isNotBlank()) {
                val chart = WidgetChartRenderer.sparkline(WidgetData.trendPoints(context))
                if (chart != null) {
                    views.setImageViewBitmap(R.id.user_widget_chart, chart)
                    views.setViewVisibility(R.id.user_widget_chart, View.VISIBLE)
                }
            } else views.setViewVisibility(R.id.user_widget_chart, View.GONE)

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                launch.action = MainActivity.ACTION_WIDGET_ROUTE
                launch.putExtra("widgetRoute", definition.action)
                launch.putExtra("widgetBookId", definition.bookId)
                launch.putExtra("widgetId", widgetId)
                launch.putExtra(EXTRA_DEFINITION_ID, definition.id)
                val pending = PendingIntent.getActivity(
                    context, widgetId, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.user_widget_root, pending)
            }
            manager.updateAppWidget(widgetId, views)
        }
    }
}

/** Native configuration screen shown by the launcher when adding a user widget. */
class UserWidgetConfigureActivity : android.app.Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var selectedId: String = ""

    override fun onCreate(state: android.os.Bundle?) {
        super.onCreate(state)
        setResult(RESULT_CANCELED)
        widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }
        val ids = WidgetData.readDefinitionIds(this)
        if (ids.isEmpty()) {
            val fallback = WidgetData.UserDefinition(id = "default", name = getString(R.string.user_widget_default_name))
            WidgetData.writeDefinition(this, fallback)
            selectedId = fallback.id
        } else selectedId = ids.first()

        val root = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(32, 40, 32, 24)
            setBackgroundColor(Color.WHITE)
        }
        root.addView(android.widget.TextView(this).apply {
            text = getString(R.string.user_widget_choose_design)
            textSize = 22f
            setTextColor(Color.rgb(17, 24, 39))
        })
        val group = android.widget.RadioGroup(this).apply { orientation = android.widget.RadioGroup.VERTICAL }
        ids.forEach { id ->
            val definition = WidgetData.readDefinition(this@UserWidgetConfigureActivity, id) ?: return@forEach
            val button = android.widget.RadioButton(this@UserWidgetConfigureActivity).apply {
                text = definition.name
                textSize = 16f
                isChecked = id == selectedId
                tag = id
            }
            group.addView(button)
        }
        group.setOnCheckedChangeListener { _, checkedId ->
            selectedId = group.findViewById<android.widget.RadioButton>(checkedId)?.tag as? String ?: selectedId
        }
        root.addView(group, android.widget.LinearLayout.LayoutParams(-1, 0, 1f))
        root.addView(android.widget.Button(this).apply {
            text = getString(R.string.user_widget_add)
            setOnClickListener {
                WidgetData.bindDefinition(this@UserWidgetConfigureActivity, widgetId, selectedId)
                val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                setResult(RESULT_OK, result)
                UserWidgetProvider.refresh(this@UserWidgetConfigureActivity)
                finish()
            }
        })
        setContentView(root)
    }
}

class UserWidgetPinReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val widgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        val definitionId = intent?.getStringExtra(UserWidgetProvider.EXTRA_DEFINITION_ID)
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID || definitionId.isNullOrBlank()) return
        WidgetData.bindDefinition(context, widgetId, definitionId)
        UserWidgetProvider.refresh(context)
    }
}
