/// The server's view of entities, for cleaning up local offline
/// entities that were deleted there.
///
/// Port of `org.odk.collect.entities.server.EntitySource`. The app
/// implements it (Collect calls the entity list's integrity URL);
/// asynchronous since it's network access.
abstract interface class EntitySource {
  /// Whether each of [ids] is deleted on the server, as (id, deleted)
  /// pairs, from the list's [integrityUrl].
  Future<List<(String, bool)>> fetchDeletedStates(
    String integrityUrl,
    List<String> ids,
  );
}
