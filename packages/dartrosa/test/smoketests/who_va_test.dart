// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (WhoVATest), Copyright 2020 Nafundi; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 WhoVATest.
@TestOn('vm')
library;

import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';
import '../support/matchers.dart';

void main() {
  test('regression_after_2_17_0_relevance_updates', () async {
    final scenario = await scenarioFor('whova_form.xml');

    // region Give consent to unblock the rest of the form
    // (Id10013) [Did the respondent give consent?]
    // ref:/data/respondent_backgr/Id10013
    scenario
      ..next(14)
      ..answerCurrent('yes')
      // endregion
      // region Info on deceased
      // (Id10019) What was the sex of the deceased?
      ..next(6)
      ..answerCurrent('female')
      // (Id10020) Is the date of birth known?
      ..next()
      ..answerCurrent('yes')
      // (Id10021) When was the deceased born?
      ..next()
      ..answerCurrent(DateTime(1998))
      // (Id10022) Is the date of death known?
      ..next()
      ..answerCurrent('yes')
      // (Id10021) When was the deceased born?
      ..next()
      ..answerCurrent(DateTime(2018));
    // endregion

    // Regression happens here: we changed FormInstanceParser to add all
    // descendants of a group as targets of a relevance condition defined in
    // that group.
    //
    // When a field inside the group has also a relevance condition, then we
    // have two equipotent condition triggerables in the DAG that will update
    // the field's relevance, which may set it in unexpected ways. In this
    // form, the Id10120_0 should be irrelevant at this point, but some
    // relevance expression declared in an ancestor group is making it
    // relevant.
    //
    // In v2.17.0, we compute the descendant targets just in time, which makes
    // the condition triggerables not equipotent, ensuring that the one
    // declared in the field will be evaluated last, producing the expected
    // relevance state.
    expect(
      scenario.getAnswerNode('/data/consented/illhistory/illdur/Id10120_0'),
      nonRelevant,
    );
  });

  test('smoke_test_route_fever_and_lumps', () async {
    final scenario = await scenarioFor('whova_form.xml');

    void answerNo(int times) {
      for (var n = 0; n < times; n++) {
        scenario.next();
        if (scenario.atQuestion) scenario.answerCurrent('no');
      }
    }

    void expectAt(String xPath) =>
        expect(scenario.refAtIndex!.genericize(), getRef(xPath));

    // region Give consent to unblock the rest of the form
    // (Id10013) [Did the respondent give consent?]
    scenario.next(14);
    expectAt('/data/respondent_backgr/Id10013');
    scenario.answerCurrent('yes');
    // endregion

    // region Info on deceased
    // (Id10019) What was the sex of the deceased?
    scenario.next(6);
    expectAt('/data/consented/deceased_CRVS/info_on_deceased/Id10019');
    scenario
      ..answerCurrent('female')
      // (Id10020) Is the date of birth known?
      ..next()
      ..answerCurrent('yes')
      // (Id10021) When was the deceased born?
      ..next()
      ..answerCurrent(DateTime(1998))
      // (Id10022) Is the date of death known?
      // This question triggers one of the longest evaluation chain of
      // triggerables including 5 calculations
      ..next()
      ..answerCurrent('yes')
      // (Id10021) When was the deceased born?
      ..next()
      ..answerCurrent(DateTime(2018));

    // Sanity check about age and isAdult field
    expect(
      scenario.answerOf(
        '/data/consented/deceased_CRVS/info_on_deceased/ageInDays',
      ),
      intAnswer(7305),
    );
    expect(
      scenario.answerOf(
        '/data/consented/deceased_CRVS/info_on_deceased/isAdult',
      ),
      stringAnswer('1'),
    );
    expect(
      scenario.answerOf(
        '/data/consented/deceased_CRVS/info_on_deceased/isNeonatal',
      ),
      stringAnswer('0'),
    );

    // Skip a bunch of non yes/no questions
    scenario.next(11);
    expectAt('/data/consented/illhistory/illdur/id10120_unit');

    // Answer no to the rest of questions
    answerNo(23);
    // endregion

    // region Signs and symptoms - fever
    // (Id10147) Did (s)he have a fever?
    scenario.next();
    expectAt('/data/consented/illhistory/signs_symptoms_final_illness/Id10147');
    scenario
      ..answerCurrent('yes')
      // (Id10148_units) How long did the fever last?
      ..next()
      ..answerCurrent('days')
      // (Id10148_b) [Enter how long the fever lasted in days]:
      ..next()
      ..answerCurrent(30)
      // (Id10149) Did the fever continue until death?
      ..next()
      ..answerCurrent('yes')
      // (Id10150) How severe was the fever?
      ..next()
      ..answerCurrent('severe')
      // (Id10151) What was the pattern of the fever?
      ..next()
      ..answerCurrent('nightly');
    expectAt('/data/consented/illhistory/signs_symptoms_final_illness/Id10151');
    // endregion

    // region Answer "no" until we get to the lumps group
    answerNo(36);
    // endregion

    // region Signs and symptoms - lumps
    // (Id10253) Did (s)he have any lumps?
    scenario.next();
    expectAt('/data/consented/illhistory/signs_symptoms_final_illness/Id10253');
    scenario
      ..answerCurrent('yes')
      // (Id10254) Did (s)he have any lumps or lesions in the mouth?
      ..next()
      ..answerCurrent('yes')
      // (Id10255) Did (s)he have any lumps on the neck?
      ..next()
      ..answerCurrent('yes')
      // (Id10256) Did (s)he have any lumps on the armpit?
      ..next()
      ..answerCurrent('yes')
      // (Id10257) Did (s)he have any lumps on the groin?
      ..next()
      ..answerCurrent('yes');
    expectAt('/data/consented/illhistory/signs_symptoms_final_illness/Id10257');
    // endregion

    // region Answer "no" to almost the end of the form
    answerNo(59);
    // endregion

    // region Answer the last question with comments
    scenario.next();
    expectAt('/data/consented/comment');
    scenario
      ..answerCurrent('No comments')
      ..next();
    expect(scenario.atTheEndOfForm, isTrue);
    // endregion
  });
}
