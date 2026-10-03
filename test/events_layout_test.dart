import 'package:agecalculator/app.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/screens/event_detail_screen.dart';
import 'package:agecalculator/screens/event_editor_screen.dart';
import 'package:agecalculator/screens/settings_screen.dart';
import 'package:agecalculator/screens/upcoming_screen.dart';
import 'package:agecalculator/widgets/event_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_driver.dart';
import 'support/upcoming_fixtures.dart';

const _sizes = {
  '320x568': Size(320, 568),
  '360x640': Size(360, 640),
  '412x915': Size(412, 915),
  '1280x800': Size(1280, 800),
};
const _textScales = [1.0, 1.3, 2.0];

Future<void> _launch(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  Map<String, Object> preferences = const {},
}) async {
  tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  setSurfaceSize(tester, size);
  SharedPreferences.setMockInitialValues(preferences);
  await tester.pumpWidget(const AgeCalculatorApp(clock: fixedNow));
  await tester.pumpAndSettle();
}

Future<void> _openUpcoming(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Upcoming'),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _upcomingScrollable => find
    .descendant(
      of: find.byType(UpcomingScreen),
      matching: find.byType(Scrollable),
    )
    .first;

/// [finder]'s text offers no line break between a number and its unit, and
/// every number-and-unit pair that fits on a line is drawn on one line.
///
/// The test font draws every glyph 1em wide, so at large text sizes a single
/// pair can be wider than the line; such a pair has to be broken somewhere
/// and is only checked for the missing break opportunity.
void _expectNumbersStayWithUnits(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final text = paragraph.text.toPlainText();
  expect(text, isNot(matches(RegExp(r'\d '))), reason: text);

  final pairs = RegExp(r'\d+\s\p{L}+', unicode: true).allMatches(text);
  expect(pairs, isNotEmpty, reason: text);
  for (final pair in pairs) {
    final pairPainter = TextPainter(
      text: TextSpan(text: pair[0], style: paragraph.text.style),
      textScaler: paragraph.textScaler,
      textDirection: TextDirection.ltr,
    )..layout();
    final fitsOnALine = pairPainter.width <= paragraph.size.width;
    pairPainter.dispose();
    if (!fitsOnALine) continue;

    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: pair.start, extentOffset: pair.end),
    );
    final lineTops = boxes.map((box) => box.top.round()).toSet();
    expect(lineTops, hasLength(1), reason: '"${pair[0]}" in "$text"');
  }
}

