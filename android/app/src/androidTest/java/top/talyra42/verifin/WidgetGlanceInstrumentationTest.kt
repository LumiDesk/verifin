package top.talyra42.verifin

import android.app.Activity
import android.app.Instrumentation
import android.os.Bundle
import java.io.File
import kotlinx.coroutines.runBlocking

/** Lightweight device-side smoke check for the home_widget/Glance providers. */
class WidgetGlanceInstrumentationTest : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val result = Bundle()
        try {
            testQuickWidget()
            listOf(
                QuickEntryWidgetProvider::class.java,
                BudgetWidgetProvider::class.java,
                NetWorthWidgetProvider::class.java,
                TrendWidgetProvider::class.java,
                WidgetConfigurationActivity::class.java,
            ).forEach { check(it.name.isNotBlank()) }
            val output = File(targetContext.filesDir, "widget-previews").apply { mkdirs() }
            val sizes = mapOf(
                VeriFinWidgetTemplate.QUICK_ENTRY to (220 to 72),
                VeriFinWidgetTemplate.BUDGET to (220 to 220),
                VeriFinWidgetTemplate.NET_WORTH to (220 to 220),
                VeriFinWidgetTemplate.TREND to (360 to 220),
            )
            sizes.forEach { (template, size) ->
                File(output, "${template.key}.png").writeBytes(
                    runBlocking {
                        WidgetPreviewRenderer.png(targetContext, template, size.first, size.second, sample = true)
                    },
                )
            }
            result.putString("stream", "PASS: VeriFin Glance providers and configuration activity load\n")
            finish(Activity.RESULT_OK, result)
        } catch (error: Throwable) {
            result.putString("stream", error.stackTraceToString())
            finish(Activity.RESULT_CANCELED, result)
        }
    }
    private fun testQuickWidget() {
        val output = File(targetContext.filesDir, "widget-previews").apply { mkdirs() }
        val data = WidgetDisplay("今日支出", "Today's spending / 今日累计支出", "CNY 123,456,789.99", dark = true)
        val density = targetContext.resources.displayMetrics.density
        runOnMainSync {
            for (width in listOf(148, 180, 220)) {
                val view = QuickWidgetContent.views(targetContext, data).apply(targetContext, android.widget.FrameLayout(targetContext))
                val w = (width * density).toInt()
                val h = (72 * density).toInt()
                view.measure(android.view.View.MeasureSpec.makeMeasureSpec(w, android.view.View.MeasureSpec.EXACTLY),
                    android.view.View.MeasureSpec.makeMeasureSpec(h, android.view.View.MeasureSpec.EXACTLY))
                view.layout(0, 0, w, h)
                for (id in listOf(R.id.quick_widget_label, R.id.quick_widget_amount)) {
                    val text = view.findViewById<android.widget.TextView>(id)
                    val layout = requireNotNull(text.layout)
                    check((0 until layout.lineCount).all { layout.getEllipsisCount(it) == 0 })
                    check(layout.getLineEnd(layout.lineCount - 1) == text.text.length) { "Lost text at width $width" }
                    check(layout.height <= text.height) { "Clipped text at width $width" }
                }
                val bitmap = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
                view.draw(android.graphics.Canvas(bitmap))
                File(output, "quick-long-$width.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
                val add = view.findViewById<android.widget.TextView>(R.id.quick_widget_add)
                val x = add.left + (4 * density).toInt()
                val y = add.top + (4 * density).toInt()
                check(bitmap.getPixel(x, y) != 0xFF346EDB.toInt()) { "Square button corner" }
                bitmap.recycle()
            }
        }
        val app = QuickWidgetContent.uri(41, "app", "book-a")
        val entry = QuickWidgetContent.uri(41, "entry", "book-a")
        check(app != entry && app.lastPathSegment == "app" && entry.lastPathSegment == "entry")
        val first = es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(targetContext, MainActivity::class.java, app)
        val second = es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(targetContext, MainActivity::class.java, entry)
        check(first != second) { "Data and plus PendingIntents collide" }
    }

}
