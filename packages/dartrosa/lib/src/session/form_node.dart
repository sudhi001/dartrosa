import '../form_api/form_entry_caption.dart';
import '../form_api/form_entry_model.dart';
import '../form_api/form_entry_prompt.dart';
import '../model/control_type.dart';
import '../model/data/answer_value.dart';
import '../model/data_type.dart';
import '../model/form_element.dart';
import '../model/form_index.dart';
import '../model/instance/tree_element.dart';
import '../model/instance/tree_reference.dart';
import '../model/select_choice.dart';

/// A text with its media and alternative forms, in the current language
/// with `<output>`s filled in.
final class LocalizedText {
  /// Creates a text.
  const LocalizedText({
    this.text,
    this.short,
    this.image,
    this.bigImage,
    this.audio,
    this.video,
    this.guidance,
  });

  /// The text (long form).
  final String? text;

  /// The short form, if any.
  final String? short;

  /// Image URI (`jr://images/...`), if any.
  final String? image;

  /// Big image URI, if any.
  final String? bigImage;

  /// Audio URI, if any.
  final String? audio;

  /// Video URI, if any.
  final String? video;

  /// Guidance hint, if any.
  final String? guidance;

  static LocalizedText _of(FormEntryCaption caption) => LocalizedText(
    text: caption.longText,
    short: caption.specialFormQuestionText(FormEntryCaption.textFormShort),
    image: caption.imageText,
    bigImage: caption.specialFormQuestionText('big-image'),
    audio: caption.audioText,
    video: caption.specialFormQuestionText(FormEntryCaption.textFormVideo),
    guidance: caption.specialFormQuestionText('guidance'),
  );

  @override
  String toString() => text ?? '';
}

/// A node of a form being filled: a group, repeat, repeat instance or
/// question. Nodes are views of the session's current state; read them
/// again after changes.
sealed class FormNode {
  FormNode._(this._model, this.index);

  final FormEntryModel _model;

  /// Where the node is in the form.
  final FormIndex index;

  /// The node's instance reference.
  TreeReference? get ref => index.reference;

  /// The form element.
  FormElement get element => _model.form.elementAt(index);

  /// Whether the node is relevant (shown).
  bool get isRelevant => _model.isIndexRelevant(index);

  /// Whether the node is read-only.
  bool get isReadonly => _model.isIndexReadonly(index);

  /// The `appearance` attribute.
  String? get appearance => element.appearance;

  /// The node's label.
  LocalizedText get label => LocalizedText._of(_model.captionPrompt(index));

  /// The groups and repeat instances containing this node, outermost
  /// first.
  List<FormNode> get ancestors => [
    for (final caption in _model.captionHierarchy(index))
      if (caption.index != index) _nodeAt(_model, caption.index),
  ];
}

/// A node with children.
sealed class ContainerNode extends FormNode {
  ContainerNode._(super.model, super.index) : super._();

  /// All children, relevant or not.
  List<FormNode> get children;

  /// The relevant children.
  List<FormNode> get visibleChildren => [
    for (final child in children)
      if (child.isRelevant) child,
  ];
}

/// The whole form.
final class RootNode extends ContainerNode {
  RootNode._(FormEntryModel model)
    : super._(model, FormIndex.beginningOfForm());

  @override
  bool get isRelevant => true;

  @override
  bool get isReadonly => false;

  @override
  LocalizedText get label => LocalizedText(text: _model.form.title);

  @override
  List<FormNode> get ancestors => const [];

  @override
  List<FormNode> get children => _childrenOf(_model, null, _model.form);
}

/// A group (`<group>`).
final class GroupNode extends ContainerNode {
  GroupNode._(super.model, super.index) : super._();

  /// Whether the group is shown as one screen (`field-list`).
  bool get isFieldList =>
      appearance?.toLowerCase().contains('field-list') ?? false;

  @override
  List<FormNode> get children => _childrenOf(_model, index, element);
}

/// A repeat (`<repeat>`) with its instances.
final class RepeatNode extends FormNode {
  RepeatNode._(super.model, super.index) : super._();

  @override
  bool get isRelevant => true;

  /// The repeat definition.
  GroupDef get repeat => element as GroupDef;

  /// The existing instances.
  List<RepeatInstanceNode> get instances {
    final form = _model.form;
    final count = form.numRepetitions(index);
    return [
      for (var i = 0; i < count; i++)
        RepeatInstanceNode._(_model, form.descendIntoRepeat(index, i)),
    ];
  }

