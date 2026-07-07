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

    final picked = await showDatePicker(
      context: context,
      initialDate: clampedInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      cancelText: 'Cancel',
      confirmText: 'Select',
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
