// Port of JavaRosa v6.0.0 FormDefTest. Every test drives the form through
// Scenario, so they are ported with the form runner (P4).
import 'package:test/test.dart';

void main() {
  for (final name in [
    'enforces constraints defined in a field',
    'enforces constraints when instance is deserialized',
    'repeat relevance changes when dependent values of relevance change',
    'repeat is irrelevant when relevance set to false',
    'repeat relevance changes with grandparent relevance dependencies',
    'repeat is irrelevant when grandparent relevance set to false',
    'nested repeat relevance updates based on parent position',
    'inner repeat group is irrelevant when its parent repeat does not exist',
    'canCreateRepeat is false when repeat count group does not exist',
    'fillTemplateString resolves relative references',
    'fillTemplateString resolves relative references in itext',
    'can add function handlers before initialize',
  ]) {
    test(name, () {}, skip: 'needs the form runner (P4)');
  }
}
