// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dartrosa/dartrosa.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_parsing/path_parsing.dart';
import 'package:xml/xml.dart';

import '../localizations.dart';
import '../xform_scope.dart';
import 'common.dart';

/// The fill of selected areas (ODK Collect's `svg_map_helper.js`).
const imageMapSelectedColor = '#E65100';

/// An SVG image map: the areas whose `id`s are choice values, as paths in
/// the SVG's user space, and the SVG text with selected areas filled.
///
/// Like ODK Collect's `SelectImageMapWidget`, `g`, `path`, `rect`,
/// `circle`, `ellipse` and `polygon` elements are areas; an SVG without a
/// size gets 1000×1000.
class SvgImageMap {
  /// Parses [svg], keeping the areas whose ids are in [choiceValues].
  /// Throws a [FormatException] if [svg] is not an SVG document.
  factory SvgImageMap.parse(String svg, Iterable<String> choiceValues) {
    final document = XmlDocument.parse(svg);
    final root = document.rootElement;
    if (root.localName != 'svg') {
      throw const FormatException('Not an SVG document');
    }
    root.getAttribute('width') ?? root.setAttribute('width', '1000');
    root.getAttribute('height') ?? root.setAttribute('height', '1000');
    final viewBox = _viewBox(root);
    final values = choiceValues.toSet();
    final areas = <String, ui.Path>{};
    final order = <String>[];
    void visit(XmlElement element, _Affine transform, String? area) {
      final local = transform.multiply(
        _Affine.parse(element.getAttribute('transform')),
      );
      final id = element.getAttribute('id');
      var current = area;
      if (id != null &&
          values.contains(id) &&
          _areaTags.contains(element.localName)) {
        current = id;
        areas.putIfAbsent(id, ui.Path.new);
        order
          ..remove(id)
          ..add(id);
      }
      if (current != null) {
        final shape = _shape(element);
        if (shape != null) {
          areas[current]!.addPath(shape.transform(local.storage), Offset.zero);
        }
      }
      for (final child in element.childElements) {
        visit(child, local, current);
      }
    }

    visit(root, _Affine.identity, null);
    return SvgImageMap._(document, viewBox, areas, order);
  }

  SvgImageMap._(this._document, this.viewBox, this._areas, this._order);

  final XmlDocument _document;

  /// The SVG's user space (its `viewBox`, or its size).
  final Rect viewBox;

  final Map<String, ui.Path> _areas;

  /// The area ids in paint order.
  final List<String> _order;

  static const _areaTags = {
    'g', 'path', 'rect', 'circle', 'ellipse', 'polygon', //
  };

  /// The ids of the areas found.
  Iterable<String> get areaIds => _order;

  /// The bounds of the area [id] in user space, or `null` if there is no
  /// such area.
  Rect? areaBounds(String id) => _areas[id]?.getBounds();

  /// The topmost area at [point] (in user space), if any.
  String? areaAt(Offset point) {
    for (final id in _order.reversed) {
      if (_areas[id]!.contains(point)) return id;
    }
    return null;
  }

  /// The SVG text with the areas in [selected] filled with
  /// [imageMapSelectedColor].
  ///
  /// The last result is kept: rebuilds and layout changes with the same
  /// selection get the same text, which the SVG renderer has cached.
  String highlighted(Set<String> selected) {
    final last = _highlighted;
    if (last != null && setEquals(last.$1, selected)) return last.$2;
    final svg = _highlight(selected);
    _highlighted = ({...selected}, svg);
    return svg;
  }

  (Set<String>, String)? _highlighted;

  String _highlight(Set<String> selected) {
    if (selected.isEmpty) return _document.toXmlString();
    final copy = _document.copy();
    for (final element in copy.descendantElements) {
      final id = element.getAttribute('id');
      if (id == null || !selected.contains(id)) continue;
      for (final e in [element, ...element.descendantElements]) {
        if (_areaTags.contains(e.localName)) {
          e.setAttribute('style', 'fill: $imageMapSelectedColor');
        }
      }
    }
    return copy.toXmlString();
  }

  static Rect _viewBox(XmlElement root) {
    final box = _numbers(root.getAttribute('viewBox'));
    if (box.length == 4 && box[2] > 0 && box[3] > 0) {
      return Rect.fromLTWH(box[0], box[1], box[2], box[3]);
    }
    return Rect.fromLTWH(
      0,
      0,
      _length(root.getAttribute('width')) ?? 1000,
      _length(root.getAttribute('height')) ?? 1000,
    );
  }

