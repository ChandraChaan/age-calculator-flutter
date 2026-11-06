// Renders the Play Store listing assets and the legacy launcher icons.
//
//   flutter test tool/store_assets/render_store_assets_test.dart
//
// Writes store_assets/ (icon, feature graphic, phone screenshots) and
// android/app/src/main/res/mipmap-*/ic_launcher.png. The screenshots are the
// real app widgets with sample events, rendered with Roboto and the Material
// icon font from the Flutter SDK.

// A test file outside test/, so the analyzer can't tell it is one.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:ui' as ui;

import 'package:agecalculator/app.dart';
import 'package:agecalculator/data/event_storage.dart';
import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/screens/import_screen.dart';
import 'package:agecalculator/services/device_import.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:agecalculator/theme/app_theme.dart';
import 'package:agecalculator/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/app_driver.dart';
import '../../test/support/app_launcher.dart';
import '../../test/support/upcoming_fixtures.dart';

const _out = 'store_assets';

/// One store screenshot format: the app's screen size, and the frame the
/// captioned screenshot is drawn on.
class _Device {
  const _Device({
    required this.dir,
    required this.screen,
    required this.dpr,
    required this.frame,
    required this.screenWidth,
    required this.scale,
    required this.cornerRadius,
    required this.ageScroll,
  });

  final String dir;
  final Size screen;
  final double dpr;
  final Size frame;
  final double screenWidth;

  /// Caption scale relative to the phone frame.
  final double scale;

  /// The screen's corner radius inside the bezel.
  final double cornerRadius;

  /// How far the Age screen is scrolled to show its results.
  final double ageScroll;
}

const _phone = _Device(
  dir: 'screenshots',
  screen: Size(390, 700),
  dpr: 3,
  frame: Size(1080, 1920),
  screenWidth: 760,
  scale: 1,
  cornerRadius: 56,
  ageScroll: 150,
);

const _tablet = _Device(
  dir: 'tablet',
  screen: Size(800, 1180),
  dpr: 2,
  // Play requires exactly 9:16 for tablet screenshots.
  frame: Size(1440, 2560),
  screenWidth: 1160,
  scale: 1.4,
  cornerRadius: 36,
  ageScroll: 0,
);

_Device _device = _phone;

Size get _screenLogical => _device.screen;
double get _screenDpr => _device.dpr;

String get _flutterRoot =>
    Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File(
      '$_flutterRoot/bin/cache/artifacts/material_fonts/$file',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Event _event(
  String id,
  String title, {
  required EventCategory category,
  required CivilDate date,
  LocalTime? time,
  Recurrence recurrence = Recurrence.none,
  List<int> reminders = const [0],
  bool enabled = true,
}) {
  final created = DateTime.utc(2026, 1, 1);
  return Event(
    id: id,
    title: title,
    category: category,
    date: date,
    time: time,
    recurrence: recurrence,
    enabled: enabled,
    createdAt: created,
    updatedAt: created,
    reminders: reminders,
  );
}

// fixedNow() is Monday 15 June 2026, 12:00.
final List<Event> _sampleEvents = [
  _event(
    'mom',
    "Mom's birthday",
    category: EventCategory.birthday,
    date: CivilDate(1968, 6, 18),
    recurrence: Recurrence.yearly,
    reminders: const [0, 1440],
  ),
  _event(
    'goa',
    'Goa trip',
    category: EventCategory.travel,
    date: CivilDate(2026, 6, 15),
    time: LocalTime(18, 30),
    reminders: const [60, 1440],
  ),
  _event(
    'exam',
    'Final exam',
    category: EventCategory.exam,
    date: CivilDate(2026, 6, 22),
    time: LocalTime(9, 0),
    reminders: const [60, 1440, 10080],
  ),
  _event(
    'anniv',
    'Wedding anniversary',
    category: EventCategory.anniversary,
    date: CivilDate(2019, 6, 16),
    recurrence: Recurrence.yearly,
  ),
  _event(
    'standup',
    'Team offsite',
    category: EventCategory.meeting,
    date: CivilDate(2026, 6, 19),
    time: LocalTime(10, 0),
  ),
  _event(
    'passport',
    'Passport renewal',
    category: EventCategory.importantDate,
    date: CivilDate(2026, 8, 3),
  ),
  _event(
    'arjun',
    "Arjun's birthday",
    category: EventCategory.birthday,
    date: CivilDate(2015, 9, 12),
    recurrence: Recurrence.yearly,
  ),
];

class _FakeImporter extends DeviceImporter {
  _FakeImporter() : super(enabled: true);

  @override
  Future<List<ImportCandidate>> candidates(
    ImportKind kind,
    List<Event> existing,
    DateTime now,
  ) async {
    return contactCandidates([
      {
        'contactId': '1',
        'name': 'Priya Sharma',
        'date': '1992-07-04',
        'type': 'birthday',
      },
      {
        'contactId': '2',
        'name': 'Rahul',
        'date': '--08-21',
        'type': 'birthday',
      },
      {
        'contactId': '3',
        'name': 'Ananya & Vikram',
        'date': '2018-12-09',
        'type': 'anniversary',
      },
      {
        'contactId': '4',
        'name': 'Grandpa',
        'date': '1949-10-30',
        'type': 'birthday',
      },
      {
        'contactId': '5',
        'name': 'Meera',
        'date': '2001-02-14',
        'type': 'birthday',
      },
    ], existing);
  }
}

/// Paints the app icon on a 108-unit grid, matching the adaptive icon
/// vectors. [zoom] enlarges the foreground for full-bleed uses.
class _IconPainter extends CustomPainter {
  const _IconPainter({this.zoom = 1.0, this.legacyShape = false});

  final double zoom;
  final bool legacyShape;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 108;
    final full = Offset.zero & size;
    if (legacyShape) {
      final inset = size.width * 0.04;
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          full.deflate(inset),
          Radius.circular(size.width * 0.22),
        ),
      );
    }
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF48484A), Color(0xFF1C1C1E), Color(0xFF000000)],
          stops: [0, 0.55, 1],
        ).createShader(full),
    );
    final glow = Rect.fromCircle(
      center: Offset(30 * u, 26 * u),
      radius: 58 * u,
    );
    canvas.drawRect(
      full,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
        ).createShader(glow),
    );

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(-size.width / 2, -size.height / 2);

    final card = RRect.fromLTRBR(
      30 * u,
      34 * u,
      78 * u,
      80 * u,
      Radius.circular(7 * u),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x59FFFFFF), Color(0x1AFFFFFF)],
        ).createShader(card.outerRect),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u
        ..color = const Color(0x99FFFFFF),
    );
    canvas.drawRect(
      Rect.fromLTWH(30.5 * u, 46 * u, 47 * u, u),
      Paint()..color = const Color(0x40FFFFFF),
    );
    final ring = Paint()..color = Colors.white;
    for (final x in [40.0, 64.0]) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          x * u,
          29 * u,
          (x + 4) * u,
          38 * u,
          Radius.circular(1.5 * u),
        ),
        ring,
      );
    }
    final cake = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.cake.codePoint),
        style: TextStyle(
          fontFamily: Icons.cake.fontFamily,
          fontSize: 22 * u,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    cake.paint(canvas, Offset(43 * u, 51 * u));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) => false;
}

