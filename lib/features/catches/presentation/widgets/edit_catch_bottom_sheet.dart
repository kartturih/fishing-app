import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/domain/catch_photo.dart';
import 'package:fishing_app/features/catch_photos/domain/catch_photo_limits.dart';
import 'package:fishing_app/features/catch_photos/domain/pending_catch_photo.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_picker.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_preview_list.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_viewer.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

sealed class EditCatchResult {
  const EditCatchResult();
}

final class CatchUpdated extends EditCatchResult {
  const CatchUpdated(this.catchModel, {this.photoFailureCount = 0});

  final Catch catchModel;
  final int photoFailureCount;

  bool get hasPhotoFailures => photoFailureCount > 0;
}

final class CatchDeleted extends EditCatchResult {
  const CatchDeleted(this.catchId);

  final String catchId;
}

class EditCatchBottomSheet extends StatefulWidget {
  const EditCatchBottomSheet({
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

  static Future<EditCatchResult?> show(
    BuildContext context,
    FishingSpot fishingSpot,
    Catch catchModel,
    CatchRepository catchRepository,
    CatchPhotoRepository catchPhotoRepository,
  ) {
    return showModalBottomSheet<EditCatchResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => EditCatchBottomSheet(
        fishingSpot: fishingSpot,
        catchModel: catchModel,
        catchRepository: catchRepository,
        catchPhotoRepository: catchPhotoRepository,
      ),
    );
  }

  @override
  State<EditCatchBottomSheet> createState() => _EditCatchBottomSheetState();
}

class _EditCatchBottomSheetState extends State<EditCatchBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _weightController = TextEditingController(
    text: _initialMeasurementText(widget.catchModel.weightGrams, 1000, 3),
  );
  late final _lengthController = TextEditingController(
    text: _initialMeasurementText(widget.catchModel.lengthMillimeters, 10, 1),
  );
  final _catchPhotoPicker = CatchPhotoPicker();

  late FishSpecies? _selectedSpecies = widget.catchModel.species;
  late DateTime _selectedCaughtAt = widget.catchModel.caughtAt;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isPickingPhoto = false;

  bool _isLoadingPhotos = true;
  String? _photoLoadError;
  List<CatchPhoto> _existingPhotos = [];
  Map<String, File> _existingFiles = {};
  final List<PendingCatchPhoto> _pendingPhotos = [];
  final Set<String> _deletingPhotoIds = {};

  bool get _isBusy => _isSaving || _isDeleting;
  bool get _isPhotoBusy => _isPickingPhoto || _deletingPhotoIds.isNotEmpty;

