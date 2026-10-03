/// Kinds of form control (widget) a question uses.
///
/// Port of the `Constants.CONTROL_*` constants, keeping JavaRosa's codes.
enum ControlType {
  /// No control type.
  untyped(-1),

  /// `<input>`
  input(1),

  /// `<select1>`
  selectOne(2),

  /// `<select>`
  selectMulti(3),

  /// `<textarea>`
  textarea(4),

  /// `<secret>`
  secret(5),

  /// `<range>`
  range(6),

  /// `<upload>` without a recognized media type
  upload(7),

  /// `<submit>`
  submit(8),

  /// `<trigger>` (acknowledge)
  trigger(9),

  /// `<upload mediatype="image/*">`
  imageChoose(10),

  /// A standalone `<label>`.
  label(11),

  /// `<upload mediatype="audio/*">`
  audioCapture(12),

  /// `<upload mediatype="video/*">`
  videoCapture(13),

  /// `<upload mediatype="osm/*">`
  osmCapture(14),

  /// `<upload>` with any other media type
  fileCapture(15),

  /// `<odk:rank>`
  rank(16);

  const ControlType(this.code);

  /// JavaRosa's numeric code.
  final int code;
}
