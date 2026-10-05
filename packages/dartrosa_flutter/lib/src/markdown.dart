import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'xform_scope.dart';

/// Styles for [parseOdkMarkdown].
@immutable
class OdkMarkdownStyles {
  /// Creates styles; [headers] are for `#` to `######`.
  const OdkMarkdownStyles({required this.headers, required this.link});

  /// Styles from [theme].
  factory OdkMarkdownStyles.of(ThemeData theme) {
    final t = theme.textTheme;
    return OdkMarkdownStyles(
      headers: [
        ?t.headlineMedium,
        ?t.headlineSmall,
        ?t.titleLarge,
        ?t.titleMedium,
        ?t.titleSmall,
        ?t.labelLarge,
      ],
      link: TextStyle(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    );
  }

  /// Header styles, level 1 first (missing levels reuse the last).
  final List<TextStyle> headers;

  /// Link style.
  final TextStyle link;
}

final _header = RegExp(r'^(#{1,6})\s+(.*)$');
final _markup = RegExp(r'[*_#\[<\\&]');
final _linkPattern = RegExp(r'\[([^\[\]]*)\]\(([^()\s]+)\)');
final _spanOpen = RegExp(
  r'''<span\s+style\s*=\s*(?:"([^"]*)"|'([^']*)')\s*>''',
  caseSensitive: false,
);
final _spanTag = RegExp(r'<(/?)span\b[^>]*>', caseSensitive: false);
final _br = RegExp(r'<br\s*/?>', caseSensitive: false);
final _quotes = RegExp('["\']');
final _rgb = RegExp(r'^rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$');

/// Parses ODK Collect's markdown subset into spans: `*em*`/`_em_`,
/// `**strong**`/`__strong__`, `#` headers (at line start), `[text](url)`
/// links, `<span style="color: ...; font-family: ...">` and backslash
/// escapes. [onLink] makes the recognizer for a link (the caller owns
/// and disposes it).
List<InlineSpan> parseOdkMarkdown(
  String text,
  OdkMarkdownStyles styles, {
  GestureRecognizer Function(String url)? onLink,
}) {
  final spans = <InlineSpan>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) spans.add(const TextSpan(text: '\n'));
    final line = lines[i];
    final header = _header.firstMatch(line);
    if (header != null && styles.headers.isNotEmpty) {
      final level = header[1]!.length.clamp(1, styles.headers.length);
      spans.add(
        TextSpan(
          style: styles.headers[level - 1],
          children: _Inline(header[2]!, styles, onLink).parse(),
        ),
      );
    } else {
      spans.addAll(_Inline(line, styles, onLink).parse());
    }
  }
  return spans;
}

/// [text] without its ODK markdown formatting (e.g. for semantics).
String odkMarkdownToPlainText(String text) => hasOdkMarkdown(text)
    ? TextSpan(
        children: parseOdkMarkdown(
          text,
          const OdkMarkdownStyles(headers: [], link: TextStyle()),
        ),
      ).toPlainText()
    : text;

/// Whether [text] has anything [parseOdkMarkdown] would format.
bool hasOdkMarkdown(String text) => _markup.hasMatch(text);

class _Inline {
  _Inline(this.text, this.styles, this.onLink);

  final String text;
  final OdkMarkdownStyles styles;
  final GestureRecognizer Function(String url)? onLink;

  List<InlineSpan> parse() => _parse(0, text.length);

  static const _escapable = r'\*_#[]()<>`';

  List<InlineSpan> _parse(int start, int end) {
    final spans = <InlineSpan>[];
    final plain = StringBuffer();
    void flush() {
      if (plain.isEmpty) return;
      spans.add(TextSpan(text: _entities(plain.toString())));
      plain.clear();
    }

    var i = start;
    while (i < end) {
      final c = text[i];
      if (c == r'\' && i + 1 < end && _escapable.contains(text[i + 1])) {
        plain.write(text[i + 1]);
        i += 2;
        continue;
      }
      if (c == '*' || c == '_') {
        final strong = i + 1 < end && text[i + 1] == c;
        final delimiter = strong ? '$c$c' : c;
        final close = _closing(delimiter, i + delimiter.length, end);
        if (close != null) {
          flush();
          spans.add(
            TextSpan(
              style: TextStyle(
                fontWeight: strong ? FontWeight.bold : null,
                fontStyle: strong ? null : FontStyle.italic,
              ),
              children: _parse(i + delimiter.length, close),
            ),
          );
          i = close + delimiter.length;
          continue;
        }
      }
      if (c == '[') {
        final link = _linkPattern.matchAsPrefix(text.substring(0, end), i);
        if (link != null) {
          flush();
          final url = link[2]!;
          spans.add(
            TextSpan(
              style: styles.link,
              children: _linked(
                _parse(i + 1, i + 1 + link[1]!.length),
                onLink?.call(url),
              ),
            ),
          );
          i = link.end;
          continue;
        }
      }
      if (c == '<') {
        final open = _spanOpen.matchAsPrefix(text.substring(0, end), i);
        final close = open == null ? null : _spanEnd(open.end, end);
        if (open != null && close != null) {
          flush();
          spans.add(
            TextSpan(
              style: _css(open[1] ?? open[2]!),
              children: _parse(open.end, close),
            ),
          );
          i = close + '</span>'.length;
          continue;
        }
        final br = _br.matchAsPrefix(text.substring(0, end), i);
        if (br != null) {
          plain.write('\n');
          i = br.end;
          continue;
        }
      }
      plain.write(c);
      i++;
    }
    flush();
    return spans;
  }