  static ui.Path? _shape(XmlElement e) {
    double n(String name) => _length(e.getAttribute(name)) ?? 0;
    switch (e.localName) {
      case 'path':
        final d = e.getAttribute('d');
        if (d == null) return null;
        final proxy = _PathProxy();
        try {
          writeSvgPathDataToPath(d, proxy);
        } on Object {
          return null;
        }
        return proxy.path;
      case 'rect':
        final rect = Rect.fromLTWH(n('x'), n('y'), n('width'), n('height'));
        final rx =
            _length(e.getAttribute('rx')) ?? _length(e.getAttribute('ry'));
        final ry = _length(e.getAttribute('ry')) ?? rx;
        return ui.Path()..addRRect(RRect.fromRectXY(rect, rx ?? 0, ry ?? 0));
      case 'circle':
        return ui.Path()..addOval(
          Rect.fromCircle(center: Offset(n('cx'), n('cy')), radius: n('r')),
        );
      case 'ellipse':
        return ui.Path()..addOval(
          Rect.fromCenter(
            center: Offset(n('cx'), n('cy')),
            width: 2 * n('rx'),
            height: 2 * n('ry'),
          ),
        );
      case 'polygon':
        final p = _numbers(e.getAttribute('points'));
        if (p.length < 4) return null;
        return ui.Path()..addPolygon([
          for (var i = 0; i + 1 < p.length; i += 2) Offset(p[i], p[i + 1]),
        ], true);
    }
    return null;
  }
}

final _number = RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

List<double> _numbers(String? text) => [
  for (final m in _number.allMatches(text ?? '')) double.parse(m[0]!),
];

double? _length(String? text) {
  if (text == null || text.trim().endsWith('%')) return null;
  final m = _number.matchAsPrefix(text.trim());
  return m == null ? null : double.parse(m[0]!);
}

class _PathProxy extends PathProxy {
  final ui.Path path = ui.Path();

  @override
  void close() => path.close();

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}

/// A 2D affine transform `[a c e; b d f]` (SVG's `matrix(a b c d e f)`).
@immutable
class _Affine {
  const _Affine(this.a, this.b, this.c, this.d, this.e, this.f);

  static const identity = _Affine(1, 0, 0, 1, 0, 0);

  final double a, b, c, d, e, f;

  _Affine multiply(_Affine o) => _Affine(
    a * o.a + c * o.b,
    b * o.a + d * o.b,
    a * o.c + c * o.d,
    b * o.c + d * o.d,
    a * o.e + c * o.f + e,
    b * o.e + d * o.f + f,
  );

  Float64List get storage =>
      Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]);

  /// Parses an SVG `transform` list.
  static _Affine parse(String? text) {
    var result = identity;
    if (text == null) return result;
    for (final m in RegExp(r'(\w+)\s*\(([^)]*)\)').allMatches(text)) {
      final v = _numbers(m[2]);
      double at(int i, [double fallback = 0]) => i < v.length ? v[i] : fallback;
      final next = switch (m[1]) {
        'matrix' when v.length == 6 => _Affine(
          v[0],
          v[1],
          v[2],
          v[3],
          v[4],
          v[5],
        ),
        'translate' => _Affine(1, 0, 0, 1, at(0), at(1)),
        'scale' => _Affine(at(0, 1), 0, 0, at(1, at(0, 1)), 0, 0),
        'rotate' => () {
          final r = at(0) * math.pi / 180;
          final (cos, sin) = (math.cos(r), math.sin(r));
          final rotation = _Affine(cos, sin, -sin, cos, 0, 0);
          final (cx, cy) = (at(1), at(2));
          return _Affine(
            1,
            0,
            0,
            1,
            cx,
            cy,
          ).multiply(rotation).multiply(_Affine(1, 0, 0, 1, -cx, -cy));
        }(),
        'skewX' => _Affine(1, 0, math.tan(at(0) * math.pi / 180), 1, 0, 0),
        'skewY' => _Affine(1, math.tan(at(0) * math.pi / 180), 0, 1, 0, 0),
        _ => identity,
      };
      result = result.multiply(next);
    }
    return result;
  }
}

