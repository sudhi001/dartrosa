import 'dart:async';

/// Counts named engine events (such as predicate evaluations) while some
/// work runs, so tests can check how much the caches save.
///
/// Port of `org.javarosa.measure.Measure`. JavaRosa keeps the counts in
/// static state; here they live in a [Zone] set up by [withMeasure], so
/// measurements are scoped to the measured work and [log] costs a zone
/// lookup otherwise.
abstract final class Measure {
  static final Object _countsKey = Object();

  /// Runs [work] and returns how many of [events] it logged.
  static int withMeasure(List<String> events, void Function() work) {
    final counts = <String, int>{};
    runZoned(work, zoneValues: {_countsKey: counts});
    return _total(counts, events);
  }

  /// Like [withMeasure] for asynchronous [work].
  static Future<int> withMeasureAsync(
    List<String> events,
    Future<void> Function() work,
  ) async {
    final counts = <String, int>{};
    await runZoned(work, zoneValues: {_countsKey: counts});
    return _total(counts, events);
  }

  /// Records one occurrence of [event] if it is being measured.
  static void log(String event) {
    final counts = Zone.current[_countsKey] as Map<String, int>?;
    if (counts == null) return;
    counts[event] = (counts[event] ?? 0) + 1;
  }

  static int _total(Map<String, int> counts, List<String> events) =>
      events.fold(0, (sum, event) => sum + (counts[event] ?? 0));
}
