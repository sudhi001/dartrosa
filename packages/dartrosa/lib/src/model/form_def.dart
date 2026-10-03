import '../i18n/localizer.dart';
import '../xpath/conversions.dart';
import '../xpath/exceptions.dart';
import '../xpath/parser.dart';
import 'actions/actions.dart';
import 'condition/conditions.dart';
import 'condition/evaluation_context.dart';
import 'control_type.dart';
import 'data/answer_value.dart';
import 'form_element.dart';
import 'instance/data_instance.dart';
import 'instance/tree_reference.dart';
import 'select_choice.dart';
import 'submission_profile.dart';

/// A parsed form: its controls, instances, binds, translations and
/// submission settings.
///
/// Port of `org.javarosa.core.model.FormDef`. Phase 2 provides what the
/// XForm parser builds; the engine (recalculation, repeats, validation,
/// navigation) is added in Phases 3–4.
final class FormDef extends FormElement {
  /// Creates an empty form.
  FormDef() : super(id: -1);

  final List<FormElement> _children = [];
  final Map<String, DataInstance> _instances = {};
  final Map<String, SubmissionProfile> _submissionProfiles = {};
  final List<Triggerable> _triggerables = [];
  final Set<String> _actions = {};
  final Set<FormElement> _elementsWithTopLevelActions = {};
  final List<XPathFunctionHandler> _customFunctionHandlers = [];
  final List<FilterStrategy> _customFilterStrategies = [];

  /// The form title (`<h:title>`).
  String? title;

  /// The form name (`<meta name>` or the title).
  String? name;

  /// Where the form XML came from, if known.
  String? formXmlPath;

  FormInstance? _mainInstance;
  EvaluationContext? _evaluationContext;
  Localizer? _localizer;

  /// The `<output>` expressions referenced as `${n}` in labels and hints.
  final List<XPathConditional> outputFragments = [];

  /// Warnings found while parsing.
  final List<String> parseWarnings = [];

  /// Non-fatal errors found while parsing.
  final List<String> parseErrors = [];

  /// Receives `<odk:recordaudio>` requests (replaces JavaRosa's static
  /// `RecordAudioActions` listener).
  RecordAudioListener? recordAudioListener;

  @override
  List<FormElement> get children => _children;

  @override
  void addChild(FormElement child) => _children.add(child);

  /// Replaces child [i].
  void replaceChildAt(int i, FormElement child) => _children[i] = child;

  @override
  int get deepChildCount =>
      _children.fold(0, (total, child) => total + child.deepChildCount);

  /// The main instance.
  FormInstance get mainInstance => _mainInstance!;

  /// Whether the main instance has been set.
  bool get hasMainInstance => _mainInstance != null;

  set mainInstance(FormInstance instance) {
    _evaluationContext = null;
    _mainInstance = instance;
  }

  /// Adds a secondary instance under its name.
  void addNonMainInstance(DataInstance instance) {
    _evaluationContext = null;
    _instances[instance.name!] = instance;
  }

  /// The secondary instance called [name], if any.
  DataInstance? nonMainInstance(String name) => _instances[name];

  /// All secondary instances by name.
  Map<String, DataInstance> get nonMainInstances =>
      Map.unmodifiable(_instances);

  /// The translations, if the form has `<itext>`.
  Localizer? get localizer => _localizer;

  set localizer(Localizer? localizer) {
    _localizer?.unregisterLocalizable(this);
    _localizer = localizer;
    _localizer?.registerLocalizable(this);
  }

  /// The default submission profile, if any.
  SubmissionProfile? get defaultSubmission => _submissionProfiles['1'];

  set defaultSubmission(SubmissionProfile? profile) {
    if (profile == null) {
      _submissionProfiles.remove('1');
    } else {
      _submissionProfiles['1'] = profile;
    }
  }

  /// Adds a submission profile with [id].
  void addSubmissionProfile(String id, SubmissionProfile profile) =>
      _submissionProfiles[id] = profile;

  /// The submission profile with [id], or the default one.
  SubmissionProfile? submissionProfile([String? id]) =>
      _submissionProfiles[id ?? '1'];

  /// Registers a triggerable, or returns an equal one already registered.
  Triggerable addTriggerable(Triggerable triggerable) {
    for (final existing in _triggerables) {
      if (existing.matches(triggerable)) {
        // Merge contexts so the shared triggerable covers both binds.
        existing.intersectContextWith(triggerable);
        return existing;
      }
    }
    _triggerables.add(triggerable);
    return triggerable;
  }

  /// The registered triggerables, in registration order.
  List<Triggerable> get triggerables => List.unmodifiable(_triggerables);