void main() {
  group('UI-01 Upcoming layouts', () {
    for (final MapEntry(key: name, value: size) in _sizes.entries) {
      for (final scale in _textScales) {
        testWidgets('$name at text scale $scale: empty state', (tester) async {
          await _launch(tester, size: size, textScale: scale);
          await _openUpcoming(tester);
          expect(tester.takeException(), isNull);

          await tester.scrollUntilVisible(
            find.text('Calculate an age'),
            200,
            scrollable: _upcomingScrollable,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final button = tester.getRect(
            find.widgetWithText(OutlinedButton, 'Calculate an age'),
          );
          expect(button.left, greaterThanOrEqualTo(0));
          expect(button.right, lessThanOrEqualTo(size.width));
          expect(button.height, greaterThanOrEqualTo(48));
        });

        testWidgets('$name at text scale $scale: twelve events', (
          tester,
        ) async {
          await _launch(
            tester,
            size: size,
            textScale: scale,
            preferences: storedEvents(mixedEvents()),
          );
          expect(find.byType(UpcomingScreen), findsOneWidget);
          expect(find.text('Next'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.scrollUntilVisible(
            find.text('Paused trip'),
            200,
            scrollable: _upcomingScrollable,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // At the end of the list the last tile sits clear of the FAB.
          await tester.drag(_upcomingScrollable, const Offset(0, -10000));
          await tester.pumpAndSettle();
          final lastTile = tester.getRect(
            find.ancestor(
              of: find.text('Paused trip'),
              matching: find.byType(Card),
            ),
          );
          final fab = tester.getRect(find.byType(FloatingActionButton));
          expect(lastTile.bottom, lessThanOrEqualTo(fab.top));
          expect(lastTile.left, greaterThanOrEqualTo(0));
          expect(lastTile.right, lessThanOrEqualTo(size.width));
        });
      }
    }

    testWidgets('wide screens keep the list at a readable width', (
      tester,
    ) async {
      await _launch(
        tester,
        size: const Size(1280, 800),
        textScale: 1.0,
        preferences: storedEvents(mixedEvents()),
      );

      final card = tester.getRect(
        find.ancestor(
          of: find.text('Project review'),
          matching: find.byType(Card),
        ),
      );
      expect(card.width, lessThanOrEqualTo(720));
      expect(card.center.dx, moreOrLessEquals(640, epsilon: 1));
    });

    testWidgets('the Age tab is unchanged beside the Upcoming tab', (
      tester,
    ) async {
      await _launch(
        tester,
        size: const Size(320, 568),
        textScale: 2.0,
        preferences: storedEvents(mixedEvents()),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Age'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Calculate your exact age instantly.'), findsOneWidget);
      expect(find.byType(UpcomingScreen), findsNothing);
    });
  });

  group('UI-01 detail and editor layouts', () {
    final longEvent =
        testEvent(
          'party',
          "Grandma Lakshmi's eightieth birthday celebration",
          category: EventCategory.birthday,
          date: CivilDate(1946, 6, 20),
          time: LocalTime(18, 30),
          recurrence: Recurrence.yearly,
        ).copyWith(
          notes:
              'Community hall, second floor. Bring the photo album and the '
              'receipt for the cake order.',
        );

    Finder scrollableIn(Type screen) => find
        .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
        .first;

    void expectOnScreen(WidgetTester tester, Finder finder, Size size) {
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
      expect(rect.right, lessThanOrEqualTo(size.width), reason: '$finder');
    }

    for (final MapEntry(key: name, value: size) in _sizes.entries) {
      for (final scale in _textScales) {
        testWidgets('$name at text scale $scale: detail', (tester) async {
          await _launch(
            tester,
            size: size,
            textScale: scale,
            preferences: storedEvents([longEvent]),
          );
          await tester.tap(find.text(longEvent.title));
          await tester.pumpAndSettle();
          expect(find.byType(EventDetailScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          for (final label in ['Edit', 'Duplicate', 'Delete']) {
            final button = find.ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            );
            await tester.scrollUntilVisible(
              button,
              200,
              scrollable: scrollableIn(EventDetailScreen),
            );
            await tester.pumpAndSettle();
            expectOnScreen(tester, button, size);
            expect(
              tester.getSize(button).height,
              greaterThanOrEqualTo(48),
              reason: label,
            );
          }
          expect(tester.takeException(), isNull);
        });

        testWidgets('$name at text scale $scale: editor', (tester) async {
          await _launch(
            tester,
            size: size,
            textScale: scale,
            preferences: storedEvents([longEvent]),
          );
          await tester.tap(find.text(longEvent.title));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Edit'),
            200,
            scrollable: scrollableIn(EventDetailScreen),
          );
          await tester.ensureVisible(find.text('Edit'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Edit'));
          await tester.pumpAndSettle();
          expect(find.byType(EventEditorScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          expectOnScreen(tester, find.byTooltip('Cancel'), size);
          expectOnScreen(tester, find.widgetWithText(TextButton, 'Save'), size);

          final notes = find.widgetWithText(TextField, 'Notes (optional)');
          await tester.scrollUntilVisible(
            notes,
            200,
            scrollable: scrollableIn(EventEditorScreen),
          );
          await tester.pumpAndSettle();
          expectOnScreen(tester, notes, size);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('UI-01 Settings layouts', () {
    Finder settingsScrollable() => find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    for (final MapEntry(key: name, value: size) in _sizes.entries) {
      for (final scale in _textScales) {
        testWidgets('$name at text scale $scale: settings', (tester) async {
          await _launch(tester, size: size, textScale: scale);
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text('Settings'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          final themes = tester.getRect(
            find.byType(SegmentedButton<ThemeMode>),
          );
          expect(themes.left, greaterThanOrEqualTo(0));
          expect(themes.right, lessThanOrEqualTo(size.width));
          for (final label in ['System', 'Light', 'Dark']) {
            final segment = find.ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            );
            expect(
              tester.getSize(segment).height,
              greaterThanOrEqualTo(40),
              reason: label,
            );
          }

          final deleteAll = find.widgetWithText(
            OutlinedButton,
            'Delete all events',
          );
          await tester.scrollUntilVisible(
            deleteAll,
            200,
            scrollable: settingsScrollable(),
          );
          await tester.pumpAndSettle();
          final button = tester.getRect(deleteAll);
          expect(button.right, lessThanOrEqualTo(size.width));
          expect(button.height, greaterThanOrEqualTo(48));

          final note = find.textContaining('stored only on this device');
          await tester.scrollUntilVisible(
            note,
            200,
            scrollable: settingsScrollable(),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(note).right, lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final (name, size, scale, direction) in [
      ('412x915 at 1.0', const Size(412, 915), 1.0, Axis.horizontal),
      ('1280x800 at 2.0', const Size(1280, 800), 2.0, Axis.horizontal),
      ('320x568 at 2.0', const Size(320, 568), 2.0, Axis.vertical),
      ('360x640 at 1.3', const Size(360, 640), 1.3, Axis.vertical),
    ]) {
      testWidgets('$name lays the theme choices out ${direction.name}', (
        tester,
      ) async {
        await _launch(tester, size: size, textScale: scale);
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Settings'),
          ),
        );
        await tester.pumpAndSettle();

        final themes = tester.widget<SegmentedButton<ThemeMode>>(
          find.byType(SegmentedButton<ThemeMode>),
        );
        expect(themes.direction, direction);
      });
    }

    testWidgets('Save as birthday fits at 2.0 on 320dp', (tester) async {
      await _launch(tester, size: const Size(412, 915), textScale: 1.0);
      await typeDate(tester, 'Calculate Age As Of', '06/15/2026');
      await typeDate(tester, 'Date of Birth', '03/15/2000');
      setSurfaceSize(tester, const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      await tester.pumpAndSettle();

      final saveBirthday = find.widgetWithText(
        OutlinedButton,
        'Save as birthday',
      );
      await tester.ensureVisible(saveBirthday);
      await tester.pumpAndSettle();
      final rect = tester.getRect(saveBirthday);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  });

  group('UI-02 countdown labels', () {
    test('numbers are joined to their units by no-break spaces', () {
      expect(
        keepNumbersWithUnits('15 days 21 hours left'),
        '15\u00A0days 21\u00A0hours left',
      );
      expect(keepNumbersWithUnits('1 minute left'), '1\u00A0minute left');
      expect(keepNumbersWithUnits('Tomorrow'), 'Tomorrow');
    });

    for (final scale in _textScales) {
      testWidgets('320x568 at text scale $scale: no number is split', (
        tester,
      ) async {
        await _launch(
          tester,
          size: const Size(320, 568),
          textScale: scale,
          preferences: storedEvents(mixedEvents()),
        );

        for (final title in [
          'Project review',
          'Morning run',
          'Flight to Goa',
          'Final exam',
          'Wedding anniversary',
        ]) {
          final tile = find.ancestor(
            of: find.text(title),
            matching: find.byType(EventTile),
          );
          await tester.scrollUntilVisible(
            tile,
            200,
            scrollable: _upcomingScrollable,
          );
          await tester.pumpAndSettle();
          final status = tester.widget<EventTile>(tile).status;
          _expectNumbersStayWithUnits(
            tester,
            find.descendant(of: tile, matching: find.text(displayed(status))),
          );
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the hero is readable at 2.0 on 320dp', (tester) async {
      await _launch(
        tester,
        size: const Size(320, 568),
        textScale: 2.0,
        preferences: storedEvents([
          testEvent(
            'exam',
            'Final exam',
            date: mixedEvents()[5].date,
            time: mixedEvents()[5].time,
          ),
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Final exam'), findsOneWidget);

      final label = find.text(displayed('15 days 21 hours left'));
      await tester.scrollUntilVisible(
        label,
        100,
        scrollable: _upcomingScrollable,
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(label);
      final appBar = tester.getRect(
        find.descendant(
          of: find.byType(UpcomingScreen),
          matching: find.byType(AppBar),
        ),
      );
      final navigationBar = tester.getRect(find.byType(NavigationBar));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.top, greaterThanOrEqualTo(appBar.bottom));
      expect(rect.bottom, lessThanOrEqualTo(navigationBar.top));
      _expectNumbersStayWithUnits(tester, label);
      expect(tester.takeException(), isNull);
    });
  });
}
