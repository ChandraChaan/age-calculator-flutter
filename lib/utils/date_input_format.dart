import 'package:agecalculator/engine/calendar_math.dart';
import 'package:intl/date_time_patterns.dart';
import 'package:intl/intl.dart';

enum DateInputField { day, month, year }

/// The order and separator for typing a numeric date, such as `DD/MM/YYYY`.
///
/// Derived from the locale's CLDR short date pattern bundled with `intl`,
/// so `en_IN` gets day-first input and `en_US` month-first input.
class DateInputFormat {
  const DateInputFormat._(this.fields, this.separator);

  /// ISO 8601 order, used when the locale has no known date pattern.
  static const iso = DateInputFormat._([
    DateInputField.year,
    DateInputField.month,
    DateInputField.day,
  ], '-');

  factory DateInputFormat.forLocale(
    String languageCode, [
    String? countryCode,
  ]) {
    final localeName = countryCode == null || countryCode.isEmpty
        ? languageCode
        : '${languageCode}_$countryCode';
    final verified = Intl.verifiedLocale(
      localeName,
      _patterns.containsKey,
      onFailure: (_) => null,
    );
    final pattern = verified == null ? null : _patterns[verified]?['yMd'];
    return pattern == null ? iso : DateInputFormat.fromPattern(pattern);
  }

  /// Reads the field order from an ICU pattern such as `d/M/y`, `M/d/y`,
  /// `d.M.y` or `y. M. d.`.
  factory DateInputFormat.fromPattern(String pattern) {
    final fields = <DateInputField>[];
    String? separator;
    var literal = StringBuffer();
    var quoted = false;

    for (final char in pattern.split('')) {
      if (char == "'") {
        quoted = !quoted;
        continue;
      }
      final field = quoted ? null : _fieldForPatternLetter(char);
      if (field == null) {
        if (fields.isNotEmpty) literal.write(char);
        continue;
      }
      if (fields.isNotEmpty && fields.last == field) continue;
      if (fields.contains(field)) return iso;
      if (fields.isNotEmpty) {
        separator ??= _separatorIn(literal.toString());
      }
      fields.add(field);
      literal = StringBuffer();
    }

    if (fields.length != 3) return iso;
    return DateInputFormat._(List.unmodifiable(fields), separator ?? '/');
  }

  static final Map<String, Map<String, String>> _patterns =
      dateTimePatternMap();

  static final RegExp _separators = RegExp(r'[\s./\-]+');
  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  final List<DateInputField> fields;
  final String separator;

  /// For example `DD/MM/YYYY`.
  String get hintText {
    return fields
        .map(
          (field) => switch (field) {
            DateInputField.day => 'DD',
            DateInputField.month => 'MM',
            DateInputField.year => 'YYYY',
          },
        )
        .join(separator);
  }

  String format(DateTime date) {
    return fields
        .map(
          (field) => switch (field) {
            DateInputField.day => date.day.toString().padLeft(2, '0'),
            DateInputField.month => date.month.toString().padLeft(2, '0'),
            DateInputField.year => date.year.toString().padLeft(4, '0'),
          },
        )
        .join(separator);
  }

  /// Parses [input] in this format's field order.
  ///
  /// Returns `null` unless the input has exactly three numeric parts, a
  /// four-digit year, and forms a real calendar date. Any of `/ . -` or
  /// spaces are accepted as separators.
  DateTime? parse(String input) {
    final parts = input
        .trim()
        .split(_separators)
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length != 3 || !parts.every(_digitsOnly.hasMatch)) {
      return null;
    }

    var day = 0;
    var month = 0;
    var year = 0;
    for (var i = 0; i < fields.length; i++) {
      final part = parts[i];
      switch (fields[i]) {
        case DateInputField.day:
          if (part.length > 2) return null;
          day = int.parse(part);
        case DateInputField.month:
          if (part.length > 2) return null;
          month = int.parse(part);
        case DateInputField.year:
          if (part.length != 4) return null;
          year = int.parse(part);
      }
    }

    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > CalendarMath.daysInMonth(year, month)) {
      return null;
    }
    return DateTime(year, month, day);
  }

  @override
  bool operator ==(Object other) {
    return other is DateInputFormat &&
        other.separator == separator &&
        other.fields.length == fields.length &&
        other.fields.indexed.every((entry) => fields[entry.$1] == entry.$2);
  }

  @override
  int get hashCode => Object.hash(separator, Object.hashAll(fields));

  @override
  String toString() => 'DateInputFormat($hintText)';

  static DateInputField? _fieldForPatternLetter(String letter) {
    return switch (letter) {
      'd' => DateInputField.day,
      'M' || 'L' => DateInputField.month,
      'y' => DateInputField.year,
      _ => null,
    };
  }

  static String _separatorIn(String literal) {
    for (final char in literal.split('')) {
      if (char == '/' || char == '.' || char == '-') return char;
    }
    return '/';
  }
}
