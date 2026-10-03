import 'package:agecalculator/utils/date_input_format.dart';
import 'package:agecalculator/utils/date_input_formatter.dart';
import 'package:agecalculator/utils/date_utils.dart';
import 'package:flutter/material.dart';

/// A date you can type (separators are added for you) or pick from a
/// calendar.
///
/// The typed order follows the device locale, for example `DD/MM/YYYY` in
/// India and `MM/DD/YYYY` in the United States. A complete, valid date in
/// range is reported through [onDateSelected] and shown in words below the
/// field.
class DatePickerField extends StatefulWidget {
  const DatePickerField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
    this.onDateCleared,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
  });

  final String label;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  /// Called when the text stops being a valid date, for example while a new
  /// date is typed over the old one. When null the field is required: an
  /// empty field shows an error once it loses focus.
  final VoidCallback? onDateCleared;

  final DateTime firstDate;
  final DateTime lastDate;

  /// Title of the calendar.
  final String helpText;

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField>
    with WidgetsBindingObserver {
  final _focusNode = FocusNode();
  late final TextEditingController _controller;
  late DateInputFormat _format;
  bool _reportedValid = false;
  bool _showIncomplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _format = _deviceFormat();
    _controller = TextEditingController(text: _textFor(widget.selectedDate));
    _reportedValid = widget.selectedDate != null;
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  // The app's Material localizations are en_US only, so the device locale
  // decides the typed date order instead.
  DateInputFormat _deviceFormat() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return DateInputFormat.forLocale(locale.languageCode, locale.countryCode);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final format = _deviceFormat();
    if (format == _format) return;
    final shown = _parseComplete(_controller.text);
    setState(() {
      _format = format;
      if (shown != null) _controller.text = format.format(shown);
    });
  }

  @override
  void didUpdateWidget(DatePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameDay(widget.selectedDate, oldWidget.selectedDate)) return;
    if (_sameDay(_parseComplete(_controller.text), widget.selectedDate)) return;
    _controller.text = _textFor(widget.selectedDate);
    _reportedValid = widget.selectedDate != null;
    _showIncomplete = false;
  }

  String _textFor(DateTime? date) => date == null ? '' : _format.format(date);

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static int _digitCount(String text) =>
      text.replaceAll(RegExp(r'\D'), '').length;

  // Requires every digit, so a year-first `1998-08-1` isn't taken as the 1st
  // before the last digit is typed.
  DateTime? _parseComplete(String text) =>
      _digitCount(text) == 8 ? _format.parse(text) : null;

  bool _inRange(DateTime date) =>
      !AppDateUtils.isBeforeDate(date, widget.firstDate) &&
      !AppDateUtils.isAfterDate(date, widget.lastDate);

  DateTime? _validDate(String text) {
    final date = _parseComplete(text);
    return date != null && _inRange(date) ? date : null;
  }

  String? _errorText() {
    final text = _controller.text;
    if (_digitCount(text) == 8) {
      final date = _format.parse(text);
      if (date == null) return "That date doesn't exist.";
      if (!_inRange(date)) {
        return 'Enter a date between ${_format.format(widget.firstDate)} '
            'and ${_format.format(widget.lastDate)}.';
      }
      return null;
    }
    return _showIncomplete
        ? 'Enter the full date as ${_format.hintText}.'
        : null;
  }

  void _onChanged(String text) {
    setState(() => _showIncomplete = false);
    final date = _validDate(text);
    if (date != null) {
      _reportedValid = true;
      widget.onDateSelected(date);
      _focusNode.unfocus();
    } else if (_reportedValid) {
      _reportedValid = false;
      widget.onDateCleared?.call();
    }
  }

  void _onFocusChanged() {
    if (!mounted || _focusNode.hasFocus) return;
    final text = _controller.text;
    final incomplete = _digitCount(text) < 8;
    final required = widget.onDateCleared == null;
    setState(() {
      _showIncomplete = incomplete && (text.isNotEmpty || required);
    });
  }

  // A tap that focuses a complete date selects it, so typing replaces it.
  void _onTap() {
    if (_focusNode.hasFocus || _digitCount(_controller.text) < 8) return;
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  Future<void> _openCalendar() async {
    _focusNode.unfocus();
    final current = _validDate(_controller.text) ?? widget.selectedDate;
    var initial = current ?? widget.lastDate;
    if (initial.isBefore(widget.firstDate)) initial = widget.firstDate;
    if (initial.isAfter(widget.lastDate)) initial = widget.lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      helpText: widget.helpText,
      cancelText: 'Cancel',
      confirmText: 'Select',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: current == null
          ? DatePickerMode.year
          : DatePickerMode.day,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _controller.text = _format.format(picked);
      _showIncomplete = false;
    });
    _reportedValid = true;
    widget.onDateSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final error = _errorText();
    final date = error == null ? _validDate(_controller.text) : null;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [DateInputFormatter(_format)],
      onChanged: _onChanged,
      onTap: _onTap,
      onTapOutside: (_) => _focusNode.unfocus(),
      decoration: InputDecoration(
        labelText: widget.label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: _format.hintText,
        border: const OutlineInputBorder(),
        helperText: date == null ? null : AppDateUtils.formatDisplayDate(date),
        helperMaxLines: 2,
        errorText: error,
        errorMaxLines: 3,
        suffixIcon: IconButton(
          onPressed: _openCalendar,
          tooltip: 'Choose from calendar',
          icon: const Icon(Icons.calendar_month_rounded),
        ),
      ),
    );
  }
}
