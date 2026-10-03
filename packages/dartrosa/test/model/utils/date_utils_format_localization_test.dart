// Port of JavaRosa v6.0.0 DateUtilsFormatLocalizationTests. The Java test
// switches the default Locale; here the locale is a parameter. Expected
// names are Java 27's (Month/DayOfWeek.getDisplayName(SHORT, locale)).
import 'package:dartrosa/src/model/utils/date_utils.dart';
import 'package:test/test.dart';

void main() {
  test('format is localized', () {
    // A Sunday in January.
    final date = DateTime(2018, 1, 7, 10, 20, 30, 400);
    const expected = {
      'en': ('Jan', 'Sun'),
      'es-ES': ('ene', 'dom'),
      'fr': ('janv.', 'dim.'),
    };
    expected.forEach((locale, names) {
      expect(format(date, '%b', locale: locale), names.$1, reason: locale);
      expect(format(date, '%a', locale: locale), names.$2, reason: locale);
    });
  });
}
