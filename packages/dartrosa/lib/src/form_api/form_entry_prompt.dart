import 'package:logging/logging.dart';

import '../i18n/locale_exceptions.dart';
import '../model/condition/conditions.dart';
import '../model/condition/evaluation_context.dart';
import '../model/condition/pivot.dart';
import '../model/control_type.dart';
import '../model/data/answer_value.dart';
import '../model/data_type.dart';
import '../model/form_element.dart';
import '../model/instance/tree_element.dart';
import '../model/select_choice.dart';
import 'form_entry_caption.dart';

final _log = Logger('dartrosa.form_entry');

/// A question at a form index: its texts, answer, choices, constraint
/// message and state.
///
/// Port of `org.javarosa.form.api.FormEntryPrompt`.
class FormEntryPrompt extends FormEntryCaption {
  /// The prompt for the question at [index] in [form].
  FormEntryPrompt(super.form, super.index)
    : treeElement = form.mainInstance.resolveReference(index.reference!)! {
    if (element is! QuestionDef) {
      throw ArgumentError(
        'FormEntryPrompt can only be created for QuestionDef elements',
      );
    }
  }

  /// The question's instance node.
  final TreeElement treeElement;

  /// The question.
  QuestionDef get question => element as QuestionDef;

  /// The question's control type.
  ControlType get controlType => question.controlType;

  /// The instance node's data type.
  DataType get dataType => treeElement.dataType;

  /// The current answer. For deprecated `<copy>` itemsets, the selections
  /// matching the copied subtrees; for itemsets without `<value>`, `null`.
  AnswerValue? get answerValue {
    final q = question;
    final itemset = q.dynamicChoices;
    if (itemset == null) return treeElement.value;
    if (itemset.valueRef == null) return null;
    final choices = selectChoices;
    if (!itemset.copyMode) return treeElement.value;
    final destRef = itemset.destRef!.contextualize(treeElement.ref)!;
    final preselected = [
      for (final ref in form.evaluationContext.expandReference(destRef)!)
        itemset.relativeValue!.evalReadable(
          form.mainInstance,
          EvaluationContext.withContext(
            form.evaluationContext,
            form.mainInstance.resolveReference(ref)!.ref,
          ),
        ),
    ];
    final selections = [
      for (final value in preselected)
        if (choices.where((c) => c.value == value).firstOrNull case final c?)
          Selection.ofChoice(c),
    ];
    if (selections.isEmpty) return null;
    return switch (q.controlType) {
      ControlType.selectMulti ||
      ControlType.rank => MultipleItemsValue(selections),
      ControlType.selectOne => SelectOneValue(selections.first),
      _ => throw StateError("can't happen"),
    };
  }

  /// The answer as displayed: choice labels for selects, asterisks for
  /// secret inputs.
  String? get answerText {
    final data = answerValue;
    if (data == null) return null;
    var text = switch (data) {
      SelectOneValue(:final selection) => selectItemText(selection),
      MultipleItemsValue(:final selections) => [
        for (final s in selections) '${selectItemText(s)} ',
      ].join(),
      _ => data.displayText,
    };
    if (controlType == ControlType.secret) text = '*' * text!.length;
    return text;
  }

  /// The constraint message (in [textForm], if given), evaluated with
  /// [attemptedValue] as the candidate; `null` without a constraint.
  String? constraintText({String? textForm, AnswerValue? attemptedValue}) {
    final constraint = treeElement.constraint;
    if (constraint is! Constraint) return null;
    final ec = EvaluationContext.withContext(
      form.evaluationContext,
      treeElement.ref,
    );
    if (textForm != null) ec.outputTextForm = textForm;
    if (attemptedValue != null) {
      ec
        ..isConstraint = true
        ..candidateValue = attemptedValue;
    }
    return substituteStringArgs(
      constraint.constraintMessage(ec, form.mainInstance, textForm),
    );
  }

  /// The bind attributes not handled by JavaRosa itself.
  List<TreeElement> get bindAttributes => treeElement.bindAttributes;

  /// The choices: static ones, or the itemset's for this question.
  List<SelectChoice> get selectChoices {
    final itemset = question.dynamicChoices;
    if (itemset != null) return itemset.getChoices(form, treeElement.ref);
    return question.choices ?? const [];
  }

  /// Whether an answer is required.
  bool get isRequired => treeElement.isRequired;

  /// Whether the question is read-only.
  bool get isReadOnly => !treeElement.isEnabled;

  /// The hint: localized, else the literal hint.
  String? get helpText {
    final q = question;
    var help = q.helpText;
    try {
      final id = q.helpTextId;
      help = id != null
          ? substituteStringArgs(localizer!.getLocalizedText(id))
          : substituteStringArgs(q.helpInnerText);
    } on NoLocalizedTextException {
      // JavaRosa keeps the literal hint.
    } on UnregisteredLocaleException {
      _log.warning('No Locale set yet (while attempting to getHelpText())');
    } on Object catch (e) {
      _log.severe('FormEntryPrompt.getHelpText', e);
    }
    return help;
  }

  /// The label of the choice [selection] refers to.
  String? selectItemText(Selection selection) {
    final sel = selection.index == -1
        ? question.attachChoice(selection)
        : selection;
    final choice = sel.choice!;
    final tid = choice.textId;
    if (tid == null || tid.isEmpty) {
      return substituteStringArgs(choice.labelInnerText);
    }
    return substituteStringArgs(itext(tid, 'long') ?? itext(tid, null));
  }

  /// The label of [choice].
  String? selectChoiceText(SelectChoice choice) =>
      selectItemText(Selection.ofChoice(choice));

  /// The [form] text form of [selection]'s label, if any.
  String? specialFormSelectItemText(Selection selection, String? form) {
    final sel = selection.index == -1
        ? question.attachChoice(selection)
        : selection;
    final tid = sel.choice!.textId;
    if (tid == null || tid.isEmpty) return null;
    return substituteStringArgs(itext(tid, form));
  }

  /// The [form] text form of [choice]'s label, if any.
  String? specialFormSelectChoiceText(SelectChoice choice, String? form) =>
      specialFormSelectItemText(Selection.ofChoice(choice), form);

  /// Initializes [hint] with this question's constraint; throws
  /// [UnpivotableExpressionException] without one.
  void requestConstraintHint(ConstraintHint hint) {
    final constraint = treeElement.constraint;
    if (constraint is! Constraint) {
      throw const UnpivotableExpressionException();
    }
    hint.init(
      EvaluationContext.withContext(form.evaluationContext, treeElement.ref),
      constraint.constraint.expr,
      form.mainInstance,
    );
  }

  @override
  void register(QuestionWidget widget) {
    super.register(widget);
    treeElement.addListener(_nodeChanged);
  }

  @override
  void unregister() {
    treeElement.removeListener(_nodeChanged);
    super.unregister();
  }

  void _nodeChanged(TreeElement node, int changeFlags) {
    if (!identical(node, treeElement)) {
      throw StateError('Widget received event from foreign question');
    }
    viewWidget?.refreshWidget(changeFlags);
  }
}
