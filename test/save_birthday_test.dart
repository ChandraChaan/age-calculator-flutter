import 'dart:math';

import 'package:agecalculator/engine/age_calculator.dart';
import 'package:agecalculator/engine/calendar_math.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/engine/upcoming_planner.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/screens/app_shell.dart';
import 'package:agecalculator/screens/event_editor_screen.dart';
import 'package:agecalculator/screens/home_screen.dart';
import 'package:agecalculator/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_driver.dart';
import 'support/app_launcher.dart';
import 'support/upcoming_fixtures.dart';

Finder get _saveBirthday =>
    find.widgetWithText(OutlinedButton, 'Save as birthday');
Finder get _titleField => find.widgetWithText(TextField, 'Title');

/// Calculates an age on the Age tab, "as of" the fixed clock's date.
Future<void> _calculate(WidgetTester tester, String dateOfBirth) async {
  await typeDate(tester, 'Calculate Age As Of', '06/15/2026');
  await typeDate(tester, 'Date of Birth', dateOfBirth);
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.ensureVisible(_saveBirthday);
  await tester.tap(_saveBirthday);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.widgetWithText(TextButton, 'Save'));
  await tester.pumpAndSettle();
}

/// The value shown next to [label] in an Age result card.
String _infoValue(WidgetTester tester, String label) {
  final row = find.ancestor(of: find.text(label), matching: find.byType(Wrap));
  return tester
      .widgetList<Text>(
        find.descendant(of: row.first, matching: find.byType(Text)),
      )
      .map((text) => text.data)
      .firstWhere((data) => data != label)!;
}

Event _birthday(
  String id,
  String title,
  CivilDate date, {
  bool enabled = true,
}) => testEvent(
  id,
  title,
  category: EventCategory.birthday,
  date: date,
  recurrence: Recurrence.yearly,
  enabled: enabled,
);

