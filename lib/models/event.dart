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
  }) : assert(id.isNotEmpty, 'id must not be empty'),
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

  bool get isAllDay => time == null;

  /// Pass `time: null` or `notes: null` to clear those fields.
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
        other.updatedAt == updatedAt;
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
