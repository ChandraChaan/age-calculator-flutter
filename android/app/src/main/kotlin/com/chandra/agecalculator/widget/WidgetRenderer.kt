package com.chandra.agecalculator.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import com.chandra.agecalculator.R
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

object WidgetRenderer {
    fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val snapshot = WidgetSnapshotStore.load(context)
        val now = System.currentTimeMillis()
        val tz = TimeZone.getDefault()
        for (id in ids) {
            updateOne(context, manager, id, snapshot, now, tz)
        }
    }

    fun updateOne(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        snapshot: WidgetSnapshot? = WidgetSnapshotStore.load(context),
        now: Long = System.currentTimeMillis(),
        tz: TimeZone = TimeZone.getDefault(),
    ) {
        if (Build.VERSION.SDK_INT >= 31) {
            val views = RemoteViews(
                mapOf(
                    SizeF(110f, 110f) to small(context, id, snapshot, now, tz),
                    SizeF(250f, 110f) to list(context, id, snapshot, now, tz, large = false),
                    SizeF(250f, 300f) to list(context, id, snapshot, now, tz, large = true),
                ),
            )
            manager.updateAppWidget(id, views)
        } else {
            val options = manager.getAppWidgetOptions(id)
            manager.updateAppWidget(id, pick(context, id, snapshot, now, tz, options))
        }
    }

    private fun pick(
        context: Context,
        id: Int,
        snapshot: WidgetSnapshot?,
        now: Long,
        tz: TimeZone,
        options: Bundle,
    ): RemoteViews {
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        return when {
            minWidth >= 250 && maxHeight >= 300 -> list(context, id, snapshot, now, tz, large = true)
            minWidth >= 250 -> list(context, id, snapshot, now, tz, large = false)
            else -> small(context, id, snapshot, now, tz)
        }
    }

    private fun small(
        context: Context,
        widgetId: Int,
        snapshot: WidgetSnapshot?,
        now: Long,
        tz: TimeZone,
    ): RemoteViews {
        val view = WidgetContent.build(snapshot, now, tz, WidgetContent.SMALL)
        if (view.kind != WidgetKind.ITEMS) return message(context, widgetId, view)
        val item = view.items.first()
        val views = RemoteViews(context.packageName, R.layout.widget_upcoming_small)
        views.setTextViewText(R.id.widget_title, item.title)
        views.setTextViewText(R.id.widget_when, whenLabel(context, item, tz))
        views.setTextViewText(R.id.widget_countdown, item.countdown)
        views.setContentDescription(R.id.widget_root, item.talkBack)
        views.setOnClickPendingIntent(
            R.id.widget_root,
            WidgetLaunch.pendingIntent(
                context,
                widgetId,
                1,
                WidgetLaunch.ACTION_EVENT,
                item.eventId,
            ),
        )
        return views
    }

    private val rowIds = intArrayOf(
        R.id.widget_row_0, R.id.widget_row_1, R.id.widget_row_2, R.id.widget_row_3, R.id.widget_row_4,
    )
    private val titleIds = intArrayOf(
        R.id.widget_title_0, R.id.widget_title_1, R.id.widget_title_2, R.id.widget_title_3, R.id.widget_title_4,
    )
    private val whenIds = intArrayOf(
        R.id.widget_when_0, R.id.widget_when_1, R.id.widget_when_2, R.id.widget_when_3, R.id.widget_when_4,
    )
    private val countIds = intArrayOf(
        R.id.widget_countdown_0, R.id.widget_countdown_1, R.id.widget_countdown_2,
        R.id.widget_countdown_3, R.id.widget_countdown_4,
    )

    private fun list(
        context: Context,
        widgetId: Int,
        snapshot: WidgetSnapshot?,
        now: Long,
        tz: TimeZone,
        large: Boolean,
    ): RemoteViews {
        val rows = if (large) WidgetContent.LARGE else WidgetContent.MEDIUM
        val view = WidgetContent.build(snapshot, now, tz, rows)
        if (view.kind != WidgetKind.ITEMS) return message(context, widgetId, view)
        val layout = if (large) R.layout.widget_upcoming_large else R.layout.widget_upcoming_medium
        val views = RemoteViews(context.packageName, layout)
        views.setTextViewText(R.id.widget_header, view.header)
        views.setOnClickPendingIntent(
            R.id.widget_header,
            WidgetLaunch.pendingIntent(context, widgetId, 0, WidgetLaunch.ACTION_UPCOMING),
        )
        views.setContentDescription(R.id.widget_header, "Upcoming")
        views.setOnClickPendingIntent(
            R.id.widget_add,
            WidgetLaunch.pendingIntent(context, widgetId, 9, WidgetLaunch.ACTION_ADD_EVENT),
        )
        // Only the rows this layout has; touching a missing view breaks the widget.
        for (i in 0 until rows) {
            val item = view.items.getOrNull(i)
            if (item == null) {
                views.setViewVisibility(rowIds[i], View.GONE)
                continue
            }
            views.setViewVisibility(rowIds[i], View.VISIBLE)
            views.setTextViewText(titleIds[i], item.title)
            views.setTextViewText(whenIds[i], whenLabel(context, item, tz))
            views.setTextViewText(countIds[i], item.rowCountdown)
            views.setContentDescription(rowIds[i], item.talkBack)
            views.setOnClickPendingIntent(
                rowIds[i],
                WidgetLaunch.pendingIntent(
                    context,
                    widgetId,
                    i + 1,
                    WidgetLaunch.ACTION_EVENT,
                    item.eventId,
                ),
            )
        }
        return views
    }

    /** "Turns 27 · Sun, 8 Nov · 6:30 PM", leaving out what doesn't apply. */
    private fun whenLabel(context: Context, item: WidgetItem, tz: TimeZone): String {
        val date = item.date ?: return item.turns.orEmpty()
        val cal = Calendar.getInstance(tz).apply {
            clear()
            set(date.year, date.month - 1, date.day, item.time?.hour ?: 0, item.time?.minute ?: 0)
        }
        val parts = mutableListOf<String>()
        item.turns?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
        parts.add(SimpleDateFormat("EEE, d MMM", Locale.getDefault()).apply { timeZone = tz }.format(cal.time))
        if (item.time != null) {
            val format: DateFormat = android.text.format.DateFormat.getTimeFormat(context)
            format.timeZone = tz
            parts.add(format.format(cal.time))
        }
        return parts.joinToString(" · ")
    }

    private fun message(context: Context, widgetId: Int, view: WidgetView): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_upcoming_message)
        views.setTextViewText(R.id.widget_header, view.header)
        views.setTextViewText(R.id.widget_title, view.title)
        views.setTextViewText(R.id.widget_subtitle, view.subtitle)
        views.setContentDescription(R.id.widget_root, view.talkBack)
        val eventId = if (view.kind == WidgetKind.ITEMS) view.items.firstOrNull()?.eventId else null
        views.setOnClickPendingIntent(
            R.id.widget_root,
            WidgetLaunch.pendingIntent(context, widgetId, 0, view.launchAction, eventId),
        )
        return views
    }
}