final _boundary = GlobalKey();

Future<Uint8List> _capture(WidgetTester tester, double pixelRatio) async {
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

void _write(String path, Uint8List bytes) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}

Future<void> _renderIcon(
  WidgetTester tester,
  int pixels,
  String path, {
  double zoom = 1,
  bool legacyShape = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(pixels.toDouble(), pixels.toDouble());
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: CustomPaint(
        size: Size(pixels.toDouble(), pixels.toDouble()),
        painter: _IconPainter(zoom: zoom, legacyShape: legacyShape),
      ),
    ),
  );
  _write(path, await _capture(tester, 1));
}

/// Renders the current app state at phone size and returns it.
Future<ui.Image> _grabScreen(WidgetTester tester) async {
  final bytes = await _capture(tester, _screenDpr);
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }))!;
}

Future<void> _launch(
  WidgetTester tester, {
  required bool dark,
  List<Event> events = const [],
  bool showDeviceFeatures = false,
}) async {
  tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
  tester.view.devicePixelRatio = _screenDpr;
  tester.view.physicalSize = _screenLogical * _screenDpr;
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({
    ...storedEvents(events),
    'flutter.theme_mode': dark ? 'dark' : 'light',
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: AgeCalculatorApp(
        clock: fixedNow,
        homeWidgetSync: false,
        reminders: showDeviceFeatures,
        deviceImport: showDeviceFeatures,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The store frame: a caption over the screen, on the theme's backdrop.
Future<void> _compose(
  WidgetTester tester,
  ui.Image screen,
  String path, {
  required bool dark,
  required String title,
  required String subtitle,
}) async {
  final frame = _device.frame;
  final k = _device.scale;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = frame;
  final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  final screenWidth = _device.screenWidth;
  final screenHeight = screenWidth * screen.height / screen.width;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: Theme(
        data: theme,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final ink = theme.colorScheme.onSurface;
              return GlassBackdrop(
                child: SizedBox.fromSize(
                  size: frame,
                  child: Column(
                    children: [
                      SizedBox(height: 96 * k),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 68 * k,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.2,
                          color: ink,
                        ),
                      ),
                      SizedBox(height: 18 * k),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 34 * k,
                          height: 1.3,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 56 * k),
                      Container(
                        width: screenWidth + 16,
                        height: screenHeight + 16,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            _device.cornerRadius + 8,
                          ),
                          color: dark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFF1C1C1E),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: dark ? 0.5 : 0.18,
                              ),
                              blurRadius: 60,
                              offset: const Offset(0, 24),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            _device.cornerRadius,
                          ),
                          child: RawImage(
                            image: screen,
                            width: screenWidth,
                            height: screenHeight,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  _write(path, await _capture(tester, 1));
}

void main() {
  setUpAll(() async {
    await _loadFont('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Black.ttf',
    ]);
    await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  testWidgets('icons', (tester) async {
    addTearDown(tester.view.reset);
    await _renderIcon(tester, 512, '$_out/icon-512.png', zoom: 1.3);
    for (final (dir, px) in [
      ('mdpi', 48),
      ('hdpi', 72),
      ('xhdpi', 96),
      ('xxhdpi', 144),
      ('xxxhdpi', 192),
    ]) {
      await _renderIcon(
        tester,
        px,
        'android/app/src/main/res/mipmap-$dir/ic_launcher.png',
        zoom: 1.2,
        legacyShape: true,
      );
    }
  });

  testWidgets('feature graphic', (tester) async {
    addTearDown(tester.view.reset);
    const size = Size(1024, 500);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    final theme = AppTheme.darkTheme;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: Theme(
          data: theme,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: GlassBackdrop(
              child: SizedBox.fromSize(
                size: size,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 72),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(56),
                        child: const CustomPaint(
                          size: Size(240, 240),
                          painter: _IconPainter(zoom: 1.3),
                        ),
                      ),
                      const SizedBox(width: 56),
                      const Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Age Calculator',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 66,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.4,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Exact ages, countdowns\nand reminders.',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 32,
                                height: 1.3,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _write('$_out/feature-graphic.png', await _capture(tester, 1));
  });

  testWidgets('phone screenshots', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    _device = _phone;
    await _renderScreens(tester);
  });

  testWidgets('tablet screenshots', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    _device = _tablet;
    await _renderScreens(tester);
    _device = _phone;
  });
}

Future<void> _renderScreens(WidgetTester tester) async {
  // 1. Upcoming, light.
  await _launch(tester, dark: false, events: _sampleEvents);
  final upcomingLight = await _grabScreen(tester);
  await _compose(
    tester,
    upcomingLight,
    '$_out/${_device.dir}/01-upcoming.png',
    dark: false,
    title: 'Every date\nthat matters',
    subtitle: 'Birthdays, trips and exams, counting down.',
  );

  // 2. Exact age, light.
  await _launch(tester, dark: false);
  await typeDate(tester, 'Date of Birth', '03/14/1994');
  await tester.drag(
    find.byType(SingleChildScrollView).first,
    Offset(0, -_device.ageScroll),
  );
  await tester.pumpAndSettle();
  final age = await _grabScreen(tester);
  await _compose(
    tester,
    age,
    '$_out/${_device.dir}/02-exact-age.png',
    dark: false,
    title: 'Your exact age,\ninstantly',
    subtitle: 'Years, months, days, and every day lived.',
  );

  // 3. Event with reminders, dark.
  await _launch(tester, dark: true, events: _sampleEvents);
  await tester.scrollUntilVisible(
    find.text('Final exam'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Final exam'));
  await tester.pumpAndSettle();
  final detail = await _grabScreen(tester);
  await _compose(
    tester,
    detail,
    '$_out/${_device.dir}/03-reminders.png',
    dark: true,
    title: 'Reminders that\narrive on time',
    subtitle: 'From 10 minutes to a week before.',
  );

  // 4. Import from contacts, light.
  tester.view.devicePixelRatio = _screenDpr;
  tester.view.physicalSize = _screenLogical * _screenDpr;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final events = EventController(
    storage: EventStorage(prefs, newId: () => 'x'),
    clock: fixedNow,
    newId: () => 'y',
  );
  await events.load();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) => BackdropGroup(child: child!),
        home: ImportScreen(
          kind: ImportKind.contacts,
          importer: _FakeImporter(),
          events: events,
          clock: fixedNow,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final import = await _grabScreen(tester);
  await _compose(
    tester,
    import,
    '$_out/${_device.dir}/04-import.png',
    dark: false,
    title: 'Bring in birthdays\nin one tap',
    subtitle: 'From contacts or your calendar.\nNothing leaves your phone.',
  );

  // 5. Upcoming, dark.
  await _launch(tester, dark: true, events: _sampleEvents);
  final upcomingDark = await _grabScreen(tester);
  await _compose(
    tester,
    upcomingDark,
    '$_out/${_device.dir}/05-dark.png',
    dark: true,
    title: 'Glass, in light\nand dark',
    subtitle: 'Private, offline, no account.',
  );

  // 6. Settings, light.
  await _launch(
    tester,
    dark: false,
    events: _sampleEvents,
    showDeviceFeatures: true,
  );
  await openTab(tester, 'Settings');
  final settings = await _grabScreen(tester);
  await _compose(
    tester,
    settings,
    '$_out/${_device.dir}/06-settings.png',
    dark: false,
    title: 'Simple, and\nyours alone',
    subtitle: 'Your events stay on your device.',
  );
  events.dispose();
}
