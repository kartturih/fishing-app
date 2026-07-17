# MFS-013 — Catch Photos

## Goal

Allow users to attach photos to a catch when creating a new catch or editing an existing catch.

Photos shall work fully offline and remain persistently associated with the correct catch.

---

## User Story

**As a fisherman**

I want to attach photos to my catches

So that I can preserve a visual record of the fish I have caught.

---

# Feature Ownership

Catch Photos shall be implemented as its own feature.

The feature is responsible for:

- photo management
- photo persistence
- photo storage lifecycle
- photo presentation

The Catch feature remains responsible for catch data and catch lifecycle.

---

# Functional Requirements

## 1. Photo Availability

A catch may contain:

- no photos
- one photo
- multiple photos

A single catch shall contain no more than 5 photos.

---

## 2. Add Catch Integration

The Add Catch bottom sheet shall allow the user to select photos before the catch is saved.

Selected photos shall be displayed in the form as local previews.

Before the catch has been saved, selected photos are temporary form data.

Temporary photos shall not create:

- CatchPhoto database records
- permanent application-owned photo files

---

## 3. Edit Catch Integration

The Edit Catch bottom sheet shall display photos currently attached to the catch.

The user shall be able to:

- view existing photos
- add new photos
- remove existing photos

The total number of photos shall not exceed 5.

---

## 4. Photo Sources

The user shall be able to add photos using:

- device camera
- device photo gallery

The user shall be able to choose the source when adding photos.

The exact picker implementation is defined in the Technical Design.

---

## 5. Gallery Selection

The gallery flow shall support selecting multiple photos when supported by the chosen platform implementation.

The application shall prevent selecting more photos than the remaining photo capacity.

---

## 6. Camera Capture

The camera flow shall allow the user to capture photos.

Captured photos shall appear as previews before being saved.

The user may repeat the camera flow until the photo limit is reached.

---

## 7. Photo Limit

When a catch contains 5 selected or stored photos:

- adding additional photos shall not be possible
- the UI shall clearly communicate that the maximum has been reached

The application shall enforce this limit independently of the UI.

---

## 8. Temporary Photo Selection

Photos selected while creating a new catch shall remain temporary until the user saves the catch.

Closing or canceling the Add Catch bottom sheet shall:

- discard temporary photos
- not create a Catch
- not create CatchPhoto records
- not leave permanent photo files behind

The application shall not create draft catches.

---

## 9. Save New Catch

When saving a new catch containing photos:

1. Validate catch data.
2. Create the Catch.
3. Obtain the persistent Catch ID.
4. Store selected photos.
5. Create CatchPhoto records.

The Catch shall always exist before persistent CatchPhoto records are created.

---

## 10. Catch Save Failure

If creating the Catch fails:

- the Add Catch bottom sheet remains open
- entered values are preserved
- selected temporary photos are preserved
- no CatchPhoto records are created
- no permanent photo files remain
- the user can retry

---

## 11. Photo Storage Failure

If photo storage fails after the Catch has been successfully created:

- the Catch shall remain saved
- successfully stored photos shall remain attached
- failed photos shall not create database records
- incomplete files shall not remain
- the user shall receive a clear message

Example:

Catch saved, but some photos could not be added.
The missing photos can be added later through Edit Catch.

---

## 12. Persistent Photo Identity

Each persistent CatchPhoto shall have a stable unique identifier.

The identifier shall not depend on:

- filename
- file path
- photo order
- Catch ID

The identifier shall allow future synchronization support.

---

## 13. Catch Association

Every CatchPhoto shall belong to exactly one Catch.

A CatchPhoto shall not exist without a valid Catch.

Photos cannot be moved between catches.

---

## 14. Photo Ordering

Photos shall have a stable display order.

New photos shall be added after existing photos.

Manual photo reordering is not included.

---

## 15. Application-Owned Storage

Persistent photo files shall be stored in application-owned storage.

The application shall not depend on:

- original gallery paths
- temporary camera files
- external file locations

Deleting or moving the original source image shall not affect stored Catch photos.

---

## 16. Stored Path

