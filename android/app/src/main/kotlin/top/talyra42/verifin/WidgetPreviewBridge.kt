package top.talyra42.verifin

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.FrameLayout
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.appwidget.ExperimentalGlanceRemoteViewsApi
import androidx.glance.appwidget.GlanceRemoteViews
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import kotlin.math.roundToInt

/** Preview-only adapter. It never stores a draft or renders a separate Flutter UI. */
class WidgetPreviewBridge(private val context: Context) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    fun close() = scope.cancel()
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                when (call.method) {
                    "refreshWidgetInstance" -> {
                        val id = requireNotNull(call.argument<Int>("widgetId"))
                        val manager = AppWidgetManager.getInstance(context)
                        val info = requireNotNull(manager.getAppWidgetInfo(id))
                        require(info.provider.packageName == context.packageName)
                        val template = VeriFinWidgetTemplate.fromProvider(info.provider.className)
                        val options = manager.getAppWidgetOptions(id)
                        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 168).coerceIn(100, 600)
                        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 168).coerceIn(56, 400)
                        val selection = VeriFinWidgetStore.config(VeriFinWidgetStore.prefs(context), id)
                        val views = WidgetPreviewRenderer.views(context, template, width, height, selection, widgetId = id)
                        manager.updateAppWidget(id, views)
                        result.success(null)
                    }
                    "widgetConfigurationInfo" -> {
                        val id = requireNotNull(call.argument<Int>("widgetId"))
                        val info = requireNotNull(AppWidgetManager.getInstance(context).getAppWidgetInfo(id))
                        require(info.provider.packageName == context.packageName)
                        val template = VeriFinWidgetTemplate.fromProvider(info.provider.className)
                        result.success(mapOf("template" to template.key, "provider" to info.provider.className, "metric" to template.metric))
                    }
                    "renderWidgetPreview" -> result.success(WidgetPreviewRenderer.png(context,
                        VeriFinWidgetTemplate.fromKey(requireNotNull(call.argument<String>("template"))),
                        call.argument<Int>("widthDp") ?: 168, call.argument<Int>("heightDp") ?: 168,
                        WidgetInstanceSelection(call.argument<String>("bookId").orEmpty(), call.argument<String>("metric").orEmpty()),
                        call.argument<Boolean>("sample") ?: false))
                    else -> result.notImplemented()
                }
            } catch (error: CancellationException) {
                result.error("WIDGET_PREVIEW_CANCELLED", "Widget activity closed", null)
                throw error
            } catch (error: Exception) {
                android.util.Log.e("VeriFinWidgets", "Widget preview/configuration unavailable", error)
                result.error("WIDGET_PREVIEW_FAILED", "Widget preview/configuration unavailable", null)
            }
        }
    }
}

object WidgetPreviewRenderer {
    @OptIn(ExperimentalGlanceRemoteViewsApi::class)
    suspend fun views(context: Context, template: VeriFinWidgetTemplate, width: Int, height: Int,
                      selection: WidgetInstanceSelection = WidgetInstanceSelection(), sample: Boolean = false,
                      widgetId: Int? = null): android.widget.RemoteViews {
        require(width in 100..600 && height in 56..400)
        val data = VeriFinWidgetStore.display(context, template, selection, sample)
        return GlanceRemoteViews().compose(context, DpSize(width.dp, height.dp)) {
            VeriFinWidgetContent(template, data,
                widgetId?.let { widgetAction(context, it, "app", data.bookId) },
                widgetId?.let { widgetAction(context, it, "entry", data.bookId) }, widgetId)
        }.remoteViews
    }
    suspend fun png(context: Context, template: VeriFinWidgetTemplate, width: Int, height: Int,
                    selection: WidgetInstanceSelection = WidgetInstanceSelection(), sample: Boolean = false): ByteArray {
        val remote = views(context, template, width, height, selection, sample)
        return withContext(Dispatchers.Main) {
            val density = context.resources.displayMetrics.density
            val w = (width * density).roundToInt()
            val h = (height * density).roundToInt()
            val view = remote.apply(context, FrameLayout(context))
            view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
            view.layout(0, 0, w, h)
            val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            try {
                view.draw(Canvas(bitmap))
                ByteArrayOutputStream().use { output -> bitmap.compress(Bitmap.CompressFormat.PNG, 100, output); output.toByteArray() }
            } finally { bitmap.recycle() }
        }
    }
}
