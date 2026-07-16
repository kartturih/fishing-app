import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
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

class FishingSpotDetailsBottomSheet extends StatefulWidget {
  const FishingSpotDetailsBottomSheet({super.key, required this.fishingSpot});

  final FishingSpot fishingSpot;

  static Future<FishingSpotDetailsResult?> show(
    BuildContext context,
    FishingSpot fishingSpot,
  ) {
    return showModalBottomSheet<FishingSpotDetailsResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          FishingSpotDetailsBottomSheet(fishingSpot: fishingSpot),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _isEditing ? _editingContent() : _detailsContent(),
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
      OutlinedButton(
        onPressed: _confirmDelete,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        child: const Text('Delete'),
      ),
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
}
