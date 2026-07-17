/// A photo that the user has selected (from camera or gallery) but that has
/// not yet been persisted.
///
/// Represents a transient picker result only. It carries no database identity,
/// no Catch association, and no application-owned relative path, and it does not
/// imply that the application owns [sourcePath]. See MFS-013 / TD-013.
final class PendingCatchPhoto {
  const PendingCatchPhoto({required this.sourcePath});

  /// The path to the picked source file (camera capture or gallery item).
  ///
  /// This file is outside application ownership and may become unavailable.
  final String sourcePath;
}
