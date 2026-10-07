import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/life_expectancy.dart';
import 'package:agecalculator/utils/date_utils.dart';
import 'package:agecalculator/widgets/date_picker_field.dart';
import 'package:flutter/material.dart';

class LifeExpectancyScreen extends StatefulWidget {
  const LifeExpectancyScreen({super.key, this.initialDateOfBirth});

  final DateTime? initialDateOfBirth;

  @override
  State<LifeExpectancyScreen> createState() => _LifeExpectancyScreenState();
}

class _LifeExpectancyScreenState extends State<LifeExpectancyScreen> {
  static const _calculator = LifeExpectancyCalculator();

  DateTime? _dateOfBirth;
  SmokingStatus _smoking = SmokingStatus.never;
  CigarettesPerDay _cigarettes = CigarettesPerDay.oneToFive;
  AlcoholHabit _alcohol = AlcoholHabit.never;
  ExerciseHabit _exercise = ExerciseHabit.sometimes;
  LifeExpectancyEstimate? _result;

  @override
  void initState() {
    super.initState();
    _dateOfBirth = widget.initialDateOfBirth;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _calculate() {
    final dob = _dateOfBirth;
    if (dob == null) {
      setState(() => _result = null);
      _showMessage('Please select your date of birth first.');
      return;
    }
    if (AppDateUtils.isFutureDate(dob)) {
      setState(() => _result = null);
      _showMessage('Date of birth cannot be in the future.');
      return;
    }

    setState(() {
      _result = _calculator.estimate(
        LifeExpectancyAnswers(
          dateOfBirth: CivilDate.fromDateTime(dob),
          smoking: _smoking,
          cigarettesPerDay: _smoking == SmokingStatus.current
              ? _cigarettes
              : null,
          alcohol: _alcohol,
          exercise: _exercise,
        ),
        asOf: CivilDate.fromDateTime(AppDateUtils.today()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = AppDateUtils.today();

    return Scaffold(
      appBar: AppBar(title: const Text('Life Expectancy Challenge')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 20.0;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    24,
                  ),
                  children: [
                    Text(
                      'A fun estimate based on a few lifestyle answers — not a '
                      'medical prediction.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: DatePickerField(
                          label: 'Date of Birth',
                          selectedDate: _dateOfBirth,
                          onDateSelected: (date) {
                            setState(() {
                              _dateOfBirth = date;
                              _result = null;
                            });
                          },
                          onDateCleared: () {
                            setState(() {
                              _dateOfBirth = null;
                              _result = null;
                            });
                          },
                          firstDate: DateTime(1900),
                          lastDate: today,
                          helpText: 'Select Date of Birth',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ChoiceCard<SmokingStatus>(
                      title: 'Smoking',
                      value: _smoking,
                      options: const [
                        (SmokingStatus.never, 'Never'),
                        (SmokingStatus.former, 'Former smoker'),
                        (SmokingStatus.current, 'Current smoker'),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _smoking = value;
                          _result = null;
                        });
                      },
                    ),
                    if (_smoking == SmokingStatus.current) ...[
                      const SizedBox(height: 12),
                      _ChoiceCard<CigarettesPerDay>(
                        title: 'Cigarettes per day',
                        value: _cigarettes,
                        options: const [
                          (CigarettesPerDay.oneToFive, '1–5'),
                          (CigarettesPerDay.sixToTen, '6–10'),
                          (CigarettesPerDay.elevenToTwenty, '11–20'),
                          (CigarettesPerDay.twentyPlus, '20+'),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _cigarettes = value;
                            _result = null;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    _ChoiceCard<AlcoholHabit>(
                      title: 'Alcohol',
                      value: _alcohol,
                      options: const [
                        (AlcoholHabit.never, 'Never'),
                        (AlcoholHabit.occasionally, 'Occasionally'),
                        (AlcoholHabit.regularly, 'Regularly'),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _alcohol = value;
                          _result = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _ChoiceCard<ExerciseHabit>(
                      title: 'Exercise',
                      value: _exercise,
                      options: const [
                        (ExerciseHabit.regularly, 'Regularly'),
                        (ExerciseHabit.sometimes, 'Sometimes'),
                        (ExerciseHabit.rarely, 'Rarely'),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _exercise = value;
                          _result = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _calculate,
                      icon: const Icon(Icons.calculate_rounded),
                      label: const Text('Calculate'),
                    ),
                    if (_result != null) ...[
                      const SizedBox(height: 28),
                      _ResultCard(result: _result!),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChoiceCard<T> extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            RadioGroup<T>(
              groupValue: value,
              onChanged: (selected) {
                if (selected != null) onChanged(selected);
              },
              child: Column(
                children: [
                  for (final option in options)
                    RadioListTile<T>(
                      title: Text(option.$2),
                      value: option.$1,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final LifeExpectancyEstimate result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your estimated lifespan',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppDateUtils.pluralize(result.estimatedYears, 'year'),
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Estimated date based on this model',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppDateUtils.formatDisplayDate(result.estimatedDate.toDateTime()),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'You have approximately',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${AppDateUtils.pluralize(result.yearsRemaining, 'year')} remaining',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'This is a fun estimate, not a medical prediction. Actual '
              'lifespan depends on many factors. Smoking and other health '
              'risks affect people differently.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (result.isCurrentSmoker) ...[
              const SizedBox(height: 12),
              Text(
                'Smoking can significantly affect life expectancy. Quitting '
                'has health benefits at any age.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Quitting smoking can improve health and increase life '
                'expectancy.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
