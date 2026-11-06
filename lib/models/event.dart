import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';

enum EventCategory {
  birthday,
  anniversary,
  travel,
  exam,
  meeting,
  event,
  importantDate,
  other,
}

const Object _unchanged = Object();

/// Where an imported event came from.
enum EventSourceKind { contact, calendar }

/// Links an event to the device record it was imported from, so importing
/// again skips it. The app never writes back to that record.
class EventSource {
  const EventSource({
    required this.kind,
    required this.externalId,
    this.yearKnown = true,
    this.group,
  });

  final EventSourceKind kind;

  /// Stable within [kind], e.g. `"42:birthday"` for a contact's birthday.
  final String externalId;

  /// `false` for a contact birthday saved without a year. The event's year
  /// is then only a placeholder and no age is shown.
  final bool yearKnown;

  /// The calendar's display name for calendar imports; `null` for contacts
  /// and for events imported before groups were recorded.
  final String? group;

  /// [kind] and [externalId] joined; unique across all sources.
  String get key => '${kind.name}:$externalId';

  @override
  bool operator ==(Object other) {
    return other is EventSource &&
        other.kind == kind &&
        other.externalId == externalId &&
        other.yearKnown == yearKnown &&
        other.group == group;
  }

  @override
  int get hashCode => Object.hash(kind, externalId, yearKnown, group);

  @override
  String toString() => 'EventSource($key${yearKnown ? '' : ', no year'})';
}

/// Reminder lead times, in minutes before an occurrence starts. All-day
/// occurrences "start" at [allDayReminderTime] for reminders.
abstract final class ReminderLeads {
  static const atStart = 0;
  static const tenMinutes = 10;
  static const thirtyMinutes = 30;
  static const oneHour = 60;
  static const threeHours = 180;
  static const oneDay = 1440;
  static const oneWeek = 10080;

  /// The choices offered for a timed event.
  static const timed = [
    atStart,
    tenMinutes,
    thirtyMinutes,
    oneHour,
    threeHours,
    oneDay,
    oneWeek,
  ];

  /// The choices offered for an all-day event.
  static const allDay = [atStart, oneDay, oneWeek];

  /// What a new event starts with.
  static List<int> defaultsFor({required bool allDay}) =>
      allDay ? const [atStart] : const [oneHour];
}

/// The hour of day at which an all-day event's reminders fire.
const int allDayReminderHour = 9;

/// Sorted, without duplicates or negative values, unmodifiable.
List<int> normalizeReminders(Iterable<int> minutes) {
  final unique = {
    for (final m in minutes)
      if (m >= 0) m,
  }.toList()..sort();
  return List.unmodifiable(unique);
}

/// A user-created event.
///
/// An event without a [time] is all-day. [enabled] is the Active state:
/// `false` means the event is paused.
class Event {
  Event({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    this.time,
    required this.recurrence,
    this.notes,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    List<int> reminders = const [],
    this.source,
    List<CivilDate> skippedDates = const [],
  }) : reminders = normalizeReminders(reminders),
       skippedDates = _normalizeDates(skippedDates),
       assert(id.isNotEmpty, 'id must not be empty'),
       assert(title.trim().isNotEmpty, 'title must not be blank'),
       assert(createdAt.isUtc, 'createdAt must be UTC'),
       assert(updatedAt.isUtc, 'updatedAt must be UTC');

  final String id;
  final String title;
  final EventCategory category;

  /// The event's date; for recurring events, the first occurrence.
  final CivilDate date;

  final LocalTime? time;
  final Recurrence recurrence;
  final String? notes;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Minutes before each occurrence at which to remind; sorted, unique.
  /// Empty means no reminders.
  final List<int> reminders;

  /// Set when the event was imported from contacts or the calendar.
  final EventSource? source;

  /// Dates of a repeating event the user removed ("delete this date only").
  /// Sorted, unique, unmodifiable.
  final List<CivilDate> skippedDates;

  bool isSkipped(CivilDate date) => skippedDates.contains(date);

  bool get isAllDay => time == null;

  /// `false` only for an imported birthday without a year.
  bool get yearKnown => source?.yearKnown ?? true;

  /// Pass `time: null`, `notes: null` or `source: null` to clear those
  /// fields.
  Event copyWith({
    String? id,
    String? title,
    EventCategory? category,
    CivilDate? date,
    Object? time = _unchanged,
    Recurrence? recurrence,
    Object? notes = _unchanged,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<int>? reminders,
    Object? source = _unchanged,
    List<CivilDate>? skippedDates,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      date: date ?? this.date,
      time: identical(time, _unchanged) ? this.time : time as LocalTime?,
      recurrence: recurrence ?? this.recurrence,
      notes: identical(notes, _unchanged) ? this.notes : notes as String?,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminders: reminders ?? this.reminders,
      source: identical(source, _unchanged)
          ? this.source
          : source as EventSource?,
      skippedDates: skippedDates ?? this.skippedDates,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Event &&
        other.id == id &&
        other.title == title &&
        other.category == category &&
        other.date == date &&
        other.time == time &&
        other.recurrence == recurrence &&
        other.notes == notes &&
        other.enabled == enabled &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        _sameInts(other.reminders, reminders) &&
        other.source == source &&
        _sameDates(other.skippedDates, skippedDates);
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    category,
    date,
    time,
    recurrence,
    notes,
    enabled,
    createdAt,
    updatedAt,
    Object.hashAll(reminders),
    source,
    Object.hashAll(skippedDates),
  );

  @override
  String toString() {
    return 'Event($id, "$title", ${category.name}, $date'
        '${time == null ? '' : ' $time'}, ${recurrence.name}, '
        '${enabled ? 'active' : 'paused'})';
  }
}

/// The birthday events in [events] whose date is exactly [date], active or
/// paused, in their given order.
List<Event> findBirthdaysOn(Iterable<Event> events, CivilDate date) {
  return [
    for (final event in events)
      if (event.category == EventCategory.birthday && event.date == date) event,
  ];
}

bool _sameInts(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _sameDates(List<CivilDate> a, List<CivilDate> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<CivilDate> _normalizeDates(Iterable<CivilDate> dates) {
  final unique = dates.toSet().toList()..sort();
  return List.unmodifiable(unique);
}

/// The title as compared for duplicates: case and spacing ignored.
String normalizedTitle(String title) =>
    title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
