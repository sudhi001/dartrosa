import '../i18n/localizer.dart';
import '../xpath/exceptions.dart';
import 'actions/actions.dart';
import 'control_type.dart';
import 'data/answer_value.dart';
import 'instance/tree_element.dart';
import 'instance/tree_reference.dart';
import 'itemset_binding.dart';
import 'select_choice.dart';

/// Receives state changes of a [FormElement] (an [ElementChange] flag set).
///
/// Port of `FormElementStateListener` for form elements.
typedef FormElementListener = void Function(FormElement element, int changes);

/// A node of the form's control tree: the form itself, a group, a repeat or
/// a question.
///
/// Port of `org.javarosa.core.model.IFormElement` (and its shared state).
/// Form elements are built by the XForm parser and then read by the engine.
abstract class FormElement implements Localizable {
  /// Creates an element with [id].
  FormElement({this.id = -1});

  /// A form-wide unique id assigned by the parser.
  int id;

  /// The absolute reference this element is bound to (`null` for a
  /// trigger without `ref`).
  TreeReference? bind;

  /// Literal label text (when not localized).
  String? labelInnerText;

  /// The `appearance` attribute.
  String? appearance;

  String? _textId;

  /// The itext id of the label. A `;form` suffix is stripped, as in
  /// JavaRosa.
  String? get textId => _textId;

  set textId(String? textId) {
    if (textId != null && textId.contains(';')) {
      textId = textId.substring(0, textId.indexOf(';'));
    }
    _textId = textId;
  }

  /// Attributes of the control element not handled by the parser, kept
  /// verbatim (e.g. `rows`, `odk:tag`).
  final List<TreeElement> additionalAttributes = [];

  /// Actions registered on this element, by event.
  final ActionController actionController = ActionController();

  final List<FormElementListener> _listeners = [];

  /// Child elements (empty for questions).
  List<FormElement> get children;

  /// The child at [i], or `null` if out of range.
  FormElement? childAt(int i) =>
      i >= 0 && i < children.length ? children[i] : null;

  /// Adds [child]. Throws for questions.
  void addChild(FormElement child);

  /// Number of questions at or below this element.
  int get deepChildCount;

  /// Sets, adds or removes (with a `null` [value]) an additional attribute.
  void setAdditionalAttribute(String? namespace, String name, String? value) =>
      TreeElement.setAttributeIn(
        null,
        additionalAttributes,
        namespace,
        name,
        value,
      );

  /// The value of additional attribute [name] in [namespace], if present.
  String? additionalAttribute(String? namespace, String name) =>
      TreeElement.findAttributeIn(
        additionalAttributes,
        namespace,
        name,
      )?.attributeValue;

  /// Registers [listener] (once).
  void addListener(FormElementListener listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  /// Unregisters [listener].
  void removeListener(FormElementListener listener) =>
      _listeners.remove(listener);

  /// Notifies listeners of [changes].
  void notifyListeners(int changes) {
    for (final listener in [..._listeners]) {
      listener(this, changes);
    }
  }
}

/// A `<group>` or `<repeat>`.
///
/// Port of `org.javarosa.core.model.GroupDef`.
final class GroupDef extends FormElement {
  /// Creates a group (or, with [isRepeat], a repeat).
  GroupDef({super.id, this.isRepeat = false, List<FormElement>? children})
    : _children = children ?? [];

  final List<FormElement> _children;

  /// Whether this is a `<repeat>`.
  bool isRepeat;

  /// Whether the user may not add or remove repeat instances
  /// (`jr:noAddRemove`, or implied by `jr:count`).
  bool noAddRemove = false;

  /// The `jr:count` reference, if any.
  TreeReference? count;

  /// `jr:chooseCaption`
  String? chooseCaption;

  /// `jr:addCaption`
  String? addCaption;

  /// `jr:delCaption`
  String? delCaption;

  /// `jr:doneCaption`
  String? doneCaption;

  /// `jr:addEmptyCaption`
  String? addEmptyCaption;

  /// `jr:doneEmptyCaption`
  String? doneEmptyCaption;

  /// `jr:entryHeader`
  String? entryHeader;

  /// `jr:delHeader`
  String? delHeader;

  /// `jr:mainHeader`
  String? mainHeader;

  @override
  List<FormElement> get children => _children;

  /// Replaces child [i] (used when collapsing a group around a repeat).
  void replaceChildAt(int i, FormElement child) => _children[i] = child;

  @override
  void addChild(FormElement child) => _children.add(child);

  @override
  int get deepChildCount =>
      _children.fold(0, (total, child) => total + child.deepChildCount);

  /// The `jr:count` reference anchored to [context].
  TreeReference? contextualizedCountReference(TreeReference context) =>
      count?.contextualize(context);

