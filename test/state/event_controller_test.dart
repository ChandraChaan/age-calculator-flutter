import 'dart:convert';

import 'package:agecalculator/data/event_storage.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _physicalStoreKey = 'flutter.event_store';
const _physicalUnreadableKey = 'flutter.event_store_unreadable';
const _physicalThemeKey = 'flutter.theme_mode';

/// A controllable clock. Times are local; the controller stores UTC.
class _Clock {
  DateTime now = DateTime(2026, 6, 15, 12);
  DateTime call() => now;
}

/// Deterministic IDs: id-1, id-2, …
class _Ids {
  int _next = 0;
  String call() => 'id-${++_next}';
}

/// Storage whose writes can be made to fail.
class _FlakyStorage extends EventStorage {
  _FlakyStorage(super.preferences, {required super.newId});

  bool failSaves = false;
  bool throwOnSave = false;
  bool failClear = false;

  @override
  Future<bool> save(List<Event> events) async {
    if (throwOnSave) throw StateError('disk full');
    if (failSaves) return false;
    return super.save(events);
  }

  @override
  Future<bool> clear() async => failClear ? false : super.clear();
}

class _Harness {
  _Harness(this.prefs, {_Clock? clock, _Ids? ids})
    : clock = clock ?? _Clock(),
      ids = ids ?? _Ids() {
    storage = _FlakyStorage(prefs, newId: this.ids.call);
    controller = EventController(
      storage: storage,
      clock: this.clock.call,
      newId: this.ids.call,
    );
    controller.addListener(() => notifications++);
  }

  final SharedPreferences prefs;
  final _Clock clock;
  final _Ids ids;
  late final _FlakyStorage storage;
  late final EventController controller;
  int notifications = 0;

  String? get storedDocument => prefs.getString(EventStorage.storeKey);
}

