// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (ChildVaccinationTest), Copyright 2020 Nafundi;
//  modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

// Port of JavaRosa v6.0.0 ChildVaccinationTest.
@TestOn('vm')
library;

import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../support/forms.dart';

final dobDayMonthType1Ref = getRef('/data/household/child_repeat/dob_day_1');
final dobDayMonthType2Ref = getRef('/data/household/child_repeat/dob_day_2');
final dobDayMonthType3Ref = getRef('/data/household/child_repeat/dob_day_3');
final dobDayMonthType4Ref = getRef('/data/household/child_repeat/dob_day_4');
final dobAgeInMonthsRef = getRef('/data/household/child_repeat/age_months');
final vaccinationPenta1Ref = getRef('/data/household/child_repeat/penta1');
final vaccinationPenta3Ref = getRef('/data/household/child_repeat/penta3');
final vaccinationMeaslesRef = getRef('/data/household/child_repeat/mcv1');
final childRepeatRef = getRef('/data/household/child_repeat');
final notEligNoteRef = getRef('/data/household/child_repeat/not_elig_note');
final nextChildRef = getRef('/data/household/child_repeat/nextChild');
final nextChildNoMotherRef = getRef(
  '/data/household/child_repeat/nextChild_no_mother',
);
final newHouseholdRepeatJunctionRef = getRef('/data/household');
final finalFlatRef = getRef('/data/household/finalflat');
final finishedFormRef = getRef('/data/household/finished2');

/// Java's `LocalDate.now()`.
final today = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}();

/// Java's `LocalDate.minusMonths` (clamping the day to the month's length).
DateTime minusMonths(DateTime date, int months) {
  final total = date.year * 12 + date.month - 1 - months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
}

/// Java's `start.until(end).getMonths()` (the months part of the period).
int periodMonths(DateTime start, DateTime end) {
  var total = (end.year - start.year) * 12 + end.month - start.month;
  if (total > 0 && end.day < start.day) total--;
  if (total < 0 && end.day > start.day) total++;
  return total.remainder(12);
}

TreeReference genericNextRef(Scenario scenario) =>
    scenario.nextRef()!.genericize();

enum Vaccines {
  none(false, false, false),
  diphteriaFirst(true, false, false),
  diphteria(true, true, false),
  measles(false, false, true),
  diphteriaFirstAndMeasles(true, false, true),
  diphteriaAndMeasles(true, true, true);

  const Vaccines(
    this.hasDiphteriaFirst,
    this.hasDiphteriaThird,
    this.hasMeasles,
  );

  final bool hasDiphteriaFirst;
  final bool hasDiphteriaThird;
  final bool hasMeasles;

  static List<TreeReference> get endOfVisitRefs => [
    nextChildRef,
    finalFlatRef,
    childRepeatRef,
  ];

  void visit(Scenario scenario) {
    // Answer questions until there's no more vaccination related questions
    while (!endOfVisitRefs.contains(genericNextRef(scenario))) {
      scenario.next();
      final ref = scenario.refAtIndex!.genericize();
      if (ref == vaccinationPenta1Ref) {
        scenario.answerCurrent(hasDiphteriaFirst ? 'yes' : 'no');
      } else if (ref == vaccinationPenta3Ref) {
        scenario.answerCurrent(hasDiphteriaThird ? 'yes' : 'no');
      } else if (ref == vaccinationMeaslesRef) {
        scenario.answerCurrent(hasMeasles ? 'yes' : 'no');
      }
    }
  }
}

enum HealthRecord {
  healthHandbook,
  vaccinationCard,
  healthClinic;

  void visit(Scenario scenario) {
    switch (this) {
      case healthHandbook:
        scenario
          ..next()
          ..answerCurrent('yes');
      case vaccinationCard:
        scenario
          ..next()
          ..answerCurrent('no')
          ..next()
          ..answerCurrent('yes');
      case healthClinic:
        scenario
          ..next()
          ..answerCurrent('no')
          ..next()
          ..answerCurrent('no')
          ..next()
          ..answerCurrent('yes');
    }
  }
}

enum Sex {
  female('female'),
  male('male');

  const Sex(this.name);

  final String name;
}

typedef Child = void Function(int i);

