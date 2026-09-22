package top.talyra42.verifin

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.ui.graphics.Color as ComposeColor
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.color.ColorProvider
import androidx.compose.ui.unit.dp
import androidx.glance.action.Action
import es.antonborri.home_widget.actionStartActivity
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Native widget renderer supplied through home_widget's supported Glance path.
 * Flutter only publishes a projection; the launcher can render this while the
 * Flutter process is stopped.
 */
enum class VeriFinWidgetTemplate {
    QUICK_ENTRY,
    BUDGET,
    NET_WORTH,
    TREND,
}

private const val SNAPSHOTS_KEY = "verifin.widget.snapshots"
private const val BOOKS_KEY = "verifin.widget.books"
private const val ACTIVE_BOOK_KEY = "verifin.widget.active_book"
private const val LOCALE_KEY = "verifin.widget.locale"
private const val CONFIG_PREFIX = "verifin.widget.config."
private const val TODAY_KEY = "todayExpense"
private const val BUDGET_KEY = "budgetRemaining"
private const val NET_WORTH_KEY = "netWorth"
private const val PERIOD_EXPENSE_KEY = "periodExpense"

private data class InstanceConfig(
    val bookId: String = "",
    val metric: String = "",
)

private data class MetricValue(
    val label: String,
    val amount: String,
)

private object VeriFinWidgetStore {
    private fun prefs(context: Context): SharedPreferences = HomeWidgetPlugin.getData(context)

    fun locale(context: Context): String = prefs(context).getString(LOCALE_KEY, "") ?: ""

    fun config(context: Context, appWidgetId: Int): InstanceConfig {
        val raw = prefs(context).getString(CONFIG_PREFIX + appWidgetId, null) ?: return InstanceConfig()
        return runCatching {
            val json = JSONObject(raw)
            InstanceConfig(
                bookId = json.optString("bookId"),
                metric = json.optString("metric"),
            )
        }.getOrDefault(InstanceConfig())
    }

    fun clearConfig(context: Context, appWidgetId: Int) {
        prefs(context).edit().remove(CONFIG_PREFIX + appWidgetId).apply()
    }

    fun activeBook(context: Context): String = prefs(context).getString(ACTIVE_BOOK_KEY, "") ?: ""

    fun snapshot(context: Context, bookId: String): JSONObject? {
        val raw = prefs(context).getString(SNAPSHOTS_KEY, null) ?: return null
        return runCatching { JSONObject(raw).optJSONObject(bookId) }.getOrNull()
    }

    fun defaultBook(context: Context): String {
        val active = activeBook(context)
        if (active.isNotBlank() && snapshot(context, active) != null) return active
        val raw = prefs(context).getString(BOOKS_KEY, null) ?: return ""
        return runCatching {
            val books = org.json.JSONArray(raw)
            if (books.length() == 0) "" else books.optJSONObject(0)?.optString("id", "").orEmpty()
        }.getOrDefault("")
    }

    fun metric(
        context: Context,
        bookId: String,
        template: VeriFinWidgetTemplate,
        requested: String,
    ): MetricValue {
        val snapshot = snapshot(context, bookId)
        val key = requested.ifBlank {
            when (template) {
                VeriFinWidgetTemplate.QUICK_ENTRY -> TODAY_KEY
                VeriFinWidgetTemplate.BUDGET -> BUDGET_KEY
                VeriFinWidgetTemplate.NET_WORTH -> NET_WORTH_KEY
                VeriFinWidgetTemplate.TREND -> PERIOD_EXPENSE_KEY
            }
        }
        val item = snapshot?.optJSONObject(key)
        val currentDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val snapshotDate = snapshot?.optString("date").orEmpty()
        if (key == TODAY_KEY && snapshotDate.isNotBlank() && snapshotDate != currentDate) {
            return MetricValue(item?.optString("label").orEmpty().ifBlank { todayLabel(context) }, "0")
        }
        return MetricValue(
            label = item?.optString("label").orEmpty().ifBlank { fallbackLabel(context, template) },
            amount = item?.optString("amount").orEmpty().ifBlank { "0" },
        )
    }

    private fun fallbackLabel(context: Context, template: VeriFinWidgetTemplate): String = when (template) {
        VeriFinWidgetTemplate.QUICK_ENTRY -> todayLabel(context)
        VeriFinWidgetTemplate.BUDGET -> budgetLabel(context)
        VeriFinWidgetTemplate.NET_WORTH -> netWorthLabel(context)
        VeriFinWidgetTemplate.TREND -> periodExpenseLabel(context)
    }

