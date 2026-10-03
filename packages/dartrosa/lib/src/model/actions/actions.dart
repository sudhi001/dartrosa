import '../../xpath/expression.dart';
import '../condition/evaluation_context.dart';
import '../form_def.dart';
import '../form_element.dart';
import '../instance/tree_reference.dart';

/// XForms events that can trigger actions.
///
/// Port of `org.javarosa.core.model.actions.Actions`.
abstract final class FormEvents {
  /// When a new instance is first loaded.
  static const odkInstanceFirstLoad = 'odk-instance-first-load';

  /// Whenever an instance (new or saved) is loaded.
  static const odkInstanceLoad = 'odk-instance-load';

  /// Deprecated alias of [odkInstanceFirstLoad].
  static const xformsReady = 'xforms-ready';

  /// Before the form is finalized.
  static const xformsRevalidate = 'xforms-revalidate';

  /// When a repeat instance is added.
  static const odkNewRepeat = 'odk-new-repeat';

  /// Deprecated alias of [odkNewRepeat].
  static const jrInsert = 'jr-insert';

  /// When a question's value changes.
  static const xformsValueChanged = 'xforms-value-changed';

  static const _all = {
    odkInstanceFirstLoad, odkInstanceLoad, xformsReady, //
    odkNewRepeat, jrInsert, xformsValueChanged, xformsRevalidate,
  };

  static const _instanceLoad = {
    odkInstanceFirstLoad,
    odkInstanceLoad,
    xformsReady,
  };

  static const _topLevel = {
    odkInstanceFirstLoad,
    odkInstanceLoad,
    xformsReady,
    xformsRevalidate,
  };

  /// Whether [event] is supported.
  static bool isValid(String event) => _all.contains(event);

  /// Whether [event] is dispatched to the whole form.
  static bool isTopLevel(String event) => _topLevel.contains(event);

  /// Whether [event] is an instance-load event.
  static bool isInstanceLoad(String event) => _instanceLoad.contains(event);
}

/// An XForms action such as `<setvalue>`.
///
/// Port of `org.javarosa.core.model.actions.Action`.
abstract class Action {
  /// Creates an action called [name] (its element name).
  Action(this.name);

  /// The element name, e.g. `setvalue`.
  final String name;

  /// Performs the action in [form], within [context] (a repeat instance or
  /// `null` for top level); returns the reference it set, if any.
  TreeReference? processAction(FormDef form, TreeReference? context);
}

/// Receives the reference each triggered action set. Port of
/// `ActionController.ActionResultProcessor`.
typedef ActionResultProcessor =
    void Function(TreeReference target, String event);

/// The actions registered on a form element, by event.
///
/// Port of `org.javarosa.core.model.actions.ActionController`.
final class ActionController {
  final Map<String, List<Action>> _listeners = {};

  /// The actions registered for [event].
  List<Action> listenersFor(String event) =>
      List.unmodifiable(_listeners[event] ?? const []);

  /// Registers [action] for each of [events].
  void registerEventListener(Iterable<String> events, Action action) {
    for (final event in events) {
      (_listeners[event] ??= []).add(action);
    }
  }

  /// Triggers [event]'s actions here, then in every instance of each of
  /// [nestedElements] (elements inside repeats with top-level events).
  void triggerActionsFromEventNested(
    String event,
    Iterable<FormElement> nestedElements,
    FormDef form,
  ) {
    triggerActionsFromEvent(event, form, null, null);
    for (final element in nestedElements) {
      final reference = element.bind!;
      final unqualified = element is GroupDef
          ? reference
          : reference.parentRef!;
      final context = EvaluationContext.withContext(
        form.evaluationContext,
        unqualified,
      );
      for (final contextRef in context.expandReference(unqualified)!) {
        element.actionController.triggerActionsFromEvent(
          event,
          form,
          contextRef,
          null,
        );
      }
    }
  }

  /// Triggers [event]'s actions in [context], reporting each set reference
  /// to [resultProcessor].
  void triggerActionsFromEvent(
    String event,
    FormDef form,
    TreeReference? context,
    ActionResultProcessor? resultProcessor,
  ) {
    for (final action in listenersFor(event)) {
      final ref = action.processAction(form, context);
      if (resultProcessor != null && ref != null) resultProcessor(ref, event);
    }
  }
}

/// `<setvalue>`: sets [target] to [value] when its event fires.
///
/// Port of `SetValueAction`; [processAction] needs the engine's value
/// setting and is completed in Phase 4.
final class SetValueAction extends Action {
  /// Creates the action.
  SetValueAction(this.target, this.value) : super(elementName);

  /// The element name.
  static const elementName = 'setvalue';

  /// The node to set.
  final TreeReference target;

  /// The value expression (a string literal for literal content).
  final XPathExpression value;

  @override
  TreeReference? processAction(FormDef form, TreeReference? context) =>
      form.processSetValue(this, context);
}

/// `<odk:setgeopoint>`: records the device location into [targetReference].
///
/// Port of `SetGeopointAction`. Apps provide location through
/// [requestLocationUpdates] and report it with [saveLocationValue].
abstract class SetGeopointAction extends Action {
  /// Creates the action for [targetReference].
  SetGeopointAction(this.targetReference) : super(elementName);

  /// The element name.
  static const elementName = 'setgeopoint';

  /// The node to set.
  TreeReference? targetReference;

  TreeReference? _contextualizedTarget;
  FormDef? _form;

  /// The target anchored to the triggering context.
  TreeReference? get contextualizedTargetReference => _contextualizedTarget;

  @override
  TreeReference? processAction(FormDef form, TreeReference? context) {
    _form = form;
    _contextualizedTarget = context == null
        ? targetReference
        : targetReference!.contextualize(context);
    requestLocationUpdates();
    return _contextualizedTarget;
  }

  /// Starts obtaining a location; call [saveLocationValue] with it.
  void requestLocationUpdates();

  /// Stores [location] (an ODK geopoint string) in the target.
  void saveLocationValue(String location) =>
      _form!.saveActionValue(_contextualizedTarget!, location);
}

/// Stores "no client implementation", as JavaRosa's default.
///
/// Port of `StubSetGeopointAction`.
final class StubSetGeopointAction extends SetGeopointAction {
  /// Creates the stub.
  StubSetGeopointAction(super.targetReference);

  @override
  void requestLocationUpdates() =>
      saveLocationValue('no client implementation');
}

/// Receives `<odk:recordaudio>` requests.
///
/// Port of `RecordAudioActionListener`.
typedef RecordAudioListener =
    void Function(TreeReference absoluteTargetRef, String? quality);

/// `<odk:recordaudio>`: asks the app to record audio into
/// [targetReference] in the background.
///
/// Port of `RecordAudioAction` (the listener is a per-form setting instead
/// of JavaRosa's static `RecordAudioActions`).
final class RecordAudioAction extends Action {
  /// Creates the action.
  RecordAudioAction(this.targetReference, this.quality) : super(elementName);

  /// The element name.
  static const elementName = 'recordaudio';

  /// The node to record into.
  final TreeReference targetReference;

  /// The `odk:quality` attribute.
  final String? quality;

  @override
  TreeReference? processAction(FormDef form, TreeReference? context) {
    final target = context == null
        ? targetReference
        : targetReference.contextualize(context)!;
    form.recordAudioListener?.call(target, quality);
    return target;
  }
}
