package com.chandra.agecalculator.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.util.Calendar
import java.util.TimeZone

class WidgetLogicTest {
    private val utc: TimeZone = TimeZone.getTimeZone("UTC")

    @Test
    fun parsesFlutterSnapshot() {
        val json =
            """{"schemaVersion":1,"generatedAt":"2026-06-15T06:30:00.000Z","eventCount":2,"validThrough":"2026-07-15","occurrences":[{"eventId":"call","title":"Call","date":"2026-06-15","time":"14:30"},{"eventId":"mom","title":"Mom's birthday","date":"2026-06-20","turns":"Turns 56"}]}"""
        val snapshot = WidgetSnapshot.parse(json)
        assertEquals(1, snapshot.schemaVersion)
        assertEquals(2, snapshot.eventCount)
        assertEquals(CivilDate(2026, 7, 15), snapshot.validThrough)
        assertEquals("call", snapshot.occurrences[0].eventId)
        assertEquals(ClockTime(14, 30), snapshot.occurrences[0].time)
        assertEquals("Turns 56", snapshot.occurrences[1].turns)
        assertEquals(null, snapshot.occurrences[1].time)
    }

    @Test
    fun malformedSnapshotIsRejected() {
        val bad = listOf(
            "",
            "{",
            "[]",
            """{"schemaVersion":2,"eventCount":0,"validThrough":"2026-07-15","occurrences":[]}""",
            """{"schemaVersion":1,"eventCount":0,"occurrences":[]}""",
            """{"schemaVersion":1,"eventCount":0,"validThrough":"2026-07-15"}""",
            "not json",
        )
        for (json in bad) {
            var threw = false
            try {
                WidgetSnapshot.parse(json)
            } catch (_: Exception) {
                threw = true
            }
            assertTrue("should reject $json", threw)
        }
    }

    @Test
    fun emptyAndStaleStates() {
        val now = millis(2026, 6, 15, 12, 0)
        val none = WidgetSnapshot.parse(
            """{"schemaVersion":1,"eventCount":0,"validThrough":"2026-07-15","occurrences":[]}""",
        )
        assertEquals(WidgetKind.ADD_EVENT, WidgetContent.build(none, now, utc, 3).kind)

        val paused = WidgetSnapshot.parse(
            """{"schemaVersion":1,"eventCount":2,"validThrough":"2026-07-15","occurrences":[]}""",
        )
        assertEquals(WidgetKind.OPEN_UPCOMING, WidgetContent.build(paused, now, utc, 3).kind)

        val passed = WidgetSnapshot.parse(
            """{"schemaVersion":1,"eventCount":1,"validThrough":"2026-07-15","occurrences":[{"eventId":"x","title":"Past","date":"2026-06-14"}]}""",
        )
        assertEquals(WidgetKind.OPEN_UPCOMING, WidgetContent.build(passed, now, utc, 3).kind)

        val stale = WidgetSnapshot.parse(
            """{"schemaVersion":1,"eventCount":1,"validThrough":"2026-06-14","occurrences":[{"eventId":"x","title":"Soon","date":"2026-06-20"}]}""",
        )
        assertEquals(WidgetKind.STALE, WidgetContent.build(stale, now, utc, 3).kind)
        assertEquals(WidgetKind.SETUP, WidgetContent.build(null, now, utc, 3).kind)
        assertEquals(WidgetLaunch.ACTION_ADD_EVENT, WidgetContent.build(none, now, utc, 3).launchAction)
        assertEquals(WidgetLaunch.ACTION_UPCOMING, WidgetContent.build(paused, now, utc, 3).launchAction)
    }

    @Test
    fun hidesUnusedRowsAndKeepsOrder() {
        val now = millis(2026, 6, 15, 12, 0)
        val snapshot = WidgetSnapshot.parse(
            """{"schemaVersion":1,"eventCount":3,"validThrough":"2026-07-15","occurrences":[{"eventId":"a","title":"A","date":"2026-06-16"},{"eventId":"b","title":"B","date":"2026-06-17"},{"eventId":"c","title":"C","date":"2026-06-18"}]}""",
        )
        val small = WidgetContent.build(snapshot, now, utc, 1)
        assertEquals(listOf("A"), small.items.map { it.title })
        val medium = WidgetContent.build(snapshot, now, utc, 3)
        assertEquals(listOf("A", "B", "C"), medium.items.map { it.title })
        assertEquals("Tomorrow", small.items[0].countdown)
        assertEquals("2 days", medium.items[1].rowCountdown)
        assertEquals("Dad's birthday, Turns 61, 11 days left", WidgetItem("id", "Dad's birthday", "Turns 61", "11 days left", "11 days").talkBack)
    }

    @Test
    fun fixtureCountdownParity() {
        val root = Json.parseObject(fixture().readText())
        for (item in root.array("cases")) {
            val entry = item as Json.Obj
            val occurrence = WidgetOccurrence(
                eventId = "e",
                title = "T",
                date = CivilDate.parse(entry.string("date")),
                time = entry.optionalString("time")?.let { ClockTime.parse(it) },
                turns = null,
            )
            val now = parseLocal(entry.string("now"))
            val label = WidgetCountdown.of(occurrence, now, utc)
            assertEquals(entry.string("now"), entry.optionalString("label"), label.full)
            assertEquals(entry.string("now"), entry.optionalString("rowLabel"), label.row)
        }
    }

    @Test
    fun nextRefreshIsCappedAtOneHour() {
        val now = millis(2026, 6, 15, 12, 0)
        val snapshot = WidgetSnapshot.parse(
            """{"schemaVersion":1,"eventCount":1,"validThrough":"2026-07-15","occurrences":[{"eventId":"a","title":"A","date":"2026-06-20"}]}""",
        )
        val next = WidgetRefreshScheduler.nextTriggerMillis(snapshot, now, utc)
        assertEquals(now + 60 * 60 * 1000L, next)
    }

    private fun millis(y: Int, m: Int, d: Int, h: Int, min: Int, sec: Int = 0): Long {
        val cal = Calendar.getInstance(utc)
        cal.clear()
        cal.set(y, m - 1, d, h, min, sec)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun parseLocal(raw: String): Long {
        val main = raw.split('T')
        val date = CivilDate.parse(main[0])
        val timeParts = main[1].split(':')
        val sec = if (timeParts.size > 2) timeParts[2].toInt() else 0
        return millis(date.year, date.month, date.day, timeParts[0].toInt(), timeParts[1].toInt(), sec)
    }

    private fun fixture(): File {
        val candidates = listOf(
            File("test/fixtures/home_widget_countdown_cases.json"),
            File("../test/fixtures/home_widget_countdown_cases.json"),
            File("../../test/fixtures/home_widget_countdown_cases.json"),
        )
        return candidates.first { it.exists() }
    }
}
