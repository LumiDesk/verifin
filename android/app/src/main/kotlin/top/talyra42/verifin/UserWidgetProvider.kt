package top.talyra42.verifin

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.Bundle
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

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

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        render(context, manager, id)
    }

    companion object {
        const val EXTRA_DEFINITION_ID = "userWidgetDefinitionId"

        /** Preview shown by Android's pin confirmation when the launcher supports it. */
        fun pickerPreview(context: Context): RemoteViews {
            val id = WidgetData.readDefinitionIds(context).firstOrNull()
            val definition = id?.let { WidgetData.readDefinition(context, it) }
            val presentation = try {
                JSONObject(definition?.presentationJson.orEmpty())
            } catch (_: Exception) {
                JSONObject()
            }
            val views = RemoteViews(context.packageName, R.layout.user_widget)
            val bitmap = definition?.backgroundPath?.takeIf { it.isNotBlank() }?.let {
                runCatching { BitmapFactory.decodeFile(it) }.getOrNull()
            }
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.user_widget_background, bitmap)
                views.setViewVisibility(R.id.user_widget_background, View.VISIBLE)
                views.setViewVisibility(R.id.user_widget_scrim, View.VISIBLE)
                views.setTextColor(R.id.user_widget_title, Color.WHITE)
                views.setTextColor(R.id.user_widget_label, Color.LTGRAY)
                views.setTextColor(R.id.user_widget_value, Color.WHITE)
            } else {
                views.setInt(R.id.user_widget_root, "setBackgroundColor", definition?.backgroundColor ?: Color.rgb(30, 41, 59))
                views.setViewVisibility(R.id.user_widget_background, View.GONE)
                views.setViewVisibility(R.id.user_widget_scrim, View.GONE)
                val light = definition?.let { isLightColor(it.backgroundColor) } ?: false
                views.setTextColor(R.id.user_widget_title, if (light) Color.rgb(107, 114, 128) else Color.WHITE)
                views.setTextColor(R.id.user_widget_label, if (light) Color.rgb(107, 114, 128) else Color.LTGRAY)
                views.setTextColor(R.id.user_widget_value, if (light) Color.rgb(17, 24, 39) else Color.WHITE)
            }
            return views.apply {
                setTextViewText(
                    R.id.user_widget_title,
                    definition?.name ?: context.getString(R.string.user_widget_default_name),
                )
                setTextViewText(
                    R.id.user_widget_label,
                    presentation.optString("label", context.getString(R.string.widget_today_expense)),
                )
                setTextViewText(R.id.user_widget_value, presentation.optString("amount", "0"))
                setViewVisibility(R.id.user_widget_chart, View.GONE)
                setViewVisibility(R.id.user_widget_add, View.GONE)
            }
        }

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val provider = android.content.ComponentName(context, UserWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(provider)
            ids.forEach { render(context, manager, it) }
        }

        private fun render(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val definitionId = WidgetData.readDefinitionId(context, widgetId)
            // Some launchers skip the configure Activity when adding from the picker.
            // Render the first saved design as a safe fallback; a later pin callback
            // replaces this binding with the design selected in the app.
            val definition = WidgetData.readDefinition(context, definitionId)
                ?: WidgetData.readDefinitionIds(context).firstOrNull()?.let {
                    WidgetData.readDefinition(context, it)
                }
                ?: WidgetData.UserDefinition(id = "fallback", name = context.getString(R.string.user_widget_choose_design))
            val views = RemoteViews(context.packageName, R.layout.user_widget)
            val presentation = try { JSONObject(definition.presentationJson) } catch (_: Exception) { JSONObject() }
            val compact = definition.size == "oneByTwo" ||
                manager.getAppWidgetOptions(widgetId).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 160) < 130
            val bitmap = definition.backgroundPath.takeIf { it.isNotBlank() }?.let {
                runCatching { BitmapFactory.decodeFile(it) }.getOrNull()
            }
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.user_widget_background, bitmap)
                views.setViewVisibility(R.id.user_widget_background, View.VISIBLE)
            } else {
                views.setInt(R.id.user_widget_root, "setBackgroundColor", definition.backgroundColor)
                views.setViewVisibility(R.id.user_widget_background, View.GONE)
            }
            views.setViewVisibility(R.id.user_widget_scrim, if (bitmap == null) View.GONE else View.VISIBLE)
            // User designs use dark surfaces by default. Android inflates RemoteViews
            // with the launcher's resource mode, which may be light even when the app
            // preview is dark; choose text contrast from the actual surface color.
            val surfaceLight = bitmap == null && isLightColor(definition.backgroundColor)
            val foreground = if (bitmap != null || !surfaceLight) Color.WHITE else Color.rgb(17, 24, 39)
            val muted = if (bitmap != null || !surfaceLight) Color.LTGRAY else Color.rgb(107, 114, 128)
            views.setTextColor(R.id.user_widget_title, muted)
            views.setTextColor(R.id.user_widget_label, muted)
            views.setTextColor(R.id.user_widget_value, foreground)
            views.setTextViewText(R.id.user_widget_title, definition.name)
            views.setTextViewText(R.id.user_widget_label, presentation.optString("label", context.getString(R.string.widget_refresh_required)))
            views.setViewVisibility(R.id.user_widget_label, if (compact) View.GONE else View.VISIBLE)
            views.setTextViewText(
                R.id.user_widget_value,
                presentation.optString("amount", "—"),
            )
            val secondaries = presentation.optJSONArray("secondary")
            val ids = intArrayOf(R.id.user_widget_secondary_1, R.id.user_widget_secondary_2, R.id.user_widget_secondary_3)
            ids.forEachIndexed { index, viewId ->
                val text = secondaries?.optString(index).orEmpty()
                if (text.isBlank() || compact) {
                    views.setViewVisibility(viewId, View.GONE)
                } else {
                    views.setTextViewText(viewId, text)
                    views.setTextColor(viewId, muted)
                    views.setViewVisibility(viewId, View.VISIBLE)
                }
            }
            views.setViewVisibility(R.id.user_widget_chart, View.GONE)
            if (definition.chartMetric.isNotBlank() && !compact && definition.template != "quickEntry") {
                val points = presentation.optJSONArray("points")
                val values = if (points == null) emptyList() else
                    (0 until points.length()).map { points.optDouble(it, Double.NaN).toFloat() }.filter { it.isFinite() }
                val chart = WidgetChartRenderer.sparkline(values)
                if (chart != null) {
                    views.setImageViewBitmap(R.id.user_widget_chart, chart)
                    views.setViewVisibility(R.id.user_widget_chart, View.VISIBLE)
                }
            }
            val quickEntry = definition.template == "quickEntry"
            views.setViewVisibility(R.id.user_widget_add, if (quickEntry) View.VISIBLE else View.GONE)
            views.setContentDescription(R.id.user_widget_add, presentation.optString("quickEntryLabel", context.getString(R.string.quick_entry_button)))

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                launch.action = MainActivity.ACTION_WIDGET_ROUTE
                launch.putExtra("widgetRoute", definition.action)
                launch.putExtra("widgetBookId", definition.bookId)
                launch.putExtra("widgetId", widgetId)
                launch.putExtra(EXTRA_DEFINITION_ID, definition.id)
                launch.data = Uri.parse("verifin://widget/$widgetId/open")
                val pending = PendingIntent.getActivity(
                    context, widgetId, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.user_widget_root, pending)
                if (quickEntry) {
                    val entry = Intent(launch).apply {
                        putExtra("widgetRoute", "entry")
                        data = Uri.parse("verifin://widget/$widgetId/entry")
                    }
                    views.setOnClickPendingIntent(R.id.user_widget_add, PendingIntent.getActivity(
                        context, widgetId, entry, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ))
                }
            }
            manager.updateAppWidget(widgetId, views)
        }

        private fun isLightColor(color: Int): Boolean {
            val r = Color.red(color) / 255.0
            val g = Color.green(color) / 255.0
            val b = Color.blue(color) / 255.0
            return (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.62
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
        selectedId = ids.firstOrNull().orEmpty()

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
                this.id = View.generateViewId()
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
        if (ids.isEmpty()) root.addView(android.widget.TextView(this).apply {
            text = getString(R.string.user_widget_empty)
            setPadding(0, 24, 0, 24)
        })
        root.addView(android.widget.Button(this).apply {
            text = getString(R.string.user_widget_add)
            isEnabled = ids.isNotEmpty()
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
