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
import 'package:fishing_app/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

/// Read-only Catch Details screen shown between the Catch list and Edit
/// Catch.
///
/// Pushed as a normal full-screen page (like [CatchPhotoViewer]) rather than
/// a modal Bottom Sheet: MFS-014 requires a Material 3 AppBar with a Back
/// button and an overflow menu, which no modal Bottom Sheet in this app has,
/// and pushing a page keeps the Catch list's Bottom Sheet open underneath so
/// Back/Android-back naturally land on it again. See MFS-014 / TD-014.
///
/// `lure` and `notes` are part of MFS-014's read-only field list but are
/// intentionally not displayed here: `Catch` has never captured either
/// field (no column, no input in Add/Edit Catch), so showing them would
/// require a domain/schema change that is out of scope for this feature.
class CatchDetailsPage extends StatefulWidget {
  const CatchDetailsPage({
    super.key,
    required this.fishingSpot,
    required this.catchModel,
    required this.catchRepository,
    required this.catchPhotoRepository,
  });

  final FishingSpot fishingSpot;
  final Catch catchModel;
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;

  /// Pushes Catch Details as a normal [MaterialPageRoute].
  static Future<void> open(
    BuildContext context, {
    required FishingSpot fishingSpot,
    required Catch catchModel,
    required CatchRepository catchRepository,
    required CatchPhotoRepository catchPhotoRepository,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CatchDetailsPage(
          fishingSpot: fishingSpot,
          catchModel: catchModel,
          catchRepository: catchRepository,
          catchPhotoRepository: catchPhotoRepository,
        ),
      ),
    );
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadPhotos());
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

  Future<void> _openEdit() async {
    final result = await EditCatchBottomSheet.show(
      context,
      widget.fishingSpot,
      _catchModel,
      widget.catchRepository,
      widget.catchPhotoRepository,
    );

    if (!mounted || result == null) {
      return;
    }

    switch (result) {
      case CatchUpdated(:final catchModel, :final hasPhotoFailures):
        setState(() => _catchModel = catchModel);
        unawaited(_loadPhotos());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasPhotoFailures
                  ? 'Saalis päivitetty, mutta osaa kuvista ei voitu lisätä.'
                  : 'Saalis päivitetty',
            ),
          ),
        );
      case CatchDeleted():
        // The delete itself (including photo-file cleanup) already happened
        // inside EditCatchBottomSheet; this screen just leaves.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saalis poistettu')));
        Navigator.of(context).pop();
    }
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
      Navigator.of(context).pop();
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
    return Scaffold(
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
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
              _buildInfoRow('Kalalaji', _catchModel.species.finnishName),
              if (_catchModel.weightGrams != null)
                _buildInfoRow(
                  'Paino',
                  formatCatchWeight(_catchModel.weightGrams!),
                ),
              if (_catchModel.lengthMillimeters != null)
                _buildInfoRow(
                  'Pituus',
                  formatCatchLength(_catchModel.lengthMillimeters!),
                ),
              _buildInfoRow(
                'Päivämäärä',
                formatCatchDate(_catchModel.caughtAt),
              ),
              _buildInfoRow(
                'Kellonaika',
                formatCatchTime(_catchModel.caughtAt),
              ),
            ],
          ),
        ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
