import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The renderer's own UI strings (buttons, prompts, default messages).
/// English by default; subclass and register a [LocalizationsDelegate]
/// for other languages. Form content comes from the form's translations.
class XFormLocalizations {
  /// Creates the English strings.
  const XFormLocalizations();

  /// The strings in [context], or English.
  static XFormLocalizations of(BuildContext context) =>
      Localizations.of<XFormLocalizations>(context, XFormLocalizations) ??
      const XFormLocalizations();

  /// A delegate loading the English strings for every locale.
  static const LocalizationsDelegate<XFormLocalizations> delegate =
      _EnglishDelegate();

  /// Moves to the next screen.
  String get next => 'Next';

  /// Moves to the previous screen.
  String get back => 'Back';

  /// Finishes a scrolling form.
  String get finish => 'Finish';

  /// Finalizes the form on its last screen.
  String get finalize => 'Finalize';

  /// Shown on the last screen.
  String get endOfForm => "You're at the end of the form.";

  /// Asks whether to add a repeat instance named [label].
  String addRepeatPrompt(String label) => 'Add a new "$label" group?';

  /// Adds a repeat instance (pager prompt).
  String get addGroup => 'Add group';

  /// Declines adding a repeat instance.
  String get doNotAdd => 'Do not add';

  /// Adds a repeat instance named [label] (scroll mode).
  String addRepeat(String? label) =>
      label == null || label.isEmpty ? 'Add another' : 'Add $label';

  /// Removes a repeat instance.
  String get remove => 'Remove';

  /// The error of a required question without `jr:requiredMsg`.
  String get requiredDefault => 'Sorry, this response is required!';

  /// The error of a failed constraint without `jr:constraintMsg`.
  String get constraintDefault => 'Sorry, this response is not valid.';

  /// Shown when finalizing fails.
  String get answersNeedAttention => 'Some answers need attention.';

  /// Clears an answer.
  String get clear => 'Clear';

  /// Opens a date picker.
  String get selectDate => 'Select date';

  /// Opens a time picker.
  String get selectTime => 'Select time';

  /// Opens a date and time picker.
  String get selectDateTime => 'Select date and time';

  /// Acknowledges a trigger.
  String get acknowledge => 'OK';

  /// Captures media through the delegates.
  String get capture => 'Capture';

  /// Gets the location through the delegates.
  String get getLocation => 'Get location';

  /// Scans a barcode through the delegates.
  String get scan => 'Scan';

  /// Expands a guidance hint.
  String get guidance => 'Guidance';

  /// Marks a required question for screen readers.
  String get required => 'required';

  /// The name of [month] (1-12).
  String monthName(int month) => const [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ][month - 1];
}

class _EnglishDelegate extends LocalizationsDelegate<XFormLocalizations> {
  const _EnglishDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<XFormLocalizations> load(Locale locale) =>
      SynchronousFuture(const XFormLocalizations());

  @override
  bool shouldReload(_EnglishDelegate old) => false;
}

/// Languages written right to left (ISO 639-1 codes).
const rtlLanguageCodes = {
  'ar', 'fa', 'he', 'ur', 'ps', 'sd', 'ug', 'yi', 'dv', //
};

const _rtlNames = {
  'arabic', 'farsi', 'persian', 'hebrew', 'urdu', 'pashto', 'sindhi', //
  'uyghur', 'yiddish', 'dhivehi',
};

/// The text direction of a form language such as `ar`, `fa-IR` or
/// `Arabic (ar)`; `null` without a language.
TextDirection? textDirectionOfLanguage(String? language) {
  if (language == null || language.trim().isEmpty) return null;
  final lower = language.toLowerCase().trim();
  final code = RegExp(r'\(([^)]*)\)').firstMatch(lower)?[1] ?? lower;
  final primary = code.trim().split(RegExp('[-_ ]')).first;
  final name = lower.split(RegExp(r'[\s(]')).first;
  return rtlLanguageCodes.contains(primary) || _rtlNames.contains(name)
      ? TextDirection.rtl
      : TextDirection.ltr;
}
