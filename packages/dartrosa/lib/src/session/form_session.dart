// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import '../form_api/form_entry_controller.dart';
import '../form_api/form_entry_model.dart';
import '../form_api/form_entry_prompt.dart';
import '../model/data/answer_value.dart';
import '../model/data_type.dart';
import '../model/form_def.dart';
import '../model/form_index.dart';
import '../model/instance/data_instance.dart';
import '../model/instance/tree_reference.dart';
import '../model/triggerable_dag.dart';
import '../model/utils/question_preloader.dart';
import '../reference/resource_resolver.dart';
import '../xform/instance_loading.dart';
import '../xform/xform_answer_data_parser.dart';
import '../xform/xform_parser.dart';
import '../xform/xform_serializing_visitor.dart';
import 'answer_result.dart';
import 'config.dart';
import 'form_node.dart';

/// A parsed form, ready to be filled.
///
/// Until definitions can be cached and copied (Phase 6), a definition
/// backs one session at a time: [createSession] resets it and closes the
/// session created before (see [FormSession.close]).
final class FormDefinition {
  FormDefinition._(this.formDef, this.config)
    : _blankInstance = formDef.mainInstance.clone();

  /// Parses the XForm [xml] with [config] (secondary instances are read
  /// through its resolver, hence asynchronous).
  static Future<FormDefinition> parse(
    String xml, {
    DartRosaConfig config = const DartRosaConfig(),
  }) async {
    final parser = XFormParser(
      resolver: config.resolver,
      externalInstanceParser: config.externalInstanceParser,
      setGeopointAction: config.setGeopointAction,
    );
    config.parseProcessors.forEach(parser.addProcessor);
    for (final plugin in config.plugins) {
      plugin.createParseProcessors().forEach(parser.addProcessor);
    }
    final form = await parser.parse(xml, lastSavedSrc: config.lastSavedSrc);
    final resolver = config.resolver ?? MapResourceResolver(const {});
    for (final plugin in config.plugins) {
      await plugin.prepareForm(form, resolver);
    }
    config.functions.forEach(form.addFunctionHandler);
    config.filterStrategies.forEach(form.addFilterStrategy);
    form.preloader = QuestionPreloader(properties: config.properties);
    config.preloadHandlers.forEach(form.preloader.addPreloadHandler);
    return FormDefinition._(form, config);
  }

  /// The underlying JavaRosa-style form definition.
  final FormDef formDef;

  /// The configuration it was parsed with.
  final DartRosaConfig config;

  final FormInstance _blankInstance;

  /// The session filling the form, if not closed.
  FormSession? _session;

  /// The form title.
  String? get title => formDef.title;

  /// The form's languages (empty without translations).
  List<String> get languages => formDef.localizer?.availableLocales ?? const [];

  /// Starts filling a new instance, or continues [existingInstance] (a
  /// saved draft or submission XML), in [language] if given.
  ///
  /// The session created before, which shared this definition's form, is
  /// closed first (its [FormSession.changes] stream is done and it stops
  /// receiving the form's events), so the definition doesn't keep every
  /// session it ever created.
  FormSession createSession({String? existingInstance, String? language}) {
    if (_session case final previous?) unawaited(previous._detach());
    formDef.mainInstance = _blankInstance.clone();
    if (existingInstance != null) {
      formDef.loadXmlInstance(
        existingInstance,
        resolver:
            config.plugins.map((p) => p.answerResolver).nonNulls.firstOrNull ??
            defaultAnswerResolver,
      );
    }
    final session = _session = FormSession._(
      this,
      newInstance: existingInstance == null,
    );
    if (language != null) session.language = language;
    return session;
  }
}

/// A change made by the engine: the nodes whose value or state was
/// recalculated, or a structural change.
final class FormChange {
  /// Creates a change.
  const FormChange(this.kind, this.refs);

  /// What happened: `value`, `condition`, `repeat`, `language`, ...
  final String kind;

  /// The affected nodes.
  final List<TreeReference> refs;

  @override
  String toString() => 'FormChange($kind, $refs)';
}

/// Filling one instance of a form: a tree of nodes to read and answer,
/// and a cursor ([navigator]) with JavaRosa's navigation semantics.
final class FormSession {
  FormSession._(this.definition, {required bool newInstance})
    : _controller = FormEntryController(FormEntryModel(definition.formDef)) {
    final form = definition.formDef;
    definition.config.finalizationProcessors.forEach(
      _controller.addPostProcessor,
    );
    form.addEventListener(_onEvaluation);
    try {
      form.initialize(newInstance: newInstance);
    } catch (_) {
      // The session is never returned: don't leave it listening.
      form.removeEventListener(_onEvaluation);
      rethrow;
    }
    navigator = FormNavigator._(this);
  }

  /// The form being filled.
  final FormDefinition definition;

