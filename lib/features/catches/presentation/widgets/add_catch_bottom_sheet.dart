import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

class AddCatchBottomSheet extends StatefulWidget {
  const AddCatchBottomSheet({
    super.key,
    required this.fishingSpot,
    required this.catchRepository,
  });

  final FishingSpot fishingSpot;
  final CatchRepository catchRepository;

  static Future<Catch?> show(
    BuildContext context,
    FishingSpot fishingSpot,
    CatchRepository catchRepository,
  ) {
    return showModalBottomSheet<Catch>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AddCatchBottomSheet(
        fishingSpot: fishingSpot,
        catchRepository: catchRepository,
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

  FishSpecies? _selectedSpecies;
  late DateTime _selectedCaughtAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCaughtAt = DateTime.now();
  }

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
    if (_isSaving) {
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
      final createdCatch = await widget.catchRepository.create(
        fishingSpotId: widget.fishingSpot.id,
        species: species,
        caughtAt: _selectedCaughtAt,
        weightGrams: weightGrams,
        lengthMillimeters: lengthMillimeters,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(createdCatch);
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
    }
  }

  String _formatDate(DateTime dateTime) =>
      '${dateTime.day}.${dateTime.month}.${dateTime.year}';

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour.$minute';
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
                  'Fishing Spot',
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
                  decoration: const InputDecoration(labelText: 'Species'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_formatDate(_selectedCaughtAt)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _pickTime,
                        icon: const Icon(Icons.access_time),
                        label: Text(_formatTime(_selectedCaughtAt)),
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
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  validator: validateCatchWeightInput,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _lengthController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Length (cm)'),
                  validator: validateCatchLengthInput,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save'),
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

// The following are file-local helpers for the add-catch form: decimal
// parsing (comma or period), canonical-unit conversion, and validation
// messages. They are not a shared/reusable utility and are only used here.

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
