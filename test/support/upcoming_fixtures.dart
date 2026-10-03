import 'package:agecalculator/data/event_codec.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';

/// Monday 15 June 2026, 12:00 local time.
DateTime fixedNow() => DateTime(2026, 6, 15, 12);

/// A controllable local clock.
class TestClock {
  TestClock([DateTime? now]) : now = now ?? fixedNow();

  DateTime now;
  int calls = 0;

  DateTime call() {
    calls++;
    return now;
  }
}

Event testEvent(
  String id,
  String title, {
  EventCategory category = EventCategory.event,
  required CivilDate date,
  LocalTime? time,
  Recurrence recurrence = Recurrence.none,
  bool enabled = true,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 1, 1);
  return Event(
    id: id,
    title: title,
    category: category,
    date: date,
    time: time,
    recurrence: recurrence,
    enabled: enabled,
    createdAt: created,
    updatedAt: created,
  );
}

/// Twelve events that, as of [fixedNow], fill every Upcoming section.
List<Event> mixedEvents() => [
  testEvent(
    'review',
    'Project review',
    category: EventCategory.meeting,
    date: CivilDate(2026, 6, 15),
    time: LocalTime(14, 30),
  ),
  testEvent(
    'mom',
    "Mom's birthday",
    category: EventCategory.birthday,
    date: CivilDate(1970, 6, 15),
    recurrence: Recurrence.yearly,
  ),
  testEvent(
    'run',
    'Morning run',
    category: EventCategory.other,
    date: CivilDate(2026, 6, 1),
    time: LocalTime(9, 0),
    recurrence: Recurrence.daily,
  ),
  testEvent(
    'flight',
    'Flight to Goa',
    category: EventCategory.travel,
    date: CivilDate(2026, 6, 18),
  ),
  testEvent(
    'lunch',
    'Team lunch',
    date: CivilDate(2026, 6, 5),
    recurrence: Recurrence.weekly,
  ),
  testEvent(
    'exam',
    'Final exam',
    category: EventCategory.exam,
    date: CivilDate(2026, 7, 1),
    time: LocalTime(9, 30),
  ),
  testEvent(
    'anniversary',
    'Wedding anniversary',
    category: EventCategory.anniversary,
    date: CivilDate(2010, 8, 25),
    recurrence: Recurrence.yearly,
  ),
  testEvent(
    'rent',
    'Rent',
    category: EventCategory.importantDate,
    date: CivilDate(2026, 1, 31),
    recurrence: Recurrence.monthly,
  ),
  testEvent(
    'dentist',
    'Dentist',
    category: EventCategory.other,
    date: CivilDate(2026, 6, 10),
  ),
  testEvent(
    'standup',
    'Old meeting',
    category: EventCategory.meeting,
    date: CivilDate(2026, 6, 15),
    time: LocalTime(9, 0),
  ),
  testEvent(
    'trip',
    'Paused trip',
    category: EventCategory.travel,
    date: CivilDate(2026, 6, 17),
    enabled: false,
    createdAt: DateTime.utc(2026, 2, 1),
  ),
  testEvent(
    'old-birthday',
    'Paused birthday',
    category: EventCategory.birthday,
    date: CivilDate(1990, 1, 1),
    recurrence: Recurrence.yearly,
    enabled: false,
  ),
];

Map<String, Object> storedEvents(List<Event> events) => {
  'flutter.event_store': const EventCodec().encodeDocument(events),
};

/// [label] as displayed: each number joined to its unit by a no-break space.
String displayed(String label) =>
    label.replaceAll(RegExp(r'(?<=\d) '), '\u00A0');
