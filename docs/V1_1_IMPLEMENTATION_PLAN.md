# Age Calculator — v1.1 Implementation Plan

**Personal Events & Countdown Foundation**

| | |
|---|---|
| Status | Plan only. Nothing in this document is implemented. |
| Date | 2026-10-03 |
| Baseline | v1.0.1 (`1.0.1+2`) working tree on top of commit `8ebe849`. 249/249 tests pass in 5 time zones plus the machine default; analyze and format are clean. |
| Inputs | `docs/CURRENT_STATE_AUDIT.md`, `docs/FUTURE_PRODUCT_ARCHITECTURE.md`, the current `lib/` and `test/` trees, `pubspec.yaml`, `pubspec.lock` |
| Out of scope | Widgets, notifications/alarms, background work, calendar, contacts, native Kotlin, Gradle/signing, Firebase/backend/analytics/ads, smart ranking |

How claims are tagged:

- **[Repo]**: verified in this repository during this pass.
- **[Doc]**: verified in Flutter, plugin or Android source/docs.
- **[Verify]**: must be confirmed during implementation.
- **[Decision]**: needs product-owner approval (see §21).

---

## 0. Summary

v1.1 adds one new concept, a **user-created Event**, plus the smallest machinery around it:

- **A pure-Dart engine** for wall-clock times, recurrence, countdowns and a deterministic planner. It reuses the v1.0.1 `CivilDate` and `CalendarMath` unchanged.
- **One JSON document** stored under a single key in the *existing* `SharedPreferences`. No new dependency and no lockfile change.
- **One `ChangeNotifier`** (`EventController`) that owns the event list and its persistence.
- **A three-tab shell**: Upcoming | Age | Settings.
- **Four new screens**: Upcoming, Event detail, Event editor, Settings.
- **"Save as birthday"** from the existing Age result.

**Deliberate deviations from `FUTURE_PRODUCT_ARCHITECTURE.md`, with reasons:**

| Architecture doc said | v1.1 plan does | Why |
|---|---|---|
| `events.json` file via `path_provider` (§3.7) | JSON document in the existing `SharedPreferences` under key `event_store` | `path_provider` is only a **transitive** dependency today (`pubspec.lock`: `dependency: transitive` **[Repo]**). Making it direct rewrites `pubspec.lock`, which must not change. Volume fits easily (§19). Revisit trigger in §7.9. |
| Upgraders land on Age once, new installs on Upcoming, detected with native install info (§13.4) | Land on **Age until the first event exists**, then Upcoming (recommended), or a theme-based heuristic | Native code is out of scope, and v1.0.1 wrote no version marker. A pure-Dart app **cannot reliably tell an upgrade from a new install** (§12). **[Decision D1]** |
| `AppServices` + `AppScope` InheritedWidget, three controllers (§3.4–3.5) | One `EventController`, passed by constructor. Theme stays where it is today. | Only a few consumers exist; fewer objects means less to test. |
| `FloatingTiming` / `FixedTiming` / `AllDayTiming` sealed types (§4.2) | `CivilDate date` + optional `LocalTime time` | v1.1 has only user-created, floating-local events. Fixed instants arrive with calendar import in v1.5. |
| Every-N-days recurrence, share countdown, personal/private category (§14 v1.1–v1.2) | Not in v1.1 | Not in the requested v1.1 feature list. The model leaves room for them (§18). |

---

## 1. What exists today (inspected, not assumed)

| Area | Actual state | Evidence |
|---|---|---|
| Folder structure | `lib/{app.dart, main.dart, engine/, models/, screens/, services/, theme/, utils/, widgets/}`: 17 files, 1,684 lines | **[Repo]** |
| Engine (v1.0.1) | `engine/civil_date.dart`: `CivilDate` (validated y/m/d, `epochDay` via UTC, `daysUntil`, `addDays`, `weekday`, `fromDateTime`, ordering, ISO `toString`). `engine/calendar_math.dart`: `isLeapYear`, `daysInMonth`, `addMonthsWithOverflow`, `birthdayInYear` (29 Feb → 28 Feb). `engine/age_calculator.dart`: `AgeCalculator.calculate(CivilDate, CivilDate) → AgeBreakdown?`, `monthAnchor`. No Flutter imports. | **[Repo]** |
| Services | `AgeService` is a thin adapter: `calculate(DateTime dob, [DateTime? reference]) → AgeResult?`, with an injectable `AgeCalculator`. `ShareService` builds and shares the result text. | **[Repo]** |
| Models | `AgeResult` (14 fields; `weeks/hours/minutes` removed in v1.0.1) | **[Repo]** |
| Screens | One: `HomeScreen` (its own `Scaffold` + `AppBar` titled "Age Calculator" with `ThemeSwitch`). Private widgets: `_ActionButtons`, `_ResultsSection`, `_PrimaryAgeCards`. | **[Repo]** |
| Navigation | `MaterialApp(home: …)` only. No routes, no `Navigator.push`. Overlays: date-picker dialog, SnackBars, share sheet. | **[Repo]** |
| State management | `setState` only. Theme lives in `_AgeCalculatorAppState` (`app.dart`), passed down as `themeMode` + `onThemeChanged`. Age inputs and result live in `_HomeScreenState`. | **[Repo]** |
| SharedPreferences | Legacy API `SharedPreferences.getInstance()`. One key `theme_mode` ∈ {`light`, `dark`, `system`}; unknown → system. Physical storage: `flutter.theme_mode` in `FlutterSharedPreferences.xml`. Writes use `commit()`. | **[Repo]** `app.dart:14-60`; **[Doc]** `LegacySharedPreferencesPlugin.java` (`SHARED_PREFERENCES_NAME`, `.commit()`), `shared_preferences_legacy.dart` (`_prefix = 'flutter.'`) |
| Date utilities | `AppDateUtils` (formatting `dd MMMM yyyy`, weekday, pluralize; arithmetic delegated to the engine). `DateInputFormat`: locale-ordered typed dates through the picker's `calendarDelegate`. | **[Repo]** |
| Reusable widgets | `DatePickerField` (generic: label, placeholder, first/last date, help text, icon); `AgeCard`, `InfoCard`, `DateSelectionCard`, `ThemeSwitch` | **[Repo]** |
| Material 3 | `AppTheme`: `useMaterial3: true`, `ColorScheme.fromSeed(#6750A4)`, card and button themes. No `NavigationBar` theme yet; M3 defaults apply. | **[Repo]** |
| Initialization | `main()`: `ensureInitialized` → portrait lock → `runApp(AgeCalculatorApp())`. The app shows `_LoadingScreen` until the theme is read. | **[Repo]** |
| Tests | 11 test files, the frozen 1.0.0 oracle (`test/legacy/`), helper `test/support/app_driver.dart` (`pumpAgeCalculatorApp`, `setSurfaceSize`, `typeDate`), and `tool/run_tests_in_time_zones.sh`. **249 tests.** | **[Repo]** |
| Dependencies | `shared_preferences ^2.5.3`, `intl ^0.20.2`, `share_plus ^13.2.0`; dev: `flutter_test`, `flutter_lints ^6.0.0` | **[Repo]** |
| Nested Scaffolds | `ScaffoldMessenger` shows SnackBars only on the **root** Scaffold of a nested set | **[Doc]** `scaffold.dart` `_isRoot` |
| Version control | v1.0.1 changes are **uncommitted** (`git status`: 14 modified, 11 untracked paths) | **[Repo]** |

**Precondition for implementation**: commit (and optionally tag) v1.0.1 first, so v1.1 has a clean, revertible baseline. That's the owner's action, not part of this plan.

---

## 2. Event domain model

### 2.1 v1.1 `Event`

```dart
// lib/models/event.dart (design sketch, pure Dart)
enum EventCategory { birthday, anniversary, travel, exam, meeting, event, importantDate, other }

class Event {
  const Event({ … });
  final String id;               // stable random id (§2.3)
  final String title;            // 1–80 chars after trim (UI-enforced)
  final EventCategory category;
  final CivilDate date;          // the date, or first occurrence for recurring events
  final LocalTime? time;         // null = all-day; otherwise a wall-clock time (§3)
  final Recurrence recurrence;   // none | daily | weekly | monthly | yearly (§4)
  final String? notes;           // optional, ≤ 500 chars (UI-enforced)
  final bool enabled;            // false = paused, hidden from the timeline
  final DateTime createdAt;      // UTC
  final DateTime updatedAt;      // UTC

  bool get isAllDay => time == null;
  Event copyWith({ … });
}
```

