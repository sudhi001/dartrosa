import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/data_type.dart';
import 'package:test/test.dart';

void main() {
  group('text forms match JavaRosa', () {
    test('numbers', () {
      expect(const DecimalValue(10).uncast().string, '10.0');
      expect(const DecimalValue(1e10).displayText, '1.0E10');
      expect(const IntegerValue(-3).uncast().string, '-3');
      expect(const BooleanValue(true).uncast().string, '1');
      expect(const BooleanValue(false).displayText, 'False');
    });

    test('selections', () {
      final multi = MultipleItemsValue.cast(const UncastValue('a  b c'));
      expect(multi.uncast().string, 'a b c');
      expect(multi.displayText, 'a, b, c');
      expect(SelectOneValue.cast(const UncastValue('x')).uncast().string, 'x');
      expect(
        () => const SelectOneValue(Selection('')).displayText,
        throwsStateError,
      );
    });

    test('geo values', () {
      final point = GeoPointValue.cast(const UncastValue('12.5 -3 100 5'));
      expect(point.uncast().string, '12.5 -3.0 100.0 5.0');
      expect(point.toNumeric(), 5.0);
      // cast always yields four parts, as in JavaRosa.
      expect(
        GeoPointValue.cast(const UncastValue('1 2')).uncast().string,
        '1.0 2.0 0.0 0.0',
      );
      expect(GeoPointValue.empty().displayText, '');
      expect(GeoPointValue.empty().toNumeric(), 9999999.0);
      final trace = GeoTraceValue.cast(const UncastValue('1 2; 3 4;'));
      expect(trace.points, hasLength(2));
      expect(trace.uncast().string, '1.0 2.0 0.0 0.0;3.0 4.0 0.0 0.0');
    });

    test('dates', () {
      final date = DateValue.cast(const UncastValue('2018-01-31'));
      expect(date.uncast().string, '2018-01-31');
      expect(date.displayText, '31/01/18');
      expect(
        () => DateValue.cast(const UncastValue('2018-02-31')),
        throwsArgumentError,
      );
    });
  });

  test('casts reject invalid input with JavaRosa messages', () {
    expect(
      () => IntegerValue.cast(const UncastValue('1.5')),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'Invalid cast of data [1.5] to type Decimal',
        ),
      ),
    );
    expect(() => LongValue.cast(const UncastValue(' 1')), throwsArgumentError);
    // JavaRosa's BooleanData.cast always fails (it compares to the wrong
    // object); ported as is.
    expect(
      () => BooleanValue.cast(const UncastValue('1')),
      throwsArgumentError,
    );
  });

  group('wrapData (calculate results)', () {
    test('empty results become null', () {
      expect(wrapData('', DataType.text), isNull);
      expect(wrapData(double.nan, DataType.decimal), isNull);
    });

    test('numbers pick integer, long or decimal', () {
      expect(wrapData(3.0, DataType.text), const IntegerValue(3));
      expect(wrapData(3.0, DataType.decimal), const IntegerValue(3));
      expect(wrapData(3.5, DataType.decimal), const DecimalValue(3.5));
      expect(wrapData(3.7, DataType.integer), const IntegerValue(3));
      expect(wrapData(3e10, DataType.decimal), const LongValue(30000000000));
    });

    test('booleans', () {
      expect(wrapData(true, DataType.text), const BooleanValue(true));
      expect(wrapData(0.0, DataType.boolean), const BooleanValue(false));
      expect(wrapData('x', DataType.boolean), const BooleanValue(true));
    });

    test('typed nodes parse the string form', () {
      expect(
        wrapData('a b', DataType.multipleItems),
        isA<MultipleItemsValue>(),
      );
      expect(wrapData('1 2', DataType.geopoint), isA<GeoPointValue>());
      expect(wrapData('2018-01-01', DataType.date), isA<DateValue>());
      expect(wrapData('not a date', DataType.date), isNull);
      expect(wrapData('hello', DataType.text), const StringValue('hello'));
    });
  });
}
