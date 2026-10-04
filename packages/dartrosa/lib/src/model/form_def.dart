import 'package:collection/collection.dart';

import '../i18n/localizer.dart';
import '../xform/xform_answer_data_serializer.dart';
import '../xpath/conversions.dart';
import '../xpath/exceptions.dart';
import '../xpath/parser.dart';
import 'actions/actions.dart';
import 'condition/conditions.dart';
import 'condition/evaluation_context.dart';
import 'condition/filter_strategies.dart';
import 'control_type.dart';
import 'data/answer_value.dart';
import 'form_element.dart';
import 'instance/data_instance.dart';
import 'instance/tree_element.dart';
import 'instance/tree_reference.dart';
import 'select_choice.dart';
import 'submission_profile.dart';
import 'triggerable_dag.dart';
import 'utils/question_preloader.dart';

/// A parsed form: its controls, instances, binds, translations and
/// submission settings.
///
/// Port of `org.javarosa.core.model.FormDef`. Phase 2 provides what the
/// XForm parser builds; Phase 3 adds recalculation (the [TriggerableDag]),
/// repeat insertion and deletion, constraints and preloads; navigation is
/// added in Phase 4.
final class FormDef extends FormElement {
  /// Creates an empty form.
  FormDef() : super(id: -1) {
    _dag = TriggerableDag(publishEvent);
  }

  late final TriggerableDag _dag;
  final List<void Function(EvaluationEvent event)> _eventListeners = [];

  /// The `jr:preload` handlers; replace or extend before [initialize].
  QuestionPreloader preloader = QuestionPreloader();

  final List<FormElement> _children = [];
  final Map<String, DataInstance> _instances = {};
  final Map<String, SubmissionProfile> _submissionProfiles = {};
  final Set<String> _actions = {};
  final Set<FormElement> _elementsWithTopLevelActions = {};
  final List<XPathFunctionHandler> _customFunctionHandlers = [];
  final List<FilterStrategy> _customFilterStrategies = [];
  // Like JavaRosa's, these live as long as the form (secondary instances
  // don't change), across evaluation-context resets.
  final _equalityIndexStrategy = EqualityExpressionIndexFilterStrategy();
  final _comparisonCacheStrategy = ComparisonExpressionCacheFilterStrategy();

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

  /// Registers a triggerable, or returns an equal one already registered
  /// (whose context then covers both binds).
  Triggerable addTriggerable(Triggerable triggerable) =>
      _dag.addTriggerable(triggerable);

  /// The registered triggerables, in registration order.
  List<Triggerable> get triggerables => _dag.triggerables;

  /// The dependency graph of the calculations and conditions.
  TriggerableDag get dag => _dag;

  /// Orders the triggerables for evaluation; throws [StateError] naming
  /// the nodes involved when they depend on each other in a cycle.
  void finalizeTriggerables() =>
      _dag.finalizeTriggerables(mainInstance, evaluationContext);

  /// Re-evaluates what depends on the node at [ref]; returns the
  /// triggerables evaluated.
  Set<Triggerable> triggerTriggerables(TreeReference ref) =>
      _dag.triggerTriggerables(mainInstance, evaluationContext, ref);

  /// Receives evaluation events (debugging and tracing). Port of
  /// JavaRosa's `EventNotifier`.
  void addEventListener(void Function(EvaluationEvent event) listener) =>
      _eventListeners.add(listener);

  /// Stops [listener] from receiving evaluation events.
  void removeEventListener(void Function(EvaluationEvent event) listener) =>
      _eventListeners.remove(listener);

  /// Sends [event] to the event listeners.
  void publishEvent(EvaluationEvent event) {
    for (final listener in [..._eventListeners]) {
      listener(event);
    }
  }

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
    context = EvaluationContext.withFilterStrategies(context, [
      ..._customFilterStrategies,
      _equalityIndexStrategy,
      _comparisonCacheStrategy,
    ]);
    _customFunctionHandlers.forEach(context.addFunctionHandler);
    // property() reads the same properties as `property` preloads (one
    // PropertyManager in JavaRosa).
    context.propertyLookup ??= (name) => preloader.properties.getProperty(name);
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

  /// Sets [value] at [ref], re-evaluates what depends on it and, when the
  /// value changed, fires the question's `xforms-value-changed` actions.
  ///
  /// [midSurvey] is kept for JavaRosa compatibility; it has no effect.
  void setValue(
    AnswerValue? value,
    TreeReference ref, {
    bool midSurvey = true,
  }) {
    final node = mainInstance.resolveReference(ref)!;
    final valueChanged = !_serializedEquals(node.value, value);
    node.setAnswer(value);
    final question = findQuestionByRef(ref, this);
    final evaluated = triggerTriggerables(ref);
    if (valueChanged && question != null) {
      question.actionController.triggerActionsFromEvent(
        FormEvents.xformsValueChanged,
        this,
        ref.parentRef,
        null,
      );
    }
    _dag.publishSummary('New value', ref, evaluated);
  }

