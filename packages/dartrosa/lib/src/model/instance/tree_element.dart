// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (FormElementStateListener, TreeElement,
//  TreeElementChildrenList, TreeElementNameComparator), Copyright (C) 2009
//  JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import '../data/answer_value.dart';
import '../data_type.dart';
import 'tree_reference.dart';

/// Kinds of change reported to [TreeElementListener]s, as bit flags.
///
/// Port of the `FormElementStateListener.CHANGE_*` constants.
abstract final class ElementChange {
  /// Initial notification.
  static const init = 0x00;

  /// The value changed.
  static const data = 0x01;

  /// The language changed.
  static const locale = 0x02;

  /// The enabled state changed.
  static const enabled = 0x04;

  /// The relevance changed.
  static const relevant = 0x08;

  /// The required state changed.
  static const required = 0x10;

  /// Any other change.
  static const other = 0x40;
}

/// Receives state changes of a [TreeElement]: [changes] is a combination
/// of [ElementChange] flags.
typedef TreeElementListener = void Function(TreeElement element, int changes);

/// A node of an instance: an element (or attribute) with a name,
/// multiplicity, value or children, and model properties such as relevance.
///
/// Port of `org.javarosa.core.model.instance.TreeElement`. Instance trees
/// are the engine's mutable state, so this class is mutable; its reference
/// cache behaves exactly like JavaRosa's (expired by `name`, `multiplicity`
/// and `parent` changes on this node only).
final class TreeElement {
  /// Creates an element called [name] with [multiplicity]; a `null` name
  /// is only used for the hidden root above an instance's top element.
  TreeElement([
    this._name,
    this._multiplicity = TreeReference.defaultMultiplicity,
    this._isPartial = false,
  ]);

  /// An attribute node with [value].
  TreeElement.attribute(String? namespace, String name, String value)
    : _name = name,
      _multiplicity = TreeReference.indexAttribute,
      _value = UncastValue(value),
      _isPartial = false,
      namespace = namespace ?? '' {
    _setFlag(_attributeFlag, true);
  }

  String? _name;
  int _multiplicity;
  TreeElement? _parent;
  AnswerValue? _value;
  bool _isPartial;
  String? _instanceName;
  List<TreeElementListener>? _listeners;
  TreeReference? _refCache;

  /// Whether this element was ever put in a children list (whose lookup
  /// tables then depend on its name, multiplicity and prefix).
  bool _listed = false;

  final _children = _TreeElementChildren();
  final _attributes = <TreeElement>[];

  /// The data type declared by the bind (default [DataType.nullType]).
  DataType dataType = DataType.nullType;

  /// The bind constraint (a `Constraint`, ported with the dependency
  /// graph in P3).
  Object? constraint;

  /// The `jr:preload` handler name.
  String? preloadHandler;

  /// The `jr:preloadParams` value.
  String? preloadParams;

  /// Namespace URI.
  String? namespace;

  /// Namespace prefix, used to match names such as `orx:meta`.
  String? get namespacePrefix => _namespacePrefix;

  set namespacePrefix(String? namespacePrefix) {
    if (_listed) _identityEpoch++;
    _namespacePrefix = namespacePrefix;
  }

  String? _namespacePrefix;

  var _bindAttributes = <TreeElement>[];

  static const _requiredFlag = 0x01;
  static const _repeatableFlag = 0x02;
  static const _attributeFlag = 0x04;
  static const _relevantFlag = 0x08;
  static const _enabledFlag = 0x10;
  static const _relevantInheritedFlag = 0x20;
  static const _enabledInheritedFlag = 0x40;

  int _flags =
      _relevantFlag |
      _enabledFlag |
      _relevantInheritedFlag |
      _enabledInheritedFlag;

  bool _flag(int mask) => (_flags & mask) == mask;

  void _setFlag(int mask, bool value) {
    _flags = value ? _flags | mask : _flags & ~mask;
  }

  // ------------------------------------------------------------ identity

  /// The element name (`null` only for an instance's hidden root).
  String? get name => _name;

  set name(String? name) {
    _refCache = null;
    if (_listed) _identityEpoch++;
    _name = name;
  }

  /// Position among same-named siblings, or a `TreeReference.index*`
  /// sentinel (template, attribute).
  int get multiplicity => _multiplicity;

