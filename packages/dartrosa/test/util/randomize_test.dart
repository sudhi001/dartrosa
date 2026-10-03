// Port of JavaRosa v6.0.0 FisherYatesTest, FisherYatesExamplesTest,
// ParkMillerTest, XPathNodesetShuffleTest and RandomizeHelperTest, plus
// seeded shuffles captured from JavaRosa (jshell).
import 'package:collection/collection.dart' show ListEquality;
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:dartrosa/src/util/randomize.dart';
import 'package:dartrosa/src/xpath/functions.dart';
import 'package:dartrosa/src/xpath/nodeset.dart';
import 'package:test/test.dart';

const _input = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
const _eq = ListEquality<Object?>();

List<String> letters(String s) => s.split('');

void main() {
  group('FisherYates', () {
    test('produces the same elements in a different order', () {
      expect(_eq.equals(shuffle(_input), _input), isFalse);
    });

    test('shuffling an empty list has no effect', () {
      expect(shuffle(<int>[]), isEmpty);
    });

    test('different seeds give different outputs', () {
      expect(_eq.equals(shuffle(_input, 33), shuffle(_input, 42)), isFalse);
    });

    const examples = [
      ('Numbers [0-9], seed 33', _input, 33.0, [3, 5, 4, 8, 2, 0, 1, 6, 9, 7]),
      ('Numbers [0-9], seed 42', _input, 42.0, [0, 5, 9, 1, 8, 4, 6, 3, 7, 2]),
    ];
    for (final (name, input, seed, expected) in examples) {
      test(name, () => expect(shuffle(input, seed), expected));
    }
    const letterExamples = [
      ('Letters [A-F], seed 42', 42.0, 'AFCBDE'),
      ('Letters [A-F], seed -42', -42.0, 'EDAFBC'),
      ('Letters [A-F], seed 1', 1.0, 'BFEACD'),
      ('Letters [A-F], seed 11111111', 11111111.0, 'ACDBFE'),
    ];
    for (final (name, seed, expected) in letterExamples) {
      test(name, () {
        expect(shuffle(letters('ABCDEF'), seed), letters(expected));
      });
    }
  });

  group('ParkMiller', () {
    for (final seed in [42.0, -42.0]) {
      test('same seed $seed gives the same sequence', () {
        final a = ParkMiller(seed);
        final b = ParkMiller(seed);
        for (var i = 0; i < 1000000; i++) {
          expect(a.nextInt(), b.nextInt());
          expect(a.nextDouble(), b.nextDouble());
        }
      });
    }
  });

  group('seeds match JavaRosa', () {
    // (text, toLongHash, shuffle of 0..9 with that seed) from JavaRosa.
    const hashes = [
      ('', 0, [9, 1, 8, 0, 5, 3, 6, 4, 7, 2]),
      ('a', -3848465438864589366.0, [9, 2, 1, 0, 3, 4, 6, 5, 7, 8]),
      ('seed', 1851639526980669642.0, [6, 1, 8, 3, 4, 7, 0, 5, 2, 9]),
      ('ODK rocks', -5625330177621791059.0, [7, 6, 0, 4, 9, 5, 8, 1, 2, 3]),
      ('नमस्ते', -2472320649917034092.0, [1, 8, 0, 5, 9, 3, 6, 2, 4, 7]),
      ('1.5abc', 3710367466420620119.0, [3, 8, 0, 2, 6, 9, 5, 4, 7, 1]),
    ];
    for (final (text, hash, expected) in hashes) {
      test("text seed '$text'", () {
        expect(longHash(text), hash);
        expect(shuffle(_input, toNumericWithLongHash(text)), expected);
      });
    }
    // (number, Java long seed, shuffle) from JavaRosa.
    const numbers = [
      (3.7, 3.0, [8, 3, 4, 5, 1, 0, 2, 6, 9, 7]),
      (-3.7, -3.0, [5, 0, 9, 1, 4, 6, 3, 2, 7, 8]),
      (1e19, 9223372036854775807.0, [6, 2, 7, 8, 1, 0, 4, 5, 9, 3]),
      (-1e19, -9223372036854775808.0, [0, 9, 5, 2, 3, 4, 6, 7, 8, 1]),
      (2147483648.0, 2147483648.0, [6, 5, 4, 0, 2, 7, 8, 3, 1, 9]),
    ];
    for (final (number, seed, expected) in numbers) {
      test('number seed $number', () {
        expect(toNumericWithLongHash(number), seed);
        expect(shuffle(_input, toNumericWithLongHash(number)), expected);
      });
    }
  });

  group('nodeset shuffle', () {
    XPathNodeset nodeset(int size) => XPathNodeset(
      [
        for (var i = 0; i < size; i++)
          const TreeReference.relative().extend('n$i', 0),
      ],
      null,
      null,
    );

    test('an empty nodeset gives a new empty nodeset', () {
      final input = nodeset(0);
      final output = shuffleNodeset(input);
      expect(identical(input, output), isFalse);
      expect(output.size, 0);
    });

    test('same elements, shuffled', () {
      final input = nodeset(10);
      final output = shuffleNodeset(input);
      expect(output.references!.toSet(), input.references!.toSet());
      expect(_eq.equals(output.references, input.references), isFalse);
    });

    test('same seed, same order', () {
      final input = nodeset(10);
      expect(
        shuffleNodeset(input, 42).references,
        shuffleNodeset(input, 42).references,
      );
    });
  });

  group('cleanNodesetDefinition', () {
    const cases = {
      'randomize(/some/path)': '/some/path',
      ' randomize(/some/path)': '/some/path',
      'randomize(/some/path) ': '/some/path',
      ' randomize(/some/path) ': '/some/path',
      'randomize( /some/path )': '/some/path',
      'randomize(/some/path,33)': '/some/path',
      'randomize(/some/path, 33)': '/some/path',
      'randomize( /some/path , 33)': '/some/path',
      'randomize(/some/path, /some/other/path)': '/some/path',
      'randomize(/some/path , /some/other/path)': '/some/path',
      'randomize( /some/path, /some/other/path)': '/some/path',
      'randomize( /some/path , /some/other/path)': '/some/path',
      'randomize(/some/path[someFilter])': '/some/path[someFilter]',
      'randomize(/some/path[someFilter], 33)': '/some/path[someFilter]',
      'randomize(/some/path[someFilter(with, commas)])':
          '/some/path[someFilter(with, commas)]',
      'randomize(/some/path[someFilter(with, commas)], 33)':
          '/some/path[someFilter(with, commas)]',
    };
    cases.forEach((input, expected) {
      test(input, () => expect(cleanNodesetDefinition(input), expected));
    });

    test('rejects definitions without randomize()', () {
      expect(
        () => cleanNodesetDefinition("this doesn't start with randomize( )"),
        throwsArgumentError,
      );
      expect(
        () => cleanNodesetDefinition("this doesn't end with ) *some filler*"),
        throwsArgumentError,
      );
    });
  });
}