  /// Whether another instance may be added (no fixed `jr:count`/
  /// `noAddRemove`, and the repeat is relevant).
  bool get canAddInstance {
    final newIndex = _model.form.descendIntoRepeat(index, -1);
    return _model.isIndexRelevant(newIndex);
  }
}

/// One instance of a repeat.
final class RepeatInstanceNode extends ContainerNode {
  RepeatInstanceNode._(super.model, super.index) : super._();

  /// The instance's position (0-based).
  int get position => index.elementMultiplicity;

  /// The instance's header, such as `Child 2/3`.
  String? get header =>
      _model.captionPrompt(index).repetitionText(newRepeat: false);

  @override
  List<FormNode> get children => _childrenOf(_model, index, element);
}

/// A question (input, select, upload, trigger, range, ...).
final class QuestionNode extends FormNode {
  QuestionNode._(super.model, super.index) : super._();

  FormEntryPrompt get _prompt => _model.questionPrompt(index);

  /// The question definition.
  QuestionDef get question => element as QuestionDef;

  /// The control type.
  ControlType get controlType => question.controlType;

  /// The instance node's data type.
  DataType get dataType => _prompt.dataType;

  /// The current answer.
  AnswerValue? get value => _prompt.answerValue;

  /// The answer as displayed (choice labels, masked secrets).
  String? get displayValue => _prompt.answerText;

  /// The hint.
  String? get hint => _prompt.helpText;

  /// Whether an answer is required.
  bool get isRequired => _prompt.isRequired;

  /// The constraint message, if the form has one.
  String? get constraintMessage => _prompt.constraintText();

  /// The required message (`jr:requiredMsg`), if any.
  String? get requiredMessage => _prompt.treeElement.bindAttributes
      .where((a) => a.name == 'requiredMsg')
      .firstOrNull
      ?.attributeValue;

  /// The choices of a select (re-evaluated for itemsets).
  List<SelectChoice> get choices => _prompt.selectChoices;

  /// The label of [choice] in the current language.
  String? choiceLabel(SelectChoice choice) => _prompt.selectChoiceText(choice);

  /// The [form] (`image`, `audio`, ...) of [choice]'s label, if any.
  String? choiceMedia(SelectChoice choice, String form) =>
      _prompt.specialFormSelectChoiceText(choice, form);

  /// Bind attributes not handled by the engine (e.g. `jr:requiredMsg`).
  List<TreeElement> get bindAttributes => _prompt.bindAttributes;

  /// Body attributes not handled by the engine (e.g. `rows`, `query`).
  List<TreeElement> get attributes => question.additionalAttributes;

  /// Whether this is a note: a read-only text input.
  bool get isNote =>
      controlType == ControlType.input &&
      isReadonly &&
      (dataType == DataType.text || dataType == DataType.nullType);
}

FormNode _nodeAt(FormEntryModel model, FormIndex index) {
  final element = model.form.elementAt(index);
  if (element is QuestionDef) return QuestionNode._(model, index);
  final group = element as GroupDef;
  if (!group.isRepeat) return GroupNode._(model, index);
  return index.elementMultiplicity >= 0 &&
          model.form.mainInstance.resolveReference(index.reference!) != null
      ? RepeatInstanceNode._(model, index)
      : RepeatNode._(model, index);
}

/// The child nodes of the element at [parent] (`null` for the form).
List<FormNode> _childrenOf(
  FormEntryModel model,
  FormIndex? parent,
  FormElement element,
) {
  final form = model.form;
  final indexes = <int>[];
  final multiplicities = <int>[];
  final elements = <FormElement>[];
  if (parent != null) {
    form.collapseIndex(parent, indexes, multiplicities, elements);
  }
  return [
    for (final (i, child) in element.children.indexed)
      () {
        final index = form.buildIndex([...indexes, i], [...multiplicities, 0], [
          ...elements,
          child,
        ])!;
        return child is GroupDef && child.isRepeat
            ? RepeatNode._(model, index)
            : _nodeAt(model, index);
      }(),
  ];
}

/// The node at [index] in [model]'s form. Used by the session.
FormNode nodeAtIndex(FormEntryModel model, FormIndex index) =>
    index.isInForm ? _nodeAt(model, index) : RootNode._(model);

/// The root node of [model]'s form. Used by the session.
RootNode rootNode(FormEntryModel model) => RootNode._(model);
