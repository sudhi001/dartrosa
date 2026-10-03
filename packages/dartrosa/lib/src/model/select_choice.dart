import 'instance/tree_element.dart';

/// One choice of a select question: a value and a label (literal text or
/// an itext id).
///
/// Port of `org.javarosa.core.model.SelectChoice`. Choices are created by
/// the parser; [index] is assigned afterwards by the owning question.
final class SelectChoice {
  /// A choice whose label is the itext id [labelId].
  SelectChoice.localized(String labelId, String value)
    : this._(labelId, null, value, true, null, null);

  /// A choice with explicit label text or id.
  SelectChoice(
    String? labelId,
    String? labelInnerText,
    String value, {
    required bool isLocalizable,
  }) : this._(labelId, labelInnerText, value, isLocalizable, null, null);

  /// A choice built from an itemset [item]; [labelOrId] is an itext id when
  /// [isLocalizable], otherwise the label text.
  SelectChoice.fromItem(
    String labelOrId,
    String value, {
    required bool isLocalizable,
    TreeElement? item,
    String? labelRefName,
  }) : this._(
         isLocalizable ? labelOrId : null,
         isLocalizable ? null : labelOrId,
         value,
         isLocalizable,
         item,
         labelRefName,
       );

  SelectChoice._(
    this.textId,
    this.labelInnerText,
    String value,
    this.isLocalizable,
    this.item,
    this.labelRefName,
  ) : value = value.trim();

  /// The value stored when this choice is selected (trimmed).
  final String value;

  /// Literal label text, when not localized.
  String? labelInnerText;

  /// The itext id of the label, when localized.
  String? textId;

  /// Whether the label is an itext id.
  bool isLocalizable;

  /// The itemset node this choice came from, if any.
  final TreeElement? item;

  /// Name of the itemset label child, if any.
  final String? labelRefName;

  int _index = -1;

  /// Position within the question's choices. Throws if not yet assigned.
  int get index {
    if (_index == -1) {
      throw StateError('trying to access choice index before it has been set!');
    }
    return _index;
  }

  set index(int index) => _index = index;

  /// Whether [index] has been assigned.
  bool get hasIndex => _index != -1;

  /// Display text of the itemset child [childName], `''` if it has no
  /// value, or `null` if there is no such child.
  String? child(String childName) {
    final child = item?.getChild(childName, 0);
    if (child == null) return null;
    return child.value?.displayText ?? '';
  }

  /// Name and display text of every itemset child except the label.
  List<(String, String)> get additionalChildren {
    final item = this.item;
    if (item == null) return [];
    return [
      for (final child in item.children)
        if (child.ref.lastName != labelRefName)
          (child.name!, child.value?.displayText ?? ''),
    ];
  }

  @override
  String toString() =>
      '${textId != null && textId!.isNotEmpty ? '{$textId}' : ''}'
      '${labelInnerText ?? ''} => $value';
}
