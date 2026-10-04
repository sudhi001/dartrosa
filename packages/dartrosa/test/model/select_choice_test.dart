// Port of JavaRosa v6.0.0 SelectChoiceTest. Most tests read choices
// through the form runner (P4) or itemsets (P5).
import 'package:dartrosa/src/model/select_choice.dart';
import 'package:test/test.dart';

void main() {
  test('value is trimmed when the select choice is constructed', () {
    expect(
      SelectChoice(null, 'Label', ' value ', isLocalizable: false).value,
      'value',
    );
  });

  test(
    'value stays an empty string after deserialization',
    () {},
    skip: 'codec (P6)',
  );
  for (final name in [
    'getChild returns named child when choices are from secondary instance',
    'getChild returns null when requested child does not exist',
    'getChild returns empty string when requested child has no value',
    'getChild updates when choices are from repeat',
    'getChild returns null when called on a choice from inline select',
    'getAdditionalChildren returns children in order',
    'getChildren updates when choices are from repeat',
    'select from repeat uses specified value and label refs',
    'getAdditionalChildren returns empty for inline select',
    'getAdditionalChildren returns empty string value for empty children',
    'itemset binding verification does not verify second item',
    'itemset binding verification verifies first item',
  ]) {
    test(name, () {}, skip: 'needs the form runner and itemsets (P4/P5)');
  }
}
