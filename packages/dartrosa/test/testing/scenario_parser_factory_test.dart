// Added for Phase 8: Scenario.parserFactory and FormDef.extras (parser
// plugins such as ODK Collect's entities keep data in FormDef.extras).
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

final class _ExtrasProcessor implements FormDefProcessor {
  int calls = 0;

  @override
  void processFormDef(FormDef form) {
    calls++;
    form.extras[_ExtrasProcessor] = form.title;
  }
}

void main() {
  XFormsElement form() => html(
    head([
      title('Extras'),
      model([
        mainInstance([
          t('data id="extras"', [t('q')]),
        ]),
      ]),
    ]),
    body([input('/data/q')]),
  );

  test('FormDef.extras starts empty', () {
    expect(FormDef().extras, isEmpty);
  });

  test('parserFactory parsers are used to load and restore the form', () async {
    final processor = _ExtrasProcessor();
    final scenario = await Scenario.init(
      form(),
      parserFactory: (resolver) =>
          XFormParser(resolver: resolver)..addProcessor(processor),
    );
    expect(scenario.formDef.extras[_ExtrasProcessor], 'Extras');

    scenario.answer('/data/q', 'a');
    final restored = await scenario.serializeAndDeserializeForm();
    expect(restored.formDef.extras[_ExtrasProcessor], 'Extras');
    expect(restored.answerOf('/data/q')?.value, 'a');

    final reloaded = await restored.serializeAndDeserializeInstance(form());
    expect(reloaded.formDef.extras[_ExtrasProcessor], 'Extras');
    expect(processor.calls, 3);
  });
}
