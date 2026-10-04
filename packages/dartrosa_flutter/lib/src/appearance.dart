import 'package:flutter/foundation.dart';

/// The space-separated tokens of an `appearance` attribute, with ODK
/// Collect's deprecated aliases (`compact`, `quickcompact`,
/// `horizontal`, ...) mapped to their current names.
@immutable
class Appearance {
  /// Parses [raw] (case-insensitively).
  factory Appearance.parse(String? raw) {
    final tokens = <String>{};
    // `search(...)` (external data) may contain spaces.
    final text = (raw ?? '').toLowerCase().replaceAll(
      RegExp(r'search\([^)]*\)?'),
      ' search() ',
    );
    for (final token in text.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      tokens.add(token);
      switch (token) {
        case 'quickcompact':
          tokens.addAll(['quick', 'no-buttons']);
        case 'compact':
          tokens.add('no-buttons');
        case 'horizontal':
          tokens.add('columns');
        case 'horizontal-compact':
          tokens.add('columns-pack');
      }
      final compactN = RegExp(r'^(?:quick)?compact-(\d+)$').firstMatch(token);
      if (compactN != null) {
        tokens.addAll(['no-buttons', 'columns-${compactN[1]}']);
        if (token.startsWith('quick')) tokens.add('quick');
      }
    }
    return Appearance._(tokens);
  }

  const Appearance._(this.tokens);

  /// The tokens, lower-cased, including mapped aliases.
  final Set<String> tokens;

  /// Whether the appearance has [token].
  bool has(String token) => tokens.contains(token);

  /// The column count of `columns-N`, if any.
  int? get columnCount {
    for (final token in tokens) {
      final match = RegExp(r'^columns-(\d+)$').firstMatch(token);
      if (match != null) return int.parse(match[1]!).clamp(1, 20);
    }
    return null;
  }

  /// Whether choices are laid out in columns (`columns`, `columns-N`,
  /// `columns-pack`).
  bool get hasColumns =>
      has('columns') || has('columns-pack') || columnCount != null;

  /// Tokens the renderer handles (or that only matter to the engine or
  /// to group layout).
  static final Set<String> _known = {
    'minimal', 'quick', 'autocomplete', 'columns', 'columns-pack', //
    'no-buttons', 'likert', 'label', 'list-nolabel', 'list', 'multiline',
    'numbers', 'thousands-sep', 'masked', 'no-calendar', 'month-year',
    'year', 'vertical', 'picker', 'rating', 'no-ticks', 'field-list',
    'table-list', 'quickcompact', 'compact', 'horizontal',
    'horizontal-compact', 'image-map',
  };

  static final RegExp _knownPattern = RegExp(
    r'^(?:columns-\d+|(?:quick)?compact-\d+|w\d+|search\(\))$',
  );

  /// Tokens this renderer does not support; their questions get the
  /// default widget.
  Iterable<String> get unknown =>
      tokens.where((t) => !_known.contains(t) && !_knownPattern.hasMatch(t));

  static final Set<String> _warned = {};

  /// Prints (once per token) the tokens this renderer ignores.
  void warnUnknown() {
    for (final token in unknown) {
      if (_warned.add(token)) {
        debugPrint('dartrosa_flutter: unsupported appearance "$token"');
      }
    }
  }

  /// Forgets which tokens were warned about.
  @visibleForTesting
  static void resetWarnings() => _warned.clear();
}
