// DartRosa tests of collectFormConfig: the Collect services wired together.
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:test/test.dart';

import 'collect_test_forms.dart';

void main() {
  test('wires last-saved, itemsets and edited form finalization', () async {
    final store = InMemoryLastSavedStore();
    final lastSaved = LastSaved(store, 'editable/1');
    DartRosaConfig config() => collectFormConfig(
      media: MapResourceResolver({
        'jr://file/itemsets.csv': utf8.encode(
          media['selectOneExternal-media/itemsets.csv']!,
        ),
      }),
      lastSaved: lastSaved,
      uuid: () => 'fixed',
    );
    expect(config().lastSavedSrc, LastSaved.src);
    expect(config().plugins.single, isA<FastExternalItemsetsPlugin>());
    expect(
      config().finalizationProcessors.single,
      isA<EditedFormFinalizationProcessor>(),
    );

    final definition = await FormDefinition.parse(
      forms['one-question-editable.xml']!,
      config: config(),
    );
    final session = definition.createSession();
    session.answer(
      (session.root.children.first as QuestionNode).index,
      const IntegerValue(1),
    );
    final first = (session.finalize() as FinalizeSuccess).submission;
    await lastSaved.instanceSaved(session);
    expect(store.instances['editable/1'], contains('<age>1</age>'));

    final edit = definition.createSession(existingInstance: first.xml);
    const InstanceEdit(editOf: 1).markSession(edit);
    final second = (edit.finalize() as FinalizeSuccess).submission;
    expect(second.instanceId, 'uuid:fixed');
    expect(second.xml, contains('<deprecatedID>${first.instanceId}<'));

    final itemsetForm = await FormDefinition.parse(
      forms['selectOneExternal.xml']!,
      config: config(),
    );
    expect(
      itemsetForm.formDef.extras.get<FastExternalItemsets>()?.table,
      isNotNull,
    );
  });

  test('services can be left out', () {
    final config = collectFormConfig(
      media: MapResourceResolver(const {}),
      fastExternalItemsets: false,
      editedFormFinalization: false,
    );
    expect(config.plugins, isEmpty);
    expect(config.finalizationProcessors, isEmpty);
    expect(config.lastSavedSrc, isNull);
  });
}