  set multiplicity(int multiplicity) {
    _refCache = null;
    if (_listed) _identityEpoch++;
    _multiplicity = multiplicity;
  }

  /// The parent element, or `null` for the hidden root.
  TreeElement? get parent => _parent;

  set parent(TreeElement? parent) {
    _refCache = null;
    _parent = parent;
  }

  /// The secondary instance this element belongs to (`null` = main).
  String? get instanceName => _parent?.instanceName ?? _instanceName;

  set instanceName(String? instanceName) => _instanceName = instanceName;

  /// Whether this element is a placeholder whose children load later.
  bool get isPartial => _isPartial;

  /// The absolute reference to this element (cached).
  TreeReference get ref => _refCache ??= buildRef(this);

  /// Builds the reference to [element] by walking up its parents.
  ///
  /// The named elements up to the first unnamed one (an instance's hidden
  /// root, which makes the reference absolute) give the levels; the last
  /// element visited gives the instance name and context type. Same result
  /// as prepending one step per element with [TreeReference.parent], in
  /// one list.
  static TreeReference buildRef(TreeElement? element) {
    if (element == null) return const TreeReference.self();
    final levels = <TreeReferenceLevel>[];
    var top = element;
    for (TreeElement? e = element; e != null; e = e.parent) {
      top = e;
      final elementName = e.name;
      if (elementName == null) break;
      levels.add(TreeReferenceLevel(elementName, e.multiplicity));
    }
    final instanceName = top.instanceName;
    final absolute = top.name == null;
    return TreeReference.ofLevels(
      levels.reversed.toList(),
      refLevel: absolute ? TreeReference.refAbsolute : 0,
      contextType: instanceName != null
          ? ReferenceContext.instance
          : absolute
          ? ReferenceContext.absolute
          : ReferenceContext.inherited,
      instanceName: instanceName,
    );
  }

  /// Number of named ancestors including this element.
  int get depth {
    var depth = 0;
    TreeElement? element = this;
    while (element?.name != null) {
      depth++;
      element = element!.parent;
    }
    return depth;
  }

  /// Forgets the cached [ref] of this element.
  void clearCaches() => _refCache = null;

  /// Forgets the cached refs of all descendants.
  void clearChildrenCaches() {
    for (final child in _children) {
      child
        ..clearCaches()
        ..clearChildrenCaches();
    }
  }

  // ------------------------------------------------------------ value

  /// The value, or `null` when empty.
  AnswerValue? get value => _value;

  /// Sets the value without notifying listeners. Only leaves can hold a
  /// value.
  set value(AnswerValue? value) {
    if (!isLeaf) {
      throw StateError("Can't set data value for node that has children!");
    }
    _value = value;
  }

  /// Sets the value and notifies listeners; returns `false` (and does
  /// nothing) when both the old and new values are empty.
  bool setAnswer(AnswerValue? answer) {
    if (_value == null && answer == null) return false;
    value = answer;
    _notify(ElementChange.data);
    return true;
  }

  // ------------------------------------------------------------ children

  /// Whether this element has no children.
  bool get isLeaf => _children.isEmpty;

  /// Whether this element can have children (it has no value).
  bool get isChildable => _value == null;

  /// The children, in document order (including repeat templates).
  List<TreeElement> get children => List.unmodifiable(_children._list);

  /// Number of children.
  int get numChildren => _children.length;

  /// Whether there is at least one child.
  bool get hasChildren => _children.isNotEmpty;

  /// The child at [i].
  TreeElement childAt(int i) => _children[i];

  /// The child called [name] with [multiplicity], if any. [name] may be
  /// `*` to address children by position.
  TreeElement? getChild(String name, int multiplicity) =>
      _children.find(name, multiplicity);

  /// The first child called [name], if any.
  TreeElement? firstChild(String name, {String? namespace}) {
    final child = getChild(name, 0);
    if (namespace == null || child == null || child.namespace == namespace) {
      return child;
    }
    return null;
  }

  /// All non-template children matching [name] (`*` matches all).
  List<TreeElement> childrenWithName(String name) => _children.withName(name);

  /// Number of non-template children matching [name].
  int childMultiplicity(String name) => _children.countWithName(name);

