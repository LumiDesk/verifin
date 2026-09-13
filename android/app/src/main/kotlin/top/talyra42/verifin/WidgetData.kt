package top.talyra42.verifin

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import org.json.JSONObject
import java.util.Calendar

/// 桌面小组件的共享数据与刷新工具。
///
/// 三个小组件（今日支出 / 本月预算 / 资产总额）都从同一份 SharedPreferences 读取各自
/// 的字段；Flutter 侧经 MethodChannel `updateWidgetData` 一次写入全部字段（见
/// [MainActivity]），随后广播刷新各 Provider。字段值均为已格式化好的字符串。
object WidgetData {
    const val PREFS_NAME = "verifin_widget"

    // 今日支出小组件（沿用旧键名，避免历史数据失效）。
    const val KEY_TODAY_AMOUNT = "today_expense"
    const val KEY_TODAY_LABEL = "today_label"
    const val KEY_QUICK_ENTRY_LABEL = "quick_entry_label"

    // 本月预算小组件（展示本月可用/超支金额）。
    const val KEY_BUDGET_AMOUNT = "month_budget"
    const val KEY_BUDGET_LABEL = "month_budget_label"

    // 资产总额小组件。
    const val KEY_NET_WORTH_AMOUNT = "net_worth"
    const val KEY_NET_WORTH_LABEL = "net_worth_label"

    // 趋势小组件（可选，由 Flutter 推送聚合后的 sparkline 点位）。
    const val KEY_TREND_AMOUNT = "trend_amount"
    const val KEY_TREND_LABEL = "trend_label"
    const val KEY_TREND_POINTS = "trend_points"
    const val KEY_TREND_RANGE_LABEL = "trend_range_label"

    /** Per-instance configuration is kept separately so multiple widgets can target
     * different books, metrics or date ranges without changing the global snapshot. */
    private const val INSTANCE_CONFIG_PREFIX = "instance_config_"
    private const val DEFINITIONS_KEY = "user_widget_definitions"
    private const val INSTANCE_DEFINITION_PREFIX = "user_widget_definition_"
    private const val WIDGET_BOOKS_KEY = "widget_books"
    private const val WIDGET_SNAPSHOTS_KEY = "widget_snapshots"

    /** A saved design owned by the user. Kept as JSON so Flutter can evolve the schema. */
    data class UserDefinition(
        val id: String,
        val name: String = "我的小组件",
        val template: String = "overview",
        val primaryMetric: String = "today_expense",
        val secondaryMetrics: List<String> = emptyList(),
        val chartMetric: String = "",
        val chartDays: Int = 30,
        val bookId: String = "",
        val action: String = "app",
        val backgroundColor: Int = 0xFF1E293B.toInt(),
        val backgroundPath: String = "",
        val hideAmounts: Boolean = false,
        val presentationJson: String = "",
        val size: String = "twoByTwo",
    )

    fun readDefinition(context: Context, id: String): UserDefinition? {
        if (id.isBlank()) return null
        val raw = read(context, "${DEFINITIONS_KEY}_$id", "")
        if (raw.isBlank()) return null
        return try {
            val json = JSONObject(raw)
            val secondary = json.optJSONArray("secondaryMetrics")
                ?.let { array -> (0 until array.length()).map { array.optString(it) } }
                ?: emptyList()
            UserDefinition(
                id = json.optString("id", id),
                name = json.optString("name", "我的小组件"),
                template = json.optString("template", "overview"),
                primaryMetric = json.optString("primaryMetric", "today_expense"),
                secondaryMetrics = secondary,
                chartMetric = json.optString("chartMetric", ""),
                chartDays = json.optInt("chartDays", 30).coerceIn(7, 365),
                bookId = json.optString("bookId", ""),
                action = json.optString("action", "app"),
                backgroundColor = json.optInt("backgroundColor", 0xFF1E293B.toInt()),
                backgroundPath = json.optString("backgroundPath", ""),
                hideAmounts = json.optBoolean("hideAmounts", false),
                presentationJson = json.optString("presentationJson", ""),
                size = json.optString("size", "twoByTwo"),
            )
        } catch (_: Exception) { null }
    }

    fun writeDefinition(context: Context, definition: UserDefinition) {
        val json = JSONObject().apply {
            put("id", definition.id)
            put("name", definition.name)
            put("template", definition.template)
            put("primaryMetric", definition.primaryMetric)
            put("secondaryMetrics", org.json.JSONArray(definition.secondaryMetrics))
            put("chartMetric", definition.chartMetric)
            put("chartDays", definition.chartDays)
            put("bookId", definition.bookId)
            put("action", definition.action)
            put("backgroundColor", definition.backgroundColor)
            put("backgroundPath", definition.backgroundPath)
            put("hideAmounts", definition.hideAmounts)
            put("presentationJson", definition.presentationJson)
            put("size", definition.size)
        }
        write(context, mapOf("${DEFINITIONS_KEY}_${definition.id}" to json.toString()))
        val ids = readDefinitionIds(context).toMutableSet().apply { add(definition.id) }
        write(context, mapOf(DEFINITIONS_KEY to ids.joinToString("\n")))
    }