  /// Builds the dependency graph and checks it for cycles (Phase 3).
  void finalizeTriggerables() {}

  /// Records that the form uses action element [name].
  void registerAction(String name) => _actions.add(name);

  /// Whether the form uses action element [name].
  bool hasAction(String name) => _actions.contains(name);

  /// Records an element inside the body whose actions listen to top-level
  /// events.
  void registerElementWithActionTriggeredByToplevelEvent(FormElement e) =>
      _elementsWithTopLevelActions.add(e);

  /// Elements whose actions listen to top-level events.
  Set<FormElement> get elementsWithActionTriggeredByToplevelEvent =>
      Set.unmodifiable(_elementsWithTopLevelActions);

  /// Adds a custom XPath function available to the form's expressions.
  void addFunctionHandler(XPathFunctionHandler handler) {
    _customFunctionHandlers.add(handler);
    _evaluationContext = null;
  }

  /// Adds a predicate filter strategy tried before the built-in ones.
  void addFilterStrategy(FilterStrategy strategy) {
    _customFilterStrategies.add(strategy);
    _evaluationContext = null;
  }

  /// Adds a parse warning.
  void addParseWarning(String warning) => parseWarnings.add(warning);

  /// Adds a non-fatal parse error.
  void addParseError(String error) => parseErrors.add(error);

  /// The evaluation context for the form's expressions: the instances,
  /// `jr:itext`, `jr:choice-name` and custom functions.
  EvaluationContext get evaluationContext {
    final existing = _evaluationContext;
    if (existing != null) return existing;
    var context = EvaluationContext.forInstance(
      _mainInstance!,
      _instances,
      EvaluationContext(null),
    );
    if (!context.functionHandlers.containsKey('jr:itext')) {
      context.addFunctionHandler(_ItextFunction(this));
    }
    if (!context.functionHandlers.containsKey('jr:choice-name')) {
      context.addFunctionHandler(_ChoiceNameFunction(this));
    }
    context = EvaluationContext.withFilterStrategies(
      context,
      _customFilterStrategies,
    );
    _customFunctionHandlers.forEach(context.addFunctionHandler);
    return _evaluationContext = context;
  }

  static const _templatingRecursionLimit = 10;

  /// Replaces `${n}` placeholders in [template] with the values of
  /// [outputFragments], evaluated at [contextRef].
  String fillTemplateString(
    String template,
    TreeReference contextRef, [
    Map<String, Object?> variables = const {},
  ]) {
    final args = <String, String>{};
    var depth = 0;
    var outstanding = Localizer.getArgs(template);
    while (outstanding.isNotEmpty) {
      for (final argName in outstanding) {
        if (args.containsKey(argName)) continue;
        final index = int.tryParse(argName) ?? -1;
        if (index < 0 || index >= outputFragments.length) continue;
        final ec = EvaluationContext.withContext(evaluationContext, contextRef)
          ..originalContext = contextRef
          ..setVariables(variables);
        args[argName] = outputFragments[index].evalReadable(mainInstance, ec);
      }
      template = Localizer.processNamedArguments(template, args);
      outstanding = Localizer.getArgs(template);
      if (++depth >= _templatingRecursionLimit) {
        throw StateError(
          'Dependency cycle in <output>s; recursion limit exceeded!!',
        );
      }
    }
    return template;
  }

  @override
  void localeChanged(String locale, Localizer localizer) {
    for (final child in _children) {
      child.localeChanged(locale, localizer);
    }
  }

  /// Sets [value] at [ref] and recalculates dependents (Phase 3/4).
  void setValue(
    AnswerValue? value,
    TreeReference ref, {
    bool midSurvey = true,
  }) =>
      throw UnimplementedError('FormDef.setValue arrives with the engine (P4)');

  /// Performs a `<setvalue>` (port of `SetValueAction.processAction`).
  TreeReference? processSetValue(
    SetValueAction action,
    TreeReference? context,
  ) {
    final target = action.target;
    var targetRef = context == null ? target : target.contextualize(context)!;
    final ec = EvaluationContext.withContext(evaluationContext, targetRef);
    final failMessage =
        'Target of TreeReference ${target.toString(includePredicates: true)} '
        'could not be resolved!';
    final refs = ec.expandReference(targetRef)!;
    if (refs.isEmpty) {
      if (mainInstance.hasTemplatePath(target)) return null;
      throw StateError(failMessage);
    }
    if (refs.length > 1) {
      throw XPathTypeMismatchException(
        'You are trying to target a repeated field. Currently you may only '
        'target a field in a specific repeat instance.\n\nXPath nodeset has '
        'more than one node [" + references + "].',
      );
    }
    targetRef = refs.single;
    final node = ec.resolveReference(targetRef);
    if (node == null) {
      if (mainInstance.hasTemplatePath(target)) return null;
      throw StateError(failMessage);
    }
    final result = unpack(action.value.eval(mainInstance, ec));
    final wrapped = wrapData(result, node.dataType);
    setValue(
      wrapped == null ? null : castToDataType(wrapped.uncast(), node.dataType),
      targetRef,
    );
    return targetRef;
  }

