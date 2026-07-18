import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_radius.dart';
import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_image.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_item.dart';

/// A thin presentation layer over an already-owned [TackleBoxItem] — not a
/// separate feature. In this milestone it is limited to exactly three
/// responsibilities: displaying resolved catalog details, displaying the
/// personal photo (when present), and providing the "Remove from Tackle
/// Box" action. Future capabilities such as replacing the photo, notes,
/// purchase information, or condition are explicitly out of scope. See
/// MFS-016 / TD-016.
class OwnedEntryDetailPage extends StatefulWidget {
  const OwnedEntryDetailPage({
    super.key,
    required this.item,
    required this.repository,
    required this.photoStorage,
  });

  final TackleBoxItem item;
  final PersonalTackleBoxRepository repository;
  final TackleBoxPhotoStorage photoStorage;

  @override
  State<OwnedEntryDetailPage> createState() => _OwnedEntryDetailPageState();
}

class _OwnedEntryDetailPageState extends State<OwnedEntryDetailPage> {
  bool _isRemoving = false;
  File? _photoFile;

  @override
  void initState() {
    super.initState();
    final relativePath = widget.item.personalPhotoRelativePath;
    if (relativePath != null) {
      unawaited(_resolvePhoto(relativePath));
    }
  }

  Future<void> _resolvePhoto(String relativePath) async {
    try {
      final file = await widget.photoStorage.resolve(relativePath);
      if (!mounted) {
        return;
      }
      setState(() => _photoFile = file);
    } catch (error) {
      // A missing/corrupt file falls back to the catalog image via
      // Image.file's own errorBuilder below; a resolution failure here just
      // means _photoFile stays null and the same fallback applies.
      debugPrint('Failed to resolve tackle box photo: $error');
    }
  }

  Future<void> _onRemovePressed() async {
    if (_isRemoving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poistetaanko vieherasiasta?'),
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

    setState(() => _isRemoving = true);
    try {
      await widget.repository.remove(widget.item.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Failed to remove tackle box entry: $error');
      if (!mounted) {
        return;
      }
      setState(() => _isRemoving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Poistaminen epäonnistui. Yritä uudelleen.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogEntry = widget.item.catalogEntry;
    final variant = catalogEntry.variant;

    return Scaffold(
      appBar: AppBar(
        title: Text('${catalogEntry.manufacturer} ${catalogEntry.modelName}'),
        actions: [
          IconButton(
            key: const Key('removeTackleBoxEntryButton'),
            icon: _isRemoving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            tooltip: 'Poista vieherasiasta',
            onPressed: _isRemoving ? null : _onRemovePressed,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _buildImage(catalogEntry)),
              const SizedBox(height: AppSpacing.lg),
              _buildInfoRow(context, 'Valmistaja', catalogEntry.manufacturer),
              if (catalogEntry.productFamily != null)
                _buildInfoRow(context, 'Mallisto', catalogEntry.productFamily!),
              _buildInfoRow(context, 'Malli', catalogEntry.modelName),
              _buildInfoRow(
                context,
                'Vieheen tyyppi',
                lureTypeDisplayLabel(catalogEntry.lureType),
              ),
              if (variant.colorName != null)
                _buildInfoRow(context, 'Väri', variant.colorName!),
              if (variant.variantName != null)
                _buildInfoRow(context, 'Variantti', variant.variantName!),
              if (variant.manufacturerColorCode != null)
                _buildInfoRow(
                  context,
                  'Valmistajan värikoodi',
                  variant.manufacturerColorCode!,
                ),
              if (variant.lengthMillimeters != null)
                _buildInfoRow(
                  context,
                  'Pituus',
                  _formatCentimeters(variant.lengthMillimeters!),
                ),
              if (variant.weightGrams != null)
                _buildInfoRow(context, 'Paino', '${variant.weightGrams} g'),
              if (variant.minRunningDepthMillimeters != null ||
                  variant.maxRunningDepthMillimeters != null)
                _buildInfoRow(
                  context,
                  'Uintisyvyys',
                  _formatRunningDepth(
                    variant.minRunningDepthMillimeters,
                    variant.maxRunningDepthMillimeters,
                  ),
                ),
              if (variant.buoyancy != null)
                _buildInfoRow(
                  context,
                  'Kellunta',
                  buoyancyDisplayLabel(variant.buoyancy!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(LureCatalogEntry catalogEntry) {
    final semanticLabel =
        '${catalogEntry.manufacturer} ${catalogEntry.modelName}';
    final photoFile = _photoFile;
    if (photoFile != null) {
      return Semantics(
        label: 'Oma kuva: $semanticLabel',
        image: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Image.file(
            photoFile,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => LureImage(
              imageReference: catalogEntry.effectiveImageReference,
              semanticLabel: semanticLabel,
              size: 200,
            ),
          ),
        ),
      );
    }

    return LureImage(
      imageReference: catalogEntry.effectiveImageReference,
      semanticLabel: semanticLabel,
      size: 200,
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
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

String _formatCentimeters(int millimeters) {
  final centimeters = millimeters / 10;
  final text = centimeters.toStringAsFixed(1);
  final trimmed = text.endsWith('.0')
      ? text.substring(0, text.length - 2)
      : text;
  return '$trimmed cm';
}

String _formatRunningDepth(int? minMillimeters, int? maxMillimeters) {
  String formatMeters(int millimeters) {
    final meters = millimeters / 1000;
    final text = meters.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  if (minMillimeters != null && maxMillimeters != null) {
    return '${formatMeters(minMillimeters)}–${formatMeters(maxMillimeters)} m';
  }
  if (minMillimeters != null) {
    return '${formatMeters(minMillimeters)} m';
  }
  return '${formatMeters(maxMillimeters!)} m';
}
