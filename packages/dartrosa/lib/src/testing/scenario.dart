import 'package:logging/logging.dart';

import '../codec/form_def_codec.dart';
import '../form_api/form_entry_caption.dart';
import '../form_api/form_entry_controller.dart';
import '../form_api/form_entry_model.dart';
import '../form_api/form_entry_prompt.dart';
import '../model/condition/evaluation_context.dart';
import '../model/data/answer_value.dart';
import '../model/form_def.dart';
import '../model/form_element.dart';
import '../model/form_index.dart';
import '../model/instance/data_instance.dart';
import '../model/instance/tree_element.dart';
import '../model/instance/tree_reference.dart';
import '../model/select_choice.dart';
import '../model/triggerable_dag.dart';
import '../reference/resource_resolver.dart';
import '../xform/xform_parser.dart';
import '../xform/xform_serializing_visitor.dart';
import 'references.dart';
import 'xforms_element.dart';

final _log = Logger('dartrosa.scenario');

/// The outcome of [Scenario.answer]. Port of `Scenario.AnswerResult`.
typedef AnswerResult = AnswerStatus;

/// Fills a form from tests: answer by XPath, navigate, add and remove
/// repeat instances, and read answers, choices and prompts.
///
/// Port of `org.javarosa.test.Scenario`, JavaRosa's test driver. Loading
/// is asynchronous (secondary instances); everything else is synchronous.
/// Java's `answer` overloads become one [answer] taking the value
/// (a `String`, `List<String>`, `int`, `double`, `bool`, `DateTime`
/// (a date), [SelectChoice] or [AnswerValue]); answering the current
/// question is [answerCurrent].
final class Scenario {
  Scenario._(
    this.formDef,
    this._controllerFactory,
    this._blankInstance, [
    this._parserFactory,
  ]) : _evaluationContext = formDef.evaluationContext;

  /// Parses [xml] (resolving `jr://` resources through [resolver]) and
  /// starts a new instance.
  ///
  /// [parserFactory] creates the parser instead (e.g. with plugin
  /// processors added, as JavaRosa's `XFormUtils.setXFormParserFactory`);
  /// it is also used to restore the form in [serializeAndDeserializeForm]
  /// and [serializeAndDeserializeInstance].
  static Future<Scenario> fromXml(
    String xml, {
    ResourceResolver? resolver,
    FormEntryController Function(FormDef form)? controllerFactory,
    XFormParser Function(ResourceResolver? resolver)? parserFactory,
  }) async => fromFormDef(
    await _parser(parserFactory, resolver).parse(xml),
    controllerFactory: controllerFactory,
    parserFactory: parserFactory,
  );

  /// Builds the form [form] (see `test/xforms_element`) and starts a new
  /// instance. Port of `Scenario.init(XFormsElement)`.
  static Future<Scenario> init(
    XFormsElement form, {
    ResourceResolver? resolver,
    FormEntryController Function(FormDef form)? controllerFactory,
    XFormParser Function(ResourceResolver? resolver)? parserFactory,
  }) => fromXml(
    form.asXml(),
    resolver: resolver,
    controllerFactory: controllerFactory,
    parserFactory: parserFactory,
  );

  /// Starts filling [form] (a new instance unless not [newInstance]).
  static Scenario fromFormDef(
    FormDef form, {
    bool newInstance = true,
    FormEntryController Function(FormDef form)? controllerFactory,
    XFormParser Function(ResourceResolver? resolver)? parserFactory,
  }) => Scenario._(
    form,
    controllerFactory ?? (f) => FormEntryController(FormEntryModel(f)),
    form.mainInstance.clone(),
    parserFactory,
  ).._init(newInstance: newInstance);

  static XFormParser _parser(
    XFormParser Function(ResourceResolver? resolver)? factory,
    ResourceResolver? resolver,
  ) => factory != null ? factory(resolver) : XFormParser(resolver: resolver);

  /// The form, with its current instance, encoded and restored (as after
  /// an app restart), continuing that instance. Port of
  /// `serializeAndDeserializeForm` (JavaRosa's `Externalizable` becomes
  /// [FormDefCodec]).
  Future<Scenario> serializeAndDeserializeForm({
    ResourceResolver? resolver,
  }) async => fromFormDef(
    await FormDefCodec.decode(
      FormDefCodec.encode(formDef),
      resolver: resolver,
      parser: _parserFactory == null ? null : _parser(_parserFactory, resolver),
    ),
    newInstance: false,
    parserFactory: _parserFactory,
  );

  /// The instance serialized and loaded into a fresh parse of [form] (the
  /// same form), as a new scenario continuing that instance. Port of
  /// `serializeAndDeserializeInstance`.
  Future<Scenario> serializeAndDeserializeInstance(
    XFormsElement form, {
    ResourceResolver? resolver,
  }) async {
    final instanceXml = XFormSerializingVisitor().serializeInstanceToString(
      formDef.mainInstance,
    );
    final restored = await _parser(
      _parserFactory,
      resolver,
    ).parse(form.asXml(), instanceXml: instanceXml);
    return fromFormDef(
      restored,
      newInstance: false,
      parserFactory: _parserFactory,
    );
  }

