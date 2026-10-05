// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Ports of Collect's DownloadMediaFilesServerFormUseCasesTest (last-saved
// cases) and FormUpdateTest.whenAnUpdatedFormIsDownloaded_copyLastSaved
// FileFromPreviousFormVersion, plus DartRosa tests of LastSaved.
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:test/test.dart';

import '../collect_test_forms.dart';

Future<FormSession> open(String xml, LastSaved lastSaved) async {
  final definition = await FormDefinition.parse(
    xml,
    config: DartRosaConfig(
      lastSavedSrc: LastSaved.src,
      resolver: lastSaved.resolver(MapResourceResolver(const {})),
    ),
  );
  return definition.createSession();
}

QuestionNode age(FormSession session) =>
    session.root.children.first as QuestionNode;

void main() {
  group('copySavedFileFromPreviousFormVersionIfExists', () {
    test(
      'does not copy any file if there is no matching last-saved file',
      () async {
        final store = InMemoryLastSavedStore();
        await copySavedFileFromPreviousFormVersionIfExists(
          store,
          const [],
          '1',
          'destination',
        );
        expect(await store.read('destination'), isNull);
      },
    );

    test(
      'copies the newest matching last-saved file for given formId',
      () async {
        final store = InMemoryLastSavedStore()
          ..instances.addAll({
            'dir1': 'file1',
            'dir2': 'file2',
            'dir3': 'file3',
            'dir4': 'file4',
          });
        await copySavedFileFromPreviousFormVersionIfExists(
          store,
          const [
            LastSavedFormVersion(formId: '1', date: 0, formKey: 'dir1'),
            LastSavedFormVersion(formId: '1', date: 2, formKey: 'dir2'),
            LastSavedFormVersion(formId: '1', date: 1, formKey: 'dir3'),
            LastSavedFormVersion(formId: '2', date: 3, formKey: 'dir4'),
          ],
          '1',
          'destination',
        );
        expect(await store.read('destination'), 'file2');
      },
    );

    test(
      'the newest version without a last-saved file copies nothing',
      () async {
        final store = InMemoryLastSavedStore()..instances['dir1'] = 'file1';
        await copySavedFileFromPreviousFormVersionIfExists(
          store,
          const [
            LastSavedFormVersion(formId: '1', date: 0, formKey: 'dir1'),
            LastSavedFormVersion(formId: '1', date: 2, formKey: 'dir2'),
          ],
          '1',
          'destination',
        );
        expect(await store.read('destination'), isNull);
      },
    );
  });

  test('without a saved instance, the stub is created and read', () async {
    final store = InMemoryLastSavedStore();
    final session = await open(
      forms['one-question-last-saved.xml']!,
      LastSaved(store, 'v1'),
    );
    expect(age(session).value, isNull);
    expect(store.instances['v1'], LastSaved.stubXml);
  });

  test('the last saved instance prefills the next one', () async {
    final store = InMemoryLastSavedStore();
    final lastSaved = LastSaved(store, 'v1');
    final first = await open(forms['one-question-last-saved.xml']!, lastSaved);
    first.answer(age(first).index, const IntegerValue(32));
    expect(first.finalize(), isA<FinalizeSuccess>());
    await lastSaved.instanceSaved(first);

    final second = await open(forms['one-question-last-saved.xml']!, lastSaved);
    expect(age(second).value?.displayText, '32');
  });

  test(
    'whenAnUpdatedFormIsDownloaded_copyLastSavedFileFromPreviousFormVersion',
    () async {
      final store = InMemoryLastSavedStore();
      final v1 = LastSaved(store, 'one_question_last_saved/1');
      final first = await open(forms['one-question-last-saved.xml']!, v1);
      first.answer(age(first).index, const IntegerValue(32));
      first.finalize();
      await v1.instanceSaved(first);

      // Version 2 is downloaded.
      await copySavedFileFromPreviousFormVersionIfExists(
        store,
        const [
          LastSavedFormVersion(
            formId: 'one_question_last_saved',
            date: 1,
            formKey: 'one_question_last_saved/1',
          ),
        ],
        'one_question_last_saved',
        'one_question_last_saved/2',
      );
      final second = await open(
        forms['one-question-last-saved-updated.xml']!,
        LastSaved(store, 'one_question_last_saved/2'),
      );
      expect(age(second).label.text, 'what is your age?');
      expect(age(second).value?.displayText, '32');
    },
  );

  test('an encrypted finalized instance leaves no last-saved copy', () async {
    final store = InMemoryLastSavedStore()..instances['v1'] = '<data/>';
    await LastSaved(store, 'v1').encryptedInstanceFinalized();
    expect(store.instances, isEmpty);
  });

  test('other resources come from the media resolver', () async {
    final resolver = LastSaved(InMemoryLastSavedStore(), 'v1').resolver(
      MapResourceResolver({
        'jr://file/a.csv': Uint8List.fromList([1, 2]),
      }),
    );
    expect(await resolver.read('jr://file/a.csv'), [1, 2]);
    expect(
      () => resolver.read('jr://file/b.csv'),
      throwsA(isA<ResourceNotFoundException>()),
    );
  });
}
