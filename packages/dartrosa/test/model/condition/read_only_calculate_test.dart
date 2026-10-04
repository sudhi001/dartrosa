// Port of JavaRosa v6.0.0 ReadOnlyCalculateTest.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../support/matchers.dart';

void main() {
  // Read-only is only a UI concern so calculates should be evaluated on
  // read-only fields.
  test('calculate_evaluatedOnReadonlyFieldWithUi', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Calculate readonly'),
          model([
            mainInstance([
              t('data id="calculate-readonly"', [t('readonly-calculate')]),
            ]),
            bind('/data/readonly-calculate')
              ..readonly('1')
              ..calculate('7 * 2'),
          ]),
        ]),
        body([input('/data/readonly-calculate')]),
      ),
    );

    expect(scenario.answerOf('/data/readonly-calculate'), intAnswer(14));
  });
}
