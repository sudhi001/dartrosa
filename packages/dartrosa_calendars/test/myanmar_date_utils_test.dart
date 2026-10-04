// Port of ODK Collect's MyanmarDateUtilsTest ("Results confirmed with
// https://yan9a.github.io/mcal/").
import 'package:dartrosa_calendars/src/gregorian.dart';
import 'package:dartrosa_calendars/src/myanmar/myanmar_date_utils.dart';
import 'package:test/test.dart';

void main() {
  test('convertDatesTest', () {
    const cases = [
      (1900, 1, 28, 1261, 'ပြာသို', 29),
      (1912, 2, 15, 1273, 'တပို့တွဲ', 28),
      (1924, 3, 7, 1285, 'တပေါင်း', 3),
      (1938, 4, 10, 1299, 'နှောင်းတန်ခူး', 11),
      (1944, 5, 29, 1306, 'နယုန်', 8),
      (1959, 6, 1, 1321, 'ကဆုန်', 26),
      (1963, 7, 11, 1325, 'ဝါဆို', 21),
      (1972, 8, 16, 1334, 'ဝါခေါင်', 7),
      (1986, 9, 20, 1348, 'တော်သလင်း', 17),
      (1991, 10, 20, 1353, 'သီတင်းကျွတ်', 12),
      (2000, 11, 25, 1362, 'တန်ဆောင်မုန်း', 30),
      (2013, 12, 30, 1375, 'နတ်တော်', 28),
      (2027, 1, 2, 1388, 'နတ်တော်', 24),
      (2033, 2, 12, 1394, 'တပို့တွဲ', 13),
      (2048, 3, 15, 1409, 'နှောင်းတန်ခူး', 2),
      (2059, 4, 21, 1421, 'တန်ခူး', 9),
      (2064, 5, 24, 1426, 'နယုန်', 10),
      (2077, 6, 4, 1439, 'နယုန်', 14),
      (2085, 7, 19, 1447, 'ဝါဆို', 28),
      (2097, 8, 22, 1459, 'ဝါခေါင်', 15),
    ];
    for (final (y, m, d, myear, monthName, day) in cases) {
      final gregorian = epochDayOf(y, m, d);
      final md = MyanmarDateUtils.gregorianDateToMyanmarDate(gregorian);
      expect(md.year, myear);
      expect(md.monthName, monthName);
      expect(md.dayOfMonth, day);
      expect(MyanmarDateUtils.myanmarDateToGregorianDate(md), gregorian);
      final monthIndex = MyanmarDateUtils.getMonthIndexes(
        md.year,
      )[MyanmarDateUtils.getMonthId(md)];
      final created = MyanmarDateUtils.createMyanmarDate(
        md.year,
        monthIndex,
        md.dayOfMonth,
      );
      expect(
        [created.year, created.monthName, created.dayOfMonth],
        [md.year, md.monthName, md.dayOfMonth],
      );
    }
  });
}
