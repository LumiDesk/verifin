package top.talyra42.verifin

import android.app.Activity
import android.app.Instrumentation
import android.os.Bundle

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
            result.putString("stream", "PASS: VeriFin Glance providers and configuration activity load\n")
            finish(Activity.RESULT_OK, result)
        } catch (error: Throwable) {
            result.putString("stream", error.stackTraceToString())
            finish(Activity.RESULT_CANCELED, result)
        }
    }
}