  /// The beginning-of-form index.
  static final FormIndex beginningOfForm = FormIndex.beginningOfForm();

  /// The form.
  final FormDef formDef;

  final FormEntryController Function(FormDef form) _controllerFactory;
  final XFormParser Function(ResourceResolver? resolver)? _parserFactory;
  final FormInstance _blankInstance;
  late FormEntryController _controller;
  late FormEntryModel _model;
  EvaluationContext _evaluationContext;

  void _init({required bool newInstance}) {
    _controller = _controllerFactory(formDef);
    _model = _controller.model;
    formDef.initialize(newInstance: newInstance);
  }

  /// Starts again with a blank instance.
  void newInstance() {
    formDef.mainInstance = _blankInstance.clone();
    _init(newInstance: true);
    _evaluationContext = formDef.evaluationContext;
  }

  /// The form's evaluation context when the scenario started.
  EvaluationContext get evaluationContext => _evaluationContext;

  /// The controller.
  FormEntryController get formEntryController => _controller;

  /// The current index.
  FormIndex get currentIndex => _model.formIndex;

  /// The first validation failure, or `null`.
  ValidateOutcome? get validationOutcome => formDef.validate();

  /// The index of the element at [xPath].
  FormIndex? indexOf(String xPath) => _indexOf(expandSingle(getRef(xPath)));

  /// The form's language.
  String? get language => _controller.language;

  /// Sets the form's language.
  set language(String? language) => _controller.language = language;

  /// Receives the form's evaluation events. Port of `onDagEvent`.
  void onDagEvent(void Function(EvaluationEvent event) callback) =>
      formDef.addEventListener(callback);

  /// The single node [reference] expands to; throws otherwise.
  TreeReference expandSingle(TreeReference reference) {
    final expanded = _evaluationContext.expandReference(reference)!;
    if (expanded.length != 1) {
      throw StateError(
        'Provided xPath expands to ${expanded.length} references. Expecting '
        'exactly one expanded reference.',
      );
    }
    return expanded.single;
  }

  /// Logs [msg] prominently.
  void trace(String msg) => _log.info('=== $msg ===');

  /// Finalizes the form.
  void finalizeInstance() => _controller.finalizeFormEntry();

  bool _refExists(TreeReference reference) =>
      _evaluationContext.expandReference(reference)!.length == 1;

  FormIndex? _indexOf(TreeReference ref) {
    final qualified = expandSingle(ref);
    final backup = _model.formIndex;
    _silentJump(beginningOfForm);
    var index = _model.formIndex;
    do {
      if (index.reference == qualified) {
        _silentJump(backup);
        return index;
      }
      index = _model.incrementIndex(index);
    } while (index.isInForm);
    _silentJump(backup);
    return null;
  }

  /// Answers the question at [xPath] (creating missing repeat instances
  /// on the way) with [value].
  AnswerResult answer(String xPath, Object? value) {
    _createMissingRepeats(xPath);
    _silentJump(_indexOf(getRef(xPath))!);
    return answerCurrent(value);
  }

  /// Answers the current question with [value].
  AnswerResult answerCurrent(Object? value) {
    final data = switch (value) {
      null => null,
      final AnswerValue v => v,
      final String s => StringValue(s),
      final List<String> values => MultipleItemsValue([
        for (final v in values) Selection(v),
      ]),
      final int i => IntegerValue(i),
      final double d => DecimalValue(d),
      final bool b => BooleanValue(b),
      final DateTime d => DateValue(DateTime.utc(d.year, d.month, d.day)),
      final SelectChoice c => SelectOneValue(Selection.ofChoice(c)),
      _ => throw ArgumentError.value(value, 'value', 'unsupported answer'),
    };
    final index = _model.formIndex;
    _log.info('Answer $data at ${index.reference}');
    return _controller.answerQuestion(data, index: index, midSurvey: true);
  }

  /// Removes the repeat instance at [xPath].
  void removeRepeat(String xPath) {
    final reference = expandSingle(getRef(xPath));
    final group = formDef.mainInstance.resolveReference(reference)!;
    FormIndex? childIndex;
    for (final child in group.children) {
      childIndex = _indexOf(child.ref);
      if (childIndex != null) break;
    }
    if (childIndex == null) {
      throw StateError(
        "Can't find an index inside the repeat group you want to remove. "
        'Please add some field and a form control.',
      );
    }
    formDef.deleteRepeat(childIndex);
  }

  /// Adds a repeat instance at the current index.
  void createNewRepeatHere() {
    _log.info('Create repeat instance ${_model.formIndex.reference}');
    _controller.newRepeat();
  }

