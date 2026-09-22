package top.talyra42.verifin

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.net.Uri
import android.appwidget.AppWidgetManager
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.*
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.*
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Provider identity is stable across upgrades; each Glance widget has its own
 * class because Glance uses that class to resolve its receiver and sessions. */
enum class VeriFinWidgetTemplate(val key: String, val metric: String, val labelRes: Int) {
    QUICK_ENTRY("quick_entry", "todayExpense", R.string.widget_today_expense),
    BUDGET("budget", "budgetRemaining", R.string.widget_budget_available),
    NET_WORTH("net_worth", "netWorth", R.string.widget_net_worth),
    TREND("trend", "periodExpense", R.string.widget_trend);
    companion object {
        fun fromKey(key: String) = entries.first { it.key == key }
        fun fromProvider(provider: String) = when (provider.substringAfterLast('.')) {
            "QuickEntryWidgetProvider" -> QUICK_ENTRY
            "BudgetWidgetProvider" -> BUDGET
            "NetWorthWidgetProvider" -> NET_WORTH
            "TrendWidgetProvider" -> TREND
            else -> error("Unknown widget provider")
        }
    }
}

data class WidgetInstanceSelection(val bookId: String = "", val metric: String = "")
data class WidgetDisplay(
    val title: String, val label: String, val amount: String,
    val points: List<Float> = emptyList(), val usage: Float? = null,
    val dark: Boolean = false, val bookId: String = "",
)

object VeriFinWidgetStore {
    const val CONFIG_PREFIX = "verifin.widget.config."
    fun prefs(context: Context): SharedPreferences = HomeWidgetPlugin.getData(context)
    fun config(prefs: SharedPreferences, id: Int): WidgetInstanceSelection {
        val raw = prefs.getString("$CONFIG_PREFIX$id", null) ?: return WidgetInstanceSelection()
        return try {
            val json = JSONObject(raw)
            WidgetInstanceSelection(json.optString("bookId"), json.optString("metric"))
        } catch (error: Exception) {
            android.util.Log.w("VeriFinWidgets", "Invalid instance configuration", error)
            WidgetInstanceSelection()
        }
    }
    fun localized(context: Context, prefs: SharedPreferences): Context {
        val language = prefs.getString("verifin.widget.locale", "").orEmpty()
        if (language.isBlank()) return context
        return context.createConfigurationContext(Configuration(context.resources.configuration).apply {
            setLocale(Locale.forLanguageTag(language))
        })
    }
    fun display(context: Context, template: VeriFinWidgetTemplate, selection: WidgetInstanceSelection,
                sample: Boolean = false, now: Date = Date(), prefs: SharedPreferences = prefs(context)): WidgetDisplay {
        val localized = localized(context, prefs)
        val dark = when (prefs.getString("verifin.widget.theme", "system")) {
            "dark" -> true
            "light" -> false
            else -> context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        }
        val title = localized.getString(template.labelRes)
        if (sample) return WidgetDisplay(title, title, "0", List(30) { 0f }, if (template == VeriFinWidgetTemplate.BUDGET) 0f else null, dark)
        val bookId = selection.bookId.ifBlank { prefs.getString("verifin.widget.active_book", "").orEmpty() }
        val root = try { JSONObject(prefs.getString("verifin.widget.snapshots", "{}").orEmpty()) }
            catch (error: Exception) { android.util.Log.w("VeriFinWidgets", "Invalid widget projection", error); JSONObject() }
        val snapshot = root.optJSONObject(bookId)
        val metric = selection.metric.ifBlank { template.metric }
        val item = snapshot?.optJSONObject(metric)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now)
        val expiredToday = metric == "todayExpense" && snapshot?.optString("date") != today
        val label = item?.optString("label").orEmpty().ifBlank { title }
        val amount = if (expiredToday) "0" else item?.optString("amount").orEmpty().ifBlank { if (snapshot == null) "—" else "0" }
        val pointsJson = item?.optJSONArray("points")
        val points = if (pointsJson == null) emptyList() else (0 until pointsJson.length()).map {
            pointsJson.optDouble(it, Double.NaN).toFloat()
        }.let { values -> if (values.all { it.isFinite() }) values else emptyList() }
        val usage = item?.optDouble("usage", Double.NaN)?.toFloat()?.takeIf { it.isFinite() }
        return WidgetDisplay(title, label, amount, points, usage, dark, bookId)
    }
}

