import 'package:agecalculator/models/age_result.dart';
import 'package:agecalculator/services/share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shareService = ShareService();

  final sampleResult = AgeResult(
    years: 26,
    months: 3,
    days: 22,
    weeks: 3,
    hours: 12,
    minutes: 30,
    totalDays: 9580,
    totalMonths: 315,
    totalWeeks: 1368,
    totalHours: 229920,
    totalMinutes: 13795200,
    nextBirthdayDays: 305,
    birthdayWeekday: 'Tuesday',
    ageInMonths: 315,
    ageInDays: 9580,
    dateOfBirth: DateTime(2000, 3, 15),
    calculatedAt: DateTime(2026, 7, 7),
  );

  test('buildShareText includes required fields', () {
    final text = shareService.buildShareText(sampleResult);

    expect(text, contains('Date of Birth:'));
    expect(text, contains('Calculate Age As Of:'));
    expect(text, contains('Years: 26'));
    expect(text, contains('Months: 3'));
    expect(text, contains('Days: 22'));
    expect(text, contains('Total Months: 315'));
    expect(text, contains('Total Weeks: 1368'));
    expect(text, contains('Total Days: 9580'));
    expect(text, contains('Total Hours: 229920'));
    expect(text, contains('Total Minutes: 13795200'));
    expect(text, contains('Next Birthday: 305 days'));
  });
}
