// Port of JavaRosa v6.0.0 BufferedInputStreamTests.
import 'package:test/test.dart';

void main() {
  for (final name in ['testBuffered', 'testIndividual']) {
    test(
      name,
      () {},
      skip:
          'Externalizable binary format is not ported '
          '(FormDefCodec replaces it)',
    );
  }
}
