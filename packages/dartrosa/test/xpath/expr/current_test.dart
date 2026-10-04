// Port of JavaRosa v6.0.0 CurrentTest.
@TestOn('vm')
library;

import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../support/forms.dart';
import '../../support/matchers.dart';

void main() {
  late Scenario scenario;
  setUp(() async => scenario = await scenarioFor('relative-current-ref.xml'));

  // current() in a calculate should refer to the node it is in (in this case,
  // /data/my_group/name_relative). This means that to refer to a sibling
  // node, the path should be current()/../<name of sibling node>. This is
  // verified by changing the value of the node that the calculate is
  // supposed to refer to (/data/my_group/name) and seeing that the dependent
  // calculate is updated accordingly.
  test('current_as_calculate_root_should_refer_to_its_bound_nodeset', () {
    scenario.answer('/data/my_group/name', 'Bob');

    // The binding of /data/my_group/name_relative is:
    //   <bind calculate="current()/../name"
    //         nodeset="/data/my_group/name_relative" type="string"/>
    // That will copy the value of our previous answer to /data/my_group/name
    expect(
      scenario.answerOf('/data/my_group/name_relative'),
      answer(scenario.answerOf('/data/my_group/name')!),
    );
  });

  // current() in a choice filter should refer to the select node the choice
  // filter is called from, NOT the expression it is in. See
  // https://developer.mozilla.org/en-US/docs/Web/XPath/Functions/current --
  // this is the difference between current() and .
  //
  // The behavior of current() in a choice filter is verified by selecting a
  // value for a first, static select and then using that value to filter a
  // second, dynamic select.
  test(
    'current_as_itemset_choice_filter_root_should_refer_to_the_select_node',
    () {
      scenario.answer('/data/fruit', 'blueberry');
      final choices = scenario.choicesOf('/data/variety');
      // The itemset for /data/variety is
      // instance('variety')/root/item[fruit = current()/../fruit]
      // and the "variety" instance has three items for blueberry: blueray,
      // collins, and duke
      expect(
        choices,
        unorderedEquals([choice('blueray'), choice('collins'), choice('duke')]),
      );
    },
  );
}
