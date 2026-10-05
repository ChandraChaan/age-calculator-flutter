package com.chandra.agecalculator.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class UpcomingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        WidgetRenderer.update(context, manager, ids)
        WidgetRefreshScheduler.schedule(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        WidgetRenderer.updateOne(context, manager, appWidgetId)
    }

    override fun onEnabled(context: Context) {
        WidgetRefreshScheduler.schedule(context)
    }

    override fun onDisabled(context: Context) {
        WidgetRefreshScheduler.cancel(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            WidgetRefreshScheduler.ACTION_REFRESH,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_LOCALE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> refreshAll(context)
        }
    }

    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, UpcomingWidgetProvider::class.java))
            if (ids.isEmpty()) {
                WidgetRefreshScheduler.cancel(context)
                return
            }
            WidgetRenderer.update(context, manager, ids)
            WidgetRefreshScheduler.schedule(context)
        }
    }
}
