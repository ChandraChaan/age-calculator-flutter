import 'package:agecalculator/models/age_result.dart';
import 'package:agecalculator/services/age_service.dart';
import 'package:agecalculator/services/share_service.dart';
import 'package:agecalculator/utils/date_utils.dart';
import 'package:agecalculator/widgets/age_card.dart';
import 'package:agecalculator/widgets/date_selection_card.dart';
import 'package:agecalculator/widgets/info_card.dart';
import 'package:agecalculator/widgets/theme_switch.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AgeService _ageService = const AgeService();
  final ShareService _shareService = const ShareService();

  DateTime? _selectedDob;
  late DateTime _selectedCurrentDate;
  AgeResult? _result;
  int _animationKey = 0;

  @override
  void initState() {
    super.initState();
    _selectedCurrentDate = AppDateUtils.today();
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateDates() {
    if (_selectedDob == null) {
      return 'Please select your date of birth first.';
    }

    if (AppDateUtils.isFutureDate(_selectedDob!)) {
      return 'Date of birth cannot be in the future.';
    }

    if (AppDateUtils.isEndBeforeStart(_selectedDob!, _selectedCurrentDate)) {
      return 'Calculate age as of date cannot be earlier than date of birth.';
    }

    return null;
  }

  void _calculate({bool showValidationFeedback = true}) {
    final validationMessage = _validateDates();
    if (validationMessage != null) {
      setState(() => _result = null);
      if (showValidationFeedback) {
        _showValidationMessage(validationMessage);
      }
      return;
    }

    final result = _ageService.calculate(_selectedDob!, _selectedCurrentDate);
    setState(() {
      _result = result;
      if (result != null) {
        _animationKey++;
      } else if (showValidationFeedback) {
        _showValidationMessage('Unable to calculate age.');
      }
    });
  }

  void _onDateOfBirthSelected(DateTime date) {
    setState(() => _selectedDob = date);
    _calculate(showValidationFeedback: false);
  }

  void _onCurrentDateSelected(DateTime date) {
    setState(() => _selectedCurrentDate = date);
    if (_selectedDob != null) {
      _calculate(showValidationFeedback: false);
    }
  }

  void _reset() {
    setState(() {
      _selectedDob = null;
      _selectedCurrentDate = AppDateUtils.today();
      _result = null;
      _animationKey++;
    });
  }

  Future<void> _shareResult() async {
    if (_result == null) {
      _showValidationMessage('Please calculate your age first.');
      return;
    }

    await _shareService.shareResult(_result!);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Age Calculator'),
        actions: [
          ThemeSwitch(
            themeMode: widget.themeMode,
            onChanged: widget.onThemeChanged,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
            final horizontalPadding =
                isWide ? _wideHorizontalPadding : _compactHorizontalPadding;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Calculate your exact age instantly.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DateSelectionCard(
                    dateOfBirth: _selectedDob,
                    currentDate: _selectedCurrentDate,
                    onDateOfBirthSelected: _onDateOfBirthSelected,
                    onCurrentDateSelected: _onCurrentDateSelected,
                  ),
                  const SizedBox(height: 16),
                  _ActionButtons(
                    onCalculate: _calculate,
                    onReset: _reset,
                    onShare: _shareResult,
                    canShare: _result != null,
                    isWide: isWide,
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 28),
                    _ResultsSection(
                      key: ValueKey(_animationKey),
                      result: _result!,
                      isWide: isWide,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

const double _wideLayoutBreakpoint = 600;
const double _wideHorizontalPadding = 32;
const double _compactHorizontalPadding = 20;

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onCalculate,
    required this.onReset,
    required this.onShare,
    required this.canShare,
    required this.isWide,
  });

  final VoidCallback onCalculate;
  final VoidCallback onReset;
  final VoidCallback onShare;
  final bool canShare;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onCalculate,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('Calculate'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canShare ? onShare : null,
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share Result'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onCalculate,
          icon: const Icon(Icons.calculate_rounded),
          label: const Text('Calculate'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canShare ? onShare : null,
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({
    super.key,
    required this.result,
    required this.isWide,
  });

  final AgeResult result;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final crossAxisCount = isWide ? 3 : 2;
    final calculatedOn = AppDateUtils.dateOnly(result.calculatedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your Age',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Born on ${AppDateUtils.formatDisplayDate(result.dateOfBirth)} · '
          'As of ${AppDateUtils.formatDisplayDate(calculatedOn)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isWide ? 1.4 : 1.1,
          children: [
            AgeCard(
              label: 'Years',
              value: '${result.years}',
              icon: Icons.cake_rounded,
              accentColor: colorScheme.primary,
            ),
            AgeCard(
              label: 'Months',
              value: '${result.months}',
              icon: Icons.calendar_view_month_rounded,
              accentColor: colorScheme.secondary,
            ),
            AgeCard(
              label: 'Days',
              value: '${result.days}',
              icon: Icons.today_rounded,
              accentColor: colorScheme.tertiary,
            ),
            AgeCard(
              label: 'Weeks',
              value: '${result.weeks}',
              icon: Icons.date_range_rounded,
            ),
            AgeCard(
              label: 'Hours',
              value: '${result.hours}',
              icon: Icons.schedule_rounded,
            ),
            AgeCard(
              label: 'Minutes',
              value: '${result.minutes}',
              icon: Icons.timer_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: 'Total Time Lived',
          icon: Icons.hourglass_bottom_rounded,
          items: [
            InfoItem(
              label: 'Total Days',
              value: AppDateUtils.pluralize(result.totalDays, 'day'),
            ),
            InfoItem(
              label: 'Total Months',
              value: AppDateUtils.pluralize(result.totalMonths, 'month'),
            ),
            InfoItem(
              label: 'Total Weeks',
              value: AppDateUtils.pluralize(result.totalWeeks, 'week'),
            ),
            InfoItem(
              label: 'Total Hours',
              value: AppDateUtils.pluralize(result.totalHours, 'hour'),
            ),
            InfoItem(
              label: 'Total Minutes',
              value: AppDateUtils.pluralize(result.totalMinutes, 'minute'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: 'Birthday Details',
          icon: Icons.celebration_rounded,
          items: [
            InfoItem(
              label: 'Next Birthday Countdown',
              value: AppDateUtils.pluralize(result.nextBirthdayDays, 'day'),
            ),
            InfoItem(
              label: 'Birthday Weekday',
              value: result.birthdayWeekday,
            ),
            InfoItem(
              label: 'Age in Months',
              value: AppDateUtils.pluralize(result.ageInMonths, 'month'),
            ),
            InfoItem(
              label: 'Age in Days',
              value: AppDateUtils.pluralize(result.ageInDays, 'day'),
            ),
          ],
        ),
      ],
    );
  }
}
