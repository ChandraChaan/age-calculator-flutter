# Age Calculator — v1.1 Decisions (Locked)

| | |
|---|---|
| Status | **Approved and locked.** These decisions resolve §21 "Decisions required before implementation" in `docs/V1_1_IMPLEMENTATION_PLAN.md`. |
| Date | 2026-10-03 |
| Baseline | `v1.0.1` tag at `d9f0fee` (release checkpoint); documentation commit `694b879` (HEAD when recorded) |
| Implementation | Not started |
| References | `docs/CURRENT_STATE_AUDIT.md`, `docs/FUTURE_PRODUCT_ARCHITECTURE.md`, `docs/V1_1_IMPLEMENTATION_PLAN.md` |

Where `docs/FUTURE_PRODUCT_ARCHITECTURE.md` and this file differ for v1.1, **this file wins**. Examples: that document's `events.json` via `path_provider`, and its install-detection landing rule.

---

## Locked decisions

### D1 — Landing

Upcoming when at least one active event exists; otherwise Age.

### D2 — Storage

Versioned event JSON document stored under the existing SharedPreferences key:
`event_store`

Do not add `path_provider` or another storage dependency.

### D3 — Timed event state

A timed event is "Now" during its start minute.
There is no end time in v1.1.

### D4 — Monthly recurrence

Monthly recurrence clamps invalid dates to the last valid day of the target month.

Example:
31 Jan → 28/29 Feb → 31 Mar.

### D5 — Theme

Keep the existing theme control.
Settings also provides System / Light / Dark.

Preserve:
`flutter.theme_mode`

### D6 — Countdown precision

Minute resolution only.
No seconds in v1.1.

### D7 — Event deletion

Settings provides Delete All Events with confirmation.

### D8 — v1.1 version

`1.1.0+3`

### D9 — Duplicate event

Event detail/editor supports duplicating an existing event.
A duplicate must receive a new unique ID, new `createdAt`, and new `updatedAt`.
The duplicate copies the original event's user-facing content and recurrence settings.

### D10 — Active / Paused

Every event uses the existing `enabled` field as its Active state.
`enabled = true` → Active.
`enabled = false` → Paused.
Paused events remain stored and are shown under a Paused section.
Paused events are excluded from upcoming planning and countdown calculations.
Do not introduce a separate `active` field.

### D11 — Undo delete

After deleting an event, provide an immediate Undo action that restores the deleted event with its previous data.
Undo is local/in-memory only in v1.1.
Do not introduce persistent undo history or another storage mechanism.

### D12 — Delete All Events and recovery backup

"Delete All Events" removes both:
- `event_store`
- `event_store_unreadable`

After deletion, the event collection is empty and no recovered event-data backup remains.

Do not delete or modify:
`flutter.theme_mode`

---

## Scope boundaries

### IN v1.1

- local custom events
- one-time events
- daily recurrence
- weekly recurrence
- monthly recurrence
- yearly recurrence
- all-day events
- timed events
- upcoming event planning
- countdown display
- local event persistence
- Upcoming / Age / Settings navigation
- event detail
- event creation/editing
- Save as birthday
- Settings
- tests

### OUT of v1.1

- Android widgets
- calendar integration
- contacts integration
- notifications/reminders
- background scheduling
- backend
- Firebase
- account/login
- cloud sync
- analytics
- ads
- medical prediction/advice
- new third-party dependencies
- Clean Architecture rewrite
- BLoC/Riverpod migration
- signing/CI/CD changes
