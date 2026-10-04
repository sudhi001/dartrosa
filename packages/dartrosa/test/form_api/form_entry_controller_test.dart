// DartRosa tests (not ports) of FormEntryController operations JavaRosa's
// FormEntryControllerTest doesn't cover: saveAnswer (no checks), answering
// at the current index, finalization processors, and registering function
// handlers and filter strategies through the controller. Expected
// behaviour follows JavaRosa 6.0.0's FormEntryController source.
import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/src/model/condition/evaluation_context.dart';
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/model/instance/data_instance.dart';
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:dartrosa/src/xpath/expression.dart';
import 'package:test/test.dart';

const form = '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
<h:head><h:title>Controller</h:title><model>
<instance><data id="controller"><age/><g><x/></g><item>a</item><item>b</item><item>a</item><shout/><count/></data></instance>
<bind nodeset="/data/age" type="int" required="true()" constraint=". &lt; 150"/>
<bind nodeset="/data/shout" calculate="shout('hi')"/>
<bind nodeset="/data/count" calculate="count(/data/item[. = 'a'])"/>
</model></h:head>
<h:body>
<input ref="/data/age"><label>Age</label></input>
<group ref="/data/g"><label>G</label><input ref="/data/g/x"><label>X</label></input></group>
</h:body></h:html>
''';

final class Shout extends XPathFunctionHandler {
  @override
  String get name => 'shout';

  @override
  List<List<XPathArgType>> get prototypes => [
    [XPathArgType.string],
  ];

  @override
  Object eval(List<Object> args, EvaluationContext context) =>
      '${args.single}!'.toUpperCase();
}

final class RecordingFilter implements FilterStrategy {
  final predicates = <String>[];

  @override
  List<TreeReference> filter(
    DataInstance sourceInstance,
    TreeReference nodeset,
    XPathExpression predicate,
    List<TreeReference> children,
    EvaluationContext context,
    List<TreeReference> Function() next,
  ) {
    predicates.add('$nodeset');
    return next();
  }
}

final class RecordingProcessor implements FormEntryFinalizationProcessor {
  final seen = <String?>[];

  @override
  void processForm(FormEntryModel model) => seen.add(model.formTitle);
}

void main() {
  late FormDef formDef;
  late FormEntryController controller;

  setUp(() async {
    formDef = await XFormParser().parse(form);
    controller = FormEntryController(FormEntryModel(formDef));
  });

  String? valueOf(String name) =>
      formDef.mainInstance.root.getChild(name, 0)!.value?.displayText;

  test('function handlers and filter strategies added to the form', () {
    final filter = RecordingFilter();
    controller
      ..addFunctionHandler(Shout())
      ..addFilterStrategy(filter);
    formDef.initialize(newInstance: true);
    expect(valueOf('shout'), 'HI!');
    expect(valueOf('count'), '2');
    // As in JavaRosa, custom strategies only see first predicates on
    // nodesets with no bound multiplicity below the top level.
    expect(filter.predicates, contains('/data/item'));
  });

  group('answers', () {
    setUp(() {
      controller.addFunctionHandler(Shout());
      formDef.initialize(newInstance: true);
      controller.stepToNextEvent();
    });

    test('answerQuestion checks the current question', () {
      expect(controller.answerQuestion(null), AnswerStatus.requiredButEmpty);
      expect(
        controller.answerQuestion(const IntegerValue(200)),
        AnswerStatus.constraintViolated,
      );
      expect(
        controller.answerQuestion(const IntegerValue(20)),
        AnswerStatus.ok,
      );
      expect(valueOf('age'), '20');
    });

    test('saveAnswer stores without checks', () {
      // Nothing to clear: nothing is saved.
      expect(controller.saveAnswer(null), isFalse);
      expect(controller.saveAnswer(const IntegerValue(200)), isTrue);
      expect(valueOf('age'), '200');
      expect(controller.saveAnswer(null), isTrue);
      expect(valueOf('age'), isNull);
      expect(
        formDef.validate().toString(),
        'ValidateOutcome(0, , AnswerStatus.requiredButEmpty)',
      );
    });

    test('saveAnswer refuses non-questions', () {
      controller.stepToNextEvent();
      expect(controller.model.event(), FormEntryEvent.group);
      expect(
        () => controller.saveAnswer(const StringValue('x')),
        throwsStateError,
      );
    });
  });

  test('finalization runs the processors after post-processing', () {
    controller.addFunctionHandler(Shout());
    formDef.initialize(newInstance: true);
    final processor = RecordingProcessor();
    controller
      ..addPostProcessor(processor)
      ..finalizeFormEntry();
    expect(processor.seen, ['Controller']);
  });
}
