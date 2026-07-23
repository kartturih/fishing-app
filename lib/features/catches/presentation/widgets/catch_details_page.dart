import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_radius.dart';
import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/domain/catch_photo.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_viewer.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/catch_formatters.dart';
import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart';
import 'package:fishing_app/features/catches/presentation/widgets/assigned_lure_row.dart';
import 'package:fishing_app/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';

/// What happened to the catch during a Catch Details visit — the result
/// [CatchDetailsPage.open] resolves to once the page is popped, by whatever
/// means (overflow menu action, AppBar back button, or the system/gesture
/// back navigation). Mirrors [EditCatchResult]'s existing three-outcome
/// shape (MFS-014/MFS-017), so every caller gets an explicit, typed answer
/// instead of an implicit `void` that only means "control has returned."
sealed class CatchDetailsResult {
  const CatchDetailsResult();
}

/// Nothing about the catch changed during this visit.
final class CatchDetailsUnchanged extends CatchDetailsResult {
  const CatchDetailsUnchanged();
}

/// The catch was edited (fields and/or photos) during this visit, via
/// [EditCatchBottomSheet].
final class CatchDetailsUpdated extends CatchDetailsResult {
  const CatchDetailsUpdated(this.catchModel);

  final Catch catchModel;
}

/// The catch was deleted during this visit — by construction, this result
/// can only be produced once the deletion has already been awaited to
/// completion (see `_confirmDelete` and the `CatchDeleted` case in
/// `_openEdit`), never before.
final class CatchDetailsDeleted extends CatchDetailsResult {
  const CatchDetailsDeleted(this.catchId);

  final String catchId;
}

/// Read-only Catch Details screen shown between the Catch list and Edit
/// Catch.
///
/// Pushed as a normal full-screen page (like [CatchPhotoViewer]) rather than
/// a modal Bottom Sheet: MFS-014 requires a Material 3 AppBar with a Back
/// button and an overflow menu, which no modal Bottom Sheet in this app has,
/// and pushing a page keeps the Catch list's Bottom Sheet open underneath so
/// Back/Android-back naturally land on it again. See MFS-014 / TD-014.
///
/// `lure` is displayed — see MFS-017 / TD-017. `notes` is displayed as the
/// final section, when present — see MFS-023 / TD-023.
class CatchDetailsPage extends StatefulWidget {
  const CatchDetailsPage({
    super.key,
    required this.fishingSpot,
    required this.catchModel,
    required this.catchRepository,
    required this.catchPhotoRepository,
    required this.lureCatalogRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
    required this.waterBodyRepository,
  });

  final FishingSpot fishingSpot;
  final Catch catchModel;
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;
  final LureCatalogRepository lureCatalogRepository;

  /// Held only to forward to [EditCatchBottomSheet] when the user opens the
  /// editor from the overflow menu — this page never launches the lure
  /// picker itself (MFS-014's read-only principle, FR-10).
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;

  /// Resolves [fishingSpot]'s own water body for the location fields
  /// ("Vesistö"/"Kalastuspaikka"), reused unconditionally regardless of
  /// which screen opened Catch Details — this page never receives a
  /// [WaterBody] directly from its caller, so its behavior does not vary
  /// by navigation source.
  final WaterBodyRepository waterBodyRepository;

  /// Pushes Catch Details as a normal [MaterialPageRoute], resolving to a
  /// [CatchDetailsResult] once popped — see that type's own doc comment.
  static Future<CatchDetailsResult> open(
    BuildContext context, {
    required FishingSpot fishingSpot,
    required Catch catchModel,
    required CatchRepository catchRepository,
    required CatchPhotoRepository catchPhotoRepository,
    required LureCatalogRepository lureCatalogRepository,
    required PersonalTackleBoxRepository personalTackleBoxRepository,
    required TackleBoxPhotoStorage personalTackleBoxPhotoStorage,
    required WaterBodyRepository waterBodyRepository,
  }) {
    return Navigator.of(context)
        .push<CatchDetailsResult>(
          MaterialPageRoute<CatchDetailsResult>(
            builder: (context) => CatchDetailsPage(
              fishingSpot: fishingSpot,
              catchModel: catchModel,
              catchRepository: catchRepository,
              catchPhotoRepository: catchPhotoRepository,
              lureCatalogRepository: lureCatalogRepository,
              personalTackleBoxRepository: personalTackleBoxRepository,
              personalTackleBoxPhotoStorage: personalTackleBoxPhotoStorage,
              waterBodyRepository: waterBodyRepository,
            ),
          ),
        )
        // Navigator.push's Future is nullable in the general case; every
        // pop path in this page always supplies a result (see PopScope's
        // onPopInvokedWithResult below), so null only guards against a
        // route being removed by means outside this page's own control.
        .then((result) => result ?? const CatchDetailsUnchanged());
  }

