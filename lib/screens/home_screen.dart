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
    this.onSaveBirthday,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  /// Shows "Save as birthday" with each result when not null.
  final ValueChanged<AgeResult>? onSaveBirthday;

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

  void _onDateOfBirthCleared() {
    setState(() {
      _selectedDob = null;
      _result = null;
    });
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
            final horizontalPadding = isWide
                ? _wideHorizontalPadding
                : _compactHorizontalPadding;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    onDateOfBirthCleared: _onDateOfBirthCleared,
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
                      onSaveBirthday: widget.onSaveBirthday,
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

// Width needed per unit of text scale before items are placed side by side.
const double _minAgeCardRowWidth = 300;
const double _minButtonRowWidth = 240;

double _bodyTextScale(BuildContext context) {
  const bodyFontSize = 14.0;
  return MediaQuery.textScalerOf(context).scale(bodyFontSize) / bodyFontSize;
}

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

    final resetButton = OutlinedButton.icon(
      onPressed: onReset,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Reset'),
    );
    final shareButton = OutlinedButton.icon(
      onPressed: canShare ? onShare : null,
      icon: const Icon(Icons.share_rounded),
      label: const Text('Share'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackSecondary =
            constraints.maxWidth < _minButtonRowWidth * _bodyTextScale(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: onCalculate,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('Calculate'),
            ),
            const SizedBox(height: 12),
            if (stackSecondary) ...[
              resetButton,
              const SizedBox(height: 12),
              shareButton,
            ] else
              Row(
                children: [
                  Expanded(child: resetButton),
                  const SizedBox(width: 12),
                  Expanded(child: shareButton),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _ResultsSection extends StatelessWidget {
  const _ResultsSection({super.key, required this.result, this.onSaveBirthday});

  final AgeResult result;
  final ValueChanged<AgeResult>? onSaveBirthday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final calculatedOn = AppDateUtils.dateOnly(result.calculatedAt);
    final saveBirthday = onSaveBirthday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your Age',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Born on ${AppDateUtils.formatDisplayDate(result.dateOfBirth)} · '
          'As of ${AppDateUtils.formatDisplayDate(calculatedOn)}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        if (saveBirthday != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => saveBirthday(result),
              icon: const Icon(Icons.cake_outlined),
              label: const Text('Save as birthday'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _PrimaryAgeCards(result: result),
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
            InfoItem(label: 'Birthday Weekday', value: result.birthdayWeekday),
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

class _PrimaryAgeCards extends StatelessWidget {
  const _PrimaryAgeCards({required this.result});

  final AgeResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitsInRow =
            constraints.maxWidth >=
            _minAgeCardRowWidth * _bodyTextScale(context);

        final cards = [
          AgeCard(
            label: 'Years',
            value: '${result.years}',
            icon: Icons.cake_rounded,
            accentColor: colorScheme.primary,
            horizontal: !fitsInRow,
          ),
          AgeCard(
            label: 'Months',
            value: '${result.months}',
            icon: Icons.calendar_view_month_rounded,
            accentColor: colorScheme.secondary,
            horizontal: !fitsInRow,
          ),
          AgeCard(
            label: 'Days',
            value: '${result.days}',
            icon: Icons.today_rounded,
            accentColor: colorScheme.tertiary,
            horizontal: !fitsInRow,
          ),
        ];

        if (!fitsInRow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}
