/// Builds the "structure" trace (see conformance/TRACE_FORMAT.md) for a
/// parsed form, matching the JVM oracle's Structure.java.
library;

import 'package:dartrosa/src/model/condition/conditions.dart';
import 'package:dartrosa/src/model/data_type.dart';
import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/model/form_element.dart';
import 'package:dartrosa/src/model/instance/tree_element.dart';
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:dartrosa/src/model/select_choice.dart';

final _uuid = RegExp(
  '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

final _dateTime = RegExp(
  r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?',
);

/// When the test run started (for `<now>` normalization).
final runStarted = DateTime.now();

/// The oracle's value normalization: UUIDs, date-times during the run and
/// today's date.
String? normalize(String? s) {
  if (s == null) return null;
  s = s.replaceAllMapped(_dateTime, (m) {
    final t = DateTime.tryParse(m[0]!);
    final duringRun =
        t != null &&
        !t.isBefore(runStarted.subtract(const Duration(seconds: 1))) &&
        !t.isAfter(DateTime.now().add(const Duration(seconds: 1)));
    return duringRun ? '<now>' : m[0]!;
  });
  final today = DateTime.now();
  final iso =
      '${today.year.toString().padLeft(4, '0')}-'
      '${today.month.toString().padLeft(2, '0')}-'
      '${today.day.toString().padLeft(2, '0')}';
  return s.replaceAll(_uuid, '<uuid>').replaceAll(iso, '<today>');
}

String? _ref(TreeReference? r) => r?.toString(includePredicates: true);

/// Java constant names (camelCased) for data types.
String _dataType(DataType t) => t == DataType.nullType ? 'null' : t.name;

Map<String, Object?> structureOf(FormDef f) {
  final localizer = f.localizer;
  final triggerables = [for (final t in f.triggerables) _triggerable(t)]
    ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
  final submission = f.defaultSubmission;
  return {
    'title': f.title,
    'name': f.name,
    'languages': localizer?.availableLocales,
    'defaultLanguage': localizer?.defaultLocale,
    'elements': _elements(f),
    'instance': _tree(f.mainInstance.root),
    'secondaryInstances': {
      for (final e in f.nonMainInstances.entries) e.key: _tree(e.value.root),
    },
    'triggerables': triggerables,
    'outputs': [for (final o in f.outputFragments) o.expr.toString()],
    'submission': submission == null
        ? null
        : {
            'ref': _ref(submission.ref),
            'method': '${submission.method}',
            'action': '${submission.action}',
          },
    'warnings': f.parseWarnings,
  };
}

/// Each triggerable's immediate cascades, both sorted by sort key (the
/// oracle's `Structure.cascades`).
List<Object?> cascadesOf(FormDef f) {
  final out =
      [
        for (final t in f.triggerables)
          {
            'triggerable': _sortKey(_triggerable(t)),
            'cascades': [
              for (final c in f.dag.immediateCascades(t))
                _sortKey(_triggerable(c)),
            ]..sort(),
          },
      ]..sort(
        (a, b) => (a['triggerable']! as String).compareTo(
          b['triggerable']! as String,
        ),
      );
  return out;
}

String _sortKey(Map<String, Object?> t) =>
    '${t['kind']}|${t['expr']}|${t['originalContext']}|'
    '[${(t['targets']! as List).join(', ')}]';

List<Object?> _attributes(List<TreeElement> attributes) => [
  for (final a in attributes) ['${a.namespace}', a.name, '${a.attributeValue}'],
];

List<Object?> _elements(FormElement parent) => [
  for (final e in parent.children)
    {
      if (e is GroupDef) ...{
        'kind': e.isRepeat ? 'repeat' : 'group',
        'count': _ref(e.count),
        'noAddRemove': e.noAddRemove,
      },
      if (e is QuestionDef) ...{
        'kind': 'question',
        'control': e.controlType.name,
        'helpText': e.helpText,
        'helpInnerText': e.helpInnerText,
        'helpTextId': e.helpTextId,
        'choices': [
          for (final c in e.choices ?? const <SelectChoice>[])
            {
              'value': c.value,
              'label': c.labelInnerText,
              'textId': c.textId,
              'index': c.index,
            },
        ],
        if (e.dynamicChoices case final i?)
          'itemset': {
            'nodeset': _ref(i.nodesetRef),
            'label': _ref(i.labelRef),
            'value': _ref(i.valueRef),
            'labelIsItext': i.labelIsItext,
            'randomize': i.randomize,
            'seed': i.randomSeedExpr?.toString(),
            'filter': i.nodesetExpr!.expr.toString(),
          },
      },
      'ref': _ref(e.bind),
      'appearance': e.appearance,
      'label': e.labelInnerText,
      'textId': e.textId,
      'attributes': _attributes(e.additionalAttributes),
      'children': _elements(e),
    },
];

Map<String, Object?> _tree(TreeElement? t) {
  if (t == null) return {};
  final constraint = t.constraint as Constraint?;
  return {
    'name': t.name,
    'mult': t.multiplicity,
    'type': _dataType(t.dataType),
    'value': normalize(t.value?.uncast().string),
    'relevant': t.isRelevant,
    'required': t.isRequired,
    'enabled': t.isEnabled,
    'repeatable': t.isRepeatable,
    'namespace': t.namespace,
    'prefix': t.namespacePrefix,
    'preload': t.preloadHandler,
    'preloadParams': t.preloadParams,
    'constraint': constraint?.constraint.expr.toString(),
    'attributes': _attributes(t.attributes),
    'bindAttributes': _attributes(t.bindAttributes),
    'children': [for (final c in t.children) _tree(c)],
  };
}

Map<String, Object?> _triggerable(Triggerable t) => {
  'kind': t is Condition ? 'condition' : 'recalculate',
  'expr': t.expr.expr.toString(),
  'context': _ref(t.context),
  'originalContext': _ref(t.originalContext),
  'targets': [for (final r in t.targets) _ref(r)!]..sort(),
  'triggers': [for (final r in t.triggers) _ref(r)!]..sort(),
};
