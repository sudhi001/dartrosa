// Port of JavaRosa v6.0.0 FormIndexSerializationTest.
import 'package:test/test.dart';

void main() {
  for (final name in [
    'testBeginningOfForm',
    'testEndOfForm',
    'testLocalAndInstanceNullReference',
    'testLocalAndInstanceNonNullReference',
    'testOnFormController',
  ]) {
    test(name, () {}, skip: 'instance/form serialization (P6)');
  }
}
