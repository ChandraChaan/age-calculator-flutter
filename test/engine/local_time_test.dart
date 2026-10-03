import 'package:agecalculator/engine/local_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalTime', () {
    test('accepts the full 24-hour range', () {
      expect(LocalTime(0, 0).minuteOfDay, 0);
      expect(LocalTime(23, 59).minuteOfDay, 1439);
      expect(LocalTime(17, 0).hour, 17);
      expect(LocalTime(17, 0).minute, 0);
    });

    test('rejects out-of-range values', () {
      expect(() => LocalTime(24, 0), throwsArgumentError);
      expect(() => LocalTime(12, 60), throwsArgumentError);
      expect(() => LocalTime(-1, 0), throwsArgumentError);
      expect(() => LocalTime(0, -1), throwsArgumentError);
    });

    test('formats as zero-padded 24-hour HH:mm', () {
      expect(LocalTime(0, 0).toString(), '00:00');
      expect(LocalTime(7, 5).toString(), '07:05');
      expect(LocalTime(17, 0).toString(), '17:00');
      expect(LocalTime(23, 59).toString(), '23:59');
    });

    test('equality, hashing and ordering', () {
      expect(LocalTime(9, 30), LocalTime(9, 30));
      expect(LocalTime(9, 30).hashCode, LocalTime(9, 30).hashCode);
      expect(LocalTime(9, 30), isNot(LocalTime(9, 31)));
      expect(LocalTime(9, 30).compareTo(LocalTime(10, 0)), lessThan(0));
      expect(LocalTime(23, 0).compareTo(LocalTime(0, 59)), greaterThan(0));
      expect(LocalTime(12, 0).compareTo(LocalTime(12, 0)), 0);
    });
  });
}
