import 'dart:convert';

import 'package:agecalculator/data/event_codec.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

const _codec = EventCodec();
final _created = DateTime.utc(2026, 10, 3, 2);
final _updated = DateTime.utc(2026, 10, 3, 2, 30);

Event _event({
  String id = 'evt-1',
  String title = "Sai's birthday",
  EventCategory category = EventCategory.birthday,
  CivilDate? date,
  LocalTime? time,
  Recurrence recurrence = Recurrence.yearly,
  String? notes,
  bool enabled = true,
}) {
  return Event(
    id: id,
    title: title,
    category: category,
    date: date ?? CivilDate(1999, 8, 25),
    time: time,
    recurrence: recurrence,
    notes: notes,
    enabled: enabled,
    createdAt: _created,
    updatedAt: _updated,
  );
}

/// A valid stored entry with [overrides] applied and [remove] keys dropped.
Map<String, Object?> _entry([
  Map<String, Object?> overrides = const {},
  Set<String> remove = const {},
]) {
  final entry = <String, Object?>{
    'id': 'evt-1',
    'title': 'Exam',
    'category': 'exam',
    'date': '2026-11-14',
    'time': null,
    'recurrence': 'none',
    'notes': null,
    'enabled': true,
    'createdAt': '2026-10-03T02:00:00.000Z',
    'updatedAt': '2026-10-03T02:30:00.000Z',
    ...overrides,
  };
  remove.forEach(entry.remove);
  return entry;
}

String _document(List<Object?> entries, {Object? schemaVersion = 1}) {
  return jsonEncode({'schemaVersion': schemaVersion, 'events': entries});
}

String Function() _ids(List<String> ids) {
  var index = 0;
  return () => ids[index++];
}

String _noIdsNeeded() => throw StateError('no new id expected');

EventDecodeResult _decode(String raw, {String Function()? newId}) {
  return _codec.decodeDocument(raw, newId: newId ?? _noIdsNeeded);
}

Event? _decodeEntry(Map<String, Object?> entry) => _codec.decodeEvent(entry);

