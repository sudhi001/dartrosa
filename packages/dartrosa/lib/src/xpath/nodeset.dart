import '../model/condition/evaluation_context.dart';
import '../model/instance/data_instance.dart';
import '../model/instance/tree_reference.dart';
import 'conversions.dart';
import 'exceptions.dart';

/// The result of a path expression: a list of node references.
///
/// Port of `org.javarosa.xpath.XPathNodeset` (and, through [XPathNodeset.lazy],
/// `XPathLazyNodeset`). Converting a nodeset to a single value ([unpack])
/// requires it to contain at most one node.
class XPathNodeset {
  /// A nodeset of [refs] in [instance].
  XPathNodeset(
    List<TreeReference> refs,
    DataInstance this._instance,
    EvaluationContext this._context,
  ) : _refs = refs,
      _pathEvaluated = null,
      _originalPath = null;

  /// A nodeset for a path that didn't resolve; any access throws.
  XPathNodeset.invalidPath(String pathEvaluated, String originalPath)
    : _refs = null,
      _instance = null,
      _context = null,
      _pathEvaluated = pathEvaluated,
      _originalPath = originalPath;

  XPathNodeset._lazy(this._instance, this._context)
    : _refs = null,
      _pathEvaluated = null,
      _originalPath = null;

  /// A nodeset for [ref] that is only expanded when needed.
  factory XPathNodeset.lazy(
    TreeReference ref,
    DataInstance instance,
    EvaluationContext context,
  ) = _LazyNodeset;

  List<TreeReference>? _refs;
  final DataInstance? _instance;
  final EvaluationContext? _context;
  final String? _pathEvaluated;
  final String? _originalPath;

  /// The instance the references point into.
  DataInstance? get instance => _instance;

  /// The evaluation context the nodeset was produced in.
  EvaluationContext? get context => _context;

  /// The node references, in document order (`null` for an invalid path).
  List<TreeReference>? get references => _refs;

  /// Number of nodes (0 for an invalid path).
  int get size => _refs?.length ?? 0;

  /// The single value of this nodeset: `''` when empty, the node's value
  /// when it has one node; throws when it has several.
  Object unpack() {
    final refs = _refs;
    if (refs == null) throw _invalidNodesetException();
    if (refs.isEmpty) return unpackValue(null);
    if (refs.length > 1) {
      throw XPathTypeMismatchException(
        'This field is repeated: \n\n$nodeContents\n\nYou may need to use '
        'the indexed-repeat() function to specify which value you want.',
      );
    }
    return valueAt(0);
  }

  /// The values of all nodes.
  List<Object> toArgList() {
    if (_refs == null) throw _invalidNodesetException();
    return [for (var i = 0; i < size; i++) valueAt(i)];
  }

  /// Number of nodes that have children or a value.
  int get nonEmptySize {
    final refs = _refs;
    if (refs == null) return 0;
    var count = 0;
    for (final ref in refs) {
      final element = _context!.mainInstance!.resolveReference(ref)!;
      if (element.numChildren > 0 || element.value != null) count++;
    }
    return count;
  }

  /// The reference of node [i].
  TreeReference refAt(int i) {
    final refs = _refs;
    if (refs == null) throw _invalidNodesetException();
    return refs[i];
  }

  /// The value of node [i].
  Object valueAt(int i) => getRefValue(_instance!, _context!, refAt(i));

  /// The node references joined by `;` (for error messages).
  String get nodeContents {
    final refs = _refs;
    if (refs == null) return 'Invalid Path: $_pathEvaluated';
    return refs.join(';');
  }

  XPathTypeMismatchException _invalidNodesetException() {
    if (_pathEvaluated != _originalPath) {
      throw XPathTypeMismatchException(
        'The path $_originalPath refers to the location $_pathEvaluated '
        'which was not found',
      );
    }
    throw XPathTypeMismatchException('Location $_pathEvaluated was not found');
  }
}

final class _LazyNodeset extends XPathNodeset {
  _LazyNodeset(
    this._unexpanded,
    DataInstance instance,
    EvaluationContext context,
  ) : super._lazy(instance, context);

  final TreeReference _unexpanded;
  bool _evaluated = false;

  void _evaluate() {
    if (_evaluated) return;
    _refs = _context!
        .expandReference(_unexpanded)!
        .where((ref) => _instance!.resolveReference(ref)!.isRelevant)
        .toList();
    _evaluated = true;
  }

  @override
  Object unpack() {
    if (_evaluated) return super.unpack();
    // Without predicates or special multiplicities, try the single node
    // directly before expanding.
    var safe = true;
    for (var i = 0; i < _unexpanded.size; i++) {
      final multiplicity = _unexpanded.multiplicityAt(i);
      if (_unexpanded.predicatesAt(i) != null ||
          !(multiplicity >= 0 || multiplicity == TreeReference.indexUnbound)) {
        safe = false;
        break;
      }
    }
    if (safe) {
      try {
        return getRefValue(_instance!, _context!, _unexpanded);
      } on XPathException {
        // fall through to full expansion
      }
    }
    _evaluate();
    return super.unpack();
  }

  @override
  List<Object> toArgList() {
    _evaluate();
    return super.toArgList();
  }

  @override
  List<TreeReference>? get references {
    _evaluate();
    return super.references;
  }

  @override
  int get size {
    _evaluate();
    return super.size;
  }

  @override
  TreeReference refAt(int i) {
    _evaluate();
    return super.refAt(i);
  }

  @override
  Object valueAt(int i) {
    _evaluate();
    return super.valueAt(i);
  }

  @override
  String get nodeContents {
    _evaluate();
    return super.nodeContents;
  }
}
