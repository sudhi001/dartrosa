// Port of JavaRosa v6.0.0 QuestionDefTest and TextFormTests.
@TestOn('vm')
library;

import 'package:dartrosa/src/form_api/form_entry_caption.dart';
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/src/form_api/form_entry_prompt.dart';
import 'package:dartrosa/src/i18n/locale_source.dart';
import 'package:dartrosa/src/i18n/localizer.dart';
import 'package:dartrosa/src/model/control_type.dart';
import 'package:dartrosa/src/model/form_element.dart';
import 'package:dartrosa/src/model/form_index.dart';
import 'package:dartrosa/src/model/select_choice.dart';
import 'package:dartrosa/src/reference/reference_manager.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/form_parse_init.dart';

/// Port of `DummyFormEntryPrompt`: a prompt with its own localizer and
/// text id, without argument substitution.
final class DummyFormEntryPrompt extends FormEntryPrompt {
  DummyFormEntryPrompt(super.form, super.index, this._localizer, this._textId);

  final Localizer _localizer;
  final String _textId;

  @override
  String? get textId => _textId;

  @override
  Localizer? get localizer => _localizer;

  @override
  String? substituteStringArgs(String? template) => template;
}

void main() {
  group('QuestionDefTest', () {
    test('constructors', () {
      expect(QuestionDef().id, -1);
      final q = QuestionDef(id: 17, controlType: ControlType.range);
      expect(q.id, 17);
      expect(q.controlType, ControlType.range);
    });

    test('accessors and modifiers', () {
      final q = QuestionDef()..id = 45;
      expect(q.id, 45);
      final ref = getRef('/data');
      q.bind = ref;
      expect(q.bind, same(ref));
      q.controlType = ControlType.selectOne;
      expect(q.controlType, ControlType.selectOne);
      q.appearance = 'minimal';
      expect(q.appearance, 'minimal');
    });

    test('child', () {
      // JavaRosa returns null children; DartRosa an empty list.
      final q = QuestionDef();
      expect(q.children, isEmpty);
      expect(() => q.addChild(QuestionDef()), throwsStateError);
    });

    test('flag observers', () {
      final q = QuestionDef();
      var flagged = false;
      void observer(FormElement element, int changes) => flagged = true;
      q.addListener(observer);
      expect(flagged, isFalse);
      q
        ..removeListener(observer)
        ..notifyListeners(1);
      expect(flagged, isFalse);
    });

    test('references', () async {
      final fpi = await FormParseInit.load('ImageSelectTester.xhtml');
      fpi.firstQuestionDef;
      var fep = fpi.formEntryModel.questionPrompt();

      final l = fpi.formDef.localizer!;
      l
        ..defaultLocale = l.availableLocales[0]
        ..locale = l.availableLocales[0];

      final audioUri = fep.audioText!;

      final referenceManager = ReferenceManager()
        ..addReferenceFactory(PrefixedRootFactory.resource())
        ..addRootTranslator(
          const RootTranslator('jr://audio/', 'jr://resource/'),
        );
      expect(
        referenceManager.deriveReference(audioUri).uri,
        'jr://resource/hah.mp3',
        reason: 'Root translation failed.',
      );

      referenceManager.addRootTranslator(
        const RootTranslator('jr://images/', 'jr://resource/'),
      );
      fpi.nextQuestion();
      fep = fpi.formEntryModel.questionPrompt();
      final imUri = fep.imageText!;
      expect(
        referenceManager.deriveReference(imUri).uri,
        'jr://resource/four.gif',
        reason: 'Root translation failed.',
      );
    });
  });

  group('TextFormTests', () {
    late FormParseInit fpi;
    late FormEntryPrompt fep;

    setUp(() async {
      fpi = await FormParseInit.load('ImageSelectTester.xhtml');
      fpi.firstQuestionDef;
      fep = FormEntryPrompt(fpi.formDef, fpi.formEntryModel.formIndex);
    });

    test('constructors', () {
      expect(QuestionDef().id, -1);
      final q = QuestionDef(id: 17, controlType: ControlType.range);
      expect(q.id, 17);
      expect(q.controlType, ControlType.range);
    });

    /// Test that the long and short text forms work as expected (fallback
    /// to default for example). Test being able to retrieve other exotic
    /// forms.
    test('text forms', () {
      final fec = fpi.formEntryController
        ..jumpToIndex(FormIndex.beginningOfForm());
      final l = fpi.formDef.localizer!;
      l
        ..defaultLocale = l.availableLocales[0]
        ..locale = l.availableLocales[0];
      while (fec.stepToNextEvent() != FormEntryEvent.question) {}
      fep = fec.model.questionPrompt();

      expect(fep.longText, 'Patient ID');
      expect(fep.shortText, 'ID');
      expect(fep.audioText, 'jr://audio/hah.mp3');

      while (fec.stepToNextEvent() != FormEntryEvent.question) {}
      fep = fec.model.questionPrompt();
      expect(fep.shortText, 'Name');
      expect(
        fep.longText,
        'Full Name',
        reason: 'getLongText() not falling back to default text form',
      );
      expect(fep.specialFormQuestionText('long'), isNull);
    });

    test('non-localized text', () {
      final fec = fpi.formEntryController
        ..jumpToIndex(FormIndex.beginningOfForm());
      var testFlag = false;
      final l = fpi.formDef.localizer!;
      l
        ..defaultLocale = l.availableLocales[0]
        ..locale = l.availableLocales[0];

      do {
        if (fpi.currentQuestion == null) continue;
        fep = fpi.formEntryModel.questionPrompt();
        final t = fep.questionText();
        if (t == null) continue;
        if (t == 'Non-Localized label inner text!') testFlag = true;
      } while (fec.stepToNextEvent() != FormEntryEvent.endOfForm);

      expect(
        testFlag,
        isTrue,
        reason:
            'Failed to fallback to labelInnerText in testNonLocalizedText()',
      );
    });

    test('select choice ids without localizer', () {
      final q = fpi.firstQuestionDef!
        ..addSelectChoice(SelectChoice.localized('choice1 id', 'val1'))
        ..addSelectChoice(
          SelectChoice(null, 'loc: choice2', 'val2', isLocalizable: false),
        );
      expect(
        fep.selectChoices.toString(),
        '[{choice1 id} => val1, loc: choice2 => val2]',
      );
      // clean up
      q
        ..removeSelectChoice(q.choices![0])
        ..removeSelectChoice(q.choices![0]);
    });

    test('select choices without localizer', () {
      final q = fpi.firstQuestionDef!;
      expect(q.numChoices, 0, reason: 'Select choices not empty on init');

      const onetext = 'choice';
      const twotext = "stacey's";
      final one = SelectChoice(null, onetext, 'val', isLocalizable: false);
      q.addSelectChoice(one);
      final two = SelectChoice(null, twotext, 'mom', isLocalizable: false);
      q.addSelectChoice(two);

      expect(fep.selectChoices.toString(), "[choice => val, stacey's => mom]");
      expect(fep.selectChoiceText(one), onetext);
      expect(fep.selectChoiceText(two), twotext);
      expect(
        fep.specialFormSelectChoiceText(one, FormEntryCaption.textFormImage),
        isNull,
        reason: 'Form Entry Caption incorrectly contains Image Text',
      );
      expect(
        fep.specialFormSelectChoiceText(one, FormEntryCaption.textFormAudio),
        isNull,
        reason: 'Form Entry Caption incorrectly contains Audio Text',
      );

      q
        ..removeSelectChoice(q.choiceAt(0))
        ..removeSelectChoice(q.choiceAt(0));
    });

    test('prompts with localizer', () async {
      final l = Localizer();
      final table = TableLocaleSource();
      l
        ..addAvailableLocale('locale')
        ..defaultLocale = 'locale';
      table
        ..setLocaleMapping('prompt;long', 'loc: long text')
        ..setLocaleMapping('prompt;short', 'loc: short text')
        ..setLocaleMapping('help', 'loc: help text');
      l
        ..registerLocaleResource('locale', table)
        ..locale = 'locale';

      // DartRosa's prompt needs a form: host the question in a minimal one.
      final scenario = await Scenario.init(
        html(
          head([
            title('Dummy'),
            model([
              mainInstance([
                t('data id="dummy"', [t('q')]),
              ]),
            ]),
          ]),
          body([input('/data/q')]),
        ),
      );
      scenario.next();
      (scenario.formDef.childAt(0)! as QuestionDef).helpTextId = 'help';
      final fep = DummyFormEntryPrompt(
        scenario.formDef,
        scenario.currentIndex,
        l,
        'prompt',
      );

      expect(fep.longText, 'loc: long text');
      expect(fep.shortText, 'loc: short text');
    });

    test('prompt ids without localizer', () {
      final q = QuestionDef()..textId = 'long text id';
      expect(q.textId, 'long text id');
      q.helpTextId = 'help text id';
      expect(q.helpTextId, 'help text id');
      expect(q.helpText, isNull);
    });

    test('prompts without localizer', () {
      final q = QuestionDef()..labelInnerText = 'labelInnerText';
      expect(q.labelInnerText, 'labelInnerText');
      q.helpText = 'help text';
      expect(q.helpText, 'help text');
    });
  });
}
