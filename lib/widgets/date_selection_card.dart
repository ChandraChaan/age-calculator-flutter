import 'package:agecalculator/utils/date_utils.dart';
import 'package:agecalculator/widgets/date_picker_field.dart';
import 'package:flutter/material.dart';

class DateSelectionCard extends StatelessWidget {
  const DateSelectionCard({
    super.key,
    required this.dateOfBirth,
    required this.currentDate,
    required this.onDateOfBirthSelected,
    required this.onCurrentDateSelected,
  });

  final DateTime? dateOfBirth;
  final DateTime currentDate;
  final ValueChanged<DateTime> onDateOfBirthSelected;
  final ValueChanged<DateTime> onCurrentDateSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DatePickerField(
              label: 'Date of Birth',
              placeholder: 'Select Date of Birth',
              selectedDate: dateOfBirth,
              onDateSelected: onDateOfBirthSelected,
              firstDate: DateTime(1900),
              lastDate: currentDate,
              helpText: 'Select Date of Birth',
              icon: Icons.cake_rounded,
            ),
            const SizedBox(height: 20),
            DatePickerField(
              label: 'Calculate Age As Of',
              placeholder: 'Select Current Date',
              selectedDate: currentDate,
              onDateSelected: onCurrentDateSelected,
              firstDate: dateOfBirth ?? DateTime(1900),
              lastDate: AppDateUtils.today(),
              helpText: 'Calculate Age As Of',
              icon: Icons.event_rounded,
            ),
            if (dateOfBirth != null) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _SelectedDatesSummary(
                dateOfBirth: dateOfBirth!,
                currentDate: currentDate,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedDatesSummary extends StatelessWidget {
  const _SelectedDatesSummary({
    required this.dateOfBirth,
    required this.currentDate,
  });

  final DateTime dateOfBirth;
  final DateTime currentDate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(
          label: 'From',
          value: AppDateUtils.formatDisplayDate(dateOfBirth),
          icon: Icons.cake_rounded,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 12),
        _SummaryRow(
          label: 'To',
          value: AppDateUtils.formatDisplayDate(currentDate),
          icon: Icons.event_rounded,
          color: colorScheme.secondary,
        ),
        const SizedBox(height: 4),
        Text(
          'Age will be calculated between these dates.',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
