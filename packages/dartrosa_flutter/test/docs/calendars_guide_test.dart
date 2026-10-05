// The code of docs/guides/non-gregorian-calendars.md, run as tests so the
// guide can't rot (packages/dartrosa/test/docs checks that the guide's
// snippets are here).
import 'package:dartrosa_calendars/dartrosa_calendars.dart';
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const formXml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head>
    <h:title>Visit</h:title>
    <model>
      <instance><data id="visit"><visit_date/></data></instance>
      <bind nodeset="/data/visit_date" type="date"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/visit_date" appearance="ethiopian">
      <label>Visit date</label>
    </input>
  </h:body>
</h:html>
''';

// Collect's spinner dialog, outside a form: pops the Gregorian date, or
// null when cancelled.
Future<DateTime?> pickDate(BuildContext context) => showDialog<DateTime>(
  context: context,
  builder: (context) => CustomCalendarDatePickerDialog(
    details: DatePickerDetails.fromAppearance('ethiopian'),
    initialDate: DateTime(2024, 3, 20),
  ),
);

void main() {
  test('the stored value is the Gregorian date', () async {
    final definition = await FormDefinition.parse(formXml);
    final session = definition.createSession();
    final date = session.root.children.first as QuestionNode;
    session.answer(date.index, DateValue(DateTime(2024, 3, 20)));
    // The instance holds <visit_date>2024-03-20</visit_date>.
    final draft = session.saveDraft();
    expect(draft, contains('<visit_date>2024-03-20</visit_date>'));
    expect(date.appearance, 'ethiopian');
  });

  test('conversions and labels', () {
    final details = DatePickerDetails.fromAppearance('ethiopian');
    final calendar = CustomCalendar.of(details.type);
    final day = DateTime(2024, 3, 20);
    final ethiopian = calendar.fromGregorian(day); // 11 Megabit 2016
    final label = dateTimeLabel(day, details); // 11 Megabit 2016 (Mar 20, 2024)
    final years = (calendar.minYear, calendar.maxYear); // (1893, 2093)
    expect('$ethiopian', '11 Megabit 2016');
    expect(label, '11 Megabit 2016 (Mar 20, 2024)');
    expect(years, (1893, 2093));
  });

  test('appearances combine a calendar and a mode', () {
    final details = DatePickerDetails.fromAppearance('persian month-year');
    final type = details.type; // DatePickerType.persian
    final monthYear = details.isMonthYearMode; // true: no day spinner
    expect(type, DatePickerType.persian);
    expect(monthYear, isTrue);
  });

  test('your own picker over CustomDatePickerModel', () {
    final picker = CustomDatePickerModel(
      DatePickerDetails.fromAppearance('persian'),
      DateTime(2024, 3, 20),
    );
    final shown = (picker.day, picker.year); // (1, 1403): 1 Farvardin 1403
    picker.setYear(picker.year + 1); // the user turns the year spinner
    final chosen = picker.gregorianDate; // 2025-03-21, the date to store
    final text = picker.label(); // 1 Farvardin 1404 (Mar 21, 2025)
    expect(shown, (1, 1403));
    expect(chosen, DateTime(2025, 3, 21));
    expect(text, '1 Farvardin 1404 (Mar 21, 2025)');
  });

  testWidgets('the dialog pops the Gregorian date', (tester) async {
    late Future<DateTime?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = pickDate(context),
            child: const Text('Pick'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(await result, DateTime(2024, 3, 20));
  });
}
