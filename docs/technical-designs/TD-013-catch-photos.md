# TD-013 — Catch Photos

## Goal

Implement offline Catch photo support that allows users to attach, view, add, and remove photos when creating or editing a Catch.

Catch photos shall be stored in application-owned local storage and persistently associated with the correct Catch.

The implementation shall satisfy MFS-013.

---

## Scope

Implement:

- CatchPhoto domain model
- CatchPhotos Drift table
- database migration
- concrete CatchPhotoRepository
- application-owned photo storage
- image selection from camera
- image selection from gallery
- multiple photos
- maximum of 5 photos per Catch
- temporary photo handling during Add Catch
- persistent photo handling during Edit Catch
- image processing before permanent storage
- photo previews
- full-screen photo viewer
- persistent photo deletion
- Catch deletion photo cleanup
- missing and corrupt file handling
- permission and picker cancellation handling
- tests

Do **not** implement:

- cloud synchronization
- remote image storage
- upload queues
- repository interfaces
- DAO layer
- service layer
- use-case layer
- global photo state notifier
- reactive database streams
- draft Catches
- photo captions
- photo notes
- videos
- photo editing
- filters
- cropping UI
- manual photo rotation
- manual photo reordering
- cover photos
- EXIF display
- GPS extraction from image metadata
- separate persistent thumbnail files
- undo after photo deletion

---

# Architecture

Catch Photos shall be implemented as its own feature.

Expected structure:

```text
lib/features/catch_photos/
  data/
    catch_photo_mapper.dart
    catch_photo_repository.dart
    local/
      catch_photos_table.dart
    storage/
      catch_photo_storage.dart
  domain/
    catch_photo.dart
    pending_catch_photo.dart
  presentation/
    widgets/
      catch_photo_picker.dart
      catch_photo_preview_list.dart
      catch_photo_thumbnail.dart
      catch_photo_viewer.dart
```

Exact widget file separation may be adjusted if a smaller structure is clearer.

The implementation shall follow the current project architecture:

- feature-first
- offline-first
- concrete repositories
- Drift accessed directly through repositories
- local Bottom Sheet state
- explicit result objects
- Material 3
- no unnecessary abstraction layers

---

# Feature Ownership

The `catch_photos` feature owns:

- CatchPhoto persistence
- photo file lifecycle
- photo path resolution
- photo processing
- photo selection integration
- photo previews
- photo viewing
- photo deletion

The `catches` feature continues to own:

- Catch domain data
- Catch creation
- Catch editing
- Catch deletion entry points
- Add Catch Bottom Sheet
- Edit Catch Bottom Sheet

The Catch Bottom Sheets may use Catch Photos presentation widgets and repository operations.

Do not move Catch ownership into the Catch Photos feature.

---

# Dependencies

Select maintained Flutter packages that support the required platforms.

Expected dependency categories:

- image picking
- application document directory access
- image decoding, resizing, and encoding
- UUID generation if not already available
- full-screen zoomable image viewing if not implemented with Flutter SDK widgets

Likely packages:

```yaml
image_picker:
path_provider:
image:
```

Reuse the project’s existing UUID package if already present.

Do not add a second UUID package.

A separate photo viewer package is optional.

Prefer Flutter SDK widgets such as:

- `InteractiveViewer`
- `PageView`
- `Image.file`

when they satisfy the requirements without excessive custom code.

Document every dependency added.

---

# Domain

## CatchPhoto

Create a framework-independent domain model.

Expected API:

```dart
final class CatchPhoto {
  const CatchPhoto({
    required this.id,
    required this.catchId,
    required this.relativePath,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String catchId;
  final String relativePath;
  final int sortOrder;
  final DateTime createdAt;
}
```

Requirements:

- `id` shall be non-empty
- `catchId` shall be non-empty
- `relativePath` shall be non-empty
- `sortOrder` shall be zero or greater
- the model shall not depend on Flutter
- the model shall not depend on Drift
- the model shall not contain image bytes
- the model shall not contain an absolute device path
- the model shall not contain cloud fields

Use assertions only if consistent with the existing Catch domain model.

Repository methods shall still validate public input and throw meaningful argument errors where appropriate.

---

## PendingCatchPhoto

Temporary photos selected before persistence shall use a separate temporary model.

Expected API:

```dart
final class PendingCatchPhoto {
  const PendingCatchPhoto({
    required this.sourcePath,
  });

  final String sourcePath;
}
```

The exact fields may include picker-specific metadata only when genuinely required.

Requirements:

