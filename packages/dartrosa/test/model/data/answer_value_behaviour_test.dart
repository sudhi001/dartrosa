// DartRosa tests (not ports) of answer values not covered by the JavaRosa
// ports: long/decimal/date-time/time casts and texts, geo trace/shape
// accuracy, wrapData's failures and pointer answers. Every expectation was
// captured from JavaRosa 6.0.0 (jshell, the matching IAnswerData classes),
// in UTC like the rest of the suite.
@TestOn('vm')
library;

import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/data_type.dart';
import 'package:test/test.dart';

final class FilePointer implements DataPointer {
  const FilePointer(this.displayText);

  @override
  final String displayText;
}

Matcher invalidCast(String message) =>
    throwsA(isA<ArgumentError>().having((e) => e.message, 'message', message));

void main() {
  test('long values', () {
    final big = LongValue.cast(const UncastValue('9007199254740993'));
    expect(big.displayText, '9007199254740993');
    expect(big.value, 9007199254740993);
    expect(const LongValue(42).uncast(), const UncastValue('42'));
    expect('${const LongValue(3)}', 'LongData{n=3}');
    expect(const LongValue(3), const LongValue(3));
    expect(const LongValue(3).hashCode, const LongValue(3).hashCode);
    expect(
      () => LongValue.cast(const UncastValue('x')),
      invalidCast('Invalid cast of data [x] to type Long'),
    );
  });

  test('decimal values', () {
    expect(DecimalValue.cast(const UncastValue('1e3')).displayText, '1000.0');
    expect(DecimalValue.cast(const UncastValue('1e3')).value, 1000.0);
    expect(
      () => DecimalValue.cast(const UncastValue('abc')),
      invalidCast('Invalid cast of data [abc] to type Decimal'),
    );
    // NaN equals itself, like Java's Double.equals.
    expect(const DecimalValue(double.nan), const DecimalValue(double.nan));
    expect(
      const DecimalValue(double.nan).hashCode,
      const DecimalValue(double.nan).hashCode,
    );
  });

  test('date-time values', () {
    // Display and serialization use the device's local zone (as in
    // JavaRosa), so build the value from a local time.
    final value = DateTimeValue(DateTime(2020, 3, 4, 5, 6, 7));
    expect(value.displayText, '04/03/20 05:06');
    expect(DateTimeValue.cast(value.uncast()), value);
    expect(
      DateTimeValue.cast(const UncastValue('2020-03-04T05:06:07.000Z')),
      DateTimeValue.cast(const UncastValue('2020-03-04T05:06:07.000Z')),
    );
    expect(
      () => DateTimeValue.cast(const UncastValue('nope')),
      invalidCast('Invalid cast of data [nope] to type DateTime'),
    );
  });

  test('time values', () {
    // Local zone, as for date-times. Parsed times are re-based on today's
    // date (JavaRosa's TimeDataLimitationsTest), so build it on today.
    final now = DateTime.now();
    final value = TimeValue(DateTime(now.year, now.month, now.day, 13, 45, 10));
    expect(value.displayText, '13:45');
    expect(TimeValue.cast(value.uncast()).displayText, '13:45');
    expect(
      TimeValue.cast(const UncastValue('13:45:10.000Z')),
      TimeValue.cast(const UncastValue('13:45:10.000Z')),
    );
    expect(value.hashCode, TimeValue(value.time).hashCode);
    expect(
      () => TimeValue.cast(const UncastValue('25:99')),
      invalidCast('Invalid cast of data [25:99] to type Time'),
    );
  });

  test('date values compare by day', () {
    // Local times on the same local day.
    final a = DateValue(DateTime(2020, 1, 2, 10));
    final b = DateValue(DateTime(2020, 1, 2, 20));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('geo point parts beyond those given are missing', () {
    expect(
      () => GeoPointValue(const [1, 2]).part(2),
      throwsA(
        isA<RangeError>().having(
          (e) => e.message,
          'message',
          'Cannot find coordinates part with index 2',
        ),
      ),
    );
  });

  test('geo traces and shapes report the largest accuracy', () {
    final trace = GeoTraceValue.cast(
      const UncastValue('1 2 0 5; 3 4 0 12; 5 6 0 7'),
    );
    expect(
      trace.displayText,
      '1.0 2.0 0.0 5.0;3.0 4.0 0.0 12.0;5.0 6.0 0.0 7.0',
    );
    expect('$trace', trace.displayText);
    expect(trace.toNumeric(), 12.0);
    expect(trace.toBoolean(), isTrue);
    expect(trace.value, hasLength(3));
    final shape = GeoShapeValue.cast(const UncastValue('1 2 0 5; 3 4 0 12'));
    expect(shape.toNumeric(), 12.0);
    expect(shape, isNot(GeoTraceValue(shape.points)));
    expect(GeoTraceValue(const []).toBoolean(), isFalse);
    expect(GeoTraceValue(const []).toNumeric(), GeoPointValue.noAccuracyValue);
  });

  test('wrapData parses geo traces and shapes', () {
    expect(
      wrapData('1 2;3 4', DataType.geotrace)!.displayText,
      '1.0 2.0 0.0 0.0;3.0 4.0 0.0 0.0',
    );
    expect(
      wrapData('1 2;3 4;1 2', DataType.geoshape)!.displayText,
      '1.0 2.0 0.0 0.0;3.0 4.0 0.0 0.0;1.0 2.0 0.0 0.0',
    );
  });

  test('wrapData rejects unknown representations', () {
    expect(
      () => wrapData(<Object>[], DataType.text),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          startsWith("unrecognized data type in 'calculate' expression"),
        ),
      ),
    );
    expect(
      () => wrapData(<Object>[], DataType.boolean),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'unrecognized data representation while trying to convert to '
              'BOOLEAN',
        ),
      ),
    );
  });

  test('pointer answers', () {
    const a = FilePointer('a.jpg');
    const b = FilePointer('b.jpg');
    const single = PointerValue(a);
    expect(single.value, a);
    expect(single.displayText, 'a.jpg');
    expect(single.uncast().string, 'a.jpg');
    expect(single, const PointerValue(a));
    expect(single.hashCode, const PointerValue(a).hashCode);

    final multi = MultiPointerValue([a, b]);
    expect(multi.value, [a, b]);
    expect(multi.displayText, 'a.jpg, b.jpg');
    expect(multi.uncast().string, 'a.jpg b.jpg');
    expect(multi, MultiPointerValue([a, b]));
    expect(multi.hashCode, MultiPointerValue([a, b]).hashCode);
  });

  test('uncast values', () {
    expect('${const UncastValue('x')}', 'UncastValue{x}');
    expect(const UncastValue('x').hashCode, const UncastValue('x').hashCode);
    expect(const BooleanValue(true).value, isTrue);
    expect(
      const BooleanValue(true).hashCode,
      const BooleanValue(true).hashCode,
    );
    expect(const IntegerValue(1).hashCode, const IntegerValue(1).hashCode);
  });
}