  static bool _serializedEquals(AnswerValue? a, AnswerValue? b) {
    final serializedA = serializeAnswerData(a);
    final serializedB = serializeAnswerData(b);
    return serializedA is List && serializedB is List
        ? const ListEquality<Object?>().equals(serializedA, serializedB)
        : serializedA == serializedB;
  }

  /// Sets the answer at [ref] without re-evaluating anything.
  void setAnswer(AnswerValue? value, TreeReference ref) =>
      mainInstance.resolveReference(ref)!.setAnswer(value);

  // ------------------------------------------------------------ repeats

  /// Adds a repeat instance at [repeatRef] (fully qualified, with the new
  /// instance's multiplicity) from the repeat's template, preloads it,
  /// fires `jr-insert` and `odk-new-repeat`, and evaluates what it
  /// affects.
  ///
  /// The reference-based core of JavaRosa's `createNewRepeat(FormIndex)`.
  TreeElement createRepeatInstance(TreeReference repeatRef) {
    final template = mainInstance.getTemplate(repeatRef);
    if (template == null) {
      throw InvalidReferenceException(
        'no repeat template at ${repeatRef.toString(includePredicates: true)}',
        repeatRef,
      );
    }
    mainInstance.copyNode(template, repeatRef);
    final newNode = mainInstance.resolveReference(repeatRef)!;
    preloadInstance(newNode);
    actionController
      ..triggerActionsFromEvent(FormEvents.jrInsert, this, repeatRef, null)
      ..triggerActionsFromEvent(FormEvents.odkNewRepeat, this, repeatRef, null);
    _repeatDefFor(repeatRef)?.actionController.triggerActionsFromEvent(
      FormEvents.odkNewRepeat,
      this,
      repeatRef,
      null,
    );
    _dag.createRepeatInstance(
      mainInstance,
      evaluationContext,
      repeatRef,
      newNode,
    );
    return newNode;
  }

  /// Removes the repeat instance at [deleteRef], renumbers the following
  /// instances and re-evaluates what depended on it.
  ///
  /// The reference-based core of JavaRosa's `deleteRepeat(FormIndex)`.
  void deleteRepeatInstance(TreeReference deleteRef) {
    final deleteElement = mainInstance.resolveReference(deleteRef)!;
    final parentElement = mainInstance.resolveReference(deleteRef.parentRef!)!;
    final childMult = deleteElement.multiplicity;
    parentElement.removeChild(deleteElement);
    for (final child in parentElement.children) {
      if (child.name == deleteElement.name && child.multiplicity > childMult) {
        child
          ..multiplicity = child.multiplicity - 1
          ..clearChildrenCaches();
      }
    }
    _dag.deleteRepeatInstance(
      mainInstance,
      evaluationContext,
      deleteRef,
      deleteElement,
    );
  }

  GroupDef? _repeatDefFor(TreeReference repeatRef) {
    final generic = repeatRef.genericize();
    GroupDef? search(FormElement element) {
      for (final child in element.children) {
        if (child is GroupDef) {
          if (child.isRepeat && child.bind?.genericize() == generic) {
            return child;
          }
          final found = search(child);
          if (found != null) return found;
        }
      }
      return null;
    }

    return search(this);
  }

  /// Whether the repeat instance at [repeatRef] is relevant: its own
  /// relevance condition, its parent's relevance and its template's.
  bool isRepeatRelevant(TreeReference repeatRef) {
    var relevant = true;
    final condition = _dag.relevanceForRepeat(repeatRef.genericize());
    if (condition != null) {
      relevant =
          condition.eval(
                mainInstance,
                EvaluationContext.withContext(evaluationContext, repeatRef),
              )
              as bool;
    }
    if (relevant) {
      final template = mainInstance.getTemplate(repeatRef)!;
      final parentPath = template.parent!.ref.genericize();
      final parentNode = mainInstance.resolveReference(
        parentPath.contextualize(repeatRef)!,
      );
      relevant =
          parentNode != null && parentNode.isRelevant && template.isRelevant;
    }
    return relevant;
  }

