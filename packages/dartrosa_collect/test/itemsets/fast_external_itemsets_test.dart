// Ports of Collect's ExternalSelectsTest (fast external itemsets cases)
// and DartRosa tests of the itemsets.csv import and query semantics
// (Collect's ItemsetDao / FormLoaderTask.readCSV over SQLite).
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:test/test.dart';

import '../collect_test_forms.dart';

const itemsetsUri = 'jr://file/itemsets.csv';

Future<FormSession> load(
  String xml, {
  String? csv,
  FastExternalItemsetsPlugin? plugin,
  String? language,
}) async {
  final definition = await FormDefinition.parse(
    xml,
    config: DartRosaConfig(
      resolver: MapResourceResolver({
        if (csv != null) itemsetsUri: utf8.encode(csv),
      }),
      plugins: [plugin ?? FastExternalItemsetsPlugin()],
    ),
  );
  return definition.createSession(language: language);
}

FormIndex indexOf(FormSession session, String name) {
  FormIndex? found;
  void visit(FormNode node) {
    if (node.ref?.lastName == name) found = node.index;
    if (node is ContainerNode) node.children.forEach(visit);
  }

  visit(session.root);
  return found!;
}

FormEntryPrompt prompt(FormSession session, String name) =>
    FormEntryPrompt(session.definition.formDef, indexOf(session, name));

List<String?> labels(List<SelectChoice> choices) => [
  for (final c in choices) c.labelInnerText,
];

List<String> values(List<SelectChoice> choices) => [
  for (final c in choices) c.value,
];

/// A form with one select reading itemsets.csv with [query].
String queryForm(String query, {String type = 'string'}) =>
    '''
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head>
    <h:title>Query</h:title>
    <model>
      <instance><data id="q"><a/><b/><n/><choice/></data></instance>
      <bind nodeset="/data/n" type="$type"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/a"><label>A</label></input>
    <input ref="/data/b"><label>B</label></input>
    <input ref="/data/n"><label>N</label></input>
    <input ref="/data/choice" query="$query"><label>Choice</label></input>
  </h:body>
</h:html>
''';

const queryCsv =
    'list_name,name,label,a,b\n'
    'l,x1,X1,1,p\n'
    'l,x2,X2,1,q\n'
    'l,x3,X3,2,q\n'
    'm,y1,Y1,1,p\n';

