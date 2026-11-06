import 'dart:math';

import 'package:agecalculator/data/event_storage.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/models/event.dart';
import 'package:flutter/foundation.dart';

enum LoadStatus {
  loading,
  ready,

  /// Some stored data could not be read; see [EventLoadStatus.recovered].
  recovered,
}

final Random _secureRandom = Random.secure();

/// A new random event ID: 32 lowercase hex characters (128 bits).
String generateEventId() {
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(_secureRandom.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// Owns the user's events in memory and keeps [EventStorage] in step.
///
/// Loads and changes run one at a time, in call order. Each change is shown
/// immediately and undone again if saving it fails.
class EventController extends ChangeNotifier {
  EventController({
    required EventStorage storage,
    required DateTime Function() clock,
    required String Function() newId,
  }) : _storage = storage,
       _clock = clock,
       _newId = newId;

  final EventStorage _storage;
  final DateTime Function() _clock;
  final String Function() _newId;

  List<Event> _events = const [];
  LoadStatus _status = LoadStatus.loading;
  ({Event event, int index})? _lastDeleted;
  Future<void> _queue = Future.value();
  bool _disposed = false;

  LoadStatus get status => _status;

  /// All events in stored order. Unmodifiable.
  List<Event> get events => _events;

  bool get hasActiveEvents => _events.any((event) => event.enabled);

  Event? eventById(String id) {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  /// The upcoming plan for the current events as of [now] (default: the
  /// clock).
  UpcomingPlan upcomingPlan({DateTime? now}) {
    return planUpcoming(_events, now ?? _clock(), hideImportedDuplicates: true);
  }

  Future<void> load() {
    return _serialized(() async {
      _status = LoadStatus.loading;
      _notify();
      final result = await _storage.load();
      _events = result.events;
      _status = result.status == EventLoadStatus.recovered
          ? LoadStatus.recovered
          : LoadStatus.ready;
      _notify();
    });
  }

  /// Saves [draft] as a new event with a fresh ID and timestamps. Returns the
  /// saved event, or `null` if saving failed.
  Future<Event?> add(Event draft) {
    return _serialized(() async {
      final now = _clock().toUtc();
      final event = draft.copyWith(
        id: _uniqueId(),
        createdAt: now,
        updatedAt: now,
      );
      return await _commit([..._events, event]) ? event : null;
    });
  }

  /// Saves every draft in one go, each with a fresh ID and timestamps.
  /// Returns the saved events, or `null` if saving failed (nothing is then
  /// added).
  Future<List<Event>?> addAll(List<Event> drafts) {
    return _serialized(() async {
      if (drafts.isEmpty) return const <Event>[];
      final now = _clock().toUtc();
      final next = [..._events];
      final added = <Event>[];
      for (final draft in drafts) {
        final event = draft.copyWith(
          id: _uniqueIdAmong(next),
          createdAt: now,
          updatedAt: now,
        );
        next.add(event);
        added.add(event);
      }
      return await _commit(next) ? List<Event>.unmodifiable(added) : null;
    });
  }

  /// Replaces the stored event with the same ID. Keeps its `createdAt` and
  /// sets `updatedAt` to now. Returns `false` if there is no such event or
  /// saving failed.
  Future<bool> update(Event event) {
    return _serialized(() async {
      final index = _indexOf(event.id);
      if (index < 0) return false;
      final next = [..._events];
      next[index] = event.copyWith(
        createdAt: _events[index].createdAt,
        updatedAt: _clock().toUtc(),
      );
      return _commit(next);
    });
  }

  /// Makes the event Active (`true`) or Paused (`false`).
  Future<bool> setEnabled(String id, bool enabled) {
    return _serialized(() async {
      final index = _indexOf(id);
      if (index < 0) return false;
      if (_events[index].enabled == enabled) return true;
      final next = [..._events];
      next[index] = _events[index].copyWith(
        enabled: enabled,
        updatedAt: _clock().toUtc(),
      );
      return _commit(next);
    });
  }

  /// Deletes the event and returns it for [restore]. Returns `null` if there
  /// is no such event or saving failed.
  Future<Event?> delete(String id) {
    return _serialized(() async {
      final index = _indexOf(id);
      if (index < 0) return null;
      final removed = _events[index];
      final next = [..._events]..removeAt(index);
      if (!await _commit(next)) return null;
      _lastDeleted = (event: removed, index: index);
      return removed;
    });
  }

  /// Puts back an event returned by [delete], unchanged and, for the most
  /// recent deletion, at its previous position. Undo history is in memory
  /// only.
  Future<bool> restore(Event event) {
    return _serialized(() async {
      if (_indexOf(event.id) >= 0) return false;
      final last = _lastDeleted;
      final isLastDeleted = last != null && last.event == event;
      final index = isLastDeleted
          ? min(last.index, _events.length)
          : _events.length;
      final next = [..._events]..insert(index, event);
      if (!await _commit(next)) return false;
      if (isLastDeleted) _lastDeleted = null;
      return true;
    });
  }

  /// Removes the date [date] from repeating event [id] ("delete this date
  /// only"). Returns `false` if there is no such event or saving failed.
  Future<bool> skipOccurrence(String id, CivilDate date) {
    return _serialized(() async {
      final index = _indexOf(id);
      if (index < 0) return false;
      final event = _events[index];
      if (event.recurrence == Recurrence.none) return false;
      final next = [..._events];
      next[index] = event.copyWith(
        skippedDates: [...event.skippedDates, date],
        updatedAt: _clock().toUtc(),
      );
      return _commit(next);
    });
  }

  /// Puts back a date removed by [skipOccurrence].
  Future<bool> unskipOccurrence(String id, CivilDate date) {
    return _serialized(() async {
      final index = _indexOf(id);
      if (index < 0) return false;
      final event = _events[index];
      if (!event.isSkipped(date)) return true;
      final next = [..._events];
      next[index] = event.copyWith(
        skippedDates: event.skippedDates.where((d) => d != date).toList(),
        updatedAt: _clock().toUtc(),
      );
      return _commit(next);
    });
  }

  /// Deletes every event in [ids] in one save. Returns what was removed, in
  /// stored order with positions, for [restoreMany]; `null` if saving
  /// failed.
  Future<List<({Event event, int index})>?> deleteMany(Set<String> ids) {
    return _serialized(() async {
      final removed = <({Event event, int index})>[];
      final next = <Event>[];
      for (var i = 0; i < _events.length; i++) {
        final event = _events[i];
        if (ids.contains(event.id)) {
          removed.add((event: event, index: i));
        } else {
          next.add(event);
        }
      }
      if (removed.isEmpty) return removed;
      return await _commit(next) ? removed : null;
    });
  }

  /// Puts back events returned by [deleteMany] at their old positions,
  /// skipping any whose ID is in use again.
  Future<bool> restoreMany(List<({Event event, int index})> removed) {
    return _serialized(() async {
      final next = [..._events];
      for (final item in [...removed]..sort((a, b) => a.index - b.index)) {
        if (next.any((e) => e.id == item.event.id)) continue;
        next.insert(min(item.index, next.length), item.event);
      }
      return _commit(next);
    });
  }

  /// IDs of imported events that repeat another event: the same title
  /// (ignoring case and spacing), next date and time. The user's own events
  /// are always kept; when only imported copies exist, the active, then the
  /// oldest one is kept.
  Set<String> duplicateIds({DateTime? now}) {
    final at = now ?? _clock();
    final groups = <String, List<Event>>{};
    for (final event in _events) {
      final date = eventCountdown(event, at).date;
      groups.putIfAbsent(occurrenceKey(event, date), () => []).add(event);
    }
    final duplicates = <String>{};
    for (final group in groups.values) {
      if (group.length < 2) continue;
      final imported = group.where((e) => e.source != null).toList()
        ..sort((a, b) {
          if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
          return a.createdAt.compareTo(b.createdAt);
        });
      final hasOwn = imported.length < group.length;
      duplicates.addAll(imported.skip(hasOwn ? 0 : 1).map((e) => e.id));
    }
    return duplicates;
  }

  /// Deletes the events [duplicateIds] finds, for [restoreMany].
  Future<List<({Event event, int index})>?> removeDuplicates() =>
      deleteMany(duplicateIds());

  /// Removes every event and any recovered backup ([EventStorage.clear]).
  Future<bool> deleteAll() {
    return _serialized(() async {
      bool cleared;
      try {
        cleared = await _storage.clear();
      } catch (_) {
        cleared = false;
      }
      if (!cleared) return false;
      _events = const [];
      _status = LoadStatus.ready;
      _lastDeleted = null;
      _notify();
      return true;
    });
  }

  /// An unsaved copy of the event for the editor, with a new ID and new
  /// timestamps. Pass it to [add] to save it.
  Event duplicateDraft(String id) {
    final original = eventById(id);
    if (original == null) {
      throw ArgumentError.value(id, 'id', 'no event with this id');
    }
    final now = _clock().toUtc();
    // A copy is the user's own event, not the imported record.
    return original.copyWith(
      id: _uniqueId(),
      createdAt: now,
      updatedAt: now,
      source: null,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<bool> _commit(List<Event> next) async {
    final previous = _events;
    _events = List.unmodifiable(next);
    _notify();
    bool saved;
    try {
      saved = await _storage.save(_events);
    } catch (_) {
      saved = false;
    }
    if (!saved) {
      _events = previous;
      _notify();
    }
    return saved;
  }

  int _indexOf(String id) => _events.indexWhere((event) => event.id == id);

  String _uniqueId() => _uniqueIdAmong(_events);

  String _uniqueIdAmong(List<Event> events) {
    for (var attempt = 0; attempt < 1000; attempt++) {
      final id = _newId();
      if (id.isNotEmpty && !events.any((event) => event.id == id)) return id;
    }
    throw StateError('Could not generate a unique event id');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
