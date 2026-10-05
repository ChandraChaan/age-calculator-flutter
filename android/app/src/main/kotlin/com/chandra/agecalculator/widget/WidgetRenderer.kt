package com.chandra.agecalculator.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import com.chandra.agecalculator.R
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
                    SizeF(250f, 110f) to medium(context, id, snapshot, now, tz),
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
        return if (minWidth >= 250) {
            medium(context, id, snapshot, now, tz)
        } else {
            small(context, id, snapshot, now, tz)
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
        views.setTextViewText(R.id.widget_header, view.header)
        views.setTextViewText(R.id.widget_title, item.title)
        if (item.turns.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_turns, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_turns, View.VISIBLE)
            views.setTextViewText(R.id.widget_turns, item.turns)
        }
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

    private fun medium(
        context: Context,
        widgetId: Int,
        snapshot: WidgetSnapshot?,
        now: Long,
        tz: TimeZone,
    ): RemoteViews {
        val view = WidgetContent.build(snapshot, now, tz, WidgetContent.MEDIUM)
        if (view.kind != WidgetKind.ITEMS) return message(context, widgetId, view)
        val views = RemoteViews(context.packageName, R.layout.widget_upcoming_medium)
        views.setTextViewText(R.id.widget_header, view.header)
        views.setOnClickPendingIntent(
            R.id.widget_header,
            WidgetLaunch.pendingIntent(context, widgetId, 0, WidgetLaunch.ACTION_UPCOMING),
        )
        views.setContentDescription(R.id.widget_header, "Upcoming")
        val rowIds = intArrayOf(R.id.widget_row_0, R.id.widget_row_1, R.id.widget_row_2)
        val titleIds = intArrayOf(R.id.widget_title_0, R.id.widget_title_1, R.id.widget_title_2)
        val countIds = intArrayOf(R.id.widget_countdown_0, R.id.widget_countdown_1, R.id.widget_countdown_2)
        for (i in rowIds.indices) {
            val item = view.items.getOrNull(i)
            if (item == null) {
                views.setViewVisibility(rowIds[i], View.GONE)
                continue
            }
            views.setViewVisibility(rowIds[i], View.VISIBLE)
            views.setTextViewText(titleIds[i], item.title)
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
