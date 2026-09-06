package top.talyra42.verifin

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
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
}
