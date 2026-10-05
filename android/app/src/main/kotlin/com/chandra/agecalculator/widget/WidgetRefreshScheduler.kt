package com.chandra.agecalculator.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.util.Calendar
import java.util.TimeZone

object WidgetRefreshScheduler {
    const val ACTION_REFRESH = "com.chandra.agecalculator.widget.REFRESH"
    private const val REQUEST = 1
    private const val HOUR_MS = 60 * 60 * 1000L

    fun schedule(context: Context, nowMillis: Long = System.currentTimeMillis(), timeZone: TimeZone = TimeZone.getDefault()) {
        val snapshot = WidgetSnapshotStore.load(context)
        val trigger = nextTriggerMillis(snapshot, nowMillis, timeZone)
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.set(AlarmManager.RTC, trigger, pending(context))
    }

    fun cancel(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(context))
    }

    fun nextTriggerMillis(
        snapshot: WidgetSnapshot?,
        nowMillis: Long,
        timeZone: TimeZone,
    ): Long {
        val backstop = nowMillis + HOUR_MS
        var next = nextMidnight(nowMillis, timeZone)
        val remaining = WidgetContent.remainingOccurrences(snapshot, nowMillis, timeZone)
        for (occurrence in remaining.take(8)) {
            val time = occurrence.time
            if (time == null) continue
            val start = WidgetCountdown.startMillis(occurrence, timeZone) ?: continue
            val minutes = WidgetCountdown.ceilMinutes(start, nowMillis)
            when {
                minutes < 0 -> continue
                minutes == 0 -> next = minOf(next, start + 60_000L)
                minutes < 24 * 60 -> next = minOf(next, nextMinute(nowMillis))
                else -> next = minOf(next, nextHour(nowMillis))
            }
        }
        if (snapshot != null) {
            val staleAt = startOfDay(snapshot.validThrough.addDays(1), timeZone)
            if (staleAt > nowMillis) next = minOf(next, staleAt)
        }
        if (next <= nowMillis) next = backstop
        return minOf(next, backstop)
    }

    private fun pending(context: Context): PendingIntent {
        val intent = Intent(context, UpcomingWidgetProvider::class.java).setAction(ACTION_REFRESH)
        return PendingIntent.getBroadcast(
            context,
            REQUEST,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun nextMidnight(nowMillis: Long, timeZone: TimeZone): Long {
        val cal = Calendar.getInstance(timeZone)
        cal.timeInMillis = nowMillis
        cal.add(Calendar.DAY_OF_MONTH, 1)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun startOfDay(date: CivilDate, timeZone: TimeZone): Long {
        val cal = Calendar.getInstance(timeZone)
        cal.clear()
        cal.set(date.year, date.month - 1, date.day, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun nextMinute(nowMillis: Long): Long = (nowMillis / 60_000L + 1) * 60_000L

    private fun nextHour(nowMillis: Long): Long = (nowMillis / 3_600_000L + 1) * 3_600_000L
}
