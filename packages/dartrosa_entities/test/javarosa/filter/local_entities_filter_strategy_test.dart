// Port of
// org.odk.collect.entities.javarosa.filter.LocalEntitiesFilterStrategyTest.
import 'package:dartrosa/dartrosa.dart' show ResourceResolver, TreeReference;
import 'package:dartrosa/javarosa.dart';
import 'package:dartrosa/testing.dart';
import 'package:dartrosa_entities/dartrosa_entities.dart';
import 'package:test/test.dart';

final class _FallthroughFilterStrategy implements FilterStrategy {
  bool fellThrough = false;

  @override
  List<TreeReference> filter(
    DataInstance sourceInstance,
    TreeReference nodeset,
    XPathExpression predicate,
    List<TreeReference> children,
    EvaluationContext context,
    List<TreeReference> Function() next,
  ) {
    fellThrough = true;
    return next();
  }
}

final class _SpyInstanceProvider implements InstanceProvider {
  _SpyInstanceProvider(this._wrapped);

  final InstanceProvider _wrapped;
  bool fullParsePerformed = false;

  @override
  TreeElement get(
    String instanceId,
    String instanceSrc, {
    bool partial = false,
  }) {
    if (!partial) fullParsePerformed = true;
    return _wrapped.get(instanceId, instanceSrc, partial: partial);
  }

  @override
  bool isSupported(String instanceId, String instanceSrc) =>
      _wrapped.isSupported(instanceId, instanceSrc);
}

