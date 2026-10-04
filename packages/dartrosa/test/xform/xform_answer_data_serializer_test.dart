// Port of JavaRosa v6.0.0 XFormAnswerDataSerializerTest: answers written
// into instance XML, ported with instance serialization (P6).
import 'package:test/test.dart';

void main() {
  for (final name in ['string', 'integer', 'date', 'time', 'select']) {
    test(name, () {}, skip: 'instance serialization (P6)');
  }
}