  final FormEntryController _controller;
  final _changes = StreamController<FormChange>.broadcast(sync: true);

  /// The cursor.
  late final FormNavigator navigator;

  FormDef get _form => definition.formDef;

  /// App-defined state attached to the session.
  Map<Object, Object?> get extras => _controller.model.extras;

  /// The engine's changes (recalculated values, relevance, repeats, ...).
  ///
  /// The stream is done once the session is closed ([close], or a new
  /// session of the same [definition]).
  Stream<FormChange> get changes => _changes.stream;

  /// Whether [close] was called, or the [definition] has started another
  /// session.
  bool get isClosed => _changes.isClosed;

  void _emit(FormChange change) {
    if (!_changes.isClosed) _changes.add(change);
  }

  void _onEvaluation(EvaluationEvent event) {
    // Itemsets announce each (re-)evaluation of their choices, which
    // happens while reading a question (e.g. while a UI builds); it
    // changes nothing.
    if (event.message == 'Dynamic choices') return;
    if (event.results.isEmpty || !_changes.hasListener) return;
    _emit(
      FormChange(event.message == 'Recalculate' ? 'value' : 'condition', [
        for (final result in event.results) result.ref,
      ]),
    );
  }

  /// The whole form as a tree.
  RootNode get root => rootNode(_controller.model);

  /// The node at [index].
  FormNode nodeAt(FormIndex index) => nodeAtIndex(_controller.model, index);

  /// The current language.
  String? get language => _form.localizer?.locale;

  /// Changes the language.
  set language(String? language) {
    _controller.language = language;
    _emit(const FormChange('language', []));
  }

  /// Answers the question at [index] after checking `required` and the
  /// constraint (unless not [validate]).
  ///
  /// Text ([UncastValue]) is read as the question's data type (as ODK
  /// Collect's widgets do); values that can't be read, values of another
  /// type, and choices the question doesn't offer give [AnswerRejected]
  /// (even when not [validate]) and are not saved.
  AnswerResult answer(
    FormIndex index,
    AnswerValue? value, {
    bool validate = true,
  }) {
    final (typed, problem) = _typed(
      _controller.model.questionPrompt(index),
      value,
    );
    if (problem != null) return AnswerRejected(problem);
    value = typed;
    if (!validate) {
      _controller.saveAnswer(value, index: index, midSurvey: true);
      _emit(FormChange('answer', [index.reference!]));
      return const AnswerAccepted();
    }
    final status = _controller.answerQuestion(
      value,
      index: index,
      midSurvey: true,
    );
    final prompt = _controller.model.questionPrompt(index);
    switch (status) {
      case AnswerStatus.ok:
        _emit(FormChange('answer', [index.reference!]));
        return const AnswerAccepted();
      case AnswerStatus.requiredButEmpty:
        return AnswerRequired(bindAttributeValue(prompt, 'requiredMsg'));
      case AnswerStatus.constraintViolated:
        return AnswerConstraintViolated(
          prompt.constraintText(attemptedValue: value),
        );
    }
  }

  /// [value] fitted to [prompt]'s question: text parsed, typed values
  /// checked; `(value, null)` or `(null, problem)`.
  static (AnswerValue?, String?) _typed(
    FormEntryPrompt prompt,
    AnswerValue? value,
  ) {
    if (value == null) return (null, null);
    final dataType = prompt.dataType;
    if (value is UncastValue) {
      if (value.string.trim().isEmpty) return (null, null);
      final parsed = parseAnswerData(value.string, dataType, prompt.question);
      if (parsed == null) {
        return (
          null,
          '"${value.string}" is not a valid ${dataType.name} answer',
        );
      }
      // The (JavaRosa) parser drops unknown values of a multi-select.
      final given = value.string.trim().split(RegExp(' +')).toSet().length;
      if (parsed is MultipleItemsValue && parsed.selections.length < given) {
        return (null, '"${value.string}" has values that are not choices');
      }
      value = parsed;
    }
    final fits = switch (dataType) {
      DataType.integer => value is IntegerValue,
      DataType.long => value is LongValue || value is IntegerValue,
      DataType.decimal =>
        value is DecimalValue || value is IntegerValue || value is LongValue,
      DataType.boolean => value is BooleanValue,
      DataType.date => value is DateValue,
      DataType.time => value is TimeValue,
      DataType.dateTime => value is DateTimeValue,
      DataType.choice => value is SelectOneValue,
      DataType.multipleItems => value is MultipleItemsValue,
      DataType.geopoint => value is GeoPointValue,
      DataType.geotrace => value is GeoTraceValue,
      DataType.geoshape => value is GeoShapeValue,
      DataType.text || DataType.barcode => value is StringValue,
      DataType.binary => value is StringValue || value is PointerValue,
      _ => true,
    };
    if (!fits) {
      return (
        null,
        'a ${value.runtimeType} does not fit a ${dataType.name} question',
      );
    }
    final selections = switch (value) {
      SelectOneValue(:final selection) => [selection],
      MultipleItemsValue(:final selections) => selections,
      _ => null,
    };
    // search() appearances (ODK Collect external data) take their choices
    // from CSV media, not from the question's items.
    final external =
        prompt.appearanceHint?.toLowerCase().contains('search(') ?? false;
    if (selections != null && !external) {
      final offered = {for (final c in prompt.selectChoices) c.value};
      for (final s in selections) {
        final choice = s.choice?.value ?? s.xmlValue;
        if (!offered.contains(choice)) {
          return (null, '"$choice" is not one of the choices');
        }
      }
    }
    return (value, null);
  }

