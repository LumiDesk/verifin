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
}