    fun readDefinitionIds(context: Context): List<String> = read(context, DEFINITIONS_KEY, "")
        .split('\n').map { it.trim() }.filter { it.isNotBlank() }

    fun deleteDefinition(context: Context, id: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .remove("${DEFINITIONS_KEY}_$id").putString(
                DEFINITIONS_KEY,
                readDefinitionIds(context).filterNot { it == id }.joinToString("\n"),
            ).apply()
    }

    fun removeDefinitionsNotIn(context: Context, keep: List<String>) {
        val keepSet = keep.toSet()
        readDefinitionIds(context).filterNot(keepSet::contains).forEach { id ->
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().remove("${DEFINITIONS_KEY}_$id").apply()
        }
        write(context, mapOf(DEFINITIONS_KEY to keep.joinToString("\n")))
    }

    fun readDefinitionId(context: Context, widgetId: Int): String =
        read(context, "$INSTANCE_DEFINITION_PREFIX$widgetId", "")

    fun bindDefinition(context: Context, widgetId: Int, definitionId: String) {
        write(context, mapOf("$INSTANCE_DEFINITION_PREFIX$widgetId" to definitionId))
    }

    fun clearDefinitionBinding(context: Context, widgetId: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .remove("$INSTANCE_DEFINITION_PREFIX$widgetId").apply()
    }

    data class InstanceConfig(
        val template: String = "default",
        val bookId: String = "",
        val primaryMetric: String = "",
        val secondaryMetric: String = "",
        val chartMetric: String = "",
        val chartDays: Int = 30,
        val action: String = "app",
        val hideAmounts: Boolean = false,
        val backgroundColor: Int = 0xFF1E293B.toInt(),
    )

    fun readInstanceConfig(context: Context, widgetId: Int): InstanceConfig {
        val raw = read(context, instanceConfigKey(widgetId), "")
        if (raw.isBlank()) return InstanceConfig()
        return try {
            val json = JSONObject(raw)
            InstanceConfig(
                template = json.optString("template", "default"),
                bookId = json.optString("bookId", ""),
                primaryMetric = json.optString("primaryMetric", ""),
                secondaryMetric = json.optString("secondaryMetric", ""),
                chartMetric = json.optString("chartMetric", ""),
                chartDays = json.optInt("chartDays", 30).coerceIn(7, 365),
                action = json.optString("action", "app"),
                hideAmounts = json.optBoolean("hideAmounts", false),
                backgroundColor = json.optInt("backgroundColor", 0xFF1E293B.toInt()),
            )
        } catch (_: Exception) {
            InstanceConfig()
        }
    }

    /** Accepts string values from the Flutter bridge; unknown fields are ignored. */
    fun writeInstanceConfig(context: Context, widgetId: Int, values: Map<String, String>) {
        val current = readInstanceConfig(context, widgetId)
        val json = JSONObject().apply {
            put("template", values["template"] ?: current.template)
            put("bookId", values["bookId"] ?: current.bookId)
            put("primaryMetric", values["primaryMetric"] ?: current.primaryMetric)
            put("secondaryMetric", values["secondaryMetric"] ?: current.secondaryMetric)
            put("chartMetric", values["chartMetric"] ?: current.chartMetric)
            put("chartDays", values["chartDays"]?.toIntOrNull() ?: current.chartDays)
            put("action", values["action"] ?: current.action)
            put("hideAmounts", values["hideAmounts"]?.toBoolean() ?: current.hideAmounts)
            val colorText = values["backgroundColor"]?.removePrefix("#")
            val colorValue = colorText?.toLongOrNull(16)?.let {
                when (colorText.length) {
                    6 -> (0xFF000000L or it).toInt()
                    8 -> it.toInt()
                    else -> null
                }
            }
            put("backgroundColor", colorValue ?: current.backgroundColor)
        }
        write(context, mapOf(instanceConfigKey(widgetId) to json.toString()))
    }

    fun clearInstanceConfig(context: Context, widgetId: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .remove(instanceConfigKey(widgetId))
            .remove("$INSTANCE_DEFINITION_PREFIX$widgetId").apply()
    }

    private fun instanceConfigKey(widgetId: Int) = "$INSTANCE_CONFIG_PREFIX$widgetId"

