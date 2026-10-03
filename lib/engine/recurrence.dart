import 'package:agecalculator/engine/calendar_math.dart';
import 'package:agecalculator/engine/civil_date.dart';

/// How an event repeats, counted from the event's own date.
enum Recurrence { none, daily, weekly, monthly, yearly }

/// The [index]-th occurrence (0 = [anchor] itself) of an event that starts on
/// [anchor].
///
/// Every occurrence is computed from [anchor], never from the previous one,
/// so month-end dates don't drift:
/// - monthly: days 29–31 clamp to the last day of shorter months
///   (31 Jan → 28/29 Feb → 31 Mar);
/// - yearly: [CalendarMath.birthdayInYear], the age calculator's rule
///   (29 Feb → 28 Feb in non-leap years).
CivilDate occurrenceDate(CivilDate anchor, Recurrence recurrence, int index) {
  if (index < 0) {
    throw RangeError.value(index, 'index', 'must not be negative');
  }
  return switch (recurrence) {
    Recurrence.none =>
      index == 0
          ? anchor
          : throw RangeError.value(
              index,
              'index',
              'a one-time event has only index 0',
            ),
    Recurrence.daily => anchor.addDays(index),
    Recurrence.weekly => anchor.addDays(DateTime.daysPerWeek * index),
    Recurrence.monthly => _monthlyOccurrence(anchor, index),
    Recurrence.yearly => CalendarMath.birthdayInYear(
      anchor,
      anchor.year + index,
    ),
  };
}

/// The first occurrence on or after [from], or `null` when a one-time event
/// is already in the past.
CivilDate? firstOccurrenceOnOrAfter(
  CivilDate anchor,
  Recurrence recurrence,
  CivilDate from,
) {
  if (!from.isAfter(anchor)) {
    return anchor;
  }

  final daysSinceAnchor = anchor.daysUntil(from);
  switch (recurrence) {
    case Recurrence.none:
      return null;
    case Recurrence.daily:
      return occurrenceDate(anchor, recurrence, daysSinceAnchor);
    case Recurrence.weekly:
      final weeks =
          (daysSinceAnchor + DateTime.daysPerWeek - 1) ~/ DateTime.daysPerWeek;
      return occurrenceDate(anchor, recurrence, weeks);
    case Recurrence.monthly:
      final months =
          (from.year - anchor.year) * 12 + (from.month - anchor.month);
      return _sameOrNext(anchor, recurrence, months, from);
    case Recurrence.yearly:
      return _sameOrNext(anchor, recurrence, from.year - anchor.year, from);
  }
}

/// Occurrence [index] if it is on or after [from], otherwise the next one.
CivilDate _sameOrNext(
  CivilDate anchor,
  Recurrence recurrence,
  int index,
  CivilDate from,
) {
  final candidate = occurrenceDate(anchor, recurrence, index);
  return candidate.isBefore(from)
      ? occurrenceDate(anchor, recurrence, index + 1)
      : candidate;
}

CivilDate _monthlyOccurrence(CivilDate anchor, int index) {
  final monthIndex = anchor.year * 12 + (anchor.month - 1) + index;
  final month = monthIndex % 12 + 1;
  final year = monthIndex ~/ 12;
  final lastDay = CalendarMath.daysInMonth(year, month);
  return CivilDate(year, month, anchor.day < lastDay ? anchor.day : lastDay);
}
