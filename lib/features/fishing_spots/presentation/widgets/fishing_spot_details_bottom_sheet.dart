import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

sealed class FishingSpotDetailsResult {
  const FishingSpotDetailsResult();
}

final class FishingSpotRenamed extends FishingSpotDetailsResult {
  const FishingSpotRenamed(this.name);

  final String name;
}

final class FishingSpotDeleted extends FishingSpotDetailsResult {
  const FishingSpotDeleted();
}

final class FishingSpotAddCatchRequested extends FishingSpotDetailsResult {
  const FishingSpotAddCatchRequested();
}

class FishingSpotDetailsBottomSheet extends StatefulWidget {
  const FishingSpotDetailsBottomSheet({
    super.key,
    required this.fishingSpot,
    required this.catchRepository,
  });

  final FishingSpot fishingSpot;
  final CatchRepository catchRepository;

  static Future<FishingSpotDetailsResult?> show(
    BuildContext context,
    FishingSpot fishingSpot,
    CatchRepository catchRepository,
  ) {
    return showModalBottomSheet<FishingSpotDetailsResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FishingSpotDetailsBottomSheet(
        fishingSpot: fishingSpot,
        catchRepository: catchRepository,
      ),
    );
  }

  @override
  State<FishingSpotDetailsBottomSheet> createState() =>
      _FishingSpotDetailsBottomSheetState();
}

class _FishingSpotDetailsBottomSheetState
    extends State<FishingSpotDetailsBottomSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.fishingSpot.name,
  );
  late final Future<List<Catch>> _catchesFuture = widget.catchRepository
      .getByFishingSpotId(widget.fishingSpot.id);

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    _nameController.text = widget.fishingSpot.name;
    setState(() => _isEditing = false);
  }

  void _submit() {
    if (_isSaving) {
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    Navigator.of(context).pop(FishingSpotRenamed(name));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Fishing Spot'),
        content: Text(
          'Delete "${widget.fishingSpot.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const FishingSpotDeleted());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _isEditing ? _editingContent() : _detailsContent(),
          ),
        ),
      ),
    );
  }

  List<Widget> _detailsContent() {
    return [
      Text(
        widget.fishingSpot.name,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton.tonal(
        onPressed: _startEditing,
        child: const Text('Edit Name'),
      ),
      const SizedBox(height: AppSpacing.sm),
      FilledButton.tonalIcon(
        onPressed: () =>
            Navigator.of(context).pop(const FishingSpotAddCatchRequested()),
        icon: const Icon(Icons.add),
        label: const Text('Lisää saalis'),
      ),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(
        onPressed: _confirmDelete,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        child: const Text('Delete'),
      ),
      const SizedBox(height: AppSpacing.lg),
      _buildCatchesSection(),
    ];
  }

  List<Widget> _editingContent() {
    return [
      Text('Edit Name', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _nameController,
        autofocus: true,
        enabled: !_isSaving,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _cancelEditing,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildCatchesSection() {
    return FutureBuilder<List<Catch>>(
      future: _catchesFuture,
      builder: (context, snapshot) {
        final Widget content;
        if (snapshot.connectionState != ConnectionState.done) {
          content = const Text('Loading...');
        } else if (snapshot.hasError) {
          content = const Text('Unable to load catches.');
        } else {
          final catches = snapshot.data ?? const <Catch>[];
          if (catches.isEmpty) {
            content = const Text('No catches yet.');
          } else {
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < catches.length; i++) ...[
                  if (i > 0) const Divider(),
                  _buildCatchRow(catches[i]),
                ],
              ],
            );
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text('Catches', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            content,
          ],
        );
      },
    );
  }

  Widget _buildCatchRow(Catch catchModel) {
    final measurementLine = _formatMeasurementLine(catchModel);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            catchModel.species.finnishName,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (measurementLine != null) Text(measurementLine),
          Text(
            _formatCaughtAt(catchModel.caughtAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

const _monthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String? _formatMeasurementLine(Catch catchModel) {
  final parts = [
    if (catchModel.weightGrams != null) _formatWeight(catchModel.weightGrams!),
    if (catchModel.lengthMillimeters != null)
      _formatLength(catchModel.lengthMillimeters!),
  ];

  return parts.isEmpty ? null : parts.join(' • ');
}

String _formatWeight(int grams) {
  if (grams < 1000) {
    return '$grams g';
  }
  return '${_formatTrimmedDecimal(grams / 1000, 3)} kg';
}

String _formatLength(int millimeters) {
  return '${_formatTrimmedDecimal(millimeters / 10, 1)} cm';
}

String _formatTrimmedDecimal(double value, int maxDecimals) {
  var text = value.toStringAsFixed(maxDecimals);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}

String _formatCaughtAt(DateTime dateTime) {
  final day = dateTime.day.toString();
  final month = _monthAbbreviations[dateTime.month - 1];
  final year = dateTime.year.toString();
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$day $month $year $hour:$minute';
}