  /// True while any Catch-level or photo-level operation is in flight.
  ///
  /// Catch Save/Delete must not start while a photo pick or a persistent
  /// photo deletion is running, and vice versa (the latter is already
  /// enforced by [_isBusy] checks in [_addPhoto]/[_deleteExistingPhoto]).
  bool get _isAnyOperationBusy => _isBusy || _isPhotoBusy;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPhotos());
  }

  @override
  void dispose() {
    _weightController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoadingPhotos = true;
      _photoLoadError = null;
    });

    try {
      final photos = await widget.catchPhotoRepository.getByCatchId(
        widget.catchModel.id,
      );
      final files = <String, File>{};
      for (final photo in photos) {
        files[photo.id] = await widget.catchPhotoRepository.resolveFile(photo);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _existingPhotos = photos;
        _existingFiles = files;
        _isLoadingPhotos = false;
      });
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

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedCaughtAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCaughtAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        _selectedCaughtAt.hour,
        _selectedCaughtAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedCaughtAt),
    );
    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCaughtAt = DateTime(
        _selectedCaughtAt.year,
        _selectedCaughtAt.month,
        _selectedCaughtAt.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  int get _totalPhotoCount => _existingPhotos.length + _pendingPhotos.length;

  Future<void> _addPhoto() async {
    if (_isBusy || _isPhotoBusy || _totalPhotoCount >= maxCatchPhotos) {
      return;
    }

    final source = await showCatchPhotoSourceDialog(context);
    if (source == null || !mounted) {
      return;
    }

    setState(() => _isPickingPhoto = true);

    final remainingCapacity = maxCatchPhotos - _totalPhotoCount;
    final outcome = switch (source) {
      CatchPhotoSource.camera => await _catchPhotoPicker.pickFromCamera(),
      CatchPhotoSource.gallery => await _catchPhotoPicker.pickFromGallery(
        remainingCapacity: remainingCapacity,
      ),
    };

    if (!mounted) {
      return;
    }

    switch (outcome) {
      case CatchPhotosSelected(:final photos, :final exceededCapacity):
        setState(() {
          _pendingPhotos.addAll(photos);
          _isPickingPhoto = false;
        });
        if (exceededCapacity) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Osa valituista kuvista jätettiin pois, koska kuvien '
                'enimmäismäärä on 5.',
              ),
            ),
          );
        }
      case CatchPhotoPickCancelled():
        setState(() => _isPickingPhoto = false);
      case CatchPhotoPickPermissionDenied():
        setState(() => _isPickingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kameran tai kuvien käyttöoikeus puuttuu.'),
          ),
        );
      case CatchPhotoPickFailed():
        setState(() => _isPickingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kuvan lisääminen epäonnistui.')),
        );
    }
  }

  void _removePendingPhoto(PendingCatchPhoto pendingPhoto) {
    setState(() => _pendingPhotos.remove(pendingPhoto));
  }

  Future<void> _deleteExistingPhoto(CatchPhoto photo) async {
    if (_isBusy || _isPhotoBusy) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poistetaanko kuva?'),
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

    setState(() => _deletingPhotoIds.add(photo.id));

    try {
      await widget.catchPhotoRepository.delete(photo.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _existingPhotos = _existingPhotos
            .where((existing) => existing.id != photo.id)
            .toList();
        _existingFiles = {..._existingFiles}..remove(photo.id);
        _deletingPhotoIds.remove(photo.id);
      });
    } catch (error) {
      debugPrint('Failed to delete catch photo: $error');
      if (!mounted) {
        return;
      }
      setState(() => _deletingPhotoIds.remove(photo.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kuvan poistaminen epäonnistui. Yritä uudelleen.'),
        ),
      );
    }
  }

  void _openViewer(int index) {
    final files = [
      for (final photo in _existingPhotos) ?_existingFiles[photo.id],
      for (final pendingPhoto in _pendingPhotos) File(pendingPhoto.sourcePath),
    ];
    CatchPhotoViewer.open(context, files: files, initialIndex: index);
  }

  Future<void> _submit() async {
    if (_isAnyOperationBusy) {
      return;
    }

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final species = _selectedSpecies;
    if (species == null) {
      return;
    }

    setState(() => _isSaving = true);

    final weightText = _weightController.text.trim();
    final lengthText = _lengthController.text.trim();

    final weightGrams = weightText.isEmpty
        ? null
        : kilogramsToGrams(parseCatchMeasurementInput(weightText)!);
    final lengthMillimeters = lengthText.isEmpty
        ? null
        : centimetersToMillimeters(parseCatchMeasurementInput(lengthText)!);

    final Catch updatedCatch;
    try {
      updatedCatch = await widget.catchRepository.update(
        catchModel: widget.catchModel,
        species: species,
        caughtAt: _selectedCaughtAt,
        weightGrams: weightGrams,
        lengthMillimeters: lengthMillimeters,
      );
    } catch (error) {
      debugPrint('Failed to update catch: $error');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saaliin tallentaminen epäonnistui. Yritä uudelleen.',
            ),
          ),
        );
      }
      return;
    }

    var photoFailureCount = 0;
    if (_pendingPhotos.isNotEmpty) {
      try {
        final result = await widget.catchPhotoRepository.addMany(
          catchId: widget.catchModel.id,
          pendingPhotos: _pendingPhotos,
        );
        photoFailureCount = result.failedCount;
      } catch (error) {
        debugPrint('Failed to add catch photos: $error');
        photoFailureCount = _pendingPhotos.length;
      }
    }

    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pop(CatchUpdated(updatedCatch, photoFailureCount: photoFailureCount));
  }

  Future<void> _confirmDelete() async {
    if (_isAnyOperationBusy) {
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
      // Photo files cannot participate in the Drift transaction, so file
      // cleanup runs first: if it fails, the Catch (and its photo records)
      // are preserved for retry rather than deleting a Catch whose photo
      // files could not be removed. Only files are deleted here — the
      // CatchPhoto rows are left for the database's cascading foreign key to
      // remove once the Catch row itself is deleted below, so that if that
      // second step fails, the surviving rows correctly display as
      // missing-file placeholders instead of disappearing outright.
      await widget.catchPhotoRepository.deleteFilesForCatch(
        widget.catchModel.id,
      );
      await widget.catchRepository.delete(widget.catchModel.id);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(CatchDeleted(widget.catchModel.id));
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Kalastuspaikka',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.fishingSpot.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<FishSpecies>(
                  initialValue: _selectedSpecies,
                  items: [
                    for (final species in FishSpecies.values)
                      DropdownMenuItem(
                        value: species,
                        child: Text(species.finnishName),
                      ),
                  ],
                  onChanged: _isBusy
                      ? null
                      : (value) => setState(() => _selectedSpecies = value),
                  validator: (value) =>
                      value == null ? 'Valitse kalalaji' : null,
                  decoration: const InputDecoration(labelText: 'Kalalaji'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBusy ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(formatCatchDate(_selectedCaughtAt)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBusy ? null : _pickTime,
                        icon: const Icon(Icons.access_time),
                        label: Text(formatCatchTime(_selectedCaughtAt)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _weightController,
                  enabled: !_isBusy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Paino (kg)'),
                  validator: validateCatchWeightInput,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _lengthController,
                  enabled: !_isBusy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Pituus (cm)'),
                  validator: validateCatchLengthInput,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Kuvat', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                CatchPhotoPreviewList(
                  existingPhotos: _existingPhotos,
                  existingFiles: _existingFiles,
                  pendingPhotos: _pendingPhotos,
                  maxPhotos: maxCatchPhotos,
                  isLoading: _isLoadingPhotos,
                  errorMessage: _photoLoadError,
                  onRetry: _loadPhotos,
                  isAddEnabled: !_isBusy && !_isPhotoBusy,
                  deletingPhotoIds: _deletingPhotoIds,
                  onAddPressed: _addPhoto,
                  onRemovePending: _removePendingPhoto,
                  onDeleteExisting: _deleteExistingPhoto,
                  onOpenViewer: _openViewer,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('editCatchDeleteButton'),
                        onPressed: _isAnyOperationBusy ? null : _confirmDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        child: _isDeleting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Poista'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        key: const Key('editCatchSaveButton'),
                        onPressed: _isAnyOperationBusy ? null : _submit,
                        child: _isSaving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Tallenna'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// File-local helper for prefilling the editable weight/length text fields
// from stored canonical (grams/millimeters) values. Unlike the read-only
// display formatting in FishingSpotDetailsBottomSheet, weight is always
// shown in kg and length always in cm here, since that's the fixed editing
// unit for both fields.
String _initialMeasurementText(
  int? storedValue,
  int unitDivisor,
  int maxDecimals,
) {
  if (storedValue == null) {
    return '';
  }
  return _trimTrailingZeros(
    (storedValue / unitDivisor).toStringAsFixed(maxDecimals),
  );
}

String _trimTrailingZeros(String text) {
  if (!text.contains('.')) {
    return text;
  }
  final withoutTrailingZeros = text.replaceFirst(RegExp(r'0+$'), '');
  return withoutTrailingZeros.replaceFirst(RegExp(r'\.$'), '');
}