void main() {
  test('smoke_test', () async {
    final scenario = await scenarioFor('child_vaccination_VOL_tool_v12.xml');

    void finishChild() {
      if ([
        nextChildRef,
        nextChildNoMotherRef,
      ].contains(genericNextRef(scenario))) {
        scenario.next();
      } else if (genericNextRef(scenario) != finalFlatRef) {
        fail(
          'Unexpected next ref '
          '${scenario.nextRef()!.toString(includePredicates: true, zeroIndexMultiplicity: true)}'
          ' at index',
        );
      }
    }

    void answerDateOfBirth(DateTime dob) {
      scenario
        // Is DoB known?
        ..next()
        ..answerCurrent('yes')
        // Year in DoB
        ..next()
        ..answerCurrent(dob.year)
        // Month in DoB
        ..next()
        ..answerCurrent(dob.month)
        // Day in DoB
        ..next()
        ..answerCurrent(dob.day);
    }

    void answerAgeInMonths(int ageInMonths) {
      scenario
        // Is DoB known?
        ..next()
        ..answerCurrent('no')
        // Age in months
        ..next()
        ..answerCurrent(ageInMonths);
    }

    Child answerChildWithDob(
      HealthRecord healthRecord,
      DateTime dob,
      Vaccines vaccines,
      Sex sex,
    ) => (i) {
      final ageInMonths = periodMonths(dob, today);
      final name = 'CHILD $i - Age $ageInMonths months - ${sex.name}';
      scenario
        ..trace(name)
        ..next()
        ..next()
        ..answerCurrent(name);
      healthRecord.visit(scenario);
      scenario
        ..next()
        ..answerCurrent(sex.name);
      answerDateOfBirth(dob);
      if (genericNextRef(scenario) == notEligNoteRef) {
        scenario.next();
      } else if (genericNextRef(scenario) == vaccinationPenta1Ref) {
        vaccines.visit(scenario);
      }
      finishChild();
    };

    Child answerChildWithAge(
      HealthRecord healthRecord,
      int ageInMonths,
      Vaccines vaccines,
      Sex sex,
    ) => (i) {
      final name = 'CHILD $i - Age $ageInMonths months - ${sex.name}';
      scenario
        ..trace(name)
        ..next()
        ..next()
        ..answerCurrent(name);
      healthRecord.visit(scenario);
      scenario
        ..next()
        ..answerCurrent(sex.name);
      answerAgeInMonths(ageInMonths);
      if (genericNextRef(scenario) == vaccinationPenta1Ref) {
        vaccines.visit(scenario);
      }
      finishChild();
    };

    List<Child> buildChildrenWithIntegers(
      int ageInMonths,
      HealthRecord healthRecord,
    ) => [
      answerChildWithAge(healthRecord, ageInMonths, Vaccines.none, Sex.male),
      answerChildWithAge(
        healthRecord,
        ageInMonths,
        Vaccines.diphteriaFirst,
        Sex.female,
      ),
      answerChildWithAge(
        healthRecord,
        ageInMonths,
        Vaccines.diphteria,
        Sex.male,
      ),
      answerChildWithAge(
        healthRecord,
        ageInMonths,
        Vaccines.measles,
        Sex.female,
      ),
      answerChildWithAge(
        healthRecord,
        ageInMonths,
        Vaccines.diphteriaFirstAndMeasles,
        Sex.male,
      ),
      answerChildWithAge(
        healthRecord,
        ageInMonths,
        Vaccines.diphteriaAndMeasles,
        Sex.female,
      ),
    ];

    List<Child> buildChildrenWithLocalDates(
      int ageInMonths,
      HealthRecord healthRecord,
    ) {
      final dob = minusMonths(today, ageInMonths);
      return [
        answerChildWithDob(healthRecord, dob, Vaccines.none, Sex.female),
        answerChildWithDob(
          healthRecord,
          dob,
          Vaccines.diphteriaFirst,
          Sex.male,
        ),
        answerChildWithDob(healthRecord, dob, Vaccines.diphteria, Sex.female),
        answerChildWithDob(healthRecord, dob, Vaccines.measles, Sex.male),
        answerChildWithDob(
          healthRecord,
          dob,
          Vaccines.diphteriaFirstAndMeasles,
          Sex.female,
        ),
        answerChildWithDob(
          healthRecord,
          dob,
          Vaccines.diphteriaAndMeasles,
          Sex.male,
        ),
      ];
    }

    // Builds every possible combination of meaningful ages (23, 6 and 3
    // months), supported ways of defining the age (a decomposed date of
    // birth or a number of months) and vaccination records (no vaccines,
    // first and third diphteria shot, measles shot). These combinations
    // ensure that all critical paths for the provided health record type are
    // taken while filling out a child group. Since the form's limit to the
    // number of children per household is 10, this returns a list entry per
    // every 6 children (the possible permutations of vaccine sets).
    List<List<Child>> buildHouseholdChildren(HealthRecord healthRecord) => [
      buildChildrenWithLocalDates(23, healthRecord),
      buildChildrenWithIntegers(23, healthRecord),
      buildChildrenWithLocalDates(6, healthRecord),
      buildChildrenWithIntegers(6, healthRecord),
      buildChildrenWithLocalDates(3, healthRecord),
      buildChildrenWithIntegers(3, healthRecord),
    ];

    void answerHousehold(int number, List<Child> children) {
      // region Answer info about the household
      scenario
        ..trace('HOUSEHOLD $number')
        ..next()
        ..next()
        ..answerCurrent(number)
        // Does someone answer the door?
        ..next()
        ..answerCurrent('yes')
        // Is there an adult
        ..next()
        ..answerCurrent('yes')
        // Do children under 2 live in the house?
        ..next()
        ..answerCurrent('yes')
        // What's the mother's or caregiver's name
        ..next()
        ..answerCurrent('Foo')
        // Is the mother or caregiver present?
        ..next()
        ..answerCurrent('yes')
        // Give consent
        ..next()
        ..answerCurrent('yes')
        // endregion
        // How many children under 2?
        ..next()
        ..answerCurrent(children.length);

      for (var i = 0; i < children.length; i++) {
        children[i](i);
      }

      scenario.trace('END CHILDREN');
    }

    // region Answer questions about the building
    scenario
      ..next()
      ..answerCurrent('multi')
      ..next()
      ..next()
      // an accuracy of 0m or greater than 5m makes a second geopoint
      // question relevant
      ..answerCurrent('1.234 5.678 0 2.3')
      ..next()
      ..answerCurrent('Some building')
      ..next()
      ..answerCurrent('Some address, some location');
    // endregion

    // region Answer all household repeats

    // Create all possible permutations of children combining all health
    // record types, meaningful ages, ways to define age, and vaccination
    // sets, which amounts to 18 households and 108 children
    final households = [
      for (final healthRecord in HealthRecord.values)
        ...buildHouseholdChildren(healthRecord),
    ];

    for (var i = 0; i < households.length; i++) {
      final children = households[i];
      expect(genericNextRef(scenario), newHouseholdRepeatJunctionRef);
      answerHousehold(i, children);
      // We just want to make sure that we are in a valid position without
      // going into more detail. Due to the conditional nature of this form,
      // it would be too complex to describe that in a test with all the
      // precission in a test like this one that will follow all possible
      // branches.
      expect(
        scenario.refAtIndex!.genericize(),
        anyOf([
          // Either we stopped after filling the age with a decomposed date
          dobDayMonthType1Ref,
          dobDayMonthType2Ref,
          dobDayMonthType3Ref,
          dobDayMonthType4Ref,
          // Or we stopped after filling the age in months
          dobAgeInMonthsRef,
          // Or we stopped after answering any of the vaccination questions
          vaccinationPenta1Ref,
          vaccinationPenta3Ref,
          vaccinationMeaslesRef,
          // Or we answered all questions
          nextChildRef,
        ]),
      );
      scenario.next();
      expect(scenario.refAtIndex!.genericize(), finalFlatRef);
      if (i + 1 < households.length) {
        scenario
          ..answerCurrent('no')
          ..next();
      } else {
        scenario.answerCurrent('yes');
      }
    }

    scenario.trace('END HOUSEHOLDS');

    // endregion

    // region Go to the end of the form

    scenario.next();
    expect(scenario.refAtIndex!.genericize(), finishedFormRef);
    scenario.next();

    // endregion
  });
}