  /// Adds an instance to the repeat at [repeat] (a [RepeatNode]'s index);
  /// returns the new instance's index.
  FormIndex addRepeatInstance(FormIndex repeat) {
    final index = _form.descendIntoRepeat(repeat, -1);
    _form.createNewRepeat(index);
    _emit(FormChange('repeat', [index.reference!]));
    return index;
  }

  /// Removes the repeat instance containing [index]; returns the removed
  /// instance's index.
  FormIndex removeRepeatInstance(FormIndex index) {
    final removed = _form.deleteRepeat(index);
    _emit(FormChange('repeat', [removed.reference!]));
    return removed;
  }

  /// The whole instance as XML (non-relevant values included), to resume
  /// later with [FormDefinition.createSession].
  String saveDraft() => XFormSerializingVisitor(
    respectRelevance: false,
  ).serializeInstanceToString(_form.mainInstance);

  /// Validates the whole form and, when valid, finalizes it (end
  /// timestamps, finalization processors) and serializes the submission.
  FinalizeResult finalize() {
    final outcome = _form.validate();
    if (outcome != null) {
      final prompt = _controller.model.questionPrompt(outcome.failedPrompt);
      final result = outcome.outcome == AnswerStatus.requiredButEmpty
          ? AnswerRequired(bindAttributeValue(prompt, 'requiredMsg'))
          : AnswerConstraintViolated(prompt.constraintText());
      return FinalizeFailure(ValidationFailure(outcome.failedPrompt, result));
    }
    _controller.finalizeFormEntry();
    final serializer = XFormSerializingVisitor();
    final xml = serializer.serializeInstanceToString(_form.mainInstance);
    return FinalizeSuccess(
      Submission(xml, _instanceId(), [
        for (final pointer in serializer.dataPointers) pointer.displayText,
      ]),
    );
  }

  String? _instanceId() {
    final root = _form.mainInstance.root;
    final meta = root.getChild('meta', 0) ?? root.getChild('orx:meta', 0);
    return meta?.getChild('instanceID', 0)?.value?.displayText;
  }

  /// Stops reporting changes: [changes] is done and the session no longer
  /// listens to its form, so it can be garbage collected. Call it when the
  /// session is no longer needed (e.g. when its screen is disposed).
  /// Calling it again does nothing.
  ///
  /// The session can still be read and answered afterwards, without
  /// change events, until the [definition] starts another session.
  Future<void> close() => _detach();

  Future<void> _detach() {
    _form.removeEventListener(_onEvaluation);
    if (identical(definition._session, this)) definition._session = null;
    return _changes.close();
  }
}

/// A cursor over the form with JavaRosa's navigation: questions, groups,
/// repeat instances and "add another?" prompts, skipping non-relevant
/// nodes.
final class FormNavigator {
  FormNavigator._(this._session);

  final FormSession _session;

  FormEntryController get _controller => _session._controller;

  /// The current position.
  FormIndex get position => _controller.model.formIndex;

  /// What is at the current position.
  FormEntryEvent get event => _controller.model.event();

  /// The node at the current position (the root before and after the
  /// form).
  FormNode get current => _session.nodeAt(position);

  /// Moves to the next relevant element.
  FormEntryEvent next() => _controller.stepToNextEvent();

  /// Moves to the previous relevant element.
  FormEntryEvent previous() => _controller.stepToPreviousEvent();

  /// Moves to [index].
  FormEntryEvent jumpTo(FormIndex index) => _controller.jumpToIndex(index);

  /// Moves before the first element.
  FormEntryEvent jumpToBeginning() =>
      _controller.jumpToIndex(FormIndex.beginningOfForm());

  /// Moves after the last element.
  FormEntryEvent jumpToEnd() => _controller.jumpToIndex(FormIndex.endOfForm());

  /// At a new-repeat prompt: adds the instance and moves into it.
  FormIndex addRepeatAndEnter() => _controller.descendIntoNewRepeat();

  /// Moves forward to the new-repeat prompt of the current repeat.
  void jumpToNewRepeatPrompt() => _controller.jumpToNewRepeatPrompt();
}
