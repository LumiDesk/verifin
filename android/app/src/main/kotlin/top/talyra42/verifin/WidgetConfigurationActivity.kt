package top.talyra42.verifin

import io.flutter.embedding.android.FlutterActivity

/**
 * Dedicated Flutter entry point for the launcher-provided reconfigure action.
 * home_widget owns the AppWidget result contract; Dart calls
 * finishHomeWidgetConfigure after persisting the instance settings.
 */
class WidgetConfigurationActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName(): String = "configureMain"
}
