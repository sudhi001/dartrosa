// DartRosa's session facade (FormDefinition / FormSession / FormNavigator).
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

String formXml() => html(
  head([
    title('Session'),
    model([
      mainInstance([
        t('data id="session"', [
          t('age'),
          t('adult'),
          t('name'),
          t('child', [t('cname')]),
        ]),
      ]),
      bind('/data/age')
        ..type('int')
        ..required()
        ..constraint('. >= 0'),
      bind('/data/adult')
        ..type('string')
        ..calculate("if(/data/age >= 18, 'yes', 'no')"),
      bind('/data/name')
        ..type('string')
        ..relevant("/data/adult = 'yes'"),
      bind('/data/child/cname')..type('string'),
    ]),
  ]),
  body([
    input('/data/age', [tText('label', 'Age')]),
    input('/data/name', [tText('label', 'Name')]),
    repeat('/data/child', [
      input('/data/child/cname', [tText('label', 'Child name')]),
    ]),
  ]),
).asXml();

void main() {
  late FormSession session;
  setUp(() async {
    final definition = await FormDefinition.parse(formXml());
    expect(definition.title, 'Session');
    session = definition.createSession();
  });

  test('tree of nodes', () {
    final children = session.root.children;
    expect(children.map((n) => n.runtimeType), [
      QuestionNode,
      QuestionNode,
      RepeatNode,
    ]);
    final age = children[0] as QuestionNode;
    expect(age.label.text, 'Age');
    expect(age.isRequired, isTrue);
    expect(age.dataType, DataType.integer);
    expect(children[1].isRelevant, isFalse);
    expect(session.root.visibleChildren, hasLength(2));
    // The repeat's element in the instance (no jr:template) is also its
    // first instance, as in JavaRosa.
    expect((children[2] as RepeatNode).instances, hasLength(1));
  });

  test('answers recalculate and report changes', () {
    final changes = <FormChange>[];
    session.changes.listen(changes.add);
    final age = session.root.children[0];
    expect(
      session.answer(age.index, const IntegerValue(30)),
      isA<AnswerAccepted>(),
    );
    expect(session.root.children[1].isRelevant, isTrue);
    expect(
      changes.expand((c) => c.refs).map((r) => '$r'),
      containsAll(['/data/adult[1]', '/data/name[1]']),
    );
    expect(
      session.answer(age.index, const IntegerValue(-1)),
      isA<AnswerConstraintViolated>(),
    );
    expect(session.answer(age.index, null), isA<AnswerRequired>());
  });

  test('repeats', () {
    final repeat = session.root.children[2] as RepeatNode;
    expect(repeat.canAddInstance, isTrue);
    final second = session.addRepeatInstance(repeat.index);
    session.addRepeatInstance(repeat.index);
    final instances = (session.root.children[2] as RepeatNode).instances;
    expect(instances.map((i) => i.position), [0, 1, 2]);
    final cname = instances[2].children.single as QuestionNode;
    session.answer(cname.index, const StringValue('Ann'));
    expect(cname.value, isA<StringValue>());
    session.removeRepeatInstance(second);
    final remaining = (session.root.children[2] as RepeatNode).instances;
    expect(remaining, hasLength(2));
    expect(
      (remaining[1].children.single as QuestionNode).value?.displayText,
      'Ann',
    );
  });

  test('navigator follows JavaRosa navigation', () {
    final nav = session.navigator;
    expect(nav.next(), FormEntryEvent.question);
    expect((nav.current as QuestionNode).label.text, 'Age');
    expect(nav.next(), FormEntryEvent.repeat);
    expect(nav.next(), FormEntryEvent.question);
    expect(nav.current.ref.toString(), '/data/child[1]/cname[1]');
    expect(nav.next(), FormEntryEvent.promptNewRepeat);
    nav.addRepeatAndEnter();
    expect(nav.event, FormEntryEvent.repeat);
    expect(nav.current.ref.toString(), '/data/child[2]');
    expect(nav.next(), FormEntryEvent.question);
    expect(nav.next(), FormEntryEvent.promptNewRepeat);
    expect(nav.next(), FormEntryEvent.endOfForm);
    expect(nav.previous(), FormEntryEvent.promptNewRepeat);
  });

  test('finalize validates first', () {
    final result = session.finalize();
    expect(result, isA<FinalizeFailure>());
    final failure = (result as FinalizeFailure).failure;
    expect(failure.result, isA<AnswerRequired>());
    expect(failure.index.reference.toString(), '/data/age[1]');
    session.answer(session.root.children[0].index, const IntegerValue(3));
    expect(session.finalize(), isA<FinalizeSuccess>());
  });

  test('createSession starts from a blank instance', () async {
    session.answer(session.root.children[0].index, const IntegerValue(3));
    final definition = session.definition;
    final again = definition.createSession();
    expect((again.root.children[0] as QuestionNode).value, isNull);
  });
}
