import 'package:agecalculator/data/event_storage.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:agecalculator/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_driver.dart';
import 'upcoming_fixtures.dart';

/// Storage whose writes can be made to fail.
class FlakyStorage extends EventStorage {
  FlakyStorage(super.preferences, {required super.newId});

  bool failSaves = false;
  bool failClear = false;

  @override
  Future<bool> save(List<Event> events) async {
    if (failSaves) return false;
    return super.save(events);
  }

  @override
  Future<bool> clear() async => failClear ? false : super.clear();
}

class ControllerHarness {
  ControllerHarness._(this.controller, this.storage);

  final EventController controller;
  final FlakyStorage storage;
}

/// A loaded controller over [events], with IDs new-1, new-2, …
Future<ControllerHarness> loadController(
  TestClock clock, {
  List<Event> events = const [],
}) async {
  SharedPreferences.setMockInitialValues(storedEvents(events));
  final prefs = await SharedPreferences.getInstance();
  var ids = 0;
  String newId() => 'new-${++ids}';
  final storage = FlakyStorage(prefs, newId: newId);
  final controller = EventController(
    storage: storage,
    clock: clock.call,
    newId: newId,
  );
  await controller.load();
  return ControllerHarness._(controller, storage);
}

void useEnglishUs(WidgetTester tester) {
  tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}

/// Shows a launcher screen, then pushes [page] as a full-screen route.
/// Each time the route pops, its result is added to the returned list.
Future<List<Object?>> pushPage(
  WidgetTester tester,
  Widget Function() page, {
  Size size = const Size(412, 1400),
}) async {
  setSurfaceSize(tester, size);
  final results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                results.add(
                  await Navigator.of(context).push<Object?>(
                    MaterialPageRoute<Object?>(
                      fullscreenDialog: true,
                      builder: (_) => page(),
                    ),
                  ),
                );
              },
              child: const Text('Launcher'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Launcher'));
  await tester.pumpAndSettle();
  return results;
}

/// Types [text] into the editor's date picker and confirms it.
Future<void> typeEventDate(WidgetTester tester, String text) async {
  await tester.tap(datePickerButton('Date'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tester.tap(find.text('Select'));
  await tester.pumpAndSettle();
}

/// In an open time picker, types [hour] and [minute] and confirms.
Future<void> typeTime(WidgetTester tester, String hour, String minute) async {
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), hour);
  await tester.enterText(fields.at(1), minute);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
