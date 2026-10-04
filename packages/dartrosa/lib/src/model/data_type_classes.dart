import 'data/answer_value.dart';
import 'data_type.dart';

/// The answer value class for each data type.
///
/// Port of `org.javarosa.core.model.DataTypeClasses`.
abstract final class DataTypeClasses {
  static const Map<DataType, Type> _classesByType = {
    DataType.nullType: StringValue,
    DataType.text: StringValue,
    DataType.integer: IntegerValue,
    DataType.long: LongValue,
    DataType.decimal: DecimalValue,
    DataType.boolean: BooleanValue,
    DataType.date: DateValue,
    DataType.time: TimeValue,
    DataType.dateTime: DateTimeValue,
    DataType.choice: SelectOneValue,
    DataType.multipleItems: SelectMultiValue,
    DataType.geopoint: GeoPointValue,
    DataType.geoshape: GeoShapeValue,
    DataType.geotrace: GeoTraceValue,
  };

  /// The answer value class for [dataType], or `null`.
  static Type? classForType(DataType dataType) => _classesByType[dataType];
}