- represent a camera or gallery selection that has not been persisted
- remain independent of CatchPhoto database identity
- not require a Catch ID
- not contain a permanent relative path
- not create a database row
- not imply application ownership of the source file

Do not reuse `CatchPhoto` for temporary picker results.

---

# Database

## Schema Version

Increment the Drift schema version from its current value to the next version.

Based on the current project state, the expected migration is:

```text
schema version 2 -> schema version 3
```

Confirm the current schema version from the implementation before changing it.

Do not assume version numbers if the repository has changed.

---

## CatchPhotos Table

Create:

```text
lib/features/catch_photos/data/local/catch_photos_table.dart
```

Expected Drift structure:

```dart
class CatchPhotos extends Table {
  TextColumn get id => text()();

  TextColumn get catchId => text().references(
        Catches,
        #id,
        onDelete: KeyAction.cascade,
      )();

  TextColumn get relativePath => text()();

  IntColumn get sortOrder => integer()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

Adapt imports and generated types to the current database structure.

Requirements:

- `id` is the primary key
- `catchId` references `Catches.id`
- foreign key deletion uses cascade
- `relativePath` stores a relative path only
- `sortOrder` is required
- `createdAt` is required
- no image blob column
- no absolute path column
- no cloud synchronization columns
- no thumbnail path column

---

## Database Registration

Register `CatchPhotos` in `AppDatabase`.

Regenerate Drift output using the project’s established generation command.

Do not manually edit generated Drift files.

---

## Migration

Add a migration that creates the CatchPhotos table.

Requirements:

- preserve all existing Fishing Spots
- preserve all existing Catches
- create only the required new table and indexes
- do not rebuild unrelated tables
- do not modify existing Catch columns
- do not add placeholder photo rows
- migration from the immediately previous schema version must succeed

If the project uses explicit migration branching, follow the existing pattern.

---

## Indexes

Add an index for Catch photo lookup if supported cleanly by the current Drift setup.

Recommended indexed columns:

```text
catch_id
```

A composite index may be used for ordered queries:

```text
catch_id, sort_order
```

Do not add unnecessary indexes.

---

## Database Constraints

Repository validation shall enforce:

```text
0 <= sortOrder
```

The maximum of 5 photos per Catch shall be enforced in repository logic.

The UI limit alone is insufficient.

A database-level count constraint is not required.

---

# Mapper

Create:

```text
lib/features/catch_photos/data/catch_photo_mapper.dart
```

Responsibilities:

- map Drift CatchPhoto rows to the CatchPhoto domain model
- keep persistence types out of presentation code
- follow the existing Catch mapper style

Expected behavior:

```dart
CatchPhoto toDomain(CatchPhotoRow row)
```

Use the actual generated Drift row type.

A companion builder may remain private to the repository if that matches the current project style.

Do not create a generic mapper abstraction.

---

# Storage

## CatchPhotoStorage

Create a concrete feature-local storage component:

```text
lib/features/catch_photos/data/storage/catch_photo_storage.dart
```

Do not create:

```text
lib/core/storage/
```

Do not create a storage interface.

The storage component shall encapsulate direct file-system and image-processing operations.

---

## Storage Root

Use an application-owned persistent directory suitable for user-created application data.

Preferred base directory:

```dart
getApplicationDocumentsDirectory()
```

Do not use a cache directory for persistent Catch photos.

Conceptual path:

```text
<application-documents>/catch_photos/<catch-id>/<photo-id>.jpg
```

The database stores only:

```text
catch_photos/<catch-id>/<photo-id>.jpg
```

or an equivalent path relative to the selected application root.

---

## Path Rules

Persistent photo paths shall:

- be generated by the application
- use the Catch ID as a directory segment
- use the CatchPhoto ID as the filename
- use a normalized supported extension
- remain relative in the database
- be resolved through CatchPhotoStorage

Do not expose path construction throughout the UI or repository.

Expected storage API may include:

```dart
Future<String> store({
  required String catchId,
  required String photoId,
  required String sourcePath,
});

Future<File> resolve(String relativePath);

Future<void> delete(String relativePath);

