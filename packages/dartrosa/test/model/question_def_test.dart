// Port of JavaRosa v6.0.0 QuestionDefTest and the QuestionDef parts of
// TextFormTests. Tests going through FormEntryPrompt (localized long/short
// texts, media references) are ported with the form-entry API (P4);
// serialization round trips with the codec (P6).
import 'package:dartrosa/src/model/control_type.dart';
import 'package:dartrosa/src/model/form_element.dart';
import 'package:dartrosa/src/model/select_choice.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

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

    test('references', () {}, skip: 'needs FormEntryPrompt (P4)');
  });

  group('TextFormTests', () {
    test('text forms', () {}, skip: 'needs FormEntryPrompt (P4)');
    test('non-localized text', () {}, skip: 'needs FormEntryPrompt (P4)');
    test('prompts with localizer', () {}, skip: 'needs FormEntryPrompt (P4)');

    test('select choice ids without localizer', () {
      final q = QuestionDef()
        ..addSelectChoice(SelectChoice.localized('choice1 id', 'val1'))
        ..addSelectChoice(
          SelectChoice(null, 'loc: choice2', 'val2', isLocalizable: false),
        );
      expect(
        q.choices.toString(),
        '[{choice1 id} => val1, loc: choice2 => val2]',
      );
      q
        ..removeSelectChoice(q.choiceAt(0))
        ..removeSelectChoice(q.choiceAt(0));
      expect(q.numChoices, 0);
    });

    test('select choices without localizer', () {
      final q = QuestionDef();
      expect(q.numChoices, 0);
      final one = SelectChoice(null, 'choice', 'val', isLocalizable: false);
      final two = SelectChoice(null, "stacey's", 'mom', isLocalizable: false);
      q
        ..addSelectChoice(one)
        ..addSelectChoice(two);
      expect(q.choices.toString(), "[choice => val, stacey's => mom]");
      expect(one.labelInnerText, 'choice');
      expect(two.labelInnerText, "stacey's");
      expect(one.textId, isNull);
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
