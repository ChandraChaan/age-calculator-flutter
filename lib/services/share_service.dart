import 'package:agecalculator/models/age_result.dart';
import 'package:agecalculator/utils/date_utils.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  const ShareService();

  String buildShareText(AgeResult result) {
    final calculatedOn = AppDateUtils.dateOnly(result.calculatedAt);

    return '''
Age Calculator Result

Date of Birth: ${AppDateUtils.formatDisplayDate(result.dateOfBirth)}
Calculate Age As Of: ${AppDateUtils.formatDisplayDate(calculatedOn)}

Age
Years: ${result.years}
Months: ${result.months}
Days: ${result.days}

Totals
Total Months: ${result.totalMonths}
Total Weeks: ${result.totalWeeks}
Total Days: ${result.totalDays}
Total Hours: ${result.totalHours}
Total Minutes: ${result.totalMinutes}

Next Birthday: ${AppDateUtils.pluralize(result.nextBirthdayDays, 'day')}
'''
        .trim();
  }

  Future<void> shareResult(AgeResult result) async {
    await SharePlus.instance.share(
      ShareParams(
        text: buildShareText(result),
        subject: 'My Age Calculator Result',
      ),
    );
  }
}