void main() {
  group('Event model', () {
    test('an event without a time is all-day', () {
      expect(_event().isAllDay, isTrue);
      expect(_event().time, isNull);
      final timed = _event(time: LocalTime(17, 0));
      expect(timed.isAllDay, isFalse);
      expect(timed.time, LocalTime(17, 0));
    });

    test('enabled is the Active state: true active, false paused', () {
      expect(_event(enabled: true).enabled, isTrue);
      expect(_event(enabled: false).enabled, isFalse);
      expect(_event(enabled: false).toString(), contains('paused'));
      expect(_event(enabled: true).toString(), contains('active'));
    });

    test('equality and hashing cover every field', () {
      final base = _event(time: LocalTime(9, 0), notes: 'Hall 3');
      expect(base, _event(time: LocalTime(9, 0), notes: 'Hall 3'));
      expect(
        base.hashCode,
        _event(time: LocalTime(9, 0), notes: 'Hall 3').hashCode,
      );

      final variants = [
        base.copyWith(id: 'evt-2'),
        base.copyWith(title: 'Other title'),
        base.copyWith(category: EventCategory.exam),
        base.copyWith(date: CivilDate(1999, 8, 26)),
        base.copyWith(time: LocalTime(9, 1)),
        base.copyWith(recurrence: Recurrence.none),
        base.copyWith(notes: 'Hall 4'),
        base.copyWith(enabled: false),
        base.copyWith(createdAt: DateTime.utc(2026)),
        base.copyWith(updatedAt: DateTime.utc(2026)),
      ];
      for (final variant in variants) {
        expect(variant, isNot(base), reason: '$variant');
      }
    });

    test('copyWith keeps unspecified fields and can clear time and notes', () {
      final base = _event(time: LocalTime(9, 0), notes: 'Hall 3');
      expect(base.copyWith(), base);
      expect(base.copyWith(title: 'Renamed').time, LocalTime(9, 0));
      expect(base.copyWith(title: 'Renamed').notes, 'Hall 3');
      expect(base.copyWith(time: null).time, isNull);
      expect(base.copyWith(time: null).isAllDay, isTrue);
      expect(base.copyWith(notes: null).notes, isNull);
    });

    test('rejects empty id, blank title and non-UTC timestamps', () {
      expect(() => _event(id: ''), throwsA(isA<AssertionError>()));
      expect(() => _event(title: '   '), throwsA(isA<AssertionError>()));
      expect(
        () => _event().copyWith(createdAt: DateTime(2026, 10, 3)),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => _event().copyWith(updatedAt: DateTime(2026, 10, 3)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('categories are exactly the v1.1 set', () {
      expect(EventCategory.values, [
        EventCategory.birthday,
        EventCategory.anniversary,
        EventCategory.travel,
        EventCategory.exam,
        EventCategory.meeting,
        EventCategory.event,
        EventCategory.importantDate,
        EventCategory.other,
      ]);
    });

    test('recurrences are exactly none, daily, weekly, monthly, yearly', () {
      expect(Recurrence.values, [
        Recurrence.none,
        Recurrence.daily,
        Recurrence.weekly,
        Recurrence.monthly,
        Recurrence.yearly,
      ]);
    });
  });

  group('EM-01 round trip', () {
    test('every category × recurrence × all-day/timed × notes', () {
      var n = 0;
      final events = <Event>[];
      for (final category in EventCategory.values) {
        for (final recurrence in Recurrence.values) {
          for (final time in [null, LocalTime(0, 0), LocalTime(23, 59)]) {
            for (final notes in [null, 'Bring the admit card\nand a pen']) {
              for (final enabled in [true, false]) {
                events.add(
                  _event(
                    id: 'evt-${n++}',
                    category: category,
                    recurrence: recurrence,
                    time: time,
                    notes: notes,
                    enabled: enabled,
                  ),
                );
              }
            }
          }
        }
      }

      for (final event in events) {
        expect(_codec.decodeEvent(_codec.encodeEvent(event)), event);
      }

      final result = _decode(_codec.encodeDocument(events));
      expect(result.isUnreadable, isFalse);
      expect(result.invalidEntries, isEmpty);
      expect(result.reassignedDuplicateIds, isEmpty);
      expect(result.events, events, reason: 'same events in the same order');
    });

    test('dates across the supported range and leap days survive', () {
      for (final date in [
        CivilDate(1900, 1, 1),
        CivilDate(2000, 2, 29),
        CivilDate(2024, 2, 29),
        CivilDate(2026, 12, 31),
        CivilDate(2100, 12, 31),
      ]) {
        final event = _event(date: date);
        expect(_codec.decodeEvent(_codec.encodeEvent(event)), event);
      }
    });

    test('timestamps keep sub-second precision and stay UTC', () {
      final event = _event().copyWith(
        createdAt: DateTime.utc(2026, 10, 3, 2, 0, 0, 123, 456),
        updatedAt: DateTime.utc(2026, 10, 3, 2, 0, 1),
      );
      final decoded = _codec.decodeEvent(_codec.encodeEvent(event))!;
      expect(decoded.createdAt, event.createdAt);
      expect(decoded.updatedAt, event.updatedAt);
      expect(decoded.createdAt.isUtc, isTrue);
    });

    test('an empty list round-trips', () {
      final raw = _codec.encodeDocument(const []);
      expect(raw, '{"schemaVersion":1,"events":[]}');
      final result = _decode(raw);
      expect(result.isUnreadable, isFalse);
      expect(result.events, isEmpty);
    });

    test('encoding is deterministic', () {
      final events = [
        _event(),
        _event(id: 'evt-2', time: LocalTime(17, 0), notes: 'x'),
      ];
      final first = _codec.encodeDocument(events);
      expect(_codec.encodeDocument(events), first);
      expect(_codec.encodeDocument(_decode(first).events), first);
    });
  });

  group('EM-02 exact JSON format', () {
    test('golden document with an all-day and a timed event', () {
      final events = [
        _event(),
        Event(
          id: 'evt-2',
          title: 'Team meeting',
          category: EventCategory.meeting,
          date: CivilDate(2026, 10, 9),
          time: LocalTime(17, 0),
          recurrence: Recurrence.weekly,
          notes: 'Room 4',
          enabled: false,
          createdAt: DateTime.utc(2026, 10, 1, 8, 15),
          updatedAt: DateTime.utc(2026, 10, 2, 9, 45, 30, 250),
        ),
      ];

      expect(
        _codec.encodeDocument(events),
        '{"schemaVersion":1,"events":['
        '{"id":"evt-1","title":"Sai\'s birthday","category":"birthday",'
        '"date":"1999-08-25","time":null,"recurrence":"yearly","notes":null,'
        '"enabled":true,"createdAt":"2026-10-03T02:00:00.000Z",'
        '"updatedAt":"2026-10-03T02:30:00.000Z"},'
        '{"id":"evt-2","title":"Team meeting","category":"meeting",'
        '"date":"2026-10-09","time":"17:00","recurrence":"weekly",'
        '"notes":"Room 4","enabled":false,'
        '"createdAt":"2026-10-01T08:15:00.000Z",'
        '"updatedAt":"2026-10-02T09:45:30.250Z"}'
        ']}',
      );
    });

    test('category and recurrence wire names', () {
      String categoryOf(EventCategory c) =>
          _codec.encodeEvent(_event(category: c))['category']! as String;
      String recurrenceOf(Recurrence r) =>
          _codec.encodeEvent(_event(recurrence: r))['recurrence']! as String;

      expect(EventCategory.values.map(categoryOf), [
        'birthday',
        'anniversary',
        'travel',
        'exam',
        'meeting',
        'event',
        'important_date',
        'other',
      ]);
      expect(Recurrence.values.map(recurrenceOf), [
        'none',
        'daily',
        'weekly',
        'monthly',
        'yearly',
      ]);
    });
  });

  group('EM-03 schema version', () {
    test('version 1 is written and read', () {
      final raw = _codec.encodeDocument([_event()]);
      expect(jsonDecode(raw)['schemaVersion'], 1);
      expect(eventSchemaVersion, 1);
      expect(_decode(raw).events, [_event()]);
    });

    test('missing or non-integer versions are unreadable', () {
      for (final raw in [
        jsonEncode({'events': <Object?>[]}),
        _document([], schemaVersion: null),
        _document([], schemaVersion: '1'),
        _document([], schemaVersion: 1.5),
        _document([], schemaVersion: true),
      ]) {
        final result = _decode(raw);
        expect(result.unreadableReason, UnreadableReason.missingSchemaVersion);
        expect(result.events, isEmpty);
      }
    });

    test('other versions are unreadable', () {
      for (final version in [0, 2, 99, -1]) {
        final result = _decode(_document([_entry()], schemaVersion: version));
        expect(
          result.unreadableReason,
          UnreadableReason.unsupportedSchemaVersion,
          reason: 'version $version',
        );
        expect(result.events, isEmpty);
      }
    });
  });

  group('EM-04 defaults for missing optional fields', () {
    test('category: missing, unknown or non-string → other', () {
      expect(
        _decodeEntry(_entry({}, {'category'}))!.category,
        EventCategory.other,
      );
      expect(
        _decodeEntry(_entry({'category': 'party'}))!.category,
        EventCategory.other,
      );
      expect(
        _decodeEntry(_entry({'category': 3}))!.category,
        EventCategory.other,
      );
      expect(
        _decodeEntry(_entry({'category': 'important_date'}))!.category,
        EventCategory.importantDate,
      );
    });

    test('enabled: missing or non-bool → true; false is kept', () {
      expect(_decodeEntry(_entry({}, {'enabled'}))!.enabled, isTrue);
      expect(_decodeEntry(_entry({'enabled': 'no'}))!.enabled, isTrue);
      expect(_decodeEntry(_entry({'enabled': null}))!.enabled, isTrue);
      expect(_decodeEntry(_entry({'enabled': false}))!.enabled, isFalse);
    });

    test('recurrence: missing or null → none', () {
      expect(
        _decodeEntry(_entry({}, {'recurrence'}))!.recurrence,
        Recurrence.none,
      );
      expect(
        _decodeEntry(_entry({'recurrence': null}))!.recurrence,
        Recurrence.none,
      );
    });

    test('time: missing or null → all-day', () {
      expect(_decodeEntry(_entry({}, {'time'}))!.isAllDay, isTrue);
      expect(_decodeEntry(_entry({'time': null}))!.isAllDay, isTrue);
      expect(_decodeEntry(_entry({'time': '07:05'}))!.time, LocalTime(7, 5));
    });

    test('notes: missing, null or non-string → null; text is kept as is', () {
      expect(_decodeEntry(_entry({}, {'notes'}))!.notes, isNull);
      expect(_decodeEntry(_entry({'notes': 42}))!.notes, isNull);
      expect(
        _decodeEntry(
          _entry({
            'notes': ['a'],
          }),
        )!.notes,
        isNull,
      );
      expect(_decodeEntry(_entry({'notes': ''}))!.notes, '');
      expect(_decodeEntry(_entry({'notes': ' a \n'}))!.notes, ' a \n');
    });

    test('timestamps fall back to the other timestamp, then the epoch', () {
      final created = DateTime.utc(2026, 10, 3, 2);
      final updated = DateTime.utc(2026, 10, 3, 2, 30);

      final noCreated = _decodeEntry(_entry({}, {'createdAt'}))!;
      expect(noCreated.createdAt, updated);
      expect(noCreated.updatedAt, updated);

      final noUpdated = _decodeEntry(_entry({}, {'updatedAt'}))!;
      expect(noUpdated.createdAt, created);
      expect(noUpdated.updatedAt, created);

      final neither = _decodeEntry(_entry({}, {'createdAt', 'updatedAt'}))!;
      expect(neither.createdAt, DateTime.utc(1970));
      expect(neither.updatedAt, DateTime.utc(1970));
    });

    test('malformed or offset-less timestamps count as missing', () {
      for (final bad in [
        'yesterday',
        '',
        12345,
        '2026-10-03T02:00:00',
        '2026-10-03',
      ]) {
        final event = _decodeEntry(_entry({'createdAt': bad}))!;
        expect(
          event.createdAt,
          DateTime.utc(2026, 10, 3, 2, 30),
          reason: 'createdAt $bad',
        );
      }
    });

    test('timestamps with an explicit offset are converted to UTC', () {
      final event = _decodeEntry(
        _entry({'createdAt': '2026-10-03T07:30:00+05:30'}),
      )!;
      expect(event.createdAt, DateTime.utc(2026, 10, 3, 2));
      expect(event.createdAt.isUtc, isTrue);
    });

    test('title is kept exactly as stored', () {
      expect(_decodeEntry(_entry({'title': '  Exam  '}))!.title, '  Exam  ');
    });
  });

  group('EM-05 invalid entries are rejected', () {
    final invalid = <String, Object?>{
      'missing id': _entry({}, {'id'}),
      'empty id': _entry({'id': ''}),
      'non-string id': _entry({'id': 7}),
      'missing title': _entry({}, {'title'}),
      'empty title': _entry({'title': ''}),
      'blank title': _entry({'title': '   '}),
      'non-string title': _entry({'title': 7}),
      'missing date': _entry({}, {'date'}),
      'null date': _entry({'date': null}),
      'non-existent date 2023-02-29': _entry({'date': '2023-02-29'}),
      'month 13': _entry({'date': '2024-13-01'}),
      'day 0': _entry({'date': '2024-01-00'}),
      'unpadded date': _entry({'date': '2024-1-5'}),
      'local date format': _entry({'date': '15/03/2000'}),
      'date with time': _entry({'date': '2024-01-05T00:00:00Z'}),
      'non-string date': _entry({'date': 20240105}),
      'time 25:00': _entry({'time': '25:00'}),
      'time 24:00': _entry({'time': '24:00'}),
      'time 12:60': _entry({'time': '12:60'}),
      'unpadded time': _entry({'time': '9:00'}),
      'time without colon': _entry({'time': '0900'}),
      'time with seconds': _entry({'time': '09:00:00'}),
      'non-string time': _entry({'time': 900}),
      'unknown recurrence': _entry({'recurrence': 'hourly'}),
      'non-string recurrence': _entry({'recurrence': 1}),
      'string entry': 'evt-1',
      'number entry': 42,
      'list entry': ['evt-1'],
      'null entry': null,
    };

    invalid.forEach((name, entry) {
      test(name, () {
        expect(_codec.decodeEvent(entry), isNull);
      });
    });

    test('invalid entries are reported raw; valid siblings still load', () {
      final good = _entry({'id': 'good'});
      final bad1 = _entry({'id': 'bad-1', 'date': '2023-02-29'});
      final bad2 = _entry({'id': 'bad-2', 'recurrence': 'hourly'});
      final result = _decode(_document([bad1, good, 'junk', bad2]));

      expect(result.isUnreadable, isFalse);
      expect(result.events.map((e) => e.id), ['good']);
      expect(result.invalidEntries, [bad1, 'junk', bad2]);
    });
  });

  group('EM-06 corrupt documents are unreadable', () {
    final cases = <String, UnreadableReason>{
      '{': UnreadableReason.notJson,
      '': UnreadableReason.notJson,
      '\u0000\u0001\u00ff garbage': UnreadableReason.notJson,
      '[]': UnreadableReason.notAnObject,
      '"x"': UnreadableReason.notAnObject,
      'null': UnreadableReason.notAnObject,
      '42': UnreadableReason.notAnObject,
      '{"schemaVersion":1}': UnreadableReason.missingEventList,
      '{"schemaVersion":1,"events":{}}': UnreadableReason.missingEventList,
      '{"schemaVersion":1,"events":null}': UnreadableReason.missingEventList,
    };

    cases.forEach((raw, reason) {
      test('${jsonEncode(raw)} → ${reason.name}', () {
        final result = _decode(raw);
        expect(result.unreadableReason, reason);
        expect(result.isUnreadable, isTrue);
        expect(result.events, isEmpty);
        expect(result.invalidEntries, isEmpty);
      });
    });
  });

  group('EM-07 duplicate IDs', () {
    test('first kept, later duplicates get new IDs, nothing lost', () {
      final entries = [
        _entry({'id': 'a', 'title': 'First A'}),
        _entry({'id': 'b', 'title': 'B'}),
        _entry({'id': 'a', 'title': 'Second A'}),
        _entry({'id': 'a', 'title': 'Third A'}),
      ];
      final result = _decode(
        _document(entries),
        newId: _ids(['b', 'a', 'new-1', 'new-2']),
      );

      expect(result.events.map((e) => e.id), ['a', 'b', 'new-1', 'new-2']);
      expect(result.events.map((e) => e.title), [
        'First A',
        'B',
        'Second A',
        'Third A',
      ]);
      expect(result.reassignedDuplicateIds, ['a', 'a']);
      expect(result.invalidEntries, isEmpty);
    });

    test('a new ID never collides with a later entry', () {
      final entries = [
        _entry({'id': 'a'}),
        _entry({'id': 'a'}),
        _entry({'id': 'later'}),
      ];
      final result = _decode(
        _document(entries),
        newId: _ids(['later', 'fresh']),
      );
      expect(result.events.map((e) => e.id), ['a', 'fresh', 'later']);
    });

    test('a reassigned event keeps all its other fields', () {
      final entries = [
        _entry({'id': 'a'}),
        _entry({'id': 'a', 'time': '17:00', 'notes': 'n', 'enabled': false}),
      ];
      final result = _decode(_document(entries), newId: _ids(['z']));
      final original = _decodeEntry(entries[1])!;
      expect(result.events[1], original.copyWith(id: 'z'));
    });
  });

  group('EM-08 unknown fields', () {
    test('extra document and entry fields are ignored', () {
      final raw = jsonEncode({
        'schemaVersion': 1,
        'exportedBy': 'future version',
        'events': [
          _entry({
            'reminders': [
              {'minutesBefore': 10},
            ],
            'source': 'calendar',
            'pinned': true,
          }),
        ],
      });
      final result = _decode(raw);
      expect(result.isUnreadable, isFalse);
      expect(result.invalidEntries, isEmpty);
      expect(result.events.single, _decodeEntry(_entry()));
    });
  });
}