    fun writeWidgetBooks(context: Context, books: List<Pair<String, String>>) {
        val json = org.json.JSONArray().apply {
            books.forEach { (id, name) ->
                put(JSONObject().apply { put("id", id); put("name", name) })
            }
        }
        write(context, mapOf(WIDGET_BOOKS_KEY to json.toString()))
    }

    fun readWidgetBooks(context: Context): List<Pair<String, String>> {
        val raw = read(context, WIDGET_BOOKS_KEY, "")
        if (raw.isBlank()) return emptyList()
        return runCatching {
            val json = org.json.JSONArray(raw)
            (0 until json.length()).mapNotNull { index ->
                val item = json.optJSONObject(index) ?: return@mapNotNull null
                val id = item.optString("id").takeIf { it.isNotBlank() } ?: return@mapNotNull null
                id to item.optString("name", id)
            }
        }.getOrDefault(emptyList())
    }

    fun backgroundResource(color: Int): Int = when (color) {
        0xFF111827.toInt() -> R.drawable.widget_background_ink
        0xFFFFFFFF.toInt() -> R.drawable.widget_background_white
        0xFF312E81.toInt() -> R.drawable.widget_background_indigo
        0xFF0F3D3E.toInt() -> R.drawable.widget_background_teal
        else -> R.drawable.widget_background_navy
    }

    fun writeWidgetSnapshots(context: Context, json: String) {
        write(context, mapOf(WIDGET_SNAPSHOTS_KEY to json))
    }

    fun snapshotMetric(
        context: Context,
        bookId: String,
        metric: String,
        fallbackAmount: String,
        fallbackLabel: String,
    ): Pair<String, String> {
        if (bookId.isBlank()) return fallbackAmount to fallbackLabel
        return runCatching {
            val books = JSONObject(read(context, WIDGET_SNAPSHOTS_KEY, "{}"))
            val values = books.optJSONObject(bookId)?.optJSONObject(metric) ?: return@runCatching fallbackAmount to fallbackLabel
            values.optString("amount", fallbackAmount) to values.optString("label", fallbackLabel)
        }.getOrDefault(fallbackAmount to fallbackLabel)
    }

    fun snapshotPoints(context: Context, bookId: String): List<Float> = runCatching {
        val books = JSONObject(read(context, WIDGET_SNAPSHOTS_KEY, "{}"))
        val metric = books.optJSONObject(bookId)?.optJSONObject("periodExpense")
        metric?.optString("points", "").orEmpty().split(',').mapNotNull { it.toFloatOrNull() }
    }.getOrDefault(emptyList())

    /** Resolve a metric from the global Flutter snapshot. This keeps native rendering
     * deterministic while allowing new metrics to be added without changing providers. */
    fun metric(context: Context, metric: String, fallbackAmount: String, fallbackLabel: String, bookId: String = ""): Pair<String, String> {
        if (bookId.isNotBlank()) return snapshotMetric(context, bookId, metric, fallbackAmount, fallbackLabel)
        val normalized = metric.trim().lowercase()
        return when (normalized) {
            "today", "today_expense", "daily_expense" -> todayForToday(context)
            "budget", "budget_remaining", "month_budget" -> budgetForMonth(context)
            "net_worth", "assets", "asset_total" -> read(context, KEY_NET_WORTH_AMOUNT, fallbackAmount) to
                read(context, KEY_NET_WORTH_LABEL, fallbackLabel)
            "trend", "trend_amount", "spending" -> read(context, KEY_TREND_AMOUNT, fallbackAmount) to
                read(context, KEY_TREND_LABEL, fallbackLabel)
            else -> fallbackAmount to fallbackLabel
        }
    }

    fun trendPoints(context: Context): List<Float> = read(context, KEY_TREND_POINTS, "")
        .split(',').mapNotNull { it.trim().toFloatOrNull() }.take(120)

    // ── 跨天/跨期自愈锚点（Flutter 每次推送时写入）──────────────────────
    // 今日支出所对应的日期（yyyy-MM-dd）；若与当前日期不同，说明已跨天，展示归零值。
    const val KEY_TODAY_DATE = "today_date"
    const val KEY_TODAY_ZERO = "today_zero"
    const val KEY_TODAY_STALE_AMOUNT = "today_stale_amount"
    const val KEY_TODAY_STALE_LABEL = "today_stale_label"
    // 预算所属周期的截止日（yyyy-MM-dd，含当天）；过期后展示整期预算（新周期尚无支出）。
    // 支持应用内自定义预算周期起始日，截止日不再一定是自然月末。
    const val KEY_BUDGET_EXPIRY = "month_budget_expiry"
    // 旧锚点（yyyy-MM，v1.10.32 及之前写入）：仅在新锚点缺失时兜底按月判断，
    // 覆盖「已更新 App 但尚未打开、推送过一次旧数据」的过渡窗口。
    const val KEY_BUDGET_MONTH = "month_budget_month"
    const val KEY_BUDGET_FULL = "month_budget_full"
    const val KEY_BUDGET_FULL_LABEL = "month_budget_full_label"
    const val KEY_BUDGET_NEXT_EXPIRY = "month_budget_next_expiry"
    const val KEY_BUDGET_NEXT_AMOUNT = "month_budget_next_amount"
    const val KEY_BUDGET_NEXT_LABEL = "month_budget_next_label"
    const val KEY_BUDGET_STALE_LABEL = "month_budget_stale_label"

