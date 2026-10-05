package com.chandra.agecalculator.widget

/** Snapshot JSON produced by Flutter. Kotlin never computes recurrence. */
data class WidgetSnapshot(
    val schemaVersion: Int,
    val eventCount: Int,
    val validThrough: CivilDate,
    val occurrences: List<WidgetOccurrence>,
) {
    companion object {
        fun parse(json: String): WidgetSnapshot {
            val root = Json.parseObject(json)
            val schema = root.int("schemaVersion")
            if (schema != 1) throw IllegalArgumentException("unsupported schema")
            val occurrences =
                root.array("occurrences").map { item ->
                    val o = item as Json.Obj
                    WidgetOccurrence(
                        eventId = o.string("eventId").also {
                            if (it.isEmpty()) throw IllegalArgumentException("empty eventId")
                        },
                        title = o.string("title"),
                        date = CivilDate.parse(o.string("date")),
                        time = o.optionalString("time")?.let { ClockTime.parse(it) },
                        turns = o.optionalString("turns"),
                    )
                }
            return WidgetSnapshot(
                schemaVersion = schema,
                eventCount = root.int("eventCount"),
                validThrough = CivilDate.parse(root.string("validThrough")),
                occurrences = occurrences,
            )
        }
    }
}

data class WidgetOccurrence(
    val eventId: String,
    val title: String,
    val date: CivilDate,
    val time: ClockTime?,
    val turns: String?,
)

data class CivilDate(val year: Int, val month: Int, val day: Int) : Comparable<CivilDate> {
    override fun compareTo(other: CivilDate): Int {
        val y = year.compareTo(other.year)
        if (y != 0) return y
        val m = month.compareTo(other.month)
        return if (m != 0) m else day.compareTo(other.day)
    }

    fun addDays(days: Int): CivilDate {
        val cal = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC"))
        cal.clear()
        cal.set(year, month - 1, day, 0, 0, 0)
        cal.add(java.util.Calendar.DAY_OF_MONTH, days)
        return CivilDate(
            cal.get(java.util.Calendar.YEAR),
            cal.get(java.util.Calendar.MONTH) + 1,
            cal.get(java.util.Calendar.DAY_OF_MONTH),
        )
    }

    fun daysUntil(other: CivilDate): Int = (other.epochDay() - epochDay()).toInt()

    fun epochDay(): Long {
        val cal = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC"))
        cal.clear()
        cal.set(year, month - 1, day, 0, 0, 0)
        return cal.timeInMillis / 86_400_000L
    }

    override fun toString(): String =
        "%04d-%02d-%02d".format(year, month, day)

    companion object {
        fun parse(raw: String): CivilDate {
            val parts = raw.split('-')
            if (parts.size != 3) throw IllegalArgumentException("date $raw")
            return CivilDate(parts[0].toInt(), parts[1].toInt(), parts[2].toInt())
        }

        fun of(millis: Long, timeZone: java.util.TimeZone): CivilDate {
            val cal = java.util.Calendar.getInstance(timeZone)
            cal.timeInMillis = millis
            return CivilDate(
                cal.get(java.util.Calendar.YEAR),
                cal.get(java.util.Calendar.MONTH) + 1,
                cal.get(java.util.Calendar.DAY_OF_MONTH),
            )
        }
    }
}

data class ClockTime(val hour: Int, val minute: Int) {
    companion object {
        fun parse(raw: String): ClockTime {
            val parts = raw.split(':')
            if (parts.size != 2) throw IllegalArgumentException("time $raw")
            val hour = parts[0].toInt()
            val minute = parts[1].toInt()
            if (hour !in 0..23 || minute !in 0..59) throw IllegalArgumentException("time $raw")
            return ClockTime(hour, minute)
        }
    }
}

internal object Json {
    sealed class Val

    class Obj(val map: Map<String, Val>) : Val() {
        fun int(key: String): Int {
            val n = map[key] as? Num ?: throw IllegalArgumentException("missing $key")
            return n.value.toInt()
        }

