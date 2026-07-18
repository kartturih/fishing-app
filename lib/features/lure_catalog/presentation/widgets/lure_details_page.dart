import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_image.dart';

/// Read-only Lure Details page for a single catalog variant.
///
/// A [StatelessWidget]: the [entry] is already fully resolved by whichever
/// `browse()`/`getEntryById()` call produced it, so there is no load-on-open
/// query and no repository dependency. No actions beyond Back — the catalog
/// is shared, read-only product data. See MFS-015 / TD-015.
class LureDetailsPage extends StatelessWidget {
  const LureDetailsPage({super.key, required this.entry});

  final LureCatalogEntry entry;

  static Future<void> open(BuildContext context, LureCatalogEntry entry) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => LureDetailsPage(entry: entry)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variant = entry.variant;

    return Scaffold(
      appBar: AppBar(title: Text('${entry.manufacturer} ${entry.modelName}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: LureImage(
                  imageReference: entry.effectiveImageReference,
                  semanticLabel: '${entry.manufacturer} ${entry.modelName}',
                  size: 200,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildInfoRow(context, 'Valmistaja', entry.manufacturer),
              if (entry.productFamily != null)
                _buildInfoRow(context, 'Mallisto', entry.productFamily!),
              _buildInfoRow(context, 'Malli', entry.modelName),
              _buildInfoRow(
                context,
                'Vieheen tyyppi',
                lureTypeDisplayLabel(entry.lureType),
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
