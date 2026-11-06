import 'dart:io' show Platform;

import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ImportKind { contacts, calendar }

enum ImportPermission {
  granted,
  denied,

  /// Android no longer shows the prompt; only system Settings can grant it.
  blocked,
}

/// One event found on the device, ready to import.
class ImportCandidate {
  const ImportCandidate({required this.draft, required this.alreadyImported});

  /// The event to add; its ID and timestamps are placeholders that
  /// [EventController.addAll] replaces.
  final Event draft;

  /// An event from the same source record is already saved.
  final bool alreadyImported;

  String get key => draft.source!.key;
}

/// Reads contacts and calendars on Android. Read-only, on-device only.
class DeviceImporter {
  DeviceImporter({bool? enabled})
    : enabled = enabled ?? (!kIsWeb && Platform.isAndroid);

  static const channel = MethodChannel(
    'com.chandra.agecalculator/device_import',
  );

  /// How far ahead calendar events are read.
  static const calendarDays = 180;

  final bool enabled;

  Future<ImportPermission> permission(ImportKind kind) async {
    final raw = await channel.invokeMethod<String>('permissionStatus', {
      'kind': kind.name,
    });
    return _permission(raw);
  }

  Future<ImportPermission> requestPermission(ImportKind kind) async {
    final raw = await channel.invokeMethod<String>('requestPermission', {
      'kind': kind.name,
    });
    return _permission(raw);
  }

  Future<void> openAppSettings() => channel.invokeMethod('openAppSettings');

  /// Everything importable of [kind], with what is already saved marked.
  Future<List<ImportCandidate>> candidates(
    ImportKind kind,
    List<Event> existing,
    DateTime now,
  ) async {
    switch (kind) {
      case ImportKind.contacts:
        final rows = await channel.invokeListMethod<Object?>('contactEvents');
        return contactCandidates(rows ?? const [], existing);
      case ImportKind.calendar:
        final rows = await channel.invokeListMethod<Object?>('calendarEvents', {
          'days': calendarDays,
        });
        return calendarCandidates(rows ?? const [], existing, now);
    }
  }

  static ImportPermission _permission(String? raw) => switch (raw) {
    'granted' => ImportPermission.granted,
    'blocked' => ImportPermission.blocked,
    _ => ImportPermission.denied,
  };
}

/// The year given to a contact date saved without one. A leap year, so
/// 29 February stays valid.
const int unknownYearPlaceholder = 2000;

final DateTime _placeholderTime = DateTime.utc(1970);

/// Parses the date formats Android contacts use: `1990-05-14`, `19900514`,
/// `--05-14` and `--0514` (no year), and ISO timestamps. `null` if
/// unreadable.
({CivilDate date, bool yearKnown})? parseContactDate(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  final noYear = RegExp(r'^--(\d{2})-?(\d{2})$').firstMatch(value);
  if (noYear != null) {
    final date = _date(
      unknownYearPlaceholder,
      int.parse(noYear[1]!),
      int.parse(noYear[2]!),
    );
    return date == null ? null : (date: date, yearKnown: false);
  }
  final full = RegExp(
    r'^(\d{4})-?(\d{2})-?(\d{2})(?:[T ].*)?$',
  ).firstMatch(value);
  if (full == null) return null;
  final date = _date(
    int.parse(full[1]!),
    int.parse(full[2]!),
    int.parse(full[3]!),
  );
  return date == null ? null : (date: date, yearKnown: true);
}

CivilDate? _date(int year, int month, int day) {
  try {
    return CivilDate(year, month, day);
  } on ArgumentError {
    return null;
  }
}

/// Contact birthdays and anniversaries as yearly all-day events, one per
/// contact and type, sorted by name.
List<ImportCandidate> contactCandidates(
  List<Object?> rows,
  List<Event> existing,
) {
  final saved = _savedKeys(existing);
  final seen = <String>{};
  final candidates = <ImportCandidate>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final contactId = row['contactId'];
    final name = row['name'];
    final type = row['type'] == 'anniversary' ? 'anniversary' : 'birthday';
    if (contactId is! String || name is! String || name.trim().isEmpty) {
      continue;
    }
    final parsed = parseContactDate(row['date'] as String?);
    if (parsed == null) continue;
    final source = EventSource(
      kind: EventSourceKind.contact,
      externalId: '$contactId:$type',
      yearKnown: parsed.yearKnown,
    );
    if (!seen.add(source.key)) continue;
    final birthday = type == 'birthday';
    candidates.add(
      ImportCandidate(
        draft: Event(
          id: 'import',
          title: birthday
              ? "${name.trim()}'s birthday"
              : "${name.trim()}'s anniversary",
          category: birthday
              ? EventCategory.birthday
              : EventCategory.anniversary,
          date: parsed.date,
          recurrence: Recurrence.yearly,
          enabled: true,
          createdAt: _placeholderTime,
          updatedAt: _placeholderTime,
          reminders: ReminderLeads.defaultsFor(allDay: true),
          source: source,
        ),
        alreadyImported: saved.contains(source.key),
      ),
    );
  }
  candidates.sort(
    (a, b) =>
        a.draft.title.toLowerCase().compareTo(b.draft.title.toLowerCase()),
  );
  return candidates;
}