// Native counterparts of app_theme.dart tokens; shared by all Glance surfaces.
private val widgetRoyal = Color(0xFF346EDB)
private val widgetTextLight = Color(0xFF111827)
private val widgetTextDark = Color(0xFFF5F5F7)
private val widgetMutedLight = Color(0xFF6B7280)
private val widgetMutedDark = Color(0xFFB8C0CC)

/** Same composition for the launcher, generated preview and in-app draft preview. */
@Composable
fun VeriFinWidgetContent(template: VeriFinWidgetTemplate, data: WidgetDisplay, open: Action? = null, add: Action? = null, widgetId: Int? = null) {
    val foreground = if (data.dark) widgetTextDark else widgetTextLight
    val muted = if (data.dark) widgetMutedDark else widgetMutedLight
    val size = LocalSize.current
    val small = size.width < 150.dp || size.height < 130.dp
    val metricSize = if (template == VeriFinWidgetTemplate.QUICK_ENTRY) 24 else if (small || data.amount.length > 12) 20 else 28
    val surface = if (data.dark) R.drawable.widget_surface_dark else R.drawable.widget_surface_light
    var card = GlanceModifier.fillMaxWidth().background(ImageProvider(surface)).cornerRadius(16.dp).appWidgetBackground()
    card = if (template == VeriFinWidgetTemplate.QUICK_ENTRY) card.height(72.dp) else card.fillMaxHeight()
    if (open != null) card = card.clickable(open)
    Box(GlanceModifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        if (template == VeriFinWidgetTemplate.QUICK_ENTRY) {
            AndroidRemoteViews(QuickWidgetContent.views(LocalContext.current, data, widgetId),
                GlanceModifier.fillMaxWidth().height(72.dp))
        } else {
            Column(card.padding(if (small) 10.dp else 14.dp)) {
                Text(data.title, style = TextStyle(color = ColorProvider(muted), fontSize = 12.sp), maxLines = 1)
                if (template == VeriFinWidgetTemplate.TREND) {
                    Spacer(GlanceModifier.height(8.dp))
                    Row(GlanceModifier.fillMaxWidth().defaultWeight(), verticalAlignment = Alignment.Bottom) {
                        Column(GlanceModifier.defaultWeight()) { MetricText(data, foreground, muted, metricSize) }
                        if (data.points.size >= 2) {
                            Spacer(GlanceModifier.width(16.dp))
                            Image(ImageProvider(WidgetGraphics.sparkline(data.points)), null,
                                GlanceModifier.defaultWeight().fillMaxHeight(), contentScale = ContentScale.FillBounds)
                        }
                    }
                } else {
                    Column(GlanceModifier.fillMaxWidth().defaultWeight(), verticalAlignment = Alignment.CenterVertically) {
                        MetricText(data, foreground, muted, metricSize)
                    }
                    if (template == VeriFinWidgetTemplate.BUDGET && data.usage != null) {
                        Box(GlanceModifier.fillMaxWidth().height(if (small) 48.dp else 64.dp), contentAlignment = Alignment.CenterEnd) {
                            Image(ImageProvider(WidgetGraphics.ring(data.usage, data.dark)), null, GlanceModifier.size(if (small) 48.dp else 64.dp))
                        }
                    }
                    if (template == VeriFinWidgetTemplate.NET_WORTH && data.points.size >= 2) {
                        Image(ImageProvider(WidgetGraphics.sparkline(data.points)), null,
                            GlanceModifier.fillMaxWidth().height(44.dp), contentScale = ContentScale.FillBounds)
                    }
                }
            }
        }
    }
}

@Composable
private fun MetricText(data: WidgetDisplay, foreground: Color, muted: Color, size: Int) {
    if (data.label != data.title) Text(data.label, style = TextStyle(color = ColorProvider(muted), fontSize = 11.sp), maxLines = 1)
    Spacer(GlanceModifier.height(4.dp))
    Text(data.amount, style = TextStyle(color = ColorProvider(foreground), fontSize = size.sp, fontWeight = FontWeight.Bold), maxLines = 1)
}

