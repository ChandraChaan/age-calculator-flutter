import 'package:agecalculator/utils/date_input_format.dart';
import 'package:agecalculator/utils/date_utils.dart';
import 'package:flutter/material.dart';

class DatePickerField extends StatelessWidget {
  const DatePickerField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.selectedDate,
    required this.onDateSelected,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
    this.icon = Icons.calendar_month_rounded,
  });

  final String label;
  final String placeholder;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime firstDate;
  final DateTime lastDate;
  final String helpText;
  final IconData icon;

  Future<void> _pickDate(BuildContext context) async {
    final initialDate = selectedDate ?? lastDate;
    final clampedInitial = _clampDate(initialDate, firstDate, lastDate);
    // The app's Material localizations are en_US only, so the device locale
    // decides the typed date order instead.
    final deviceLocale = View.of(context).platformDispatcher.locale;
    final inputFormat = DateInputFormat.forLocale(
      deviceLocale.languageCode,
      deviceLocale.countryCode,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: clampedInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      cancelText: 'Cancel',
      confirmText: 'Select',
      fieldLabelText: 'Enter date (${inputFormat.hintText})',
      fieldHintText: inputFormat.hintText,
      errorFormatText: 'Invalid format. Use ${inputFormat.hintText}.',
      calendarDelegate: _LocaleDateInputDelegate(inputFormat),
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  DateTime _clampDate(DateTime date, DateTime min, DateTime max) {
    if (date.isBefore(min)) return min;
    if (date.isAfter(max)) return max;
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: label,
          child: OutlinedButton.icon(
            onPressed: () => _pickDate(context),
            icon: Icon(icon),
            label: Text(
              selectedDate == null
                  ? placeholder
                  : AppDateUtils.formatDisplayDate(selectedDate!),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gregorian calendar whose typed-date field uses [inputFormat].
class _LocaleDateInputDelegate extends GregorianCalendarDelegate {
  const _LocaleDateInputDelegate(this.inputFormat);

  final DateInputFormat inputFormat;

  @override
  String formatCompactDate(DateTime date, MaterialLocalizations localizations) {
    return inputFormat.format(date);
  }

  @override
  DateTime? parseCompactDate(
    String? inputString,
    MaterialLocalizations localizations,
  ) {
    return inputString == null ? null : inputFormat.parse(inputString);
  }

  @override
  String dateHelpText(MaterialLocalizations localizations) {
    return inputFormat.hintText;
  }
}
