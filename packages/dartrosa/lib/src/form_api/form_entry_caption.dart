import '../i18n/localizer.dart';
import '../model/form_def.dart';
import '../model/form_element.dart';
import '../model/form_index.dart';
import '../model/instance/tree_element.dart';

/// Receives state changes of a registered caption or prompt.
///
/// Port of `org.javarosa.formmanager.view.IQuestionWidget`.
abstract interface class QuestionWidget {
  /// The element or its instance node changed ([ElementChange] flags).
  void refreshWidget(int changeFlags);
}

/// The texts of a group, repeat or question at a form index: label,
/// short/media forms and repeat captions, in the current language with
/// `<output>`s filled in.
///
/// Port of `org.javarosa.form.api.FormEntryCaption`.
class FormEntryCaption {
  /// The caption of the element at [index] in [form].
  FormEntryCaption(FormDef form, FormIndex index)
    : this._(form, index, form.elementAt(index));

  FormEntryCaption._(this.form, this.index, this.element)
    : _textId = element.textId;

  /// The form.
  final FormDef form;

  /// Where the element is.
  final FormIndex index;

  /// The group, repeat or question.
  final FormElement element;

  final String? _textId;

  /// The widget notified of changes, once [register]ed.
  QuestionWidget? viewWidget;

  /// The default itext form.
  static const textFormLong = 'long';

  /// The `short` itext form.
  static const textFormShort = 'short';

  /// The `audio` itext form.
  static const textFormAudio = 'audio';

  /// The `image` itext form.
  static const textFormImage = 'image';

  /// The `video` itext form.
  static const textFormVideo = 'video';

  /// The itext id of the label, if localized.
  String? get textId => _textId;

  /// The label (long form, else default form, else literal label).
  String? get longText => questionText(textId);

  /// The short label, falling back to [longText].
  String? get shortText =>
      specialFormQuestionText(textFormShort, textId) ?? longText;

  /// The label's audio URI, if any.
  String? get audioText => specialFormQuestionText(textFormAudio, textId);

  /// The label's image URI, if any.
  String? get imageText => specialFormQuestionText(textFormImage, textId);

  /// The label text for [textId] (by default this element's).
  String? questionText([String? textId]) {
    var tid = textId ?? _textId;
    if (tid != null && tid.isEmpty) tid = null;
    if (tid == null) return substituteStringArgs(element.labelInnerText);
    final text = itext(tid, 'long') ?? itext(tid, null);
    return substituteStringArgs(text);
  }

  /// The [form] text form of the label ([textId] by default this
  /// element's), if any.
  String? specialFormQuestionText(String? form, [String? textId]) {
    final tid = textId ?? _textId;
    if (tid == null || tid.isEmpty) return null;
    return substituteStringArgs(itext(tid, form));
  }

  /// The raw itext for [textId] in [form] (or the default form) in the
  /// current language; `null` without a localizer or text.
  String? itext(String? textId, String? form) {
    if (textId == null || textId.isEmpty) return null;
    final localizer = this.localizer;
    if (localizer == null) return null;
    final id = form != null && form.isNotEmpty ? '$textId;$form' : textId;
    return localizer.getRawText(localizer.locale, id);
  }

  /// A repeat caption: `mainheader`, `add`, `add-empty`, `del`, `done`,
  /// `done-empty` or `delheader`, with JavaRosa's English defaults.
  String? repeatText(String typeKey) {
    final g = element;
    if (g is! GroupDef || !g.isRepeat) throw StateError('not a repeat');
    final title = longText;
    final count = numRepetitions;
    String? caption;
    switch (typeKey) {
      case 'mainheader':
        caption = g.mainHeader;
        if (caption == null) return title;
      case 'add':
        caption = g.addCaption;
        if (caption == null) return 'Add another $title';
      case 'add-empty':
        caption = g.addEmptyCaption ?? g.addCaption;
        if (caption == null) return 'None - Add $title';
      case 'del':
        caption = g.delCaption;
        if (caption == null) return 'Delete $title';
      case 'done':
        caption = g.doneCaption;
        if (caption == null) return 'Done';
      case 'done-empty':
        caption = g.doneEmptyCaption ?? g.doneCaption;
        if (caption == null) return 'Skip';
      case 'delheader':
        caption = g.delHeader;
        if (caption == null) return 'Delete which $title?';
    }
    // JavaRosa fails on an unknown key; so does fillTemplateString(null).
    return form.fillTemplateString(caption!, index.reference!, {
      'name': title,
      'n': count,
    });
  }

  /// The number of instances of this repeat.
  int get numRepetitions => form.numRepetitions(index);

  /// The header of this repeat instance, such as `Child 2/3`.
  String? repetitionText({required bool newRepeat}) =>
      _repetitionText('header', index, newRepeat: newRepeat);

  String? _repetitionText(
    String type,
    FormIndex index, {
    required bool newRepeat,
  }) {
    final g = element;
    if (g is! GroupDef || !g.isRepeat || index.elementMultiplicity < 0) {
      return null;
    }
    final title = longText;
    final ix = index.elementMultiplicity + 1;
    final count = numRepetitions;
    final caption = switch (type) {
      'header' => g.entryHeader,
      'choose' => g.chooseCaption ?? g.entryHeader,
      _ => null,
    };
    if (caption == null) return '$title $ix/$count';
    return form.fillTemplateString(caption, index.reference!, {
      'name': title,
      'i': ix,
      'n': count,
      'new': newRepeat,
    });
  }

  /// The header of every instance of this repeat.
  List<String?> get repetitionsText {
    final g = element;
    if (g is! GroupDef || !g.isRepeat) throw StateError('not a repeat');
    return [
      for (var i = 0; i < numRepetitions; i++)
        _repetitionText(
          'choose',
          form.descendIntoRepeat(index, i),
          newRepeat: false,
        ),
    ];
  }

  /// The `appearance` attribute.
  String? get appearanceHint => element.appearance;

  /// [template] with its `${n}` outputs filled in at this index.
  String? substituteStringArgs(String? template) => template == null
      ? null
      : form.fillTemplateString(template, index.reference!);

  /// The repeat instance index (-1 outside repeats).
  int get multiplicity => index.elementMultiplicity;

  /// The group, repeat or question.
  FormElement get formElement => element;

  /// Whether the element is a repeat.
  bool get repeats {
    final e = element;
    return e is GroupDef && e.isRepeat;
  }

  /// The form's localizer.
  Localizer? get localizer => form.localizer;

  /// Notifies [widget] of state changes until [unregister].
  void register(QuestionWidget widget) {
    viewWidget = widget;
    element.addListener(_elementChanged);
  }

  /// Stops notifying the registered widget.
  void unregister() {
    viewWidget = null;
    element.removeListener(_elementChanged);
  }

  void _elementChanged(FormElement changed, int changeFlags) {
    if (!identical(changed, element)) {
      throw StateError('Widget received event from foreign question');
    }
    viewWidget?.refreshWidget(changeFlags);
  }
}
