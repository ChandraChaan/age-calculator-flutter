import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/reminder_planner.dart';
import 'package:agecalculator/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/upcoming_fixtures.dart';

Event _event(
  String id, {
  String title = 'Event',
  EventCategory category = EventCategory.event,
  required CivilDate date,
  LocalTime? time,
  Recurrence recurrence = Recurrence.none,
  List<int> reminders = const [ReminderLeads.atStart],
  bool enabled = true,
  EventSource? source,
}) {
  return Event(
    id: id,
    title: title,
    category: category,
    date: date,
    time: time,
    recurrence: recurrence,
    enabled: enabled,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    reminders: reminders,
    source: source,
  );
}

/// intl separates "PM" with a narrow no-break space.
String _body(Event event, int lead) =>
    reminderBody(event, event.date, lead).replaceAll('\u202f', ' ');

DateTime _local(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime(y, m, d, h, min).toUtc();

void main() {
  // fixedNow is Monday 15 June 2026, 12:00 local.
  final now = fixedNow();

  group('when reminders fire', () {
    test('an all-day event reminds at 9:00 on the day and days before', () {
      final event = _event(
        'a',
        date: CivilDate(2026, 6, 20),
        reminders: const [
          ReminderLeads.atStart,
          ReminderLeads.oneDay,
          ReminderLeads.oneWeek,
        ],
      );
      final planned = planReminders([event], now);
      expect(
        planned.map((r) => r.fireAtUtc),
        [_local(2026, 6, 19, 9), _local(2026, 6, 20, 9)],
        reason: 'the 1-week reminder (13 June) has already passed',
      );
    });

    test('a timed event subtracts minutes from its start', () {
      final event = _event(
        't',
        date: CivilDate(2026, 6, 16),
        time: LocalTime(18, 30),
        reminders: const [
          ReminderLeads.tenMinutes,
          ReminderLeads.oneHour,
          ReminderLeads.oneDay,
        ],
      );
      final planned = planReminders([event], now);
      expect(planned.map((r) => r.fireAtUtc), [
        _local(2026, 6, 15, 18, 30),
        _local(2026, 6, 16, 17, 30),
        _local(2026, 6, 16, 18, 20),
      ]);
    });

    test('past reminders, paused events and events without reminders are '
        'skipped', () {
      final planned = planReminders([
        _event('past', date: CivilDate(2026, 6, 1)),
        _event('today', date: CivilDate(2026, 6, 15)),
        _event('paused', date: CivilDate(2026, 6, 20), enabled: false),
        _event('silent', date: CivilDate(2026, 6, 20), reminders: const []),
      ], now);
      expect(planned, isEmpty);
    });

    test('recurring events plan their next occurrences', () {
      final event = _event(
        'w',
        date: CivilDate(2026, 6, 1),
        recurrence: Recurrence.weekly,
      );
      final planned = planReminders([event], now, occurrencesPerEvent: 3);
      expect(
        planned.map((r) => r.occurrenceDate),
        [CivilDate(2026, 6, 22), CivilDate(2026, 6, 29)],
        reason: "15 June's 9:00 reminder is past but still counts as one",
      );
    });

    test('keeps only the soonest maxCount, soonest first', () {
      final events = [
        for (var i = 1; i <= 10; i++)
          _event('e$i', date: CivilDate(2026, 6, 15 + i)),
      ];
      final planned = planReminders(events.reversed.toList(), now, maxCount: 3);
      expect(planned.map((r) => r.eventId), ['e1', 'e2', 'e3']);
    });
  });

  group('reminder text', () {
    test('birthdays say the age; unknown years do not', () {
      final known = _event(
        'b',
        title: "Asha's birthday",
        category: EventCategory.birthday,
        date: CivilDate(1990, 6, 20),
        recurrence: Recurrence.yearly,
      );
      final unknown = _event(
        'u',
        category: EventCategory.birthday,
        date: CivilDate(2000, 6, 20),
        recurrence: Recurrence.yearly,
        source: const EventSource(
          kind: EventSourceKind.contact,
          externalId: '1:birthday',
          yearKnown: false,
        ),
      );
      expect(planReminders([known], now).first.body, 'Turns 36 · Today');
      expect(planReminders([unknown], now).first.body, 'Today');
    });

    test('timed leads read naturally', () {
      final event = _event(
        't',
        date: CivilDate(2026, 6, 16),
        time: LocalTime(17, 0),
      );
      expect(_body(event, 0), 'Starting now');
      expect(_body(event, 30), 'In 30 minutes · 5:00 PM');
      expect(_body(event, 180), 'In 3 hours · 5:00 PM');
      expect(_body(event, 1440), 'Tomorrow · 5:00 PM');
      expect(_body(event, 10080), 'In 1 week · Tue, 16 Jun · 5:00 PM');
    });

    test('lead labels', () {
      expect(reminderLeadLabel(0), 'At start');
      expect(reminderLeadLabel(0, allDay: true), 'On the day');
      expect(reminderLeadLabel(10), '10 minutes before');
      expect(reminderLeadLabel(60), '1 hour before');
      expect(reminderLeadLabel(1440), '1 day before');
      expect(reminderLeadLabel(10080), '1 week before');
    });
  });

  test('IDs are stable, positive 31-bit and unique within a plan', () {
    final a = reminderId('event', CivilDate(2026, 6, 20), 60);
    expect(reminderId('event', CivilDate(2026, 6, 20), 60), a);
    expect(a, inInclusiveRange(1, 0x7fffffff));
    final events = [
      for (var i = 0; i < 40; i++)
        _event(
          'e$i',
          date: CivilDate(2026, 6, 16),
          time: LocalTime(18, 0),
          reminders: ReminderLeads.timed,
        ),
    ];
    final planned = planReminders(events, now, maxCount: 1000);
    expect(planned.map((r) => r.id).toSet(), hasLength(planned.length));
  });
}
