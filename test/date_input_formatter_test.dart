import 'package:agecalculator/utils/date_input_format.dart';
import 'package:agecalculator/utils/date_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _dayFirst = DateInputFormatter(DateInputFormat.forLocale('en', 'IN'));
final _monthFirst = DateInputFormatter(DateInputFormat.forLocale('en', 'US'));
final _iso = DateInputFormatter(DateInputFormat.iso);
final _dotted = DateInputFormatter(DateInputFormat.forLocale('de', 'DE'));
final _yearFirstDotted = DateInputFormatter(
  DateInputFormat.forLocale('ko', 'KR'),
);

const _empty = TextEditingValue(selection: TextSelection.collapsed(offset: 0));

TextEditingValue _at(String text, [int? cursor]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: cursor ?? text.length),
);

TextEditingValue _selected(String text, int start, int end) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end),
);

/// Types [chars] one key at a time, as a keyboard would.
TextEditingValue _type(
  DateInputFormatter formatter,
  TextEditingValue value,
  String chars,
) {
  for (final char in chars.split('')) {
    final selection = value.selection;
    final text = value.text.replaceRange(selection.start, selection.end, char);
    value = formatter.formatEditUpdate(
      value,
      _at(text, selection.start + char.length),
    );
  }
  return value;
}

/// The text after each key of [chars], starting from an empty field.
List<String> _steps(DateInputFormatter formatter, String chars) {
  var value = _empty;
  return [
    for (final char in chars.split(''))
      (value = _type(formatter, value, char)).text,
  ];
}

TextEditingValue _backspace(
  DateInputFormatter formatter,
  TextEditingValue value,
) {
  final selection = value.selection;
  if (!selection.isCollapsed) {
    return formatter.formatEditUpdate(
      value,
      _at(
        value.text.replaceRange(selection.start, selection.end, ''),
        selection.start,
      ),
    );
  }
  if (selection.start == 0) return value;
  return formatter.formatEditUpdate(
    value,
    _at(
      value.text.replaceRange(selection.start - 1, selection.start, ''),
      selection.start - 1,
    ),
  );
}

TextEditingValue _deleteForward(
  DateInputFormatter formatter,
  TextEditingValue value,
) {
  final cursor = value.selection.start;
  return formatter.formatEditUpdate(
    value,
    _at(value.text.replaceRange(cursor, cursor + 1, ''), cursor),
  );
}

TextEditingValue _paste(
  DateInputFormatter formatter,
  TextEditingValue value,
  String pasted,
) {
  final selection = value.selection;
  return formatter.formatEditUpdate(
    value,
    _at(
      value.text.replaceRange(selection.start, selection.end, pasted),
      selection.start + pasted.length,
    ),
  );
}

