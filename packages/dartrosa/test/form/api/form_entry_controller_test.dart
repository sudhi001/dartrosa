// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (FormEntryControllerTest), Copyright (C) 2009 JavaRosa
//  and contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 FormEntryControllerTest.
import 'package:dartrosa/src/form_api/form_entry_controller.dart';
import 'package:dartrosa/src/form_api/form_entry_model.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  test('jumpToNewRepeatPrompt_whenInRepeat_jumpsToRepeatPrompt', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('form'),
          model([
            mainInstance([
              t('data', [
                t('repeat', [t('question1'), t('question2')]),
              ]),
            ]),
            bind('/data/repeat/question1')..type('int'),
            bind('/data/repeat/question2')..type('int'),
          ]),
        ]),
        body([
          formGroup('/data/repeat', [
            repeat('/data/repeat', [
              input('/data/repeat/question1'),
              input('/data/repeat/question2'),
            ]),
          ]),
        ]),
      ),
    );

    final controller = FormEntryController(FormEntryModel(scenario.formDef));

    expect(controller.stepToNextEvent(), FormEntryEvent.repeat);
    expect(controller.stepToNextEvent(), FormEntryEvent.question);
    expect(
      controller.model.formIndex.reference,
      getRef('/data/repeat[1]/question1[1]'),
    );

    controller.jumpToNewRepeatPrompt();
    expect(controller.model.formIndex.reference, getRef('/data/repeat[2]'));
  });

  XFormsElement nestedRepeatForm() => html(
    head([
      title('form'),
      model([
        mainInstance([
          t('data', [
            t('repeat1', [
              t('question1'),
              t('question2'),
              t('repeat2', [t('question3')]),
            ]),
          ]),
        ]),
        bind('/data/repeat1/question1')..type('int'),
        bind('/data/repeat1/question2')..type('int'),
        bind('/data/repeat1/repeat2/question3')..type('int'),
      ]),
    ]),
    body([
      formGroup('/data/repeat1', [
        repeat('/data/repeat1', [
          input('/data/repeat1/question1'),
          input('/data/repeat1/question2'),
          formGroup('/data/repeat1/repeat2', [
            repeat('/data/repeat1/repeat2', [
              input('/data/repeat1/repeat2/question3'),
            ]),
          ]),
        ]),
      ]),
    ]),
  );

  test(
    'jumpToNewRepeatPrompt_whenInOuterOfNestedRepeat_jumpsToOuterRepeatPrompt',
    () async {
      final scenario = await Scenario.init(nestedRepeatForm());

      final controller = FormEntryController(FormEntryModel(scenario.formDef));

      expect(controller.stepToNextEvent(), FormEntryEvent.repeat);
      expect(controller.stepToNextEvent(), FormEntryEvent.question);
      expect(
        controller.model.formIndex.reference,
        getRef('/data/repeat1[1]/question1[1]'),
      );

      controller.jumpToNewRepeatPrompt();
      expect(controller.model.formIndex.reference, getRef('/data/repeat1[2]'));
    },
  );

  test(
    'jumpToNewRepeatPrompt_whenInInnerOfNestedRepeat_jumpsToInnerRepeatPrompt',
    () async {
      final scenario = await Scenario.init(nestedRepeatForm());

      final controller = FormEntryController(FormEntryModel(scenario.formDef));

      expect(controller.stepToNextEvent(), FormEntryEvent.repeat);
      expect(controller.stepToNextEvent(), FormEntryEvent.question);
      expect(controller.stepToNextEvent(), FormEntryEvent.question);
      expect(controller.stepToNextEvent(), FormEntryEvent.repeat);
      expect(controller.stepToNextEvent(), FormEntryEvent.question);
      expect(
        controller.model.formIndex.reference,
        getRef('/data/repeat1[1]/repeat2[1]/question3[1]'),
      );

      controller.jumpToNewRepeatPrompt();
      expect(
        controller.model.formIndex.reference,
        getRef('/data/repeat1[1]/repeat2[2]'),
      );
    },
  );

  test(
    'jumpToNewRepeatPrompt_whenInGroupInRepeat_jumpsToRepeatPrompt',
    () async {
      final scenario = await Scenario.init(
        html(
          head([
            title('form'),
            model([
              mainInstance([
                t('data', [
                  t('repeat', [
                    t('group', [t('question1'), t('question2')]),
                  ]),
                ]),
              ]),
              bind('/data/repeat/group/question1')..type('int'),
              bind('/data/repeat/group/question1')..type('int'),
            ]),
          ]),
          body([
            formGroup('/data/repeat', [
              repeat('/data/repeat', [
                formGroup('/data/repeat/group', [
                  input('/data/repeat/group/question1'),
                  input('/data/repeat/group/question2'),
                ]),
              ]),
            ]),
          ]),
        ),
      );

      final controller = FormEntryController(FormEntryModel(scenario.formDef));

      expect(controller.stepToNextEvent(), FormEntryEvent.repeat);
      expect(controller.stepToNextEvent(), FormEntryEvent.group);
      expect(controller.stepToNextEvent(), FormEntryEvent.question);
      expect(
        controller.model.formIndex.reference,
        getRef('/data/repeat[1]/group[1]/question1[1]'),
      );

      controller.jumpToNewRepeatPrompt();
      expect(controller.model.formIndex.reference, getRef('/data/repeat[2]'));
    },
  );

  test('jumpToNewRepeatPrompt_whenNotInRepeat_doesNothing', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('form'),
          model([
            mainInstance([
              t('data', [t('question1'), t('question2')]),
            ]),
            bind('/data/question1')..type('int'),
            bind('/data/question1')..type('int'),
          ]),
        ]),
        body([input('/data/question1'), input('/data/question2')]),
      ),
    );

    final controller = FormEntryController(FormEntryModel(scenario.formDef));
    expect(controller.stepToNextEvent(), FormEntryEvent.question);
    expect(controller.model.formIndex.reference, getRef('/data/question1[1]'));

    controller.jumpToNewRepeatPrompt();
    expect(controller.model.formIndex.reference, getRef('/data/question1[1]'));
  });
}
