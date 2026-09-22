package top.talyra42.verifin

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Separate engine per edit session; no second ledger Controller or DB writer. */
class WidgetConfigurationActivity : FlutterActivity() {
    private var preview: WidgetPreviewBridge? = null
    override fun getDartEntrypointFunctionName(): String = "configureMain"
    override fun onCreate(savedInstanceState: Bundle?) {
        setResult(Activity.RESULT_CANCELED)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val info = AppWidgetManager.getInstance(this).getAppWidgetInfo(id)
        if (info == null || info.provider.packageName != packageName) { super.onCreate(savedInstanceState); finish(); return }
        super.onCreate(savedInstanceState)
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        preview = WidgetPreviewBridge(this)
        MethodChannel(engine.dartExecutor.binaryMessenger, "verifin/app").setMethodCallHandler { call, result -> preview!!.handle(call, result) }
    }
    override fun onDestroy() { preview?.close(); super.onDestroy() }
}
