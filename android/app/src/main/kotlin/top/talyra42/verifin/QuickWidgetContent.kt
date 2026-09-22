package top.talyra42.verifin

import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/** Native TextView auto-size inside the Glance composition; no parallel provider.
 * The drawable contains the rounded pixels, so software-rendered previews and
 * Android <31 do not depend on RenderNode outline clipping. */
object QuickWidgetContent {
    fun uri(id: Int, route: String, bookId: String): Uri = Uri.Builder()
        .scheme("verifin").authority("widget").appendPath(id.toString()).appendPath(route)
        .appendQueryParameter("bookId", bookId).build()

    fun views(context: Context, data: WidgetDisplay, widgetId: Int? = null): RemoteViews {
        val localized = VeriFinWidgetStore.localized(context, VeriFinWidgetStore.prefs(context))
        return RemoteViews(context.packageName, R.layout.quick_widget_content).apply {
            setInt(R.id.quick_widget_card, "setBackgroundResource",
                if (data.dark) R.drawable.widget_surface_dark else R.drawable.widget_surface_light)
            setTextViewText(R.id.quick_widget_label, data.label)
            setTextViewText(R.id.quick_widget_amount, data.amount)
            setTextColor(R.id.quick_widget_label, if (data.dark) 0xFFB8C0CC.toInt() else 0xFF6B7280.toInt())
            setTextColor(R.id.quick_widget_amount, if (data.dark) 0xFFF5F5F7.toInt() else 0xFF111827.toInt())
            setContentDescription(R.id.quick_widget_add, localized.getString(R.string.quick_entry_button))
            if (widgetId != null) {
                val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri(widgetId, "app", data.bookId))
                val entry = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri(widgetId, "entry", data.bookId))
                // Explicit siblings: no inherited Glance click target can turn
                // the whole weighted data column into the add button.
                listOf(R.id.quick_widget_card, R.id.quick_widget_data, R.id.quick_widget_label, R.id.quick_widget_amount)
                    .forEach { setOnClickPendingIntent(it, open) }
                setOnClickPendingIntent(R.id.quick_widget_add, entry)
            }
        }
    }
}
