// Port of JavaRosa v6.0.0 TreeElementTests and
// SameRefDifferentInstancesIssue449Test.
import 'package:test/test.dart';

void main() {
  test(
    'populate with node attributes',
    () {},
    skip: 'TreeElement.populate is ported with instance loading (P6)',
  );
  for (final name in [
    'form with same ref in different instances is deserialized',
    'constraints are correctly applied after deserialization',
  ]) {
    test(name, () {}, skip: 'needs the form runner and codec (P4/P6)');
  }
}