The database shall store only application-managed relative paths.

The database shall not store:

- absolute device paths
- original source paths
- image binary data

Images shall not be stored directly inside SQLite.

---

## 17. Photo Processing

Photos shall be processed before permanent storage.

Processing shall:

- reduce unnecessary file size
- maintain suitable visual quality
- preserve correct orientation

Exact resizing and compression parameters are defined in the Technical Design.

---

## 18. Photo Ownership

The application exclusively owns the lifecycle of persistent CatchPhoto files.

The application is responsible for:

- creating stored files
- tracking stored files
- deleting stored files
- cleaning up unused files

---

## 19. Photo Previews

The Add Catch and Edit Catch bottom sheets shall display photo previews.

Previews shall:

- have consistent sizing
- preserve aspect ratio
- support up to 5 photos
- indicate that the image can be opened

Separate persistent thumbnail files are not required.

---

## 20. Full-Screen Viewing

Selecting a photo preview shall open a full-screen photo viewer.

The viewer shall:

- display the selected image
- preserve aspect ratio
- allow closing
- allow navigating between photos

Pinch-to-zoom may be supported depending on the selected viewer implementation.

The viewer shall not be implemented as a nested bottom sheet.

---

## 21. Removing Temporary Photos

Temporary photos selected before saving shall be removable without confirmation.

Removing a temporary photo shall:

- remove the preview
- free a photo slot
- not affect the original source image

---

## 22. Removing Persistent Photos

Removing an existing Catch photo shall require confirmation.

Example:

Delete photo?

This action cannot be undone.
Cancel   Delete

Confirmed deletion shall remove:

- CatchPhoto database record
- application-owned photo file

---

## 23. Catch Deletion Cleanup

Deleting a Catch shall also clean up its associated photo files.

Database cascade deletion alone is not sufficient.

The application shall explicitly remove application-owned files.

---

## 24. Missing Photo Files

If a CatchPhoto record exists but the file is missing:

- the application shall not crash
- a placeholder shall be displayed
- the user can remove the broken photo entry

The database record shall not automatically be removed.

---

## 25. Corrupt Photo Files

If a stored photo cannot be displayed:

- the application shall not crash
- a placeholder shall be shown
- other photos remain available
- the user can remove the broken photo

---

## 26. Permissions

The application shall request only required permissions.

Permission handling shall support:

- camera access
- photo selection access

Denied permissions shall:

- not close the Catch form
- not remove entered data
- show a clear message
- allow continuing without photos

---

## 27. Offline Support

All photo functionality shall work without internet access.

The feature shall not require:

- cloud storage
- network access
- authentication
- remote URLs

---

## 28. Future Synchronization Compatibility

The local design shall allow future synchronization.

Future synchronization may add:

- remote identifiers
- upload state
- synchronization timestamps
- conflict handling

Cloud functionality is not implemented in this feature.

---

# Out of Scope

This feature does not include:

- cloud synchronization
- remote image storage
- photo sharing
- videos
- photo editing
- filters
- cropping controls
- captions
- notes
- EXIF display
- map extraction from image metadata
- manual photo reordering
- cover photos
- undo deletion
- automatic repair of missing files
- draft catches

---

# Acceptance Criteria

- A catch supports 0–5 photos.
- Photos can be added from camera.
- Photos can be added from gallery.
- Multiple photos are supported.
- Photo limit is enforced.
- Photos can be selected during Add Catch.
- Temporary photos do not create persistent data before saving.
- Catch is created before CatchPhoto records.
- Catch creation failure does not lose entered form data.
- Photo storage failure does not delete a successfully created catch.
- Successfully stored photos remain available after application restart.
- Photos are stored in application-owned storage.
- Database stores photo references, not image data.
- Photos remain associated with the correct catch.
- Existing photos can be viewed in Edit Catch.
- Existing photos can be removed.
- Deleted photos remove their stored files.
- Deleted catches clean up their associated photo files.
- Missing or corrupt files do not crash the application.
- Permission denial does not break catch creation or editing.
- Feature works fully offline.
- `flutter analyze` passes.
- All tests pass.