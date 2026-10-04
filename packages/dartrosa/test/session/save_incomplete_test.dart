// DartRosa test: QuestionNode.saveIncomplete exposes the ODK spec's
// `saveIncomplete="true()"` bind attribute (kept by JavaRosa as a bind
// attribute) to apps.
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  test('saveIncomplete reflects the bind attribute', () async {
    final xml = html(
      head([
        title('Save'),
        model([
          mainInstance([
            t('data id="save"', [t('a'), t('b')]),
          ]),
          bind('/data/a')
            ..type('string')
            ..withAttribute('', 'saveIncomplete', 'true()'),
          bind('/data/b')..type('string'),
        ]),
      ]),
      body([input('/data/a'), input('/data/b')]),
    ).asXml().replaceFirst(':saveIncomplete', 'saveIncomplete');
    final session = (await FormDefinition.parse(xml)).createSession();
    final [a, b] = session.root.children.cast<QuestionNode>();
    expect(a.saveIncomplete, isTrue);
    expect(b.saveIncomplete, isFalse);
  });
}