  /// [spans] with [recognizer] on every span with text (hit testing
  /// finds the innermost span, so children need it too).
  static List<InlineSpan> _linked(
    List<InlineSpan> spans,
    GestureRecognizer? recognizer,
  ) => recognizer == null
      ? spans
      : [
          for (final span in spans)
            span is TextSpan
                ? TextSpan(
                    text: span.text,
                    style: span.style,
                    recognizer: recognizer,
                    children: span.children == null
                        ? null
                        : _linked(span.children!, recognizer),
                  )
                : span,
        ];

  /// The index of the [delimiter] closing one opened before [from]: not
  /// escaped, not preceded by a space, with a non-space right after the
  /// opening.
  int? _closing(String delimiter, int from, int end) {
    if (from >= end || text[from].trim().isEmpty) return null;
    var i = from + 1;
    while (i <= end - delimiter.length) {
      if (text[i] == r'\') {
        i += 2;
        continue;
      }
      if (text.startsWith(delimiter, i) &&
          text[i - 1].trim().isNotEmpty &&
          // `*a**` is not an em closing at the first `*` of `**`.
          (delimiter.length == 2 ||
              !(i + 1 < end && text[i + 1] == delimiter))) {
        return i;
      }
      // Skip over a nested double delimiter when looking for a single.
      if (delimiter.length == 1 && text.startsWith('$delimiter$delimiter', i)) {
        final inner = _closing('$delimiter$delimiter', i + 2, end);
        if (inner != null) {
          i = inner + 2;
          continue;
        }
      }
      i++;
    }
    return null;
  }

  /// The index of the `</span>` matching a span opened before [from].
  int? _spanEnd(int from, int end) {
    var depth = 1;
    for (final m in _spanTag.allMatches(text.substring(0, end), from)) {
      depth += m[1]!.isEmpty ? 1 : -1;
      if (depth == 0) return m.start;
    }
    return null;
  }

  static TextStyle _css(String css) {
    Color? color;
    String? family;
    for (final declaration in css.split(';')) {
      final colon = declaration.indexOf(':');
      if (colon < 0) continue;
      final name = declaration.substring(0, colon).trim().toLowerCase();
      final value = declaration.substring(colon + 1).trim();
      switch (name) {
        case 'color':
          color = parseCssColor(value);
        case 'font-family':
          family = value.split(',').first.trim().replaceAll(_quotes, '');
      }
    }
    return TextStyle(color: color, fontFamily: family);
  }

  static String _entities(String s) => s.contains('&')
      ? s
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
      : s;
}

/// A CSS color: `#rgb`, `#rrggbb`, `#aarrggbb`-free `#rrggbbaa`,
/// `rgb(r, g, b)` or a basic color name; `null` if unrecognized.
Color? parseCssColor(String value) {
  final v = value.trim().toLowerCase();
  if (v.startsWith('#')) {
    var hex = v.substring(1);
    if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
    final n = int.tryParse(hex, radix: 16);
    if (n == null) return null;
    if (hex.length == 6) return Color(0xFF000000 | n);
    if (hex.length == 8) return Color(((n & 0xFF) << 24) | (n >> 8));
    return null;
  }
  if (_rgb.firstMatch(v) case final m?) {
    return Color.fromARGB(
      255,
      int.parse(m[1]!).clamp(0, 255),
      int.parse(m[2]!).clamp(0, 255),
      int.parse(m[3]!).clamp(0, 255),
    );
  }
  return _named[v];
}

const _named = {
  'black': Color(0xFF000000),
  'white': Color(0xFFFFFFFF),
  'red': Color(0xFFFF0000),
  'green': Color(0xFF008000),
  'blue': Color(0xFF0000FF),
  'yellow': Color(0xFFFFFF00),
  'orange': Color(0xFFFFA500),
  'purple': Color(0xFF800080),
  'pink': Color(0xFFFFC0CB),
  'brown': Color(0xFFA52A2A),
  'gray': Color(0xFF808080),
  'grey': Color(0xFF808080),
  'cyan': Color(0xFF00FFFF),
  'magenta': Color(0xFFFF00FF),
  'navy': Color(0xFF000080),
  'teal': Color(0xFF008080),
  'maroon': Color(0xFF800000),
  'olive': Color(0xFF808000),
  'lime': Color(0xFF00FF00),
  'silver': Color(0xFFC0C0C0),
};

/// Text in ODK markdown, with tappable links opened through the form's
/// delegates.
class XFormMarkdown extends StatefulWidget {
  /// Creates the text for [data].
  const XFormMarkdown(
    this.data, {
    this.style,
    this.prefix,
    this.textAlign,
    super.key,
  });

  /// The markdown.
  final String data;

  /// The base style.
  final TextStyle? style;

  /// A span shown before the text (e.g. a required marker).
  final InlineSpan? prefix;

  /// The alignment.
  final TextAlign? textAlign;

  @override
  State<XFormMarkdown> createState() => _XFormMarkdownState();
}

class _XFormMarkdownState extends State<XFormMarkdown> {
  final List<GestureRecognizer> _recognizers = [];
  List<InlineSpan> _spans = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _parse();
  }

  @override
  void didUpdateWidget(covariant XFormMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _parse();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  /// Parses the markdown once per text and theme rather than per build.
  void _parse() {
    _disposeRecognizers();
    final data = widget.data;
    _spans = hasOdkMarkdown(data)
        ? parseOdkMarkdown(
            data,
            OdkMarkdownStyles.of(Theme.of(context)),
            onLink: _link,
          )
        : [TextSpan(text: data)];
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  GestureRecognizer _link(String url) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        final uri = Uri.tryParse(url);
        if (uri == null) return;
        final delegates = XFormScope.maybeOf(context)?.delegates;
        if (delegates != null) unawaited(delegates.openLink(context, uri));
      };
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(children: [?widget.prefix, ..._spans]),
    style: widget.style,
    textAlign: widget.textAlign,
  );
}
