import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_details_page.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_list_item.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';

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
    required this.catchPhotoRepository,
    required this.lureCatalogRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
  });

  final FishingSpot fishingSpot;
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;
  final LureCatalogRepository lureCatalogRepository;
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;

  static Future<FishingSpotDetailsResult?> show(
    BuildContext context,
    FishingSpot fishingSpot,
    CatchRepository catchRepository,
    CatchPhotoRepository catchPhotoRepository,
    LureCatalogRepository lureCatalogRepository,
    PersonalTackleBoxRepository personalTackleBoxRepository,
    TackleBoxPhotoStorage personalTackleBoxPhotoStorage,
  ) {
    return showModalBottomSheet<FishingSpotDetailsResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FishingSpotDetailsBottomSheet(
        fishingSpot: fishingSpot,
        catchRepository: catchRepository,
        catchPhotoRepository: catchPhotoRepository,
        lureCatalogRepository: lureCatalogRepository,
        personalTackleBoxRepository: personalTackleBoxRepository,
        personalTackleBoxPhotoStorage: personalTackleBoxPhotoStorage,
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
  late Future<List<Catch>> _catchesFuture = widget.catchRepository
      .getByFishingSpotId(widget.fishingSpot.id);

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _openCatchDetails(Catch catchModel) async {
    await CatchDetailsPage.open(
      context,
      fishingSpot: widget.fishingSpot,
      catchModel: catchModel,
      catchRepository: widget.catchRepository,
      catchPhotoRepository: widget.catchPhotoRepository,
      lureCatalogRepository: widget.lureCatalogRepository,
      personalTackleBoxRepository: widget.personalTackleBoxRepository,
      personalTackleBoxPhotoStorage: widget.personalTackleBoxPhotoStorage,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _catchesFuture = widget.catchRepository.getByFishingSpotId(
        widget.fishingSpot.id,
      );
    });
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
        title: const Text('Poista kalastuspaikka'),
        content: Text(
          'Poistetaanko "${widget.fishingSpot.name}"? Toimintoa ei voi perua.',
        ),
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
        child: const Text('Muokkaa nimeä'),
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
        child: const Text('Poista'),
      ),
      const SizedBox(height: AppSpacing.lg),
      _buildCatchesSection(),
    ];
  }

  List<Widget> _editingContent() {
    return [
      Text('Muokkaa nimeä', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _nameController,
        autofocus: true,
        enabled: !_isSaving,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Nimi'),
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _cancelEditing,
              child: const Text('Peruuta'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: const Text('Tallenna'),
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
          content = const Text('Ladataan...');
        } else if (snapshot.hasError) {
          content = const Text('Saaliiden lataaminen epäonnistui.');
        } else {
          final catches = snapshot.data ?? const <Catch>[];
          if (catches.isEmpty) {
            content = const Text('Ei vielä saaliita.');
          } else {
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < catches.length; i++) ...[
                  if (i > 0) const Divider(),
                  CatchListItem(
                    key: ValueKey(catches[i].id),
                    catchModel: catches[i],
                    catchPhotoRepository: widget.catchPhotoRepository,
                    onTap: () => _openCatchDetails(catches[i]),
                  ),
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
            Text('Saaliit', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            content,
          ],
        );
      },
    );
  }
}
