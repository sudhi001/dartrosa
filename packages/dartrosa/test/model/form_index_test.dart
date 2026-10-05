// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (FormIndexTest), Copyright (C) 2009 JavaRosa and
//  contributors; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 FormIndexTest.
import 'package:dartrosa/src/model/form_index.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  test('getPreviousLevel_atBeginningOfForm_returnsNull', () {
    expect(FormIndex.beginningOfForm().previousLevel, isNull);
  });

  test('getPreviousLevel_atTheTopLevelOfTheForm_returnsNull', () {
    final formIndex = FormIndex(0, reference: getRef('/data/question'));
    expect(formIndex.previousLevel, isNull);
  });

  test('getPreviousLevel_forIndexInGroup_returnsGroup', () {
    final groupThenQuestionIndex = FormIndex(
      7,
      nextLevel: FormIndex(0, reference: getRef('/data/group/question')),
      reference: getRef('/data/group'),
    );

    final groupIndex = FormIndex(7, reference: getRef('/data/group'));
    expect(groupThenQuestionIndex.previousLevel, groupIndex);
  });

  test('getPreviousLevel_forIndexInNestedGroup_returnsInnerGroup', () {
    final groupThenGroupThenQuestionIndex = FormIndex(
      1,
      nextLevel: FormIndex(
        5,
        nextLevel: FormIndex(
          0,
          reference: getRef('/data/outer_group/inner_group/question'),
        ),
        reference: getRef('/data/outer_group/inner_group'),
      ),
      reference: getRef('/data/outer_group'),
    );

    final innerGroupIndex = FormIndex(
      1,
      nextLevel: FormIndex(
        5,
        reference: getRef('/data/outer_group/inner_group'),
      ),
      reference: getRef('/data/outer_group'),
    );
    expect(groupThenGroupThenQuestionIndex.previousLevel, innerGroupIndex);
  });

  test('getPreviousLevel_forRepeatIndex_returnsNull', () {
    final repeatIndex = FormIndex(
      0,
      instanceIndex: 2,
      reference: getRef('/data/repeat[2]'),
    );

    expect(repeatIndex.previousLevel, isNull);
  });

  test('getPreviousLevel_forIndexInRepeat_returnsRepeatWithMultiplicity', () {
    final repeatThenQuestionIndex = FormIndex(
      7,
      instanceIndex: 2,
      nextLevel: FormIndex(0, reference: getRef('/data/repeat[2]/question')),
      reference: getRef('/data/repeat[2]'),
    );

    final repeatIndex = FormIndex(
      7,
      instanceIndex: 2,
      reference: getRef('/data/repeat[2]'),
    );
    expect(repeatThenQuestionIndex.previousLevel, repeatIndex);
  });

  test(
    'getPreviousLevel_forIndexInNestedRepeat_returnsInnerRepeatWithMultiplicity',
    () {
      final repeatThenRepeatThenQuestionIndex = FormIndex(
        7,
        instanceIndex: 2,
        nextLevel: FormIndex(
          0,
          instanceIndex: 3,
          nextLevel: FormIndex(
            0,
            reference: getRef('/data/repeat[2]/repeat[3]/question'),
          ),
          reference: getRef('/data/repeat[2]/question'),
        ),
        reference: getRef('/data/repeat[2]'),
      );

      final innerRepeatIndex = FormIndex(
        7,
        instanceIndex: 2,
        nextLevel: FormIndex(
          0,
          instanceIndex: 3,
          reference: getRef('/data/repeat[2]/repeat[3]'),
        ),
        reference: getRef('/data/repeat[2]'),
      );
      expect(repeatThenRepeatThenQuestionIndex.previousLevel, innerRepeatIndex);
    },
  );
}
