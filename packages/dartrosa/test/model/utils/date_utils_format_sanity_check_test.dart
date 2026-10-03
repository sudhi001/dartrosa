// Port of JavaRosa v6.0.0 DateUtilsFormatSanityCheckTests.
//
// The Java test repeats the check under several default time zones
// (default, UTC, GMT+12, GMT-13, GMT+0230). Here it runs in the process's
// local zone; CI runs the suite under each of those zones via TZ.
import 'package:dartrosa/src/model/utils/date_utils.dart';
import 'package:test/test.dart';

void main() {
  for (final timestamp in const [1300139579000, 0]) {
    test('ISO format and parse back: $timestamp', () {
      final input = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final output = parseDateTime(
        formatDateTime(input, DateFormatStyle.iso8601),
      );
      expect(output?.millisecondsSinceEpoch, timestamp);
    });
  }
}
