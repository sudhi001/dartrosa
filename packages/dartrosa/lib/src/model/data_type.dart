// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (DataType), Copyright 2018 Nafundi; modified:
//  translated to Dart.
// SPDX-License-Identifier: Apache-2.0

/// Data types of instance nodes and answers.
///
/// Port of `org.javarosa.core.model.DataType` (and the `DATATYPE_*`
/// constants), keeping JavaRosa's numeric codes.
enum DataType {
  /// A type JavaRosa does not support.
  unsupported(-1),

  /// No type declared.
  nullType(0),

  /// `string`
  text(1),

  /// `int`
  integer(2),

  /// `decimal`
  decimal(3),

  /// `date`
  date(4),

  /// `time`
  time(5),

  /// `dateTime`
  dateTime(6),

  /// `select1`
  choice(7),

  /// `select` / `odk:rank`
  multipleItems(8),

  /// `boolean`
  boolean(9),

  /// `geopoint`
  geopoint(10),

  /// `barcode`
  barcode(11),

  /// `binary` (attachments)
  binary(12),

  /// `long`
  long(13),

  /// `geoshape`
  geoshape(14),

  /// `geotrace`
  geotrace(15);

  const DataType(this.code);

  /// JavaRosa's numeric code.
  final int code;

  /// The type with JavaRosa code [code].
  static DataType fromCode(int code) => values.firstWhere(
    (type) => type.code == code,
    orElse: () => throw ArgumentError('No DataType with value $code'),
  );
}
