class AgeResult {
  const AgeResult({
    required this.years,
    required this.months,
    required this.days,
    required this.totalDays,
    required this.totalMonths,
    required this.totalWeeks,
    required this.totalHours,
    required this.totalMinutes,
    required this.nextBirthdayDays,
    required this.birthdayWeekday,
    required this.ageInMonths,
    required this.ageInDays,
    required this.dateOfBirth,
    required this.calculatedAt,
  });

  final int years;
  final int months;
  final int days;
  final int totalDays;
  final int totalMonths;
  final int totalWeeks;
  final int totalHours;
  final int totalMinutes;
  final int nextBirthdayDays;
  final String birthdayWeekday;
  final int ageInMonths;
  final int ageInDays;
  final DateTime dateOfBirth;
  final DateTime calculatedAt;
}
