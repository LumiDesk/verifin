package top.talyra42.verifin

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/// 桌面小组件的「午夜刷新」调度与接收。
///
/// 小组件展示的是 Flutter 推送的字符串，其中「今日支出」「本月可用预算」是随时间过期的
/// （跨天 / 跨月后旧值不再正确）。为了让用户在不打开应用时看到的也是对的，这里在**下一个
/// 本地午夜**安排一次刷新广播：触发时重绘全部三个小组件（重绘逻辑会读锚点日期/月份并自愈），
/// 并顺手安排下一晚的刷新，形成每日一次的低功耗节律。
///
/// **必须用 [AlarmManager.setAndAllowWhileIdle] + [AlarmManager.RTC_WAKEUP]**：手机夜间静置会
/// 进入 Doze，普通 `set()` 排的闹钟会被压到下一个维护窗口（深度 Doze 下可延迟数小时），
/// 且 `RTC`（非唤醒）不会把设备唤醒——两者叠加会导致午夜闹钟整夜不触发，用户次日打开手机仍是
/// 旧数据（历史 bug）。`setAndAllowWhileIdle` 允许闹钟在 Doze 下按约每 9 分钟一次的配额触发
/// （每天一次的午夜刷新远低于此配额），配 `RTC_WAKEUP` 能主动唤醒设备。它**不需要**精确闹钟
/// 权限（`SCHEDULE_EXACT_ALARM`），午夜后一小段延迟内刷新即可；即便仍被推迟，小组件因任何原因
/// 重绘时也会依据锚点自愈。此外两个时间敏感小组件的 `updatePeriodMillis` 设为非 0，作为
/// 「设备活跃时（如次日点亮屏幕）」的第二条兜底触发。
object WidgetRefreshScheduler {
    private const val ACTION_MIDNIGHT_REFRESH =
        "top.talyra42.verifin.action.WIDGET_MIDNIGHT_REFRESH"
    private const val REQUEST_CODE = 0x5744 // 'W''D'

    fun scheduleNextMidnight(context: Context) {
        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

        // 下一个本地午夜 00:00:05（留 5 秒余量，确保跨过日界）。
        val next = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 5)
            set(Calendar.MILLISECOND, 0)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pending = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, WidgetRefreshReceiver::class.java).apply {
                action = ACTION_MIDNIGHT_REFRESH
            },
            flags,
        )
        // setAndAllowWhileIdle 穿透 Doze、RTC_WAKEUP 唤醒设备；均无需 SCHEDULE_EXACT_ALARM 权限。
        // minSdk >= 23，该 API 恒可用。
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            next.timeInMillis,
            pending,
        )
    }

    fun refreshAll(context: Context) {
        WidgetData.refresh(context, QuickEntryWidgetProvider::class.java)
        WidgetData.refresh(context, BudgetWidgetProvider::class.java)
        WidgetData.refresh(context, NetWorthWidgetProvider::class.java)
    }
}

/// 接收午夜刷新广播与开机 / 更新广播：刷新全部小组件并安排下一晚的刷新。
class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        WidgetRefreshScheduler.refreshAll(context)
        WidgetRefreshScheduler.scheduleNextMidnight(context)
    }
}
