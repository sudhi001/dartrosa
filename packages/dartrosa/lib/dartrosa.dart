/// Pure-Dart ODK XForms engine. A port of JavaRosa.
///
/// Parse a form with [FormDefinition.parse], start a [FormSession] with
/// [FormDefinition.createSession], then read its node tree
/// ([FormSession.root]) or step through it with its [FormNavigator], and
/// answer questions with [FormSession.answer].
///
/// The JavaRosa-compatible API (`FormDef`, `FormEntryController`, ...) is
/// available from `package:dartrosa/javarosa.dart`.
///
/// @docImport 'src/session/form_session.dart';
library;

export 'src/form_api/form_entry_model.dart' show FormEntryEvent;
export 'src/model/control_type.dart';
export 'src/model/data/answer_value.dart';
export 'src/model/data_type.dart';
export 'src/model/form_element.dart'
    show FormElement, GroupDef, QuestionDef, RangeQuestion;
export 'src/model/form_index.dart';
export 'src/model/instance/tree_reference.dart' show TreeReference;
export 'src/model/select_choice.dart';
export 'src/model/utils/question_preloader.dart'
    show MapPropertyManager, PreloadHandler, PropertyManager;
export 'src/reference/reference_manager.dart';
export 'src/reference/resource_resolver.dart';
export 'src/session/answer_result.dart';
export 'src/session/config.dart';
export 'src/session/form_node.dart'
    hide bindAttributeValue, nodeAtIndex, rootNode;
export 'src/session/form_session.dart';
export 'src/xform/xform_parse_exception.dart';
export 'src/xpath/exceptions.dart';