/// Calendar instances as events: one per calendar event (its next
/// occurrence), soonest first. Repeats the app can express are kept; other
/// repeating events become one-time events on their next date.
///
/// They get no reminders by default, because the calendar app already
/// reminds about them.
List<ImportCandidate> calendarCandidates(
  List<Object?> rows,
  List<Event> existing,
  DateTime now,
) {
  final saved = _savedKeys(existing);
  final seen = <String>{};
  final candidates = <ImportCandidate>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final eventId = row['eventId'];
    final title = row['title'];
    final begin = row['begin'];
    if (eventId is! String || title is! String || title.trim().isEmpty) {
      continue;
    }
    if (begin is! int) continue;
    final source = EventSource(
      kind: EventSourceKind.calendar,
      externalId: eventId,
    );
    final allDay = row['allDay'] == true;
    final CivilDate date;
    LocalTime? time;
    if (allDay) {
      // All-day instances begin at UTC midnight of their date.
      date = CivilDate.fromDateTime(
        DateTime.fromMillisecondsSinceEpoch(begin, isUtc: true),
      );
      // A multi-day event that is already under way.
      if (date.isBefore(CivilDate.fromDateTime(now.toLocal()))) continue;
    } else {
      final start = DateTime.fromMillisecondsSinceEpoch(begin);
      if (start.isBefore(now)) continue;
      date = CivilDate.fromDateTime(start);
      time = LocalTime(start.hour, start.minute);
    }
    if (!seen.add(source.key)) continue;
    final calendar = row['calendar'];
    candidates.add(
      ImportCandidate(
        draft: Event(
          id: 'import',
          title: title.trim(),
          category: EventCategory.event,
          date: date,
          time: time,
          recurrence: recurrenceFromRrule(row['rrule'] as String?),
          notes: calendar is String && calendar.trim().isNotEmpty
              ? 'From calendar: ${calendar.trim()}'
              : null,
          enabled: true,
          createdAt: _placeholderTime,
          updatedAt: _placeholderTime,
          source: source,
        ),
        alreadyImported: saved.contains(source.key),
      ),
    );
  }
  return candidates;
}

/// The app's [Recurrence] for an RFC 5545 rule, or [Recurrence.none] when
/// the rule needs more than the app can express (intervals, several
/// weekdays, an end date or count, "second Tuesday").
Recurrence recurrenceFromRrule(String? rrule) {
  if (rrule == null || rrule.trim().isEmpty) return Recurrence.none;
  final parts = <String, String>{};
  for (final part in rrule.toUpperCase().split(';')) {
    final eq = part.indexOf('=');
    if (eq > 0) parts[part.substring(0, eq).trim()] = part.substring(eq + 1);
  }
  final interval = parts['INTERVAL'];
  if (interval != null && interval != '1') return Recurrence.none;
  if (parts.containsKey('COUNT') || parts.containsKey('UNTIL')) {
    return Recurrence.none;
  }
  final byDay = parts['BYDAY'];
  final freq = parts['FREQ'];
  switch (freq) {
    case 'DAILY':
      return byDay == null ? Recurrence.daily : Recurrence.none;
    case 'WEEKLY':
      return byDay == null || !byDay.contains(',')
          ? Recurrence.weekly
          : Recurrence.none;
    case 'MONTHLY':
      return byDay == null && !parts.containsKey('BYSETPOS')
          ? Recurrence.monthly
          : Recurrence.none;
    case 'YEARLY':
      return byDay == null ? Recurrence.yearly : Recurrence.none;
  }
  return Recurrence.none;
}

Set<String> _savedKeys(List<Event> events) => {
  for (final event in events)
    if (event.source case final source?) source.key,
};
