/// A photo the user has selected (from camera or gallery) but that has not
/// yet been persisted.
///
/// Represents a transient picker result only — mirrors `PendingCatchPhoto`
/// (catch_photos), kept as this feature's own small type rather than a
/// reused import so `personal_tackle_box` never depends on `catch_photos`.
/// See MFS-016 / TD-016.
final class PendingTackleBoxPhoto {
  const PendingTackleBoxPhoto({required this.sourcePath});

  /// The path to the picked source file. Outside application ownership and
  /// may become unavailable.
  final String sourcePath;
}
