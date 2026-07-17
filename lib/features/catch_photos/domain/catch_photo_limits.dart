/// The maximum number of photos a single Catch may contain.
///
/// This is the single shared source of truth for the limit. It is enforced
/// authoritatively by [CatchPhotoRepository] and mirrored by the Add/Edit Catch
/// presentation so the UI can disable photo actions once the limit is reached.
/// See MFS-013 / TD-013.
const int maxCatchPhotos = 5;