### 2.2 Field-by-field justification

**A. Required for v1.1**

| Field | Why it exists in v1.1 |
|---|---|
| `id` | Edit, delete, duplicate and undo need a stable identity. The planner uses it as the final, deterministic sort tie-breaker. |
| `title` | Shown everywhere |
| `category` | Feature #16. Drives icon and colour, and the birthday "Turns N" label. Set to `birthday` by "Save as birthday". |
| `date` (`CivilDate`) | Every event has a calendar date. For recurring events it is the **anchor** (first occurrence); yearly birthdays use it as the birth date. |
| `time` (`LocalTime?`) | Features #14/#15. Null means all-day. A separate `allDay` flag would allow invalid states (`allDay: true` with a time), so it is **derived**, not stored. |
| `recurrence` | Feature #5 |
| `notes` | Feature #17 |
| `enabled` | Feature #9 |
| `createdAt` | Default ordering of the Paused list (oldest first) and diagnostics. Also used when resolving duplicate IDs on load (§7.6). |
| `updatedAt` | Shown nowhere in v1.1. Needed as soon as two copies of an event can meet: backup restore now (§8), and imported-source overlays in v1.4/v1.5. Cheap to write now, impossible to reconstruct later. |

**B. Reserved for future compatibility (not stored in v1.1; absent means the default)**

| Field | Future version | Default when absent |
|---|---|---|
| `source` (`custom`, `contactBirthday`, `calendar`) | v1.4/v1.5 | `custom`. v1.1 only stores user events, so the field carries no information yet. |
| `reminders` (list) | v1.2 | none |
| `endDate` / `endTime` (or duration) | v1.5 calendar events have ends; also enables an "ongoing" state | no end (see §5 "Now" rule) **[Decision D3]** |
| `zoneId` (IANA) | v1.6 travel events | floating (device zone) |
| `yearKnown` | v1.4 contact birthdays without a year | `true` |
| `pinned` / priority | v1.6 ranking | not pinned |
| `sensitivity` (private) | v1.2, with notifications and widgets | normal |

Adding an optional field later needs **no data migration**, because older documents simply lack it. A `schemaVersion` bump is reserved for incompatible changes (§7.5).

**C. Unnecessary (rejected)**

| Field | Why not |
|---|---|
| `allDay` flag | Derived from `time == null` |
| `emoji` / `icon` | Derived from `category` |
| `metadata` map | Untyped catch-all; future sources get typed fields |
| `customCategoryLabel` | "Other" is enough for v1.1 |
| `timezone` on all events | Personal events are floating wall-clock times (§3) |

### 2.3 IDs

- Format: 32 lowercase hex characters (128 bits) from `Random.secure()`. Pure Dart, no `uuid` dependency (`uuid` is only transitive **[Repo]**).
- The generator is injected into `EventController`, so tests are deterministic.
- IDs are never reused. Duplicating an event gets a new ID.

### 2.4 Value types added to the engine

```dart
// lib/engine/local_time.dart (pure Dart)
class LocalTime implements Comparable<LocalTime> {
  factory LocalTime(int hour, int minute);   // 0–23, 0–59; validated
  final int hour, minute;
  int get minuteOfDay => hour * 60 + minute;
  // ==, hashCode, compareTo, toString 'HH:mm'
}
```

`CivilDate` (v1.0.1) is reused as the **calendar date** type and is not renamed.

---

## 3. Date/time model

### 3.1 The three concepts

| Concept | Type | Used for | Rule |
|---|---|---|---|
| Calendar date | `CivilDate` (existing) | Birthdays, all-day events, recurrence anchors, "days left", sections | Day counts **only** via `CivilDate.daysUntil` (UTC epoch days). Never subtract local `DateTime`s. |
| Wall-clock time | `LocalTime` (new) | "Meeting at 17:00" | Combined with a `CivilDate` only at the edge, to produce an instant |
| Instant | `DateTime` (UTC) | "Now", timed countdowns, `createdAt`/`updatedAt` | Remaining time = difference of UTC instants (real elapsed time) |

### 3.2 Representing the required cases

| Case | Representation |
|---|---|
| Birthday (Sai, 25 Aug 1999) | `date: 1999-08-25, time: null, recurrence: yearly, category: birthday` |
| All-day event (exam day) | `date: 2026-11-14, time: null, recurrence: none` |
| Event at 5:00 PM | `date: 2026-10-09, time: 17:00, recurrence: none` |
| Monthly event (rent on the 31st) | `date: 2026-01-31, time: null` (or a time), `recurrence: monthly` |
| Yearly event (anniversary) | `date: 2015-02-14, time: null, recurrence: yearly, category: anniversary` |

### 3.3 Time-zone behaviour

- **All-day events and birthdays are time-zone free.** "Today" is the device's current local calendar date: `CivilDate.fromDateTime(now)`, where `now` is local. Days left = `today.daysUntil(occurrenceDate)`. This matches the v1.0.1 principle.
- **Timed events are floating wall-clock times.** "17:00" means 17:00 in whatever zone the device is in when the countdown is evaluated. Travelling from IST to London changes the instant, not the stored value. This matches user intent for personal events; explicit zones are v1.6 (§18).
- **The single edge conversion** is `instantOf(CivilDate date, LocalTime time) = DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc()`. It lives in one engine function (`lib/engine/countdown.dart`) and is the **only** place v1.1 maps a wall time to an instant.
- **DST.** Remaining time is the UTC difference, so it is real elapsed time. Example: in New York, 21:00 on 7 Mar 2026 → 09:00 on 8 Mar 2026 is **11 h**, not 12 h. Daily recurrences repeat the **wall time** (09:00 stays 09:00 across DST), because each occurrence's instant is computed from its own date + time.
- **Non-existent local times** (spring-forward gap, e.g. 02:30 on 8 Mar 2026 in New York): Dart's local `DateTime` constructor normalises them. The expected result is 03:30 EDT. **[Verify]** with a test pinned to `America/New_York`. The UI always shows the stored wall time ("02:30").
- **Ambiguous local times** (fall-back, e.g. 01:30 on 1 Nov 2026 in New York): Dart picks one of the two instants. **[Verify]** which one, then pin it in a test. Either is acceptable, as long as it is deterministic.
- **Testing**: the whole suite already runs under UTC, Asia/Kolkata, Europe/London, America/New_York and America/Los_Angeles via `tool/run_tests_in_time_zones.sh` **[Repo]**. Zone-specific expectations are selected by detecting the active zone's January/July offsets (§15.3).

---

## 4. Recurrence

### 4.1 Model

```dart
// lib/engine/recurrence.dart (pure Dart)
enum Recurrence { none, daily, weekly, monthly, yearly }

/// k-th occurrence date (k ≥ 0) of an event anchored at [anchor].
CivilDate occurrenceDate(CivilDate anchor, Recurrence recurrence, int k);

/// First occurrence date that is on or after [from] (null for a passed one-time event).
CivilDate? firstOccurrenceOnOrAfter(CivilDate anchor, Recurrence recurrence, CivilDate from);
```

No recurrence package. Five frequencies with closed-form maths are smaller and easier to verify than an RRULE library.

### 4.2 Exact rules

Each occurrence is computed **from the anchor**, never from the previous occurrence, so month-end clamping never drifts.

| Frequency | k-th occurrence |
|---|---|
| `none` | `anchor` only (k = 0) |
| `daily` | `anchor.addDays(k)` |
| `weekly` | `anchor.addDays(7 * k)`, same weekday as the anchor |
| `monthly` | Year and month = anchor's month + k. Day = `min(anchor.day, daysInMonth(target))`: **clamp to the last day**. |
| `yearly` | `CalendarMath.birthdayInYear(anchor, anchor.year + k)`, the **same function the v1.0.1 age engine uses**. Feb 29 → Feb 28 in non-leap years; every other month/day exists every year. |

