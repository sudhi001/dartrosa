// `pulldata()` over a CSV attached to the form, as in ODK Collect.
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_external_data/dartrosa_external_data.dart';

const xform = '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head>
    <h:title>Fruit prices</h:title>
    <model>
      <instance>
        <data id="fruit-prices"><fruit/><price/></data>
      </instance>
      <bind nodeset="/data/fruit" type="string"/>
      <bind nodeset="/data/price" type="decimal"
          calculate="pulldata('fruits', 'price', 'name', /data/fruit)"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/fruit"><label>Fruit</label></input>
    <input ref="/data/price"><label>Price</label></input>
  </h:body>
</h:html>
''';

const fruitsCsv = 'name,price\nmango,1.5\nbanana,0.25\n';

Future<void> main() async {
  final config = DartRosaConfig(
    // Form media, read as jr://file/<name>.
    resolver: MapResourceResolver({
      'jr://file/fruits.csv': utf8.encode(fruitsCsv),
    }),
    plugins: [
      ExternalDataPlugin(listMedia: (_) => ['fruits.csv']),
    ],
  );
  final definition = await FormDefinition.parse(xform, config: config);
  final session = definition.createSession();

  final [fruit, price] = session.root.children.cast<QuestionNode>();
  session.answer(fruit.index, const StringValue('mango'));
  _log('price: ${price.value?.displayText}'); // 1.5
}

// ignore: avoid_print
void _log(Object? message) => print(message);
