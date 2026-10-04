import 'package:meta/meta.dart';

/// A named entity list (dataset) stored on the device.
///
/// Port of `org.odk.collect.entities.storage.EntityList`.
@immutable
final class EntityList {
  /// Creates a list description.
  const EntityList(
    this.name, {
    this.hash,
    this.needsApproval = false,
    this.lastUpdated,
  });

  /// The list (dataset) name, also the secondary instance id forms use.
  final String name;

  /// The hash of the server list (media file) last imported, if any.
  final String? hash;

  /// Whether new entities need server approval (an
  /// `APPROVAL_ENTITY_LIST`), in which case forms don't create them
  /// locally.
  final bool needsApproval;

  /// When the list was last updated from the server (milliseconds since
  /// the epoch, from the repository's clock), if ever.
  final int? lastUpdated;

  /// A copy with the given fields replaced.
  EntityList copyWith({String? hash, bool? needsApproval, int? lastUpdated}) =>
      EntityList(
        name,
        hash: hash ?? this.hash,
        needsApproval: needsApproval ?? this.needsApproval,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  @override
  bool operator ==(Object other) =>
      other is EntityList &&
      other.name == name &&
      other.hash == hash &&
      other.needsApproval == needsApproval &&
      other.lastUpdated == lastUpdated;

  @override
  int get hashCode => Object.hash(name, hash, needsApproval, lastUpdated);

  @override
  String toString() =>
      'EntityList(name=$name, hash=$hash, needsApproval=$needsApproval, '
      'lastUpdated=$lastUpdated)';
}
