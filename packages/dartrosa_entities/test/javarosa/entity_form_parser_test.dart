// Port of org.odk.collect.entities.javarosa.EntityFormParserTest.
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

void main() {
  TreeElement entityWith(Map<String, String> attributes) {
    final element = TreeElement(FormEntityElement.elementEntity);
    attributes.forEach(
      (name, value) => element.setAttribute(null, name, value),
    );
    return element;
  }

  test('parse action finds create with true string', () {
    expect(
      EntityFormParser.parseAction(
        entityWith({FormEntityElement.attributeCreate: 'true'}),
      ),
      EntityAction.create,
    );
  });

  test('parse action finds update with true string', () {
    expect(
      EntityFormParser.parseAction(
        entityWith({FormEntityElement.attributeUpdate: 'true'}),
      ),
      EntityAction.update,
    );
  });

  test('parse action finds upsert with true create and update strings', () {
    expect(
      EntityFormParser.parseAction(
        entityWith({
          FormEntityElement.attributeCreate: 'true',
          FormEntityElement.attributeUpdate: 'true',
        }),
      ),
      EntityAction.upsert,
    );
  });

  test('parse action is null without true create or update', () {
    expect(
      EntityFormParser.parseAction(
        entityWith({FormEntityElement.attributeCreate: 'false'}),
      ),
      isNull,
    );
  });

  test('parse label when label is an int, converts to string', () {
    final labelElement = TreeElement(FormEntityElement.elementLabel)
      ..value = const IntegerValue(0);
    final entityElement = TreeElement(FormEntityElement.elementEntity)
      ..addChild(labelElement);

    expect(EntityFormParser.parseLabel(entityElement), '0');
  });

  test('parse label when label is null, returns an empty string', () {
    final entityElement = TreeElement(FormEntityElement.elementEntity)
      ..addChild(TreeElement(FormEntityElement.elementLabel));

    expect(EntityFormParser.parseLabel(entityElement), '');
  });
}
