import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/screens/event_editor_screen.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_driver.dart';
import 'support/event_screens_driver.dart';
import 'support/upcoming_fixtures.dart';

final _today = CivilDate(2026, 6, 15);

Finder get _titleField => find.widgetWithText(TextField, 'Title');
Finder get _notesField => find.widgetWithText(TextField, 'Notes (optional)');
Finder get _saveButton => find.widgetWithText(TextButton, 'Save');
Finder get _allDaySwitch => find.widgetWithText(SwitchListTile, 'All day');
Finder get _repeat => find.byType(DropdownButton<Recurrence>);
Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<TextButton>(_saveButton).onPressed != null;

Recurrence? _repeatValue(WidgetTester tester) =>
    tester.widget<DropdownButton<Recurrence>>(_repeat).value;

String _text(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

List<String> _selectedChips(WidgetTester tester) => tester
    .widgetList<ChoiceChip>(find.byType(ChoiceChip))
    .where((chip) => chip.selected)
    .map((chip) => (chip.label as Text).data!)
    .toList();

Future<void> _save(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(_saveButton);
  await tester.pumpAndSettle();
}

Future<void> _chooseRepeat(WidgetTester tester, String label) async {
  await tester.tap(_repeat);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _cancel(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Cancel'));
  await tester.pumpAndSettle();
}

Event _timedEvent({bool enabled = true}) => testEvent(
  'exam',
  'Final exam',
  category: EventCategory.exam,
  date: CivilDate(2026, 7, 1),
  time: LocalTime(9, 30),
  enabled: enabled,
).copyWith(notes: 'Hall B');

class _Editor {
  _Editor(this.harness, this.results);

  final ControllerHarness harness;
  final List<Object?> results;

  EventController get events => harness.controller;
}

Future<_Editor> _openCreate(
  WidgetTester tester, {
  List<Event> events = const [],
  TestClock? clock,
}) async {
  useEnglishUs(tester);
  final harness = await loadController(clock ?? TestClock(), events: events);
  final results = await pushPage(
    tester,
    () => EventEditorScreen.create(
      events: harness.controller,
      initialDate: _today,
    ),
  );
  return _Editor(harness, results);
}

Future<_Editor> _openEdit(
  WidgetTester tester,
  Event event, {
  TestClock? clock,
}) async {
  useEnglishUs(tester);
  final harness = await loadController(clock ?? TestClock(), events: [event]);
  final results = await pushPage(
    tester,
    () => EventEditorScreen.edit(
      events: harness.controller,
      event: harness.controller.eventById(event.id)!,
    ),
  );
  return _Editor(harness, results);
}

void main() {
  group('opening the editor', () {
    testWidgets('create: empty title, today, all day, no repeat', (
      tester,
    ) async {
      await _openCreate(tester);

      expect(find.text('New event'), findsOneWidget);
      expect(_text(tester, _titleField), isEmpty);
      expect(_selectedChips(tester), ['Event']);
      expect(
        find.descendant(
          of: datePickerButton('Date'),
          matching: find.text('15 June 2026'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<SwitchListTile>(_allDaySwitch).value, isTrue);
      expect(find.text('Time'), findsNothing);
      expect(_repeatValue(tester), Recurrence.none);
      expect(_text(tester, _notesField), isEmpty);
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('every category is offered with its icon', (tester) async {
      await _openCreate(tester);

      const categories = {
        'Birthday': Icons.cake_rounded,
        'Anniversary': Icons.favorite_rounded,
        'Travel': Icons.flight_takeoff_rounded,
        'Exam': Icons.school_rounded,
        'Meeting': Icons.groups_rounded,
        'Event': Icons.event_rounded,
        'Important date': Icons.star_rounded,
        'Other': Icons.label_rounded,
      };
      expect(find.byType(ChoiceChip), findsNWidgets(categories.length));
      for (final MapEntry(key: label, value: icon) in categories.entries) {
        expect(
          find.descendant(of: _chip(label), matching: find.byIcon(icon)),
          findsOneWidget,
          reason: label,
        );
      }
    });

    testWidgets('edit: every field is prefilled', (tester) async {
      await _openEdit(tester, _timedEvent());

      expect(find.text('Edit event'), findsOneWidget);
      expect(_text(tester, _titleField), 'Final exam');
      expect(_selectedChips(tester), ['Exam']);
      expect(
        find.descendant(
          of: datePickerButton('Date'),
          matching: find.text('01 July 2026'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<SwitchListTile>(_allDaySwitch).value, isFalse);
      expect(find.widgetWithText(OutlinedButton, '9:30 AM'), findsOneWidget);
      expect(_repeatValue(tester), Recurrence.none);
      expect(_text(tester, _notesField), 'Hall B');
      expect(_saveEnabled(tester), isTrue);
    });
  });

  group('validation', () {
    testWidgets('Save is enabled only with a non-blank title', (tester) async {
      await _openCreate(tester);

      await tester.enterText(_titleField, '   ');
      await tester.pump();
      expect(_saveEnabled(tester), isFalse);

      await tester.enterText(_titleField, ' Trip ');
      await tester.pump();
      expect(_saveEnabled(tester), isTrue);

      await tester.enterText(_titleField, '');
      await tester.pump();
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('the title is trimmed and at most 80 characters', (
      tester,
    ) async {
      final editor = await _openCreate(tester);

      await tester.enterText(_titleField, 'x' * 100);
      await tester.pump();
      expect(_text(tester, _titleField), hasLength(80));
      expect(find.text('80/80'), findsOneWidget);

      await tester.enterText(_titleField, '  Sai\'s birthday  ');
      await _save(tester);
      expect(editor.events.events.single.title, "Sai's birthday");
    });

    testWidgets('notes are at most 500 characters', (tester) async {
      final editor = await _openCreate(tester);

      await tester.enterText(_titleField, 'Trip');
      await tester.enterText(_notesField, 'n' * 600);
      await tester.pump();
      expect(_text(tester, _notesField), hasLength(500));
      expect(find.text('500/500'), findsOneWidget);

      await _save(tester);
      expect(editor.events.events.single.notes, hasLength(500));
    });
  });

  group('creating', () {
    testWidgets('saves through the controller and returns the event', (
      tester,
    ) async {
      final editor = await _openCreate(tester);

      await tester.enterText(_titleField, 'Flight to Goa');
      await tester.tap(_chip('Travel'));
      await tester.pump();
      await typeEventDate(tester, '06/18/2026');
      await _save(tester);

      final saved = editor.events.events.single;
      expect(saved.id, 'new-1');
      expect(saved.title, 'Flight to Goa');
      expect(saved.category, EventCategory.travel);
      expect(saved.date, CivilDate(2026, 6, 18));
      expect(saved.time, isNull);
      expect(saved.recurrence, Recurrence.none);
      expect(saved.notes, isNull);
      expect(saved.enabled, isTrue);
      expect(saved.createdAt, fixedNow().toUtc());
      expect(saved.updatedAt, fixedNow().toUtc());
      expect(editor.results, [saved]);
      expect(find.text('New event'), findsNothing);
    });

    testWidgets('a timed, repeating event with notes', (tester) async {
      tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
      addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
      final editor = await _openCreate(tester);

      await tester.enterText(_titleField, 'Standup');
      await tester.tap(_chip('Meeting'));
      await tester.tap(_allDaySwitch);
      await tester.pumpAndSettle();
      await typeTime(tester, '14', '30');
      await _chooseRepeat(tester, 'Every week');
      await tester.enterText(_notesField, 'Room 4\nBring the slides');
      await _save(tester);

      final saved = editor.events.events.single;
      expect(saved.category, EventCategory.meeting);
      expect(saved.date, _today);
      expect(saved.time, LocalTime(14, 30));
      expect(saved.recurrence, Recurrence.weekly);
      expect(saved.notes, 'Room 4\nBring the slides');
    });

    testWidgets('a failed save keeps the editor open with its input', (
      tester,
    ) async {
      final editor = await _openCreate(tester);
      editor.harness.storage.failSaves = true;

      await tester.enterText(_titleField, 'Trip');
      await _save(tester);

      expect(find.text("Couldn't save. Please try again."), findsOneWidget);
      expect(find.text('New event'), findsOneWidget);
      expect(_text(tester, _titleField), 'Trip');
      expect(editor.events.events, isEmpty);
      expect(editor.results, isEmpty);

      editor.harness.storage.failSaves = false;
      await _save(tester);
      expect(editor.events.events.single.title, 'Trip');
    });
  });

  group('editing', () {
    testWidgets('keeps id, createdAt and Active state; bumps updatedAt', (
      tester,
    ) async {
      final clock = TestClock(DateTime(2026, 6, 20, 8));
      final original = _timedEvent(enabled: false);
      final editor = await _openEdit(tester, original, clock: clock);

      await tester.enterText(_titleField, 'Final exam (maths)');
      await _save(tester);

      final saved = editor.events.events.single;
      expect(saved.id, original.id);
      expect(saved.title, 'Final exam (maths)');
      expect(saved.createdAt, original.createdAt);
      expect(saved.updatedAt, DateTime(2026, 6, 20, 8).toUtc());
      expect(saved.enabled, isFalse);
      expect(saved.time, LocalTime(9, 30));
      expect(saved.notes, 'Hall B');
      expect(editor.results, [saved]);
    });

    testWidgets('notes can be changed and cleared', (tester) async {
      final editor = await _openEdit(tester, _timedEvent());

      await tester.enterText(_notesField, 'Hall C');
      await _save(tester);
      expect(editor.events.events.single.notes, 'Hall C');
    });

    testWidgets('clearing the notes stores none', (tester) async {
      final editor = await _openEdit(tester, _timedEvent());

      await tester.enterText(_notesField, '  ');
      await _save(tester);
      expect(editor.events.events.single.notes, isNull);
    });

    testWidgets('a failed update keeps the editor open', (tester) async {
      final editor = await _openEdit(tester, _timedEvent());
      editor.harness.storage.failSaves = true;

      await tester.enterText(_titleField, 'Changed');
      await _save(tester);
      expect(find.text("Couldn't save. Please try again."), findsOneWidget);
      expect(find.text('Edit event'), findsOneWidget);
      expect(editor.events.events.single.title, 'Final exam');
    });
  });

  group('duplicating', () {
    testWidgets('saves a new event and leaves the original alone', (
      tester,
    ) async {
      useEnglishUs(tester);
      final harness = await loadController(
        TestClock(),
        events: [_timedEvent()],
      );
      final events = harness.controller;
      final results = await pushPage(
        tester,
        () => EventEditorScreen.duplicate(
          events: events,
          draft: events.duplicateDraft('exam'),
        ),
      );

      expect(find.text('Duplicate event'), findsOneWidget);
      expect(_text(tester, _titleField), 'Final exam');
      expect(_text(tester, _notesField), 'Hall B');
      await _save(tester);

      expect(events.events, hasLength(2));
      final original = events.eventById('exam')!;
      final copy = events.events.last;
      expect(copy.id, isNot('exam'));
      expect(copy.createdAt, fixedNow().toUtc());
      expect(
        copy.copyWith(
          id: original.id,
          createdAt: original.createdAt,
          updatedAt: original.updatedAt,
        ),
        original,
      );
      expect(results, [copy]);
    });
  });

  group('date and time', () {
    testWidgets('the date picker takes the device date order (en_GB)', (
      tester,
    ) async {
      final editor = await _openCreate(tester);
      tester.platformDispatcher.localeTestValue = const Locale('en', 'GB');

      await tester.enterText(_titleField, 'Trip');
      await typeEventDate(tester, '20/06/2026');
      expect(find.text('20 June 2026'), findsOneWidget);
      await _save(tester);
      expect(editor.events.events.single.date, CivilDate(2026, 6, 20));
    });

    testWidgets('dates are limited to 1900–2100', (tester) async {
      await _openCreate(tester);

      await tester.tap(datePickerButton('Date'));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, DateTime(1900));
      expect(picker.lastDate, DateTime(2100, 12, 31));
    });

    testWidgets('turning All day off asks for a time (12-hour)', (
      tester,
    ) async {
      final editor = await _openCreate(tester);
      await tester.enterText(_titleField, 'Call');

      await tester.tap(_allDaySwitch);
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(_allDaySwitch).value, isFalse);
      expect(find.widgetWithText(OutlinedButton, '9:00 AM'), findsOneWidget);
      await _save(tester);
      expect(editor.events.events.single.time, LocalTime(9, 0));
    });

    testWidgets('cancelling the time picker keeps the event all day', (
      tester,
    ) async {
      await _openCreate(tester);

      await tester.tap(_allDaySwitch);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(_allDaySwitch).value, isTrue);
      expect(find.text('Time'), findsNothing);
    });

    testWidgets('the time can be changed (24-hour)', (tester) async {
      tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
      addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
      final editor = await _openEdit(tester, _timedEvent());

      await tester.tap(find.widgetWithText(OutlinedButton, '09:30'));
      await tester.pumpAndSettle();
      await typeTime(tester, '18', '05');
      expect(find.widgetWithText(OutlinedButton, '18:05'), findsOneWidget);
      await _save(tester);
      expect(editor.events.events.single.time, LocalTime(18, 5));
    });

    testWidgets('turning All day on clears the time', (tester) async {
      final editor = await _openEdit(tester, _timedEvent());

      await tester.tap(_allDaySwitch);
      await tester.pumpAndSettle();
      expect(find.text('Time'), findsNothing);
      expect(find.byType(TimePickerDialog), findsNothing);
      await _save(tester);
      expect(editor.events.events.single.time, isNull);
      expect(editor.events.events.single.isAllDay, isTrue);
    });

    testWidgets('turning All day off again starts from the cleared time', (
      tester,
    ) async {
      final editor = await _openEdit(tester, _timedEvent());

      await tester.tap(_allDaySwitch);
      await tester.pumpAndSettle();
      await tester.tap(_allDaySwitch);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await _save(tester);
      expect(editor.events.events.single.time, LocalTime(9, 30));
    });
  });

  group('repeat', () {
    const labels = {
      'Does not repeat': Recurrence.none,
      'Every day': Recurrence.daily,
      'Every week': Recurrence.weekly,
      'Every month': Recurrence.monthly,
      'Every year': Recurrence.yearly,
    };

    testWidgets('offers the five recurrences, in order', (tester) async {
      await _openCreate(tester);

      final items = tester.widget<DropdownButton<Recurrence>>(_repeat).items!;
      expect(items.map((item) => item.value), Recurrence.values);
      expect(items.map((item) => (item.child as Text).data), labels.keys);
    });

    for (final MapEntry(key: label, value: recurrence) in labels.entries) {
      testWidgets('choosing "$label" saves $recurrence', (tester) async {
        final editor = await _openEdit(
          tester,
          testEvent(
            'e',
            'Gym',
            date: _today,
            recurrence: recurrence == Recurrence.none
                ? Recurrence.daily
                : Recurrence.none,
          ),
        );

        await _chooseRepeat(tester, label);
        expect(_repeatValue(tester), recurrence);
        await _save(tester);
        expect(editor.events.events.single.recurrence, recurrence);
      });
    }

    testWidgets('Birthday and Anniversary default to Every year', (
      tester,
    ) async {
      await _openCreate(tester);

      await tester.tap(_chip('Birthday'));
      await tester.pump();
      expect(_repeatValue(tester), Recurrence.yearly);

      await tester.tap(_chip('Exam'));
      await tester.pump();
      expect(_repeatValue(tester), Recurrence.yearly);

      await _chooseRepeat(tester, 'Does not repeat');
      await tester.tap(_chip('Anniversary'));
      await tester.pump();
      expect(_repeatValue(tester), Recurrence.none);
    });

    testWidgets('a Repeat chosen first is kept for a birthday', (tester) async {
      final editor = await _openCreate(tester);

      await _chooseRepeat(tester, 'Every month');
      await tester.tap(_chip('Birthday'));
      await tester.pump();
      expect(_repeatValue(tester), Recurrence.monthly);

      await tester.enterText(_titleField, 'Half-birthday');
      await _save(tester);
      expect(editor.events.events.single.recurrence, Recurrence.monthly);
      expect(editor.events.events.single.category, EventCategory.birthday);
    });
  });

  group('NV-06 leaving the editor', () {
    testWidgets('without changes, Cancel closes it at once', (tester) async {
      final editor = await _openCreate(tester);

      await _cancel(tester);
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New event'), findsNothing);
      expect(editor.results, [null]);
      expect(editor.events.events, isEmpty);
    });

    testWidgets('an unchanged edit closes without asking', (tester) async {
      final editor = await _openEdit(tester, _timedEvent());

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(editor.results, [null]);
    });

    testWidgets('with changes, Cancel asks first; Keep editing stays', (
      tester,
    ) async {
      final editor = await _openCreate(tester);
      await tester.enterText(_titleField, 'Trip');
      await tester.pump();

      await _cancel(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      expect(find.text('New event'), findsOneWidget);
      expect(_text(tester, _titleField), 'Trip');
      expect(editor.results, isEmpty);
    });

    testWidgets('Discard closes without saving', (tester) async {
      final editor = await _openCreate(tester);
      await tester.enterText(_titleField, 'Trip');
      await tester.pump();

      await _cancel(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('New event'), findsNothing);
      expect(editor.results, [null]);
      expect(editor.events.events, isEmpty);
    });

    testWidgets('Android back asks too', (tester) async {
      final editor = await _openEdit(tester, _timedEvent());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(_chip('Meeting'));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(editor.results, [null]);
      expect(editor.events.events.single.category, EventCategory.exam);
    });

    for (final (change, act) in <(String, Future<void> Function(WidgetTester))>[
      ('category', (tester) => tester.tap(_chip('Travel'))),
      ('date', (tester) => typeEventDate(tester, '06/20/2026')),
      ('repeat', (tester) => _chooseRepeat(tester, 'Every day')),
      ('notes', (tester) => tester.enterText(_notesField, 'x')),
    ]) {
      testWidgets('a changed $change counts as unsaved', (tester) async {
        await _openCreate(tester);
        await act(tester);
        await tester.pumpAndSettle();

        await _cancel(tester);
        expect(find.text('Discard changes?'), findsOneWidget, reason: change);
      });
    }

    testWidgets('undoing a change makes it unchanged again', (tester) async {
      final editor = await _openCreate(tester);
      await tester.enterText(_titleField, 'Trip');
      await tester.enterText(_titleField, '');
      await tester.pump();

      await _cancel(tester);
      expect(find.text('Discard changes?'), findsNothing);
      expect(editor.results, [null]);
    });

    testWidgets('after saving, the editor closes without asking', (
      tester,
    ) async {
      final editor = await _openCreate(tester);
      await tester.enterText(_titleField, 'Trip');
      await _save(tester);

      expect(find.text('Discard changes?'), findsNothing);
      expect(editor.results, hasLength(1));
    });
  });

  group('accessibility', () {
    testWidgets('fields, chips and switch expose their state', (tester) async {
      final semantics = tester.ensureSemantics();
      await _openCreate(tester);

      expect(
        tester.getSemantics(find.byTooltip('Cancel')),
        isSemantics(tooltip: 'Cancel', isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(_saveButton),
        isSemantics(label: 'Save', isButton: true, isEnabled: false),
      );
      expect(
        tester.getSemantics(_chip('Event')),
        isSemantics(label: 'Event', isSelected: true),
      );
      expect(
        tester.getSemantics(_chip('Exam')),
        isSemantics(label: 'Exam', isSelected: false),
      );
      expect(
        tester.getSemantics(_allDaySwitch),
        isSemantics(label: 'All day', isToggled: true),
      );
      expect(
        tester.getSemantics(datePickerButton('Date')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });
  });
}
