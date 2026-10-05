package com.chandra.agecalculator.widget

import java.util.Calendar
import java.util.TimeZone

/** Display countdown only. Matches Dart `countdownLabel` / row wording. */
object WidgetCountdown {
    data class Label(val full: String?, val row: String?)

    fun of(occurrence: WidgetOccurrence, nowMillis: Long, timeZone: TimeZone): Label {
        return if (occurrence.time == null) {
            allDay(occurrence.date, nowMillis, timeZone)
        } else {
            timed(occurrence, nowMillis, timeZone)
        }
    }

    fun startMillis(occurrence: WidgetOccurrence, timeZone: TimeZone): Long? {
        val time = occurrence.time ?: return null
        val cal = Calendar.getInstance(timeZone)
        cal.clear()
        cal.set(occurrence.date.year, occurrence.date.month - 1, occurrence.date.day, time.hour, time.minute, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    fun ceilMinutes(startMillis: Long, nowMillis: Long): Int {
        val remaining = startMillis - nowMillis
        return if (remaining > 0) {
            ((remaining + 59_999L) / 60_000L).toInt()
        } else {
            (remaining / 60_000L).toInt()
        }
    }

    private fun allDay(date: CivilDate, nowMillis: Long, timeZone: TimeZone): Label {
        val today = CivilDate.of(nowMillis, timeZone)
        val days = today.daysUntil(date)
        if (days < 0) return Label(null, null)
        val full = when (days) {
            0 -> "Today"
            1 -> "Tomorrow"
            else -> "$days days left"
        }
        val row = when (days) {
            0 -> "Today"
            1 -> "Tomorrow"
            else -> "$days days"
        }
        return Label(full, row)
    }

    private fun timed(occurrence: WidgetOccurrence, nowMillis: Long, timeZone: TimeZone): Label {
        val start = startMillis(occurrence, timeZone) ?: return Label(null, null)
        val minutes = ceilMinutes(start, nowMillis)
        if (minutes < 0) return Label(null, null)
        if (minutes == 0) return Label("Now", "Now")
        val units = twoLargestUnits(minutes)
        return Label("$units left", units)
    }

    private fun twoLargestUnits(minutes: Int): String {
        val minutesPerDay = 24 * 60
        val minutesPerHour = 60
        return when {
            minutes >= minutesPerDay -> {
                val days = minutes / minutesPerDay
                val hours = (minutes % minutesPerDay) / minutesPerHour
                if (hours == 0) plural(days, "day") else "${plural(days, "day")} ${plural(hours, "hour")}"
            }
            minutes >= minutesPerHour -> {
                val hours = minutes / minutesPerHour
                val mins = minutes % minutesPerHour
                if (mins == 0) plural(hours, "hour") else "${plural(hours, "hour")} ${plural(mins, "minute")}"
            }
            else -> plural(minutes, "minute")
        }
    }

    private fun plural(value: Int, unit: String): String =
        if (value == 1) "$value $unit" else "$value ${unit}s"
}