Future<void> deleteCatchDirectory(String catchId);
```

Exact signatures may be adjusted for clearer error handling.

---

## File Ownership

Once a photo has been successfully copied and processed into application storage:

- the application exclusively owns the stored file
- the original camera or gallery file remains outside application ownership
- deleting the Catch photo shall not delete the original source
- deleting the original source shall not affect the Catch photo

---

# Image Processing

Process every selected photo before permanent storage.

Required behavior:

- decode the source image
- respect decoded orientation
- resize only when larger than the configured maximum
- preserve aspect ratio
- encode to JPEG
- write to a temporary destination first
- move or rename to the final destination only after successful encoding
- clean up temporary output after failure

Recommended parameters:

```text
Maximum longest side: 2048 pixels
JPEG quality: 85
Output extension: .jpg
```

These values may be adjusted slightly if the selected package interprets quality differently.

Do not upscale smaller images.

Do not persist the original full-resolution file in addition to the processed file.

---

## Unsupported or Invalid Source Images

If a selected source image cannot be decoded:

- do not create a CatchPhoto database row
- do not leave a final destination file
- report the individual photo as failed
- continue processing other selected photos where possible

---

## Atomic File Creation

Avoid database records pointing to partially written files.

Required sequence for one photo:

1. Generate photo ID.
2. Process image into a temporary file inside application-owned storage.
3. Confirm the temporary file exists and is readable.
4. Move or rename the file to its final path.
5. Insert the CatchPhoto database row.

If database insertion fails after final file creation:

- delete the final file
- rethrow or report failure

A CatchPhoto row shall not be inserted before the final file exists.

---

# CatchPhotoRepository

Create:

```text
lib/features/catch_photos/data/catch_photo_repository.dart
```

Use a concrete class.

Expected dependencies:

```dart
AppDatabase
CatchPhotoStorage
```

Optional dependencies:

```dart
UUID generator
clock function
```

Follow existing repository construction patterns.

---

## Repository Responsibilities

The repository owns:

- CatchPhoto ID generation
- persistent sort order assignment
- database CRUD
- coordination between database and storage
- maximum photo count validation
- relative path persistence
- storage cleanup after database failures
- database cleanup after confirmed photo deletion
- Catch photo lookup
- Catch-level photo file cleanup support

The repository does not own:

- image picker UI
- Bottom Sheet state
- permission dialogs
- snackbars
- full-screen viewer state
- Catch creation

---

## Get Photos

Expected method:

```dart
Future<List<CatchPhoto>> getByCatchId(String catchId);
```

Requirements:

- reject an empty Catch ID
- query only photos for the Catch
- order by `sortOrder` ascending
- use a stable secondary order such as `createdAt` or `id` if needed
- map rows to domain models
- return an empty list when there are no photos
- do not require the files to exist in order to return records

No Stream is required.

---

## Add Photo

Expected single-photo method:

```dart
Future<CatchPhoto> add({
  required String catchId,
  required PendingCatchPhoto pendingPhoto,
});
```

Requirements:

- reject an empty Catch ID
- reject an empty source path
- confirm the Catch exists or rely on the enforced foreign key and map failures clearly
- check the current photo count
- reject additions beyond 5 photos
- generate a unique photo ID
- calculate the next sort order
- store the processed file
- insert the database row
- return the persisted CatchPhoto
- clean up the stored file if insertion fails

---

## Add Multiple Photos

Expected method:

```dart
Future<AddCatchPhotosResult> addMany({
  required String catchId,
  required List<PendingCatchPhoto> pendingPhotos,
});
```

A result object is recommended:

```dart
final class AddCatchPhotosResult {
  const AddCatchPhotosResult({
    required this.added,
    required this.failedCount,
  });

  final List<CatchPhoto> added;
  final int failedCount;

