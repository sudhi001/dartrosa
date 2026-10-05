# dartrosa_calendars

The non-Gregorian date appearances of ODK Collect for
[DartRosa](https://github.com/sudhi001/dartrosa): `ethiopian`, `coptic`,
`islamic`, `bikram-sambat`, `myanmar`, `persian` and `buddhist`.

- `DatePickerDetails.fromAppearance` tells which calendar and spinners a
  date question uses (`month-year`, `year`, `no-calendar` included).
- `CustomCalendar` converts the Gregorian dates ODK stores to the
  calendar's dates and gives the month names and year range Collect's
  spinners offer.
- `dateTimeLabel` is the text Collect shows for an answer.
- `CustomDatePickerModel` is the state of Collect's spinner dialog.

Pure Dart, no dependency on the engine. Ports of ODK Collect's date widget
logic and of the libraries it uses (Joda-Time, persianjodatime,
bikram-sambat, myanmar-calendar); conversions match them day for day from
1880 to 2120. `dartrosa_flutter` uses it for its date pickers.

## Install

Not on pub.dev yet; depend on it from Git:

```yaml
dependencies:
  dartrosa_calendars:
    git:
      url: https://github.com/sudhi001/dartrosa
      path: packages/dartrosa_calendars
```

## Example

```dart
import 'package:dartrosa_calendars/dartrosa_calendars.dart';

void main() {
  final date = DateTime(2024, 3, 20);
  final details = DatePickerDetails.fromAppearance('ethiopian');
  final calendar = CustomCalendar.of(details.type);
  print(calendar.fromGregorian(date)); // 11 Megabit 2016
  print(dateTimeLabel(date, details)); // 11 Megabit 2016 (Mar 20, 2024)
}
```

See [example/example.dart](example/example.dart).

## Documentation

- [Getting started](https://github.com/sudhi001/dartrosa/blob/main/docs/GETTING_STARTED.md)
- [Compatibility matrix](https://github.com/sudhi001/dartrosa/blob/main/docs/COMPATIBILITY.md)
- [Plugins and extension points](https://github.com/sudhi001/dartrosa/blob/main/docs/PLUGINS.md)
- [Migrating from JavaRosa](https://github.com/sudhi001/dartrosa/blob/main/docs/MIGRATING_FROM_JAVAROSA.md)

## License

Apache License 2.0 (see [LICENSE](LICENSE)). Ports ODK Collect code and
the calendar algorithms of the libraries it uses (Apache-2.0 and MIT);
see [NOTICE.md](https://github.com/sudhi001/dartrosa/blob/main/NOTICE.md)
for their attribution.
