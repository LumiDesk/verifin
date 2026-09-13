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
                setViewVisibility(R.id.user_widget_ring, View.GONE)
                setViewVisibility(R.id.user_widget_add, View.GONE)
                if (definition?.template == "budget") {
                    val usage = presentation.optDouble("budgetUsage", Double.NaN).toFloat()
                    WidgetChartRenderer.progressRing(usage)?.let {
                        setImageViewBitmap(R.id.user_widget_ring, it)
                        setViewVisibility(R.id.user_widget_ring, View.VISIBLE)
                    }
                }
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
            views.setViewVisibility(R.id.user_widget_ring, View.GONE)
            if (definition.template == "budget" && !compact) {
                val usage = presentation.optDouble("budgetUsage", Double.NaN).toFloat()
                WidgetChartRenderer.progressRing(usage)?.let {
                    views.setImageViewBitmap(R.id.user_widget_ring, it)
                    views.setViewVisibility(R.id.user_widget_ring, View.VISIBLE)
                }
            }
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

/** Native per-instance configuration shown when the launcher adds or edits a widget. */
class UserWidgetConfigureActivity : android.app.Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(state: android.os.Bundle?) {
        super.onCreate(state)
        setResult(RESULT_CANCELED)
        widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }
        val info = AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId)
        if (info == null) { finish(); return }
        val provider = info.provider.className
        val template = when {
            provider.endsWith("QuickEntryWidgetProvider") -> "quickEntry"
            provider.endsWith("BudgetWidgetProvider") -> "budget"
            provider.endsWith("TrendWidgetProvider") -> "trend"
            else -> "netWorth"
        }
        val current = WidgetData.readInstanceConfig(this, widgetId)
        val root = android.widget.ScrollView(this).apply { setBackgroundColor(Color.WHITE) }
        val content = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(32, 36, 32, 24)
        }
        content.addView(android.widget.TextView(this).apply {
            text = getString(R.string.widget_instance_config_title)
            textSize = 23f
            setTextColor(Color.rgb(17, 24, 39))
        })
        content.addView(android.widget.TextView(this).apply {
            text = templateLabel(template)
            textSize = 16f
            setTextColor(Color.rgb(107, 114, 128))
            setPadding(0, 8, 0, 18)
        })

        val books = WidgetData.readWidgetBooks(this)
        val bookIds = books.map { it.first }
        val bookSpinner = addSpinner(content, getString(R.string.widget_instance_book),
            books.map { it.second }, bookIds.indexOf(current.bookId).coerceAtLeast(0))
        val metricCodes = listOf("todayExpense", "periodExpense", "periodIncome", "budgetRemaining", "budgetUsed", "netWorth", "totalAssets", "totalLiabilities", "balance", "transactionCount")
        val metricLabels = listOf("今日支出", "周期支出", "周期收入", "预算剩余", "预算已用", "净资产", "总资产", "总负债", "账户余额", "交易笔数")
        val defaultMetric = when (template) { "quickEntry" -> "todayExpense"; "budget" -> "budgetRemaining"; "trend" -> "periodExpense"; else -> "netWorth" }
        val metricSpinner = addSpinner(content, getString(R.string.widget_instance_primary), metricLabels,
            metricCodes.indexOf(current.primaryMetric.ifBlank { defaultMetric }).coerceAtLeast(0))
        val secondaryCodes = listOf("") + metricCodes
        val secondaryLabels = listOf(getString(R.string.widget_instance_none)) + metricLabels
        val secondarySpinner = addSpinner(content, getString(R.string.widget_instance_secondary), secondaryLabels,
            secondaryCodes.indexOf(current.secondaryMetric).coerceAtLeast(0))
        val chartCodes = listOf("", "expense", "income", "net", "budgetUsage", "netWorth")
        val chartLabels = listOf(getString(R.string.widget_instance_none), "支出趋势", "收入趋势", "收支净额", "预算使用", "净资产变化")
        val chartSpinner = addSpinner(content, getString(R.string.widget_instance_chart), chartLabels,
            chartCodes.indexOf(current.chartMetric).coerceAtLeast(0))
        val rangeSpinner = addSpinner(content, getString(R.string.widget_instance_range),
            listOf("近 7 天", "近 30 天", "近 90 天", "本年"), listOf(7, 30, 90, 365).indexOf(current.chartDays).let { if (it < 0) 1 else it })
        val colorCodes = listOf("FF1E293B", "FF111827", "FFFFFFFF", "FF312E81", "FF0F3D3E")
        val colorLabels = listOf("深海蓝", "墨黑", "纯白", "靛青", "深青")
        val colorSpinner = addSpinner(content, getString(R.string.widget_instance_background), colorLabels,
            colorCodes.indexOf(Integer.toHexString(current.backgroundColor).uppercase()).coerceAtLeast(0))
        val hide = android.widget.Switch(this).apply {
            text = getString(R.string.widget_instance_hide_amounts)
            setTextColor(Color.rgb(17, 24, 39))
            isChecked = current.hideAmounts
            setPadding(0, 12, 0, 12)
        }
        content.addView(hide)
        val save = android.widget.Button(this).apply {
            text = getString(R.string.widget_instance_save)
            setOnClickListener {
                val values = mapOf(
                    "template" to template,
                    "bookId" to bookIds.getOrElse(bookSpinner.selectedItemPosition) { "" },
                    "primaryMetric" to metricCodes[metricSpinner.selectedItemPosition],
                    "secondaryMetric" to secondaryCodes[secondarySpinner.selectedItemPosition],
                    "chartMetric" to chartCodes[chartSpinner.selectedItemPosition],
                    "chartDays" to listOf(7, 30, 90, 365)[rangeSpinner.selectedItemPosition].toString(),
                    "backgroundColor" to colorCodes[colorSpinner.selectedItemPosition],
                    "hideAmounts" to hide.isChecked.toString(),
                    "action" to if (template == "quickEntry") "entry" else "app",
                )
                WidgetData.writeInstanceConfig(this@UserWidgetConfigureActivity, widgetId, values)
                val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                setResult(RESULT_OK, result)
                refreshProvider(provider)
                finish()
            }
        }
        content.addView(save)
        root.addView(content)
        setContentView(root)
    }

    private fun addSpinner(parent: android.widget.LinearLayout, label: String, values: List<String>, selected: Int): android.widget.Spinner {
        parent.addView(android.widget.TextView(this).apply {
            text = label
            textSize = 13f
            setTextColor(Color.rgb(107, 114, 128))
            setPadding(0, 8, 0, 2)
        })
        val spinner = android.widget.Spinner(this)
        spinner.adapter = android.widget.ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, values)
        spinner.setSelection(selected.coerceIn(0, values.lastIndex.coerceAtLeast(0)))
        parent.addView(spinner, android.widget.LinearLayout.LayoutParams(-1, android.widget.LinearLayout.LayoutParams.WRAP_CONTENT))
        return spinner
    }

    private fun templateLabel(template: String): String = when (template) {
        "quickEntry" -> getString(R.string.widget_template_quick_entry)
        "budget" -> getString(R.string.widget_template_budget)
        "trend" -> getString(R.string.widget_template_trend)
        else -> getString(R.string.widget_template_net_worth)
    }

    private fun refreshProvider(className: String) {
        runCatching {
            val provider = Class.forName(className).asSubclass(AppWidgetProvider::class.java)
            WidgetData.refresh(this, provider)
        }
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