  bool get hasFailures => failedCount > 0;
}
```

The exact failure representation may include per-photo errors if useful for testing.

Requirements:

- empty input returns an empty successful result
- preserve input order
- enforce the remaining photo capacity before processing
- never exceed 5 persistent photos
- process photos independently
- keep successfully added photos when another photo fails
- report failed additions
- do not roll back the Catch
- do not leave incomplete files
- do not leave incomplete rows

Do not wrap all file operations and database operations in a false atomic abstraction.

The file system cannot participate in a Drift transaction.

---

## Photo Count

Expected helper:

```dart
Future<int> countByCatchId(String catchId);
```

May remain private if only used internally.

Maximum:

```dart
static const int maxPhotosPerCatch = 5;
```

Keep this limit in one shared feature-level location used by repository and UI.

Do not duplicate the numeric literal throughout the project.

---

## Delete Photo

Expected method:

```dart
Future<void> delete(String photoId);
```

Requirements:

- reject an empty photo ID
- load the CatchPhoto row before deleting
- deleting a missing row completes successfully
- if the row exists, attempt file deletion
- a missing file is treated as already deleted
- remove the database row
- affect only the selected CatchPhoto
- preserve the Catch
- preserve all other photos

Preferred consistency sequence:

1. Load row.
2. Delete the physical file if present.
3. Delete the database row.

If file deletion fails for a reason other than file not found:

- keep the database row
- surface the failure
- allow retry

This avoids intentionally creating a database record whose file was known to remain undeleted after the operation failed.

---

## Delete Catch Photos

Provide repository support for Catch deletion cleanup.

Expected method:

```dart
Future<void> deleteAllForCatch(String catchId);
```

Requirements:

- reject an empty Catch ID
- retrieve all photo rows for the Catch
- attempt to delete every physical file
- ignore already missing files
- report genuine file-system failures
- remove related database rows only when cleanup can proceed consistently

The exact Catch deletion orchestration is defined below.

---

## Resolve Photo File

Presentation code requires a safe way to resolve a stored relative path.

Possible repository method:

```dart
Future<File> resolveFile(CatchPhoto photo);
```

Alternatively expose CatchPhotoStorage directly through feature dependency injection.

Prefer keeping UI path handling minimal.

The presentation layer shall not manually concatenate application directory paths.

---

# Add Catch Integration

Modify the existing Add Catch Bottom Sheet.

Do not replace the current Catch creation flow.

---

## Local State

Add Catch shall maintain local temporary state:

```dart
List<PendingCatchPhoto> pendingPhotos
```

Requirements:

- initially empty
- preserve selections during validation failures
- preserve selections during Catch repository failures
- remove selections explicitly deleted by the user
- discard selections when the Bottom Sheet is closed without saving
- enforce a maximum of 5

No database rows are created while editing the unsaved form.

No permanent application-owned files are created while editing the unsaved form.

---

## Photo Picker

Add a photo action that allows the user to choose:

```text
Camera
Gallery
Cancel
```

Use an appropriate Material 3 action sheet or dialog.

Do not open another full CRUD Bottom Sheet over the Add Catch Bottom Sheet if it causes nested Bottom Sheet behavior.

A small source-selection modal is acceptable.

---

## Camera

Camera capture:

- selects one photo per invocation
- adds the returned source path to pending state
- does nothing when the picker is cancelled
- does not clear existing form state
- does not exceed the remaining capacity

---

## Gallery

Gallery selection:

- supports multiple selection
- adds selected source paths in picker order
- limits accepted results to remaining capacity
- provides clear feedback if selected files exceed remaining capacity
- does nothing when the picker is cancelled
- preserves existing form state

If the selected picker API cannot enforce an exact selection limit before returning, enforce it immediately after selection.

---

## Temporary Preview

Display temporary previews inside Add Catch.

Requirements:

- support 0–5 images
- use consistent thumbnail dimensions
- crop visually using `BoxFit.cover`
- preserve the source image itself
- allow removing a pending photo
- allow opening a selected temporary photo in the viewer
- show a placeholder if the temporary source becomes unavailable

Removing a pending photo does not require confirmation.

---

## Add Catch Save Flow

The save flow shall be:

1. Prevent duplicate Save taps.
2. Validate the Catch form.
3. Parse and convert Catch fields.
4. Create the Catch through `CatchRepository`.
5. Pass the new Catch ID and pending photos to `CatchPhotoRepository.addMany`.
6. Close the Bottom Sheet with a result describing Catch creation and photo outcome.
7. Show the appropriate user message through the existing coordinator.

Catch creation shall occur before persistent photo creation.

---

## Add Catch Result

Extend the existing Add Catch result only as much as required to report partial photo failure.

Possible result:

```dart
final class CatchCreated extends AddCatchResult {
  const CatchCreated({
    required this.catchModel,
    required this.photoFailureCount,
  });

  final Catch catchModel;
  final int photoFailureCount;

