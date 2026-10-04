// DartRosa tests of CollectCsvReader against opencsv's CSVParser behaviour
// (separator ',', quote '"', escape '\0', the settings Collect uses).
import 'package:dartrosa_external_data/dartrosa_external_data.dart';
import 'package:test/test.dart';

List<List<String>> readAll(String text) {
  final reader = CollectCsvReader(text);
  return [for (var r = reader.readNext(); r != null; r = reader.readNext()) r];
}

void main() {
  test('splits records and fields', () {
    expect(readAll('a,b\r\nc,d\re,f\n'), [
      ['a', 'b'],
      ['c', 'd'],
      ['e', 'f'],
    ]);
  });

  test('empty lines are records with one empty field', () {
    expect(readAll('a\n\nb'), [
      ['a'],
      [''],
      ['b'],
    ]);
  });

  test('quoted fields keep separators, doubled quotes and newlines', () {
    expect(readAll('"a,b","say ""hi""","line1\nline2",x'), [
      ['a,b', 'say "hi"', 'line1\nline2', 'x'],
    ]);
  });

  test('spaces are kept in unquoted fields', () {
    expect(readAll(' a , b '), [
      [' a ', ' b '],
    ]);
  });

  test('white space before a quote is dropped', () {
    expect(readAll('a,  "b c"'), [
      ['a', 'b c'],
    ]);
  });

  test('a quote in the middle of a field is kept', () {
    expect(readAll('a,bc"d"ef,g'), [
      ['a', 'bc"d"ef', 'g'],
    ]);
  });

  test('backslashes are not escapes', () {
    expect(readAll(r'a\,b'), [
      [r'a\', 'b'],
    ]);
  });

  test('an unterminated quote fails', () {
    expect(
      () => readAll('a,"b\nc'),
      throwsA(
        isA<ExternalDataException>().having(
          (e) => e.message,
          'message',
          startsWith('Unterminated quoted field at end of CSV line.'),
        ),
      ),
    );
  });
}
