import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_image.dart';

/// Pure presentation row for a catch's assigned lure.
///
/// Renders one of three states — assigned, unassigned, or unavailable — and
/// exposes [onAssign]/[onChange]/[onRemove] callbacks for its parent to react
/// to. It never resolves a lure itself, never talks to a repository, and
/// never navigates: Add Catch, Edit Catch, and Catch Details own all of that
/// behavior and simply pass this widget already-resolved data. See MFS-017 /
/// TD-017.
class AssignedLureRow extends StatelessWidget {
  const AssignedLureRow({
    super.key,
    required this.entry,
    this.isUnavailable = false,
    this.onAssign,
    this.onChange,
    this.onRemove,
  });

  /// The resolved lure to display. `null` means either nothing is assigned
  /// ([isUnavailable] is `false`) or resolution failed ([isUnavailable] is
  /// `true`).
  final LureCatalogEntry? entry;

  /// `true` when a lure is assigned but its catalog details could not be
  /// resolved. Ignored when [entry] is non-null.
  final bool isUnavailable;

  /// Invoked when the user taps to assign a lure. Rendered only when nothing
  /// is currently assigned or resolvable.
  final VoidCallback? onAssign;

  /// Invoked when the user taps to change the assigned lure. Rendered
  /// whenever something is currently assigned (resolved or not).
  final VoidCallback? onChange;

  /// Invoked when the user taps to remove the assigned lure. Rendered
  /// whenever something is currently assigned (resolved or not).
  final VoidCallback? onRemove;

  bool get _hasAssignment => entry != null || isUnavailable;

  String get _distinguishingDetail {
    final variant = entry?.variant;
    if (variant == null) {
      return '';
    }
    return variant.variantName ??
        variant.colorName ??
        variant.manufacturerColorCode ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAssignment) {
      return _buildUnassigned(context);
    }
    final entry = this.entry;
    if (entry == null) {
      return _buildUnavailable(context);
    }
    return _buildAssigned(context, entry);
  }

  Widget _buildUnassigned(BuildContext context) {
    return Semantics(
      label: 'Ei valittua viehettä',
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Ei valittua viehettä',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (onAssign != null)
            TextButton(onPressed: onAssign, child: const Text('Valitse viehe')),
        ],
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context) {
    return Semantics(
      label: 'Viehetiedot eivät ole saatavilla',
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Viehetiedot eivät ole saatavilla',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          if (onChange != null)
            TextButton(onPressed: onChange, child: const Text('Vaihda')),
          if (onRemove != null)
            TextButton(onPressed: onRemove, child: const Text('Poista')),
        ],
      ),
    );
  }

  Widget _buildAssigned(BuildContext context, LureCatalogEntry entry) {
    final distinguishingDetail = _distinguishingDetail;
    final baseLabel = distinguishingDetail.isEmpty
        ? '${entry.manufacturer} ${entry.modelName}'
        : '${entry.manufacturer} ${entry.modelName} $distinguishingDetail';

    return Semantics(
      label: baseLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LureImage(
            imageReference: entry.effectiveImageReference,
            semanticLabel: baseLabel,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.manufacturer} ${entry.modelName}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (distinguishingDetail.isNotEmpty)
                  Text(
                    distinguishingDetail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  lureTypeDisplayLabel(entry.lureType),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onChange != null)
            TextButton(onPressed: onChange, child: const Text('Vaihda')),
          if (onRemove != null)
            TextButton(onPressed: onRemove, child: const Text('Poista')),
        ],
      ),
    );
  }
}