  bool get hasPhotoFailures => photoFailureCount > 0;
}
```

Reuse the actual existing result naming and structure.

Do not create a second parallel result hierarchy unnecessarily.

---

## Catch Creation Failure

If Catch creation fails:

- keep the Add Catch Bottom Sheet open
- preserve all Catch form values
- preserve all pending photos
- re-enable controls
- show an error
- allow retry
- do not call CatchPhotoRepository
- do not create permanent photo files
- do not create CatchPhoto rows

---

## Partial Photo Failure

If the Catch is created but one or more photos fail:

- keep the Catch saved
- keep successfully persisted photos
- do not retry automatically
- close the Add Catch Bottom Sheet as a successful Catch creation
- show a partial-success message

Example user-facing meaning:

```text
Catch saved, but some photos could not be added.
```

The exact displayed language shall follow the application’s current UI language conventions.

Do not delete the successfully created Catch.

---

# Edit Catch Integration

Modify the existing Edit Catch Bottom Sheet.

---

## Initial Photo Load

When Edit Catch opens:

1. Load Catch photos using `CatchPhotoRepository.getByCatchId`.
2. Display a loading state only in the photo section when appropriate.
3. Keep existing Catch fields usable.
4. Show loaded photos in sort order.
5. Handle an empty list normally.

A photo loading failure shall:

- not close the Bottom Sheet
- not discard Catch form values
- show a clear photo-section error
- allow retry where practical

---

## Edit Catch Photo State

Maintain separate local collections:

```dart
List<CatchPhoto> existingPhotos
List<PendingCatchPhoto> pendingPhotos
```

Requirements:

- existing photos represent persistent records
- pending photos represent newly selected unsaved images
- combined count shall not exceed 5
- persistent deletion updates `existingPhotos` after repository success
- removing a pending photo updates only `pendingPhotos`

Do not convert persistent photos back into pending photos.

---

## Adding Photos During Edit

Newly selected photos may remain pending until the user presses Save.

On Save:

1. Validate and update the Catch using the existing flow.
2. Add pending photos using CatchPhotoRepository.
3. Preserve the successful Catch update even if some photos fail.
4. Return an update result containing partial photo failure information if required.
5. Show an appropriate message through the existing coordinator.

This keeps Catch field updates and new photo additions within the user’s Save action.

---

## Persistent Photo Deletion

Deleting an existing stored photo is immediate and independent from the Catch form Save action.

Flow:

1. User selects Delete on a persistent photo.
2. Show confirmation.
3. On Cancel, close confirmation only.
4. On confirmation, disable conflicting photo actions.
5. Call `CatchPhotoRepository.delete`.
6. Remove the photo from local existing photo state.
7. Re-enable actions.
8. Keep the Edit Catch Bottom Sheet open.

Do not require pressing Save after confirmed persistent photo deletion.

---

## Persistent Delete Confirmation

Display:

```text
Delete photo?

This action cannot be undone.

