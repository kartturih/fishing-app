import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/domain/catch_photo_limits.dart';
import 'package:fishing_app/features/catch_photos/domain/pending_catch_photo.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_picker.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_preview_list.dart';
import 'package:fishing_app/features/catch_photos/presentation/widgets/catch_photo_viewer.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/catch_notes_limits.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/widgets/assigned_lure_row.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_item.dart';
import 'package:fishing_app/features/personal_tackle_box/presentation/widgets/personal_tackle_box_page.dart';

sealed class AddCatchResult {
  const AddCatchResult();
}

final class CatchCreated extends AddCatchResult {
  const CatchCreated({
    required this.catchModel,
    required this.photoFailureCount,
  });

  final Catch catchModel;
  final int photoFailureCount;

  bool get hasPhotoFailures => photoFailureCount > 0;
}

class AddCatchBottomSheet extends StatefulWidget {
  const AddCatchBottomSheet({
    super.key,
    required this.fishingSpot,
    required this.catchRepository,
    required this.catchPhotoRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
  });

  final FishingSpot fishingSpot;
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;

  static Future<AddCatchResult?> show(
    BuildContext context,
    FishingSpot fishingSpot,
    CatchRepository catchRepository,
    CatchPhotoRepository catchPhotoRepository,
    PersonalTackleBoxRepository personalTackleBoxRepository,
    TackleBoxPhotoStorage personalTackleBoxPhotoStorage,
  ) {
    return showModalBottomSheet<AddCatchResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AddCatchBottomSheet(
        fishingSpot: fishingSpot,
        catchRepository: catchRepository,
        catchPhotoRepository: catchPhotoRepository,
        personalTackleBoxRepository: personalTackleBoxRepository,
        personalTackleBoxPhotoStorage: personalTackleBoxPhotoStorage,
      ),
    );
  }

  @override
  State<AddCatchBottomSheet> createState() => _AddCatchBottomSheetState();
}

