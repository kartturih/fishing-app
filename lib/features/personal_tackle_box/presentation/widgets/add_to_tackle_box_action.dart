import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/pending_tackle_box_photo.dart';
import 'package:fishing_app/features/personal_tackle_box/presentation/widgets/tackle_box_photo_picker.dart';

/// The "Add to Tackle Box" action, meant to be built into `LureDetailsPage`'s
/// optional `actionsBuilder` (see TD-016 Navigation) — `lure_catalog` never
/// imports this file itself.
///
/// On [initState], queries [PersonalTackleBoxRepository.isOwned] to decide
/// its own state: already-owned renders disabled, satisfying MFS-016 FR-6's
/// "reflect existing ownership state" requirement without any change to the
/// Lure Catalog screen itself. See MFS-016 / TD-016.
class AddToTackleBoxAction extends StatefulWidget {
  const AddToTackleBoxAction({
    super.key,
    required this.catalogEntry,
    required this.repository,
    this.photoPicker,
  });

  final LureCatalogEntry catalogEntry;
  final PersonalTackleBoxRepository repository;

  /// Injectable for tests; production code uses the default.
  final TackleBoxPhotoPicker? photoPicker;

  @override
  State<AddToTackleBoxAction> createState() => _AddToTackleBoxActionState();
}

class _AddToTackleBoxActionState extends State<AddToTackleBoxAction> {
  late final TackleBoxPhotoPicker _photoPicker =
      widget.photoPicker ?? TackleBoxPhotoPicker();

  bool _isLoadingOwnedState = true;
  bool _isOwned = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOwnedState());
  }

  Future<void> _loadOwnedState() async {
    try {
      final isOwned = await widget.repository.isOwned(widget.catalogEntry.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _isOwned = isOwned;
        _isLoadingOwnedState = false;
      });
    } catch (error) {
      debugPrint('Failed to load tackle box ownership state: $error');
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingOwnedState = false);
    }
  }

  Future<void> _onAddPressed() async {
    if (_isBusy || _isOwned) {
      return;
    }

    final source = await showTackleBoxPhotoSourceDialog(context);
    if (!mounted) {
      return;
    }

    PendingTackleBoxPhoto? pendingPhoto;
    if (source != null) {
      final outcome = source == TackleBoxPhotoSource.camera
          ? await _photoPicker.pickFromCamera()
          : await _photoPicker.pickFromGallery();
      if (!mounted) {
        return;
      }

      switch (outcome) {
        case TackleBoxPhotoSelected(:final photo):
          pendingPhoto = photo;
        case TackleBoxPhotoPickCancelled():
          // The user backed out of the native picker: no state change, the
          // action remains available to try again.
          return;
        case TackleBoxPhotoPickPermissionDenied():
          _showSnackBar(
            'Kameran tai galleriakäyttöoikeus evätty. Lisätään ilman kuvaa.',
          );
        case TackleBoxPhotoPickFailed():
          _showSnackBar(
            'Kuvan valitseminen epäonnistui. Lisätään ilman kuvaa.',
          );
      }
    }

    await _add(pendingPhoto);
  }

  Future<void> _add(PendingTackleBoxPhoto? pendingPhoto) async {
    setState(() => _isBusy = true);

    try {
      final result = await widget.repository.add(
        catalogEntry: widget.catalogEntry,
        pendingPhoto: pendingPhoto,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isOwned = true;
        _isBusy = false;
      });
      if (result.photoFailed) {
        _showPhotoFailedSnackBar(result.item.id);
      } else {
        _showSnackBar('Lisätty vieherasiaan.');
      }
    } catch (error) {
      debugPrint('Failed to add tackle box entry: $error');
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      _showSnackBar('Vieherasiaan lisääminen epäonnistui. Yritä uudelleen.');
    }
  }

  void _showPhotoFailedSnackBar(String tackleBoxEntryId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Lisätty vieherasiaan, mutta kuvan lisääminen epäonnistui.',
        ),
        action: SnackBarAction(
          label: 'Yritä uudelleen',
          onPressed: () => unawaited(_retryPhoto(tackleBoxEntryId)),
        ),
      ),
    );
  }

  /// The narrow, post-add-failure-only retry path described in TD-016 — the
  /// only place `PersonalTackleBoxRepository.attachPhoto` is ever called
  /// from. Not a general "replace photo" control.
  Future<void> _retryPhoto(String tackleBoxEntryId) async {
    final source = await showTackleBoxPhotoSourceDialog(context);
    if (!mounted || source == null) {
      return;
    }

    final outcome = source == TackleBoxPhotoSource.camera
        ? await _photoPicker.pickFromCamera()
        : await _photoPicker.pickFromGallery();
    if (!mounted || outcome is! TackleBoxPhotoSelected) {
      return;
    }

    try {
      await widget.repository.attachPhoto(
        tackleBoxEntryId: tackleBoxEntryId,
        pendingPhoto: outcome.photo,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Kuva lisätty.');
    } catch (error) {
      debugPrint('Failed to attach tackle box photo: $error');
      if (!mounted) {
        return;
      }
      _showSnackBar('Kuvan lisääminen epäonnistui.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingOwnedState) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_isOwned) {
      return const Padding(
        key: Key('tackleBoxAlreadyOwnedLabel'),
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Center(child: Text('Vieherasiassa')),
      );
    }

    return IconButton(
      key: const Key('addToTackleBoxButton'),
      icon: _isBusy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_box_outlined),
      tooltip: 'Lisää vieherasiaan',
      onPressed: _isBusy ? null : _onAddPressed,
    );
  }
}