[Cancel] [Delete]
```

Use destructive styling for Delete.

---

## Persistent Delete Failure

If deletion fails:

- keep the photo in the UI
- keep the Edit Catch Bottom Sheet open
- preserve all Catch field values
- preserve pending photos
- show an error
- allow retry
- prevent duplicate delete requests during the active operation

---

## Edit Catch Save Failure

If the Catch update fails:

- do not persist pending photos
- keep the Bottom Sheet open
- preserve Catch field values
- preserve existing photos
- preserve pending photos
- re-enable controls
- show an error
- allow retry

---

## Edit Catch Partial Photo Failure

If Catch update succeeds but one or more pending photos fail:

- keep the Catch update
- keep successfully added photos
- close the Bottom Sheet with a successful Catch update result
- report the photo failure count
- show a partial-success message

Do not roll back the Catch update.

---

# Photo Limit

Use:

```dart
const int maxCatchPhotos = 5;
```

Place the constant in the Catch Photos feature where both data and presentation can access it without creating an unnecessary dependency direction.

Requirements:

- repository enforces persistent limit
- Add Catch enforces pending limit
- Edit Catch enforces combined existing and pending limit
- camera action is disabled or hidden at the limit
- gallery action is disabled or hidden at the limit
- clear UI feedback is shown when maximum is reached

Repository validation remains the source of truth.

---

# Photo Preview UI

Create reusable presentation widgets where useful.

Recommended component:

```text
CatchPhotoPreviewList
```

Inputs may include:

- existing photos
- pending photos
- maximum photo count
- add callback
- remove pending callback
- delete persistent callback
- open viewer callback
- loading state
- error state

Avoid a single oversized widget with repository logic inside it.

---

## Thumbnail Behavior

Thumbnail requirements:

- consistent square or near-square dimensions
- rounded Material 3 shape
- `BoxFit.cover`
- visible remove or delete affordance
- accessible semantic label
- placeholder for missing or corrupt image
- loading indicator only when useful
- no layout overflow on small Android screens

Use bounded image decoding where supported:

- `cacheWidth`
- `cacheHeight`

Do not create persistent thumbnail files in this feature.

---

# Full-Screen Photo Viewer

Create a dedicated full-screen route or page-style presentation.

Do not implement it as a nested Bottom Sheet.

Requirements:

- open at the selected photo
- support persistent and pending local files
- use `PageView` for multiple photos
- preserve aspect ratio
- use a dark or neutral viewing background
- provide an obvious Close or Back action
- support zoom and pan with `InteractiveViewer`
- handle missing or corrupt files with a placeholder
- not modify photo state

The viewer does not require a named GoRouter route if a direct Material page route better matches the current local flow.

Follow the project’s current navigation conventions.

---

# Missing and Corrupt Files

## Missing Persistent File

When a CatchPhoto row exists but its file is missing:

- return the CatchPhoto record normally
- show a placeholder
- allow deletion of the broken record
- do not silently delete the row
- do not crash the Catch form
- do not prevent viewing other photos

---

## Corrupt Persistent File

When image decoding fails:

- show a placeholder
- keep the CatchPhoto record
- allow deletion
- keep other photos available
- do not automatically overwrite or repair the file

---

## Missing Pending File

If a temporary picker source becomes unavailable:

- show a placeholder
- allow removing the pending selection
- exclude it or report failure during persistence
- do not crash Save

---

# Permissions and Picker Behavior

Use the selected picker package’s platform-appropriate behavior.

Prefer system photo picker behavior where available.

Do not request broad storage permissions when the platform picker does not require them.

---

## Permission Denial

Camera or photo access denial shall:

- keep the Catch Bottom Sheet open
- preserve Catch form values
- preserve existing and pending photos
- show a user-friendly message
- allow continuing without adding a photo

Do not treat user denial as an application crash or repository error.

---

## Picker Cancellation

Picker cancellation shall:

- make no state changes
- show no error
- preserve the form
- preserve existing selections
- not create files
- not create database rows

---

# Catch Deletion Integration

The existing Catch deletion flow must clean up photo files.

Database cascade removes CatchPhoto rows but cannot remove physical files.

Therefore Catch deletion requires orchestration before the Catch row is deleted.

---

## CatchRepository Coordination

Do not make CatchRepository directly depend on CatchPhotoRepository if that creates a cyclic feature dependency.

Preferred coordination location:

- the existing Edit Catch deletion workflow
- a small private coordination helper in the presentation flow
- or a repository-level composition approved by the existing dependency direction

The final design must preserve:

```text
catches does not become dependent on catch_photos presentation
```

Data-layer dependency from Catch deletion coordination to CatchPhotoRepository is acceptable if it remains simple and acyclic.

Do not introduce a service or use-case layer solely for this operation.

---

## Catch Delete Flow

Required sequence:

1. Disable duplicate actions.
2. Retrieve photo records for the Catch.
3. Delete associated photo files.
4. Delete the Catch through CatchRepository.
5. Allow database cascade to remove CatchPhoto rows.
6. Remove an empty Catch photo directory when practical.
7. Close the Edit Catch Bottom Sheet.
8. Return CatchDeleted.

Alternative accepted sequence:

1. Delete all photos through CatchPhotoRepository.
2. Delete Catch through CatchRepository.

Use this only if failure semantics are clear and tested.

---

## Catch Delete Failure Semantics

If photo file cleanup fails before Catch deletion:

- do not delete the Catch
- keep the Edit Catch Bottom Sheet open
- preserve the Catch and its photo records
- show an error
- allow retry

If the Catch deletion fails after photo cleanup:

- report the failure
- keep the Catch row
- missing photo files shall display placeholders
- allow the Catch to be deleted on retry

This rare cross-resource inconsistency shall be documented in implementation notes.

Do not pretend file-system and database deletion are fully transactional.

---

## Missing Files During Catch Delete

Already missing files shall not block Catch deletion.

The cleanup logic shall continue for all other photos.

---

# Dependency Injection

Expose CatchPhotoRepository using the project’s existing dependency pattern.

If Riverpod providers currently supply repositories, add a simple provider for the concrete repository.

Do not add:

- StateNotifier
- AsyncNotifier
- global photo state
- repository interface provider

Bottom Sheets shall continue to own transient UI state.

---

# Operation State

Track local operation states needed to prevent duplicate actions.

Examples:

```dart
bool isSaving
bool isPickingPhoto
Set<String> deletingPhotoIds
```

Requirements:

- prevent duplicate Save
- prevent duplicate photo picker invocation
- prevent duplicate deletion of the same photo
- disable conflicting actions during Catch deletion
- preserve unrelated UI state
- restore controls after failure

Avoid one global boolean if it unnecessarily disables unrelated photo viewing.

---

# Error Handling

Use explicit exceptions or result objects consistently with the existing project.

Handle:

- invalid Catch ID
- invalid photo ID
- photo limit exceeded
- source file missing
- image decode failure
- image encode failure
- destination directory creation failure
- file write failure
- file delete failure
- Drift insert failure
- Drift delete failure
- permission denial
- picker cancellation

User-facing messages shall be clear and non-technical.

Do not expose raw file paths or exception strings directly to users.

---

# Logging

Use the project’s existing logging approach if one exists.

Useful diagnostic context:

- operation name
- Catch ID
- CatchPhoto ID
- failure stage

Do not log image bytes.

Avoid logging full external source paths unless required for local debugging and consistent with project rules.

---

# Testing

## Domain Tests

Cover:

- valid CatchPhoto creation
- empty ID rejection where enforced
- empty Catch ID rejection where enforced
- empty relative path rejection where enforced
- negative sort order rejection
- PendingCatchPhoto source path behavior

---

## Database Tests

Cover:

- schema migration succeeds
- existing Catch data remains
- CatchPhoto row can be inserted
- CatchPhoto row maps correctly
- foreign key rejects invalid Catch ID
- Catch deletion cascades CatchPhoto rows
- ordered Catch photo query
- empty result

---

## Storage Tests

Use a temporary directory through dependency injection or configurable storage root.

Cover:

- directory creation
- relative path generation
- image decoding
- image resizing
- no upscaling
- JPEG encoding
- final file creation
- temporary file cleanup
- resolving relative path
- deleting existing file
- deleting missing file
- Catch directory cleanup
- corrupt source image
- missing source image
- write failure where practical

Do not depend on the real application documents directory in unit tests.

---

## Repository Tests

Cover:

- get photos for Catch
- ordered result
- add one photo
- add multiple photos
- stable unique IDs
- correct Catch association
- next sort order
- maximum of 5
- reject sixth photo
- empty addMany input
- partial success
- cleanup file when database insert fails
- no database row when file processing fails
- delete existing photo
- delete missing photo row
- delete row with already missing file
- preserve row when genuine file deletion fails
- delete all photos for Catch
- reject empty Catch ID
- reject empty photo ID

---

## Add Catch Widget Tests

Cover:

- no photos initially
- open source selection
- camera selection
- gallery selection
- multiple gallery photos
- picker cancellation
- permission denial
- temporary preview
- remove temporary photo
- open temporary photo viewer
- maximum photo count
- add action disabled at limit
- validation failure preserves photos
- Catch save failure preserves photos
- Catch save success persists photos
- Catch save success with no photos
- partial photo failure result
- duplicate Save prevention
- duplicate picker prevention

Mock picker and repository behavior.

Do not launch a real camera in widget tests.

---

## Edit Catch Widget Tests

Cover:

- photo loading
- empty photo list
- existing photos displayed
- pending photo addition
- combined maximum limit
- remove pending photo
- persistent delete confirmation
- persistent delete cancellation
- persistent delete success
- persistent delete failure
- missing file placeholder
- corrupt file placeholder
- open viewer
- Catch update failure preserves photos
- Catch update success adds pending photos
- partial photo failure
- duplicate persistent delete prevention
- duplicate Save prevention

---

## Viewer Tests

Cover:

- opens selected index
- displays one photo
- navigates multiple photos
- closes correctly
- missing file placeholder
- corrupt file placeholder
- zoom widget exists where practical

---

## Catch Deletion Tests

Cover:

- Catch with no photos
- Catch with one photo
- Catch with multiple photos
- files removed
- CatchPhoto rows removed
- Catch removed
- missing photo file does not block deletion
- genuine cleanup failure keeps Catch
- duplicate delete prevention

---

# Platform Testing

Physical Android testing is required.

Test:

- camera capture
- gallery single selection
- gallery multiple selection
- permission grant
- permission denial
- picker cancellation
- five-photo limit
- image orientation
- large camera image processing
- app restart persistence
- photo deletion
- Catch deletion cleanup
- full-screen viewer
- missing file placeholder where manually reproducible
- small screen layout
- keyboard behavior in Add and Edit Catch

If iOS is currently supported by the project, verify required usage-description configuration even if physical iOS testing is not available.

---

# Platform Configuration

Update Android configuration only as required by selected packages.

Update iOS configuration only as required by selected packages.

Document:

- permissions added
- usage-description keys added
- minimum SDK changes
- platform-specific behavior

Do not add legacy storage permissions unless genuinely required.

---

# Expected Files To Create

Expected new files include:

```text
lib/features/catch_photos/domain/catch_photo.dart
lib/features/catch_photos/domain/pending_catch_photo.dart
lib/features/catch_photos/data/local/catch_photos_table.dart
lib/features/catch_photos/data/catch_photo_mapper.dart
lib/features/catch_photos/data/catch_photo_repository.dart
lib/features/catch_photos/data/storage/catch_photo_storage.dart
lib/features/catch_photos/presentation/widgets/catch_photo_picker.dart
lib/features/catch_photos/presentation/widgets/catch_photo_preview_list.dart
lib/features/catch_photos/presentation/widgets/catch_photo_thumbnail.dart
lib/features/catch_photos/presentation/widgets/catch_photo_viewer.dart
```

Test files shall mirror the final production structure.

Exact widget file count may be reduced when combining small cohesive widgets improves clarity.

---

# Expected Files To Modify

Expected areas:

```text
pubspec.yaml
lib/core/database/app_database.dart
lib/features/catches/presentation/widgets/add_catch_bottom_sheet.dart
lib/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart
repository provider configuration
Android platform configuration
iOS platform configuration
database tests
Catch widget tests
```

Modify generated Drift files only through code generation.

---

# Implementation Notes

- Inspect the current repository before implementation.
- Follow current naming and import conventions.
- Reuse existing Bottom Sheet result patterns.
- Reuse existing error-message and SnackBar coordination.
- Preserve current Catch parsing and validation behavior.
- Preserve the existing keyboard and small-screen fixes.
- Keep photo-specific code out of Catch domain models.
- Do not add `List<CatchPhoto>` to the Catch domain model.
- Do not store image data in Drift.
- Do not persist picker source paths.
- Do not create permanent files before Catch creation.
- Do not introduce repository interfaces.
- Do not introduce a generic file-storage abstraction.
- Do not introduce a service or use-case layer.
- Do not introduce reactive streams.
- Do not modify unrelated features.
- Do not silently repair or delete broken photo records.
- Prefer private helpers for focused implementation details.
- Keep public APIs small.

---

# Validation

Run code generation using the project’s established command.

Run:

```bash
dart format .
```

Run:

```bash
flutter analyze
```

Run:

```bash
flutter test
```

All must pass.

Review generated Drift changes.

Confirm the schema version and migration are correct.

---

# Documentation

After successful implementation, update:

```text
docs/project-status.md
```

Include:

- Catch Photos implementation status
- schema migration status
- new dependencies
- physical testing status

Update README only if its current feature summary requires it.

Do not modify MFS-013 or TD-013 after implementation merely to match deviations.

Report deviations explicitly and obtain approval when required.

---

# Deliverables

Report:

1. Files created
2. Files modified
3. Dependencies added
4. Platform configuration changes
5. Domain model added
6. Drift table added
7. Schema version change
8. Migration implementation
9. Repository methods added
10. Storage implementation
11. Image processing parameters
12. Add Catch integration
13. Edit Catch integration
14. Catch deletion cleanup
15. Viewer implementation
16. Error handling
17. Tests added
18. `dart format` result
19. `flutter analyze` result
20. `flutter test` result
21. Number of passing tests
22. Generated files changed
23. Physical Android test status
24. Any deviations from MFS-013
25. Any deviations from TD-013

Do not commit.

---

# Definition of Done

The feature is considered complete when:

- The implementation satisfies all requirements in MFS-013.
- The implementation follows TD-013.
- Users can add photos from camera.
- Users can add photos from gallery.
- Multiple photos are supported.
- A Catch cannot contain more than 5 photos.
- Photos can be selected during Add Catch.
- Temporary photos do not create persistent records before Catch creation.
- Persistent photos are stored in application-owned storage.
- Only relative paths are stored in Drift.
- Image data is not stored in SQLite.
- Photos remain available after application restart.
- Existing photos are shown in Edit Catch.
- Pending photos are preserved after validation and save failures.
- Persistent photos can be deleted with confirmation.
- Deleting a photo removes its application-owned file.
- Deleting a Catch cleans up associated photo files.
- Missing or corrupt files do not crash the application.
- Partial photo failures do not delete a successfully saved Catch.
- Camera and gallery cancellation preserve form state.
- Permission denial preserves form state.
- The database migration succeeds without losing existing data.
- No unnecessary architectural layers were introduced.
- No repository interfaces were introduced.
- No DAO, service, or use-case layers were introduced.
- No reactive database streams were introduced.
- All generated files are up to date.
- `dart format .` completes successfully.
- `flutter analyze` reports no issues.
- `flutter test` passes.
- Physical Android testing has been completed successfully.
- Architecture review has been completed.
- Code review has been completed.
- Documentation has been updated.
- The feature is ready to be committed.