class _AddCatchBottomSheetState extends State<AddCatchBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _notesController = TextEditingController();
  final _catchPhotoPicker = CatchPhotoPicker();

  FishSpecies? _selectedSpecies;
  late DateTime _selectedCaughtAt;
  bool _isSaving = false;
  bool _isPickingPhoto = false;
  final List<PendingCatchPhoto> _pendingPhotos = [];
  TackleBoxItem? _selectedLure;

  bool get _isBusy => _isSaving || _isPickingPhoto;

  @override
  void initState() {
    super.initState();
    _selectedCaughtAt = DateTime.now();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _lengthController.dispose();
    _notesController.dispose();
    super.dispose();
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

  Future<void> _addPhoto() async {
    if (_isBusy || _pendingPhotos.length >= maxCatchPhotos) {
      return;
    }

    final source = await showCatchPhotoSourceDialog(context);
    if (source == null || !mounted) {
      return;
    }

    setState(() => _isPickingPhoto = true);

    final remainingCapacity = maxCatchPhotos - _pendingPhotos.length;
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

  /// Pushes the Personal Tackle Box as a lure picker, reusing its existing
  /// grouped browsing screen unchanged (MFS-017/TD-017). Only lures already
  /// owned can be selected; the picker's own empty state offers a path to
  /// the Lure Catalog when the tackle box is empty.
  Future<void> _selectLure() async {
    if (_isSaving) {
      return;
    }
    final selected = await Navigator.of(context).push<TackleBoxItem>(
      MaterialPageRoute(
        builder: (context) => PersonalTackleBoxPage(
          repository: widget.personalTackleBoxRepository,
          photoStorage: widget.personalTackleBoxPhotoStorage,
          onSelect: (item) => Navigator.of(context).pop(item),
        ),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() => _selectedLure = selected);
  }

  void _removeLure() {
    setState(() => _selectedLure = null);
  }

  void _openViewer(int index) {
    final files = [
      for (final pendingPhoto in _pendingPhotos) File(pendingPhoto.sourcePath),
    ];
    CatchPhotoViewer.open(context, files: files, initialIndex: index);
  }

  Future<void> _submit() async {
    if (_isBusy) {
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

    final Catch createdCatch;
    try {
      createdCatch = await widget.catchRepository.create(
        fishingSpotId: widget.fishingSpot.id,
        species: species,
        caughtAt: _selectedCaughtAt,
        weightGrams: weightGrams,
        lengthMillimeters: lengthMillimeters,
        lureVariantId: _selectedLure?.catalogEntry.id,
        notes: _notesController.text,
      );
    } catch (error) {
      debugPrint('Failed to save catch: $error');
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
          catchId: createdCatch.id,
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
    Navigator.of(context).pop(
      CatchCreated(
        catchModel: createdCatch,
        photoFailureCount: photoFailureCount,
      ),
    );
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
                  onChanged: _isSaving
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
                        onPressed: _isSaving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(formatCatchDate(_selectedCaughtAt)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _pickTime,
                        icon: const Icon(Icons.access_time),
                        label: Text(formatCatchTime(_selectedCaughtAt)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _weightController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Paino (kg)'),
                  validator: validateCatchWeightInput,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _lengthController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Pituus (cm)'),
                  validator: validateCatchLengthInput,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Viehe', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                AssignedLureRow(
                  entry: _selectedLure?.catalogEntry,
                  onAssign: _isSaving ? null : _selectLure,
                  onChange: _isSaving ? null : _selectLure,
                  onRemove: _isSaving ? null : _removeLure,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Kuvat', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                CatchPhotoPreviewList(
                  existingPhotos: const [],
                  existingFiles: const {},
                  pendingPhotos: _pendingPhotos,
                  maxPhotos: maxCatchPhotos,
                  isAddEnabled: !_isBusy,
                  onAddPressed: _addPhoto,
                  onRemovePending: _removePendingPhoto,
                  onDeleteExisting: (_) {},
                  onOpenViewer: _openViewer,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Muistiinpanot',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  key: const Key('addCatchNotesField'),
                  controller: _notesController,
                  enabled: !_isSaving,
                  minLines: 3,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: maxCatchNotesLength,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: validateCatchNotesInput,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Peruuta'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isBusy ? null : _submit,
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

// The following are shared helpers for the catch forms: decimal parsing
// (comma or period), canonical-unit conversion, validation messages, and
// date/time display. They live here (rather than a separate utility file)
// but are reused directly by EditCatchBottomSheet to avoid duplicating this
// logic.

double? parseCatchMeasurementInput(String rawValue) {
  return double.tryParse(rawValue.trim().replaceAll(',', '.'));
}

int kilogramsToGrams(double kilograms) => (kilograms * 1000).round();

int centimetersToMillimeters(double centimeters) => (centimeters * 10).round();

String? validateCatchWeightInput(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return null;
  }

  final parsed = parseCatchMeasurementInput(text);
  if (parsed == null || !parsed.isFinite) {
    return 'Syötä kelvollinen paino';
  }
  if (parsed <= 0 || kilogramsToGrams(parsed) <= 0) {
    return 'Painon täytyy olla suurempi kuin 0';
  }

  return null;
}

String? validateCatchLengthInput(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return null;
  }

  final parsed = parseCatchMeasurementInput(text);
  if (parsed == null || !parsed.isFinite) {
    return 'Syötä kelvollinen pituus';
  }
  if (parsed <= 0 || centimetersToMillimeters(parsed) <= 0) {
    return 'Pituuden täytyy olla suurempi kuin 0';
  }

  return null;
}

String? validateCatchNotesInput(String? value) {
  final text = value ?? '';
  if (text.length > maxCatchNotesLength) {
    return 'Muistiinpanot voivat olla enintään $maxCatchNotesLength merkkiä.';
  }
  return null;
}

String formatCatchDate(DateTime dateTime) =>
    '${dateTime.day}.${dateTime.month}.${dateTime.year}';

String formatCatchTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour.$minute';
}
