/// App- or plugin-defined objects attached to a form, at most one per type.
///
/// Port of `org.javarosa.core.util.Extras` (JavaRosa keys them by class
/// name; here by runtime type). Plugins use it to mark parsed forms, e.g.
/// ODK Collect's `DynamicPreloadExtra`.
final class Extras<T extends Object> {
  final Map<Type, T> _map = {};

  /// Stores [extra], replacing any extra of the same runtime type.
  void put(T extra) => _map[extra.runtimeType] = extra;

  /// The extra of type [U], if any.
  U? get<U extends T>() => _map[U] as U?;
}
