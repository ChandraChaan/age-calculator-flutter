import 'package:agecalculator/utils/date_utils.dart';
import 'package:agecalculator/widgets/date_picker_field.dart';
import 'package:flutter/material.dart';

class DateSelectionCard extends StatelessWidget {
  const DateSelectionCard({
    super.key,
    required this.dateOfBirth,
    required this.currentDate,
    required this.onDateOfBirthSelected,
    required this.onDateOfBirthCleared,
    required this.onCurrentDateSelected,
  });

  final DateTime? dateOfBirth;
  final DateTime currentDate;
  final ValueChanged<DateTime> onDateOfBirthSelected;
  final VoidCallback onDateOfBirthCleared;
  final ValueChanged<DateTime> onCurrentDateSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DatePickerField(
              label: 'Date of Birth',
              selectedDate: dateOfBirth,
              onDateSelected: onDateOfBirthSelected,
              onDateCleared: onDateOfBirthCleared,
              firstDate: DateTime(1900),
              lastDate: currentDate,
              helpText: 'Select Date of Birth',
            ),
            const SizedBox(height: 20),
            DatePickerField(
              label: 'Calculate Age As Of',
              selectedDate: currentDate,
              onDateSelected: onCurrentDateSelected,
              firstDate: dateOfBirth ?? DateTime(1900),
              lastDate: AppDateUtils.today(),
              helpText: 'Calculate Age As Of',
            ),
          ],
        ),
      ),
    );
  }
}