Future<_Harness> _harness([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final harness = _Harness(await SharedPreferences.getInstance());
  await harness.controller.load();
  harness.notifications = 0;
  return harness;
}

/// A new controller over the same stored data, as after an app restart.
Future<EventController> _restart() async {
  SharedPreferences.resetStatic();
  final prefs = await SharedPreferences.getInstance();
  final ids = _Ids();
  final controller = EventController(
    storage: EventStorage(prefs, newId: ids.call),
    clock: _Clock().call,
    newId: ids.call,
  );
  await controller.load();
  return controller;
}

Event _draft({
  String title = 'Exam',
  EventCategory category = EventCategory.exam,
  CivilDate? date,
  LocalTime? time,
  Recurrence recurrence = Recurrence.none,
  String? notes,
  bool enabled = true,
}) {
  return Event(
    id: 'draft',
    title: title,
    category: category,
    date: date ?? CivilDate(2026, 6, 20),
    time: time,
    recurrence: recurrence,
    notes: notes,
    enabled: enabled,
    createdAt: DateTime.utc(2000),
    updatedAt: DateTime.utc(2000),
  );
}

Map<String, Object?> _entry(String id, {String? date}) => {
  'id': id,
  'title': 'Stored $id',
  'category': 'event',
  'date': date ?? '2026-06-20',
  'time': null,
  'recurrence': 'none',
  'notes': null,
  'enabled': true,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('initial load', () {
    test('starts in loading, then ready with no events', () async {
      SharedPreferences.setMockInitialValues({});
      final harness = _Harness(await SharedPreferences.getInstance());
      expect(harness.controller.status, LoadStatus.loading);
      expect(harness.controller.events, isEmpty);

      await harness.controller.load();
      expect(harness.controller.status, LoadStatus.ready);
      expect(harness.controller.events, isEmpty);
      expect(harness.controller.hasActiveEvents, isFalse);
      expect(harness.notifications, 2, reason: 'loading, then ready');
    });

    test('loads stored events in stored order', () async {
      final harness = await _harness({
        _physicalStoreKey: jsonEncode({
          'schemaVersion': 1,
          'events': [_entry('b'), _entry('a')],
        }),
      });
      expect(harness.controller.events.map((e) => e.id), ['b', 'a']);
      expect(harness.controller.status, LoadStatus.ready);
      expect(harness.controller.eventById('a')!.title, 'Stored a');
      expect(harness.controller.eventById('missing'), isNull);
    });

    test('the event list cannot be modified from outside', () async {
      final harness = await _harness();
      await harness.controller.add(_draft());
      expect(
        () => harness.controller.events.add(_draft()),
        throwsUnsupportedError,
      );
    });
  });

  group('ST-01 create', () {
    test('assigns a new id and timestamps, then survives a restart', () async {
      final harness = await _harness();
      harness.clock.now = DateTime(2026, 6, 15, 9, 30);

      final saved = await harness.controller.add(
        _draft(time: LocalTime(17, 0), notes: 'Hall 3'),
      );
      expect(saved!.id, 'id-1');
      expect(saved.createdAt, DateTime(2026, 6, 15, 9, 30).toUtc());
      expect(saved.updatedAt, saved.createdAt);
      expect(saved.createdAt.isUtc, isTrue);
      expect(saved.title, 'Exam');
      expect(saved.time, LocalTime(17, 0));
      expect(saved.notes, 'Hall 3');
      expect(harness.controller.events, [saved]);
      expect(harness.notifications, 1);

      final restarted = await _restart();
      expect(restarted.events, [saved]);
    });

    test('never reuses an id that is already taken', () async {
      final harness = await _harness({
        _physicalStoreKey: jsonEncode({
          'schemaVersion': 1,
          'events': [_entry('id-1'), _entry('id-2')],
        }),
      });
      final saved = await harness.controller.add(_draft());
      expect(saved!.id, 'id-3');
    });
  });

  group('ST-02 edit', () {
    test('keeps createdAt, bumps updatedAt and persists', () async {
      final harness = await _harness();
      final saved = (await harness.controller.add(_draft()))!;

      harness.clock.now = DateTime(2026, 6, 16, 8);
      final ok = await harness.controller.update(
        saved.copyWith(
          title: 'Final exam',
          recurrence: Recurrence.yearly,
          time: LocalTime(9, 0),
          createdAt: DateTime.utc(1999),
          updatedAt: DateTime.utc(1999),
        ),
      );
      expect(ok, isTrue);

      final updated = harness.controller.eventById(saved.id)!;
      expect(updated.title, 'Final exam');
      expect(updated.recurrence, Recurrence.yearly);
      expect(updated.time, LocalTime(9, 0));
      expect(updated.createdAt, saved.createdAt);
      expect(updated.updatedAt, DateTime(2026, 6, 16, 8).toUtc());

      expect((await _restart()).events, [updated]);
    });

    test('editing can clear the time and notes', () async {
      final harness = await _harness();
      final saved = (await harness.controller.add(
        _draft(time: LocalTime(9, 0), notes: 'x'),
      ))!;
      await harness.controller.update(saved.copyWith(time: null, notes: null));
      final updated = harness.controller.eventById(saved.id)!;
      expect(updated.isAllDay, isTrue);
      expect(updated.notes, isNull);
    });

    test('an unknown id changes nothing', () async {
      final harness = await _harness();
      await harness.controller.add(_draft());
      final before = harness.storedDocument;
      harness.notifications = 0;

      expect(await harness.controller.update(_draft()), isFalse);
      expect(harness.storedDocument, before);
      expect(harness.notifications, 0);
    });
  });

  group('ST-03 delete and undo', () {
    test(
      'delete persists; undo restores the identical event in place',
      () async {
        final harness = await _harness();
        final a = (await harness.controller.add(_draft(title: 'A')))!;
        final b = (await harness.controller.add(_draft(title: 'B')))!;
        final c = (await harness.controller.add(_draft(title: 'C')))!;
        final documentBefore = harness.storedDocument;

        final removed = await harness.controller.delete(b.id);
        expect(removed, b);
        expect(harness.controller.events, [a, c]);
        expect((await _restart()).events, [a, c]);

        expect(await harness.controller.restore(removed!), isTrue);
        expect(harness.controller.events, [a, b, c]);
        expect(harness.storedDocument, documentBefore);
        expect((await _restart()).events, [a, b, c]);
      },
    );

    test('undo cannot add the same event twice', () async {
      final harness = await _harness();
      final a = (await harness.controller.add(_draft()))!;
      final removed = (await harness.controller.delete(a.id))!;
      expect(await harness.controller.restore(removed), isTrue);
      expect(await harness.controller.restore(removed), isFalse);
      expect(harness.controller.events, [a]);
    });

    test('an older deleted event is restored at the end', () async {
      final harness = await _harness();
      final a = (await harness.controller.add(_draft(title: 'A')))!;
      final b = (await harness.controller.add(_draft(title: 'B')))!;
      final c = (await harness.controller.add(_draft(title: 'C')))!;
      final first = (await harness.controller.delete(a.id))!;
      await harness.controller.delete(c.id);

      await harness.controller.restore(first);
      expect(harness.controller.events, [b, a]);
    });

    test('deleting an unknown id returns null and changes nothing', () async {
      final harness = await _harness();
      await harness.controller.add(_draft());
      harness.notifications = 0;
      expect(await harness.controller.delete('nope'), isNull);
      expect(harness.notifications, 0);
      expect(harness.controller.events, hasLength(1));
    });
  });

  group('ST-04 duplicate', () {
    test(
      'a duplicate copies the content with a new id and timestamps',
      () async {
        final harness = await _harness();
        final original = (await harness.controller.add(
          _draft(
            title: 'Rent',
            category: EventCategory.importantDate,
            date: CivilDate(2026, 1, 31),
            time: LocalTime(10, 0),
            recurrence: Recurrence.monthly,
            notes: 'Transfer',
          ),
        ))!;

        harness.clock.now = DateTime(2026, 6, 18, 7);
        final draft = harness.controller.duplicateDraft(original.id);
        expect(draft.id, isNot(original.id));
        expect(draft.createdAt, DateTime(2026, 6, 18, 7).toUtc());
        expect(harness.controller.events, [original], reason: 'not saved yet');

        final copy = (await harness.controller.add(draft))!;
        expect(copy.id, isNot(original.id));
        expect(copy.createdAt, DateTime(2026, 6, 18, 7).toUtc());
        expect(copy.updatedAt, copy.createdAt);
        expect(
          copy.copyWith(
            id: original.id,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt,
          ),
          original,
          reason: 'title, category, date, time, recurrence, notes, enabled',
        );
        expect(harness.controller.events, [original, copy]);
        expect((await _restart()).events, [original, copy]);
      },
    );

    test('duplicating an unknown id is an error', () async {
      final harness = await _harness();
      expect(
        () => harness.controller.duplicateDraft('nope'),
        throwsArgumentError,
      );
    });
  });

  group('ST-05 Active / Paused', () {
    test('pausing and resuming persists and bumps updatedAt', () async {
      final harness = await _harness();
      final saved = (await harness.controller.add(_draft()))!;
      expect(harness.controller.hasActiveEvents, isTrue);

      harness.clock.now = DateTime(2026, 6, 15, 13);
      expect(await harness.controller.setEnabled(saved.id, false), isTrue);
      final paused = harness.controller.eventById(saved.id)!;
      expect(paused.enabled, isFalse);
      expect(paused.updatedAt, DateTime(2026, 6, 15, 13).toUtc());
      expect(harness.controller.hasActiveEvents, isFalse);
      expect((await _restart()).events.single.enabled, isFalse);

      expect(await harness.controller.setEnabled(saved.id, true), isTrue);
      expect((await _restart()).events.single.enabled, isTrue);
    });

    test('setting the current state again is a no-op', () async {
      final harness = await _harness();
      final saved = (await harness.controller.add(_draft()))!;
      harness.notifications = 0;
      expect(await harness.controller.setEnabled(saved.id, true), isTrue);
      expect(harness.notifications, 0);
      expect(harness.controller.eventById(saved.id), saved);
    });

    test('an unknown id returns false', () async {
      final harness = await _harness();
      expect(await harness.controller.setEnabled('nope', false), isFalse);
    });
  });

  group('ST-06 Delete All', () {
    test('removes events and the stored document, keeps the theme', () async {
      final harness = await _harness({_physicalThemeKey: 'dark'});
      await harness.controller.add(_draft(title: 'A'));
      await harness.controller.add(_draft(title: 'B'));
      harness.notifications = 0;

      expect(await harness.controller.deleteAll(), isTrue);
      expect(harness.controller.events, isEmpty);
      expect(harness.controller.status, LoadStatus.ready);
      expect(harness.notifications, 1);
      expect(harness.prefs.getKeys(), {'theme_mode'});
      expect(harness.prefs.getString('theme_mode'), 'dark');
      expect((await _restart()).events, isEmpty);
    });

    test('D12: also removes the recovered backup after a recovery', () async {
      final harness = await _harness({
        _physicalThemeKey: 'light',
        _physicalStoreKey: '{broken',
      });
      expect(harness.controller.status, LoadStatus.recovered);
      expect(harness.prefs.containsKey(EventStorage.unreadableKey), isTrue);

      expect(await harness.controller.deleteAll(), isTrue);
      expect(harness.controller.status, LoadStatus.ready);
      expect(harness.prefs.getKeys(), {'theme_mode'});
      expect(harness.prefs.getString('theme_mode'), 'light');
    });

    test('a failed clear keeps the events', () async {
      final harness = await _harness();
      await harness.controller.add(_draft());
      harness.storage.failClear = true;
      expect(await harness.controller.deleteAll(), isFalse);
      expect(harness.controller.events, hasLength(1));
    });
  });

  group('ST-07 failed saves are undone', () {
    test('add: shown, then reverted, listeners told both times', () async {
      final harness = await _harness();
      harness.storage.failSaves = true;
      harness.notifications = 0;

      expect(await harness.controller.add(_draft()), isNull);
      expect(harness.controller.events, isEmpty);
      expect(harness.notifications, 2);
      expect(harness.storedDocument, isNull);
    });

    test('edit, pause and delete revert when the save throws', () async {
      final harness = await _harness();
      final saved = (await harness.controller.add(_draft()))!;
      final before = harness.storedDocument;
      harness.storage.throwOnSave = true;

      expect(
        await harness.controller.update(saved.copyWith(title: 'X')),
        isFalse,
      );
      expect(await harness.controller.setEnabled(saved.id, false), isFalse);
      expect(await harness.controller.delete(saved.id), isNull);
      expect(harness.controller.events, [saved]);
      expect(harness.storedDocument, before);
    });

    test('a failed undo leaves the event deleted', () async {
      final harness = await _harness();
      final a = (await harness.controller.add(_draft(title: 'A')))!;
      final b = (await harness.controller.add(_draft(title: 'B')))!;
      final removed = (await harness.controller.delete(a.id))!;
      harness.storage.failSaves = true;
      expect(await harness.controller.restore(removed), isFalse);
      expect(harness.controller.events, [b]);
    });
  });

  group('ST-08 recovered data', () {
    test(
      'unreadable document: recovered, kept once, saves still work',
      () async {
        final harness = await _harness({_physicalStoreKey: 'not json'});
        expect(harness.controller.status, LoadStatus.recovered);
        expect(harness.controller.events, isEmpty);
        expect(harness.prefs.getString(EventStorage.unreadableKey), 'not json');

        final saved = await harness.controller.add(_draft());
        expect(saved, isNotNull);
        expect(harness.prefs.getString(EventStorage.unreadableKey), 'not json');
        expect((await _restart()).events, [saved]);
      },
    );

    test(
      'duplicate stored ids get new ids, written with the next save',
      () async {
        final raw = jsonEncode({
          'schemaVersion': 1,
          'events': [_entry('a'), _entry('a')],
        });
        final harness = await _harness({_physicalStoreKey: raw});
        expect(harness.controller.events.map((e) => e.id), ['a', 'id-1']);
        expect(harness.storedDocument, raw, reason: 'not written on load');

        await harness.controller.add(_draft());
        final restarted = await _restart();
        expect(restarted.events.map((e) => e.id), ['a', 'id-1', 'id-2']);
      },
    );
  });

  group('ST-09 serialised writes', () {
    test('rapid calls apply in order and end in the right document', () async {
      final harness = await _harness();
      final first = harness.controller.add(_draft(title: 'A'));
      final second = harness.controller.add(_draft(title: 'B'));
      final third = harness.controller.add(_draft(title: 'C'));
      final deletion = harness.controller.delete('id-2');
      final pause = harness.controller.setEnabled('id-3', false);

      expect((await first)!.id, 'id-1');
      expect((await second)!.id, 'id-2');
      expect((await third)!.id, 'id-3');
      expect((await deletion)!.title, 'B');
      expect(await pause, isTrue);

      final restarted = await _restart();
      expect(restarted.events.map((e) => (e.id, e.title, e.enabled)), [
        ('id-1', 'A', true),
        ('id-3', 'C', false),
      ]);
    });
  });

  group('ST-10 preference keys', () {
    test('only theme_mode, event_store and event_store_unreadable', () async {
      final harness = await _harness({
        _physicalThemeKey: 'system',
        _physicalStoreKey: jsonEncode({
          'schemaVersion': 1,
          'events': [_entry('ok'), 'junk'],
        }),
      });
      final saved = (await harness.controller.add(_draft()))!;
      await harness.controller.update(saved.copyWith(title: 'Renamed'));
      await harness.controller.setEnabled(saved.id, false);
      final removed = (await harness.controller.delete(saved.id))!;
      await harness.controller.restore(removed);

      expect(harness.prefs.getKeys(), {
        'theme_mode',
        'event_store',
        'event_store_unreadable',
      });
      expect(harness.prefs.getString('theme_mode'), 'system');
    });
  });

  group('planner integration', () {
    test('upcomingPlan is planUpcoming over the current events', () async {
      final harness = await _harness();
      await harness.controller.add(
        _draft(title: 'Soon', date: CivilDate(2026, 6, 16)),
      );
      await harness.controller.add(
        _draft(title: 'Later', date: CivilDate(2026, 8, 1)),
      );
      final now = DateTime(2026, 6, 15, 12);

      final plan = harness.controller.upcomingPlan(now: now);
      expect(plan, planUpcoming(harness.controller.events, now));
      expect(plan.next!.event.title, 'Soon');
      expect(plan.later.single.event.title, 'Later');
    });

    test('uses the clock when no time is given', () async {
      final harness = await _harness();
      await harness.controller.add(_draft(date: CivilDate(2026, 6, 15)));
      harness.clock.now = DateTime(2026, 6, 15, 8);
      expect(
        harness.controller.upcomingPlan().next!.countdown.state,
        CountdownState.now,
      );
      harness.clock.now = DateTime(2026, 6, 16, 8);
      expect(harness.controller.upcomingPlan().next, isNull);
      expect(harness.controller.upcomingPlan().passed, hasLength(1));
    });

    test('paused events leave the timeline and appear under paused', () async {
      final harness = await _harness();
      final saved = (await harness.controller.add(_draft()))!;
      await harness.controller.setEnabled(saved.id, false);

      final plan = harness.controller.upcomingPlan(
        now: DateTime(2026, 6, 15, 12),
      );
      expect(plan.next, isNull);
      expect(plan.paused.single.id, saved.id);
    });
  });

  group('listeners and lifecycle', () {
    test('each successful change notifies once', () async {
      final harness = await _harness();
      final saved = (await harness.controller.add(_draft()))!;
      await harness.controller.update(saved.copyWith(title: 'B'));
      await harness.controller.setEnabled(saved.id, false);
      final removed = (await harness.controller.delete(saved.id))!;
      await harness.controller.restore(removed);
      await harness.controller.deleteAll();
      expect(harness.notifications, 6);
    });

    test('a save finishing after dispose does not notify', () async {
      final harness = await _harness();
      final pending = harness.controller.add(_draft());
      harness.controller.dispose();
      expect(await pending, isNotNull);
    });
  });

  group('determinism', () {
    Future<String?> run() async {
      final harness = await _harness();
      final a = (await harness.controller.add(_draft(title: 'A')))!;
      harness.clock.now = DateTime(2026, 6, 15, 13);
      await harness.controller.add(
        _draft(title: 'B', recurrence: Recurrence.weekly),
      );
      await harness.controller.update(a.copyWith(notes: 'n'));
      await harness.controller.setEnabled(a.id, false);
      return harness.storedDocument;
    }

    test('the same operations store the same document', () async {
      final first = await run();
      final second = await run();
      expect(second, first);
      expect(first, isNotNull);
    });
  });

  group('generateEventId', () {
    test('32 lowercase hex characters, unique across many calls', () {
      final ids = {for (var i = 0; i < 10000; i++) generateEventId()};
      expect(ids, hasLength(10000));
      for (final id in ids.take(200)) {
        expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
      }
    });
  });

  group('the physical unreadable key', () {
    test('matches the on-device name', () async {
      final harness = await _harness({_physicalUnreadableKey: 'x'});
      expect(harness.prefs.getString(EventStorage.unreadableKey), 'x');
    });
  });
}