void main() {
  group('typing digits only', () {
    test('DD/MM/YYYY: 15081998 → 15/08/1998', () {
      expect(_steps(_dayFirst, '15081998'), [
        '1',
        '15',
        '15/0',
        '15/08',
        '15/08/1',
        '15/08/19',
        '15/08/199',
        '15/08/1998',
      ]);
    });

    test('MM/DD/YYYY: 08151998 → 08/15/1998', () {
      expect(_steps(_monthFirst, '08151998').last, '08/15/1998');
      expect(_steps(_monthFirst, '0815').last, '08/15');
    });

    test('YYYY-MM-DD: 19980815 → 1998-08-15', () {
      expect(_steps(_iso, '19980815'), [
        '1',
        '19',
        '199',
        '1998',
        '1998-0',
        '1998-08',
        '1998-08-1',
        '1998-08-15',
      ]);
    });

    test('the locale separator is used', () {
      expect(_steps(_dotted, '15081998').last, '15.08.1998');
      expect(_steps(_yearFirstDotted, '19980815').last, '1998.08.15');
    });

    test('the cursor follows the last typed digit', () {
      final value = _type(_dayFirst, _empty, '150');
      expect(value.selection, const TextSelection.collapsed(offset: 4));
    });

    test('a ninth digit is ignored', () {
      final full = _type(_dayFirst, _empty, '15081998');
      final value = _type(_dayFirst, full, '7');
      expect(value.text, '15/08/1998');
      expect(value.selection, const TextSelection.collapsed(offset: 10));
    });

    test('letters and symbols are ignored', () {
      expect(_type(_dayFirst, _empty, '1a5b0*8').text, '15/08');
    });

    test('every complete result parses back to the typed date', () {
      for (final formatter in [
        _dayFirst,
        _monthFirst,
        _iso,
        _dotted,
        _yearFirstDotted,
      ]) {
        for (
          var date = DateTime(1900, 1, 1);
          date.year < 2101;
          date = DateTime(date.year, date.month, date.day + 41)
        ) {
          final shown = formatter.format.format(date);
          final digits = shown.replaceAll(RegExp(r'\D'), '');
          final typed = _type(formatter, _empty, digits).text;
          expect(typed, shown);
          expect(formatter.format.parse(typed), date);
        }
      }
    });
  });

  group('typing a separator', () {
    test('after one digit pads it with a zero', () {
      expect(_type(_dayFirst, _empty, '1/').text, '01/');
      expect(_type(_dayFirst, _empty, '1/8/').text, '01/08/');
      expect(_type(_dayFirst, _empty, '1/8/1998').text, '01/08/1998');
      expect(_type(_monthFirst, _empty, '8/1/1998').text, '08/01/1998');
    });

    test('after a complete field shows the separator', () {
      expect(_type(_dayFirst, _empty, '15/').text, '15/');
      expect(_type(_dayFirst, _empty, '15/0').text, '15/0');
      expect(_type(_iso, _empty, '1998-').text, '1998-');
    });

    test('any of / . - and space work, and repeats are ignored', () {
      expect(_type(_dayFirst, _empty, '15.').text, '15/');
      expect(_type(_dayFirst, _empty, '15-').text, '15/');
      expect(_type(_dayFirst, _empty, '15 ').text, '15/');
      expect(_type(_dayFirst, _empty, '15//').text, '15/');
      expect(_type(_dayFirst, _empty, '/').text, '');
    });

    test('inside a year, or after a full date, it is ignored', () {
      expect(_type(_dayFirst, _empty, '150819/').text, '15/08/19');
      expect(_type(_iso, _empty, '199-').text, '199');
      expect(_type(_dayFirst, _empty, '15081998/').text, '15/08/1998');
    });
  });

  group('deleting', () {
    test('backspace at the end removes one digit and its separator', () {
      var value = _type(_dayFirst, _empty, '15081998');
      final texts = <String>[];
      while (value.text.isNotEmpty) {
        value = _backspace(_dayFirst, value);
        texts.add(value.text);
      }
      expect(texts, [
        '15/08/199',
        '15/08/19',
        '15/08/1',
        '15/08',
        '15/0',
        '15',
        '1',
        '',
      ]);
    });

    test('backspace after a typed separator removes just the separator', () {
      final value = _backspace(_dayFirst, _type(_dayFirst, _empty, '15/'));
      expect(value.text, '15');
      expect(value.selection, const TextSelection.collapsed(offset: 2));
    });

    test('backspace over a separator deletes the digit before it', () {
      final full = _type(_dayFirst, _empty, '15081998');
      final value = _backspace(
        _dayFirst,
        full.copyWith(selection: const TextSelection.collapsed(offset: 6)),
      );
      expect(value.text, '15/01/998');
      expect(value.selection, const TextSelection.collapsed(offset: 4));
    });

    test('delete before a separator deletes the digit after it', () {
      final value = _deleteForward(_dayFirst, _at('15/08', 2));
      expect(value.text, '15/8');
      expect(value.selection, const TextSelection.collapsed(offset: 2));
    });

    test('deleting and retyping a middle digit restores the date', () {
      var value = _backspace(_dayFirst, _at('15/08/1998', 4));
      expect(value.text, '15/81/998');
      expect(value.selection, const TextSelection.collapsed(offset: 2));
      value = _type(_dayFirst, value, '0');
      expect(value.text, '15/08/1998');
    });

    test('a selected separator alone is not removed', () {
      final value = _backspace(_dayFirst, _selected('15/08/1998', 2, 3));
      expect(value.text, '15/08/1998');
    });

    test('select all and delete clears the field', () {
      final value = _backspace(_dayFirst, _selected('15/08/1998', 0, 10));
      expect(value.text, '');
      expect(value.selection, const TextSelection.collapsed(offset: 0));
    });
  });

  group('replacing and inserting', () {
    test('typing over a selected date starts a new one', () {
      final value = _type(_dayFirst, _selected('15/08/1998', 0, 10), '2');
      expect(value.text, '2');
      expect(_type(_dayFirst, value, '0122000').text, '20/12/2000');
    });

    test('typing over a selected month keeps the cursor in place', () {
      var value = _type(_dayFirst, _selected('15/08/1998', 3, 5), '1');
      expect(value.text, '15/11/998');
      expect(value.selection, const TextSelection.collapsed(offset: 4));
      value = _type(_dayFirst, value, '2');
      expect(value.text, '15/12/1998');
    });

    test('inserting in the middle keeps the cursor after the digit', () {
      final value = _type(_dayFirst, _at('15/08', 2), '3');
      expect(value.text, '15/30/8');
      expect(value.selection, const TextSelection.collapsed(offset: 4));
    });
  });

  group('pasting', () {
    for (final (pasted, expected) in [
      ('15/08/1998', '15/08/1998'),
      ('15-08-1998', '15/08/1998'),
      ('15.08.1998', '15/08/1998'),
      ('15 08 1998', '15/08/1998'),
      (' 15/08/1998 ', '15/08/1998'),
      ('15081998', '15/08/1998'),
      ('1/8/1998', '01/08/1998'),
      ('150819981234', '15/08/1998'),
      ('15/08', '15/08'),
    ]) {
      test('"$pasted" → "$expected"', () {
        final value = _paste(_dayFirst, _empty, pasted);
        expect(value.text, expected);
        expect(value.selection.baseOffset, expected.length);
      });
    }

    test('pasting over a selected date replaces it', () {
      final value = _paste(
        _dayFirst,
        _selected('15/08/1998', 0, 10),
        '03/04/2000',
      );
      expect(value.text, '03/04/2000');
    });

    test('month-first and ISO formats normalise pastes too', () {
      expect(_paste(_monthFirst, _empty, '8-15-1998').text, '08/15/1998');
      expect(_paste(_iso, _empty, '1998/8/5').text, '1998-08-05');
      expect(_paste(_dotted, _empty, '15/08/1998').text, '15.08.1998');
    });

    test('a pasted date in another order is not silently reordered', () {
      final value = _paste(_dayFirst, _empty, '1998-08-15');
      expect(value.text, '19/98/0815');
      expect(_dayFirst.format.parse(value.text), isNull);
    });
  });
}