  /// Adds an instance to the repeat [xPath] (an unqualified reference).
  void createNewRepeat(String xPath) {
    final groupRef = getRef(xPath);
    if (!groupRef.isAmbiguous) {
      throw StateError('Provided xPath must be ambiguous');
    }
    final multiplicity = _evaluationContext.expandReference(groupRef)!.length;
    _createRepeat(groupRef.withMultiplicity(groupRef.size - 1, multiplicity));
  }

  void _createRepeat(TreeReference repeatInstanceRef) {
    if (repeatInstanceRef.isAmbiguous) {
      throw StateError("The provided reference can't be ambiguous");
    }
    _silentJump(beginningOfForm);
    while (!atTheEndOfForm && !_refExists(repeatInstanceRef)) {
      if (_silentNext() == FormEntryEvent.promptNewRepeat &&
          _model.formIndex.reference == repeatInstanceRef) {
        while (!_refExists(repeatInstanceRef)) {
          _controller.descendIntoNewRepeat();
        }
      }
    }
    if (!_refExists(repeatInstanceRef)) {
      throw StateError(
        "We couldn't create repeat group instance at $repeatInstanceRef. "
        'Check your form and your test',
      );
    }
  }

  void _createMissingRepeats(String xPath) {
    final backup = _model.formIndex;
    final reference = getRef(xPath);
    for (var i = 0; i < reference.size; i++) {
      if (reference.multiplicityAt(i) < 0) continue;
      _createRepeat(reference.subReference(i));
    }
    _silentJump(backup);
  }

  /// Moves to the next relevant element.
  FormEntryEvent next([int amount = 1]) {
    var event = _model.event();
    for (var i = 0; i < amount; i++) {
      event = _controller.stepToNextEvent();
      _log.info(_jumpTrace(event));
    }
    return event;
  }

  /// Moves to the previous relevant element.
  FormEntryEvent prev() {
    final event = _controller.stepToPreviousEvent();
    _log.info(_jumpTrace(event));
    return event;
  }

  /// Moves before the first element.
  void jumpToBeginningOfForm() {
    final event = _controller.jumpToIndex(beginningOfForm);
    _log.info(_jumpTrace(event));
  }

  /// Moves to [index].
  FormEntryEvent jumpTo(FormIndex index) => _controller.jumpToIndex(index);

  FormEntryEvent _silentNext() => _controller.stepToNextEvent();

  FormEntryEvent _silentPrev() => _controller.stepToPreviousEvent();

  void _silentJump(FormIndex index) => _controller.jumpToIndex(index);

  String _jumpTrace(FormEntryEvent event) {
    final index = _model.formIndex;
    final element = formDef.elementAt(index);
    var label = element.labelInnerText;
    if (label == null) {
      final textId = element.textId;
      final localizer = formDef.localizer;
      label = textId == null || localizer == null
          ? ''
          : (localizer.getText(textId) ?? '')
                .split('\n')
                .map((l) => l.trim())
                .join(' ');
    }
    final ref = index.reference?.toString(
      includePredicates: true,
      zeroIndexMultiplicity: true,
    );
    return 'Jump to ${event.name}${label.isEmpty ? '' : ' $label'}'
        '${ref == null || ref.isEmpty ? '' : ' ref:$ref'}';
  }

  /// Whether the current index is the end of the form.
  bool get atTheEndOfForm => _model.formIndex.isEndOfFormIndex;

  /// The reference of the next element (without moving).
  TreeReference? nextRef() {
    _silentNext();
    final ref = refAtIndex;
    _silentPrev();
    return ref;
  }

  /// The reference at the current index.
  TreeReference? get refAtIndex => _model.formIndex.reference;

  /// Whether the current index is a question.
  bool get atQuestion => formDef.elementAt(_model.formIndex) is QuestionDef;

  /// The question at the current index.
  QuestionDef get questionAtIndex => _model.questionPrompt().question;

  /// The prompt at the current index.
  FormEntryPrompt get formEntryPromptAtIndex => _model.questionPrompt();

  /// The caption at the current index.
  FormEntryCaption get formEntryCaptionAtIndex => _model.captionPrompt();

  /// The answer at [xPath], or `null` if there is no such node.
  AnswerValue? answerOf(String xPath) {
    final reference = getRef(xPath);
    if (!_refExists(reference)) return null;
    return formDef.mainInstance.resolveReference(reference)?.value;
  }

  /// The number of instances of the repeat [xPath] (unqualified).
  int countRepeatInstancesOf(String xPath) {
    final reference = getRef(xPath);
    if (!reference.isAmbiguous) {
      throw StateError('Provided xPath must be ambiguous');
    }
    return _evaluationContext.expandReference(reference)!.length;
  }

  /// The choices of the select question at [xPath].
  List<SelectChoice> choicesOf(String xPath) {
    final reference = expandSingle(getRef(xPath));
    final control = _model.questionPrompt(_indexOf(reference)).question;
    return control.choices ??
        control.dynamicChoices!.getChoices(formDef, reference);
  }

  /// The instance node at [xPath].
  TreeElement getAnswerNode(String xPath) =>
      formDef.mainInstance.resolveReference(expandSingle(getRef(xPath)))!;
}
