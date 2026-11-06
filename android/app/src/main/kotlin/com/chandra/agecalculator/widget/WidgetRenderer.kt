package com.chandra.agecalculator.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.os.Build
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
            // One layout per breakpoint; the launcher picks the largest that fits.
            val views = RemoteViews(
                WidgetSizes.breakpoints().associate { (w, h) ->
                    SizeF(w.toFloat(), h.toFloat()) to
                        render(context, id, snapshot, now, tz, WidgetSizes.specFor(w, h))
                },
            )
            manager.updateAppWidget(id, views)
        } else {
            // Older launchers report a range; in portrait the width is the
            // minimum and the height the maximum.
            val options = manager.getAppWidgetOptions(id)
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 110)
            manager.updateAppWidget(
                id,
                render(context, id, snapshot, now, tz, WidgetSizes.specFor(width, height)),
            )
        }
    }

    private fun render(
        context: Context,
        widgetId: Int,
        snapshot: WidgetSnapshot?,
        now: Long,
        tz: TimeZone,
        spec: WidgetLayoutSpec,
    ): RemoteViews {
        val view = WidgetContent.build(snapshot, now, tz, spec.rows)
        if (view.kind != WidgetKind.ITEMS) return message(context, widgetId, view, spec.form)
        return when (spec.form) {
            WidgetForm.TINY -> single(context, widgetId, view, tz, R.layout.widget_upcoming_tiny, short = true)
            WidgetForm.STRIP -> single(context, widgetId, view, tz, R.layout.widget_upcoming_strip, short = true)
            WidgetForm.CARD -> single(context, widgetId, view, tz, R.layout.widget_upcoming_small, short = false)
            WidgetForm.COLUMN -> list(context, widgetId, view, tz, spec.rows, column = true)
            WidgetForm.LIST -> list(context, widgetId, view, tz, spec.rows, column = false)
        }
    }

    /** The next event alone: tiny, strip and card layouts. */
    private fun single(
        context: Context,
        widgetId: Int,
        view: WidgetView,
        tz: TimeZone,
        layout: Int,
        short: Boolean,
    ): RemoteViews {
        val item = view.items.first()
        val views = RemoteViews(context.packageName, layout)
        views.setTextViewText(R.id.widget_title, item.title)
        if (layout != R.layout.widget_upcoming_tiny) {
            views.setTextViewText(R.id.widget_when, whenLabel(context, item, tz))
        }
        views.setTextViewText(R.id.widget_countdown, if (short) item.rowCountdown else item.countdown)
        views.setContentDescription(R.id.widget_root, item.talkBack)
        views.setOnClickPendingIntent(
            R.id.widget_root,
            WidgetLaunch.pendingIntent(context, widgetId, 1, WidgetLaunch.ACTION_EVENT, item.eventId),
        )
        return views
    }

    private val rowIds = intArrayOf(
        R.id.widget_row_0, R.id.widget_row_1, R.id.widget_row_2,
        R.id.widget_row_3, R.id.widget_row_4, R.id.widget_row_5,
    )
    private val titleIds = intArrayOf(
        R.id.widget_title_0, R.id.widget_title_1, R.id.widget_title_2,
        R.id.widget_title_3, R.id.widget_title_4, R.id.widget_title_5,
    )
    private val whenIds = intArrayOf(
        R.id.widget_when_0, R.id.widget_when_1, R.id.widget_when_2,
        R.id.widget_when_3, R.id.widget_when_4, R.id.widget_when_5,
    )
    private val countIds = intArrayOf(
        R.id.widget_countdown_0, R.id.widget_countdown_1, R.id.widget_countdown_2,
        R.id.widget_countdown_3, R.id.widget_countdown_4, R.id.widget_countdown_5,
    )

    private fun list(
        context: Context,
        widgetId: Int,
        view: WidgetView,
        tz: TimeZone,
        rows: Int,
        column: Boolean,
    ): RemoteViews {
        val layout = if (column) R.layout.widget_upcoming_column else R.layout.widget_upcoming_list
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
        for (i in 0 until WidgetSizes.MAX_ROWS) {
            val item = if (i < rows) view.items.getOrNull(i) else null
            if (item == null) {
                views.setViewVisibility(rowIds[i], View.GONE)
                continue
            }
            views.setViewVisibility(rowIds[i], View.VISIBLE)
            views.setTextViewText(titleIds[i], item.title)
            // The column layout has no date line; it would not fit.
            if (!column) views.setTextViewText(whenIds[i], whenLabel(context, item, tz))
            views.setTextViewText(countIds[i], item.rowCountdown)
            views.setContentDescription(rowIds[i], item.talkBack)
            views.setOnClickPendingIntent(
                rowIds[i],
                WidgetLaunch.pendingIntent(context, widgetId, i + 1, WidgetLaunch.ACTION_EVENT, item.eventId),
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

    private fun message(
        context: Context,
        widgetId: Int,
        view: WidgetView,
        form: WidgetForm,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_upcoming_message)
        val compact = form == WidgetForm.TINY || form == WidgetForm.STRIP
        // Small sizes keep only the line that says what to do.
        views.setViewVisibility(R.id.widget_header, if (compact) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.widget_subtitle, if (form == WidgetForm.TINY) View.GONE else View.VISIBLE)
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
