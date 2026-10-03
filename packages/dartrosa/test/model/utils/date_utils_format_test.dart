// Port of JavaRosa v6.0.0 DateUtilsFormatTests.
import 'package:dartrosa/src/model/utils/date_utils.dart';
import 'package:test/test.dart';

void main() {
  test('format week of year', () {
    expect(
      formatFields(DateFields.of(2018, 4, 1, 10, 20, 30, 400), '%W'),
      '13',
    );
    expect(formatFields(DateFields.of(2018, 1, 1, 10, 20, 30, 400), '%W'), '1');
    // Week of year is based on what year the first Thursday is. 1/1/2017
    // was a Sunday so it's actually the 52nd week of the previous year.
    expect(
      formatFields(DateFields.of(2017, 1, 1, 10, 20, 30, 400), '%W'),
      '52',
    );
    // 12/29/2020 is the 53rd week of the year.
    expect(
      formatFields(DateFields.of(2020, 12, 29, 10, 20, 30, 400), '%W'),
      '53',
    );
  });
}
