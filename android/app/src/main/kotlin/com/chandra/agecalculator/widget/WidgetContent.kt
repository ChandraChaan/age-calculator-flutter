package com.chandra.agecalculator.widget

import java.util.TimeZone

enum class WidgetKind {
    ITEMS,
    ADD_EVENT,
    OPEN_UPCOMING,
    SETUP,
    STALE,
}

data class WidgetItem(
    val eventId: String,
    val title: String,
    val turns: String?,
    val countdown: String,
    val rowCountdown: String,
) {
    val talkBack: String
        get() = if (turns.isNullOrEmpty()) {
            "$title, $countdown"
        } else {
            "$title, $turns, $countdown"
        }
}

data class WidgetView(
    val kind: WidgetKind,
    val items: List<WidgetItem> = emptyList(),
) {
    val header = "Upcoming"

    val title: String
        get() = when (kind) {
            WidgetKind.ITEMS -> items.firstOrNull()?.title.orEmpty()
            WidgetKind.ADD_EVENT, WidgetKind.OPEN_UPCOMING -> "No upcoming events"
            WidgetKind.SETUP -> "Open Age Calculator"
            WidgetKind.STALE -> "Open Age Calculator"
        }

    val subtitle: String
        get() = when (kind) {
            WidgetKind.ITEMS -> items.firstOrNull()?.turns.orEmpty()
            WidgetKind.ADD_EVENT -> "Tap to add an event"
            WidgetKind.OPEN_UPCOMING -> "Tap to open Upcoming"
            WidgetKind.SETUP -> "to show your events"
            WidgetKind.STALE -> "to update"
        }

    val launchAction: String
        get() = when (kind) {
            WidgetKind.ADD_EVENT -> WidgetLaunch.ACTION_ADD_EVENT
            WidgetKind.ITEMS -> WidgetLaunch.ACTION_EVENT
            else -> WidgetLaunch.ACTION_UPCOMING
        }

    val talkBack: String
        get() = when (kind) {
            WidgetKind.ITEMS -> items.firstOrNull()?.talkBack ?: header
            WidgetKind.ADD_EVENT -> "Upcoming. No upcoming events. Tap to add an event"
            WidgetKind.OPEN_UPCOMING -> "Upcoming. No upcoming events. Tap to open Upcoming"
            WidgetKind.SETUP -> "Open Age Calculator to show your events"
            WidgetKind.STALE -> "Open Age Calculator to update"
        }
}

object WidgetContent {
    const val SMALL = 1
    const val MEDIUM = 3

    fun build(
        snapshot: WidgetSnapshot?,
        nowMillis: Long,
        timeZone: TimeZone,
        maxItems: Int,
    ): WidgetView {
        if (snapshot == null) return WidgetView(WidgetKind.SETUP)
        val today = CivilDate.of(nowMillis, timeZone)
        if (today > snapshot.validThrough) return WidgetView(WidgetKind.STALE)

        val remaining = snapshot.occurrences.mapNotNull { occurrence ->
            val label = WidgetCountdown.of(occurrence, nowMillis, timeZone)
            val full = label.full ?: return@mapNotNull null
            val row = label.row ?: return@mapNotNull null
            WidgetItem(
                eventId = occurrence.eventId,
                title = occurrence.title,
                turns = occurrence.turns,
                countdown = full,
                rowCountdown = row,
            )
        }
        if (remaining.isEmpty()) {
            return WidgetView(
                if (snapshot.eventCount == 0) WidgetKind.ADD_EVENT else WidgetKind.OPEN_UPCOMING,
            )
        }
        return WidgetView(WidgetKind.ITEMS, remaining.take(maxItems))
    }

    fun remainingOccurrences(
        snapshot: WidgetSnapshot?,
        nowMillis: Long,
        timeZone: TimeZone,
    ): List<WidgetOccurrence> {
        if (snapshot == null) return emptyList()
        return snapshot.occurrences.filter {
            WidgetCountdown.of(it, nowMillis, timeZone).full != null
        }
    }
}
