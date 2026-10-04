import '../model/data_type.dart';

/// Bind `type` names (without namespace prefix) → data types.
///
/// Port of `org.javarosa.xform.parse.TypeMappings`. Note that JavaRosa maps
/// the XSD binary and URI types to [DataType.unsupported].
const Map<String, DataType> typeMappings = {
  // xsd
  'string': DataType.text,
  'integer': DataType.integer,
  'long': DataType.long,
  'int': DataType.integer,
  'decimal': DataType.decimal,
  'double': DataType.decimal,
  'float': DataType.decimal,
  'dateTime': DataType.dateTime,
  'date': DataType.date,
  'time': DataType.time,
  'gYear': DataType.unsupported,
  'gMonth': DataType.unsupported,
  'gDay': DataType.unsupported,
  'gYearMonth': DataType.unsupported,
  'gMonthDay': DataType.unsupported,
  'boolean': DataType.boolean,
  'base64Binary': DataType.unsupported,
  'hexBinary': DataType.unsupported,
  'anyURI': DataType.unsupported,
  // xforms
  'listItem': DataType.choice,
  'listItems': DataType.multipleItems,
  // non-standard
  'select1': DataType.choice,
  'select': DataType.multipleItems,
  'rank': DataType.multipleItems,
  'geopoint': DataType.geopoint,
  'geoshape': DataType.geoshape,
  'geotrace': DataType.geotrace,
  'barcode': DataType.barcode,
  'binary': DataType.binary,
};