  /// Adds [child] in multiplicity order, adopting it and propagating this
  /// element's relevance, enabled state and instance name.
  void addChild(TreeElement child) {
    if (!isChildable) {
      throw StateError("Can't add children to node that has data value!");
    }
    if (child.multiplicity == TreeReference.indexUnbound) {
      throw StateError('Cannot add child with an unbound index!');
    }
    _children.addInOrder(child);
    child
      ..parent = this
      .._setRelevant(isRelevant, inherited: true)
      ..setEnabled(isEnabled, inherited: true)
      ..instanceName = instanceName;
  }

  /// Inserts [child] at [index] without adopting it.
  void insertChildAt(int index, TreeElement child) =>
      _children.insert(index, child);

  /// Removes [child].
  void removeChild(TreeElement child) => _children.remove(child);

  /// Removes the child called [name] with [multiplicity], if any.
  void removeChildNamed(String name, int multiplicity) {
    final child = getChild(name, multiplicity);
    if (child != null) _children.remove(child);
  }

  /// Removes all children called [name].
  void removeChildrenNamed(String name) {
    for (final child in childrenWithName(name)) {
      _children.remove(child);
    }
  }

  /// Removes the child at [i].
  void removeChildAt(int i) => _children.removeAt(i);

  /// Removes all children.
  void clearChildren() => _children.clear();

  /// This element and all its descendants, depth first (replaces
  /// JavaRosa's `accept(ITreeVisitor)`).
  Iterable<TreeElement> get selfAndDescendants sync* {
    yield this;
    for (final child in _children) {
      yield* child.selfAndDescendants;
    }
  }

  /// A copy of this element that shares its children and parent.
  TreeElement shallowCopy() {
    final copy = TreeElement(_name, _multiplicity)
      .._parent = _parent
      ..isRepeatable = isRepeatable
      ..dataType = dataType
      ..constraint = constraint
      ..preloadHandler = preloadHandler
      ..preloadParams = preloadParams
      .._instanceName = _instanceName
      ..namespace = namespace
      .._bindAttributes = _bindAttributes;
    copy
      .._setFlag(_relevantFlag, _flag(_relevantFlag))
      .._setFlag(_requiredFlag, _flag(_requiredFlag))
      .._setFlag(_enabledFlag, _flag(_enabledFlag));
    for (final attribute in _attributes) {
      copy.setAttribute(
        attribute.namespace,
        attribute.name!,
        attribute.attributeValue,
      );
    }
    copy
      .._value = _value
      .._children.addAll(_children);
    return copy;
  }

  /// A deep copy, leaving out repeat templates unless [includeTemplates].
  TreeElement deepCopy({required bool includeTemplates}) {
    final copy = shallowCopy().._children.clear();
    for (final child in _children) {
      if (includeTemplates ||
          child.multiplicity != TreeReference.indexTemplate) {
        copy.addChild(child.deepCopy(includeTemplates: includeTemplates));
      }
    }
    return copy;
  }

  /// Replaces a partial element's children with [element]'s.
  void populatePartial(TreeElement element) {
    if (!_isPartial) return;
    _children.clear();
    for (final child in element._children) {
      addChild(child);
    }
    _isPartial = false;
  }

  // ------------------------------------------------------------ properties

  /// Whether this element is a repeat (or repeat template).
  bool get isRepeatable => _flag(_repeatableFlag);

  set isRepeatable(bool repeatable) => _setFlag(_repeatableFlag, repeatable);

  /// Whether this node is an attribute.
  bool get isAttribute => _flag(_attributeFlag);

  /// Whether this element is relevant, including inherited relevance.
  bool get isRelevant => _flag(_relevantInheritedFlag) && _flag(_relevantFlag);

  /// Whether this element is enabled, including the inherited state.
  bool get isEnabled => _flag(_enabledInheritedFlag) && _flag(_enabledFlag);

  /// Whether a value is required.
  bool get isRequired => _flag(_requiredFlag);

  /// Sets the required state, notifying listeners on change.
  set isRequired(bool required) {
    if (_flag(_requiredFlag) == required) return;
    _setFlag(_requiredFlag, required);
    _notify(ElementChange.required);
  }

  /// Sets this element's own relevance; descendants inherit it.
  set isRelevant(bool relevant) => _setRelevant(relevant, inherited: false);

