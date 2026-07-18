import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_image.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_item.dart';
import 'package:fishing_app/features/personal_tackle_box/presentation/widgets/owned_entry_detail_page.dart';

/// Personal Tackle Box browsing screen: owned entries grouped by
/// manufacturer, then model — never a flat one-row-per-variant list.
///
/// A plain [StatefulWidget] receiving its [PersonalTackleBoxRepository]/
/// [TackleBoxPhotoStorage] via required constructor parameters — constructed
/// and pushed the same way every other feature screen in this app is
/// (manual dependency construction, no Riverpod). See MFS-016 / TD-016.
class PersonalTackleBoxPage extends StatefulWidget {
  const PersonalTackleBoxPage({
    super.key,
    required this.repository,
    required this.photoStorage,
  });

  final PersonalTackleBoxRepository repository;
  final TackleBoxPhotoStorage photoStorage;

  @override
  State<PersonalTackleBoxPage> createState() => _PersonalTackleBoxPageState();
}

class _PersonalTackleBoxPageState extends State<PersonalTackleBoxPage> {
  bool _isLoading = true;
  String? _loadError;
  List<TackleBoxItem> _items = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final items = await widget.repository.getAll();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load personal tackle box: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = 'Vieherasian lataaminen epäonnistui.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openDetails(TackleBoxItem item) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => OwnedEntryDetailPage(
          item: item,
          repository: widget.repository,
          photoStorage: widget.photoStorage,
        ),
      ),
    );
    if (removed == true) {
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oma vieherasia')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final loadError = _loadError;
    if (loadError != null) {
      return Center(
        child: Text(
          loadError,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Et ole vielä lisännyt viehteitä vieherasiaan. '
            'Voit lisätä viehteitä viehekatalogista.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final rows = _buildRows(_items);
    return ListView.builder(
      key: const Key('personalTackleBoxList'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: rows.length,
      itemBuilder: (context, index) => _buildRow(context, rows[index]),
    );
  }

  Widget _buildRow(BuildContext context, _TackleBoxListRow row) {
    return switch (row) {
      _ManufacturerHeaderRow(:final manufacturer) => Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xs,
        ),
        child: Text(
          manufacturer,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      _ModelHeaderRow(:final modelName) => Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          bottom: AppSpacing.xs,
        ),
        child: Text(modelName, style: Theme.of(context).textTheme.titleSmall),
      ),
      _ItemRow(:final item) => Padding(
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        child: _TackleBoxItemRow(
          key: ValueKey(item.id),
          item: item,
          onTap: () => _openDetails(item),
        ),
      ),
    };
  }
}

sealed class _TackleBoxListRow {}

final class _ManufacturerHeaderRow extends _TackleBoxListRow {
  _ManufacturerHeaderRow(this.manufacturer);
  final String manufacturer;
}

final class _ModelHeaderRow extends _TackleBoxListRow {
  _ModelHeaderRow(this.modelName);
  final String modelName;
}

final class _ItemRow extends _TackleBoxListRow {
  _ItemRow(this.item);
  final TackleBoxItem item;
}

/// Groups the already-sorted (manufacturer -> model -> variant) flat
/// repository result into a flat row list with manufacturer/model section
/// headers, detecting section boundaries in a single linear pass — no
/// persisted grouping entity and no extra query, per MFS-016's Conceptual
/// Data Model / TD-016's Key Design Decision 3.
List<_TackleBoxListRow> _buildRows(List<TackleBoxItem> items) {
  final rows = <_TackleBoxListRow>[];
  String? lastManufacturer;
  String? lastModelName;

  for (final item in items) {
    final manufacturer = item.catalogEntry.manufacturer;
    final modelName = item.catalogEntry.modelName;

    if (manufacturer != lastManufacturer) {
      rows.add(_ManufacturerHeaderRow(manufacturer));
      lastManufacturer = manufacturer;
      lastModelName = null;
    }
    if (modelName != lastModelName) {
      rows.add(_ModelHeaderRow(modelName));
      lastModelName = modelName;
    }
    rows.add(_ItemRow(item));
  }
  return rows;
}

class _TackleBoxItemRow extends StatelessWidget {
  const _TackleBoxItemRow({super.key, required this.item, required this.onTap});

  final TackleBoxItem item;
  final VoidCallback onTap;

  String get _distinguishingDetail {
    final variant = item.catalogEntry.variant;
    return variant.variantName ??
        variant.colorName ??
        variant.manufacturerColorCode ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    final distinguishingDetail = _distinguishingDetail;
    final semanticLabel = distinguishingDetail.isEmpty
        ? '${item.catalogEntry.manufacturer} ${item.catalogEntry.modelName}'
        : '${item.catalogEntry.manufacturer} ${item.catalogEntry.modelName} '
              '$distinguishingDetail';

    return InkWell(
      onTap: onTap,
      child: Semantics(
        label: semanticLabel,
        button: true,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              LureImage(
                imageReference: item.catalogEntry.effectiveImageReference,
                semanticLabel: semanticLabel,
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  distinguishingDetail.isEmpty ? '—' : distinguishingDetail,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