void main() {
  group('AG-01 the Save as birthday button', () {
    testWidgets('appears only with a result, under the Born on line', (
      tester,
    ) async {
      await launchApp(tester);
      expect(_saveBirthday, findsNothing);

      await _calculate(tester, '03/15/2000');
      expect(_saveBirthday, findsOneWidget);
      expect(
        find.descendant(
          of: _saveBirthday,
          matching: find.byIcon(Icons.cake_outlined),
        ),
        findsOneWidget,
      );
      final bornOn = tester.getRect(find.textContaining('Born on'));
      final button = tester.getRect(_saveBirthday);
      final years = tester.getRect(find.text('Years'));
      expect(button.top, greaterThan(bornOn.bottom));
      expect(button.bottom, lessThan(years.top));

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(_saveBirthday, findsNothing);
    });

    testWidgets('HomeScreen without the callback shows no button', (
      tester,
    ) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      setSurfaceSize(tester, const Size(412, 915));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(themeMode: ThemeMode.light, onThemeChanged: (_) {}),
        ),
      );
      await _calculate(tester, '03/15/2000');

      expect(find.text('Your Age'), findsOneWidget);
      expect(_saveBirthday, findsNothing);
    });

    testWidgets('opens the editor prefilled from the date of birth', (
      tester,
    ) async {
      await launchApp(tester);
      await _calculate(tester, '03/15/2000');
      await _openEditor(tester);

      expect(find.byType(EventEditorScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      final title = tester.widget<TextField>(_titleField);
      expect(title.controller!.text, 'Birthday');
      expect(
        title.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 8),
      );
      final editable = tester.widget<EditableText>(
        find.descendant(of: _titleField, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .where((chip) => chip.selected)
            .map((chip) => (chip.label as Text).data),
        ['Birthday'],
      );
      expect(
        find.descendant(
          of: dateTextField('Date'),
          matching: find.text('15 March 2000'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'All day'),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<DropdownButton<Recurrence>>(
              find.byType(DropdownButton<Recurrence>),
            )
            .value,
        Recurrence.yearly,
      );
    });

    testWidgets('uses the date of birth, not the "as of" date', (tester) async {
      await launchApp(tester);
      await typeDate(tester, 'Calculate Age As Of', '01/02/2020');
      await typeDate(tester, 'Date of Birth', '07/09/1985');
      await _openEditor(tester);

      expect(find.text('09 July 1985'), findsOneWidget);
      await _save(tester);
      expect(appEvents(tester).events.single.date, CivilDate(1985, 7, 9));
    });

    testWidgets('saves an ordinary yearly, all-day, active birthday', (
      tester,
    ) async {
      await launchApp(tester);
      await _calculate(tester, '03/15/2000');
      await _openEditor(tester);
      await tester.enterText(_titleField, "Sai's birthday");
      await _save(tester);

      final saved = appEvents(tester).events.single;
      expect(saved.title, "Sai's birthday");
      expect(saved.category, EventCategory.birthday);
      expect(saved.date, CivilDate(2000, 3, 15));
      expect(saved.time, isNull);
      expect(saved.recurrence, Recurrence.yearly);
      expect(saved.notes, isNull);
      expect(saved.enabled, isTrue);
      expect(saved.id, hasLength(32));
      expect(saved.createdAt, fixedNow().toUtc());
      expect(saved.updatedAt, fixedNow().toUtc());
      expect(
        (await SharedPreferences.getInstance()).containsKey('event_store'),
        isTrue,
      );
    });

    testWidgets('"Saved to Upcoming" with View switches to Upcoming', (
      tester,
    ) async {
      await launchApp(tester);
      await _calculate(tester, '03/15/2000');
      await _openEditor(tester);
      await tester.enterText(_titleField, "Sai's birthday");
      await _save(tester);

      expect(visibleTab(tester), AppTab.age);
      final snackBar = find.descendant(
        of: find.byType(AppShell),
        matching: find.byType(SnackBar),
      );
      expect(snackBar, findsOneWidget);
      expect(find.text('Saved to Upcoming'), findsOneWidget);
      expect(
        tester.getRect(snackBar).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(NavigationBar)).top),
      );

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(visibleTab(tester), AppTab.upcoming);
      expect(find.text("Sai's birthday"), findsOneWidget);
      expect(
        find.text('Turns 27 · Mon, 15 Mar 2027 · Every year'),
        findsOneWidget,
      );
    });

    testWidgets('the SnackBar goes away on its own', (tester) async {
      await launchApp(tester);
      await _calculate(tester, '03/15/2000');
      await _openEditor(tester);
      await _save(tester);
      expect(find.text('Saved to Upcoming'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Saved to Upcoming'), findsNothing);
      expect(visibleTab(tester), AppTab.age);
    });

    testWidgets('leaving without changes saves nothing', (tester) async {
      await launchApp(tester);
      await _calculate(tester, '03/15/2000');
      await _openEditor(tester);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(EventEditorScreen), findsNothing);
      expect(appEvents(tester).events, isEmpty);
      expect(find.text('Saved to Upcoming'), findsNothing);
    });

    testWidgets('a changed title asks before leaving', (tester) async {
      await launchApp(tester);
      await _calculate(tester, '03/15/2000');
      await _openEditor(tester);
      await tester.enterText(_titleField, "Sai's birthday");
      await tester.pump();

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(appEvents(tester).events, isEmpty);
    });
  });

  group('AG-02 / AG-03 the countdown matches the Age tab', () {
    for (final (dateOfBirth, next, days, turns) in [
      ('03/15/2000', CivilDate(2027, 3, 15), 273, 27),
      ('02/29/2000', CivilDate(2027, 2, 28), 258, 27),
      ('06/15/1990', CivilDate(2026, 6, 15), 0, 36),
      ('06/16/2001', CivilDate(2026, 6, 16), 1, 25),
    ]) {
      testWidgets('born $dateOfBirth: next birthday $next', (tester) async {
        await launchApp(tester);
        await _calculate(tester, dateOfBirth);
        expect(
          _infoValue(tester, 'Next Birthday Countdown'),
          days == 1 ? '1 day' : '$days days',
        );
        await _openEditor(tester);
        await _save(tester);

        final plan = appEvents(tester).upcomingPlan();
        final occurrence = plan.next!;
        expect(occurrence.date, next);
        expect(occurrence.countdown.daysUntil, days);
        expect(occurrence.yearsSinceAnchor, turns);
      });
    }
  });

  group('AG-04 a birthday on the same date', () {
    final existing = _birthday('sai', "Sai's birthday", CivilDate(2000, 3, 15));

    Future<void> openWithExisting(
      WidgetTester tester,
      List<Event> events,
    ) async {
      await launchApp(tester, preferences: storedEvents(events));
      await openTab(tester, 'Age');
      await _calculate(tester, '03/15/2000');
      await _openEditor(tester);
    }

    testWidgets('asks first; Cancel saves nothing and stays', (tester) async {
      await openWithExisting(tester, [existing]);

      await _save(tester);
      expect(
        find.text(
          "A birthday on 15 March 2000 already exists ('Sai's birthday'). "
          'Save another?',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(EventEditorScreen), findsOneWidget);
      expect(appEvents(tester).events, [existing]);
      expect(find.text('Saved to Upcoming'), findsNothing);
    });

    testWidgets('Save anyway saves a second birthday', (tester) async {
      await openWithExisting(tester, [existing]);
      await tester.enterText(_titleField, 'Sai (school)');

      await _save(tester);
      await tester.tap(find.text('Save anyway'));
      await tester.pumpAndSettle();

      final events = appEvents(tester).events;
      expect(events, hasLength(2));
      expect(events.first, existing);
      expect(events.last.title, 'Sai (school)');
      expect(events.last.date, existing.date);
      expect(find.byType(EventEditorScreen), findsNothing);
      expect(find.text('Saved to Upcoming'), findsOneWidget);
    });

    testWidgets('a paused birthday on that date counts', (tester) async {
      await openWithExisting(tester, [
        _birthday('old', 'Old entry', CivilDate(2000, 3, 15), enabled: false),
      ]);

      await _save(tester);
      expect(
        find.text(
          "A birthday on 15 March 2000 already exists ('Old entry'). "
          'Save another?',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no question for other dates, categories or events', (
      tester,
    ) async {
      await openWithExisting(tester, [
        _birthday('a', 'Other year', CivilDate(2001, 3, 15)),
        testEvent('b', 'Exam', date: CivilDate(2000, 3, 15)),
      ]);

      await _save(tester);
      expect(find.textContaining('already exists'), findsNothing);
      expect(appEvents(tester).events, hasLength(3));
    });

    testWidgets('no question once the category is not Birthday', (
      tester,
    ) async {
      await openWithExisting(tester, [existing]);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Anniversary'));
      await tester.pump();

      await _save(tester);
      expect(find.textContaining('already exists'), findsNothing);
      expect(appEvents(tester).events.last.category, EventCategory.anniversary);
    });
  });

  group('AG-05 the Age tab keeps its state', () {
    testWidgets('inputs and result survive saving and switching tabs', (
      tester,
    ) async {
      await launchApp(tester);
      await _calculate(tester, '03/15/2000');
      final homeState = tester.state(find.byType(HomeScreen));
      await _openEditor(tester);
      await _save(tester);

      expect(find.text('15 March 2000'), findsOneWidget);
      expect(find.text('Your Age'), findsOneWidget);
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await openTab(tester, 'Age');

      expect(tester.state(find.byType(HomeScreen)), same(homeState));
      expect(find.text('15 March 2000'), findsOneWidget);
      expect(find.text('15 June 2026'), findsOneWidget);
      expect(find.text('Your Age'), findsOneWidget);
      expect(_saveBirthday, findsOneWidget);
    });
  });

  group('AG-06 the event engine agrees with AgeCalculator (pure)', () {
    const calculator = AgeCalculator();
    final firstDay = CivilDate(1900, 1, 1).epochDay;
    final lastDay = CivilDate(2100, 12, 31).epochDay;

    void expectAgrees(CivilDate dateOfBirth, CivilDate today) {
      final breakdown = calculator.calculate(dateOfBirth, today)!;
      final now = DateTime(today.year, today.month, today.day, 12);
      final countdown = countdownFor(
        date: dateOfBirth,
        recurrence: Recurrence.yearly,
        now: now,
      );
      expect(
        countdown.date,
        breakdown.nextBirthday,
        reason: 'born $dateOfBirth, today $today',
      );
      expect(countdown.daysUntil, breakdown.daysUntilNextBirthday);
    }

    test('100,000 seeded pairs', () {
      final random = Random(20261003);
      for (var i = 0; i < 100000; i++) {
        final born = firstDay + random.nextInt(lastDay - firstDay + 1);
        final today = born + random.nextInt(lastDay - born + 1);
        expectAgrees(
          CivilDate.fromEpochDay(born),
          CivilDate.fromEpochDay(today),
        );
      }
    });

    test('every 29 February birth date from 1904 to 2096', () {
      for (var year = 1904; year <= 2096; year += 4) {
        if (!CalendarMath.isLeapYear(year)) continue;
        final born = CivilDate(year, 2, 29);
        for (final today in [
          CivilDate(year, 3, 1),
          CivilDate(year + 1, 2, 28),
          CivilDate(year + 1, 3, 1),
          CivilDate(year + 4, 2, CalendarMath.daysInMonth(year + 4, 2)),
        ]) {
          expectAgrees(born, today);
        }
      }
    });

    test('"Turns N" is the age reached on that birthday', () {
      final random = Random(7);
      for (var i = 0; i < 10000; i++) {
        final born = firstDay + random.nextInt(lastDay - firstDay + 1);
        final today = born + random.nextInt(lastDay - born + 1);
        final dateOfBirth = CivilDate.fromEpochDay(born);
        final todayDate = CivilDate.fromEpochDay(today);
        final event = _birthday('b', 'B', dateOfBirth);
        final now = DateTime(
          todayDate.year,
          todayDate.month,
          todayDate.day,
          12,
        );
        final occurrence = planUpcoming([event], now).next!;
        final breakdown = calculator.calculate(dateOfBirth, todayDate)!;
        final ageThatDay = breakdown.nextBirthday == todayDate
            ? breakdown.years
            : breakdown.years + 1;
        expect(occurrence.yearsSinceAnchor, ageThatDay);
      }
    });
  });

  group('findBirthdaysOn (pure)', () {
    final day = CivilDate(2000, 3, 15);

    test('matches birthday events on exactly that date', () {
      final a = _birthday('a', 'A', day);
      final paused = _birthday('p', 'P', day, enabled: false);
      final events = [
        a,
        _birthday('b', 'Next day', day.addDays(1)),
        _birthday('c', 'Other year', CivilDate(2001, 3, 15)),
        testEvent('d', 'Not a birthday', date: day),
        testEvent(
          'e',
          'Anniversary',
          category: EventCategory.anniversary,
          date: day,
          recurrence: Recurrence.yearly,
        ),
        paused,
      ];

      expect(findBirthdaysOn(events, day), [a, paused]);
      expect(findBirthdaysOn(events, CivilDate(1999, 3, 15)), isEmpty);
      expect(findBirthdaysOn(const [], day), isEmpty);
    });
  });
}
