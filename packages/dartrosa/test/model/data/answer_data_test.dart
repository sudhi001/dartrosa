// Port of JavaRosa v6.0.0 StringDataTests, IntegerDataTests, DateDataTests,
// TimeDataTests, SelectOneDataTests, MultipleItemsDataTests,
// GeoPointDataTests, GeoShapeDataTest, GeoTraceDataTest and
// DataTypeClassesTest.
//
// JavaRosa's answer data are mutable (setValue), accept null (and throw)
// and wrap mutable java.util.Date / List values, which those tests guard
// with defensive copies. DartRosa's values are immutable, non-nullable and
// built from immutable DateTime / unmodifiable lists, so "set" is a new
// value, null is rejected at compile time, and the copy checks become
// checks that the lists can't be modified.
import 'package:dartrosa/src/model/data/answer_value.dart';
import 'package:dartrosa/src/model/form_element.dart';
import 'package:dartrosa/src/model/select_choice.dart';
import 'package:dartrosa/src/model/utils/date_utils.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

void main() {
  group('StringDataTests', () {
    test('get data', () {
      expect(const StringValue('string A').value, 'string A');
    });
    test('set data', () {
      expect(const StringValue('string B').value, isNot('string A'));
      expect(const StringValue('string B').value, 'string B');
    });
  });

  group('IntegerDataTests', () {
    test('get data', () => expect(const IntegerValue(1).value, 1));
    test('set data', () {
      expect(const IntegerValue(2).value, isNot(1));
      expect(const IntegerValue(2).value, 2);
    });
  });

  group('DateDataTests', () {
    final today = roundDate(DateTime.now())!;
    final notToday = roundDate(
      DateTime.fromMillisecondsSinceEpoch(
        today.millisecondsSinceEpoch - today.millisecondsSinceEpoch ~/ 2,
      ),
    )!;

    test('get data', () => expect(DateValue(today).value, today));
    test('set data', () {
      expect(DateValue(today).value, isNot(notToday));
      expect(DateValue(notToday).value, notToday);
    });
  });

  group('TimeDataTests', () {
    final now = DateTime.now();
    final minusOneHour = now.subtract(const Duration(minutes: 1));

    test('get data', () => expect(TimeValue(now).value, now));
    test('set data', () {
      expect(TimeValue(minusOneHour).value, isNot(now));
      expect(TimeValue(minusOneHour).value, minusOneHour);
    });
  });

  group('SelectOneDataTests', () {
    late Selection one;
    late Selection two;
    setUp(() {
      final question = QuestionDef(id: 57);
      for (var i = 0; i < 3; i++) {
        question.addSelectChoice(
          SelectChoice('', 'Selection$i', 'Selection$i', isLocalizable: false),
        );
      }
      one = Selection.ofChoice(question.choiceForValue('Selection1')!);
      two = Selection.ofChoice(question.choiceForValue('Selection2')!);
    });

    test('get data', () => expect(SelectOneValue(one).value, one));
    test('set data', () {
      expect(SelectOneValue(two).value, isNot(one));
      expect(SelectOneValue(two).value, two);
    });
  });

  group('MultipleItemsDataTests', () {
    late Selection one;
    late Selection two;
    late Selection three;
    setUp(() {
      final question = QuestionDef();
      for (var i = 0; i < 4; i++) {
        question.addSelectChoice(
          SelectChoice('', 'Selection$i', 'Selection $i', isLocalizable: false),
        );
      }
      Selection attach(String value) =>
          Selection.ofChoice(question.choiceForValue(value)!);
      one = attach('Selection 1');
      two = attach('Selection 2');
      three = attach('Selection 3');
    });

    test('set data', () {
      final firstTwo = [one, two];
      final lastTwo = [two, three];
      expect(MultipleItemsValue(lastTwo).value, isNot(firstTwo));
      expect(MultipleItemsValue(lastTwo).value, lastTwo);
      expect(MultipleItemsValue(firstTwo).value, firstTwo);
    });

    test('list immutability', () {
      final firstTwo = [one, two];
      final data = MultipleItemsValue(firstTwo);
      firstTwo
        ..[0] = two
        ..removeAt(1);
      expect(data.value, [one, two], reason: 'external reference');
      expect(() => data.value.removeAt(1), throwsUnsupportedError);
      expect(data.value, [one, two], reason: 'internal reference');
    });

    // testBadDataTypes (a list holding an Integer) cannot be written in
    // Dart: the list type is List<Selection>.
  });

  group('GeoPointDataTests', () {
    test('display text is space-separated components', () {
      expect(GeoPointValue([0, 1, 2, 3]).displayText, '0.0 1.0 2.0 3.0');
    });
    test('display text is empty when all components are zero', () {
      expect(GeoPointValue([0, 0, 0, 0]).displayText, '');
    });
    test('display text has three components when accuracy omitted', () {
      expect(GeoPointValue([2.3, 7.3, 3.2]).displayText, '2.3 7.3 3.2');
    });
    test('missing accuracy is not treated as 0', () async {
      final scenario =
          await Scenario.init(
              html(
                head([
                  title('Missing accuracy'),
                  model([
                    mainInstance([
                      t('data id="missing-accuracy"', [
                        t('q1'),
                        t('accuracy_rounded'),
                        t('note'),
                      ]),
                    ]),
                    bind('/data/q1')..type('geopoint'),
                    bind('/data/accuracy_rounded')
                      ..calculate('round(selected-at(/data/q1, 3), 2)'),
                    bind('/data/note')..relevant('/data/accuracy_rounded = 0'),
                  ]),
                ]),
                body([input('/data/q1'), input('/data/note')]),
              ),
            )
            ..answer('/data/q1', '1.234 5.678');
      expect(scenario.getAnswerNode('/data/note').isRelevant, isFalse);

      scenario.answer('/data/q1', '1.234 5.678 0 0');
      expect(scenario.getAnswerNode('/data/note').isRelevant, isTrue);
    });
    test('equals compares points', () {
      final data = GeoPointValue([0, 0, 0, 0]);
      expect(data, equals(data));
      expect(data, equals(GeoPointValue([0, 0, 0, 0])));
      expect(data, isNot(equals(GeoPointValue([1, 1, 1, 1]))));
    });
    test('hashCode is the same for the same points', () {
      expect(
        GeoPointValue([0, 0, 0, 0]).hashCode,
        GeoPointValue([0, 0, 0, 0]).hashCode,
      );
    });
  });

  test(
    'DataTypeClassesTest: correct class is returned',
    () {},
    skip: 'DataTypeClasses only serves CompactInstanceWrapper (codec, P6)',
  );

  for (final (name, make) in [
    ('GeoShapeDataTest', GeoShapeValue.new),
    ('GeoTraceDataTest', GeoTraceValue.new),
  ]) {
    AnswerValue points(List<List<double>> parts) =>
        make([for (final p in parts) GeoPointValue(p)]);
    group(name, () {
      final data = points([
        [0, 0, 0, 0],
        [1, 1, 0, 0],
      ]);
      test('equals compares points', () {
        expect(data, equals(data));
        expect(
          data,
          equals(
            points([
              [0, 0, 0, 0],
              [1, 1, 0, 0],
            ]),
          ),
        );
        expect(
          data,
          isNot(
            equals(
              points([
                [0, 0, 0, 0],
                [2, 2, 0, 0],
              ]),
            ),
          ),
        );
      });
      test('hashCode is the same for the same points', () {
        expect(
          data.hashCode,
          points([
            [0, 0, 0, 0],
            [1, 1, 0, 0],
          ]).hashCode,
        );
      });
      test('display text is semicolon-separated points', () {
        expect(
          points([
            [1, 1, 0, 0],
            [2, 2, 0, 0],
          ]).displayText,
          '1.0 1.0 0.0 0.0;2.0 2.0 0.0 0.0',
        );
      });
    });
  }
}
