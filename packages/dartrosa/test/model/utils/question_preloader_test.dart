// Port of JavaRosa v6.0.0 QuestionPreloaderTest.
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  test('preloader_preloadsElements', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Preload element'),
          model([
            mainInstance([
              t('data id="preload-attribute"', [t('element')]),
            ]),
            bind('/data/element')..preload('uid'),
          ]),
        ]),
        body([input('/data/element')]),
      ),
    );

    expect(
      scenario.answerOf('/data/element')!.displayText,
      startsWith('uuid:'),
    );
  });

  // Unintentional limitation
  test('preloader_doesNotpreloadAttributes', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Preload attribute'),
          model([
            mainInstance([
              t('data id="preload-attribute"', [t('element attr=""')]),
            ]),
            bind('/data/element/@attr')..preload('uid'),
          ]),
        ]),
        body([input('/data/element')]),
      ),
    );

    expect(scenario.answerOf('/data/element/@attr')!.displayText, '');
  });
}
