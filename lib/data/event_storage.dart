import 'dart:convert';

import 'package:agecalculator/data/event_codec.dart';
import 'package:agecalculator/models/event.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EventLoadStatus {
  /// The stored events were read completely (or nothing was stored yet).
  ready,

  /// Some or all stored data could not be read; the unreadable part was
  /// kept under [EventStorage.unreadableKey].
  recovered,
}

class EventLoadResult {
  const EventLoadResult({
    required this.events,
    required this.status,
    this.unreadableReason,
    this.invalidEntryCount = 0,
    this.reassignedDuplicateIds = const [],
  });

  final List<Event> events;
  final EventLoadStatus status;

  /// Set when the whole stored document was unreadable.
  final UnreadableReason? unreadableReason;

  final int invalidEntryCount;

  /// IDs that appeared more than once; the later copies were loaded with new
  /// IDs, which are stored on the next [EventStorage.save].
  final List<String> reassignedDuplicateIds;
}

/// Persists the user's events as one JSON document in the app's existing
/// SharedPreferences.
class EventStorage {
  EventStorage(
    this._preferences, {
    required String Function() newId,
    EventCodec codec = const EventCodec(),
  }) : _newId = newId,
       _codec = codec;

  static const storeKey = 'event_store';
  static const unreadableKey = 'event_store_unreadable';

  final SharedPreferences _preferences;
  final String Function() _newId;
  final EventCodec _codec;

  /// Reads the stored events.
  ///
  /// Nothing is written to [storeKey] here. Unreadable data is copied to
  /// [unreadableKey] only if that key is still empty, so the first copy is
  /// never overwritten.
  Future<EventLoadResult> load() async {
    final stored = _preferences.get(storeKey);
    if (stored == null) {
      return const EventLoadResult(events: [], status: EventLoadStatus.ready);
    }

    final raw = stored is String ? stored : jsonEncode(stored);
    final decoded = _codec.decodeDocument(raw, newId: _newId);

    if (decoded.isUnreadable) {
      await _keepUnreadable(raw);
      return EventLoadResult(
        events: const [],
        status: EventLoadStatus.recovered,
        unreadableReason: decoded.unreadableReason,
      );
    }

    if (decoded.invalidEntries.isNotEmpty) {
      await _keepUnreadable(jsonEncode(decoded.invalidEntries));
    }
    return EventLoadResult(
      events: List.unmodifiable(decoded.events),
      status: decoded.invalidEntries.isEmpty
          ? EventLoadStatus.ready
          : EventLoadStatus.recovered,
      invalidEntryCount: decoded.invalidEntries.length,
      reassignedDuplicateIds: decoded.reassignedDuplicateIds,
    );
  }

  /// Replaces the stored document with [events], in this order.
  Future<bool> save(List<Event> events) {
    return _preferences.setString(storeKey, _codec.encodeDocument(events));
  }

  /// Removes the stored document and any unreadable copy kept by [load].
  /// Other preferences are not touched.
  Future<bool> clear() async {
    final storeRemoved = await _preferences.remove(storeKey);
    final copyRemoved = await _preferences.remove(unreadableKey);
    return storeRemoved && copyRemoved;
  }

  Future<void> _keepUnreadable(String raw) async {
    if (_preferences.containsKey(unreadableKey)) return;
    await _preferences.setString(unreadableKey, raw);
  }
}
