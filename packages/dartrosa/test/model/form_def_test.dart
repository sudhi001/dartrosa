// Port of JavaRosa v6.0.0 FormDefTest.
@TestOn('vm')
library;

import 'package:dartrosa/src/form_api/form_entry_caption.dart';
import 'package:dartrosa/src/model/condition/evaluation_context.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';

final class _CustomFunc extends XPathFunctionHandler {
  @override
  String get name => 'custom-func';

  @override
  List<List<XPathArgType>> get prototypes => [];

  @override
  bool get rawArgs => true;

  @override
  Object eval(List<Object> args, EvaluationContext context) => 'blah';
}

void main() {
  test('enforces_constraints_defined_in_a_field', () async {
    final scenario = await scenarioFor('ImageSelectTester.xhtml')
      ..next(5);
    expect(scenario.answerCurrent('10'), AnswerResult.constraintViolated);
    expect(scenario.answerCurrent('13'), AnswerResult.ok);
  });

  test(
    'enforcesConstraints_whenInstanceIsDeserialized',
    () {},
    skip: 'instance/form serialization (P6)',
  );

  // region Repeat relevance
  test(
    'repeatRelevanceChanges_whenDependentValuesOfRelevanceExpressionChange',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Repeat relevance - dynamic expression'),
            model([
              mainInstance([
                t('data id="repeat_relevance_dynamic"', [
                  tText('selectYesNo', 'no'),
                  t('repeat1', [t('q1')]),
                ]),
              ]),
              bind('/data/repeat1')..relevant("/data/selectYesNo = 'yes'"),
            ]),
          ]),
          body([
            select1('/data/selectYesNo', [
              item('yes', 'Yes'),
              item('no', 'No'),
            ]),
            repeat('/data/repeat1', [input('/data/repeat1/q1')]),
          ]),
        ),
      );
      final formDef = scenario.formDef;

      expect(formDef.isRepeatRelevant(getRef('/data/repeat1[1]')), isFalse);

      scenario.answer('/data/selectYesNo', 'yes');
      expect(formDef.isRepeatRelevant(getRef('/data/repeat1[1]')), isTrue);
    },
  );

  test('repeatIsIrrelevant_whenRelevanceSetToFalse', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Repeat relevance - false()'),
          model([
            mainInstance([
              t('data id="repeat_relevance_false"', [
                t('repeat1', [t('q1')]),
              ]),
            ]),
            bind('/data/repeat1')..relevant('false()'),
          ]),
        ]),
        body([
          repeat('/data/repeat1', [input('/data/repeat1/q1')]),
        ]),
      ),
    );
    final formDef = scenario.formDef;

    expect(formDef.isRepeatRelevant(getRef('/data/repeat1[0]')), isFalse);
  });

  test(
    'repeatRelevanceChanges_whenDependentValuesOfGrandparentRelevanceExpressionChange',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Repeat relevance - dynamic expression'),
            model([
              mainInstance([
                t('data id="repeat_relevance_dynamic"', [
                  tText('selectYesNo', 'no'),
                  t('outer', [
                    t('inner', [
                      t('repeat1', [t('q1')]),
                    ]),
                  ]),
                ]),
              ]),
              bind('/data/outer')..relevant("/data/selectYesNo = 'yes'"),
            ]),
          ]),
          body([
            select1('/data/selectYesNo', [
              item('yes', 'Yes'),
              item('no', 'No'),
            ]),
            repeat('/data/outer/inner/repeat1', [
              input('/data/outer/inner/repeat1/q1'),
            ]),
          ]),
        ),
      );
      final formDef = scenario.formDef;

      expect(
        formDef.isRepeatRelevant(getRef('/data/outer/inner/repeat1[0]')),
        isFalse,
      );

      scenario.answer('/data/selectYesNo', 'yes');
      expect(
        formDef.isRepeatRelevant(getRef('/data/outer/inner/repeat1[0]')),
        isTrue,
      );
    },
  );

  test('repeatIsIrrelevant_whenGrandparentRelevanceSetToFalse', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Repeat relevance - false()'),
          model([
            mainInstance([
              t('data id="repeat_relevance_false"', [
                t('outer', [
                  t('inner', [
                    t('repeat1', [t('q1')]),
                  ]),
                ]),
              ]),
            ]),
            bind('/data/outer')..relevant('false()'),
          ]),
        ]),
        body([
          repeat('/data/outer/inner/repeat1', [
            input('/data/outer/inner/repeat1/q1'),
          ]),
        ]),
      ),
    );
    final formDef = scenario.formDef;

    expect(
      formDef.isRepeatRelevant(getRef('/data/outer/inner/repeat1[0]')),
      isFalse,
    );
  });

  test('nestedRepeatRelevance_updatesBasedOnParentPosition', () async {
    final scenario =
        await Scenario.init(
            html(
              head([
                title('Nested repeat relevance'),
                model([
                  mainInstance([
                    t('data id="nested-repeat-relevance"', [
                      t('outer', [
                        t('inner', [t('q1')]),
                        t('inner', [t('q1')]),
                      ]),
                      t('outer', [
                        t('inner', [t('q1')]),
                      ]),
                      tText('relevance-condition', '0'),
                    ]),
                  ]),
                  bind('/data/relevance-condition')..type('string'),
                  bind(
                    '/data/outer/inner',
                  )..relevant('position(..) mod 2 = /data/relevance-condition'),
                ]),
              ]),
              body([
                repeat('/data/outer', [
                  repeat('/data/outer/inner', [input('/data/outer/inner/q1')]),
                ]),
                input('/data/relevance-condition'),
              ]),
            ),
          )
          ..next();

    // For ref /data/outer[1]/inner[1], the parent position is 1 so the
    // boolean expression is false. That means none of the inner groups in
    // /data/outer[1] can be relevant.
    expect(scenario.refAtIndex, getRef('/data/outer[1]'));

    scenario.next();
    expect(scenario.refAtIndex, getRef('/data/outer[2]'));

    scenario.next();
    expect(scenario.refAtIndex, getRef('/data/outer[2]/inner[1]'));

    scenario.next();
    expect(scenario.refAtIndex, getRef('/data/outer[2]/inner[1]/q1[1]'));

    scenario
      ..answer('/data/relevance-condition', '1')
      ..jumpToBeginningOfForm()
      ..next();
    expect(scenario.refAtIndex, getRef('/data/outer[1]'));

    scenario.next();
    expect(scenario.refAtIndex, getRef('/data/outer[1]/inner[1]'));
  });

  test(
    'innerRepeatGroupIsIrrelevant_whenItsParentRepeatGroupDoesNotExist',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('Nested repeat relevance'),
            model([
              mainInstance([
                t('data id="nested-repeat-relevance"', [
                  t('outer', [
                    t('inner', [t('q1')]),
                  ]),
                ]),
              ]),
            ]),
          ]),
          body([
            repeat('/data/outer', [
              repeat('/data/outer/inner', [input('/data/outer/inner/q1')]),
            ]),
          ]),
        ),
      );

      final formDef = scenario.formDef;
      // outer[2] does not exist at this moment, we only have outer[1].
      // Checking if its inner repeat group is relevant should be possible
      // and return false.
      expect(
        formDef.isRepeatRelevant(getRef('/data/outer[2]/inner[1]')),
        isFalse,
      );
    },
  );
  // endregion

  test(
    'canCreateRepeat_returnsFalse_when_repeatCountSetButTheGroupItBelongsToDoesNotExist',
    () async {
      final scenario =
          await Scenario.init(
              html(
                head([
                  title('Nested repeat relevance'),
                  model([
                    mainInstance([
                      t('data id="nested-repeat-relevance"', [
                        t('outer', [
                          t('inner_count'),
                          t('inner', [t('question')]),
                        ]),
                      ]),
                    ]),
                    bind('/data/outer/inner_count')
                      ..type('string')
                      ..calculate('5'),
                  ]),
                ]),
                body([
                  repeat('/data/outer', [
                    repeat('/data/outer/inner', [
                      input('/data/outer/inner/question'),
                    ], '/data/outer/inner_count'),
                  ]),
                ]),
              ),
            )
            ..next();
      final outerGroupIndex = scenario.currentIndex;

      scenario.next();
      final innerGroupRef = scenario.refAtIndex!;
      final index = scenario.currentIndex;

      final formDef = scenario.formDef..deleteRepeat(outerGroupIndex);

      expect(formDef.canCreateRepeatAt(innerGroupRef, index), isFalse);
    },
  );

  XFormsElement relativeOutputForm({required bool itext}) => html(
    head([
      title(
        itext
            ? 'output with relative ref in translation'
            : 'output with relative ref',
      ),
      model([
        if (itext)
          t('itext', [
            t('translation lang="Français"', [
              t('text id="/data/repeat/position_in_label:label"', [
                tText('value', 'Position: <output value="../position"/>'),
              ]),
            ]),
          ]),
        mainInstance([
          t('data id="relative-output"', [
            t('repeat jr:template=""', [t('position'), t('position_in_label')]),
          ]),
        ]),
        bind('/data/repeat/position')
          ..type('int')
          ..calculate('position(..)'),
        bind('/data/repeat/position_in_label')..type('int'),
      ]),
    ]),
    body([
      repeat('/data/repeat', [
        input('/data/repeat/position_in_label', [
          label('Position: <output value=" ../position "/>'),
        ]),
      ]),
    ]),
  );

  Future<void> checkRelativeOutput({required bool itext}) async {
    final scenario = await Scenario.init(relativeOutputForm(itext: itext))
      ..next()
      ..createNewRepeatHere()
      ..next();

    var caption = FormEntryCaption(scenario.formDef, scenario.currentIndex);
    expect(caption.questionText(), 'Position: 1');

    scenario
      ..next()
      ..createNewRepeatHere()
      ..next();

    caption = FormEntryCaption(scenario.formDef, scenario.currentIndex);
    expect(caption.questionText(), 'Position: 2');
  }

  test(
    'fillTemplateString_resolvesRelativeReferences',
    () => checkRelativeOutput(itext: false),
  );

  test(
    'fillTemplateString_resolvesRelativeReferences_inItext',
    () => checkRelativeOutput(itext: true),
  );

  test('canAddFunctionHandlersBeforeInitialize', () async {
    final formDef = await XFormParser().parse(
      html(
        head([
          title('custom-func-form'),
          model([
            mainInstance([
              t('data', [t('calculate'), t('input')]),
            ]),
            bind('/data/calculate')
              ..type('string')
              ..calculate('custom-func()'),
          ]),
        ]),
        body([
          input('/data/input', [label('/data/calculate')]),
        ]),
      ).asXml(),
    );

    formDef.evaluationContext.addFunctionHandler(_CustomFunc());

    Scenario.fromFormDef(formDef);
  });
}