  /// Stores an action-provided [text] (e.g. a location) at [ref].
  void saveActionValue(TreeReference ref, String text) {
    final ec = EvaluationContext.withContext(evaluationContext, ref);
    final node = ec.resolveReference(ref);
    if (node == null) return;
    final wrapped = wrapData(text, node.dataType);
    setValue(
      wrapped == null ? null : castToDataType(wrapped.uncast(), node.dataType),
      ref,
    );
  }

  /// [ref] anchored to [parentRef] (which must be absolute); a missing
  /// [ref] (a `<group>` without binding) means the parent itself.
  ///
  /// Port of `FormDef.getAbsRef`.
  static TreeReference getAbsRef(TreeReference? ref, TreeReference parentRef) {
    if (!parentRef.isAbsolute) {
      throw StateError('XFormParser.getAbsRef: parentRef must be absolute');
    }
    return (ref ?? const TreeReference.self()).anchor(parentRef);
  }

  /// The question bound to [ref] under [element] (repeat-agnostic when
  /// [element] is the form).
  static QuestionDef? findQuestionByRef(
    TreeReference ref,
    FormElement element,
  ) {
    if (element is FormDef) ref = ref.genericize();
    if (element is QuestionDef) return ref == element.bind ? element : null;
    for (final child in element.children) {
      final found = findQuestionByRef(ref, child);
      if (found != null) return found;
    }
    return null;
  }

  /// Computes itemset references for all questions under [children].
  static void updateItemsetReferences(List<FormElement> children) {
    for (final child in children) {
      if (child is QuestionDef) {
        child.dynamicChoices?.initReferences(child);
      } else {
        updateItemsetReferences(child.children);
      }
    }
  }

  @override
  String toString() => title ?? '';
}

/// `jr:itext(id)`: the text for [id] in the current language (or the form
/// requested by the evaluation context).
final class _ItextFunction extends XPathFunctionHandler {
  _ItextFunction(this._form);

  final FormDef _form;

  @override
  String get name => 'jr:itext';

  @override
  List<List<XPathArgType>> get prototypes => [
    [XPathArgType.string],
  ];

  @override
  Object eval(List<Object> args, EvaluationContext context) {
    var textId = args[0] as String;
    // JavaRosa catches NoSuchElementException ("[nolocale]"), which is
    // never thrown; a missing locale fails as it does there.
    final localizer = _form.localizer!;
    final form = context.outputTextForm;
    if (form != null) {
      textId = '$textId;$form';
      return localizer.getRawText(localizer.locale, textId) ?? '';
    }
    return localizer.getText(textId) ?? '[itext:$textId]';
  }
}

/// `jr:choice-name(value, question)`: the label of the choice with [value]
/// in the select question at the given path.
final class _ChoiceNameFunction extends XPathFunctionHandler {
  _ChoiceNameFunction(this._form);

  final FormDef _form;

  @override
  String get name => 'jr:choice-name';

  @override
  List<List<XPathArgType>> get prototypes => [
    [XPathArgType.string, XPathArgType.string],
  ];

  @override
  Object eval(List<Object> args, EvaluationContext context) {
    final value = args[0] as String;
    final ref = parseReference(args[1] as String).anchor(context.contextRef);
    final question = FormDef.findQuestionByRef(ref, _form);
    if (question == null ||
        (question.controlType != ControlType.selectOne &&
            question.controlType != ControlType.selectMulti &&
            question.controlType != ControlType.rank)) {
      return '';
    }
    final List<SelectChoice>? choices;
    if (question.dynamicChoices != null) {
      // Dynamic choices need itemset evaluation, added in Phase 5.
      throw UnimplementedError('jr:choice-name on an itemset (P5)');
    } else {
      choices = question.choices;
    }
    for (final choice in choices ?? const <SelectChoice>[]) {
      if (choice.value == value) {
        final template = choice.textId != null
            ? _form.localizer!.getText(choice.textId!)
            : choice.labelInnerText;
        return _form.fillTemplateString(template ?? '', ref);
      }
    }
    return '';
  }
}
