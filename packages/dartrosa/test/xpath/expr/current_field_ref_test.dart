// Port of JavaRosa v6.0.0 CurrentFieldRefTest.
@TestOn('vm')
library;

import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../support/forms.dart';
import '../../support/matchers.dart';

void main() {
  late Scenario scenario;
  setUp(
    () async =>
        scenario = await scenarioFor('relative-current-ref-field-ref.xml'),
  );

  test('current_in_a_field_ref_should_be_the_same_as_a_relative_ref', () {
    // The ref on /data/my_group[1]/name uses current()/name instead of an
    // absolute path
    scenario
      ..answer('/data/my_group[1]/name', 'Bob')
      ..answer('/data/my_group[2]/name', 'Janet');

    expect(scenario.answerOf('/data/my_group[1]/name'), stringAnswer('Bob'));
    expect(scenario.answerOf('/data/my_group[2]/name'), stringAnswer('Janet'));
  });
}
