// Port of JavaRosa v6.0.0 TriggerableDagTest.
import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/src/model/triggerable_dag.dart';
import 'package:dartrosa/src/xform/xform_parse_exception.dart';
import 'package:dartrosa/src/xpath/conversions.dart' show getRefValue;
import 'package:dartrosa/src/xpath/expression.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/matchers.dart';

const _cycleMessage =
    "Cycle detected in form's relevant and calculation logic!";

/// JavaRosa's `exceptionRule.expect(XFormParseException.class)` plus
/// `expectMessage(...)` (a substring match).
Future<void> _expectCycleError(Future<Scenario> init) => expectLater(
  init,
  throwsA(
    isA<XFormParseException>().having(
      (e) => e.message,
      'message',
      contains(_cycleMessage),
    ),
  ),
);

void _assertDagEvents(List<EvaluationEvent> dagEvents, List<String> lines) {
  expect(dagEvents.map((e) => e.displayMessage).join('\n'), lines.join('\n'));
}

XFormsElement _buildFormForDagCyclesCheck(
  List<BindBuilderXFormsElement> binds, [
  String? initialValue,
]) {
  // Map the last part of each bind's nodeset to model fields. They will get
  // an initial value if provided.
  final modelFields = [
    for (final b in binds)
      if (initialValue == null)
        t(b.nodeset.split('/').last)
      else
        tText(b.nodeset.split('/').last, initialValue),
  ];
  return html(
    head([
      title('Some form'),
      model([
        mainInstance([t('data id="some-form"', modelFields)]),
        ...binds,
      ]),
    ]),
    body([for (final b in binds) input(b.nodeset)]),
  );
}

