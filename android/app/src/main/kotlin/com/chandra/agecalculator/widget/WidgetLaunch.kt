package com.chandra.agecalculator.widget

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.chandra.agecalculator.MainActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object WidgetLaunch {
    const val CHANNEL = "com.chandra.agecalculator/home_widget"
    const val ACTION_UPCOMING = "upcoming"
    const val ACTION_EVENT = "event"
    const val ACTION_ADD_EVENT = "add_event"

    const val EXTRA_ACTION = "widget_action"
    const val EXTRA_EVENT_ID = "event_id"

    @Volatile
    private var pending: HashMap<String, Any>? = null

    fun pendingIntent(
        context: Context,
        widgetId: Int,
        row: Int,
        action: String,
        eventId: String? = null,
    ): PendingIntent {
        val intent = launchIntent(context, action, eventId)
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getActivity(context, widgetId * 10 + row, intent, flags)
    }

    fun launchIntent(context: Context, action: String, eventId: String? = null): Intent {
        return Intent(context, MainActivity::class.java).apply {
            this.action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_ACTION, action)
            if (eventId != null) putExtra(EXTRA_EVENT_ID, eventId)
        }
    }

    fun parse(intent: Intent?): HashMap<String, Any>? {
        if (intent == null) return null
        val action = intent.getStringExtra(EXTRA_ACTION) ?: return null
        return when (action) {
            ACTION_UPCOMING -> hashMapOf("action" to "upcoming")
            ACTION_ADD_EVENT -> hashMapOf("action" to "addEvent")
            ACTION_EVENT -> {
                val id = intent.getStringExtra(EXTRA_EVENT_ID) ?: return hashMapOf("action" to "upcoming")
                if (id.isEmpty()) hashMapOf("action" to "upcoming")
                else hashMapOf("action" to "event", "eventId" to id)
            }
            else -> null
        }
    }

    fun clearExtras(intent: Intent?) {
        intent?.removeExtra(EXTRA_ACTION)
        intent?.removeExtra(EXTRA_EVENT_ID)
    }

    fun consume(activity: Activity): HashMap<String, Any>? {
        val stashed = pending
        pending = null
        if (stashed != null) {
            clearExtras(activity.intent)
            return stashed
        }
        val fromIntent = parse(activity.intent)
        clearExtras(activity.intent)
        return fromIntent
    }

    fun dispatchWarm(activity: Activity, intent: Intent, engine: FlutterEngine?) {
        val action = parse(intent) ?: return
        clearExtras(intent)
        if (engine != null) {
            pending = null
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("launchAction", action)
        } else {
            pending = action
        }
    }
}