  @override
  void localeChanged(String locale, Localizer localizer) {
    for (final child in _children) {
      child.localeChanged(locale, localizer);
    }
  }

  @override
  String toString() => '<group>';
}

/// A key and choices offered by an OSM capture question.
///
/// Port of `org.javarosa.core.model.osm.OSMTag`.
final class OsmTag {
  /// The tag key.
  String? key;

  /// The tag label.
  String? label;

  /// The choices.
  final List<OsmTagItem> items = [];
}

/// One choice of an [OsmTag]. Port of `OSMTagItem`.
final class OsmTagItem {
  /// The item label.
  String? label;

  /// The item value.
  String? value;
}

/// A question: one form control bound to one instance node.
///
/// Port of `org.javarosa.core.model.QuestionDef`.
class QuestionDef extends FormElement {
  /// Creates a question with [controlType].
  QuestionDef({super.id, this.controlType = ControlType.input});

  /// The kind of control.
  ControlType controlType;

  /// Hint text (the hint's text content), when not localized.
  String? helpText;

  /// Hint inner text (including `<output>` placeholders and HTML).
  String? helpInnerText;

  /// The itext id of the hint.
  String? helpTextId;

  /// Tags of an OSM capture question.
  List<OsmTag>? osmTags;

  List<SelectChoice>? _choices;

  /// The static choices (`<item>`s), or `null` when there are none.
  List<SelectChoice>? get choices =>
      _choices == null ? null : List.unmodifiable(_choices!);

  /// Dynamic choices from an `<itemset>`, if any.
  ItemsetBinding? dynamicChoices;

  /// Adds a static choice, assigning its index.
  void addSelectChoice(SelectChoice choice) {
    final choices = _choices ??= [];
    choice.index = choices.length;
    choices.add(choice);
  }

  /// Removes a static choice.
  void removeSelectChoice(SelectChoice choice) {
    if (_choices == null) {
      choice.index = 0;
      return;
    }
    _choices!.remove(choice);
  }

  /// The static choice at [i].
  SelectChoice choiceAt(int i) => _choices![i];

  /// Number of static choices.
  int get numChoices => _choices?.length ?? 0;

  /// The static choice whose value is [value], if any.
  SelectChoice? choiceForValue(String value) {
    for (var i = 0; i < numChoices; i++) {
      if (choiceAt(i).value == value) return choiceAt(i);
    }
    return null;
  }

  /// [selection] bound to its static choice (by index, else by value).
  /// Dynamic (itemset) choices can't be attached and return [selection]
  /// unchanged. Port of `Selection.attachChoice(QuestionDef)`, returning a
  /// new selection because DartRosa's are immutable.
  Selection attachChoice(Selection selection) {
    if (dynamicChoices != null) return selection;
    SelectChoice? choice;
    final index = selection.index;
    final xmlValue = selection.xmlValue;
    if (index != -1 && index < numChoices) {
      choice = choiceAt(index);
    } else if (xmlValue != null && xmlValue.isNotEmpty) {
      choice = choiceForValue(xmlValue);
    }
    if (choice == null) {
      throw XPathTypeMismatchException(
        'value $xmlValue could not be loaded into question $textId.  Check '
        'to see if value $xmlValue is a valid option for question $textId.',
      );
    }
    return Selection.ofChoice(choice);
  }

  /// Whether this question copies subtrees from its itemset (deprecated
  /// `<copy>` mode).
  bool get isComplex => dynamicChoices?.copyMode ?? false;

  /// Whether answers not among the choices should be cleared.
  bool get shouldLimitValueToSelectChoices =>
      controlType == ControlType.selectOne ||
      controlType == ControlType.selectMulti;

  @override
  List<FormElement> get children => const [];

  @override
  void addChild(FormElement child) =>
      throw StateError("Can't add children to question def");

  @override
  int get deepChildCount => 1;

  @override
  void localeChanged(String locale, Localizer localizer) {
    dynamicChoices?.localeChanged(locale, localizer);
    notifyListeners(ElementChange.locale);
  }
}

/// A `<range>` question with its bounds.
///
/// Port of `org.javarosa.core.model.RangeQuestion`. Values are kept as the
/// decimal text from the form (JavaRosa uses `BigDecimal`).
final class RangeQuestion extends QuestionDef {
  /// Creates a range question.
  RangeQuestion({super.id}) : super(controlType: ControlType.range);

  /// `start`
  String? rangeStart;

  /// `end`
  String? rangeEnd;

  /// `step`
  String? rangeStep;

  /// `odk:tick-interval`
  String? tickInterval;

  /// `odk:placeholder`
  String? placeholder;
}