void main() {
  final itemsetsCsv = media['selectOneExternal-media/itemsets.csv']!;

  group('ExternalSelectsTest', () {
    test('displaysAllChoicesFromItemsetsCSV', () async {
      final session = await load(
        forms['selectOneExternal.xml']!,
        csv: itemsetsCsv,
      );
      session.answer(
        indexOf(session, 'state'),
        const SelectOneValue(Selection('a1')),
      );
      final county = prompt(session, 'county');
      expect(isFastExternalItemsetUsed(county), isTrue);
      final choices = loadItemsetChoices(county);
      expect(labels(choices), ['King', 'Cameron']);
      expect(values(choices), ['b3', 'b4']);
      expect([for (final c in choices) c.index], [0, 1]);
    });

    test('cascades on two answers and follows the language', () async {
      final session = await load(
        forms['selectOneExternal.xml']!,
        csv: itemsetsCsv,
        language: 'French',
      );
      session
        ..answer(
          indexOf(session, 'state'),
          const SelectOneValue(Selection('a1')),
        )
        ..answer(indexOf(session, 'county'), const StringValue('b3'));
      final city = prompt(session, 'city');
      expect(labels(loadItemsetChoices(city)), ['Le Dumont', 'La Finney']);
      // The hierarchy shows the label of the itemset answer.
      expect(itemsetAnswerLabel(prompt(session, 'county')), 'Le King');
      session.language = 'English';
      expect(itemsetAnswerLabel(prompt(session, 'county')), 'King');
    });

    test(
      'missingFileMessage_shouldBeDisplayedIfExternalFileWithChoicesIsMissing',
      () async {
        final session = await load(forms['select_one_external.xml']!);
        session.answer(
          indexOf(session, 'state'),
          const SelectOneValue(Selection('texas')),
        );
        for (final name in ['county', 'city']) {
          expect(
            () => loadItemsetChoices(prompt(session, name)),
            throwsA(
              isA<ItemsetsFileNotFoundException>().having(
                (e) => e.path,
                'path',
                itemsetsUri,
              ),
            ),
          );
        }
      },
    );
  });

  test('selects without query keep their own choices', () async {
    final session = await load(
      forms['selectOneExternal.xml']!,
      csv: itemsetsCsv,
    );
    final state = prompt(session, 'state');
    expect(isFastExternalItemsetUsed(state), isFalse);
    expect(values(loadItemsetChoices(state)), ['a1', 'a2']);
    expect(itemsetAnswerLabel(state), isNull);
  });

  group('query semantics', () {
    Future<List<String>> query(
      String q, {
      String a = '1',
      String b = 'q',
      String csv = queryCsv,
      String type = 'string',
      String n = '',
    }) async {
      final session = await load(queryForm(q, type: type), csv: csv);
      session
        ..answer(indexOf(session, 'a'), StringValue(a))
        ..answer(indexOf(session, 'b'), StringValue(b));
      if (n.isNotEmpty) {
        session.answer(
          indexOf(session, 'n'),
          type == 'int' ? IntegerValue(int.parse(n)) : StringValue(n),
        );
      }
      return values(loadItemsetChoices(prompt(session, 'choice')));
    }

    test('list name only', () async {
      expect(await query("instance('l')/root/item[]"), ['x1', 'x2', 'x3']);
    });

    test('and', () async {
      expect(
        await query("instance('l')/root/item[a= /data/a  and b= /data/b ]"),
        ['x2'],
      );
    });

    test('or binds looser than and', () async {
      // list_name='l' and a='2' or b='p' -> x3 and both rows with b=p
      expect(
        await query(
          "instance('l')/root/item[a= /data/a or b= /data/b ]",
          a: '2',
          b: 'p',
        ),
        ['x1', 'x3', 'y1'],
      );
    });

    test('an and is split off before an earlier or (Collect quirk)', () async {
      // "a=/data/a or b=/data/b" doesn't split into two parts at = and is
      // dropped: only list_name and n remain.
      expect(
        await query(
          "instance('l')/root/item[a= /data/a or b= /data/b and a= /data/n ]",
          n: '2',
        ),
        ['x3'],
      );
    });

    test('literal arguments', () async {
      expect(await query("instance('l')/root/item[b=&quot;p&quot;]"), ['x1']);
    });

    test(
      'single-quoted literals break the list name (Collect quirk)',
      () async {
        // The list name is what lies between the first and last ' .
        expect(await query("instance('l')/root/item[b='p']"), isEmpty);
      },
    );

    test('a query without [ ] fails like Collect', () async {
      expect(() => query("instance('l')/root/item"), throwsRangeError);
    });

    test('numbers are compared as Java doubles (Collect quirk)', () async {
      expect(
        await query(
          "instance('l')/root/item[a= /data/n ]",
          type: 'int',
          n: '1',
        ),
        isEmpty,
      );
      expect(
        await query(
          "instance('l')/root/item[a= /data/n ]",
          type: 'int',
          n: '1',
          csv: '${queryCsv}l,z,Z,1.0,p\n',
        ),
        ['z'],
      );
    });

    test('a column the CSV lacks compares its name (SQLite quirk)', () async {
      expect(await query("instance('l')/root/item[zz= /data/a ]"), isEmpty);
      expect(await query("instance('l')/root/item[zz= /data/a ]", a: 'zz'), [
        'x1',
        'x2',
        'x3',
      ]);
    });

    test('column names ignore case', () async {
      expect(
        await query("instance('l')/root/item[A= /data/a  and B= /data/b ]"),
        ['x2'],
      );
    });

    test('a dangling clause is an SQL error: no choices', () async {
      expect(
        await query("instance('l')/root/item[a= /data/a  and junk]"),
        isEmpty,
      );
    });

    test('no list_name column: no choices', () async {
      expect(
        await query("instance('l')/root/item[]", csv: 'name,label\nx,X\n'),
        isEmpty,
      );
    });

    test('empty values are NULL and never match', () async {
      expect(
        await query(
          "instance('l')/root/item[b= /data/b ]",
          b: '',
          csv: 'list_name,name,label,b\nl,x,X\n',
        ),
        isEmpty,
      );
    });

    test('invalid argument XPath throws XPathSyntaxException', () async {
      expect(
        () => query("instance('l')/root/item[a= /data/a( ]"),
        throwsA(isA<XPathSyntaxException>()),
      );
    });
  });

  group('import', () {
    test('imports only when the CSV changes', () async {
      final repository = InMemoryFastExternalItemsetsRepository();
      var imports = 0;
      final counting = _CountingRepository(repository, () => imports++);
      final plugin = FastExternalItemsetsPlugin(repository: (_) => counting);
      await load(
        queryForm("instance('l')/root/item[]"),
        csv: queryCsv,
        plugin: plugin,
      );
      await load(
        queryForm("instance('l')/root/item[]"),
        csv: queryCsv,
        plugin: plugin,
      );
      expect(imports, 1);
      final session = await load(
        queryForm("instance('l')/root/item[]"),
        csv: 'list_name,name,label\nl,new,New\n',
        plugin: plugin,
      );
      expect(imports, 2);
      expect(values(loadItemsetChoices(prompt(session, 'choice'))), ['new']);
      expect(repository.paths, [itemsetsUri]);
    });

    test('empty header columns are skipped and short rows are NULL', () async {
      final repository = InMemoryFastExternalItemsetsRepository();
      final table = await importItemsets(
        repository,
        'p',
        utf8.encode('list_name,,name,label\nl,ignored,x\n'),
      );
      expect(table!.columns, ['list_name', 'name', 'label']);
      expect(table.rows, [
        ['l', 'x', null],
      ]);
    });

    test('a read error keeps the rows read so far and warns', () async {
      final warnings = <String>[];
      final table = await importItemsets(
        InMemoryFastExternalItemsetsRepository(),
        'p',
        utf8.encode('list_name,name,label\nl,x,X\nl,"y,Y\n'),
        onWarning: warnings.add,
      );
      expect(table!.rows, hasLength(1));
      expect(warnings.single, startsWith('Unterminated quoted field'));
    });

    test('duplicate columns leave no table: no choices', () async {
      final warnings = <String>[];
      final session = await load(
        queryForm("instance('l')/root/item[]"),
        csv: 'list_name,name,Name,label\nl,x,x,X\n',
        plugin: FastExternalItemsetsPlugin(onWarning: warnings.add),
      );
      expect(warnings, hasLength(1));
      expect(loadItemsetChoices(prompt(session, 'choice')), isEmpty);
    });

    test('a row longer than the header fails', () async {
      expect(
        importItemsets(
          InMemoryFastExternalItemsetsRepository(),
          'p',
          utf8.encode('list_name,name,label\nl,x,X,extra\n'),
        ),
        throwsStateError,
      );
    });

    test('the CSV reader uses opencsv defaults (backslash escape)', () {
      final reader = ItemsetsCsvReader(
        'a,"b \\" c","multi\nline"\r\n x , "y"\n',
      );
      expect(reader.readNext(), ['a', 'b " c', 'multi\nline']);
      expect(reader.readNext(), [' x ', 'y']);
      expect(reader.readNext(), isNull);
    });
  });
}

final class _CountingRepository implements FastExternalItemsetsRepository {
  _CountingRepository(this._inner, this._onSave);

  final FastExternalItemsetsRepository _inner;
  final void Function() _onSave;

  @override
  Future<void> deleteAllByCsvPath(String path) =>
      _inner.deleteAllByCsvPath(path);

  @override
  Future<String?> getHash(String path) => _inner.getHash(path);

  @override
  Future<ItemsetTable?> getTable(String path) => _inner.getTable(path);

  @override
  Future<void> save(String path, String hash, ItemsetTable table) {
    _onSave();
    return _inner.save(path, hash, table);
  }
}
