import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/services/device_import.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/upcoming_fixtures.dart';

void main() {
  group('parseContactDate', () {
    test('reads the formats contacts use', () {
      expect(parseContactDate('1990-05-14'), (
        date: CivilDate(1990, 5, 14),
        yearKnown: true,
      ));
      expect(parseContactDate('19900514'), (
        date: CivilDate(1990, 5, 14),
        yearKnown: true,
      ));
      expect(parseContactDate('1990-05-14T00:00:00.000Z'), (
        date: CivilDate(1990, 5, 14),
        yearKnown: true,
      ));
      expect(parseContactDate('--05-14'), (
        date: CivilDate(unknownYearPlaceholder, 5, 14),
        yearKnown: false,
      ));
      expect(parseContactDate('--0229'), (
        date: CivilDate(unknownYearPlaceholder, 2, 29),
        yearKnown: false,
      ));
    });

    test('rejects what it cannot read', () {
      for (final raw in [null, '', 'May 14', '1990-13-01', '1990-02-30']) {
        expect(parseContactDate(raw), isNull, reason: '$raw');
      }
    });
  });

  group('contactCandidates', () {
    final rows = [
      {
        'contactId': '7',
        'name': 'Ravi',
        'date': '1988-09-02',
        'type': 'birthday',
      },
      {'contactId': '3', 'name': 'Asha', 'date': '--03-21', 'type': 'birthday'},
      {
        'contactId': '3',
        'name': 'Asha',
        'date': '2015-11-30',
        'type': 'anniversary',
      },
      // Same contact and type twice (two raw contacts): kept once.
      {
        'contactId': '7',
        'name': 'Ravi',
        'date': '1988-09-02',
        'type': 'birthday',
      },
      {'contactId': '9', 'name': 'No date', 'date': 'soon', 'type': 'birthday'},
    ];

    test('makes yearly all-day events sorted by title', () {
      final candidates = contactCandidates(rows, const []);
      expect(candidates.map((c) => c.draft.title), [
        "Asha's anniversary",
        "Asha's birthday",
        "Ravi's birthday",
      ]);
      final asha = candidates[1].draft;
      expect(asha.category, EventCategory.birthday);
      expect(asha.recurrence, Recurrence.yearly);
      expect(asha.isAllDay, isTrue);
      expect(asha.yearKnown, isFalse);
      expect(asha.reminders, [ReminderLeads.atStart]);
      expect(candidates[0].draft.category, EventCategory.anniversary);
    });

    test('marks what was imported before', () {
      final first = contactCandidates(rows, const []);
      final saved = [
        first.last.draft.copyWith(id: 'saved', createdAt: DateTime.utc(2026)),
      ];
      final again = contactCandidates(rows, saved);
      expect(again.map((c) => c.alreadyImported), [false, false, true]);
    });

    test('a birthday without a year shows no age', () {
      final asha = contactCandidates(rows, const [])[1].draft;
      final plan = planUpcoming([asha], fixedNow());
      expect(plan.next!.date, CivilDate(2027, 3, 21));
      expect(plan.next!.yearsSinceAnchor, isNull);
    });
  });

  group('calendarCandidates', () {
    final now = fixedNow();
    int ms(DateTime t) => t.millisecondsSinceEpoch;

    test('one event per calendar event, keeping its next start', () {
      final rows = [
        {
          'eventId': '10',
          'title': 'Standup',
          'begin': ms(DateTime(2026, 6, 16, 9, 30)),
          'allDay': false,
          'rrule': 'FREQ=WEEKLY;BYDAY=TU',
          'calendar': 'Work',
        },
        {
          'eventId': '10',
          'title': 'Standup',
          'begin': ms(DateTime(2026, 6, 23, 9, 30)),
          'allDay': false,
          'rrule': 'FREQ=WEEKLY;BYDAY=TU',
        },
        {
          'eventId': '11',
          'title': 'Holiday',
          'begin': DateTime.utc(2026, 8, 15).millisecondsSinceEpoch,
          'allDay': true,
        },
        {
          'eventId': '12',
          'title': 'Already started',
          'begin': ms(DateTime(2026, 6, 15, 8)),
          'allDay': false,
        },
      ];
      final candidates = calendarCandidates(rows, const [], now);
      expect(candidates.map((c) => c.draft.title), ['Standup', 'Holiday']);
      final standup = candidates.first.draft;
      expect(standup.date, CivilDate(2026, 6, 16));
      expect(standup.time, LocalTime(9, 30));
      expect(standup.recurrence, Recurrence.weekly);
      expect(standup.notes, 'From calendar: Work');
      expect(standup.reminders, isEmpty);
      final holiday = candidates.last.draft;
      expect(holiday.date, CivilDate(2026, 8, 15));
      expect(holiday.isAllDay, isTrue);
    });
  });

  test('recurrenceFromRrule keeps only repeats the app can express', () {
    expect(recurrenceFromRrule(null), Recurrence.none);
    expect(recurrenceFromRrule('FREQ=DAILY'), Recurrence.daily);
    expect(recurrenceFromRrule('FREQ=WEEKLY;BYDAY=MO'), Recurrence.weekly);
    expect(recurrenceFromRrule('FREQ=WEEKLY;BYDAY=MO,WE'), Recurrence.none);
    expect(recurrenceFromRrule('FREQ=WEEKLY;INTERVAL=2'), Recurrence.none);
    expect(
      recurrenceFromRrule('FREQ=MONTHLY;BYMONTHDAY=5'),
      Recurrence.monthly,
    );
    expect(recurrenceFromRrule('FREQ=MONTHLY;BYDAY=2TU'), Recurrence.none);
    expect(recurrenceFromRrule('FREQ=YEARLY'), Recurrence.yearly);
    expect(recurrenceFromRrule('FREQ=DAILY;COUNT=5'), Recurrence.none);
    expect(
      recurrenceFromRrule('FREQ=DAILY;UNTIL=20261231T000000Z'),
      Recurrence.none,
    );
  });
}
