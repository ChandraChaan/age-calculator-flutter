import 'dart:convert';

import 'package:agecalculator/data/event_codec.dart';
import 'package:agecalculator/data/event_storage.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys given with the on-device prefix are stored exactly as the legacy
// SharedPreferences API stores them in FlutterSharedPreferences.
const _physicalStoreKey = 'flutter.event_store';
const _physicalUnreadableKey = 'flutter.event_store_unreadable';
const _physicalThemeKey = 'flutter.theme_mode';

Future<SharedPreferences> _prefs([Map<String, Object> initial = const {}]) {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

/// A fresh SharedPreferences instance read back from the backing store, as
/// after an app restart.
Future<SharedPreferences> _reopen() {
  SharedPreferences.resetStatic();
  return SharedPreferences.getInstance();
}

EventStorage _storage(SharedPreferences prefs, {List<String>? ids}) {
  var index = 0;
  final queue = ids ?? const [];
  return EventStorage(
    prefs,
    newId: () => index < queue.length
        ? queue[index++]
        : throw StateError('no new id expected'),
  );
}

Event _event(
  String id, {
  String title = 'Event',
  EventCategory category = EventCategory.event,
  CivilDate? date,
  LocalTime? time,
  Recurrence recurrence = Recurrence.none,
  String? notes,
  bool enabled = true,
}) {
  return Event(
    id: id,
    title: title,
    category: category,
    date: date ?? CivilDate(2026, 11, 14),
    time: time,
    recurrence: recurrence,
    notes: notes,
    enabled: enabled,
    createdAt: DateTime.utc(2026, 10, 3, 2),
    updatedAt: DateTime.utc(2026, 10, 3, 2, 30),
  );
}

Map<String, Object?> _entry(String id, {Object? date = '2026-11-14'}) => {
  'id': id,
  'title': 'Entry $id',
  'category': 'exam',
  'date': date,
  'time': null,
  'recurrence': 'none',
  'notes': null,
  'enabled': true,
  'createdAt': '2026-10-03T02:00:00.000Z',
  'updatedAt': '2026-10-03T02:30:00.000Z',
};

String _document(List<Object?> entries, {Object? schemaVersion = 1}) =>
    jsonEncode({'schemaVersion': schemaVersion, 'events': entries});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('missing and empty store', () {
    test('no stored document: empty and ready, nothing written', () async {
      final prefs = await _prefs({_physicalThemeKey: 'dark'});
      final result = await _storage(prefs).load();

      expect(result.events, isEmpty);
      expect(result.status, EventLoadStatus.ready);
      expect(result.unreadableReason, isNull);
      expect(prefs.getKeys(), {'theme_mode'});
    });

    test('an empty event list loads as empty and ready', () async {
      final prefs = await _prefs({_physicalStoreKey: _document([])});
      final result = await _storage(prefs).load();
      expect(result.events, isEmpty);
      expect(result.status, EventLoadStatus.ready);
    });

    test('saving an empty list stores an empty document', () async {
      final prefs = await _prefs();
      expect(await _storage(prefs).save(const []), isTrue);
      expect(
        prefs.getString(EventStorage.storeKey),
        '{"schemaVersion":1,"events":[]}',
      );
    });
  });

  group('first load', () {
    test('reads a document already on the device', () async {
      final prefs = await _prefs({
        _physicalStoreKey: _document([_entry('a'), _entry('b')]),
      });
      final result = await _storage(prefs).load();
      expect(result.events.map((e) => e.id), ['a', 'b']);
      expect(result.events.first.title, 'Entry a');
      expect(result.status, EventLoadStatus.ready);
    });

    test('the key is event_store and the document is versioned', () async {
      expect(EventStorage.storeKey, 'event_store');
      expect(EventStorage.unreadableKey, 'event_store_unreadable');

      final prefs = await _prefs();
      await _storage(prefs).save([_event('a')]);
      final stored = jsonDecode(prefs.getString('event_store')!) as Map;
      expect(stored['schemaVersion'], 1);
      expect(stored['events'], hasLength(1));
    });
  });

  group('save and reload', () {
    final events = [
      _event(
        'birthday',
        title: "Sai's birthday",
        category: EventCategory.birthday,
        date: CivilDate(1999, 8, 25),
        recurrence: Recurrence.yearly,
      ),
      _event(
        'meeting',
        title: 'Team meeting',
        category: EventCategory.meeting,
        date: CivilDate(2026, 10, 9),
        time: LocalTime(17, 0),
        recurrence: Recurrence.weekly,
        notes: 'Room 4\nBring slides',
      ),
      _event(
        'rent',
        category: EventCategory.importantDate,
        date: CivilDate(2026, 1, 31),
        recurrence: Recurrence.monthly,
        notes: '',
      ),
      _event('paused', enabled: false, recurrence: Recurrence.daily),
      _event('leap', date: CivilDate(2024, 2, 29), time: LocalTime(0, 0)),
    ];

    test('multiple events round-trip in order after a restart', () async {
      final prefs = await _prefs();
      expect(await _storage(prefs).save(events), isTrue);

      final reopened = await _reopen();
      final result = await _storage(reopened).load();
      expect(result.status, EventLoadStatus.ready);
      expect(result.events, events);
    });

    test(
      'ids, dates, times, recurrence, notes, enabled are preserved',
      () async {
        final prefs = await _prefs();
        await _storage(prefs).save(events);
        final loaded = (await _storage(await _reopen()).load()).events;

        for (var i = 0; i < events.length; i++) {
          final saved = events[i];
          final read = loaded[i];
          expect(read.id, saved.id);
          expect(read.date, saved.date);
          expect(read.time, saved.time);
          expect(read.recurrence, saved.recurrence);
          expect(read.notes, saved.notes);
          expect(read.enabled, saved.enabled);
          expect(read.category, saved.category);
        }
        expect(loaded[1].isAllDay, isFalse);
        expect(loaded[0].isAllDay, isTrue);
        expect(loaded[2].notes, '', reason: 'empty notes stay empty');
        expect(loaded[3].enabled, isFalse);
      },
    );

    test('every recurrence value is preserved', () async {
      final prefs = await _prefs();
      final all = [
        for (final r in Recurrence.values) _event('r-${r.name}', recurrence: r),
      ];
      await _storage(prefs).save(all);
      final loaded = (await _storage(await _reopen()).load()).events;
      expect(loaded.map((e) => e.recurrence), Recurrence.values);
    });

    test('timestamps are preserved exactly, including microseconds', () async {
      final prefs = await _prefs();
      final event = _event('t').copyWith(
        createdAt: DateTime.utc(2026, 10, 3, 2, 0, 0, 123, 456),
        updatedAt: DateTime.utc(2026, 10, 4, 23, 59, 59, 999),
      );
      await _storage(prefs).save([event]);
      final loaded = (await _storage(await _reopen()).load()).events.single;
      expect(loaded.createdAt, event.createdAt);
      expect(loaded.updatedAt, event.updatedAt);
      expect(loaded.createdAt.isUtc, isTrue);
    });
  });

  group('updates and deletions', () {
    test('an updated event replaces the stored one', () async {
      final prefs = await _prefs();
      final storage = _storage(prefs);
      final a = _event('a', title: 'Exam');
      final b = _event('b');
      await storage.save([a, b]);

      final updated = a.copyWith(
        title: 'Final exam',
        time: LocalTime(9, 30),
        notes: 'Hall 3',
        updatedAt: DateTime.utc(2026, 10, 5),
      );
      await storage.save([updated, b]);

      final loaded = (await _storage(await _reopen()).load()).events;
      expect(loaded, [updated, b]);
    });

    test('pausing and resuming persists', () async {
      final prefs = await _prefs();
      final storage = _storage(prefs);
      final a = _event('a');
      await storage.save([a.copyWith(enabled: false)]);
      expect(
        (await _storage(await _reopen()).load()).events.single.enabled,
        isFalse,
      );

      final again = _storage(await _reopen());
      await again.save([a]);
      expect(
        (await _storage(await _reopen()).load()).events.single.enabled,
        isTrue,
      );
    });

    test('a deleted event is gone after reload', () async {
      final prefs = await _prefs();
      final storage = _storage(prefs);
      final a = _event('a');
      final b = _event('b');
      final c = _event('c');
      await storage.save([a, b, c]);
      await storage.save([a, c]);

      final loaded = (await _storage(await _reopen()).load()).events;
      expect(loaded.map((e) => e.id), ['a', 'c']);
    });

    test('clear removes the document and the unreadable copy', () async {
      final prefs = await _prefs({
        _physicalThemeKey: 'light',
        _physicalUnreadableKey: 'old raw data',
      });
      final storage = _storage(prefs);
      await storage.save([_event('a')]);
      expect(await storage.clear(), isTrue);

      final reopened = await _reopen();
      expect(reopened.containsKey(EventStorage.storeKey), isFalse);
      expect(reopened.containsKey(EventStorage.unreadableKey), isFalse);
      expect(reopened.getString('theme_mode'), 'light');
      expect(reopened.getKeys(), {'theme_mode'});
      final result = await _storage(reopened).load();
      expect(result.events, isEmpty);
      expect(result.status, EventLoadStatus.ready);
    });

    test('clear after a recovery leaves no recovered data behind', () async {
      final prefs = await _prefs({
        _physicalThemeKey: 'dark',
        _physicalStoreKey: '{broken',
      });
      final storage = _storage(prefs);
      expect((await storage.load()).status, EventLoadStatus.recovered);
      expect(prefs.containsKey(EventStorage.unreadableKey), isTrue);

      expect(await storage.clear(), isTrue);
      final reopened = await _reopen();
      expect(reopened.getKeys(), {'theme_mode'});
      expect(reopened.getString('theme_mode'), 'dark');
    });

    test('clear succeeds when nothing is stored', () async {
      final prefs = await _prefs({_physicalThemeKey: 'system'});
      expect(await _storage(prefs).clear(), isTrue);
      expect((await _reopen()).getKeys(), {'theme_mode'});
    });
  });

  group('determinism', () {
    test('saving the same events twice stores the same string', () async {
      final prefs = await _prefs();
      final storage = _storage(prefs);
      final events = [_event('a', time: LocalTime(8, 0)), _event('b')];

      await storage.save(events);
      final first = prefs.getString(EventStorage.storeKey);
      await storage.save(events);
      expect(prefs.getString(EventStorage.storeKey), first);
      expect(first, const EventCodec().encodeDocument(events));
    });

    test('load → save → load is stable', () async {
      final prefs = await _prefs({
        _physicalStoreKey: _document([_entry('a'), _entry('b')]),
      });
      final storage = _storage(prefs);
      final first = await storage.load();
      await storage.save(first.events);
      final second = await _storage(await _reopen()).load();
      expect(second.events, first.events);
    });
  });

  group('unreadable documents', () {
    final cases = <String, UnreadableReason>{
      '{': UnreadableReason.notJson,
      'not json at all': UnreadableReason.notJson,
      'null': UnreadableReason.notAnObject,
      '[]': UnreadableReason.notAnObject,
      '{"events":[]}': UnreadableReason.missingSchemaVersion,
      '{"schemaVersion":"1","events":[]}':
          UnreadableReason.missingSchemaVersion,
      '{"schemaVersion":2,"events":[]}':
          UnreadableReason.unsupportedSchemaVersion,
      '{"schemaVersion":1}': UnreadableReason.missingEventList,
    };

    cases.forEach((raw, reason) {
      test('${jsonEncode(raw)}: empty, recovered, raw kept', () async {
        final prefs = await _prefs({_physicalStoreKey: raw});
        final result = await _storage(prefs).load();

        expect(result.events, isEmpty);
        expect(result.status, EventLoadStatus.recovered);
        expect(result.unreadableReason, reason);
        expect(prefs.getString(EventStorage.unreadableKey), raw);
        expect(
          prefs.getString(EventStorage.storeKey),
          raw,
          reason: 'loading never rewrites the stored document',
        );
      });
    });

    test('a non-text value is treated as unreadable', () async {
      final prefs = await _prefs({_physicalStoreKey: 42});
      final result = await _storage(prefs).load();
      expect(result.status, EventLoadStatus.recovered);
      expect(result.unreadableReason, UnreadableReason.notAnObject);
      expect(prefs.getString(EventStorage.unreadableKey), '42');
    });

    test('the first unreadable copy is never overwritten', () async {
      final prefs = await _prefs({_physicalStoreKey: 'first corruption'});
      await _storage(prefs).load();
      expect(prefs.getString(EventStorage.unreadableKey), 'first corruption');

      await prefs.setString(EventStorage.storeKey, 'second corruption');
      final result = await _storage(prefs).load();
      expect(result.status, EventLoadStatus.recovered);
      expect(prefs.getString(EventStorage.unreadableKey), 'first corruption');

      final reopened = await _reopen();
      await _storage(reopened).load();
      expect(
        reopened.getString(EventStorage.unreadableKey),
        'first corruption',
      );
    });

    test('an existing unreadable copy from earlier is kept', () async {
      final prefs = await _prefs({
        _physicalStoreKey: '{',
        _physicalUnreadableKey: 'from an earlier version',
      });
      await _storage(prefs).load();
      expect(
        prefs.getString(EventStorage.unreadableKey),
        'from an earlier version',
      );
    });

    test('after recovery, saving works and the copy stays', () async {
      final prefs = await _prefs({_physicalStoreKey: '{broken'});
      final storage = _storage(prefs);
      expect((await storage.load()).status, EventLoadStatus.recovered);

      await storage.save([_event('fresh')]);
      final reopened = await _reopen();
      final result = await _storage(reopened).load();
      expect(result.status, EventLoadStatus.ready);
      expect(result.events.map((e) => e.id), ['fresh']);
      expect(reopened.getString(EventStorage.unreadableKey), '{broken');
    });
  });

  group('invalid individual events', () {
    test('valid events load; invalid entries are kept once', () async {
      final bad1 = _entry('bad-date', date: '2023-02-29');
      final bad2 = {'id': 'no-title', 'date': '2026-01-01'};
      final prefs = await _prefs({
        _physicalStoreKey: _document([bad1, _entry('good'), bad2]),
      });
      final result = await _storage(prefs).load();

      expect(result.events.map((e) => e.id), ['good']);
      expect(result.status, EventLoadStatus.recovered);
      expect(result.invalidEntryCount, 2);
      expect(result.unreadableReason, isNull);
      expect(jsonDecode(prefs.getString(EventStorage.unreadableKey)!), [
        bad1,
        bad2,
      ]);
    });

    test('an existing unreadable copy is not overwritten', () async {
      final prefs = await _prefs({
        _physicalStoreKey: _document([_entry('good'), 'junk']),
        _physicalUnreadableKey: 'older copy',
      });
      final result = await _storage(prefs).load();
      expect(result.invalidEntryCount, 1);
      expect(prefs.getString(EventStorage.unreadableKey), 'older copy');
    });
  });

  group('duplicate IDs', () {
    test('later duplicates get new IDs; stored with the next save', () async {
      final raw = _document([_entry('a'), _entry('b'), _entry('a')]);
      final prefs = await _prefs({_physicalStoreKey: raw});
      final storage = _storage(prefs, ids: ['a-2']);

      final result = await storage.load();
      expect(result.events.map((e) => e.id), ['a', 'b', 'a-2']);
      expect(result.reassignedDuplicateIds, ['a']);
      expect(result.status, EventLoadStatus.ready);
      expect(prefs.getString(EventStorage.storeKey), raw);
      expect(prefs.containsKey(EventStorage.unreadableKey), isFalse);

      await storage.save(result.events);
      final again = await _storage(await _reopen()).load();
      expect(again.events.map((e) => e.id), ['a', 'b', 'a-2']);
      expect(again.reassignedDuplicateIds, isEmpty);
    });
  });

  group('other preferences', () {
    test('theme_mode is never read or changed by storage', () async {
      final prefs = await _prefs({_physicalThemeKey: 'dark'});
      final storage = _storage(prefs);

      await storage.load();
      await storage.save([_event('a')]);
      await storage.load();
      await storage.clear();

      final reopened = await _reopen();
      expect(reopened.getString('theme_mode'), 'dark');
    });

    test(
      'only theme_mode, event_store and event_store_unreadable exist',
      () async {
        final prefs = await _prefs({
          _physicalThemeKey: 'system',
          _physicalStoreKey: _document([_entry('ok'), 'junk']),
        });
        final storage = _storage(prefs);
        final result = await storage.load();
        await storage.save(result.events);

        final reopened = await _reopen();
        expect(reopened.getKeys(), {
          'theme_mode',
          'event_store',
          'event_store_unreadable',
        });
      },
    );
  });
}
