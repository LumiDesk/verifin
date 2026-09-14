package top.talyra42.verifin

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.content.res.Configuration
import android.app.Instrumentation
import android.app.Activity
import android.os.Bundle
import java.io.File

/** Real Android RemoteViews inflation, independent of Flutter widget-test stubs.
 * The context redirects all preferences to a test-only file; ledger and widget
 * preferences already on the device are never modified by these checks.
 */
class FixedWidgetRenderingTest : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }
    override fun onStart() {
        val result = Bundle()
        try {
            testEveryProviderInflatesAndExportsItsActualLayout()
            result.putString("stream", "PASS: all four provider layouts rendered in both themes and languages\n")
            finish(Activity.RESULT_OK, result)
        } catch (error: Throwable) {
            result.putString("stream", error.stackTraceToString())
            finish(Activity.RESULT_CANCELED, result)
        }
    }
    private class TestContext(base: Context) : ContextWrapper(base) {
        override fun getSharedPreferences(name: String, mode: Int): SharedPreferences =
            baseContext.getSharedPreferences("widget-rendering-test", mode)
        override fun createConfigurationContext(config: Configuration): Context =
            TestContext(baseContext.createConfigurationContext(config))
    }

    fun testEveryProviderInflatesAndExportsItsActualLayout() {
        val context = TestContext(targetContext)
        val output = File(context.filesDir, "widget-rendering-test").apply { mkdirs() }
        WidgetData.write(context, mapOf(
            WidgetData.KEY_TODAY_DATE to WidgetData.currentDate(),
            WidgetData.KEY_TODAY_AMOUNT to "37",
            WidgetData.KEY_BUDGET_AMOUNT to "720",
            WidgetData.KEY_BUDGET_USAGE to "0.28",
            WidgetData.KEY_NET_WORTH_AMOUNT to "963",
            WidgetData.KEY_NET_WORTH_POINTS to "1000,1000,970,980,963",
            WidgetData.KEY_TREND_AMOUNT to "280",
            WidgetData.KEY_TREND_POINTS to "10,20,5,30,37",
        ))
        runOnMainSync {
            for (locale in listOf("zh", "en")) {
                for (dark in listOf(true, false)) {
                    WidgetData.write(context, mapOf(WidgetData.KEY_LOCALE to locale, WidgetData.KEY_DARK_THEME to dark.toString()))
                    for (template in FixedWidgetPreviewRenderer.templates) {
                        val width = if (template == "trend") 352 else 168
                        val height = if (template == "quick_entry") 72 else 168
                        val bitmap = FixedWidgetPreviewRenderer.bitmap(context, template, width, height)
                        check((width * context.resources.displayMetrics.density).toInt() == bitmap.width)
                        check((height * context.resources.displayMetrics.density).toInt() == bitmap.height)
                        bitmap.recycle()
                        val inflated = FixedWidgetPreviewRenderer.views(context, template)
                            .apply(context, android.widget.FrameLayout(context))
                        check(inflated.findViewById<android.view.View>(android.R.id.background).clipToOutline)
                        File(output, "${locale}_${dark}_${template}.png").writeBytes(
                            FixedWidgetPreviewRenderer.png(context, template, width, height))
                        // Picker fallback assets are exported from the provider itself,
                        // using neutral sample data, never device ledger data.
                        File(output, "preview_${locale}_${dark}_${template}.png").writeBytes(
                            FixedWidgetPreviewRenderer.png(context, template, width, height, true))
                    }
                }
            }
            val largeText = Configuration(context.resources.configuration).apply { fontScale = 1.5f }
            val narrow = context.createConfigurationContext(largeText)
            WidgetData.write(narrow, mapOf(WidgetData.KEY_DARK_THEME to "true", WidgetData.KEY_LOCALE to "zh"))
            for (template in FixedWidgetPreviewRenderer.templates) {
                val width = if (template == "trend") 308 else 148
                val height = if (template == "quick_entry") 72 else 148
                File(output, "narrow_large_text_$template.png").writeBytes(
                    FixedWidgetPreviewRenderer.png(narrow, template, width, height))
            }
        }
    }
}
