import 'package:agecalculator/utils/date_input_format.dart';
import 'package:flutter/services.dart';

/// Formats typed digits as a date in [format]'s field order, inserting the
/// separator as soon as the next field starts: `15081998` becomes
/// `15/08/1998` in a day-first locale.
///
/// The digits are the content; separators are display only. Deleting a
/// separator deletes the digit next to it, typing a separator after a
/// single-digit day or month pads it (`1/` → `01/`), and pasted dates with
/// any of `/ . -` or spaces are normalised.
class DateInputFormatter extends TextInputFormatter {
  DateInputFormatter(this.format)
    : _fieldLengths = [
        for (final field in format.fields) field == DateInputField.year ? 4 : 2,
      ];

  final DateInputFormat format;
  final List<int> _fieldLengths;

  int get _maxDigits => _fieldLengths.fold(0, (sum, length) => sum + length);

  static bool _isDigit(String char) =>
      char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39;

  static bool _isSeparator(String char) =>
      char == '/' || char == '.' || char == '-' || char == ' ';

  static String _digitsOf(String text) => text.split('').where(_isDigit).join();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    var cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset
        : text.length;

    final removedSeparator = _removedSeparatorIndex(oldValue, newValue);
    if (removedSeparator != null) {
      final backspace =
          oldValue.selection.isCollapsed &&
          oldValue.selection.baseOffset == removedSeparator + 1;
      final digitIndex = backspace ? removedSeparator - 1 : removedSeparator;
      if (digitIndex >= 0 && digitIndex < text.length) {
        text = text.substring(0, digitIndex) + text.substring(digitIndex + 1);
        cursor = digitIndex;
      }
    }

    final selectedLength = oldValue.selection.isValid
        ? oldValue.selection.end - oldValue.selection.start
        : 0;
    final inserted = text.length - (oldValue.text.length - selectedLength);
    final atEnd = cursor >= text.length;

    String digits;
    var trailingSeparator = false;
    if (inserted == 1 &&
        atEnd &&
        text.isNotEmpty &&
        _isSeparator(text[text.length - 1])) {
      (digits, trailingSeparator) = _withTypedSeparator(oldValue.text);
    } else if (inserted > 1) {
      digits = _pastedDigits(text);
    } else {
      digits = _digitsOf(text);
      if (digits.length > _maxDigits) return oldValue;
    }
    if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);

    final formatted = _layOut(digits, trailingSeparator: trailingSeparator);
    final offset = atEnd || inserted > 1
        ? formatted.length
        : _offsetAfterDigits(formatted, _digitsOf(text.substring(0, cursor)));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  /// The index of a separator deleted from the middle of the text on its
  /// own (by backspace or delete), or `null` for any other edit.
  int? _removedSeparatorIndex(TextEditingValue old, TextEditingValue next) {
    if (next.text.length != old.text.length - 1) return null;
    if (!old.selection.isValid || !old.selection.isCollapsed) return null;
    if (!next.selection.isValid || !next.selection.isCollapsed) return null;
    final index = next.selection.baseOffset;
    if (index < 0 || index >= next.text.length) return null;
    final removed = old.text[index];
    if (_isDigit(removed)) return null;
    final unchanged =
        old.text.substring(0, index) == next.text.substring(0, index) &&
        old.text.substring(index + 1) == next.text.substring(index);
    return unchanged ? index : null;
  }

  /// A separator typed at the end of [previous]: closes the current field,
  /// padding a single-digit day or month with a leading zero.
  (String, bool) _withTypedSeparator(String previous) {
    var digits = _digitsOf(previous);
    final ended =
        previous.isNotEmpty && !_isDigit(previous[previous.length - 1]);
    if (ended || digits.isEmpty || digits.length >= _maxDigits) {
      return (digits, ended);
    }
    var start = 0;
    for (final length in _fieldLengths) {
      final typed = digits.length - start;
      if (typed == 0) return (digits, true);
      if (typed < length) {
        if (length == 2 && typed == 1) {
          digits = '${digits.substring(0, start)}0${digits.substring(start)}';
          return (digits, start + length < _maxDigits);
        }
        return (digits, false);
      }
      start += length;
    }
    return (digits, false);
  }

  /// Digits from pasted or autofilled text. Separated parts such as
  /// `1/8/1998` are padded field by field; anything else is read as plain
  /// digits. Years are never padded.
  String _pastedDigits(String text) {
    final parts = text
        .split(RegExp(r'\D+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2 || parts.length > _fieldLengths.length) {
      return _digitsOf(text);
    }
    final complete = parts.length == _fieldLengths.length;
    final buffer = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      final length = _fieldLengths[i];
      final part = parts[i];
      final isLast = i == parts.length - 1;
      if (part.length > length) return _digitsOf(text);
      if (part.length == length || (isLast && !complete)) {
        buffer.write(part);
      } else if (length == 2) {
        buffer.write(part.padLeft(2, '0'));
      } else if (isLast) {
        buffer.write(part);
      } else {
        return _digitsOf(text);
      }
    }
    return buffer.toString();
  }

  String _layOut(String digits, {required bool trailingSeparator}) {
    final parts = <String>[];
    var start = 0;
    for (final length in _fieldLengths) {
      if (start >= digits.length) break;
      final end = start + length < digits.length
          ? start + length
          : digits.length;
      parts.add(digits.substring(start, end));
      start = end;
    }
    final text = parts.join(format.separator);
    return trailingSeparator ? '$text${format.separator}' : text;
  }

  static int _offsetAfterDigits(String formatted, String digitsBefore) {
    if (digitsBefore.isEmpty) return 0;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (_isDigit(formatted[i])) seen++;
      if (seen == digitsBefore.length) return i + 1;
    }
    return formatted.length;
  }
}