### 4.3 Edge cases

| Case | Result |
|---|---|
| Monthly on the 31st | Jan 31 → Feb 28 (Feb 29 in leap years) → Mar 31 → Apr 30 → May 31 → … (no drift) |
| Monthly on the 30th | Jan 30 → Feb 28/29 → Mar 30 → … |
| Monthly on the 29th | Feb 29 in leap years, Feb 28 otherwise |
| Yearly on 29 Feb | 2024-02-29 → 2025-02-28 → 2026-02-28 → 2027-02-28 → 2028-02-29. Same rule as the Age tab's countdown. |
| Yearly on 28 Feb | Always 28 Feb |
| Leap years | Only via `CalendarMath.daysInMonth` / `isLeapYear` (existing, tested) |
| Monthly day that doesn't exist | Clamped (above). **Not skipped.** **[Decision D4]**: the alternative "skip months without that day" is RFC 5545 behaviour, but surprising for "rent on the 31st". |
| Anchor in the past, recurring | Next occurrence on or after today (or after now for timed events) |
| Anchor in the future | The anchor itself is the first occurrence |
| One-time event in the past | No next occurrence. State is `passed`. |

The clamp rule for monthly events intentionally differs from the age engine's month arithmetic (overflow). The age engine answers "how many whole months have elapsed", preserving 1.0.0 results. Monthly events answer "which day of this month". For 29 Feb yearly events both rules give **28 Feb**, so yearly events and age always agree.

### 4.4 Next-occurrence algorithm (O(1), no iteration over history)

- `daily`: `k = max(0, anchor.daysUntil(from))`
- `weekly`: `k = max(0, ceil(anchor.daysUntil(from) / 7))`
- `monthly`: `k = max(0, monthsBetween(anchor, from))`; if `occurrenceDate(k) < from`, then `k + 1`
- `yearly`: `k = max(0, from.year - anchor.year)`; if `occurrenceDate(k) < from`, then `k + 1`

For **timed** recurring events, the planner first checks today's occurrence. If its "now" window has ended (§5.3), it asks for the first occurrence on or after **tomorrow**.

---

## 5. Countdown engine

### 5.1 Output model (pure Dart)

```dart
// lib/engine/countdown.dart
enum CountdownState { upcoming, now, passed }

class Countdown {
  final CountdownState state;
  final int? daysUntil;      // all-day events: calendar days (0 = today)
  final int? minutesUntil;   // timed events: ceiling to whole minutes (§5.3)
}

Countdown countdownFor(PlannedOccurrence occurrence, DateTime now);
```

Label text is produced by a separate pure formatter (`lib/utils/countdown_format.dart`), so the UI does no maths and the maths stays free of English strings.

### 5.2 All-day events (calendar days, time-zone free)

| `daysUntil` | State | Label |
|---|---|---|
| 0 | `now` | **"Today"** |
| 1 | `upcoming` | **"Tomorrow"** |
| n ≥ 2 | `upcoming` | **"n days left"** (e.g. "2 days left") |
| < 0 (one-time only) | `passed` | **"Passed"** |

### 5.3 Timed events (real elapsed time)

Let `R = startInstant − now` (UTC).

| Condition | State | Label |
|---|---|---|
| `R > 0` | `upcoming` | From `M = ceil(R / 1 min)` (see below) |
| `−60 s < R ≤ 0` | `now` | **"Now"** |
| `R ≤ −60 s`, one-time | `passed` | **"Passed"** |
| `R ≤ −60 s`, recurring | `upcoming` | Countdown to the **next** occurrence (never "Passed") |

**Rounding rule: ceiling to the whole minute, then show the two largest units.**

1. `M = ceil(R / 60 s)`. "0 minutes left" can therefore never appear before the event starts.
2. If `M < 60`: **"M minutes left"** ("1 minute left", "14 minutes left").
3. If `60 ≤ M < 1440`: **"H hours m minutes left"**, with zero minutes omitted ("3 hours 24 minutes left", "2 hours left").
4. If `M ≥ 1440`: **"D days H hours left"**, with zero hours omitted ("1 day 9 hours left", "2 days left").

**The worked example from the brief** (event at 17:00):

| Now | R | M | Label |
|---|---|---|---|
| 14:30:00 | 2 h 30 m | 150 | **"2 hours 30 minutes left"** (not "3 hours") |
| 14:30:20 | 2 h 29 m 40 s | 150 | "2 hours 30 minutes left" |
| 14:31:00 | 2 h 29 m | 149 | "2 hours 29 minutes left" |
| 16:59:30 | 30 s | 1 | "1 minute left" |
| 17:00:00 | 0 | — | "Now" |
| 17:00:59 | −59 s | — | "Now" |
| 17:01:00 | −60 s | — | "Passed" (one-time) or next occurrence (recurring) |

Event times are whole minutes, and modern UTC offsets are whole minutes, so **labels change exactly on wall-clock minute boundaries**. A ticker that fires on each minute boundary therefore stays exact (§10.4).

**The "Now" window is one minute.** Without an end time there is no honest notion of "ongoing". Showing "Now" for the start minute is precise and invents no duration. **[Decision D3]**: alternatively, add an optional end time in v1.1.

### 5.4 Precision and resolution

- **Minute resolution everywhere in v1.1** (list and detail). No seconds ticker. **[Decision D6]**
- Countdown inputs are integers and `Duration`s, so NaN and infinity cannot occur.

---

## 6. Event planner

### 6.1 Contract

```dart
// lib/engine/upcoming_planner.dart (pure Dart)
UpcomingPlan planUpcoming(List<Event> events, DateTime now);

class PlannedOccurrence {
  final Event event;
  final CivilDate date;            // occurrence date
  final DateTime? startUtc;        // timed occurrences only
  final Countdown countdown;
  final int? yearsSinceAnchor;     // yearly events: occurrence.year − anchor.year ("Turns 27")
}

class UpcomingPlan {
  final PlannedOccurrence? next;   // the "What's next?" item (first non-passed)
  final List<PlannedOccurrence> today, tomorrow, nextSevenDays, later, passed;
  final List<Event> paused;        // disabled events
}
```

Inputs are `events` + `now` (instant). The time zone is the process's local zone, used only through the edge conversion (§3.3). v1.1 has **no settings that affect planning**; a `settings` parameter is added only when one exists (v1.2 reminders).

### 6.2 Rules

1. **Disabled** events go to `paused`, sorted by `createdAt` then `id`. They never get a countdown.
2. Each **enabled** event yields **exactly one occurrence**: its current or next one (§4.4, §5.3). A one-time event in the past yields a `passed` occurrence.
3. Sections are based on the occurrence's `CivilDate` relative to `today`:
   - `today`: daysUntil == 0, including "Now" items;
   - `tomorrow`: 1;
   - `nextSevenDays`: 2–6;
   - `later`: ≥ 7;
   - `passed`: one-time events in the past.

   "This week" is implemented as a **rolling next 7 days**, labelled "Next 7 days". That avoids locale-dependent week starts.
4. **Ordering** within upcoming sections: `(date, all-day before timed, time, title case-insensitive, id)`. `passed` is ordered most recent first.
5. `next` is the first item of `today ∪ tomorrow ∪ nextSevenDays ∪ later` in that order. It is shown as the hero card and **not repeated** in its section.
6. **Determinism.** The output depends only on `(events, now, local time zone)`. There's no `DateTime.now()`, no randomness and no iteration-order dependence (input order is irrelevant after sorting). A test runs `planUpcoming` twice and on shuffled input and asserts equal outputs.

### 6.3 Future use (not built in v1.1)

Widgets (v1.3) and reminders (v1.2) need *several* occurrences per event. They will reuse `occurrenceDate` / `firstOccurrenceOnOrAfter` through a later `occurrencesBetween(event, from, to)`. v1.1 doesn't add it, because nothing would call it.

---

## 7. Storage

### 7.1 Location