  void _setRelevant(bool relevant, {required bool inherited}) {
    final oldRelevant = isRelevant;
    _setFlag(inherited ? _relevantInheritedFlag : _relevantFlag, relevant);
    final newRelevant = isRelevant;
    if (newRelevant == oldRelevant) return;
    for (final attribute in _attributes) {
      attribute._setRelevant(newRelevant, inherited: true);
    }
    for (final child in _children) {
      child._setRelevant(newRelevant, inherited: true);
    }
    _notify(ElementChange.relevant);
  }

  /// Sets the enabled state (own or [inherited]); descendants inherit it.
  void setEnabled(bool enabled, {bool inherited = false}) {
    final oldEnabled = isEnabled;
    _setFlag(inherited ? _enabledInheritedFlag : _enabledFlag, enabled);
    if (isEnabled == oldEnabled) return;
    for (final child in _children) {
      child.setEnabled(isEnabled, inherited: true);
    }
    _notify(ElementChange.enabled);
  }

  // ------------------------------------------------------------ listeners

  /// Registers [listener] for state changes (once).
  void addListener(TreeElementListener listener) {
    final listeners = _listeners ??= [];
    if (!listeners.contains(listener)) listeners.add(listener);
  }

  /// Unregisters [listener].
  void removeListener(TreeElementListener listener) {
    final listeners = _listeners;
    if (listeners == null) return;
    listeners.remove(listener);
    if (listeners.isEmpty) _listeners = null;
  }

  /// Unregisters all listeners.
  void removeAllListeners() => _listeners = null;

  void _notify(int changes) {
    final listeners = _listeners;
    if (listeners == null) return;
    for (final listener in [...listeners]) {
      listener(this, changes);
    }
  }

  // ------------------------------------------------------------ attributes

  /// The attribute nodes.
  List<TreeElement> get attributes => List.unmodifiable(_attributes);

  /// Number of attributes.
  int get attributeCount => _attributes.length;

  /// The attribute called [name] in [namespace] (any namespace if `null`).
  TreeElement? getAttribute(String? namespace, String name) =>
      _findAttribute(_attributes, namespace, name);

  /// The value of attribute [name] in [namespace], if present.
  String? getAttributeValue(String? namespace, String name) =>
      getAttribute(namespace, name)?.value?.uncast().string;

  /// This attribute node's value. Throws if this is not an attribute.
  String? get attributeValue {
    if (!isAttribute) throw StateError('this is not an attribute');
    return _value?.uncast().string;
  }

  /// Sets, adds or (with a `null` [value]) removes an attribute.
  void setAttribute(String? namespace, String name, String? value) =>
      _setAttribute(this, _attributes, namespace, name, value);

  /// The bind attributes not handled by the engine (e.g. `odk:length`).
  List<TreeElement> get bindAttributes => _bindAttributes;

  /// Copies [attributes] into this element's bind attributes.
  set bindAttributes(List<TreeElement> attributes) {
    for (final attribute in attributes) {
      setBindAttribute(
        attribute.namespace,
        attribute.name!,
        attribute.attributeValue,
      );
    }
  }

  /// The bind attribute [name] in [namespace], if present.
  TreeElement? getBindAttribute(String? namespace, String name) =>
      _findAttribute(_bindAttributes, namespace, name);

  /// The value of bind attribute [name] in [namespace], if present.
  String? getBindAttributeValue(String? namespace, String name) =>
      getBindAttribute(namespace, name)?.value?.uncast().string;

  /// Sets, adds or removes a bind attribute.
  void setBindAttribute(String? namespace, String name, String? value) =>
      _setAttribute(this, _bindAttributes, namespace, name, value);

  static TreeElement? _findAttribute(
    List<TreeElement> attributes,
    String? namespace,
    String name,
  ) {
    for (final attribute in attributes) {
      if (attribute.name == name &&
          (namespace == null || namespace == attribute.namespace)) {
        return attribute;
      }
    }
    return null;
  }

  static void _setAttribute(
    TreeElement? parent,
    List<TreeElement> attributes,
    String? namespace,
    String name,
    String? value,
  ) {
    final existing = _findAttribute(attributes, namespace, name);
    if (existing != null) {
      if (value == null) {
        attributes.remove(existing);
      } else {
        existing.value = UncastValue(value);
      }
      return;
    }
    if (value == null) return; // a null value means "remove"
    attributes.add(
      TreeElement.attribute(namespace, name, value)..parent = parent,
    );
  }

