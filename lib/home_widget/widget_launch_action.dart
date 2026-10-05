/// What a tap on the home screen widget asks the app to show.
sealed class WidgetLaunchAction {
  const WidgetLaunchAction();

  /// Reads the map sent by Android, for example
  /// `{'action': 'event', 'eventId': '9f1c…'}`. Returns `null` for anything
  /// it doesn't recognise.
  static WidgetLaunchAction? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final eventId = raw['eventId'];
    return switch (raw['action']) {
      'upcoming' => const OpenUpcoming(),
      'addEvent' => const AddEvent(),
      'event' when eventId is String && eventId.isNotEmpty => OpenEvent(
        eventId,
      ),
      _ => null,
    };
  }
}

/// The widget header, or a widget whose only events are paused or passed.
class OpenUpcoming extends WidgetLaunchAction {
  const OpenUpcoming();

  @override
  bool operator ==(Object other) => other is OpenUpcoming;

  @override
  int get hashCode => (OpenUpcoming).hashCode;
}

/// One event in the widget.
class OpenEvent extends WidgetLaunchAction {
  const OpenEvent(this.eventId);

  final String eventId;

  @override
  bool operator ==(Object other) =>
      other is OpenEvent && other.eventId == eventId;

  @override
  int get hashCode => eventId.hashCode;
}

/// The widget when there are no events at all.
class AddEvent extends WidgetLaunchAction {
  const AddEvent();

  @override
  bool operator ==(Object other) => other is AddEvent;

  @override
  int get hashCode => (AddEvent).hashCode;
}
