import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_type_labels.dart';

/// Search field plus manufacturer/lure-type filter controls for the
/// Personal Tackle Box browsing list — visually mirrors
/// `LureCatalogFilterBar`'s shape (search field, then a row of two
/// dropdowns) and reuses its exact lure-type wording/labels, but filters an
/// already-loaded, in-memory list rather than issuing a repository query:
/// a user's tackle box is expected to stay small (MFS-016), so there is no
/// need for a dedicated search/filter query here.
///
/// Model is deliberately not a filter dimension here: the search field
/// already matches model names (e.g. "Toby", "X-Rap"), so a second,
/// separate model dropdown would add a control without adding capability.
/// Owns no filtering logic itself — [searchController] and the option
/// lists are owned by the caller. See MFS-016 / TD-016.
class PersonalTackleBoxFilterBar extends StatelessWidget {
  const PersonalTackleBoxFilterBar({
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
          key: const Key('personalTackleBoxSearchField'),
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Hae vieherasiasta',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: const Key('personalTackleBoxManufacturerFilter'),
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
                key: const Key('personalTackleBoxLureTypeFilter'),
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
