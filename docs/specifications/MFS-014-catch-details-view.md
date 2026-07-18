# MFS-014 — Catch Details View

## Status

Draft

## Purpose

Provide a dedicated read-only view for inspecting a saved catch without immediately entering edit mode.

The feature separates catch viewing from catch editing, improves back navigation, and adds photo thumbnails to the catch list.

## User Problem

Currently, selecting a catch opens the edit view directly.

This creates several usability problems:

- The user may only want to inspect the catch.
- Photo addition, photo removal, and catch deletion are immediately available.
- The user can accidentally modify the catch.
- Back navigation may return directly to the map instead of the catch list.
- Catch photos are not visible in the catch list.

## User Flow

Map  
→ Fishing spot  
→ Catch list  
→ Catch details  
→ Edit catch

After saving:

Edit catch  
→ Catch details

Back navigation:

Edit catch  
→ Catch details  
→ Catch list  
→ Map

## Functional Requirements

### FR-1 — Open Catch Details

Selecting a catch from the catch list must open a read-only Catch Details view.

The catch editor must not open directly.

### FR-2 — Read-Only Catch Information

The Catch Details view must display the available catch information without editable input fields.

The view must support displaying:

- species
- date
- time
- weight
- length
- lure
- notes
- catch photos

Missing optional values must not produce empty or broken UI elements.

### FR-3 — App Bar

The Catch Details view must use a Material 3 style app bar.

The app bar must contain:

- a back button on the left
- the catch species as the title
- an overflow menu on the right

If the species is unavailable, a generic catch title may be used.

### FR-4 — Back Navigation

The app bar back button must return to the catch list for the same fishing spot.

The Android system back action must behave consistently with the app bar back button.

It must not return directly to the map while the catch list is still part of the active navigation flow.

### FR-5 — Overflow Menu

The overflow menu must contain:

- Edit
- Delete

Destructive styling must be used for the Delete action where appropriate.

### FR-6 — Edit Catch

Selecting Edit must open the existing Edit Catch view.

After a successful save:

- the editor must close
- Catch Details must remain open
- the displayed information must reflect the saved changes

Leaving the editor without saving must return to Catch Details.

Existing unsaved-change handling must be preserved where applicable.

### FR-7 — Delete Catch

Selecting Delete must require user confirmation.

After successful deletion:

- Catch Details must close
- the user must return to the catch list
- the deleted catch must no longer appear in the list

Existing catch-photo cleanup behaviour must remain intact.

### FR-8 — Catch Photos

If the catch contains photos:

- the first photo must be displayed prominently
- all saved photos must be accessible from the details view
- photo order must follow the existing `sortOrder`

The existing full-screen photo viewer may be reused.

If the catch has no photos, the layout must remain visually valid without an empty image container.

### FR-9 — Catch List Thumbnail

Each catch item in the catch list must display:

- the first catch photo when available
- a placeholder or existing catch icon when no photo exists

The thumbnail must:

- use the first photo by `sortOrder`
- use a cropped presentation such as `BoxFit.cover`
- have rounded corners
- avoid decoding the image at unnecessarily large dimensions

### FR-10 — Operation Safety

Read-only Catch Details must not expose direct controls for:

- adding photos
- removing photos
- changing catch fields
- saving changes

These actions must only be available after entering Edit Catch.

## UX Requirements

- Catch photos are the primary visual content.
- Catch information must be easy to scan.
- The details content must be vertically scrollable.
- The view must work on narrow Android screens.
- App bar controls must remain clearly accessible.
- The view must follow the existing Material 3 application theme.
- The details view must not visually resemble an editable form.

## Architecture Constraints

- Preserve the existing feature-first architecture.
- Preserve offline-first behaviour.
- Reuse the existing catch and catch-photo repositories.
- Use constructor injection.
- Do not introduce:
  - service classes
  - use-case classes
  - DAO classes
  - repository interfaces
  - state-management providers
- Do not modify the Catch or CatchPhoto domain models unless implementation review proves it necessary.
- Do not add a new database migration for presentation-only requirements.

## Suggested Presentation Structure

`features/catches/presentation/widgets/catch_details_page.dart` (implemented
as a full-screen page, `CatchDetailsPage`, not a modal Bottom Sheet — see
TD-014)

`features/catches/presentation/widgets/edit_catch_bottom_sheet.dart`

Existing catch-photo presentation widgets should be reused where suitable.

## Acceptance Criteria

The feature is accepted when:

1. Selecting a catch opens Catch Details instead of Edit Catch.
2. Catch Details contains no editable fields.
3. The app bar contains Back and Overflow controls.
4. Back returns to the catch list.
5. Android system back follows the same navigation hierarchy.
6. Edit opens the existing catch editor.
7. Saving returns to updated Catch Details.
8. Delete requires confirmation and returns to the catch list.
9. Catch photos are visible in Catch Details.
10. The first catch photo appears as a thumbnail in the catch list.
11. Catches without photos use a valid placeholder.
12. Existing photo persistence and deletion behaviour remains correct.
13. Automated tests cover the navigation and primary actions.
14. `flutter analyze` introduces no new errors or warnings.
15. The feature is verified on a physical Android device.

## Testing Requirements

Automated tests must cover at minimum:

- opening Catch Details from the catch list
- details content rendering
- catch with photos
- catch without photos
- catch list thumbnail
- catch list placeholder
- app bar back navigation
- Android back navigation
- opening Edit Catch
- returning to Catch Details after save
- returning to Catch Details after cancelling edit
- delete confirmation cancellation
- successful catch deletion
- updated details after editing

## Out of Scope

The following are not included in MFS-014:

- Hero animations
- pinch-to-zoom
- photo reordering
- slideshow mode
- photo sharing
- catch sharing
- image captions
- EXIF metadata
- weather presentation
- map preview
- dedicated thumbnail files
- changes to image-processing quality