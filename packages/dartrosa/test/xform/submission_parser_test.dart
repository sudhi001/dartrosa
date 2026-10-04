// Port of JavaRosa v6.0.0 SubmissionParserTest. JavaRosa's SubmissionParser
// is a separate class with a dead extension point (no way to register
// custom parsers); DartRosa inlines it, so it is tested through a form.
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  test('parse submission', () async {
    final form = await XFormParser().parse(
      html(
        head([
          title('Form'),
          model([
            mainInstance([
              t('data id="form"', [t('text')]),
            ]),
            t(
              'submission method="POST" action="ACTION" ref="/data/text" '
              'mediatype="application/xml" custom_attribute="custom value"',
            ),
          ]),
        ]),
        body([input('/data/text')]),
      ).asXml(),
    );
    final profile = form.submissionProfile()!;
    expect(profile.action, 'ACTION');
    expect(profile.method, 'POST');
    expect(profile.ref, getRef('/data/text'));
    expect(profile.mediaType, 'application/xml');
    expect(profile.attribute('custom_attribute'), 'custom value');
    expect(profile.attribute('ref'), isNull);
    expect(profile.attribute('method'), isNull);
  });
}