void main() {
  late InMemEntitiesRepository entitiesRepository;
  late _FallthroughFilterStrategy fallthroughFilterStrategy;
  late _SpyInstanceProvider instanceProvider;

  setUp(() {
    entitiesRepository = InMemEntitiesRepository();
    fallthroughFilterStrategy = _FallthroughFilterStrategy();
    instanceProvider = _SpyInstanceProvider(
      LocalEntitiesInstanceProvider(
        () => entitiesRepository,
        InMemFormMediaFileRepository(),
      ),
    );
  });

  Future<Scenario> init(XFormsElement form) => Scenario.init(
    form,
    parserFactory: (ResourceResolver? resolver) => XFormParser(
      resolver: resolver,
      externalInstanceParser: ExternalInstanceParser()
        ..addInstanceProvider(instanceProvider),
    ),
    controllerFactory: (formDef) => FormEntryController(FormEntryModel(formDef))
      ..addFilterStrategy(LocalEntitiesFilterStrategy(entitiesRepository))
      ..addFilterStrategy(fallthroughFilterStrategy),
  );

  /// A form calculating [calculate] from the `things` entity list.
  XFormsElement calculateForm(String calculate) => html(
    head([
      title('Secondary instance form'),
      model([
        mainInstance([
          t('data id="create-entity-form"', [t('question'), t('calculate')]),
        ]),
        t('instance id="things" src="jr://file-csv/things.csv"'),
        bind('/data/question')..type('string'),
        bind('/data/calculate')
          ..type('string')
          ..calculate(calculate),
      ]),
    ]),
    body([input('/data/calculate')]),
  );

  /// A form with a select whose choices are [nodeset] (from `things`).
  XFormsElement selectForm(String nodeset, {bool withRefQuestion = false}) =>
      html(
        head([
          title('Secondary instance form'),
          model([
            mainInstance([
              t('data id="create-entity-form"', [
                if (withRefQuestion) t('ref_question'),
                t('question'),
              ]),
            ]),
            t('instance id="things" src="jr://file-csv/things.csv"'),
            if (withRefQuestion) bind('/data/ref_question')..type('string'),
            bind('/data/question')..type('string'),
          ]),
        ]),
        body([
          if (withRefQuestion) input('/data/ref_question'),
          select1Dynamic(
            '/data/question',
            nodeset,
            valueRef: 'name',
            labelRef: 'label',
          ),
        ]),
      );

  List<String> choiceValues(Scenario scenario) => [
    for (final choice in scenario.choicesOf('/data/question')) choice.value,
  ];

  test('returns matching nodes in the optimized way when id = value', () async {
    entitiesRepository
      ..save('things', [NewEntity('thing1', 'Thing 1')])
      ..save('things', [NewEntity('thing2', 'Thing 2')]);

    final scenario = await init(
      calculateForm("instance('things')/root/item[name='thing1']/label"),
    );

    expect(scenario.answerOf('/data/calculate')?.value, 'Thing 1');
    expect(fallthroughFilterStrategy.fellThrough, isFalse);
  });

  test(
    'returns matching nodes in the optimized way when id != value',
    () async {
      entitiesRepository
        ..save('things', [NewEntity('thing1', 'Thing 1')])
        ..save('things', [NewEntity('thing2', 'Thing 2')]);

      final scenario = await init(
        calculateForm("instance('things')/root/item[name!='thing1']/label"),
      );

      expect(scenario.answerOf('/data/calculate')?.value, 'Thing 2');
      expect(fallthroughFilterStrategy.fellThrough, isFalse);
    },
  );

  test('replaces partial elements when entity matches name', () async {
    entitiesRepository.save('things', [
      NewEntity('thing', 'Thing'),
      NewEntity('other', 'Other'),
    ]);

    await init(
      calculateForm("instance('things')/root/item[name='thing']/label"),
    );

    expect(instanceProvider.fullParsePerformed, isFalse);
  });

  test('returns empty nodeset in the optimized way when no entity matches '
      'name', () async {
    entitiesRepository.addList('things');

    final scenario = await init(
      calculateForm("instance('things')/root/item[name='other']/label"),
    );

    expect(scenario.answerOf('/data/calculate'), isNull);
    expect(fallthroughFilterStrategy.fellThrough, isFalse);
  });

  test('works correctly but not in the optimized way with non eq name '
      'expressions', () async {
    entitiesRepository.save('things', [NewEntity('thing', 'Thing')]);

    final scenario = await init(
      calculateForm(
        "instance('things')/root/item[starts-with(name, 'thing')]/label",
      ),
    );

    expect(scenario.answerOf('/data/calculate')?.value, 'Thing');
    expect(fallthroughFilterStrategy.fellThrough, isTrue);
  });

  test('does not effect name queries on non entity instances', () async {
    final scenario = await init(
      html(
        head([
          title('Secondary instance form'),
          model([
            mainInstance([
              t('data id="create-entity-form"', [
                t('question'),
                t('calculate'),
              ]),
            ]),
            instance('secondary', [
              t('item', [tText('label', 'Thing'), tText('name', 'thing')]),
            ]),
            bind('/data/question')..type('string'),
            bind('/data/calculate')
              ..type('string')
              ..calculate(
                "instance('secondary')/root/item[name='thing']/label",
              ),
          ]),
        ]),
        body([input('/data/calculate')]),
      ),
    );

    expect(scenario.answerOf('/data/calculate')?.value, 'Thing');
  });

  test('works correctly with filtering on a repeat', () async {
    final scenario = await init(
      html(
        head([
          title('Count people underage'),
          model([
            mainInstance([
              t('data id="count_people_underage"', [
                t('people', [t('name'), t('age')]),
                t('total_underage'),
              ]),
            ]),
            bind('/data/people/name')..type('string'),
            bind('/data/people/age')..type('int'),
            bind('/data/question')..type('string'),
            bind('/data/total_underage')
              ..type('string')
              ..calculate('count( /data/people [age&lt;18])'),
          ]),
        ]),
        body([
          repeat('/data/people', [
            input('/data/people/name'),
            input('/data/people/age'),
          ]),
          input('/data/total_underage'),
        ]),
      ),
    );

    expect(scenario.answerOf('/data/total_underage')?.displayText, '0');
  });

  test('works correctly in the optimized way with property = '
      'expressions', () async {
    entitiesRepository.save('things', [
      NewEntity('thing1', 'Thing1', properties: const [('property', 'value')]),
      NewEntity('thing2', 'Thing2', properties: const [('property', 'value')]),
      NewEntity('other', 'Other', properties: const [('property', 'other')]),
    ]);

    final scenario = await init(
      selectForm("instance('things')/root/item[property='value']"),
    );

    expect(choiceValues(scenario), unorderedEquals(['thing1', 'thing2']));
    expect(fallthroughFilterStrategy.fellThrough, isFalse);
  });

  test('works correctly in the optimized way with property = number', () async {
    entitiesRepository
      ..save('things', [
        NewEntity('thing1', 'Thing1', properties: const [('age', '25')]),
      ])
      ..save('things', [
        NewEntity('thing2', 'Thing2', properties: const [('age', '30')]),
      ]);

    final scenario = await init(
      selectForm("instance('things')/root/item[age=25]"),
    );

    expect(choiceValues(scenario), unorderedEquals(['thing1']));
    expect(instanceProvider.fullParsePerformed, isFalse);
  });

  test('replaces partial elements when entity matches property', () async {
    entitiesRepository.save('things', [
      NewEntity('thing1', 'Thing1', properties: const [('property', 'value')]),
    ]);

    final scenario = await init(
      selectForm("instance('things')/root/item[property='value']"),
    );

    scenario.choicesOf('/data/question'); // Calculate choices
    expect(instanceProvider.fullParsePerformed, isFalse);
  });

  test(
    'works correctly in the optimized way with label = expressions',
    () async {
      entitiesRepository.save('things', [NewEntity('thing1', 'Thing1')]);

      final scenario = await init(
        selectForm("instance('things')/root/item[label='Thing1']"),
      );

      expect(choiceValues(scenario), unorderedEquals(['thing1']));
      expect(fallthroughFilterStrategy.fellThrough, isFalse);
    },
  );

  test('works correctly in the optimized way with version = '
      'expressions', () async {
    entitiesRepository.save('things', [
      NewEntity('thing1', 'Thing1', version: 2),
    ]);

    final scenario = await init(
      selectForm("instance('things')/root/item[__version='2']"),
    );

    expect(choiceValues(scenario), unorderedEquals(['thing1']));
    expect(fallthroughFilterStrategy.fellThrough, isFalse);
  });

  test('works correctly in the optimized way with combined eq '
      'expressions', () async {
    entitiesRepository.save('things', [
      NewEntity('thing1', 'Thing1', properties: const [('property', 'value1')]),
      NewEntity(
        'thing2',
        'Thing2',
        version: 2,
        properties: const [('property', 'value2')],
      ),
      NewEntity(
        'thing3',
        'Thing3',
        version: 2,
        properties: const [('property', 'value3')],
      ),
    ]);

    final scenario = await init(
      selectForm(
        "instance('things')/root/item[label='Thing1' or "
        "(__version='2' and property='value3')]",
      ),
    );

    expect(choiceValues(scenario), unorderedEquals(['thing1', 'thing3']));
    expect(fallthroughFilterStrategy.fellThrough, isFalse);
    expect(instanceProvider.fullParsePerformed, isFalse);
  });

  test('works correctly but not in the optimized way with unanswered '
      "question = ''", () async {
    entitiesRepository.save('things', [NewEntity('thing1', 'Thing1')]);

    final scenario = await init(
      selectForm(
        "instance('things')/root/item[/data/ref_question='']",
        withRefQuestion: true,
      ),
    );

    expect(choiceValues(scenario), unorderedEquals(['thing1']));
    expect(fallthroughFilterStrategy.fellThrough, isTrue);
  });

  test('works correctly but not in the optimized way with answered question '
      '= value', () async {
    entitiesRepository.save('things', [NewEntity('thing1', 'Thing1')]);

    final scenario = await init(
      selectForm(
        "instance('things')/root/item[/data/ref_question='']",
        withRefQuestion: true,
      ),
    );
    scenario
      ..next()
      ..answerCurrent('blah');

    expect(choiceValues(scenario), isEmpty);
    expect(fallthroughFilterStrategy.fellThrough, isTrue);
  });

  test('works correctly but not in the optimized way with non existing '
      "property = ''", () async {
    entitiesRepository.save('things', [NewEntity('thing1', 'Thing1')]);

    final scenario = await init(
      selectForm("instance('things')/root/item[not_existing_property='']"),
    );

    expect(choiceValues(scenario), unorderedEquals(['thing1']));
    expect(fallthroughFilterStrategy.fellThrough, isTrue);
  });

  test('works correctly but not in the optimized way with non existing '
      'property = value', () async {
    entitiesRepository.save('things', [NewEntity('thing1', 'Thing1')]);

    final scenario = await init(
      selectForm("instance('things')/root/item[not_existing_property='value']"),
    );

    expect(choiceValues(scenario), isEmpty);
    expect(fallthroughFilterStrategy.fellThrough, isTrue);
  });
}
