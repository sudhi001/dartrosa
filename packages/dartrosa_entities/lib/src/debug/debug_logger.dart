/// Records events. Implementations decide how to surface them - for
/// example as a line in a debug log file and/or an analytics event.
///
/// Port of `org.odk.collect.shared.debug.DebugLogger`.
abstract interface class DebugLogger<T> {
  /// Records [event].
  void log(T event);
}
