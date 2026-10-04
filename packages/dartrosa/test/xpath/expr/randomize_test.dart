// Port of JavaRosa v6.0.0 RandomizeTest.
@TestOn('vm')
library;

import 'package:dartrosa/src/codec/form_def_codec.dart';
import 'package:dartrosa/src/form_api/form_entry_prompt.dart';
import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/model/form_index.dart';
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:dartrosa/src/model/select_choice.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

import '../../support/forms.dart';

/// JavaRosa's `writeExternal`/`readExternal` round trip, as a
/// [FormDefCodec] round trip.
Future<FormDef> serializeAndDeserializeForm(FormDef formDef) =>
    FormDefCodec.decode(FormDefCodec.encode(formDef));

void initializeNewInstance(FormDef formDef) =>
    formDef.initialize(newInstance: true);

FormIndex getFormIndex(FormDef formDef, TreeReference ref) {
  for (var localIndex = 0; localIndex < formDef.children.length; localIndex++) {
    if (formDef.children[localIndex].bind == ref) {
      return FormIndex(localIndex, instanceIndex: 0, reference: ref);
    }
  }
  throw ArgumentError('Reference $ref not found');
}

List<SelectChoice> getSelectChoices(FormDef formDef, String ref) =>
    FormEntryPrompt(formDef, getFormIndex(formDef, getRef(ref))).selectChoices;

Object? getAnswerValue(FormDef formDef, String ref) => FormEntryPrompt(
  formDef,
  getFormIndex(formDef, getRef(ref)),
).answerValue!.value;

bool nodesEqualInOrder(List<SelectChoice> left, List<SelectChoice> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i].value != right[i].value) return false;
  }
  return true;
}

void main() {
  // Take a look to the form file:
  //  - The first pair of fields use randomize without a seed.
  //  - The second pair of fields use randomize with a seed.
  late FormDef formDef;
  setUp(() async => formDef = await parseForm('randomize.xml'));

  test(
    'fields_without_seed_in_the_same_form_get_a_different_order_of_choices',
    () {
      initializeNewInstance(formDef);
      final choices1 = getSelectChoices(formDef, '/data/no-seed-fruit1');
      final choices2 = getSelectChoices(formDef, '/data/no-seed-fruit2');

      expect(nodesEqualInOrder(choices1, choices2), isFalse);
    },
  );

  test(
    'the_same_field_without_seed_in_different_instances_gets_a_different_order_of_choices',
    () {
      initializeNewInstance(formDef);
      final choices1 = getSelectChoices(formDef, '/data/no-seed-fruit1');

      initializeNewInstance(formDef);
      final choices2 = getSelectChoices(formDef, '/data/no-seed-fruit1');

      expect(nodesEqualInOrder(choices1, choices2), isFalse);
    },
  );

  test('seeded_fields_in_the_same_form_get_the_same_order_of_choices', () {
    initializeNewInstance(formDef);
    final choices1 = getSelectChoices(formDef, '/data/static-seed-fruit1');
    final choices2 = getSelectChoices(formDef, '/data/static-seed-fruit2');

    expect(nodesEqualInOrder(choices1, choices2), isTrue);
  });

  test(
    'the_same_seeded_field_in_different_instances_gets_the_same_order_of_choices',
    () {
      initializeNewInstance(formDef);
      final choices1 = getSelectChoices(formDef, '/data/static-seed-fruit2');

      initializeNewInstance(formDef);
      final choices2 = getSelectChoices(formDef, '/data/static-seed-fruit2');

      expect(nodesEqualInOrder(choices1, choices2), isTrue);
    },
  );

  test(
    'the_same_seeded_field_in_different_instances_from_deserialized_forms_gets_the_same_order_of_choices',
    () async {
      initializeNewInstance(formDef);
      final choices1 = getSelectChoices(formDef, '/data/static-seed-fruit2');

      final formDefAfterSerialization = await serializeAndDeserializeForm(
        formDef,
      );

      initializeNewInstance(formDefAfterSerialization);
      final choices2 = getSelectChoices(
        formDefAfterSerialization,
        '/data/static-seed-fruit2',
      );

      expect(nodesEqualInOrder(choices1, choices2), isTrue);
    },
  );

  test(
    'randomize_function_can_be_used_outside_itemset_nodeset_definitions',
    () {
      initializeNewInstance(formDef);
      // The ref /data/randomValue is the max from a randomized nodeset of
      // numbers from 1 to 6
      expect(getAnswerValue(formDef, '/data/no-seed-random-value'), 6);
    },
  );

  test(
    'seeded_randomize_function_can_be_used_outside_itemset_nodeset_definitions',
    () {
      initializeNewInstance(formDef);
      // The ref /data/seededRandomValue is the max from a randomized nodeset
      // of numbers from 1 to 6
      expect(getAnswerValue(formDef, '/data/static-seed-random-value'), 6);
    },
  );

  test('randomize_function_can_take_a_seed_from_a_nodeset', () {
    initializeNewInstance(formDef);
    // The ref /data/seededRandomValue is the max from a randomized nodeset of
    // numbers from 1 to 6
    expect(getAnswerValue(formDef, '/data/nodeset-seed-random-value'), 6);
  });

  test('fields_can_take_their_randomize_seeds_from_a_nodeset', () async {
    initializeNewInstance(formDef);
    final choices1a = getSelectChoices(formDef, '/data/nodeset-seed-fruit1');
    final choices2a = getSelectChoices(formDef, '/data/nodeset-seed-fruit2');

    initializeNewInstance(formDef);
    final choices1b = getSelectChoices(formDef, '/data/nodeset-seed-fruit1');
    final choices2b = getSelectChoices(formDef, '/data/nodeset-seed-fruit2');

    final formDefAfterSerialization = await serializeAndDeserializeForm(
      formDef,
    );

    initializeNewInstance(formDef);
    final choices1c = getSelectChoices(
      formDefAfterSerialization,
      '/data/nodeset-seed-fruit1',
    );
    final choices2c = getSelectChoices(
      formDefAfterSerialization,
      '/data/nodeset-seed-fruit2',
    );

    expect(nodesEqualInOrder(choices1a, choices2a), isTrue);
    expect(nodesEqualInOrder(choices1a, choices1b), isTrue);
    expect(nodesEqualInOrder(choices1a, choices1c), isTrue);
    expect(nodesEqualInOrder(choices2a, choices2b), isTrue);
    expect(nodesEqualInOrder(choices2a, choices2c), isTrue);
  });
}