        fun string(key: String): String {
            val s = map[key] as? Str ?: throw IllegalArgumentException("missing $key")
            return s.value
        }

        fun optionalString(key: String): String? {
            val v = map[key] ?: return null
            if (v is Null) return null
            return (v as? Str)?.value
        }

        fun array(key: String): List<Val> {
            val a = map[key] as? Arr ?: throw IllegalArgumentException("missing $key")
            return a.items
        }
    }

    class Arr(val items: List<Val>) : Val()
    class Str(val value: String) : Val()
    class Num(val value: Long) : Val()
    object Null : Val()

    fun parseObject(raw: String): Obj {
        val p = Parser(raw)
        val v = p.value()
        p.skipWs()
        if (!p.done) throw IllegalArgumentException("trailing JSON")
        return v as? Obj ?: throw IllegalArgumentException("expected object")
    }

    private class Parser(val s: String) {
        var i = 0
        val done get() = i >= s.length

        fun skipWs() {
            while (i < s.length && s[i].isWhitespace()) i++
        }

        fun value(): Val {
            skipWs()
            if (done) throw IllegalArgumentException("empty JSON")
            return when (s[i]) {
                '{' -> obj()
                '[' -> arr()
                '"' -> Str(str())
                'n' -> {
                    expect("null")
                    Null
                }
                't' -> {
                    expect("true")
                    Num(1)
                }
                'f' -> {
                    expect("false")
                    Num(0)
                }
                else -> Num(num())
            }
        }

        fun obj(): Obj {
            i++
            val map = linkedMapOf<String, Val>()
            skipWs()
            if (peek('}')) {
                i++
                return Obj(map)
            }
            while (true) {
                skipWs()
                val key = str()
                skipWs()
                if (!peek(':')) throw IllegalArgumentException("expected :")
                i++
                map[key] = value()
                skipWs()
                when {
                    peek(',') -> i++
                    peek('}') -> {
                        i++
                        return Obj(map)
                    }
                    else -> throw IllegalArgumentException("expected }")
                }
            }
        }

        fun arr(): Arr {
            i++
            val items = mutableListOf<Val>()
            skipWs()
            if (peek(']')) {
                i++
                return Arr(items)
            }
            while (true) {
                items += value()
                skipWs()
                when {
                    peek(',') -> i++
                    peek(']') -> {
                        i++
                        return Arr(items)
                    }
                    else -> throw IllegalArgumentException("expected ]")
                }
            }
        }

        fun str(): String {
            skipWs()
            if (!peek('"')) throw IllegalArgumentException("expected string")
            i++
            val out = StringBuilder()
            while (i < s.length) {
                when (val c = s[i++]) {
                    '"' -> return out.toString()
                    '\\' -> {
                        if (done) throw IllegalArgumentException("bad escape")
                        out.append(
                            when (val e = s[i++]) {
                                '"', '\\', '/' -> e
                                'b' -> '\b'
                                'f' -> '\u000c'
                                'n' -> '\n'
                                'r' -> '\r'
                                't' -> '\t'
                                'u' -> {
                                    if (i + 4 > s.length) throw IllegalArgumentException("bad unicode")
                                    val hex = s.substring(i, i + 4)
                                    i += 4
                                    hex.toInt(16).toChar()
                                }
                                else -> throw IllegalArgumentException("bad escape")
                            },
                        )
                    }
                    else -> out.append(c)
                }
            }
            throw IllegalArgumentException("unterminated string")
        }

        fun num(): Long {
            val start = i
            if (peek('-')) i++
            while (i < s.length && s[i] in '0'..'9') i++
            if (start == i || s[start] == '-' && start + 1 == i) {
                throw IllegalArgumentException("bad number")
            }
            return s.substring(start, i).toLong()
        }

        fun expect(token: String) {
            if (!s.startsWith(token, i)) throw IllegalArgumentException("expected $token")
            i += token.length
        }

        fun peek(c: Char) = i < s.length && s[i] == c
    }
}
