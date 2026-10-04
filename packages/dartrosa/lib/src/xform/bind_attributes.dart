import 'package:logging/logging.dart';

import '../model/condition/conditions.dart';
import '../model/data_binding.dart';
import '../model/data_type.dart';
import '../model/form_def.dart';
import '../model/instance/tree_reference.dart';
import '../xpath/exceptions.dart';
import 'instance_structure.dart';
import 'kdom.dart';
import 'type_mappings.dart';
import 'xform_parse_exception.dart';

final _log = Logger('dartrosa.xform');

/// Handles bind attributes it declares (e.g. ODK Collect's entities
/// `saveto`). Port of `XFormParser.BindAttributeProcessor`.
abstract interface class BindAttributeProcessor {
  /// The (namespace, name) pairs this processor handles.
  Set<(String, String)> get bindAttributes;

  /// Handles one attribute of [binding].
  void processBindAttribute(String name, String value, DataBinding binding);
}

/// Builds a [DataBinding] from a `<bind>` element.
///
/// Port of `StandardBindAttributesProcessor.createBinding`. Attributes not
/// in [usedAttributes] (or handled by a processor), and those in
/// [passedThroughAttributes], are kept as additional attributes.
DataBinding createBinding(
  KElement element, {
  required FormDef form,
  required List<String> usedAttributes,
  required List<String> passedThroughAttributes,
  required List<BindAttributeProcessor> processors,
  required TreeReference Function(TreeReference relative) absoluteRef,
  required TreeReference Function(String nodeset) parseReference,
  required XPathConditional Function(String xpath) parseConditional,
}) {
  final binding = DataBinding()..id = element.attribute('', 'id');
  final nodeset =
      element.attribute(null, 'nodeset') ??
      (throw XFormParseException(
        'XForm Parse: <bind> without nodeset',
        element,
      ));
  TreeReference ref;
  try {
    ref = parseReference(nodeset);
  } on XPathException catch (e) {
    throw XFormParseException(e.message ?? '');
  }
  ref = absoluteRef(ref);
  binding
    ..reference = ref
    ..dataType = _dataType(element.attribute(null, 'type'));

  Triggerable condition(String xpath, String type) {
    final (prettyType, trueAction, falseAction) = switch (type) {
      'relevant' => (
        'display',
        ConditionAction.relevant,
        ConditionAction.notRelevant,
      ),
      'required' => (
        'require',
        ConditionAction.require,
        ConditionAction.dontRequire,
      ),
      _ => ('readonly', ConditionAction.readOnly, ConditionAction.enable),
    };
    final XPathConditional expression;
    try {
      expression = parseConditional(xpath);
    } on XPathSyntaxException catch (e) {
      throw XFormParseException(
        'Encountered a problem with $prettyType condition for node [$ref] at '
        'line: $xpath, ${e.message}',
      );
    }
    return Condition(
      expression,
      ref,
      trueAction: trueAction,
      falseAction: falseAction,
    );
  }

  final relevant = element.attribute(null, 'relevant');
  if (relevant == 'true()') {
    binding.relevantAbsolute = true;
  } else if (relevant == 'false()') {
    binding.relevantAbsolute = false;
  } else if (relevant != null) {
    binding.relevancyCondition = form.addTriggerable(
      condition(relevant, 'relevant'),
    );
  }
  final required = element.attribute(null, 'required');
  if (required == 'true()') {
    binding.requiredAbsolute = true;
  } else if (required == 'false()') {
    binding.requiredAbsolute = false;
  } else if (required != null) {
    binding.requiredCondition = form.addTriggerable(
      condition(required, 'required'),
    );
  }
  final readonly = element.attribute(null, 'readonly');
  if (readonly == 'true()') {
    binding.readonlyAbsolute = true;
  } else if (readonly == 'false()') {
    binding.readonlyAbsolute = false;
  } else if (readonly != null) {
    binding.readonlyCondition = form.addTriggerable(
      condition(readonly, 'readonly'),
    );
  }
  final constraint = element.attribute(null, 'constraint');
  if (constraint != null) {
    try {
      binding.constraint = parseConditional(constraint);
    } on XPathSyntaxException catch (e) {
      throw XFormParseException(
        'bind for $nodeset contains invalid constraint expression '
        '[$constraint] ${e.message}',
      );
    }
    binding.constraintMessage = element.attribute(
      namespaceJavaRosa,
      'constraintMsg',
    );
  }
  final calculate = element.attribute(null, 'calculate');
  if (calculate != null) {
    try {
      binding.calculate = form.addTriggerable(
        Recalculate(parseConditional(calculate), ref),
      );
    } on XPathSyntaxException catch (e) {
      throw XFormParseException(
        'Invalid calculate for the bind attached to "$nodeset" : '
        '${e.message} in expression $calculate',
      );
    }
  }
  binding
    ..preload = element.attribute(namespaceJavaRosa, 'preload')
    ..preloadParams = element.attribute(namespaceJavaRosa, 'preloadParams');

  for (final processor in processors) {
    for (final a in element.attributes) {
      if (processor.bindAttributes.contains((a.namespace, a.name))) {
        processor.processBindAttribute(a.name, a.value, binding);
      }
    }
  }
  final processorAttributes = {
    for (final processor in processors) ...processor.bindAttributes,
  };
  for (final a in element.attributes) {
    final used =
        usedAttributes.contains(a.name) ||
        processorAttributes.contains((a.namespace, a.name));
    if (!used || passedThroughAttributes.contains(a.name)) {
      binding.setAdditionalAttribute(a.namespace, a.name, a.value);
    }
  }
  return binding;
}

DataType _dataType(String? type) {
  if (type == null) return DataType.nullType;
  // Namespaces are ignored.
  final name = type.contains(':')
      ? type.substring(type.indexOf(':') + 1)
      : type;
  final mapped = typeMappings[name];
  if (mapped == null) {
    _log.warning('XForm Parse Warning: unrecognized data type [$name]');
    return DataType.unsupported;
  }
  return mapped;
}