    private fun todayLabel(context: Context): String = if (locale(context).startsWith("en")) "Today's spending" else "今日支出"
    private fun budgetLabel(context: Context): String = if (locale(context).startsWith("en")) "Budget remaining" else "剩余预算"
    private fun netWorthLabel(context: Context): String = if (locale(context).startsWith("en")) "Total assets" else "资产总额"
    private fun periodExpenseLabel(context: Context): String = if (locale(context).startsWith("en")) "Period spending" else "本期支出"
}

class VeriFinGlanceWidget(private val template: VeriFinWidgetTemplate) : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    fun previewFingerprint(context: Context): String =
        "verifin-glance-v1|$template|${VeriFinWidgetStore.locale(context)}"

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { Content(context, id, currentState()) }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent { PreviewContent(context) }
    }

    @androidx.compose.runtime.Composable
    private fun PreviewContent(context: Context) {
        WidgetCard(
            context = context,
            label = when (template) {
                VeriFinWidgetTemplate.QUICK_ENTRY -> "今日支出"
                VeriFinWidgetTemplate.BUDGET -> "剩余预算"
                VeriFinWidgetTemplate.NET_WORTH -> "资产总额"
                VeriFinWidgetTemplate.TREND -> "本期支出"
            },
            amount = "0",
            action = null,
        )
    }

    @androidx.compose.runtime.Composable
    private fun Content(
        context: Context,
        id: GlanceId,
        state: HomeWidgetGlanceState,
    ) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        val config = VeriFinWidgetStore.config(context, appWidgetId)
        val bookId = config.bookId.ifBlank { VeriFinWidgetStore.defaultBook(context) }
        val value = VeriFinWidgetStore.metric(context, bookId, template, config.metric)
        val route = if (template == VeriFinWidgetTemplate.QUICK_ENTRY) "entry" else "open"
        val rootAction = actionStartActivity<MainActivity>(context, android.net.Uri.parse("verifin://widget/$appWidgetId/$route"))
        WidgetCard(
            context = context,
            label = value.label,
            amount = value.amount,
            action = rootAction,
        )
    }

    @androidx.compose.runtime.Composable
    private fun WidgetCard(
        context: Context,
        label: String,
        amount: String,
        action: Action?,
    ) {
        val dark = (context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        val background = if (dark) ComposeColor(0xFF1E293B) else ComposeColor(0xFFFFFFFF)
        val primary = if (dark) ComposeColor(0xFFF5F5F7) else ComposeColor(0xFF111827)
        val muted = if (dark) ComposeColor(0xFFB8C0CC) else ComposeColor(0xFF6B7280)
        val modifier = GlanceModifier.fillMaxSize().background(background).padding(14.dp)
        if (action == null) {
            Column(modifier = modifier, verticalAlignment = Alignment.CenterVertically) {
                CardContent(label, amount, muted, primary)
            }
        } else {
            Column(modifier = modifier.clickable(onClick = action), verticalAlignment = Alignment.CenterVertically) {
                CardContent(label, amount, muted, primary)
            }
        }
    }

    @androidx.compose.runtime.Composable
    private fun CardContent(
        label: String,
        amount: String,
        muted: ComposeColor,
        primary: ComposeColor,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = GlanceModifier.fillMaxWidth()) {
            Column(modifier = GlanceModifier.fillMaxWidth()) {
                Text(text = label, style = TextStyle(color = ColorProvider(muted, muted)))
                Spacer(modifier = GlanceModifier.height(4.dp))
                Text(text = amount, style = TextStyle(color = ColorProvider(primary, primary)))
            }
        }
    }
}

abstract class VeriFinWidgetReceiver<T : VeriFinGlanceWidget> :
    es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver<T>() {
    override fun previewFingerprint(context: Context): String =
        glanceAppWidget.previewFingerprint(context)

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        appWidgetIds.forEach { VeriFinWidgetStore.clearConfig(context, it) }
        super.onDeleted(context, appWidgetIds)
    }
}

class QuickEntryWidgetProvider : VeriFinWidgetReceiver<VeriFinGlanceWidget>() {
    override val glanceAppWidget = VeriFinGlanceWidget(VeriFinWidgetTemplate.QUICK_ENTRY)
}

class BudgetWidgetProvider : VeriFinWidgetReceiver<VeriFinGlanceWidget>() {
    override val glanceAppWidget = VeriFinGlanceWidget(VeriFinWidgetTemplate.BUDGET)
}

class NetWorthWidgetProvider : VeriFinWidgetReceiver<VeriFinGlanceWidget>() {
    override val glanceAppWidget = VeriFinGlanceWidget(VeriFinWidgetTemplate.NET_WORTH)
}

class TrendWidgetProvider : VeriFinWidgetReceiver<VeriFinGlanceWidget>() {
    override val glanceAppWidget = VeriFinGlanceWidget(VeriFinWidgetTemplate.TREND)
}
