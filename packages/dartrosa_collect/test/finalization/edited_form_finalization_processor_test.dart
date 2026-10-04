// DartRosa tests of EditedFormFinalizationProcessor, following the
// meta-ID assertions of Collect's EditSavedFormTest (Collect has no unit
// tests for the processor or Instance.isEdit).
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:test/test.dart';

import '../collect_test_forms.dart';

final _instanceId = RegExp('<instanceID>([^<]*)</instanceID>');
final _deprecatedId = RegExp('<deprecatedID>([^<]*)</deprecatedID>');

(String?, String?) metaIds(String xml) => (
  _instanceId.firstMatch(xml)?.group(1),
  _deprecatedId.firstMatch(xml)?.group(1),
);

void main() {
  late FormDefinition definition;
  var uuids = 0;

  setUp(() async {
    uuids = 0;
    definition = await FormDefinition.parse(
      forms['one-question-editable.xml']!,
      config: DartRosaConfig(
        finalizationProcessors: [
          EditedFormFinalizationProcessor(uuid: () => 'edit-${++uuids}'),
        ],
      ),
    );
  });

  String fill(FormSession session, int age) {
    final question = session.root.children.first as QuestionNode;
    session.answer(question.index, IntegerValue(age));
    final result = session.finalize();
    return (result as FinalizeSuccess).submission.xml;
  }

  test('editingAFinalizedForm_createsANewFormAndKeepsTheOriginalOneIntact', () {
    final first = fill(definition.createSession(), 123);
    final edit = definition.createSession(existingInstance: first);
    const InstanceEdit(editOf: 1, editNumber: 1).markSession(edit);
    final second = fill(edit, 456);

    expect(first, contains('<age>123</age>'));
    expect(second, contains('<age>456</age>'));
    final (firstFormInstanceID, firstFormDeprecatedID) = metaIds(first);
    final (secondFormInstanceID, secondFormDeprecatedID) = metaIds(second);
    expect(firstFormDeprecatedID, isNull);
    expect(firstFormInstanceID, startsWith('uuid:'));
    expect(secondFormDeprecatedID, firstFormInstanceID);
    expect(secondFormInstanceID, 'uuid:edit-1');
  });

  test('an edit of an edit deprecates the previous edit', () {
    final first = fill(definition.createSession(), 1);
    final edit1 = definition.createSession(existingInstance: first);
    const InstanceEdit(editOf: 1, editNumber: 1).markSession(edit1);
    final second = fill(edit1, 2);
    final edit2 = definition.createSession(existingInstance: second);
    const InstanceEdit(editOf: 1, editNumber: 2).markSession(edit2);
    final third = fill(edit2, 3);
    expect(metaIds(third), ('uuid:edit-2', 'uuid:edit-1'));
  });

  test('instances that are not edits are left alone', () {
    final first = fill(definition.createSession(), 123);
    final reopened = definition.createSession(existingInstance: first);
    final again = fill(reopened, 124);
    expect(metaIds(again), (metaIds(first).$1, null));
    expect(uuids, 0);
  });

  test('isEdit can be decided by the app', () async {
    final definition = await FormDefinition.parse(
      forms['one-question-editable.xml']!,
      config: DartRosaConfig(
        finalizationProcessors: [
          EditedFormFinalizationProcessor(isEdit: (_) => true, uuid: () => 'x'),
        ],
      ),
    );
    final xml = fill(definition.createSession(), 5);
    expect(metaIds(xml).$1, 'uuid:x');
    expect(metaIds(xml).$2, startsWith('uuid:'));
  });

  test('Instance.isEdit', () {
    expect(isEdit(editOf: null), isFalse);
    expect(isEdit(editOf: 3), isTrue);
  });
}