  @override
  State<CatchDetailsPage> createState() => _CatchDetailsPageState();
}

enum _CatchDetailsMenuAction { edit, delete }

/// Soft, very dark neutral background behind the photo gallery so
/// letterboxing around a `BoxFit.contain` image reads as intentional rather
/// than a pure-black void.
const Color _galleryBackgroundColor = Color(0xFF1E1E1E);

class _CatchDetailsPageState extends State<CatchDetailsPage> {
  late Catch _catchModel = widget.catchModel;
  final PageController _photoPageController = PageController();

  bool _isLoadingPhotos = true;
  String? _photoLoadError;
  List<CatchPhoto> _photos = [];
  Map<String, File> _files = {};
  int _currentPhotoIndex = 0;
  bool _isDeleting = false;

  /// Whether [_catchModel] has been edited during this visit — tracked
  /// separately from [_catchModel] itself so the back-navigation result
  /// (see [_currentResult]) doesn't need to compare `Catch` instances for
  /// equality.
  bool _hasChanges = false;

  bool _isLoadingLure = true;
  LureCatalogEntry? _assignedLure;
  bool _isLureUnavailable = false;

  bool _isLoadingWaterBody = true;
  WaterBody? _waterBody;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPhotos());
    unawaited(_loadAssignedLure());
    unawaited(_loadWaterBody());
  }

  @override
  void dispose() {
    _photoPageController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoadingPhotos = true;
      _photoLoadError = null;
    });

    try {
      final photos = await widget.catchPhotoRepository.getByCatchId(
        _catchModel.id,
      );
      final files = <String, File>{};
      for (final photo in photos) {
        files[photo.id] = await widget.catchPhotoRepository.resolveFile(photo);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _photos = photos;
        _files = files;
        _isLoadingPhotos = false;
        _currentPhotoIndex = 0;
      });
      // A reload (e.g. after editing) can happen while the gallery is
      // already showing a later page; jump back to the first photo instead
      // of leaving the PageView on a now-stale page index.
      if (_photoPageController.hasClients) {
        _photoPageController.jumpToPage(0);
      }
    } catch (error) {
      debugPrint('Failed to load catch photos: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _photoLoadError = 'Kuvien lataaminen epäonnistui.';
        _isLoadingPhotos = false;
      });
    }
  }

  void _openViewer(int index) {
    final files = [for (final photo in _photos) ?_files[photo.id]];
    CatchPhotoViewer.open(context, files: files, initialIndex: index);
  }

  /// Resolves the catch's currently assigned lure (if any), independently
  /// of photo loading. Re-run after a successful edit, since the
  /// assignment may have changed. See MFS-017 / TD-017.
  Future<void> _loadAssignedLure() async {
    final lureVariantId = _catchModel.lureVariantId;
    if (lureVariantId == null) {
      setState(() {
        _isLoadingLure = false;
        _assignedLure = null;
        _isLureUnavailable = false;
      });
      return;
    }

    setState(() => _isLoadingLure = true);

    try {
      final entry = await widget.lureCatalogRepository.getEntryById(
        lureVariantId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _assignedLure = entry;
        _isLureUnavailable = entry == null;
        _isLoadingLure = false;
      });
    } catch (error) {
      debugPrint('Failed to resolve assigned lure: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _assignedLure = null;
        _isLureUnavailable = true;
        _isLoadingLure = false;
      });
    }
  }

  /// Resolves [FishingSpot.waterBodyId] to its [WaterBody] for the location
  /// fields — independently of photo/lure loading. `widget.fishingSpot`
  /// never changes during this page's lifetime (editing a catch never
  /// changes which fishing spot it belongs to), so this only needs to run
  /// once, in [initState].
  Future<void> _loadWaterBody() async {
    try {
      final waterBody = await widget.waterBodyRepository.getById(
        widget.fishingSpot.waterBodyId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _waterBody = waterBody;
        _isLoadingWaterBody = false;
      });
    } catch (error) {
      debugPrint('Failed to resolve water body: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _waterBody = null;
        _isLoadingWaterBody = false;
      });
    }
  }

  Future<void> _openEdit() async {
    final result = await EditCatchBottomSheet.show(
      context,
      widget.fishingSpot,
      _catchModel,
      widget.catchRepository,
      widget.catchPhotoRepository,
      widget.lureCatalogRepository,
      widget.personalTackleBoxRepository,
      widget.personalTackleBoxPhotoStorage,
    );

    if (!mounted || result == null) {
      return;
    }

    switch (result) {
      case CatchUpdated(:final catchModel, :final hasPhotoFailures):
        setState(() {
          _catchModel = catchModel;
          _hasChanges = true;
        });
        unawaited(_loadPhotos());
        unawaited(_loadAssignedLure());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasPhotoFailures
                  ? 'Saalis päivitetty, mutta osaa kuvista ei voitu lisätä.'
                  : 'Saalis päivitetty',
            ),
          ),
        );
      case CatchDeleted(:final catchId):
        // The delete itself (including photo-file cleanup) already happened
        // inside EditCatchBottomSheet, fully awaited before this result
        // existed at all — this screen just leaves.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saalis poistettu')));
        Navigator.of(context).pop(CatchDetailsDeleted(catchId));
    }
  }

  /// The result [CatchDetailsPage.open] should resolve to if the page is
  /// popped right now via back navigation (as opposed to the delete
  /// action, which always supplies its own [CatchDetailsDeleted] result
  /// directly — see [_confirmDelete]).
  CatchDetailsResult _currentResult() {
    return _hasChanges
        ? CatchDetailsUpdated(_catchModel)
        : const CatchDetailsUnchanged();
  }

  Future<void> _confirmDelete() async {
    if (_isDeleting) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poistetaanko saalis?'),
        content: const Text('Toimintoa ei voi perua.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Peruuta'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Poista'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);

    try {
      // Same ordering as EditCatchBottomSheet's own delete flow: photo file
      // cleanup runs before the Catch row so a failure here leaves the Catch
      // (and its photo rows) intact for retry instead of deleting a Catch
      // whose photo files could not be removed.
      await widget.catchPhotoRepository.deleteFilesForCatch(_catchModel.id);
      await widget.catchRepository.delete(_catchModel.id);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saalis poistettu')));
      Navigator.of(context).pop(CatchDetailsDeleted(_catchModel.id));
    } catch (error) {
      debugPrint('Failed to delete catch: $error');
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saaliin poistaminen epäonnistui. Yritä uudelleen.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<CatchDetailsResult>(
      // Always false: every exit — the AppBar back button, the system/
      // gesture back navigation, and this page's own explicit pop calls —
      // is handled uniformly in onPopInvokedWithResult below, so the
      // result passed back is always an explicit CatchDetailsResult,
      // never left to Navigator's default null. This also closes the race
      // that let an impatient back-tap during _confirmDelete's in-flight
      // delete pop the page before the deletion (and thus the caller's
      // unconditional reload) had actually happened: while _isDeleting is
      // true, a back-button/gesture pop attempt is simply ignored here —
      // the only way out during that window is _confirmDelete's own pop,
      // called after the deletion has been fully awaited.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isDeleting) {
          return;
        }
        Navigator.of(context).pop(_currentResult());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_catchModel.species.finnishName),
          actions: [
            PopupMenuButton<_CatchDetailsMenuAction>(
              key: const Key('catchDetailsMenuButton'),
              onSelected: (action) {
                switch (action) {
                  case _CatchDetailsMenuAction.edit:
                    unawaited(_openEdit());
                  case _CatchDetailsMenuAction.delete:
                    unawaited(_confirmDelete());
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _CatchDetailsMenuAction.edit,
                  child: Text('Muokkaa'),
                ),
                PopupMenuItem(
                  value: _CatchDetailsMenuAction.delete,
                  child: Text(
                    'Poista',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhotoGallery(),
                // The fish species is already the AppBar title — showing it
                // again here would be redundant.
                _buildFieldRow([
                  if (_catchModel.weightGrams != null)
                    _buildField(
                      'Paino',
                      formatCatchWeight(_catchModel.weightGrams!),
                    ),
                  if (_catchModel.lengthMillimeters != null)
                    _buildField(
                      'Pituus',
                      formatCatchLength(_catchModel.lengthMillimeters!),
                    ),
                ]),
                _buildFieldRow([
                  _buildField(
                    'Päivämäärä',
                    formatCatchDate(_catchModel.caughtAt),
                  ),
                  _buildField(
                    'Kellonaika',
                    formatCatchTime(_catchModel.caughtAt),
                  ),
                ]),
                _buildFieldRow([
                  _buildWaterBodyField(),
                  _buildField('Kalastuspaikka', widget.fishingSpot.name),
                ]),
                if (_catchModel.lureVariantId != null) _buildAssignedLureRow(),
                if (_catchModel.notes != null) _buildNotesRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaterBodyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vesistö', style: Theme.of(context).textTheme.labelMedium),
        _isLoadingWaterBody
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _waterBody?.name ?? 'Vesistöä ei löytynyt',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
      ],
    );
  }

  Widget _buildAssignedLureRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Viehe', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          _isLoadingLure
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : AssignedLureRow(
                  entry: _assignedLure,
                  isUnavailable: _isLureUnavailable,
                ),
        ],
      ),
    );
  }

  Widget _buildNotesRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Muistiinpanot', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            _catchModel.notes!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery() {
    if (_isLoadingPhotos) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: ColoredBox(
            color: _galleryBackgroundColor,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      );
    }

    final photoLoadError = _photoLoadError;
    if (photoLoadError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Text(
          photoLoadError,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (_photos.isEmpty) {
      // FR-8: no empty image container when there are no photos.
      return const SizedBox(height: AppSpacing.sm);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: ColoredBox(
            color: _galleryBackgroundColor,
            child: Stack(
              children: [
                PageView.builder(
                  key: const Key('catchDetailsPhotoGallery'),
                  controller: _photoPageController,
                  itemCount: _photos.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPhotoIndex = index),
                  itemBuilder: (context, index) => _buildGalleryPage(index),
                ),
                if (_photos.length > 1)
                  Positioned(
                    left: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: _buildPageIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryPage(int index) {
    final photo = _photos[index];
    final file = _files[photo.id];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openViewer(index),
      child: file == null
          ? _buildBrokenImagePlaceholder()
          : Image.file(
              file,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) =>
                  _buildBrokenImagePlaceholder(),
            ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _photos.length; i++)
          Container(
            key: ValueKey('catchDetailsPhotoDot-$i'),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: i == _currentPhotoIndex ? 10 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _currentPhotoIndex
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }

  Widget _buildBrokenImagePlaceholder() {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Lays out up to two fields ([_buildField]/[_buildWaterBodyField]
  /// results) side by side, each taking an equal share of the available
  /// width — a more compact use of horizontal space than one field per
  /// row. A single field still renders correctly (it simply takes the
  /// whole row); an empty list renders nothing, so an optional pair (e.g.
  /// Paino/Pituus when neither is set) can be omitted entirely without a
  /// stray gap.
  Widget _buildFieldRow(List<Widget> fields) {
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            Expanded(child: fields[i]),
          ],
        ],
      ),
    );
  }

  /// One label/value pair, meant to be placed inside [_buildFieldRow] —
  /// the value is capped to a single line with an ellipsis since it now
  /// shares its row with another field rather than having the full width
  /// to itself, which matters on narrow devices or with larger accessibility
  /// text scaling.
  Widget _buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
