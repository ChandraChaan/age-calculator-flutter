import 'dart:convert';

import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';

/// The event document version this build reads and writes.
const int eventSchemaVersion = 1;

/// Why a stored event document could not be read at all.
enum UnreadableReason {
  notJson,
  notAnObject,
  missingSchemaVersion,
  unsupportedSchemaVersion,
  missingEventList,
}

class EventDecodeResult {
  const EventDecodeResult({
    required this.events,
    this.unreadableReason,
    this.invalidEntries = const [],
    this.reassignedDuplicateIds = const [],
  });

  /// Valid events in stored order. Duplicates already carry their new IDs.
  final List<Event> events;

  /// Set when the whole document was rejected; [events] is then empty.
  final UnreadableReason? unreadableReason;

  /// Rejected entries, exactly as decoded from JSON.
  final List<Object?> invalidEntries;

  /// The original ID of every entry that received a new ID because an
  /// earlier entry already used it.
  final List<String> reassignedDuplicateIds;

  bool get isUnreadable => unreadableReason != null;
}

/// Converts events to and from the stored JSON document:
/// `{"schemaVersion": 1, "events": [...]}`.
class EventCodec {
  const EventCodec();

  static final DateTime _epoch = DateTime.utc(1970);
  static final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _timePattern = RegExp(r'^(\d{2}):(\d{2})$');
  static final Map<String, EventCategory> _categoriesByName = {
    for (final category in EventCategory.values)
      _categoryName(category): category,
  };
  static final Map<String, Recurrence> _recurrencesByName = {
    for (final recurrence in Recurrence.values)
      _recurrenceName(recurrence): recurrence,
  };

  String encodeDocument(List<Event> events) {
    return jsonEncode({
      'schemaVersion': eventSchemaVersion,
      'events': [for (final event in events) encodeEvent(event)],
    });
  }

  Map<String, Object?> encodeEvent(Event event) {
    return {
      'id': event.id,
      'title': event.title,
      'category': _categoryName(event.category),
      'date': event.date.toString(),
      'time': event.time?.toString(),
      'recurrence': _recurrenceName(event.recurrence),
      'notes': event.notes,
      'enabled': event.enabled,
      'createdAt': event.createdAt.toUtc().toIso8601String(),
      'updatedAt': event.updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Decodes a stored document. [newId] supplies replacement IDs for
  /// duplicate entries.
  EventDecodeResult decodeDocument(
    String raw, {
    required String Function() newId,
  }) {
    final Object? document;
    try {
      document = jsonDecode(raw);
    } on FormatException {
      return const EventDecodeResult(
        events: [],
        unreadableReason: UnreadableReason.notJson,
      );
    }

    if (document is! Map<String, Object?>) {
      return const EventDecodeResult(
        events: [],
        unreadableReason: UnreadableReason.notAnObject,
      );
    }
    final version = document['schemaVersion'];
    if (version is! int) {
      return const EventDecodeResult(
        events: [],
        unreadableReason: UnreadableReason.missingSchemaVersion,
      );
    }
    if (version != eventSchemaVersion) {
      return const EventDecodeResult(
        events: [],
        unreadableReason: UnreadableReason.unsupportedSchemaVersion,
      );
    }
    final entries = document['events'];
    if (entries is! List<Object?>) {
      return const EventDecodeResult(
        events: [],
        unreadableReason: UnreadableReason.missingEventList,
      );
    }

    final takenIds = {
      for (final entry in entries)
        if (entry is Map<String, Object?> && entry['id'] is String)
          entry['id']! as String,
    };
    final seenIds = <String>{};
    final events = <Event>[];
    final invalidEntries = <Object?>[];
    final reassigned = <String>[];

    for (final entry in entries) {
      final event = decodeEvent(entry);
      if (event == null) {
        invalidEntries.add(entry);
      } else if (seenIds.add(event.id)) {
        events.add(event);
      } else {
        final id = _freshId(newId, takenIds);
        takenIds.add(id);
        seenIds.add(id);
        reassigned.add(event.id);
        events.add(event.copyWith(id: id));
      }
    }

    return EventDecodeResult(
      events: events,
      invalidEntries: invalidEntries,
      reassignedDuplicateIds: reassigned,
    );
  }

  /// Returns `null` when [json] is not a valid event entry.
  Event? decodeEvent(Object? json) {
    if (json is! Map<String, Object?>) return null;

    final id = json['id'];
    final title = json['title'];
    if (id is! String || id.isEmpty) return null;
    if (title is! String || title.trim().isEmpty) return null;

    final date = _parseDate(json['date']);
    if (date == null) return null;

    final rawTime = json['time'];
    LocalTime? time;
    if (rawTime != null) {
      time = _parseTime(rawTime);
      if (time == null) return null;
    }

    final rawRecurrence = json['recurrence'];
    final recurrence = rawRecurrence == null
        ? Recurrence.none
        : _recurrencesByName[rawRecurrence];
    if (recurrence == null) return null;

    final rawCategory = json['category'];
    final rawNotes = json['notes'];
    final rawEnabled = json['enabled'];
    final created = _parseUtc(json['createdAt']);
    final updated = _parseUtc(json['updatedAt']);

    return Event(
      id: id,
      title: title,
      category: _categoriesByName[rawCategory] ?? EventCategory.other,
      date: date,
      time: time,
      recurrence: recurrence,
      notes: rawNotes is String ? rawNotes : null,
      enabled: rawEnabled is bool ? rawEnabled : true,
      createdAt: created ?? updated ?? _epoch,
      updatedAt: updated ?? created ?? _epoch,
    );
  }

  static String _categoryName(EventCategory category) {
    return switch (category) {
      EventCategory.birthday => 'birthday',
      EventCategory.anniversary => 'anniversary',
      EventCategory.travel => 'travel',
      EventCategory.exam => 'exam',
      EventCategory.meeting => 'meeting',
      EventCategory.event => 'event',
      EventCategory.importantDate => 'important_date',
      EventCategory.other => 'other',
    };
  }

  static String _recurrenceName(Recurrence recurrence) {
    return switch (recurrence) {
      Recurrence.none => 'none',
      Recurrence.daily => 'daily',
      Recurrence.weekly => 'weekly',
      Recurrence.monthly => 'monthly',
      Recurrence.yearly => 'yearly',
    };
  }

  static CivilDate? _parseDate(Object? value) {
    if (value is! String) return null;
    final match = _datePattern.firstMatch(value);
    if (match == null) return null;
    try {
      return CivilDate(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      );
    } on ArgumentError {
      return null;
    }
  }

  static LocalTime? _parseTime(Object? value) {
    if (value is! String) return null;
    final match = _timePattern.firstMatch(value);
    if (match == null) return null;
    try {
      return LocalTime(int.parse(match[1]!), int.parse(match[2]!));
    } on ArgumentError {
      return null;
    }
  }

  /// Accepts ISO-8601 timestamps that state their offset (`Z` or `±hh:mm`).
  /// A timestamp without an offset would depend on the device time zone, so
  /// it counts as malformed.
  static DateTime? _parseUtc(Object? value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) return null;
    return parsed;
  }

  static String _freshId(String Function() newId, Set<String> taken) {
    for (var attempt = 0; attempt < 1000; attempt++) {
      final id = newId();
      if (id.isNotEmpty && !taken.contains(id)) return id;
    }
    throw StateError('Could not generate a unique event id');
  }
}