    /// 当前本地日期 yyyy-MM-dd。
    fun currentDate(): String {
        val c = Calendar.getInstance()
        return "%04d-%02d-%02d".format(
            c.get(Calendar.YEAR),
            c.get(Calendar.MONTH) + 1,
            c.get(Calendar.DAY_OF_MONTH),
        )
    }

    /// 当前本地月份 yyyy-MM。
    fun currentMonth(): String {
        val c = Calendar.getInstance()
        return "%04d-%02d".format(c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1)
    }

    /// 今日支出的展示值：推送日期即当天则用原值，已跨天则用归零值（新的一天尚无支出）。
    fun todayForToday(context: Context): Pair<String, String> {
        val stamp = read(context, KEY_TODAY_DATE, "")
        val amount = read(context, KEY_TODAY_AMOUNT, "0")
        if (stamp.isEmpty() || stamp == currentDate()) {
            return amount to read(
                context,
                KEY_TODAY_LABEL,
                context.getString(R.string.widget_today_expense),
            )
        }
        return read(context, KEY_TODAY_STALE_AMOUNT, "—") to
            read(
                context,
                KEY_TODAY_STALE_LABEL,
                context.getString(R.string.widget_refresh_required),
            )
    }

    /// 可用预算的展示值 / 标签：过了周期截止日后回到整期预算与「可用」文案。
    fun budgetForMonth(context: Context): Pair<String, String> {
        val amount = read(context, KEY_BUDGET_AMOUNT, "0")
        val label = read(
            context,
            KEY_BUDGET_LABEL,
            context.getString(R.string.widget_budget_available),
        )
        val expiry = read(context, KEY_BUDGET_EXPIRY, "")
        if (expiry.isNotEmpty()) {
            // ISO 日期字符串可直接字典序比较：今天 <= 截止日则周期内。
            if (currentDate() <= expiry) {
                return amount to label
            }
            val nextExpiry = read(context, KEY_BUDGET_NEXT_EXPIRY, "")
            if (nextExpiry.isNotEmpty() && currentDate() <= nextExpiry) {
                return read(context, KEY_BUDGET_NEXT_AMOUNT, amount) to
                    read(context, KEY_BUDGET_NEXT_LABEL, label)
            }
            if (nextExpiry.isNotEmpty()) {
                return "—" to read(
                    context,
                    KEY_BUDGET_STALE_LABEL,
                    context.getString(R.string.widget_refresh_required),
                )
            }
            return read(context, KEY_BUDGET_FULL, amount) to
                read(context, KEY_BUDGET_FULL_LABEL, label)
        }
        // 旧锚点兜底（更新 App 后尚未打开过的过渡窗口）：按自然月判断。
        val stamp = read(context, KEY_BUDGET_MONTH, "")
        if (stamp.isEmpty() || stamp == currentMonth()) {
            return amount to label
        }
        return read(context, KEY_BUDGET_FULL, amount) to
            read(context, KEY_BUDGET_FULL_LABEL, label)
    }

    /// 批量写入字段（只写传入的键，缺省键保持原值）。
    fun write(context: Context, values: Map<String, String>) {
        val editor = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
        values.forEach { (key, value) -> editor.putString(key, value) }
        editor.apply()
    }

    fun read(context: Context, key: String, fallback: String): String {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(key, fallback) ?: fallback
    }

    /// 广播 APPWIDGET_UPDATE，触发指定 Provider 已放置实例的 onUpdate 重绘。
    fun refresh(context: Context, provider: Class<out android.appwidget.AppWidgetProvider>) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        if (ids.isEmpty()) {
            return
        }
        val intent = Intent(context, provider).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        context.sendBroadcast(intent)
    }

    fun refreshAll(context: Context) {
        refresh(context, QuickEntryWidgetProvider::class.java)
        refresh(context, BudgetWidgetProvider::class.java)
        refresh(context, NetWorthWidgetProvider::class.java)
        refresh(context, TrendWidgetProvider::class.java)
    }
}
