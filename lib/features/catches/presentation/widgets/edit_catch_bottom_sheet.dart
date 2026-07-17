import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
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
  const CatchUpdated(this.catchModel);

  final Catch catchModel;
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
  });

  final FishingSpot fishingSpot;
  final Catch catchModel;
  final CatchRepository catchRepository;

  static Future<EditCatchResult?> show(
    BuildContext context,
    FishingSpot fishingSpot,
    Catch catchModel,
    CatchRepository catchRepository,
  ) {
    return showModalBottomSheet<EditCatchResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => EditCatchBottomSheet(
        fishingSpot: fishingSpot,
        catchModel: catchModel,
        catchRepository: catchRepository,
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

  late FishSpecies? _selectedSpecies = widget.catchModel.species;
  late DateTime _selectedCaughtAt = widget.catchModel.caughtAt;
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get _isBusy => _isSaving || _isDeleting;

  @override
  void dispose() {
    _weightController.dispose();
    _lengthController.dispose();
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

    try {
      final updatedCatch = await widget.catchRepository.update(
        catchModel: widget.catchModel,
        species: species,
        caughtAt: _selectedCaughtAt,
        weightGrams: weightGrams,
        lengthMillimeters: lengthMillimeters,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(CatchUpdated(updatedCatch));
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
    }
  }

  Future<void> _confirmDelete() async {
    if (_isBusy) {
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('editCatchDeleteButton'),
                        onPressed: _isBusy ? null : _confirmDelete,
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
