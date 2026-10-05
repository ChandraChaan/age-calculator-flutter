package com.chandra.agecalculator.widget

import android.content.Context

object WidgetSnapshotStore {
    private const val PREFS = "home_widget"
    private const val KEY = "snapshot_v1"

    fun save(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, json)
            .commit()
    }

    fun loadJson(context: Context): String? {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null)
    }

    fun load(context: Context): WidgetSnapshot? {
        val json = loadJson(context) ?: return null
        return try {
            WidgetSnapshot.parse(json)
        } catch (_: Exception) {
            null
        }
    }
}
