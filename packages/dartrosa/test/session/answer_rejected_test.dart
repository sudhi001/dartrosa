// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// DartRosa tests: FormSession.answer reads text answers as the question's
// type (as ODK Collect's widgets do) and rejects values that don't fit.
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  late FormSession session;
  late List<QuestionNode> q;
  setUp(() async {
    final xml = html(
      head([
        title('Rejected'),
        model([
          mainInstance([
            t('data id="rejected"', [t('n'), t('d'), t('s'), t('m'), t('txt')]),
          ]),
          bind('/data/n')..type('int'),
          bind('/data/d')..type('date'),
          bind('/data/s')..type('string'),
          bind('/data/m')..type('string'),
          bind('/data/txt')..type('string'),
        ]),
      ]),
      body([
        input('/data/n'),
        input('/data/d'),
        select1('/data/s', [item('a', 'A'), item('b', 'B')]),
        t('select ref="/data/m"', [item('x', 'X'), item('y', 'Y')]),
        input('/data/txt'),
      ]),
    ).asXml();
    session = (await FormDefinition.parse(xml)).createSession();
    q = session.root.children.cast<QuestionNode>();
  });

  test('text is read as the question type', () {
    expect(
      session.answer(q[0].index, const UncastValue(' 42 ')),
      isA<AnswerAccepted>(),
    );
    expect(q[0].value, const IntegerValue(42));
    expect(
      session.answer(q[1].index, const UncastValue('2020-02-29')),
      isA<AnswerAccepted>(),
    );
    expect(q[1].value, isA<DateValue>());
    expect(
      session.answer(q[2].index, const UncastValue('b')),
      isA<AnswerAccepted>(),
    );
    expect(q[2].value?.displayText, 'b');
    expect(
      session.answer(q[3].index, const UncastValue('x y')),
      isA<AnswerAccepted>(),
    );
    expect(q[3].value?.displayText, 'x, y');
    expect(
      session.answer(q[0].index, const UncastValue('')),
      isA<AnswerAccepted>(),
    );
    expect(q[0].value, isNull);
  });

  test('unreadable text, wrong types and unknown choices are rejected', () {
    session.answer(q[0].index, const IntegerValue(7));
    expect(
      session.answer(q[0].index, const UncastValue('abc')),
      isA<AnswerRejected>(),
    );
    expect(
      session.answer(q[0].index, const StringValue('12')),
      isA<AnswerRejected>(),
    );
    expect(
      session.answer(q[0].index, const DecimalValue(2.5)),
      isA<AnswerRejected>(),
    );
    // Rejected answers are not saved.
    expect(q[0].value, const IntegerValue(7));
    expect(
      session.answer(q[1].index, const UncastValue('2020-13-45')),
      isA<AnswerRejected>(),
    );
    expect(
      session.answer(q[2].index, const SelectOneValue(Selection('zzz'))),
      isA<AnswerRejected>().having(
        (r) => r.message,
        'message',
        contains('zzz'),
      ),
    );
    expect(
      session.answer(q[3].index, const UncastValue('x nope')),
      isA<AnswerRejected>(),
    );
    expect(
      session.answer(q[4].index, const IntegerValue(1)),
      isA<AnswerRejected>(),
    );
    // Also without validation.
    expect(
      session.answer(q[0].index, const StringValue('x'), validate: false),
      isA<AnswerRejected>(),
    );
  });
}
