import 'dart:convert';
import 'dart:io';

import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/countdown.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/utils/countdown_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same file is read by the Android widget's Kotlin tests, so both sides
/// word every countdown identically.
const _fixture = 'test/fixtures/home_widget_countdown_cases.json';

void main() {
  final cases =
      (jsonDecode(File(_fixture).readAsStringSync()) as Map)['cases'] as List;

  test('the fixture covers every kind of countdown wording', () {
    final labels = cases.map((c) => (c as Map)['label']).toSet();
    for (final expected in ['Today', 'Tomorrow', 'Now', null]) {
      expect(labels, contains(expected));
    }
    expect(labels.any((l) => '$l'.endsWith(' days left')), isTrue);
    expect(labels.any((l) => '$l'.contains('minute')), isTrue);
    expect(labels.any((l) => '$l'.contains('day ')), isTrue);
  });

  for (final raw in cases) {
    final entry = raw as Map;
    final time = entry['time'] as String?;
    test('${entry['now']} → ${entry['date']} ${time ?? 'all day'}', () {
      final parts = time?.split(':').map(int.parse).toList();
      final countdown = countdownFor(
        date: _date(entry['date'] as String),
        time: parts == null ? null : LocalTime(parts[0], parts[1]),
        recurrence: Recurrence.none,
        now: DateTime.parse(entry['now'] as String),
      );
      final expected = entry['label'] as String?;
      if (expected == null) {
        expect(countdown.state, CountdownState.passed);
      } else {
        expect(countdown.state, isNot(CountdownState.passed));
        expect(countdownLabel(countdown), expected);
      }
    });
  }
}

CivilDate _date(String iso) {
  final parts = iso.split('-').map(int.parse).toList();
  return CivilDate(parts[0], parts[1], parts[2]);
}
