import '../model/data/answer_value.dart';
import '../model/utils/date_utils.dart';
import '../util/java_double.dart';

/// [data] as written into instance XML: a string, or for several
/// attached files the list of their names (JavaRosa builds `<data>`
/// elements); `null` for no answer.
///
/// Port of `XFormAnswerDataSerializer.serializeAnswerData`.
Object? serializeAnswerData(AnswerValue? data) => switch (data) {
  null => null,
  UncastValue(:final string) || StringValue(:final string) => string,
  DateValue(:final date) => formatDate(date, DateFormatStyle.iso8601),
  DateTimeValue(:final dateTime) => formatDateTime(
    dateTime,
    DateFormatStyle.iso8601,
  ),
  TimeValue(:final time) => formatTime(time, DateFormatStyle.iso8601),
  PointerValue(:final pointer) => pointer.displayText,
  MultiPointerValue(:final pointers) =>
    pointers.length == 1
        ? pointers.single.displayText
        : [for (final p in pointers) p.displayText],
  MultipleItemsValue(:final selections) =>
    selections.map((s) => s.value).join(' '),
  SelectOneValue(:final selection) => selection.value,
  IntegerValue(:final n) || LongValue(:final n) => '$n',
  DecimalValue(:final d) => javaDoubleToString(d),
  GeoPointValue() || GeoTraceValue() || GeoShapeValue() => data.displayText,
  BooleanValue(:final b) => b ? '1' : '0',
};

/// Whether [serializeAnswerData] supports [data] (every answer type but
/// [BooleanValue], as in JavaRosa).
///
/// Port of `XFormAnswerDataSerializer.canSerialize`.
bool canSerializeAnswerData(AnswerValue? data) => switch (data) {
  null || BooleanValue() => false,
  _ => true,
};
