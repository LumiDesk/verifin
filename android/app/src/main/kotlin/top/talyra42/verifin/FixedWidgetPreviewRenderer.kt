package top.talyra42.verifin

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.FrameLayout
import android.widget.RemoteViews
import java.io.ByteArrayOutputStream
import kotlin.math.roundToInt

/** Preview the very same RemoteViews that the providers send to the launcher.
 * No second layout, drawing implementation or design-specific screenshot lives in Flutter.
 */
object FixedWidgetPreviewRenderer {
    val templates = listOf("quick_entry", "budget", "net_worth", "trend")

    /** Android 15+ picker uses the same native views as the actual widget.
     * Publish only after a theme/locale/layout change to respect the API rate limit.
     * Sample values prevent ledger data from lingering in the launcher picker cache.
     */
    fun publishPickerPreviews(context: Context) {
        if (android.os.Build.VERSION.SDK_INT < 35) return
        val signature = "native-v2:${WidgetData.darkTheme(context)}:${WidgetData.read(context, WidgetData.KEY_LOCALE, "")}" 
        val classes = listOf(QuickEntryWidgetProvider::class.java, BudgetWidgetProvider::class.java,
            NetWorthWidgetProvider::class.java, TrendWidgetProvider::class.java)
        val manager = android.appwidget.AppWidgetManager.getInstance(context)
        for ((index, template) in templates.withIndex()) {
            val key = "picker_preview_$template"
            if (WidgetData.read(context, key, "") == signature) continue
            try {
                val published = manager.setWidgetPreview(android.content.ComponentName(context, classes[index]),
                    android.appwidget.AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN, views(context, template, true))
                if (published) WidgetData.write(context, mapOf(key to signature))
            } catch (error: Exception) {
                // Static provider-exported PNG remains available on unsupported launchers.
                android.util.Log.w("VeriFinWidgets", "Generated picker preview unavailable", error)
            }
        }
    }

    fun views(context: Context, template: String, sample: Boolean = false): RemoteViews = when (template) {
        "quick_entry" -> QuickEntryWidgetProvider.createViews(context, 0, sample)
        "budget" -> BudgetWidgetProvider().createViews(context, 0, sample)
        "net_worth" -> NetWorthWidgetProvider().createViews(context, 0, sample)
        "trend" -> TrendWidgetProvider().createViews(context, 0, sample)
        else -> throw IllegalArgumentException("Unknown fixed widget template")
    }

    fun bitmap(context: Context, template: String, widthDp: Int, heightDp: Int, sample: Boolean = false): Bitmap {
        require(widthDp in 100..600 && heightDp in 56..400)
        val density = context.resources.displayMetrics.density
        val width = (widthDp * density).roundToInt()
        val height = (heightDp * density).roundToInt()
        val view = views(context, template, sample).apply(context, FrameLayout(context))
        view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
        view.layout(0, 0, width, height)
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { view.draw(Canvas(it)) }
    }

    fun png(context: Context, template: String, widthDp: Int, heightDp: Int, sample: Boolean = false): ByteArray {
        val bitmap = bitmap(context, template, widthDp, heightDp, sample)
        return ByteArrayOutputStream().use { output ->
            try { bitmap.compress(Bitmap.CompressFormat.PNG, 100, output); output.toByteArray() }
            finally { bitmap.recycle() }
        }
    }
}
