/// The maximum number of raw, user-entered characters a Catch's [notes]
/// field may contain, measured before whitespace trimming.
///
/// This is the single shared source of truth for the limit. It is enforced
/// authoritatively by [CatchRepository] and mirrored by the Add/Edit Catch
/// presentation so the UI can block and communicate the limit before a save
/// is attempted. See MFS-023 / TD-023.
const int maxCatchNotesLength = 1000;