/// A select (`image-map` appearance) shown as the SVG of the question's
/// image, whose areas with choice values as ids are tapped to select
/// them, like ODK Collect's `SelectOneImageMapWidget` and
/// `SelectMultiImageMapWidget`. The SVG is read with
/// `XFormDelegates.mediaBytes`.
class ImageMapInput extends StatefulWidget {
  /// Creates the input for [node].
  const ImageMapInput(this.node, {super.key});

  /// The select question.
  final QuestionNode node;

  @override
  State<ImageMapInput> createState() => _ImageMapInputState();
}

class _ImageMapInputState extends State<ImageMapInput> {
  String? _uri;
  Future<SvgImageMap?>? _map;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant ImageMapInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    final uri = widget.node.label.image;
    if (_map != null && uri == _uri) return;
    _uri = uri;
    final delegates = XFormScope.of(context).delegates;
    final values = [for (final c in choicesOf(context, widget.node)) c.value];
    _map = uri == null
        ? Future.value()
        : delegates
              .mediaBytes(uri)
              .then(
                (bytes) => bytes == null
                    ? null
                    : SvgImageMap.parse(utf8.decode(bytes), values),
              );
  }

  void _tap(String id) {
    final node = widget.node;
    if (node.isReadonly) return;
    final choice = choicesOf(
      context,
      node,
    ).where((c) => c.value == id).firstOrNull;
    if (choice == null) return;
    if (node.controlType == ControlType.selectMulti) {
      toggleSelection(context, node, id);
    } else {
      selectChoice(context, node, choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final strings = XFormLocalizations.of(context);
    return FutureBuilder<SvgImageMap?>(
      future: _map,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 48);
        }
        final map = snapshot.data;
        if (map == null) return Text(strings.svgFileMissing);
        final selected = selectedValues(node);
        final choices = choicesOf(context, node);
        final labels = [
          for (final c in choices)
            if (selected.contains(c.value)) node.choiceLabel(c) ?? c.value,
        ];
        final box = map.viewBox;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height / 1.7,
              ),
              child: AspectRatio(
                aspectRatio: box.width / box.height,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scaleX = constraints.maxWidth / box.width;
                    final scaleY = constraints.maxHeight / box.height;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          key: const ValueKey('image-map'),
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) {
                            final p = details.localPosition;
                            final id = map.areaAt(
                              Offset(
                                box.left + p.dx / scaleX,
                                box.top + p.dy / scaleY,
                              ),
                            );
                            if (id != null) _tap(id);
                          },
                          child: SvgPicture.string(
                            map.highlighted(selected),
                            fit: BoxFit.fill,
                            excludeFromSemantics: true,
                          ),
                        ),
                        // Screen readers and the keyboard (Tab, then
                        // Enter or Space) see each area as a choice over
                        // its bounds; taps fall through to the detector.
                        for (final c in choices)
                          if (map.areaBounds(c.value) case final bounds?)
                            Positioned.fromRect(
                              rect: Rect.fromLTRB(
                                (bounds.left - box.left) * scaleX,
                                (bounds.top - box.top) * scaleY,
                                (bounds.right - box.left) * scaleX,
                                (bounds.bottom - box.top) * scaleY,
                              ),
                              child: _ImageMapArea(
                                label: node.choiceLabel(c) ?? c.value,
                                selected: selected.contains(c.value),
                                multi:
                                    node.controlType == ControlType.selectMulti,
                                onTap: node.isReadonly
                                    ? null
                                    : () => _tap(c.value),
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (labels.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${strings.selected} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: labels.join(', ')),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// An image-map area for screen readers and the keyboard: focusable,
/// selected with Enter or Space, outlined while focused. It doesn't take
/// pointer events (taps reach the map's detector).
class _ImageMapArea extends StatefulWidget {
  const _ImageMapArea({
    required this.label,
    required this.selected,
    required this.multi,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool multi;
  final VoidCallback? onTap;

  @override
  State<_ImageMapArea> createState() => _ImageMapAreaState();
}

class _ImageMapAreaState extends State<_ImageMapArea> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: widget.label,
      selected: widget.selected,
      checked: widget.multi ? widget.selected : null,
      inMutuallyExclusiveGroup: !widget.multi,
      onTap: onTap,
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap?.call();
              return null;
            },
          ),
        },
        child: Focus(
          canRequestFocus: onTap != null,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: _focused
                    ? Border.all(color: scheme.primary, width: 3)
                    : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
