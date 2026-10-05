// The code of docs/MIGRATING_FROM_JAVAROSA.md, run as tests so the guide
// can't rot (doc_snippets.dart checks that its snippets are here).
@TestOn('vm')
library;

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:test/test.dart';

import 'doc_snippets.dart';

const xml = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Migrating</h:title>
    <model>
      <instance><data id="m"><n/><twice/></data></instance>
      <bind nodeset="/data/n" type="int" constraint=". &lt; 3"
          jr:constraintMsg="Too big"/>
      <bind nodeset="/data/twice" type="string" calculate="twice(/data/n)"/>
    </model>
  </h:head>
  <h:body><input ref="/data/n"><label>N</label></input></h:body>
</h:html>
''';

// A custom XPath function: twice(x).
final class MyFunction extends XPathFunctionHandler {
  @override
  String get name => 'twice';

  @override
  List<List<XPathArgType>> get prototypes => [
    [XPathArgType.number],
  ];

  @override
  Object eval(List<Object> args, EvaluationContext context) =>
      (args.single as double) * 2;
}

void main() {
  expectSnippetsTested('docs/MIGRATING_FROM_JAVAROSA.md');

  test('session API', () async {
    final messages = <String?>[];
    final definition = await FormDefinition.parse(
      xml,
      config: DartRosaConfig(functions: [MyFunction()]),
    );
    final session = definition.createSession(); // initializes the instance
    final nav = session.navigator;
    while (nav.next() != FormEntryEvent.endOfForm) {
      if (nav.current case final QuestionNode q) {
        switch (session.answer(q.index, const IntegerValue(5))) {
          case AnswerConstraintViolated(:final message):
            messages.add(message);
          case AnswerAccepted() || AnswerRequired() || AnswerRejected():
            break;
        }
      }
    }
    expect(messages, ['Too big']);
  });

  test('JavaRosa-compatible API', () async {
    final messages = <String?>[];
    final form = await XFormParser().parse(xml);
    form.addFunctionHandler(MyFunction());
    final fec = FormEntryController(FormEntryModel(form));
    form.initialize(newInstance: true);
    while (fec.stepToNextEvent() != FormEntryEvent.endOfForm) {
      if (fec.model.event() == FormEntryEvent.question) {
        final status = fec.answerQuestion(
          const IntegerValue(5),
          midSurvey: true,
        );
        if (status == AnswerStatus.constraintViolated) {
          messages.add(fec.model.questionPrompt().constraintText());
        }
      }
    }
    expect(messages, ['Too big']);
  });
}