/** Glance has no arbitrary chart canvas: charts are bitmap leaves, never a second UI. */
object WidgetGraphics {
    fun ring(usage: Float, dark: Boolean): Bitmap {
        val bitmap = Bitmap.createBitmap(192, 192, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = 16f; strokeCap = Paint.Cap.ROUND; color = if (dark) 0xFF30353D.toInt() else 0xFFE5E7EB.toInt() }
        canvas.drawCircle(96f, 96f, 78f, paint)
        paint.color = 0xFF346EDB.toInt()
        canvas.drawArc(18f, 18f, 174f, 174f, -90f, usage.coerceIn(0f, 1f) * 360f, false, paint)
        paint.style = Paint.Style.FILL; paint.color = if (dark) android.graphics.Color.WHITE else 0xFF111827.toInt()
        paint.textSize = 46f; paint.textAlign = Paint.Align.CENTER; paint.typeface = android.graphics.Typeface.DEFAULT_BOLD
        canvas.drawText("${(usage.coerceIn(0f, 1f) * 100).toInt()}%", 96f, 96f - (paint.ascent() + paint.descent()) / 2, paint)
        return bitmap
    }
    fun sparkline(points: List<Float>): Bitmap {
        val bitmap = Bitmap.createBitmap(720, 240, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        var low = points.minOrNull() ?: 0f
        var high = points.maxOrNull() ?: 1f
        if (high - low < .0001f) { low -= 1; high += 1 }
        val line = Path()
        points.forEachIndexed { i, value ->
            val x = i * 719f / (points.size - 1).coerceAtLeast(1)
            val y = 232f - (value - low) / (high - low) * 224f
            if (i == 0) line.moveTo(x, y) else line.lineTo(x, y)
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x20346EDB; style = Paint.Style.FILL }
        val fill = Path(line).apply { lineTo(720f, 240f); lineTo(0f, 240f); close() }
        canvas.drawPath(fill, paint)
        paint.color = 0xFF346EDB.toInt(); paint.style = Paint.Style.STROKE; paint.strokeWidth = 6f; paint.strokeJoin = Paint.Join.ROUND
        canvas.drawPath(line, paint)
        return bitmap
    }
}

fun widgetAction(context: Context, id: Int, route: String, bookId: String): Action =
    actionStartActivity<MainActivity>(context, Uri.Builder().scheme("verifin").authority("widget")
        .appendPath(id.toString()).appendPath(route).appendQueryParameter("bookId", bookId).build())

open class VeriFinGlanceWidget(val template: VeriFinWidgetTemplate) : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()
    override val sizeMode = SizeMode.Exact
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val widgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        provideContent {
            val preferences = currentState<HomeWidgetGlanceState>().preferences
            val data = VeriFinWidgetStore.display(context, template, VeriFinWidgetStore.config(preferences, widgetId), prefs = preferences)
            VeriFinWidgetContent(template, data, widgetAction(context, widgetId, "app", data.bookId),
                widgetAction(context, widgetId, "entry", data.bookId), widgetId)
        }
    }
    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent { VeriFinWidgetContent(template, VeriFinWidgetStore.display(context, template, WidgetInstanceSelection(), sample = true)) }
    }
}
class QuickEntryGlanceWidget : VeriFinGlanceWidget(VeriFinWidgetTemplate.QUICK_ENTRY)
class BudgetGlanceWidget : VeriFinGlanceWidget(VeriFinWidgetTemplate.BUDGET)
class NetWorthGlanceWidget : VeriFinGlanceWidget(VeriFinWidgetTemplate.NET_WORTH)
class TrendGlanceWidget : VeriFinGlanceWidget(VeriFinWidgetTemplate.TREND)

abstract class VeriFinWidgetReceiver<T : VeriFinGlanceWidget> : HomeWidgetGlanceWidgetReceiver<T>() {
    override fun previewFingerprint(context: Context): String =
        "verifin-glance-v3|${glanceAppWidget.template}|${context.resources.configuration.uiMode}|${VeriFinWidgetStore.prefs(context).getString("verifin.widget.locale", "")}|${VeriFinWidgetStore.prefs(context).getString("verifin.widget.theme", "system")}"
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val editor = VeriFinWidgetStore.prefs(context).edit()
        appWidgetIds.forEach { editor.remove(VeriFinWidgetStore.CONFIG_PREFIX + it) }
        editor.apply()
        super.onDeleted(context, appWidgetIds)
    }
}
class QuickEntryWidgetProvider : VeriFinWidgetReceiver<QuickEntryGlanceWidget>() { override val glanceAppWidget = QuickEntryGlanceWidget() }
class BudgetWidgetProvider : VeriFinWidgetReceiver<BudgetGlanceWidget>() { override val glanceAppWidget = BudgetGlanceWidget() }
class NetWorthWidgetProvider : VeriFinWidgetReceiver<NetWorthGlanceWidget>() { override val glanceAppWidget = NetWorthGlanceWidget() }
class TrendWidgetProvider : VeriFinWidgetReceiver<TrendGlanceWidget>() { override val glanceAppWidget = TrendGlanceWidget() }
