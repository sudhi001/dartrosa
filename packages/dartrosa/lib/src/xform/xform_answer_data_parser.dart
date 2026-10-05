import '../model/data/answer_value.dart';
import '../model/data_type.dart';
import '../model/form_element.dart';
import '../model/utils/date_utils.dart' as date_utils;
import '../util/java_lang.dart';

/// Parses the XML text of an instance node into an answer of [dataType];
/// `null` when the text is empty or invalid for the type.
///
/// Port of `XFormAnswerDataParser.getAnswerData`. For select questions,
/// [question] attaches static choices (values without a matching choice
/// are dropped).
AnswerValue? parseAnswerData(
  String text,
  DataType dataType, [
  QuestionDef? question,
]) {
  final trimmed = javaTrim(text);
  final value = trimmed.isEmpty ? null : trimmed;
  switch (dataType) {
    case DataType.nullType ||
        DataType.unsupported ||
        DataType.text ||
        DataType.barcode ||
        DataType.binary:
      return StringValue(text);
    case DataType.integer:
      final n = value == null ? null : javaParseInt(value);
      return n == null ? null : IntegerValue(n);
    case DataType.long:
      final n = value == null ? null : javaParseInt(value, bits: 64);
      return n == null ? null : LongValue(n);
    case DataType.decimal:
      final d = value == null ? null : javaParseDouble(value);
      return d == null ? null : DecimalValue(d);
    case DataType.choice:
      final selection = _selection(text, question);
      return selection == null ? null : SelectOneValue(selection);
    case DataType.multipleItems:
      return MultipleItemsValue([
        for (final choice in date_utils.split(
          text,
          ' ',
          combineMultipleDelimiters: true,
        ))
          ?_selection(choice, question),
      ]);
    case DataType.dateTime:
      final d = value == null ? null : date_utils.parseDateTime(value);
      return d == null ? null : DateTimeValue(d);
    case DataType.date:
      final d = value == null ? null : date_utils.parseDate(value);
      return d == null ? null : DateValue(d);
    case DataType.time:
      final t = value == null ? null : date_utils.parseTime(value);
      return t == null ? null : TimeValue(t);
    case DataType.boolean:
      if (value == null) return null;
      if (value == '1') return const BooleanValue(true);
      if (value == '0') return const BooleanValue(false);
      return BooleanValue(value == 't');
    case DataType.geopoint:
      if (value == null) return const GeoPointValue.empty();
      try {
        return GeoPointValue.cast(UncastValue(value));
      } on Object {
        return null;
      }
    case DataType.geoshape:
      if (value == null) return GeoShapeValue(const []);
      try {
        return GeoShapeValue.cast(UncastValue(value));
      } on Object {
        return null;
      }
    case DataType.geotrace:
      if (value == null) return GeoTraceValue(const []);
      try {
        return GeoTraceValue.cast(UncastValue(value));
      } on Object {
        return null;
      }
  }
}

Selection? _selection(String value, QuestionDef? question) {
  if (question == null || question.dynamicChoices != null) {
    return Selection(value);
  }
  final choice = question.choiceForValue(value);
  return choice == null ? null : Selection.ofChoice(choice);
}
