// Port of JavaRosa v6.0.0 XPathConditionalTriggersTest.
import 'package:dartrosa/src/model/condition/conditions.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'getTriggers_onExpressionWithRelativePathInPredicate_returnsPredicateTriggers',
    () {
      final expression = XPathConditional.parse(
        '../inner[position() = ../node2]/node3',
      );
      final context = getRef('/data/outer[7]/node1');

      final predicateTrigger = getRef('/data/outer[7]/node2');

      expect(expression.triggers(context), contains(predicateTrigger));
    },
  );

  test(
    'getTriggers_onExpressionWithComplexRelativePathInPredicate_returnsPredicateTriggers',
    () {
      final expression = XPathConditional.parse(
        '../inner[position() = anode and /data/foo = x/y/z]/anothernode',
      );
      final context = getRef('/data/outer[7]/bar/baz');

      expect(
        expression.triggers(context),
        containsAll([
          getRef('/data/outer[7]/bar/inner/anode'),
          getRef('/data/foo'),
          getRef('/data/outer[7]/bar/inner/x/y/z'),
        ]),
      );
    },
  );

  test(
    'getTriggers_onExpressionWithRelativePredicateAndNoContext_throwsError',
    () {
      final expression = XPathConditional.parse(
        '../inner[position() = ../node2]/node3',
      );

      expect(() => expression.triggers(null), throwsArgumentError);
    },
  );

  test(
    'getTriggers_onExpressionWithRelativePredicateWithCurrent_returnsTriggersContextualizedWithOriginalContext',
    () {
      final expression = XPathConditional.parse(
        "instance('dataset')/root/item[value > current()/../../node1]/name",
      );
      final context = getRef('/data/outer[7]/inner[3]/node2');

      final predicateTrigger = getRef('/data/outer[7]/node1');

      expect(expression.triggers(context), contains(predicateTrigger));
    },
  );
}