  /// The attribute called [name] in [namespace] (any namespace if `null`)
  /// among [attributes]. Port of the static `TreeElement.getAttribute`.
  static TreeElement? findAttributeIn(
    List<TreeElement> attributes,
    String? namespace,
    String name,
  ) => _findAttribute(attributes, namespace, name);

  /// Sets, adds or (with a `null` [value]) removes an attribute in
  /// [attributes], adopted by [parent]. Port of the static
  /// `TreeElement.setAttribute`.
  static void setAttributeIn(
    TreeElement? parent,
    List<TreeElement> attributes,
    String? namespace,
    String name,
    String? value,
  ) => _setAttribute(parent, attributes, namespace, name, value);

  @override
  String toString() => '${_name ?? 'NULL'} - Children: ${_children.length}';
}

/// Bumped whenever any element's name, multiplicity or namespace prefix
/// changes, so [_TreeElementChildren] lookup tables built before are
/// rebuilt (an element can be in a children list other than its parent's,
/// e.g. after [TreeElement.shallowCopy]).
int _identityEpoch = 0;

/// Lookup tables over a long children list (see [_TreeElementChildren]).
final class _ChildIndex {
  _ChildIndex(List<TreeElement> children) {
    for (var i = 0; i < children.length; i++) {
      _addFirst(children[i], i);
    }
  }

  /// The first index of each name and multiplicity (templates included),
  /// for [_TreeElementChildren.find]: JavaRosa's exact-name search.
  final Map<String, Map<int, int>> first = {};

  /// The indexes, in order, of the non-template children matching each
  /// name as [elementMatchesName] does (the name itself, or
  /// `prefix:name`), for [_TreeElementChildren.withName]; built on first
  /// use.
  Map<String, List<int>>? _matching;

  Map<String, List<int>> matching(List<TreeElement> children) {
    if (_matching case final matching?) return matching;
    final matching = _matching = {};
    for (var i = 0; i < children.length; i++) {
      _addMatching(matching, children[i], i);
    }
    return matching;
  }

  /// Records [child], appended at [i].
  void add(TreeElement child, int i) {
    _addFirst(child, i);
    if (_matching case final matching?) _addMatching(matching, child, i);
  }

  void _addFirst(TreeElement child, int i) {
    final name = child.name;
    if (name != null) {
      (first[name] ??= {}).putIfAbsent(child.multiplicity, () => i);
    }
  }

  static void _addMatching(
    Map<String, List<int>> matching,
    TreeElement child,
    int i,
  ) {
    if (child.multiplicity == TreeReference.indexTemplate) return;
    final name = child.name;
    if (name != null) (matching[name] ??= []).add(i);
    final prefix = child.namespacePrefix;
    if (prefix != null) {
      final prefixed = '$prefix:$name';
      if (prefixed != name) (matching[prefixed] ??= []).add(i);
    }
  }
}

/// Child list with JavaRosa's fast paths for the common case of a repeat
/// whose children all share one name and have normal multiplicities.
///
/// Port of `TreeElementChildrenList`, including its sticky "all same name"
/// flag (never reset by removals).
final class _TreeElementChildren extends Iterable<TreeElement> {
  final _list = <TreeElement>[];
  bool _allSameNameAndNormalMultiplicity = true;

  /// Added: for long lists (repeats, or a form root with many questions),
  /// lookup tables by name and multiplicity, so lookups don't scan every
  /// sibling. Same results as JavaRosa's linear searches; kept up to date
  /// by appends, dropped on any other change.
  _ChildIndex? _index;
  int _indexEpoch = -1;

  static const _indexThreshold = 32;
  static const _scansBeforeIndex = 4;
  int _scans = 0;

  @override
  Iterator<TreeElement> get iterator => _list.iterator;

  @override
  int get length => _list.length;

  @override
  bool get isEmpty => _list.isEmpty;

  TreeElement operator [](int i) => _list[i];

  void insert(int index, TreeElement child) {
    _check(child.name, child.multiplicity);
    _insert(index, child);
  }

  void addAll(Iterable<TreeElement> children) {
    for (final child in children) {
      _check(child.name, child.multiplicity);
      _insert(_list.length, child);
    }
  }

