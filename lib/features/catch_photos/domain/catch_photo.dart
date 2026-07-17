/// A persisted photo attached to a [Catch].
///
/// Framework-independent: it depends on neither Flutter nor Drift, contains no
/// image bytes, and stores only an application-managed relative path (never an
/// absolute device path). See MFS-013 / TD-013.
final class CatchPhoto {
  const CatchPhoto({
    required this.id,
    required this.catchId,
    required this.relativePath,
    required this.sortOrder,
    required this.createdAt,
  }) : assert(id != '', 'id must not be empty'),
       assert(catchId != '', 'catchId must not be empty'),
       assert(relativePath != '', 'relativePath must not be empty'),
       assert(sortOrder >= 0, 'sortOrder must be zero or greater');

  final String id;
  final String catchId;
  final String relativePath;
  final int sortOrder;
  final DateTime createdAt;
}
