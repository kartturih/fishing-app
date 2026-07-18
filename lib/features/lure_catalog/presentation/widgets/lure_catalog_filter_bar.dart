import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';

/// Search field plus manufacturer/lure-type filter controls for the Lure
/// Catalog browse list. Owns no repository or query logic — [searchController]
/// is owned by the caller. See MFS-015 / TD-015.
class LureCatalogFilterBar extends StatelessWidget {
  const LureCatalogFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.manufacturers,
    required this.selectedManufacturer,
    required this.onManufacturerChanged,
    required this.lureTypes,
    required this.selectedLureType,
    required this.onLureTypeChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<String> manufacturers;
  final String? selectedManufacturer;
  final ValueChanged<String?> onManufacturerChanged;
  final List<String> lureTypes;
  final String? selectedLureType;
  final ValueChanged<String?> onLureTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('lureCatalogSearchField'),
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Hae viehekatalogista',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: const Key('lureCatalogManufacturerFilter'),
                initialValue: selectedManufacturer,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Valmistaja'),
                items: [
                  const DropdownMenuItem(child: Text('Kaikki valmistajat')),
                  for (final manufacturer in manufacturers)
                    DropdownMenuItem(
                      value: manufacturer,
                      child: Text(manufacturer),
                    ),
                ],
                onChanged: onManufacturerChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: const Key('lureCatalogLureTypeFilter'),
                initialValue: selectedLureType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Vieheen tyyppi'),
                items: [
                  const DropdownMenuItem(child: Text('Kaikki tyypit')),
                  for (final lureType in lureTypes)
                    DropdownMenuItem(
                      value: lureType,
                      child: Text(lureTypeDisplayLabel(lureType)),
                    ),
                ],
                onChanged: onLureTypeChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