  /// Whether another instance of [repeat] can be added after
  /// [currentMultiplicity] instances at [repeatRef]: always, unless the
  /// repeat is fixed (`noAddRemove`), and for a `jr:count` repeat while
  /// the count is larger.
  ///
  /// The core of JavaRosa's `canCreateRepeat(TreeReference, FormIndex)`.
  bool canCreateRepeat(
    TreeReference repeatRef,
    GroupDef repeat,
    int currentMultiplicity,
  ) {
    if (!repeat.noAddRemove) return true;
    final countRef = repeat.count;
    if (countRef == null) return false;
    final countNode = mainInstance.resolveReference(
      countRef.contextualize(repeatRef)!,
    );
    if (countNode == null) return false;
    return answerDataToInt(countNode.value) > currentMultiplicity;
  }

  // ------------------------------------------------------------ validation

  /// Whether [data] satisfies the constraint of the node at [ref] (no
  /// answer always does).
  bool evaluateConstraint(TreeReference ref, AnswerValue? data) {
    if (data == null) return true;
    final node = mainInstance.resolveReference(ref)!;
    final constraint = node.constraint;
    if (constraint is! Constraint) return true;
    final ec = EvaluationContext.withContext(evaluationContext, ref)
      ..isConstraint = true
      ..candidateValue = data;
    final result = constraint.constraint.eval(mainInstance, ec);
    publishEvent(EvaluationEvent('Constraint', [(ref: ref, value: result)]));
    return result;
  }

  // ------------------------------------------------------------ lifecycle

  /// Prepares the form for filling: initializes the instances, preloads a
  /// [newInstance], picks the default language, fires the load actions
  /// and evaluates every calculation and condition.
  ///
  /// Port of `initialize(boolean, InstanceInitializationFactory)`; the
  /// factory is dropped because JavaRosa never uses it.
  void initialize({required bool newInstance}) {
    for (final MapEntry(key: id, value: instance) in nonMainInstances.entries) {
      if (instance is FormInstance) instance.initialize(id);
    }
    if (newInstance) preloadInstance(mainInstance.root);
    final localizer = this.localizer;
    if (localizer != null && localizer.locale == null) {
      localizer.setToDefault();
    }
    final nested = elementsWithActionTriggeredByToplevelEvent;
    if (newInstance) {
      actionController
        ..triggerActionsFromEventNested(
          FormEvents.odkInstanceFirstLoad,
          nested,
          this,
        )
        ..triggerActionsFromEventNested(FormEvents.xformsReady, nested, this);
    }
    actionController.triggerActionsFromEventNested(
      FormEvents.odkInstanceLoad,
      nested,
      this,
    );
    final evaluated = _dag.initializeTriggerables(
      mainInstance,
      evaluationContext,
      const TreeReference.root(),
    );
    _dag.publishSummary('Form initialized', null, evaluated);
  }

  /// Applies the `jr:preload` values to [node] and its descendants
  /// (templates excluded).
  void preloadInstance(TreeElement node) {
    final handler = node.preloadHandler;
    if (handler != null) {
      final preload = preloader.getQuestionPreload(handler, node.preloadParams);
      if (preload != null) node.setAnswer(preload);
    }
    for (final child in [...node.children]) {
      if (child.multiplicity != TreeReference.indexTemplate) {
        preloadInstance(child);
      }
    }
  }

  /// Finalization: fires `xforms-revalidate` and runs the preloads'
  /// finalization steps (such as `timestamp` `end`).
  void postProcessInstance() {
    actionController.triggerActionsFromEventNested(
      FormEvents.xformsRevalidate,
      elementsWithActionTriggeredByToplevelEvent,
      this,
    );
    _postProcess(mainInstance.root);
  }

  bool _postProcess(TreeElement node) {
    if (node.isLeaf) {
      final handler = node.preloadHandler;
      return handler != null &&
          preloader.questionPostProcess(node, handler, node.preloadParams);
    }
    var modified = false;
    for (final child in [...node.children]) {
      if (child.multiplicity != TreeReference.indexTemplate) {
        modified |= _postProcess(child);
      }
    }
    return modified;
  }

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
    final questionRef = parseReference(
      args[1] as String,
    ).anchor(context.contextRef);
    final question = FormDef.findQuestionByRef(questionRef, _form);
    if (question == null ||
        (question.controlType != ControlType.selectOne &&
            question.controlType != ControlType.selectMulti &&
            question.controlType != ControlType.rank)) {
      return '';
    }
    final List<SelectChoice>? choices;
    var ref = questionRef;
    final itemset = question.dynamicChoices;
    if (itemset != null) {
      // There is no real context for the choice list, so JavaRosa picks
      // the current repeat instance, else the first one.
      if (ref.isAmbiguous) {
        ref = ref.contextualize(context.contextRef)!;
        for (var i = 0; i < ref.size; i++) {
          if (ref.multiplicityAt(i) == TreeReference.indexUnbound) {
            ref = ref.withMultiplicity(i, 0);
          }
        }
      }
      choices = itemset.getChoices(_form, ref);
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
