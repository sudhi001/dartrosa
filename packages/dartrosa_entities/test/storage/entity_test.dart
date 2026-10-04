// Added: the storage model (Kotlin data-class behaviour).
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

void main() {
  test('isDirty compares version and trunk version', () {
    expect(NewEntity('1', 'One').isDirty(), isTrue);
    expect(NewEntity('1', 'One', trunkVersion: 1).isDirty(), isFalse);
    expect(
      NewEntity('1', 'One', version: 2, trunkVersion: 1).isDirty(),
      isTrue,
    );
  });

  test('sameAs ignores new/saved and index', () {
    final entity = NewEntity('1', 'One', properties: const [('a', 'b')]);
    final saved = SavedEntity(
      '1',
      'One',
      index: 3,
      properties: const [('a', 'b')],
    );
    expect(entity.sameAs(saved), isTrue);
    expect(entity == saved, isFalse);
    expect(saved.sameAs(saved.copyWith(label: 'Two')), isFalse);
  });

  test('entities have value equality', () {
    expect(
      NewEntity('1', 'One', properties: const [('a', 'b')]),
      NewEntity('1', 'One', properties: const [('a', 'b')]),
    );
    expect(
      SavedEntity('1', 'One', index: 0).hashCode,
      SavedEntity('1', 'One', index: 0).hashCode,
    );
    expect(
      NewEntity('1', 'One', properties: const [('a', 'b')]).propertyNames,
      ['a'],
    );
  });

  test('Query.mapColumns renames every column', () {
    const query = AndQuery(
      StringEqQuery('a', 'x'),
      OrQuery(NumericEqQuery('b', 1), StringNotEqQuery('c', 'y')),
    );
    expect(
      query.mapColumns((c) => 'p_$c'),
      const AndQuery(
        StringEqQuery('p_a', 'x'),
        OrQuery(NumericEqQuery('p_b', 1), StringNotEqQuery('p_c', 'y')),
      ),
    );
    expect(
      const NumericNotEqQuery('a', 1).mapColumns((c) => c.toUpperCase()),
      const NumericNotEqQuery('A', 1),
    );
  });

  test('InMemEntitiesRepository supports and/or queries', () {
    final repository = InMemEntitiesRepository()
      ..save('l', [
        NewEntity('1', 'One', properties: const [('p', 'x')]),
        NewEntity('2', 'Two', properties: const [('p', 'y')]),
        NewEntity('3', 'Three', properties: const [('p', 'x')]),
      ]);
    List<String> ids(Query q) => [
      for (final e in repository.query('l', q)) e.id,
    ];

    expect(
      ids(
        const AndQuery(StringEqQuery('p', 'x'), StringNotEqQuery('name', '1')),
      ),
      ['3'],
    );
    expect(
      ids(const OrQuery(StringEqQuery('name', '2'), StringEqQuery('p', 'x'))),
      ['2', '1', '3'],
    );
    expect(ids(const StringEqQuery('__version', '1')), ['1', '2', '3']);
  });
}