| Item | Value |
|---|---|
| API | Existing legacy `SharedPreferences` (same instance and API as the theme) |
| Logical key | `event_store` |
| Physical key | `flutter.event_store` in `FlutterSharedPreferences.xml` **[Doc]** |
| Unreadable-data backup key | `event_store_unreadable` (written once, never overwritten automatically) |
| New dependency | None |
| `theme_mode` | Untouched; independent key |

### 7.2 JSON schema (version 1)

```json
{
  "schemaVersion": 1,
  "events": [
    {
      "id": "3f9c0a1b6d2e4f5a8b7c9d0e1f2a3b4c",
      "title": "Sai's birthday",
      "category": "birthday",
      "date": "1999-08-25",
      "time": null,
      "recurrence": "yearly",
      "notes": null,
      "enabled": true,
      "createdAt": "2026-10-03T02:00:00.000Z",
      "updatedAt": "2026-10-03T02:00:00.000Z"
    }
  ]
}
```

| Field | Format | On read, if missing or invalid |
|---|---|---|
| `id` | non-empty string | Entry is **invalid** |
| `title` | string, non-empty after trim | Entry is **invalid** |
| `category` | `birthday`, `anniversary`, `travel`, `exam`, `meeting`, `event`, `important_date`, `other` | Unknown or missing → `other` |
| `date` | `YYYY-MM-DD`, a real calendar date (via `CivilDate`) | Entry is **invalid** |
| `time` | `null`/absent = all-day, or `HH:mm` 24-hour | Malformed → entry **invalid** |
| `recurrence` | `none`, `daily`, `weekly`, `monthly`, `yearly` | Missing → `none`. Unknown → entry **invalid** (never mis-schedule). |
| `notes` | string, or null/absent | Non-string → `null` |
| `enabled` | bool | Missing or non-bool → `true` |
| `createdAt`, `updatedAt` | ISO-8601 UTC | Missing or malformed → the other timestamp, else `1970-01-01T00:00:00Z` |
| Unknown fields | — | Ignored (v1.1 is the first writer, so it can't meet newer fields in practice) |

### 7.3 Layers

- `lib/data/event_codec.dart` (**pure Dart**, `dart:convert` only) handles document ↔ `List<Event>`, validation, and the results `invalidEntries`, `duplicateIds` and `documentStatus`. It contains no business logic and no I/O.
- `lib/data/event_storage.dart` (**Flutter plugin adapter**, depends on `shared_preferences`) has three methods: `Future<String?> read()`, `Future<bool> write(String json)`, and `Future<void> backupUnreadable(String raw)` (only if the backup key is empty). There are no decisions in it.

### 7.4 Load behaviour

| Stored value | Result |
|---|---|
| Key absent (new install, upgrader, or after "Delete all") | Empty list, status `ready`. Nothing is written until the first change. |
| Valid v1 document | Events loaded |
| Not JSON, not an object, or `schemaVersion` missing/non-integer | Raw string copied to `event_store_unreadable`; empty list; status `recovered`. Upcoming shows a one-line notice: "Some saved events couldn't be read." |
| `schemaVersion > 1` | Treated as unreadable (backed up, never parsed) |
| Valid document with some invalid entries | Valid events loaded. Invalid entries are appended, as a JSON array, to the unreadable backup **only if** the backup key is empty; status `recovered`. |
| Duplicate `id`s | First entry kept unchanged. Later duplicates get a new generated ID (no data loss). Persisted with the next write. |

### 7.5 Migrations

- `schemaVersion` sits at the document root.
- The codec dispatches on version (`1` → `_decodeV1`).
- A future v2 decoder converts v1 → v2 in memory, and the next write stores v2. Optional new fields don't need a version bump (§2.2B).

### 7.6 Writes

- Every mutation serialises the **whole document** and calls `setString` once. On Android this is a single `SharedPreferences.commit()` **[Doc]**. Android's `SharedPreferencesImpl` writes the file with a backup-and-rename scheme, so a crash mid-write leaves the previous version **[Verify]**.
- Writes are serialised through one `Future` chain in `EventController`. There are never two concurrent `setString` calls for `event_store`.
- On failure (`false` or an exception), the in-memory change is reverted, listeners are notified, and the UI shows "Couldn't save. Please try again."

### 7.7 Empty state

There is no document until the first event is saved. "Delete all events" removes the key, rather than writing an empty list.

### 7.8 Size and limits

About 250–350 bytes per event as JSON. XML escaping of quotes adds roughly 20–30% on disk. So 1,000 events is about 0.3–0.45 MB. The whole prefs file is loaded into memory at app start (`getInstance`). That's acceptable at this size **[Verify on a low-end device]**.

### 7.9 Revisit trigger

Move events to a dedicated file or database (needing `path_provider` or `sqflite`, which is a lockfile change and needs approval) if **any** of these happen:

- more than about 2,000 events, or a document over about 500 KB;
- a background isolate needs to write events (v1.3+; legacy prefs cache per isolate, so readers must call `reload()`);
- backup rules must treat events and other prefs differently (§8).

---

## 8. Android backup

| Fact | Status |
|---|---|
| The release manifest sets no `allowBackup`, `fullBackupContent` or `dataExtractionRules`, so backup is enabled by default (`ALLOW_BACKUP` flag seen on the emulator) | **[Repo]** audit §13 |
| Android Auto Backup includes the app's `shared_prefs/` by default | **[Verify]** (standard Auto Backup behaviour) |
| Therefore `FlutterSharedPreferences.xml`, containing `theme_mode`, `event_store` and `event_store_unreadable`, is **eligible for backup without any Android change** | Follows from the above |

**Consequences for v1.1:**

- User-created events are backup-eligible, as decided. **No Android configuration change.**
- v1.1 stores **no** calendar data, contact data or permission state, so nothing needs excluding yet.
- **Restore** brings back events with their original IDs and timestamps. A restore is a whole-file replacement, so no merge logic is needed in v1.1.
- **Important for v1.3+ (not v1.1):** backup rules apply to whole files. Individual keys in `FlutterSharedPreferences.xml` can't be excluded. Calendar- or contact-derived data, such as the widget snapshot proposed in the architecture doc (§8.2 there), **must not** be stored in this prefs file if it has to stay out of backup. It needs its own file with an exclusion rule. **[Verify]** when v1.3 is planned. This corrects a detail in `FUTURE_PRODUCT_ARCHITECTURE.md` §3.7/§8.2.
- The unreadable-data backup key is also backed up. That's harmless, and useful for support.

---

## 9. Age Calculator integration

| Aspect | Plan |
|---|---|
| UI location | `_ResultsSection` in `home_screen.dart`, directly under the "Born on … · As of …" line and above the cards: an `OutlinedButton.icon` (cake icon) **"Save as birthday"**. It's visible only when a result exists. |
| What it opens | The same **Event editor** used everywhere, pre-filled. The user can change the title (usually a person's name) before saving. |
| Default title | **"Birthday"**, with the title field focused and its text selected, so typing "Sai's birthday" replaces it |
| Date used | `result.dateOfBirth`, the DOB, **not** the "as of" date |
| Time | none (all-day) |
| Recurrence | `yearly` |
| Category | `birthday` |
| Result | An **ordinary event**. Nothing links it back to the Age tab afterwards. |
| Duplicates | Before saving, the editor calls a pure helper `findBirthdaysOn(events, date)`: same category `birthday` and same full date. If any exist, a dialog says: "A birthday on 15 March 2000 already exists ('Sai's birthday'). Save another?" Options: **Save anyway** / **Cancel**. |
| After saving | SnackBar "Saved to Upcoming" with **View**, which switches to the Upcoming tab via a callback from the shell. The Age tab keeps its inputs. |
| Editing later | Through Upcoming → detail → Edit, like any event |
| Age maths | Not duplicated. The event's countdown uses `Recurrence.yearly`, which calls `CalendarMath.birthdayInYear`, the same function behind `AgeCalculator`'s next birthday. A property test asserts that the event's next occurrence equals `AgeCalculator.calculate(dob, today).nextBirthday` for all sampled DOBs (§15). "Turns N" = occurrence year − birth year. |

---

## 10. Upcoming screen

### 10.1 Purpose

Answer **"What's coming next?"** at a glance.

### 10.2 Layout

```
AppBar: "Upcoming"
[optional notice: "Some saved events couldn't be read."]
Hero card "Next": 🎂 Sai's birthday · Turns 27 · Tue, 25 Aug 2026 · "2 days left"
Today          (items, including "Now")
Tomorrow
Next 7 days
Later
Passed         (one-time events in the past, most recent first)
Paused         (disabled events, greyed)
FAB: "+ Add event"
```

- Empty sections are hidden.
- **Each tile** shows:
  - a category icon and colour;
  - the title;
  - a subtitle with the date (`EEE, d MMM yyyy`, unambiguous month names), the time (Material time format, honouring the device 12/24-hour setting), and a recurrence label ("Every year" / "Every month" / …);
  - the countdown label on the trailing edge.
- **Empty state** (no events at all):
  - an icon;
  - "No events yet";
  - "Add birthdays, exams, trips and other important dates.";
  - buttons **[Add event]** and **[Calculate an age]** (switches to the Age tab).
- Tapping a tile opens **Event detail**.

### 10.3 Event detail (pushed route)

The detail screen shows:

- a large countdown label;
- the full date and time, recurrence, category and notes;
- for yearly birthdays, "Turns 27";
- an **Active** switch (enable/disable);
- buttons **Edit**, **Duplicate** and **Delete** (with confirmation). After deleting, the screen pops and shows a SnackBar "Event deleted" with **Undo**, which re-adds the identical event.

### 10.4 Live countdown

A small `MinuteTicker` widget schedules a `Timer` for the next local minute boundary, then rebuilds every minute. It also rebuilds on `AppLifecycleState.resumed`, because time may have jumped while the app was in the background, and it cancels its timer on `dispose`. The planner recomputes in `build`.

Planning 1,000 events takes well under a frame (§19), so no caching is needed.

### 10.5 Event editor (pushed route; create / edit / duplicate / save-birthday)

| Field | Control |
|---|---|
| Title | `TextField`, required, max 80 |
| Category | `ChoiceChip`s with icons |
| Date | Existing `DatePickerField` (reused unchanged; range 1900-01-01 to 2100-12-31) |
| All day | `Switch`, default on |
| Time | When "All day" is off: `showTimePicker`, which honours the device 24-hour setting |
| Repeat | Dropdown: Does not repeat / Every day / Every week / Every month / Every year |
| Notes | Multiline `TextField`, optional, max 500 |

- Choosing **Birthday** or **Anniversary** sets Repeat to "Every year", unless the user has already changed Repeat.
- **Save** is enabled when the title is non-empty.
- **Back with unsaved changes** asks "Discard changes?" (`PopScope`).

---

## 11. Navigation

| Aspect | Plan |
|---|---|
| Implementation | New `AppShell` (`lib/screens/app_shell.dart`): `Scaffold` + Material 3 `NavigationBar` with three destinations (**Upcoming**, **Age**, **Settings**) and an `IndexedStack` body. No navigation package. |
| Existing home screen | `HomeScreen` becomes the **Age** tab **unchanged in behaviour**: same class, same file, same `Scaffold`/`AppBar`/`ThemeSwitch`, plus the "Save as birthday" button. Nested Scaffolds are fine. SnackBars appear on the root (shell) Scaffold, above the `NavigationBar` **[Doc]**. |
| State across tabs | `IndexedStack` keeps every tab alive, so the Age inputs and result survive tab switches. `IndexedStack` also **lays out** hidden tabs, so v1.0.1 overflow tests also cover the new tabs (they must be overflow-free). |
| Routes | Detail and editor are pushed with `Navigator.push(MaterialPageRoute(…))` above the shell, so the `NavigationBar` is hidden while editing. No named routes. |
| Back behaviour | Shell: Android back exits the app, as in 1.0.x (no `PopScope` on tabs). Detail/editor: back pops; the editor confirms discarding unsaved changes. Predictive back is unaffected. |
| Selected-tab persistence | **None stored.** The landing tab is computed on each launch (§12). Within a session the last tab stays selected. |
| Deep links | None exist (the manifest has only MAIN/LAUNCHER **[Repo]**), so nothing to keep compatible |
| Wide screens | The same `NavigationBar` (≥ 600 dp could use `NavigationRail`, but that's not needed for v1.1) |

---

## 12. Migration and landing behaviour

### 12.1 Constraint discovered during inspection

The architecture doc's rule ("upgraders → Age once, new installs → Upcoming") needs an upgrade signal. The only persisted 1.0.x data is `flutter.theme_mode`, which exists **only if the user ever tapped the theme toggle** **[Repo]**. v1.0.1 writes no install marker, and reading Android's first-install/last-update times needs native code, which is out of scope. **A pure-Dart v1.1 can't reliably tell an upgrade from a new install.**

### 12.2 Options

| | **A (recommended): content-based landing** | B: marker + theme heuristic |
|---|---|---|
| Rule | Land on **Upcoming if at least one enabled event exists**, otherwise **Age** | First v1.1 launch: `theme_mode` present → Age, absent → Upcoming. Write `landing_resolved = true`. Later launches: Upcoming. |
| Upgrader who never touched the theme (most users) | **Age** ✓ | Upcoming (empty) ✗ |
| Upgrader who toggled the theme | **Age** ✓ | Age ✓ |
| New install | Age until the first event, then Upcoming | Upcoming ✓ |
| New preference keys | **None** | 1 (`landing_resolved`) |
| Existing tests | **All v1.0.1 widget, layout and theme tests stay valid unchanged** (they launch with no events and expect the Age screen) | Every v1.0.1 widget test needs a prefs fixture to land on Age |
| Failure modes | None. Deterministic from data. | Wrong guess for most upgraders |

**Recommendation: A.**

- It is the smallest mechanism, with zero new state.
- It is always correct for upgraders.
- It shows new users an empty Upcoming only when they choose it. The app is listed on Play as "Age Calculator", so opening on Age is not surprising.
- It makes Upcoming the landing screen as soon as it has something to show.

**[Decision D1]**

### 12.3 First v1.1 launch for an existing user (option A)

1. `_LoadingScreen` while one `SharedPreferences.getInstance()` resolves. Theme and events are read from the same instance.
2. `theme_mode` is applied exactly as before: same key, same values, same parser.
3. `event_store` is absent, so the event list is empty.
4. The shell opens on **Age**, which looks as it did in 1.0.1, plus the bottom navigation and the "Save as birthday" button after a calculation.
5. After the first saved event, later launches open on **Upcoming**.

Nothing is migrated or rewritten. No permission is requested. `flutter.theme_mode` is read and written by the same code as today.

---

## 13. Settings (v1.1)

| Item | Why it's needed |
|---|---|
| **Theme: System / Light / Dark** (`SegmentedButton`) | Fixes the audit finding that users can't return to "System". It calls the existing `_setThemeMode` in `app.dart`, which already writes `system` **[Repo]**. Same key, same values. |
| **Delete all events** (confirmation dialog) | The only local-data control for a privacy-first app. It removes `event_store`. Optional, low cost. **[Decision D7]** |
| **Privacy note** (static text) | "Your events are stored only on this device. The app has no account and no internet access." Grounded: no INTERNET permission in the release manifest **[Repo]**. |

**Not included** (no current need): countdown display style, week start, default reminder times (v1.2), leap-day policy (fixed to 28 Feb in v1.0.1), and the app version number. Showing the version needs `package_info_plus`, a new dependency, or a duplicated constant.

The AppBar `ThemeSwitch` on the Age tab is **kept** for continuity. **[Decision D5]**

---

## 14. Shared state (ChangeNotifier)

**Minimum: one new state object.**

```dart
// lib/state/event_controller.dart (Flutter foundation only)
class EventController extends ChangeNotifier {
  EventController({required EventStorage storage, required DateTime Function() clock,
                   required String Function() newId});
  LoadStatus get status;                 // loading | ready | recovered
  List<Event> get events;                // unmodifiable; the single source of truth
  Future<void> load();
  Future<void> add(Event draft);         // assigns id and timestamps
  Future<void> update(Event event);      // bumps updatedAt
  Future<void> setEnabled(String id, bool enabled);
  Future<Event?> delete(String id);      // returns the removed event, for Undo
  Future<void> restore(Event event);     // Undo
  Future<void> deleteAll();
  Event duplicateDraft(String id);       // a copy for the editor, not saved yet
}
```

| Concern | Decision |
|---|---|
| Ownership | Created and disposed by `_AgeCalculatorAppState` (the app's existing root state), next to the theme |
| Distribution | Passed by constructor: `AppShell` → `UpcomingScreen` / `HomeScreen` / routes. No `InheritedWidget` and no service locator for this small number of consumers. |
| Theme state | **Stays** in `_AgeCalculatorAppState` (existing owner). No `SettingsController`. |
| Upcoming plan | **Not stored.** Derived in `build` via `planUpcoming(controller.events, clock())`. |
| Current time | Not app state. `MinuteTicker` triggers rebuilds; the clock is a function. |
| Persistence | Only `EventController` calls `EventStorage`. Widgets never touch storage. |
| Testability | `AgeCalculatorApp({DateTime Function()? clock})` gains an optional clock (default `DateTime.now`). Storage tests use `SharedPreferences.setMockInitialValues`, the existing pattern **[Repo]**. |

---

## 15. Test plan

All tests are pure Dart unless marked **(W)** for widget tests. The full suite runs under the five zones plus the machine default via the existing script. **All 249 v1.0.1 tests must keep passing unchanged** (option A).

### 15.1 Event model and codec

| ID | Case |
|---|---|
| EM-01 | `Event` → JSON → `Event` round-trip for all categories, all recurrences, all-day and timed, notes null and present |
| EM-02 | Exact JSON key names and formats (`date` `YYYY-MM-DD`, `time` `HH:mm`, timestamps UTC `…Z`) — a golden string |
| EM-03 | `schemaVersion: 1` is written; missing, non-integer or `2` → unreadable (raw backed up) |
| EM-04 | Missing optional fields use defaults (`category` → other, `enabled` → true, `recurrence` → none, `notes` → null, timestamps fallback) |
| EM-05 | Invalid entries rejected: empty title, bad date (`2023-02-29`), bad time (`25:00`), unknown recurrence |
| EM-06 | Corrupt JSON (`{`, `[]`, `"x"`, `null`, a binary-like string) → empty list, status `recovered`, raw preserved once |
| EM-07 | Duplicate IDs: first kept, later ones re-ID'd with injected generator, no events lost |
| EM-08 | Unknown extra fields ignored without error |
| EM-09 | `LocalTime` validation and formatting (`00:00`, `23:59`, rejects 24:00 / 12:60) |

### 15.2 Recurrence

| ID | Case |
|---|---|
| RC-01 | `none`: only the anchor; past anchor → no next occurrence |
| RC-02 | `daily`: next on or after `from` for anchors in the past, today and the future |
| RC-03 | `weekly`: same weekday; anchor on `from` → itself |
| RC-04 | `monthly`, day 31 across a full year (non-leap and leap): Feb 28/29, Apr 30, … then back to 31 (no drift) |
| RC-05 | `monthly`, days 28/29/30 in February of leap and non-leap years |
| RC-06 | `yearly` Feb 29: 2024 → 2025-02-28 → 2028-02-29; 2100 is not a leap year → 2100-02-28 |
| RC-07 | `yearly` equals `CalendarMath.birthdayInYear` for 100k seeded anchors (shared rule) |
| RC-08 | Property, 200k seeded cases: `firstOccurrenceOnOrAfter` ≥ `from`; the previous occurrence (if k > 0) < `from`; result = `occurrenceDate(k)` |
| RC-09 | Dec → Jan year rollover for monthly; Dec 31 anchors |

### 15.3 Countdown

| ID | Case |
|---|---|
| CD-01 | All-day: today → "Today"; +1 → "Tomorrow"; +2 → "2 days left"; one-time past → "Passed" |
| CD-02 | Timed future: the table in §5.3 exactly (14:30:00, 14:30:20, 14:31:00, 16:59:30, 17:00:00, 17:00:59, 17:01:00) |
| CD-03 | Boundaries: 59 s → 1 minute; 60 min → "1 hour left"; 1439 min → "23 hours 59 minutes left"; 1440 → "1 day left"; 1 day 0 h omits hours |
| CD-04 | Singular and plural: "1 minute", "1 hour", "1 day" |
| CD-05 | Recurring timed event after its minute → next occurrence, never "Passed" |
| CD-06 | Recurring all-day event yesterday → next occurrence (daily → today = "Today") |
| CD-07 | Zero state ("Now") for all-day = "Today" for the whole local day |

### 15.4 Time zones and DST (run under all 5 zones)

| ID | Case |
|---|---|
| TZ-01 | All-day day counts and sections are identical in every zone (fixed expected values, e.g. birthday 1999-08-25, now = 2026-08-23 09:00 local → "2 days left") |
| TZ-02 | Timed countdown uses real elapsed time. Expected values per zone are selected by detecting the zone's Jan/Jul offsets. Example: 2026-03-07 21:00 → 2026-03-08 09:00 is 11 h in New York and Los Angeles, 12 h in UTC, Kolkata and London. Also 2026-03-28 21:00 → 03-29 09:00 is 11 h in London only. |
| TZ-03 | Daily 09:00 event across DST stays at 09:00 wall time on both sides |
| TZ-04 | Non-existent 02:30 (New York, 2026-03-08) and 01:30 (London, 2026-03-29): deterministic instant **[Verify]** expected normalisation |
| TZ-05 | Ambiguous 01:30 (New York, 2026-11-01): deterministic **[Verify]** |
| TZ-06 | Planner output is identical when called twice and with shuffled input (determinism) |

### 15.5 Planner

| ID | Case |
|---|---|
| PL-01 | Section assignment for days 0, 1, 2, 6, 7, 400 and passed |
| PL-02 | Ordering: all-day before timed on the same date; ties by title then id |
| PL-03 | `next` = first upcoming item and not duplicated in its section; null when only passed or paused events exist |
| PL-04 | Disabled events only in `paused` |
| PL-05 | Yearly birthday `yearsSinceAnchor` ("Turns 27"); 0 when the occurrence is the anchor |
| PL-06 | Scale: 1,000 and 5,000 generated events plan correctly (timing printed, not asserted) |

### 15.6 Storage and controller

| ID | Case |
|---|---|
| ST-01 | Create → reload (new controller, same mock prefs) → identical events |
| ST-02 | Update bumps `updatedAt` only; reload shows the change |
| ST-03 | Delete → reload → gone; Undo restores the identical event (same id and timestamps) |
| ST-04 | Duplicate → new id, new timestamps, same fields |
| ST-05 | `setEnabled` persists |
| ST-06 | `deleteAll` removes the key (`event_store` absent) and leaves `theme_mode` intact |
| ST-07 | Write failure (storage returns false) → in-memory state reverted, listeners notified |
| ST-08 | Corrupted stored data → status `recovered`, unreadable key written once, then normal saves work |
| ST-09 | Writes are serialised: rapid add/add/delete ends in the correct final document |
| ST-10 | Only the keys `theme_mode`, `event_store` and (when recovering) `event_store_unreadable` ever exist |

### 15.7 Age integration (W)

| ID | Case |
|---|---|
| AG-01 | "Save as birthday" visible only after a result; opens the editor pre-filled (title "Birthday", DOB, all-day, yearly, birthday) |
| AG-02 | Saved event's countdown equals the Age tab's "Next Birthday Countdown" when "as of" = today |
| AG-03 | DOB 29 Feb: event next occurrence 28 Feb in non-leap years, matching the Age tab |
| AG-04 | Duplicate birthday dialog: Save anyway creates a second event; Cancel creates nothing |
| AG-05 | Age inputs and result are preserved after saving and switching tabs |
| AG-06 | Property (pure): event next occurrence == `AgeCalculator.calculate(dob, today).nextBirthday` for 100k seeded pairs |

### 15.8 Navigation and migration (W)

| ID | Case |
|---|---|
| NV-01 | No events (upgrader or new install) → lands on Age; the existing `widget_test.dart` passes unchanged |
| NV-02 | `flutter.theme_mode` = dark plus no events → Age, dark theme |
| NV-03 | ≥ 1 enabled event → lands on Upcoming |
| NV-04 | Only disabled events → lands on Age (option A counts enabled events) |
| NV-05 | Tab switching keeps Age inputs (`IndexedStack`) |
| NV-06 | Editor back with unsaved changes → discard dialog; without changes → pops |
| NV-07 | Upcoming empty state "Calculate an age" switches to the Age tab |

### 15.9 UI layout (W)

| ID | Case |
|---|---|
| UI-01 | Upcoming (empty and with 12 mixed events), detail, editor, settings at 320×568, 360×640, 412×915, 1280×800 × text 1.0 / 1.3 / 2.0: no exceptions or overflow; scroll to the last item |
| UI-02 | Countdown labels never wrap mid-number; hero card readable at 2.0 on 320 dp |
| UI-03 | v1.0.1 `layout_test.dart` still passes (Age tab inside the shell) |
| UI-04 | Live ticker: with a controllable clock, advancing one minute updates the label (`tester.pump(Duration(minutes: 1))`). No pending timers after dispose. |

### 15.10 Theme (W)

| ID | Case |
|---|---|
| TH-01 | All v1.0.1 `theme_persistence_test.dart` tests pass unchanged |
| TH-02 | Settings → System writes `system`; relaunch → `ThemeMode.system` |
| TH-03 | Saving and deleting events never changes `theme_mode` |

---

## 16. File plan

### 16.1 Create

| File | Responsibility | Why | Depends on | Kind |
|---|---|---|---|---|
| `lib/engine/local_time.dart` | `LocalTime` value type | Wall-clock time without Flutter's `TimeOfDay` (keeps the engine pure) | — | Pure Dart |
| `lib/engine/recurrence.dart` | `Recurrence` enum, `occurrenceDate`, `firstOccurrenceOnOrAfter` | §4 | `civil_date`, `calendar_math` | Pure Dart |
| `lib/engine/countdown.dart` | `Countdown`, `CountdownState`, `instantOf`, `countdownFor` | §5 | `civil_date`, `local_time` | Pure Dart |
| `lib/engine/upcoming_planner.dart` | `planUpcoming`, `UpcomingPlan`, `PlannedOccurrence` | §6 | engine + `models/event` | Pure Dart |
| `lib/models/event.dart` | `Event`, `EventCategory`, `copyWith`, `findBirthdaysOn` | §2 | engine types | Pure Dart |
| `lib/data/event_codec.dart` | JSON v1 encode/decode, validation, duplicate-ID detection | §7.2–7.5 | `dart:convert`, `models/event` | Pure Dart |
| `lib/data/event_storage.dart` | Read, write and back up raw JSON via `SharedPreferences` | §7.3 | `shared_preferences` | Flutter plugin adapter |
| `lib/state/event_controller.dart` | `ChangeNotifier` owning events and persistence | §14 | `flutter/foundation`, codec, storage | Flutter (foundation only) |
| `lib/utils/countdown_format.dart` | English labels from `Countdown` | Keeps strings out of the maths and maths out of the UI | `engine/countdown` | Pure Dart |
| `lib/screens/app_shell.dart` | `NavigationBar` + `IndexedStack` + landing rule | §11–12 | screens, controller | Flutter |
| `lib/screens/upcoming_screen.dart` | Timeline, hero, sections, empty state, FAB | §10 | planner, controller, widgets | Flutter |
| `lib/screens/event_detail_screen.dart` | Detail, Active switch, edit/duplicate/delete/undo | §10.3 | controller | Flutter |
| `lib/screens/event_editor_screen.dart` | Create, edit, duplicate, save-birthday form | §10.5 | `DatePickerField`, controller | Flutter |
| `lib/screens/settings_screen.dart` | Theme selector, delete all, privacy note | §13 | theme callbacks, controller | Flutter |
| `lib/widgets/event_tile.dart` | One timeline row (icon, title, subtitle, countdown) | Used by the hero card and sections | `utils/countdown_format` | Flutter |
| `lib/widgets/event_category_style.dart` | Category → icon, label, colour | Used by tile, detail and editor (3 users) | Material icons | Flutter |
| `lib/widgets/minute_ticker.dart` | Rebuild on minute boundaries and on resume | §10.4 | `dart:async` | Flutter |
| `test/engine/local_time_test.dart` | EM-09 | | | Pure |
| `test/engine/recurrence_test.dart` | RC-01…09 | | | Pure |
| `test/engine/countdown_test.dart` | CD-01…07 | | | Pure |
| `test/engine/upcoming_planner_test.dart` | PL-01…06, TZ-06 | | | Pure |
| `test/engine/event_time_zone_test.dart` | TZ-01…05 (zone-aware expectations) | | | Pure |
| `test/data/event_codec_test.dart` | EM-01…08 | | | Pure |
| `test/state/event_controller_test.dart` | ST-01…10 (with mock prefs) | | | Flutter test |
| `test/countdown_format_test.dart` | Label strings (CD-02…04) | | | Pure |
| `test/upcoming_screen_test.dart` | Timeline, empty state, detail, delete/undo, ticker (UI-04) | | | (W) |
| `test/event_editor_test.dart` | Create, edit, validation, discard dialog | | | (W) |
| `test/navigation_test.dart` | NV-01…07 | | | (W) |
| `test/save_birthday_test.dart` | AG-01…06 | | | (W) + pure |
| `test/settings_screen_test.dart` | TH-02, TH-03, delete all | | | (W) |
| `test/events_layout_test.dart` | UI-01, UI-02 | | | (W) |

### 16.2 Change

| File | Change | Constraint |
|---|---|---|
| `lib/app.dart` | Load theme **and** events from one `getInstance()`. Create and dispose `EventController`. Show `AppShell` instead of `HomeScreen`. Optional `clock` constructor parameter. | `_themeKey`, `_parseThemeMode`, `_themeModeToString` and `_setThemeMode` stay **byte-identical in behaviour** |
| `lib/screens/home_screen.dart` | Add the "Save as birthday" button and a `ValueChanged<AgeResult>? onSaveBirthday` callback | No change to calculation, inputs, validation, share, layout rules or texts |
| `test/support/app_driver.dart` | Add helpers (seed events, controllable clock, tap tabs) | Existing functions unchanged |
| `pubspec.yaml` | **Only** `version: 1.0.1+2` → `1.1.0+3`, at release time | No dependency changes. **[Decision D8]** |

### 16.3 Leave untouched

- **v1.0.1 engine and services:**
  - `lib/engine/age_calculator.dart`, `lib/engine/calendar_math.dart`, `lib/engine/civil_date.dart`
  - `lib/services/age_service.dart`, `lib/services/share_service.dart`
  - `lib/models/age_result.dart`, `lib/utils/date_utils.dart`, `lib/utils/date_input_format.dart`
- **v1.0.1 widgets:** `lib/widgets/age_card.dart`, `date_picker_field.dart` (reused as-is), `date_selection_card.dart`, `info_card.dart`, `theme_switch.dart`.
- **App setup:** `lib/theme/app_theme.dart`, `lib/main.dart`.
- **All existing test files:** `test/*_test.dart`, `test/engine/*`, `test/legacy/legacy_age_calculator.dart`.
- **Tooling:** `tool/run_tests_in_time_zones.sh`, which already runs the whole suite.
- **Platform and build:** `pubspec.lock`, `android/` (including Gradle, the manifest and the signing configuration), `ios/`, `web/`, `analysis_options.yaml`, `.gitignore`.
- **Docs:** `docs/CURRENT_STATE_AUDIT.md`, `docs/FUTURE_PRODUCT_ARCHITECTURE.md`.

---

## 17. Dependencies

**Decision: no new dependencies.**

| Need | Satisfied by |
|---|---|
| Persistence | `shared_preferences` (existing, legacy API) |
| JSON | `dart:convert` |
| IDs | `dart:math` `Random.secure()` |
| Date and time display | `intl` `DateFormat` (existing); `MaterialLocalizations.formatTimeOfDay` |
| Date and time input | `showDatePicker` (via existing `DatePickerField`), `showTimePicker` (Flutter SDK) |
| Navigation | `NavigationBar`, `IndexedStack`, `Navigator` (Flutter SDK) |
| State | `ChangeNotifier`, `ListenableBuilder` (Flutter SDK) |
| Live countdown | `dart:async` `Timer`, `WidgetsBindingObserver` |

**Considered and rejected:**

- `path_provider` (would change `pubspec.lock`, §0).
- `uuid` (only 128 random bits are needed).
- `rrule` / recurrence packages (five closed-form rules are enough).
- `provider` / `riverpod` (prohibited and unnecessary).
- `timezone` (floating local times need no IANA database in v1.1).
- `package_info_plus` (only for a version label).

---

## 18. Future compatibility (design hooks only; nothing built)

| Version | What it needs from v1.1 | How v1.1 enables it without building it |
|---|---|---|
| v1.2 reminders | Stable IDs, occurrence instants, a per-event reminder list | `id` → deterministic notification IDs. `occurrenceDate`/`instantOf` → reminder times. Add an optional `reminders` JSON field (no migration). The planner gains a `settings` input only then. |
| v1.3 widgets | A precomputed upcoming list | `planUpcoming` is pure and deterministic, so a snapshot builder can call it. **Note §8:** the snapshot must not live in `FlutterSharedPreferences.xml` if it holds non-backup data. Background isolates must `reload()` legacy prefs. |
| v1.4 contact birthdays | Birthday events without a stored copy, possibly without a year | Imported birthdays become in-memory `Event`s with `source: contactBirthday` (field added then, default `custom`) and `yearKnown: false`. User tweaks are stored as overlays under a **separate** key, not in `event_store`. `findBirthdaysOn` is the dedupe hook. |
| v1.5 calendar events | Fixed instants with end times | Add optional `end` plus a fixed-instant timing variant. Calendar events are not persisted (read live). The planner sorts by instant, so it accepts them. |
| v1.6 smart ranking | A ranking hook, pinning | Replace the planner's sort comparator; add optional `pinned`. Sections stay as they are. |

**The principle**: v1.1 persists **only user-authored data**, in a document that grows by optional fields. External sources (calendar, contacts) are never written into `event_store`.

---

## 19. Performance

| Scale | JSON size (est.) | Load and decode (est.) | Plan per minute (est.) | Save (est.) | Verdict |
|---|---|---|---|---|---|
| 10 events | ~3 KB | < 1 ms | < 0.1 ms | < 5 ms | Trivial |
| 100 events | ~30 KB | ~1 ms | ~0.2 ms | ~5 ms | Trivial |
| 1,000 events | ~300 KB | ~5–15 ms | ~1–2 ms | ~10–30 ms | Fine |
| 5,000 events | ~1.5 MB | noticeable at startup | ~5–10 ms | ~50–150 ms | Revisit trigger (§7.9) |

All figures are estimates; PL-06 prints real timings in tests. **[Verify]** on a low-end device before release.

- Each enabled event costs O(1) for its next occurrence, plus O(n log n) to sort.
- No caching or indexing in v1.1.
- `IndexedStack` builds three tabs at startup. Upcoming's cost is the plan above.

---

## 20. Privacy

| Stored data | Where | Leaves the device? |
|---|---|---|
| Event title, category, date, optional time, recurrence, optional notes, active flag, created/updated timestamps | `flutter.event_store` (`FlutterSharedPreferences.xml`) | Only via Android backup, if the user's backup is on (§8) |
| Unreadable raw event data (only after corruption) | `flutter.event_store_unreadable` | Same as above |
| Theme | `flutter.theme_mode` (unchanged) | Same as above |

- No network, no INTERNET permission (unchanged **[Repo]**), no Firebase, analytics, ads or external APIs. v1.1 adds no permissions.
- Notes may contain personal information. They are never logged, never shared automatically, and never sent anywhere.
- "Delete all events" removes `event_store`. Uninstall removes everything.
- v1.1 does not change the Play Data safety answers ("No data collected" still holds, because nothing leaves the device under the developer's control) **[Verify]** against Play's definitions at release.

---

## 21. Decisions required before implementation

| # | Question | Recommended default | Why | Impact if changed later |
|---|---|---|---|---|
| D1 | Landing behaviour, given that upgrades can't be reliably detected in pure Dart | **Option A**: Upcoming if any enabled event exists, otherwise Age | Correct for all upgraders, zero new state, all v1.0.1 tests stay valid | Switching to B later adds one key and fixtures in widget tests. Low. |
| D2 | Event storage location | **`SharedPreferences` key `event_store`** (no new dependency, `pubspec.lock` unchanged) | Satisfies the lockfile constraint; volume fits; already backup-eligible | Moving to a file later is a one-time read-old/write-new migration inside `EventStorage`. Medium. |
| D3 | How long a timed event shows "Now" | **One minute** (start minute), no end-time field in v1.1 | No invented durations; exact; fewer UI fields | Adding optional end times later is additive (optional JSON field). Low. |
| D4 | Monthly events on days 29–31 in shorter months | **Clamp to the last day of the month** | Matches "rent on the 31st"; consistent with yearly 29 Feb → 28 Feb | Changing to "skip" later changes which dates existing events show. Medium; document in release notes. |
| D5 | Theme controls | **Keep the AppBar toggle on Age and add System/Light/Dark in Settings** | No regression for current users; fixes the "can't return to System" issue | Removing the toggle later is trivial |
| D6 | Countdown resolution | **Minutes** (list and detail); no seconds ticker | Simpler ticker, fewer rebuilds, matches the label rules | Adding seconds to the detail screen later is local to one screen. Low. |
| D7 | Include "Delete all events" in Settings | **Yes** | Privacy-first local data control; about 30 lines plus tests | Dropping it is trivial |
| D8 | v1.1 version number | **`1.1.0+3`**, set in `pubspec.yaml` at the end of implementation | Next versionCode after 2 | Must stay above whatever is live on Play |

---

## 22. Implementation phases

Each phase ends with `flutter analyze` clean, `dart format` clean, the full suite green (including all 249 v1.0.1 tests), and `tool/run_tests_in_time_zones.sh` green.

| Phase | Scope | Testable result |
|---|---|---|
| **0. Preconditions** | Owner commits v1.0.1; D1–D8 decided | Clean baseline, `git status` clean |
| **1. Engine: time and recurrence** | `local_time.dart`, `recurrence.dart` | EM-09, RC-01…09 (pure, all zones) |
| **2. Engine: countdown and labels** | `countdown.dart`, `countdown_format.dart` | CD-01…07, TZ-01…05 |
| **3. Model and codec** | `models/event.dart`, `data/event_codec.dart` | EM-01…08 |
| **4. Planner** | `upcoming_planner.dart` | PL-01…06, TZ-06, AG-06 |
| **5. Storage and controller** | `data/event_storage.dart`, `state/event_controller.dart` | ST-01…10 (mock prefs); `theme_mode` untouched |
| **6. Shell, landing and Settings** | `app_shell.dart`, `settings_screen.dart`, `app.dart` changes (Upcoming tab may still be a placeholder) | NV-01…05, TH-01…03, v1.0.1 widget, layout and theme tests unchanged |
| **7. Upcoming and detail** | `upcoming_screen.dart`, `event_detail_screen.dart`, `event_tile.dart`, `event_category_style.dart`, `minute_ticker.dart` | Timeline, empty state, enable/disable, delete + undo, UI-04 |
| **8. Editor** | `event_editor_screen.dart` (create, edit, duplicate; recurrence and time UI) | Editor tests, NV-06 |
| **9. Age → birthday** | `home_screen.dart` button + editor prefill + duplicate dialog | AG-01…05 |
| **10. Verification and release prep** | Layout matrix (UI-01/02), TZ script, manual device checklist (DST device setting, 12/24 h, backup/restore **[Verify]**), version bump (D8) | Full green; release notes listing behaviour |

Phases 1–5 add no UI, so they can merge without changing what users see.

---

## 23. Safety

This plan created only `docs/V1_1_IMPLEMENTATION_PLAN.md`. No source, test, configuration, dependency, lockfile or Android file was changed, and nothing was committed, tagged or pushed.