void main() {
  final dagEvents = <EvaluationEvent>[];

  setUp(dagEvents.clear);

  test('order_of_the_DAG_is_ensured', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [tText('a', '2'), t('b'), t('c')]),
            ]),
            bind('/data/a')..type('int'),
            bind('/data/b')
              ..type('int')
              ..calculate('/data/a * 3'),
            bind('/data/c')
              ..type('int')
              ..calculate('(/data/a + /data/b) * 5'),
          ]),
        ]),
        body([input('/data/a')]),
      ),
    );

    expect(scenario.answerOf('/data/a'), intAnswer(2));
    expect(scenario.answerOf('/data/b'), intAnswer(6));
    expect(scenario.answerOf('/data/c'), intAnswer(40));

    scenario.answer('/data/a', 3);

    expect(scenario.answerOf('/data/a'), intAnswer(3));
    expect(scenario.answerOf('/data/b'), intAnswer(9));
    // Verify that c gets computed using the updated value of b.
    expect(scenario.answerOf('/data/c'), intAnswer(60));
  });

  //region Cycles
  test(
    'parsing_forms_with_cycles_by_self_reference_in_calculate_should_fail',
    () async {
      await _expectCycleError(
        Scenario.init(
          _buildFormForDagCyclesCheck([
            bind('/data/count')
              ..type('int')
              ..calculate('. + 1'),
          ]),
        ),
      );
    },
  );

  test('parsing_forms_with_cycles_in_calculate_should_fail', () async {
    await _expectCycleError(
      Scenario.init(
        _buildFormForDagCyclesCheck([
          bind('/data/a')
            ..type('int')
            ..calculate('/data/b + 1'),
          bind('/data/b')
            ..type('int')
            ..calculate('/data/c + 1'),
          bind('/data/c')
            ..type('int')
            ..calculate('/data/a + 1'),
        ]),
      ),
    );
  });

  test(
    'parsing_forms_with_cycles_by_self_reference_in_relevance_should_fail',
    () async {
      await _expectCycleError(
        Scenario.init(
          _buildFormForDagCyclesCheck([
            bind('/data/count')
              ..type('int')
              ..relevant('. > 0'),
          ]),
        ),
      );
    },
  );

  test('parsing_forms_with_cycles_by_self_reference_in_read_only_condition_'
      'should_fail', () async {
    await _expectCycleError(
      Scenario.init(
        _buildFormForDagCyclesCheck([
          bind('/data/count')
            ..type('int')
            ..readonly('. > 10'),
        ]),
      ),
    );
  });

  test('parsing_forms_with_cycles_by_self_reference_in_required_condition_'
      'should_fail', () async {
    await _expectCycleError(
      Scenario.init(
        _buildFormForDagCyclesCheck([
          bind('/data/count')
            ..type('int')
            ..required('. > 10'),
        ]),
      ),
    );
  });

  test('supports_self_references_in_constraints', () async {
    final scenario = await Scenario.init(
      _buildFormForDagCyclesCheck([
        bind('/data/count')
          ..type('int')
          ..constraint('. > 10'),
      ]),
    );
    scenario
      ..next()
      ..answerCurrent(5);
    expect(scenario.answerOf('/data/count'), isNull);
    scenario.answerCurrent(20);
    expect(scenario.answerOf('/data/count'), intAnswer(20));
    scenario.answerCurrent(5);
    expect(scenario.answerOf('/data/count'), intAnswer(20));
  });

  // This test represents a use case that might seem like it has a cycle,
  // but it doesn't: the relevance conditions are co-dependent on the
  // fields' values, not on their relevance. Ignored in JavaRosa because the
  // implementation incorrectly detects a cycle.
  test('supports_codependant_relevant_expressions', () async {
    await Scenario.init(
      _buildFormForDagCyclesCheck([
        bind('/data/a')
          ..type('int')
          ..relevant('/data/b > 0'),
        bind('/data/b')
          ..type('int')
          ..relevant('/data/a > 0'),
      ]),
    );
    // TODO(javarosa): Complete the test adding some assertions that verify
    // that the form works as we would expect.
  }, skip: '@Ignore in JavaRosa (a cycle is incorrectly detected)');

  // Same as above for required conditions.
  test('supports_codependant_required_conditions', () async {
    await Scenario.init(
      _buildFormForDagCyclesCheck([
        bind('/data/a')
          ..type('int')
          ..required('/data/b > 0'),
        bind('/data/b')
          ..type('int')
          ..required('/data/a > 0'),
      ]),
    );
    // TODO(javarosa): Complete the test adding some assertions that verify
    // that the form works as we would expect.
  }, skip: '@Ignore in JavaRosa (a cycle is incorrectly detected)');

  // Same as above for readonly conditions.
  test('supports_codependant_readonly_conditions', () async {
    await Scenario.init(
      _buildFormForDagCyclesCheck([
        bind('/data/a')
          ..type('int')
          ..readonly('/data/b > 0'),
        bind('/data/b')
          ..type('int')
          ..readonly('/data/a > 0'),
      ]),
    );
    // TODO(javarosa): Complete the test adding some assertions that verify
    // that the form works as we would expect.
  }, skip: '@Ignore in JavaRosa (a cycle is incorrectly detected)');

  test(
    'parsing_forms_with_cycles_involving_fields_inside_and_outside_of_repeat_'
    'groups_should_fail',
    () async {
      await _expectCycleError(
        Scenario.init(
          html(
            head([
              title('Some form'),
              model([
                mainInstance([
                  t('data id="some-form"', [
                    t('group', [tText('a', '1')]),
                    tText('b', '1'),
                  ]),
                ]),
                bind('/data/group/a')
                  ..type('int')
                  ..calculate('/data/b + 1'),
                bind('/data/b')
                  ..type('int')
                  ..calculate('/data/group[position() = 1]/a + 1'),
              ]),
            ]),
            body([
              formGroup('/data/group', [
                repeat('/data/group', [input('/data/group/a')]),
              ]),
              input('/data/b'),
            ]),
          ),
        ),
      );
    },
  );

  test('parsing_forms_with_self_reference_cycles_in_fields_of_repeat_groups_'
      'should_fail', () async {
    await _expectCycleError(
      Scenario.init(
        html(
          head([
            title('Some form'),
            model([
              mainInstance([
                t('data id="some-form"', [
                  t('group', [tText('a', '1')]),
                ]),
              ]),
              bind('/data/group/a')
                ..type('int')
                ..calculate('../a + 1'),
            ]),
          ]),
          body([
            formGroup('/data/group', [
              repeat('/data/group', [input('/data/group/a')]),
            ]),
          ]),
        ),
      ),
    );
  });

  // The form fails to parse because a self-reference cycle is detected in
  // /data/group/a, which is incorrect: it depends on the same field of the
  // previous repeat instance (an auto-increment, not a cycle).
  test('supports_self_reference_dependency_when_targeting_different_repeat_'
      'instance_siblings', () async {
    await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('group', [tText('a', '1')]),
              ]),
            ]),
            bind('/data/group/a')
              ..type('int')
              ..calculate(
                '/data/group[position() = (position(current()) - 1)]/a + 1',
              ),
          ]),
        ]),
        body([
          formGroup('/data/group', [
            repeat('/data/group', [input('/data/group/a')]),
          ]),
        ]),
      ),
    );
  }, skip: '@Ignore in JavaRosa (a cycle is incorrectly detected)');

  test('parsing_forms_with_cycles_between_fields_of_the_same_repeat_instance_'
      'should_fail', () async {
    await _expectCycleError(
      Scenario.init(
        html(
          head([
            title('Some form'),
            model([
              mainInstance([
                t('data id="some-form"', [
                  t('group', [tText('a', '1'), tText('b', '1')]),
                ]),
              ]),
              bind('/data/group/a')
                ..type('int')
                ..calculate('../b + 1'),
              bind('/data/group/b')
                ..type('int')
                ..calculate('../a + 1'),
            ]),
          ]),
          body([
            formGroup('/data/group', [
              repeat('/data/group', [
                input('/data/group/a'),
                input('/data/group/b'),
              ]),
            ]),
          ]),
        ),
      ),
    );
  });
  //endregion

  //region Relevance
  // Non-relevance is inherited from ancestor nodes, as per the W3C XForms
  // specs.
  test('non_relevance_is_inherited_from_ancestors', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('is-group-relevant'),
                t('is-field-relevant'),
                t('group', [t('field')]),
              ]),
            ]),
            bind('/data/is-group-relevant')..type('boolean'),
            bind('/data/is-field-relevant')..type('boolean'),
            bind('/data/group')..relevant('/data/is-group-relevant'),
            bind('/data/group/field')
              ..type('string')
              ..relevant('/data/is-field-relevant'),
          ]),
        ]),
        body([
          input('/data/is-group-relevant'),
          input('/data/is-field-relevant'),
          formGroup('/data/group', [input('/data/group/field')]),
        ]),
      ),
    );

    // Form initialization evaluates all triggerables, which makes the group
    // and field non-relevants because their relevance expressions are not
    // satisfied
    expect(scenario.getAnswerNode('/data/group'), nonRelevant);
    expect(scenario.getAnswerNode('/data/group/field'), nonRelevant);

    // Now we make both relevant
    scenario
      ..answer('/data/is-group-relevant', true)
      ..answer('/data/is-field-relevant', true);
    expect(scenario.getAnswerNode('/data/group'), relevant);
    expect(scenario.getAnswerNode('/data/group/field'), relevant);

    // Now we make the group non-relevant, which makes the field
    // non-relevant regardless of its local relevance expression, which
    // would be satisfied in this case
    scenario.answer('/data/is-group-relevant', false);
    expect(scenario.getAnswerNode('/data/group'), nonRelevant);
    expect(scenario.getAnswerNode('/data/group/field'), nonRelevant);
  });

  // Nodes can be nested differently in the model and body. The model
  // structure is used to determine relevance inheritance.
  test('relevanceIsDeterminedByModelNesting', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('outernode'),
                t('group', [t('innernode')]),
              ]),
            ]),
            bind('/data/group')..relevant('false()'),
          ]),
        ]),
        body([
          formGroup('/data/group', [
            input('/data/outernode'),
            input('/data/group/innernode'),
          ]),
        ]),
      ),
    );

    expect(scenario.getAnswerNode('/data/group'), nonRelevant);
    expect(scenario.getAnswerNode('/data/outernode'), relevant);
    expect(scenario.getAnswerNode('/data/group/innernode'), nonRelevant);
  });

  test('non_relevant_nodes_are_excluded_from_nodeset_evaluation', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                // position() is one-based
                t('node', [tText('value', '1')]), // non-relevant
                t('node', [tText('value', '2')]), // non-relevant
                t('node', [tText('value', '3')]), // relevant
                t('node', [tText('value', '4')]), // relevant
                t('node', [tText('value', '5')]), // relevant
              ]),
            ]),
            bind('/data/node')..relevant('position() > 2'),
            bind('/data/node/value')..type('int'),
          ]),
        ]),
        body([
          formGroup('/data/node', [input('/data/node/value')]),
        ]),
      ),
    );

    // XPathPathExprEval is used when evaluating the nodesets that the xpath
    // functions declared in triggerable expressions need to operate upon.
    // This assertion shows that non-relevant nodes are not included in the
    // resulting nodesets. (DartRosa folds XPathPathExprEval into
    // XPathPathExpr.eval.)
    expect(
      XPathPathExpr.fromRef(getRef('/data/node'))
          .eval(scenario.formDef.mainInstance, scenario.evaluationContext)
          .references,
      hasLength(3),
    );

    // XPathPathExpr.getRefValue is what ultimately is used by triggerable
    // expressions to extract the values they need to operate upon. The
    // following assertion shows how extracting values from non-relevant
    // nodes returns empty values instead of the actual values they're
    // holding
    expect(
      getRefValue(
        scenario.formDef.mainInstance,
        scenario.evaluationContext,
        scenario.expandSingle(getRef('/data/node[2]/value')),
      ),
      '',
    );
    // ... as opposed to the value that we can get by resolving the same
    // reference with the main instance, which has the expected `2` value
    expect(scenario.answerOf('/data/node[2]/value'), intAnswer(2));
  });

  test(
    'non_relevant_node_values_are_always_null_regardless_of_their_actual_value',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Some form'),
            model([
              mainInstance([
                t('data id="some-form"', [
                  tText('relevance-trigger', '1'),
                  t('result'),
                  tText('some-field', '42'),
                ]),
              ]),
              bind('/data/relevance-trigger')..type('boolean'),
              bind('/data/result')
                ..type('int')
                ..calculate(
                  "if(/data/some-field != '', /data/some-field + 33, 33)",
                ),
              bind('/data/some-field')
                ..type('int')
                ..relevant('/data/relevance-trigger'),
            ]),
          ]),
          body([input('/data/relevance-trigger')]),
        ),
      );

      expect(scenario.answerOf('/data/result'), intAnswer(75));
      expect(scenario.answerOf('/data/some-field'), intAnswer(42));

      scenario.answer('/data/relevance-trigger', false);

      // This shows how JavaRosa will ignore the actual values of
      // non-relevant fields. The W3C XForm specs regard relevance a purely
      // UI concern. No side effects on node values are described in the
      // specs, which implies that a relevance change wouldn't have any
      // consequence on a node's value. This means that /data/result should
      // keep having a 75 after making /data/some-field non-relevant.
      expect(scenario.answerOf('/data/result'), intAnswer(33));
      expect(scenario.answerOf('/data/some-field'), intAnswer(42));
    },
  );

  // Inspired by https://code.google.com/archive/p/opendatakit/issues/888.
  // We focus on the relationship between relevance and other calculations
  // because relevance can be defined for fields **and groups**, which is a
  // special case of expression evaluation in our DAG.
  test(
    'verify_relation_between_calculate_expressions_and_relevancy_conditions',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Some form'),
            model([
              mainInstance([
                t('data id="some-form"', [
                  t('number1'),
                  t('continue'),
                  t('group', [
                    t('number1_x2'),
                    t('number1_x2_x2'),
                    t('number2'),
                  ]),
                ]),
              ]),
              bind('/data/number1')
                ..type('int')
                ..constraint('. > 0')
                ..required(),
              bind('/data/continue')
                ..type('string')
                ..required(),
              bind('/data/group')..relevant("/data/continue = '1'"),
              bind('/data/group/number1_x2')
                ..type('int')
                ..calculate('/data/number1 * 2'),
              bind('/data/group/number1_x2_x2')
                ..type('int')
                ..calculate('/data/group/number1_x2 * 2'),
              bind('/data/group/number2')
                ..type('int')
                ..relevant('/data/group/number1_x2 > 0')
                ..required(),
            ]),
          ]),
          body([
            input('/data/number1'),
            select1('/data/continue', [item(1, 'Yes'), item(0, 'No')]),
            formGroup('/data/group', [input('/data/group/number2')]),
          ]),
        ),
      );
      scenario
        ..next()
        ..answerCurrent(2);
      expect(scenario.answerOf('/data/group/number1_x2'), intAnswer(4));
      // The expected value is null because the calculate expression uses a
      // non-relevant field. Values of non-relevant fields are always null.
      expect(scenario.answerOf('/data/group/number1_x2_x2'), isNull);
      scenario
        ..next()
        ..answerCurrent('1'); // Label: "yes"
      expect(scenario.answerOf('/data/group/number1_x2'), intAnswer(4));
      expect(scenario.answerOf('/data/group/number1_x2_x2'), intAnswer(8));
    },
  );

  // Identical expressions in a form get collapsed to a single Triggerable
  // and the Triggerable's context becomes its targets' highest common
  // parent (see Triggerable.intersectContextWith). This test shows that
  // relevance is propagated as expected when a relevance expression is
  // shared between a repeat and non-repeat. See
  // https://github.com/getodk/javarosa/issues/603.
  test('whenRepeatAndTopLevelNodeHaveSameRelevanceExpression_'
      'andExpressionEvaluatesToFalse_repeatPromptIsSkipped', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Repeat relevance same as other'),
          model([
            mainInstance([
              t('data id="repeat_relevance_same_as_other"', [
                tText('selectYesNo', 'no'),
                t('repeat1', [t('q1')]),
                t('q0'),
              ]),
            ]),
            bind('/data/q0')..relevant("/data/selectYesNo = 'yes'"),
            bind('/data/repeat1')..relevant("/data/selectYesNo = 'yes'"),
          ]),
        ]),
        body([
          select1('/data/selectYesNo', [item('yes', 'Yes'), item('no', 'No')]),
          repeat('/data/repeat1', [input('/data/repeat1/q1')]),
        ]),
      ),
    );

    scenario
      ..jumpToBeginningOfForm()
      ..next();
    final event = scenario.next();

    expect(event, FormEntryEvent.endOfForm);
  });
  //endregion

  //region Read-only
  // Read-only is inherited from ancestor nodes, as per the W3C XForms specs.
  test('readonly_is_inherited_from_ancestors', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('is-outer-readonly'),
                t('is-inner-readonly'),
                t('is-field-readonly'),
                t('outer', [
                  t('inner', [t('field')]),
                ]),
              ]),
            ]),
            bind('/data/is-outer-readonly')..type('boolean'),
            bind('/data/is-inner-readonly')..type('boolean'),
            bind('/data/is-field-readonly')..type('boolean'),
            bind('/data/outer')..readonly('/data/is-outer-readonly'),
            bind('/data/outer/inner')..readonly('/data/is-inner-readonly'),
            bind('/data/outer/inner/field')
              ..type('string')
              ..readonly('/data/is-field-readonly'),
          ]),
        ]),
        body([
          input('/data/is-outer-readonly'),
          input('/data/is-inner-readonly'),
          input('/data/is-field-readonly'),
          formGroup('/data/outer', [
            formGroup('/data/outer/inner', [input('/data/outer/inner/field')]),
          ]),
        ]),
      ),
    );

    // Form initialization evaluates all triggerables, which makes the field
    // editable (not read-only)
    expect(scenario.getAnswerNode('/data/outer'), enabled);
    expect(scenario.getAnswerNode('/data/outer/inner'), enabled);
    expect(scenario.getAnswerNode('/data/outer/inner/field'), enabled);

    // Make the outer group read-only
    scenario.answer('/data/is-outer-readonly', true);
    expect(scenario.getAnswerNode('/data/outer'), readOnly);
    expect(scenario.getAnswerNode('/data/outer/inner'), readOnly);
    expect(scenario.getAnswerNode('/data/outer/inner/field'), readOnly);

    // Make the inner group read-only
    scenario
      ..answer('/data/is-outer-readonly', false)
      ..answer('/data/is-inner-readonly', true);
    expect(scenario.getAnswerNode('/data/outer'), enabled);
    expect(scenario.getAnswerNode('/data/outer/inner'), readOnly);
    expect(scenario.getAnswerNode('/data/outer/inner/field'), readOnly);

    // Make the field read-only
    scenario
      ..answer('/data/is-inner-readonly', false)
      ..answer('/data/is-field-readonly', true);
    expect(scenario.getAnswerNode('/data/outer'), enabled);
    expect(scenario.getAnswerNode('/data/outer/inner'), enabled);
    expect(scenario.getAnswerNode('/data/outer/inner/field'), readOnly);
  });
  //endregion Read-only

  //region Required and constraint
  test('constraints_of_fields_that_are_empty_are_always_satisfied', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [t('a'), t('b')]),
            ]),
            bind('/data/a')
              ..type('string')
              ..constraint('/data/b'),
            bind('/data/b')..type('boolean'),
          ]),
        ]),
        body([input('/data/a'), input('/data/b')]),
      ),
    );

    // Ensure that the constraint expression in /data/a won't be satisfied
    scenario.answer('/data/b', false);

    // Verify that regardless of the constraint defined in /data/a, the form
    // appears to be valid
    expect(scenario.formDef, valid);
  });

  test('empty_required_fields_make_form_validation_fail', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [t('a'), t('b')]),
            ]),
            bind('/data/a')
              ..type('string')
              ..required(),
            bind('/data/b')..type('boolean'),
          ]),
        ]),
        body([input('/data/a'), input('/data/b')]),
      ),
    );

    final validate = scenario.validationOutcome!;
    expect(validate.failedPrompt, scenario.indexOf('/data/a'));
    expect(validate.outcome, AnswerStatus.requiredButEmpty);
  });

  test('constraint_violations_and_form_finalization', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [t('a'), t('b')]),
            ]),
            bind('/data/a')
              ..type('string')
              ..constraint('/data/b'),
            bind('/data/b')..type('boolean'),
          ]),
        ]),
        body([input('/data/a'), input('/data/b')]),
      ),
    );

    // First, ensure we will be able to commit an answer in /data/a by
    // making it match its constraint. No values can be committed to the
    // instance if constraints aren't satisfied.
    scenario
      ..answer('/data/b', true)
      // Then, commit an answer (answers with empty values are always valid)
      ..answer('/data/a', 'cocotero')
      // Then, make the constraint defined at /data/a impossible to satisfy
      ..answer('/data/b', false);

    // At this point, the form has /data/a filled with an answer that's
    // invalid according to its constraint expression, but we can't be aware
    // of that, unless we validate the whole form. FormDef.validate goes
    // through all the relevant fields re-answering them with their current
    // values in order to detect any constraint violations.
    final validate = scenario.validationOutcome!;
    expect(validate.failedPrompt, scenario.indexOf('/data/a'));
    expect(validate.outcome, AnswerStatus.constraintViolated);
  });
  //endregion

  //region Adding or deleting repeats
  test('addingRepeatInstance_updatesCalculationCascade', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Add repeat instance'),
          model([
            mainInstance([
              t('data id="repeat-calcs"', [
                t('repeat', [t('inner1'), t('inner2'), t('inner3')]),
              ]),
            ]),
            bind('/data/repeat/inner2')..calculate('2 * ../inner1'),
            bind('/data/repeat/inner3')..calculate('2 * ../inner2'),
          ]),
        ]),
        body([
          repeat('/data/repeat', [input('/data/repeat/inner1')]),
        ]),
      ),
    );

    scenario
      ..next()
      ..next()
      ..answerCurrent(0);

    expect(scenario.answerOf('/data/repeat[1]/inner2'), intAnswer(0));
    expect(scenario.answerOf('/data/repeat[1]/inner3'), intAnswer(0));

    scenario
      ..next()
      ..createNewRepeatHere()
      ..next()
      ..answerCurrent(1);

    expect(scenario.answerOf('/data/repeat[2]/inner2'), intAnswer(2));
    expect(scenario.answerOf('/data/repeat[2]/inner3'), intAnswer(4));
  });

  test(
    'addingRepeat_updatesInnerCalculations_withMultipleDependencies',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Repeat cascading calc'),
            model([
              mainInstance([
                t('data id="repeat-calcs"', [
                  t('repeat', [
                    t('position'),
                    t('position_2'),
                    t('other'),
                    t('concatenated'),
                  ]),
                ]),
              ]),
              // position(..) means the full cascade is evaulated as part of
              // triggerTriggerables
              bind('/data/repeat/position')..calculate('position(..)'),
              bind('/data/repeat/position_2')..calculate('../position * 2'),
              bind('/data/repeat/other')..calculate('2 * 2'),
              // concat needs to be evaluated after /data/repeat/other has a
              // value
              bind('/data/repeat/concatenated')
                ..calculate("concat(../position_2, '-', ../other)"),
            ]),
          ]),
          body([
            repeat('/data/repeat', [input('/data/repeat/concatenated')]),
          ]),
        ),
      );

      scenario
        ..next()
        ..next();
      expect(
        scenario.answerOf('/data/repeat[1]/concatenated'),
        stringAnswer('2-4'),
      );

      scenario
        ..next()
        ..createNewRepeatHere()
        ..next();
      expect(
        scenario.answerOf('/data/repeat[2]/concatenated'),
        stringAnswer('4-4'),
      );
    },
  );

  // Illustrates the second case in
  // TriggerableDAG.getTriggerablesAffectingAllInstances
  test('addingOrRemovingRepeatInstance_withCalculatedCountOutsideRepeat_'
      'updatesReferenceToCountInside', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Count outside repeat used inside'),
                model([
                  mainInstance([
                    t('data id="outside-used-inside"', [
                      t('count'),
                      t('repeat jr:template=""', [
                        t('question'),
                        t('inner-count'),
                      ]),
                    ]),
                  ]),
                  bind('/data/count')
                    ..type('int')
                    ..calculate('count(/data/repeat)'),
                  bind('/data/repeat/inner-count')
                    ..type('int')
                    ..calculate('/data/count'),
                ]),
              ]),
              body([
                repeat('/data/repeat', [input('/data/repeat/question')]),
              ]),
            ),
          )
          ..onDagEvent(dagEvents.add);

    dagEvents.clear();

    for (var n = 1; n < 6; n++) {
      scenario
        ..next()
        ..createNewRepeatHere();
      expect(scenario.answerOf('/data/count'), intAnswer(n));
      scenario.next();
    }

    for (var n = 1; n < 6; n++) {
      expect(scenario.answerOf('/data/repeat[$n]/inner-count'), intAnswer(5));
    }

    scenario.removeRepeat('/data/repeat[5]');

    for (var n = 1; n < 5; n++) {
      expect(scenario.answerOf('/data/repeat[$n]/inner-count'), intAnswer(4));
    }
  });

  // In this case, the count(/data/repeat) expression is represented by a
  // single triggerable. The expression gets evaluated once and it's the
  // expandReference call in Triggerable.apply which ensures the result is
  // updated for every repeat instance.
  test(
    'addingOrRemovingRepeatInstance_updatesRepeatCount_insideAndOutsideRepeat',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Count outside repeat used inside'),
            model([
              mainInstance([
                t('data id="outside-used-inside"', [
                  t('count'),
                  t('repeat jr:template=""', [t('question'), t('inner-count')]),
                ]),
              ]),
              bind('/data/count')
                ..type('int')
                ..calculate('count(/data/repeat)'),
              bind('/data/repeat/inner-count')
                ..type('int')
                ..calculate('count(/data/repeat)'),
            ]),
          ]),
          body([
            repeat('/data/repeat', [input('/data/repeat/question')]),
          ]),
        ),
      );

      for (var n = 1; n < 6; n++) {
        scenario
          ..next()
          ..createNewRepeatHere();
        expect(scenario.answerOf('/data/repeat[$n]/inner-count'), intAnswer(n));
        scenario.next();
      }

      for (var n = 1; n < 6; n++) {
        expect(scenario.answerOf('/data/repeat[$n]/inner-count'), intAnswer(5));
      }

      scenario.removeRepeat('/data/repeat[5]');

      for (var n = 1; n < 5; n++) {
        expect(scenario.answerOf('/data/repeat[$n]/inner-count'), intAnswer(4));
      }
    },
  );

  // In this case, /data/repeat in the count(/data/repeat) expression is
  // given the context of the current repeat so the count always evaluates
  // to 1. See contrast with
  // addingOrRemovingRepeatInstance_updatesRepeatCount_insideAndOutsideRepeat.
  test(
    'addingOrRemovingRepeatInstance_updatesRepeatCount_insideRepeat',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Count outside repeat used inside'),
            model([
              mainInstance([
                t('data id="outside-used-inside"', [
                  t('repeat jr:template=""', [t('question'), t('inner-count')]),
                ]),
              ]),
              bind('/data/repeat/inner-count')
                ..type('int')
                ..calculate('count(/data/repeat)'),
            ]),
          ]),
          body([
            repeat('/data/repeat', [input('/data/repeat/question')]),
          ]),
        ),
      );

      for (var n = 1; n < 6; n++) {
        scenario
          ..next()
          ..createNewRepeatHere();
        expect(scenario.answerOf('/data/repeat[$n]/inner-count'), intAnswer(n));
        scenario.next();
      }

      for (var n = 1; n < 6; n++) {
        expect(scenario.answerOf('/data/repeat[$n]/inner-count'), intAnswer(5));
      }

      scenario.removeRepeat('/data/repeat[4]');

      for (var n = 1; n < 5; n++) {
        expect(scenario.answerOf('/data/repeat[$n]/inner-count'), intAnswer(4));
      }
    },
    skip:
        '@Ignore in JavaRosa: Highlights issue with de-duplicating refs and '
        'different contexts',
  );

  test(
    'addingOrRemovingRepeatInstance_updatesRelativeRepeatCount_insideRepeat',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Count outside repeat used inside'),
            model([
              mainInstance([
                t('data id="outside-used-inside"', [
                  t('repeat jr:template=""', [t('question'), t('inner-count')]),
                ]),
              ]),
              bind('/data/repeat/inner-count')
                ..type('int')
                ..calculate('count(../../repeat)'),
            ]),
          ]),
          body([
            repeat('/data/repeat', [input('/data/repeat/question')]),
          ]),
        ),
      );

      for (var n = 1; n < 6; n++) {
        scenario
          ..next()
          ..createNewRepeatHere();
        expect(scenario.answerOf('/data/repeat[$n]/inner-count'), intAnswer(n));
        scenario.next();
      }

      for (var n = 1; n < 6; n++) {
        expect(scenario.answerOf('/data/repeat[$n]/inner-count'), intAnswer(5));
      }

      scenario.removeRepeat('/data/repeat[4]');

      for (var n = 1; n < 5; n++) {
        expect(scenario.answerOf('/data/repeat[$n]/inner-count'), intAnswer(4));
      }
    },
  );

  test('addingOrRemovingRepeatInstance_withReferenceToRepeatInRepeat_'
      'andOuterSum_updates', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Count outside repeat used inside'),
          model([
            mainInstance([
              t('data id="outside-used-inside"', [
                t('sum'),
                t('repeat jr:template=""', [
                  t('question'),
                  t('position1'),
                  t('position2'),
                ]),
              ]),
            ]),
            bind('/data/sum')
              ..type('int')
              ..calculate('sum(/data/repeat/position1)'),
            bind('/data/repeat/position1')
              ..type('int')
              ..calculate('position(..)'),
            bind('/data/repeat/position2')
              ..type('int')
              ..calculate('../position1'),
          ]),
        ]),
        body([
          repeat('/data/repeat', [input('/data/repeat/position1')]),
        ]),
      ),
    );

    for (var n = 1; n < 6; n++) {
      scenario
        ..next()
        ..createNewRepeatHere();
      expect(scenario.answerOf('/data/sum'), intAnswer(n * (n + 1) ~/ 2));
      scenario.next();
    }

    for (var n = 1; n < 6; n++) {
      expect(scenario.answerOf('/data/repeat[$n]/position1'), intAnswer(n));
    }

    scenario.removeRepeat('/data/repeat[5]');

    for (var n = 1; n < 5; n++) {
      expect(scenario.answerOf('/data/repeat[$n]/position2'), intAnswer(n));
    }
  });

  test('addingOrRemovingRepeatInstance_withReferenceToPreviousInstance_'
      'updatesThatReference', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('group jr:template=""', [t('prev-number'), t('number')]),
              ]),
            ]),
            bind('/data/group/prev-number')
              ..type('int')
              ..calculate(
                '/data/group[position() = (position(current()/..) - 1)]'
                '/number',
              ),
            bind('/data/group/number')
              ..type('int')
              ..required(),
          ]),
        ]),
        body([
          formGroup('/data/group', [
            repeat('/data/group', [input('/data/group/number')]),
          ]),
        ]),
      ),
    );

    scenario
      ..next()
      ..createNewRepeatHere()
      ..next()
      ..answerCurrent(11);

    expect(scenario.answerOf('/data/group[1]/prev-number'), isNull);
    expect(scenario.answerOf('/data/group[1]/number'), intAnswer(11));

    scenario
      ..next()
      ..createNewRepeatHere()
      ..next()
      ..answerCurrent(22);

    expect(scenario.answerOf('/data/group[1]/number'), intAnswer(11));
    expect(scenario.answerOf('/data/group[2]/number'), intAnswer(22));

    expect(scenario.answerOf('/data/group[1]/prev-number'), isNull);
    expect(scenario.answerOf('/data/group[2]/prev-number'), intAnswer(11));

    scenario
      ..next()
      ..createNewRepeatHere()
      ..next()
      ..answerCurrent(33);

    expect(scenario.answerOf('/data/group[1]/prev-number'), isNull);
    expect(scenario.answerOf('/data/group[2]/prev-number'), intAnswer(11));
    expect(scenario.answerOf('/data/group[3]/prev-number'), intAnswer(22));

    scenario.removeRepeat('/data/group[2]');

    expect(scenario.answerOf('/data/group[1]/prev-number'), isNull);
    expect(scenario.answerOf('/data/group[2]/number'), intAnswer(33));
    expect(scenario.answerOf('/data/group[2]/prev-number'), intAnswer(11));
  });

  test(
    'addingOrDeletingRepeatInstance_withRelevanceInsideRepeatDependingOnCount_'
    'updatesRelevanceForAllInstances',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Some form'),
            model([
              mainInstance([
                t('data id="some-form"', [
                  t('repeat jr:template=""', [
                    t('number'),
                    t('group', [t('in_group')]),
                  ]),
                ]),
              ]),
              bind('/data/repeat/number')
                ..type('int')
                ..required(),
              bind('/data/repeat/group')
                ..relevant('count(../../repeat) mod 2 = 1'),
            ]),
          ]),
          body([
            repeat('/data/repeat', [
              input('/data/repeat/number'),
              formGroup('/data/repeat/group', [
                input('/data/repeat/group/in_group'),
              ]),
            ]),
          ]),
        ),
      );

      scenario
        ..next()
        ..createNewRepeatHere();

      expect(
        scenario.getAnswerNode('/data/repeat[1]/group/in_group').isRelevant,
        isTrue,
      );

      scenario.createNewRepeat('/data/repeat');

      expect(
        scenario.getAnswerNode('/data/repeat[2]/group/in_group').isRelevant,
        isFalse,
      );
      expect(
        scenario.getAnswerNode('/data/repeat[1]/group/in_group').isRelevant,
        isFalse,
      );

      scenario.removeRepeat('/data/repeat[2]');

      expect(
        scenario.getAnswerNode('/data/repeat[1]/group/in_group').isRelevant,
        isTrue,
      );
    },
  );
  //endregion

  //region Deleting repeats
  test('deleteSecondRepeatGroup_evaluatesTriggerables_'
      'dependentOnPrecedingRepeatGroupSiblings', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Some form'),
                model([
                  mainInstance([
                    t('data id="some-form"', [
                      t('house jr:template=""', [t('number')]),
                    ]),
                  ]),
                  bind('/data/house/number')
                    ..type('int')
                    ..calculate('position(..)'),
                ]),
              ]),
              body([
                formGroup('/data/house', [
                  repeat('/data/house', [input('number')]),
                ]),
              ]),
            ),
          )
          ..onDagEvent(dagEvents.add);
    for (var i = 1; i < 6; i++) {
      scenario
        ..next()
        ..createNewRepeatHere()
        ..next();
    }
    expect(scenario.answerOf('/data/house[1]/number'), intAnswer(1));
    expect(scenario.answerOf('/data/house[2]/number'), intAnswer(2));
    expect(scenario.answerOf('/data/house[3]/number'), intAnswer(3));
    expect(scenario.answerOf('/data/house[4]/number'), intAnswer(4));
    expect(scenario.answerOf('/data/house[5]/number'), intAnswer(5));

    // Start recording DAG events now
    dagEvents.clear();

    scenario.removeRepeat('/data/house[2]');

    expect(scenario.answerOf('/data/house[1]/number'), intAnswer(1));
    expect(scenario.answerOf('/data/house[2]/number'), intAnswer(2));
    expect(scenario.answerOf('/data/house[3]/number'), intAnswer(3));
    expect(scenario.answerOf('/data/house[4]/number'), intAnswer(4));
    expect(scenario.answerOf('/data/house[5]/number'), isNull);
    _assertDagEvents(dagEvents, [
      "Processing 'Recalculate' for number [1_1] (1.0), number [2_1] (2.0), "
          'number [3_1] (3.0), number [4_1] (4.0)',
      "Processing 'Deleted: number [2_1]: 1 triggerables were fired.' for ",
    ]);
  });

  test(
    'deleteSecondRepeatGroup_evaluatesTriggerables_dependentOnTheParentPosition',
    () async {
      final scenario =
          await Scenario.init(
              html(
                head([
                  title('Some form'),
                  model([
                    mainInstance([
                      t('data id="some-form"', [
                        t('house jr:template=""', [
                          t('number'),
                          t('name'),
                          t('name_and_number'),
                        ]),
                      ]),
                    ]),
                    bind('/data/house/number')
                      ..type('int')
                      ..calculate('position(..)'),
                    bind('/data/house/name')
                      ..type('string')
                      ..required(),
                    bind('/data/house/name_and_number')
                      ..type('string')
                      ..calculate('concat(../name, ../number)'),
                  ]),
                ]),
                body([
                  formGroup('/data/house', [
                    repeat('/data/house', [input('/data/house/name')]),
                  ]),
                ]),
              ),
            )
            ..onDagEvent(dagEvents.add);
      for (var n = 1; n < 6; n++) {
        scenario
          ..next()
          ..createNewRepeatHere()
          ..next()
          ..answerCurrent(String.fromCharCode(64 + n));
      }
      expect(
        scenario.answerOf('/data/house[1]/name_and_number'),
        stringAnswer('A1'),
      );
      expect(
        scenario.answerOf('/data/house[2]/name_and_number'),
        stringAnswer('B2'),
      );
      expect(
        scenario.answerOf('/data/house[3]/name_and_number'),
        stringAnswer('C3'),
      );
      expect(
        scenario.answerOf('/data/house[4]/name_and_number'),
        stringAnswer('D4'),
      );
      expect(
        scenario.answerOf('/data/house[5]/name_and_number'),
        stringAnswer('E5'),
      );

      // Start recording DAG events now
      dagEvents.clear();

      scenario.removeRepeat('/data/house[2]');

      expect(
        scenario.answerOf('/data/house[1]/name_and_number'),
        stringAnswer('A1'),
      );
      expect(
        scenario.answerOf('/data/house[2]/name_and_number'),
        stringAnswer('C2'),
      );
      expect(
        scenario.answerOf('/data/house[3]/name_and_number'),
        stringAnswer('D3'),
      );
      expect(
        scenario.answerOf('/data/house[4]/name_and_number'),
        stringAnswer('E4'),
      );
      expect(scenario.answerOf('/data/house[5]/name_and_number'), isNull);
      _assertDagEvents(dagEvents, [
        "Processing 'Recalculate' for number [1_1] (1.0), number [2_1] (2.0), "
            'number [3_1] (3.0), number [4_1] (4.0)',
        "Processing 'Recalculate' for name_and_number [1_1] (A1), "
            'name_and_number [2_1] (C2), name_and_number [3_1] (D3), '
            'name_and_number [4_1] (E4)',
        "Processing 'Deleted: number [2_1]: 0 triggerables were fired.' for ",
        "Processing 'Deleted: name [2_1]: 0 triggerables were fired.' for ",
        "Processing 'Deleted: name_and_number [2_1]: 2 triggerables were "
            "fired.' for ",
      ]);
    },
  );

  test('deleteSecondRepeatGroup_doesNotEvaluateTriggerables_'
      'notDependentOnTheParentPosition', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Some form'),
                model([
                  mainInstance([
                    t('data id="some-form"', [
                      t('house jr:template=""', [
                        t('number'),
                        t('name'),
                        t('name_and_number'),
                      ]),
                    ]),
                  ]),
                  bind('/data/house/number')
                    ..type('int')
                    ..calculate('position(..)'),
                  bind('/data/house/name')
                    ..type('string')
                    ..required(),
                  bind('/data/house/name_and_number')
                    ..type('string')
                    ..calculate("concat(../name, 'X')"),
                ]),
              ]),
              body([
                formGroup('/data/house', [
                  repeat('/data/house', [input('/data/house/name')]),
                ]),
              ]),
            ),
          )
          ..onDagEvent(dagEvents.add);
    for (var n = 1; n < 6; n++) {
      scenario
        ..next()
        ..createNewRepeatHere()
        ..next()
        ..answerCurrent(String.fromCharCode(64 + n));
    }
    expect(
      scenario.answerOf('/data/house[1]/name_and_number'),
      stringAnswer('AX'),
    );
    expect(
      scenario.answerOf('/data/house[2]/name_and_number'),
      stringAnswer('BX'),
    );
    expect(
      scenario.answerOf('/data/house[3]/name_and_number'),
      stringAnswer('CX'),
    );
    expect(
      scenario.answerOf('/data/house[4]/name_and_number'),
      stringAnswer('DX'),
    );
    expect(
      scenario.answerOf('/data/house[5]/name_and_number'),
      stringAnswer('EX'),
    );

    // Start recording DAG events now
    dagEvents.clear();

    scenario.removeRepeat('/data/house[2]');

    expect(
      scenario.answerOf('/data/house[1]/name_and_number'),
      stringAnswer('AX'),
    );
    expect(
      scenario.answerOf('/data/house[2]/name_and_number'),
      stringAnswer('CX'),
    );
    expect(
      scenario.answerOf('/data/house[3]/name_and_number'),
      stringAnswer('DX'),
    );
    expect(
      scenario.answerOf('/data/house[4]/name_and_number'),
      stringAnswer('EX'),
    );
    expect(scenario.answerOf('/data/house[5]/name_and_number'), isNull);
    _assertDagEvents(dagEvents, [
      "Processing 'Recalculate' for number [1_1] (1.0), number [2_1] (2.0), "
          'number [3_1] (3.0), number [4_1] (4.0)',
      "Processing 'Deleted: number [2_1]: 1 triggerables were fired.' for ",
      "Processing 'Recalculate' for name_and_number [2_1] (CX)",
      "Processing 'Deleted: name [2_1]: 1 triggerables were fired.' for ",
      "Processing 'Deleted: name_and_number [2_1]: 1 triggerables were "
          "fired.' for ",
    ]);
  });

  test('deleteThirdRepeatGroup_evaluatesTriggerables_'
      'dependentOnTheRepeatGroupsNumber', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('house jr:template=""', [t('number')]),
                t('summary'),
              ]),
            ]),
            bind('/data/house/number')
              ..type('int')
              ..calculate('position(..)'),
            bind('/data/summary')
              ..type('int')
              ..calculate('sum(/data/house/number)'),
          ]),
        ]),
        body([
          formGroup('/data/house', [
            repeat('/data/house', [input('number')]),
          ]),
        ]),
      ),
    );
    for (var n = 0; n < 10; n++) {
      scenario
        ..next()
        ..createNewRepeatHere()
        ..next();
    }
    expect(scenario.answerOf('/data/summary'), intAnswer(55));

    scenario.removeRepeat('/data/house[3]');

    expect(scenario.answerOf('/data/summary'), intAnswer(45));
  });

  // Verifies that the list of recalculations triggered by the repeat
  // instance deletion is minimal. In particular, calculations outside the
  // repeat should only be re-computed once.
  test(
    'repeatInstanceDeletion_triggersCalculationsOutsideTheRepeat_exactlyOnce',
    () async {
      final scenario =
          await Scenario.init(
              html(
                head([
                  title('Some form'),
                  model([
                    mainInstance([
                      t('data id="some-form"', [
                        t('house jr:template=""', [t('number')]),
                        t('summary'),
                      ]),
                    ]),
                    bind('/data/house/number')
                      ..type('int')
                      ..calculate('position(..)'),
                    bind('/data/summary')
                      ..type('int')
                      ..calculate('sum(/data/house/number)'),
                  ]),
                ]),
                body([
                  formGroup('/data/house', [
                    repeat('/data/house', [input('number')]),
                  ]),
                ]),
              ),
            )
            ..onDagEvent(dagEvents.add);
      for (var n = 1; n < 11; n++) {
        scenario
          ..next()
          ..createNewRepeatHere()
          ..next();
      }

      // Start recording DAG events now
      dagEvents.clear();

      scenario.removeRepeat('/data/house[3]');

      expect(scenario.answerOf('/data/summary'), intAnswer(45));
      _assertDagEvents(dagEvents, [
        "Processing 'Recalculate' for number [1_1] (1.0), number [2_1] (2.0), "
            'number [3_1] (3.0), number [4_1] (4.0), number [5_1] (5.0), '
            'number [6_1] (6.0), number [7_1] (7.0), number [8_1] (8.0), '
            'number [9_1] (9.0)',
        "Processing 'Recalculate' for summary [1] (45.0)",
        "Processing 'Deleted: number [3_1]: 0 triggerables were fired.' for ",
      ]);
    },
  );

  test('repeatInstanceDeletion_withoutReferencesToRepeat_'
      'evaluatesNoTriggersInInstances', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Some form'),
                model([
                  mainInstance([
                    t('data id="some-form"', [
                      t('repeat jr:template=""', [
                        t('number'),
                        t('numberx2'),
                        t('calc'),
                      ]),
                    ]),
                  ]),
                  bind('/data/repeat/number')..type('int'),
                  bind('/data/repeat/numberx2')
                    ..type('int')
                    ..calculate('../number * 2'),
                  bind('/data/repeat/calc')
                    ..type('int')
                    ..calculate('2 * random()'),
                ]),
              ]),
              body([
                formGroup('/data/repeat', [
                  repeat('/data/repeat', [input('number')]),
                ]),
              ]),
            ),
          )
          ..onDagEvent(dagEvents.add);
    for (var n = 1; n < 11; n++) {
      scenario
        ..next()
        ..createNewRepeatHere()
        ..next();
    }

    // Start recording DAG events now
    dagEvents.clear();

    scenario.removeRepeat('/data/repeat[3]');

    _assertDagEvents(dagEvents, [
      "Processing 'Recalculate' for numberx2 [3_1] (NaN)",
      "Processing 'Deleted: number [3_1]: 1 triggerables were fired.' for ",
      "Processing 'Deleted: numberx2 [3_1]: 0 triggerables were fired.' for ",
      "Processing 'Deleted: calc [3_1]: 0 triggerables were fired.' for ",
    ]);
  });

  // The calculation `concat(/data/house/name)` does not take the
  // `/data/house` nodeset (the repeat group) as an argument but, since it
  // takes one of its children (`name`), it must be re-evaluated once after
  // a repeat group deletion because one of the children has been deleted
  // along with its parent (the repeat group instance).
  test('deleteThirdRepeatGroup_evaluatesTriggerables_'
      'indirectlyDependentOnTheRepeatGroupsNumber', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Some form'),
                model([
                  mainInstance([
                    t('data id="some-form"', [
                      t('house jr:template=""', [t('name')]),
                      t('summary'),
                    ]),
                  ]),
                  bind('/data/house/name')
                    ..type('string')
                    ..required(),
                  bind('/data/summary')
                    ..type('string')
                    ..calculate('concat(/data/house/name)'),
                ]),
              ]),
              body([
                formGroup('/data/house', [
                  repeat('/data/house', [input('/data/house/name')]),
                ]),
              ]),
            ),
          )
          ..onDagEvent(dagEvents.add);
    for (var n = 1; n < 6; n++) {
      scenario
        ..next()
        ..createNewRepeatHere()
        ..next()
        ..answerCurrent(String.fromCharCode(64 + n));
    }
    expect(scenario.answerOf('/data/summary'), stringAnswer('ABCDE'));

    // Start recording DAG events now
    dagEvents.clear();

    scenario.removeRepeat('/data/house[3]');

    expect(scenario.answerOf('/data/summary'), stringAnswer('ABDE'));
    _assertDagEvents(dagEvents, [
      "Processing 'Recalculate' for summary [1] (ABDE)",
      "Processing 'Deleted: name [3_1]: 1 triggerables were fired.' for ",
    ]);
  });

  test('deleteLastRepeat_evaluatesTriggerables', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Delete last repeat instance'),
          model([
            mainInstance([
              t('data id="delete-last-repeat-instance"', [
                t('repeat-count'),
                t('repeat', [t('question')]),
                t('repeat', [t('question')]),
                t('repeat', [t('question')]),
              ]),
            ]),
            bind('/data/repeat-count')
              ..type('int')
              ..calculate('count(/data/repeat)'),
          ]),
        ]),
        body([
          repeat('/data/repeat', [input('question')]),
        ]),
      ),
    );

    expect(scenario.answerOf('/data/repeat-count'), intAnswer(3));

    scenario.removeRepeat('/data/repeat[3]');
    expect(scenario.answerOf('/data/repeat-count'), intAnswer(2));
  });

  test('deleteLastRepeat_evaluatesTriggerables_'
      'indirectlyDependentOnTheDeletedRepeat', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Delete last repeat instance'),
          model([
            mainInstance([
              t('data id="delete-last-repeat-instance"', [
                t('summary'),
                t('repeat', [tText('question', 'a')]),
                t('repeat', [tText('question', 'b')]),
                t('repeat', [tText('question', 'c')]),
              ]),
            ]),
            bind('/data/summary')
              ..type('string')
              ..calculate('concat(/data/repeat/question)'),
          ]),
        ]),
        body([
          repeat('/data/repeat', [input('question')]),
        ]),
      ),
    );

    expect(scenario.answerOf('/data/summary'), stringAnswer('abc'));

    scenario.removeRepeat('/data/repeat[3]');
    expect(scenario.answerOf('/data/summary'), stringAnswer('ab'));
  });
  //endregion

  //region Adding repeats
  // Exercises the triggerTriggerables call in createRepeatInstance.
  test('adding_repeat_instance_triggers_triggerables_outside_repeat_that_'
      'reference_repeat_nodeset', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Form'),
          model([
            mainInstance([
              t('data', [
                t('count'),
                t('repeat jr:template=""', [t('string')]),
              ]),
            ]),
            bind('/data/count')
              ..type('int')
              ..calculate('count(/data/repeat)'),
            bind('/data/repeat/string')..type('string'),
          ]),
        ]),
        body([
          repeat('/data/repeat', [input('/data/repeat/string')]),
        ]),
      ),
    );

    scenario
      ..createNewRepeat('/data/repeat')
      ..createNewRepeat('/data/repeat');

    expect(scenario.answerOf('/data/count'), intAnswer(2));
  });

  // Exercises the initializeTriggerables call in createRepeatInstance.
  test(
    'adding_repeat_instance_triggers_descendant_node_triggerables',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Form'),
            model([
              mainInstance([
                t('data', [
                  t('repeat jr:template=""', [
                    t('string'),
                    t('group', [t('int')]),
                  ]),
                ]),
              ]),
              bind('/data/repeat/string')..type('string'),
              bind('/data/repeat/group')..relevant('0'),
            ]),
          ]),
          body([
            repeat('/data/repeat', [
              input('/data/repeat/string'),
              input('/data/repeat/group/int'),
            ]),
          ]),
        ),
      );

      scenario
        ..next()
        ..createNewRepeatHere()
        ..next()
        ..next();
      expect(scenario.getAnswerNode('/data/repeat[0]/group/int'), nonRelevant);

      scenario
        ..createNewRepeatHere()
        ..next()
        ..next();
      expect(scenario.getAnswerNode('/data/repeat[1]/group/int'), nonRelevant);

      scenario
        ..createNewRepeatHere()
        ..next()
        ..next();
      expect(scenario.getAnswerNode('/data/repeat[2]/group/int'), nonRelevant);
    },
  );
  //endregion

  //region DAG limitations (cases that aren't correctly updated)
  // A field in a repeat makes an aggregate computation over another field
  // in the repeat. This should cause every repeat instance to be updated.
  test('addingRepeatInstance_withInnerSumOfQuestionInRepeat_'
      'updatesInnerSumForAllInstances', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Count outside repeat used inside'),
          model([
            mainInstance([
              t('data id="outside-used-inside"', [
                t('repeat jr:template=""', [
                  tText('question', '5'),
                  t('inner-sum'),
                ]),
              ]),
            ]),
            bind('/data/repeat/inner-sum')
              ..type('int')
              ..calculate('sum(../../repeat/question)'),
          ]),
        ]),
        body([
          repeat('/data/repeat', [input('/data/repeat/question')]),
        ]),
      ),
    );

    for (var n = 1; n < 6; n++) {
      scenario
        ..next()
        ..createNewRepeatHere();
      expect(scenario.answerOf('/data/repeat[$n]/inner-sum'), intAnswer(n * 5));
      scenario.next();
    }

    for (var n = 1; n < 6; n++) {
      expect(scenario.answerOf('/data/repeat[$n]/inner-sum'), intAnswer(25));
    }

    scenario.removeRepeat('/data/repeat[4]');

    for (var n = 1; n < 5; n++) {
      expect(scenario.answerOf('/data/repeat[$n]/inner-sum'), intAnswer(20));
    }
  }, skip: '@Ignore in JavaRosa: Fails on v2.17.0 (before DAG simplification)');

  // A field in a repeat is referred to in a calculation outside the repeat
  // and that calculation is then referenced in the repeat; every repeat
  // instance should be updated.
  test('addingRepeatInstance_withInnerCalculateDependentOnOuterSum_'
      'updatesInnerSumForAllInstances', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Count outside repeat used inside'),
          model([
            mainInstance([
              t('data id="outside-used-inside"', [
                t('sum'),
                t('repeat jr:template=""', [
                  tText('question', '5'),
                  t('inner-sum'),
                ]),
              ]),
            ]),
            bind('/data/sum')
              ..type('int')
              ..calculate('sum(/data/repeat/question)'),
            bind('/data/repeat/inner-sum')
              ..type('int')
              ..calculate('/data/sum'),
          ]),
        ]),
        body([
          repeat('/data/repeat', [input('/data/repeat/question')]),
        ]),
      ),
    );

    for (var n = 1; n < 6; n++) {
      scenario
        ..next()
        ..createNewRepeatHere();
      expect(scenario.answerOf('/data/sum'), intAnswer(n * 5));
      scenario.next();
    }

    for (var n = 1; n < 6; n++) {
      expect(scenario.answerOf('/data/repeat[$n]/inner-sum'), intAnswer(25));
    }

    scenario.removeRepeat('/data/repeat[4]');

    for (var n = 1; n < 5; n++) {
      expect(scenario.answerOf('/data/repeat[$n]/inner-sum'), intAnswer(20));
    }
  }, skip: '@Ignore in JavaRosa: Fails on v2.17.0 (before DAG simplification)');

  // It's not the repeat addition that needs to trigger recomputation across
  // repeat instances, it's the setting of the number value in a specific
  // instance. There's currently no mechanism to do that.
  test(
    'changingValueInRepeat_withReferenceToNextInstance_updatesPreviousInstance',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Some form'),
            model([
              mainInstance([
                t('data id="some-form"', [
                  t('group jr:template=""', [t('number'), t('next-number')]),
                ]),
              ]),
              bind('/data/group/number')
                ..type('int')
                ..required(),
              bind('/data/group/next-number')
                ..type('int')
                ..calculate(
                  '/data/group[position() = (position(current()/..) + 1)]'
                  '/number',
                ),
            ]),
          ]),
          body([
            formGroup('/data/group', [
              repeat('/data/group', [input('/data/group/number')]),
            ]),
          ]),
        ),
      );

      scenario
        ..next()
        ..createNewRepeatHere()
        ..next()
        ..answerCurrent(11);

      expect(scenario.answerOf('/data/group[1]/next-number'), isNull);
      expect(scenario.answerOf('/data/group[1]/number'), intAnswer(11));

      scenario
        ..next()
        ..createNewRepeatHere()
        ..next()
        ..answerCurrent(22);

      expect(scenario.answerOf('/data/group[1]/number'), intAnswer(11));
      expect(scenario.answerOf('/data/group[2]/number'), intAnswer(22));

      // This assertion is false because setting the answer to 22 didn't
      // trigger recomputation across repeat instances
      expect(scenario.answerOf('/data/group[1]/next-number'), intAnswer(22));
      expect(scenario.answerOf('/data/group[2]/next-number'), isNull);

      scenario
        ..next()
        ..createNewRepeatHere()
        ..next()
        ..answerCurrent(33);

      // This assertion is true because adding a new repeat triggered
      // recomputation across repeat instances
      expect(scenario.answerOf('/data/group[1]/next-number'), intAnswer(22));
      // This assertion is false because setting the answer to 33 didn't
      // trigger recomputation across repeat instances
      expect(scenario.answerOf('/data/group[2]/next-number'), intAnswer(33));
      expect(scenario.answerOf('/data/group[3]/next-number'), isNull);
    },
    skip: '@Ignore in JavaRosa: Fails on v2.17.0 (before DAG simplification)',
  );

  test('issue_119_target_question_should_be_relevant', () async {
    // This is a translation of the XML form in the issue to our DSL with
    // some adaptations:
    // - Explicit binds for all fields
    // - Migrated the condition field to boolean, which should be easier to
    //   understand
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                tText('outer_trigger', 'D'),
                t('inner_trigger'),
                t('outer', [
                  t('inner', [t('target_question')]),
                  t('inner_condition'),
                ]),
                t('end'),
              ]),
            ]),
            bind('/data/outer_trigger')..type('string'),
            bind('/data/inner_trigger')..type('int'),
            bind('/data/outer')..relevant("/data/outer_trigger = 'D'"),
            bind('/data/outer/inner_condition')
              ..type('boolean')
              ..calculate('/data/inner_trigger > 10'),
            bind('/data/outer/inner')..relevant('../inner_condition'),
            bind('/data/outer/inner/target_question')..type('string'),
          ]),
        ]),
        body([
          input('inner_trigger', [label('inner trigger (enter 5)')]),
          input('outer_trigger', [label("outer trigger (enter 'D')")]),
          input('outer/inner/target_question', [
            label('target question: i am incorrectly skipped'),
          ]),
          input('end', [label('this is the end of the form')]),
        ]),
      ),
    );

    // Starting conditions (outer trigger is D, inner trigger is empty)
    expect(scenario.getAnswerNode('/data/outer'), relevant);
    expect(scenario.getAnswerNode('/data/outer/inner_condition'), relevant);
    expect(
      scenario.answerOf('/data/outer/inner_condition'),
      booleanAnswer(false),
    );
    expect(scenario.getAnswerNode('/data/outer/inner'), nonRelevant);
    expect(
      scenario.getAnswerNode('/data/outer/inner/target_question'),
      nonRelevant,
    );

    scenario.answer('/data/inner_trigger', 15);

    expect(scenario.getAnswerNode('/data/outer'), relevant);
    expect(scenario.getAnswerNode('/data/outer/inner_condition'), relevant);
    expect(
      scenario.answerOf('/data/outer/inner_condition'),
      booleanAnswer(true),
    );
    expect(scenario.getAnswerNode('/data/outer/inner'), relevant);
    expect(
      scenario.getAnswerNode('/data/outer/inner/target_question'),
      relevant,
    );

    scenario.answer('/data/outer_trigger', 'A');

    expect(scenario.getAnswerNode('/data/outer'), nonRelevant);
    expect(scenario.getAnswerNode('/data/outer/inner_condition'), nonRelevant);
    expect(
      scenario.answerOf('/data/outer/inner_condition'),
      booleanAnswer(true),
    );
    expect(scenario.getAnswerNode('/data/outer/inner'), nonRelevant);
    expect(
      scenario.getAnswerNode('/data/outer/inner/target_question'),
      relevant,
    );
  }, skip: '@Ignore in JavaRosa: Fails on v2.17.0 (before DAG simplification)');
  //endregion

  //region Repeat misc
  test(
    'issue_135_verify_that_counts_in_inner_repeats_work_as_expected',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Some form'),
            model([
              mainInstance([
                t('data id="some-form"', [
                  tText('outer-count', '0'),
                  t('outer jr:template=""', [
                    tText('inner-count', '0'),
                    t('inner jr:template=""', [t('some-field')]),
                  ]),
                ]),
              ]),
              bind('/data/outer-count')..type('int'),
              bind('/data/outer/inner-count')..type('int'),
              bind('/data/outer/inner/some-field')..type('string'),
            ]),
          ]),
          body([
            input('/data/outer-count'),
            formGroup('/data/outer', [
              repeat('/data/outer', [
                input('/data/outer/inner-count'),
                formGroup('/data/outer/inner', [
                  repeat('/data/outer/inner', [
                    input('/data/outer/inner/some-field'),
                  ], '../inner-count'),
                ]),
              ], '/data/outer-count'),
            ]),
          ]),
        ),
      );

      scenario
        ..next()
        ..answerCurrent(2)
        ..next()
        ..next()
        ..answerCurrent(3)
        ..next()
        ..next()
        ..answerCurrent('Some field 0-0')
        ..next()
        ..next()
        ..answerCurrent('Some field 0-1')
        ..next()
        ..next()
        ..answerCurrent('Some field 0-2')
        ..next()
        ..next()
        ..answerCurrent(2)
        ..next()
        ..next()
        ..answerCurrent('Some field 1-0')
        ..next()
        ..next()
        ..answerCurrent('Some field 1-1')
        ..next();
      expect(scenario.countRepeatInstancesOf('/data/outer[1]/inner'), 3);
      expect(scenario.countRepeatInstancesOf('/data/outer[2]/inner'), 2);
    },
  );

  test('addingNestedRepeatInstance_updatesExpressionTriggeredByGenericRef_'
      'forAllRepeatInstances', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Some form'),
          model([
            mainInstance([
              t('data id="some-form"', [
                t('outer jr:template=""', [
                  t('inner jr:template=""', [t('count'), t('some-field')]),
                  t('some-field'),
                ]),
              ]),
            ]),
            bind('/data/outer/inner/count')
              ..type('int')
              ..calculate('count(../../inner)'),
          ]),
        ]),
        body([
          formGroup('/data/outer', [
            repeat('/data/outer', [
              input('/data/outer/some-field'),
              formGroup('/data/outer/inner', [
                repeat('/data/outer/inner', [
                  input('/data/outer/inner/some-field'),
                ]),
              ]),
            ]),
          ]),
        ]),
      ),
    );
    scenario
      ..createNewRepeat('/data/outer')
      ..createNewRepeat('/data/outer[1]/inner')
      ..createNewRepeat('/data/outer[1]/inner')
      ..createNewRepeat('/data/outer[1]/inner')
      ..createNewRepeat('/data/outer')
      ..createNewRepeat('/data/outer[2]/inner')
      ..createNewRepeat('/data/outer[2]/inner');

    expect(scenario.answerOf('/data/outer[1]/inner[1]/count'), intAnswer(3));
    expect(scenario.answerOf('/data/outer[1]/inner[2]/count'), intAnswer(3));
    expect(scenario.answerOf('/data/outer[1]/inner[3]/count'), intAnswer(3));
    expect(scenario.answerOf('/data/outer[2]/inner[1]/count'), intAnswer(2));
    expect(scenario.answerOf('/data/outer[2]/inner[2]/count'), intAnswer(2));
  });

  test(
    'addingRepeatInstance_updatesReferenceToLastInstance_usingPositionPredicate',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Some form'),
            model([
              mainInstance([
                t('data id="some-form"', [
                  t('group jr:template=""', [t('number')]),
                  t('count'),
                  t('result_1'),
                  t('result_2'),
                ]),
              ]),
              bind('/data/group/number')
                ..type('int')
                ..required(),
              bind('/data/count')
                ..type('int')
                ..calculate('count(/data/group)'),
              bind('/data/result_1')
                ..type('int')
                ..calculate(
                  '10 + /data/group[position() = /data/count]/number',
                ),
              bind('/data/result_2')
                ..type('int')
                ..calculate(
                  '10 + /data/group[position() = count(../group)]/number',
                ),
            ]),
          ]),
          body([
            formGroup('/data/group', [
              repeat('/data/group', [input('/data/group/number')]),
            ]),
          ]),
        ),
      );
      scenario
        ..next()
        ..createNewRepeatHere()
        ..next()
        ..answerCurrent(10);

      expect(scenario.answerOf('/data/count'), intAnswer(1));
      expect(scenario.answerOf('/data/result_1'), intAnswer(20));
      expect(scenario.answerOf('/data/result_2'), intAnswer(20));

      scenario
        ..next()
        ..createNewRepeatHere()
        ..next()
        ..answerCurrent(20);

      expect(scenario.answerOf('/data/count'), intAnswer(2));
      expect(scenario.answerOf('/data/result_1'), intAnswer(30));
      // This would fail with count(/data/group) because the absolute ref
      // would get a multiplicity
      expect(scenario.answerOf('/data/result_2'), intAnswer(30));
    },
  );
  //endregion
}