  void addInOrder(TreeElement child) {
    final childMultiplicity = child.multiplicity;
    final int searchMultiplicity;
    final int adjustment;
    if (childMultiplicity == TreeReference.indexTemplate) {
      searchMultiplicity = 0;
      adjustment = 0;
    } else {
      searchMultiplicity = childMultiplicity == 0
          ? TreeReference.indexTemplate
          : childMultiplicity - 1;
      adjustment = 1;
    }
    final index = _indexOf(child.name!, searchMultiplicity);
    _check(child.name, child.multiplicity);
    _insert(index == -1 ? _list.length : index + adjustment, child);
  }

  TreeElement? find(String name, int multiplicity) {
    final index = _indexOf(name, multiplicity);
    return index == -1 ? null : _list[index];
  }

  List<TreeElement> withName(String name) {
    if (_sameNameAndNormal(name, TreeReference.defaultMultiplicity)) {
      return _list.toList(); // sized up front (the fast path of the search)
    }
    final results = <TreeElement>[];
    _findWithName(name, results);
    return results;
  }

  int countWithName(String name) => _findWithName(name, null);

  void remove(TreeElement child) {
    _changed();
    _list.remove(child);
  }

  void removeAt(int i) {
    _changed();
    _list.removeAt(i);
  }

  void clear() {
    _changed();
    _list.clear();
  }

  /// Inserts [child] at [index]; an append keeps the lookup tables.
  void _insert(int index, TreeElement child) {
    child._listed = true;
    if (index == _list.length) {
      _current()?.add(child, index);
      _list.add(child);
    } else {
      _changed();
      _list.insert(index, child);
    }
  }

  void _changed() {
    _index = null;
    _scans = 0;
  }

  void _check(String? name, int multiplicity) {
    _allSameNameAndNormalMultiplicity = _sameNameAndNormal(name, multiplicity);
  }

  bool _sameNameAndNormal(String? name, int multiplicity) =>
      _allSameNameAndNormalMultiplicity &&
      multiplicity >= 0 &&
      (_list.isEmpty || name == _list.first.name);

  int _findWithName(String name, List<TreeElement>? results) {
    if (_sameNameAndNormal(name, TreeReference.defaultMultiplicity)) {
      results?.addAll(_list);
      return _list.length;
    }
    if (_list.length >= _indexThreshold &&
        name != TreeReference.nameWildcard) {
      final tables = _indexed();
      if (tables != null) {
        final matching = tables.matching(_list)[name];
        if (matching == null) return 0;
        if (results != null) {
          for (final i in matching) {
            results.add(_list[i]);
          }
        }
        return matching.length;
      }
    }
    var count = 0;
    for (final child in _list) {
      if (child.multiplicity != TreeReference.indexTemplate &&
          elementMatchesName(child, name)) {
        count++;
        results?.add(child);
      }
    }
    return count;
  }

  int _indexOf(String name, int multiplicity) {
    if (name == TreeReference.nameWildcard) {
      if (multiplicity == TreeReference.indexTemplate ||
          _list.length < multiplicity + 1) {
        return -1;
      }
      return multiplicity;
    }
    if (_sameNameAndNormal(name, multiplicity) && multiplicity < _list.length) {
      if (_list[multiplicity].multiplicity == multiplicity) return multiplicity;
    }
    if (_list.length >= _indexThreshold) {
      final tables = _indexed();
      if (tables != null) return tables.first[name]?[multiplicity] ?? -1;
    }
    for (var i = 0; i < _list.length; i++) {
      final child = _list[i];
      if (name == child.name && child.multiplicity == multiplicity) return i;
    }
    return -1;
  }

  /// The lookup tables, if built and still valid.
  _ChildIndex? _current() {
    if (_indexEpoch != _identityEpoch) {
      _changed();
      _indexEpoch = _identityEpoch;
    }
    return _index;
  }

  /// The lookup tables, built after a few scans of a long list (appends
  /// update them; other changes drop them and restart the count).
  _ChildIndex? _indexed() {
    if (_current() case final tables?) return tables;
    if (++_scans < _scansBeforeIndex) return null;
    return _index = _ChildIndex(_list);
  }
}

/// Whether [element] matches [name]: the wildcard `*`, its name, or
/// `prefix:name` with its namespace prefix.
///
/// Port of `TreeElementNameComparator.elementMatchesName`.
bool elementMatchesName(TreeElement element, String name) {
  if (name == TreeReference.nameWildcard) return true;
  if (element.name == name) return true;
  final prefix = element.namespacePrefix;
  return prefix != null && '$prefix:${element.name}' == name;
}
