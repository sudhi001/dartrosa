// DartRosa tests (not ports) of FormElement / QuestionDef / GroupDef
// details: the `;form` suffix stripped from text ids, attaching selections
// to static choices (Selection.attachChoice), removing choices, and the
// contextualized jr:count reference. Expected behaviour follows JavaRosa
// 6.0.0's IFormElement, QuestionDef, GroupDef and Selection sources.
import 'package:dartrosa/src/model/control_type.dart';
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/form_element.dart';
import 'package:dartrosa/src/model/select_choice.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:dartrosa/src/xpath/exceptions.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

QuestionDef selectWithChoices() =>
    QuestionDef(controlType: ControlType.selectOne)
      ..textId = 'color'
      ..addSelectChoice(SelectChoice(null, 'Red', 'r', isLocalizable: false))
      ..addSelectChoice(SelectChoice(null, 'Blue', 'b', isLocalizable: false));

void main() {
  test('a text id loses its form suffix', () {
    final question = QuestionDef()..textId = 'q1;short';
    expect(question.textId, 'q1');
    question.textId = 'plain';
    expect(question.textId, 'plain');
  });

  test('selections attach by index, else by value', () {
    final question = selectWithChoices();
    expect(
      question.attachChoice(const Selection.atIndex(1)).choice!.value,
      'b',
    );
    expect(
      question.attachChoice(const Selection('r')).choice!.labelInnerText,
      'Red',
    );
    expect(question.choiceForValue('x'), isNull);
  });

  test('selections without a matching choice fail', () {
    expect(
      () => selectWithChoices().attachChoice(const Selection('x')),
      throwsA(
        isA<XPathTypeMismatchException>().having(
          (e) => '$e',
          'message',
          contains(
            'value x could not be loaded into question color.  Check to see '
            'if value x is a valid option for question color.',
          ),
        ),
      ),
    );
    // An out-of-range index without a value can't be attached either.
    expect(
      () => selectWithChoices().attachChoice(const Selection.atIndex(5)),
      throwsA(isA<XPathTypeMismatchException>()),
    );
  });

  test('removing choices', () {
    final question = selectWithChoices();
    final red = question.choiceAt(0);
    question.removeSelectChoice(red);
    expect(question.numChoices, 1);
    // A question without choices just resets the choice's index.
    final orphan = SelectChoice(null, 'X', 'x', isLocalizable: false)
      ..index = 3;
    QuestionDef().removeSelectChoice(orphan);
    expect(orphan.index, 0);
  });

  test('jr:count references are contextualized', () async {
    final form = await XFormParser().parse(
      html(
        head([
          title('Count'),
          model([
            mainInstance([
              t('data id="count"', [
                t('outer jr:template=""', [
                  t('n'),
                  t('r jr:template=""', [t('a')]),
                ]),
              ]),
            ]),
          ]),
        ]),
        body([
          repeat('/data/outer', [
            input('/data/outer/n'),
            t('repeat nodeset="/data/outer/r" jr:count="../n"', [
              input('/data/outer/r/a'),
            ]),
          ]),
        ]),
      ).asXml(),
    );
    final outer = form.children.single as GroupDef;
    final inner = outer.children[1] as GroupDef;
    // As in JavaRosa (checked with jshell), the relative jr:count is made
    // absolute against the parent group at parse time (the `..` leaves
    // the repeat's parent), so there is nothing left to contextualize.
    expect(
      '${inner.contextualizedCountReference(getRef('/data/outer[2]/r'))}',
      '/data/n',
    );
    expect(outer.contextualizedCountReference(getRef('/data/outer')), isNull);
  });
}
