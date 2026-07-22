import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/nearby_water_bodies.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/fishing_spots/presentation/widgets/water_body_management_page.dart';

/// Lets the angler select an existing water body, or create a new one, for
/// a fishing spot at ([latitude], [longitude]) — used both when creating a
/// fishing spot and when changing an existing one's water body. The widget
/// itself has no notion of "creating" vs. "editing"; it only ever reads the
/// coordinates it is given. See MFS-024 FR-3/FR-4/FR-5/FR-6, TD-024 §9.
class WaterBodySelectionBottomSheet extends StatefulWidget {
  const WaterBodySelectionBottomSheet({
    super.key,
    required this.waterBodyRepository,
    required this.fishingSpotRepository,
    required this.latitude,
    required this.longitude,
  });

  final WaterBodyRepository waterBodyRepository;
  final FishingSpotRepository fishingSpotRepository;
  final double latitude;
  final double longitude;

  static Future<WaterBody?> show(
    BuildContext context, {
    required WaterBodyRepository waterBodyRepository,
    required FishingSpotRepository fishingSpotRepository,
    required double latitude,
    required double longitude,
  }) {
    return showModalBottomSheet<WaterBody>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => WaterBodySelectionBottomSheet(
        waterBodyRepository: waterBodyRepository,
        fishingSpotRepository: fishingSpotRepository,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  @override
  State<WaterBodySelectionBottomSheet> createState() =>
      _WaterBodySelectionBottomSheetState();
}

class _WaterBodySelectionBottomSheetState
    extends State<WaterBodySelectionBottomSheet> {
  final TextEditingController _createController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<WaterBody> _all = [];
  NearbyWaterBodies _nearby = NearbyWaterBodies.empty;
  WaterBody? _selected;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _searchController.addListener(() => setState(() {}));
    _createController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _createController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final all = await widget.waterBodyRepository.loadAll();
      final nearby = await widget.waterBodyRepository.getNearby(
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _all = all;
        _nearby = nearby;
        _selected = nearby.preselected;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load water bodies: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Vesistöjen lataaminen epäonnistui.';
        _isLoading = false;
      });
    }
  }

  bool get _hasExactNameMatch {
    final query = _createController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return false;
    }
    return _all.any((waterBody) => waterBody.name.toLowerCase() == query);
  }

  Future<void> _createAndSelect() async {
    final name = _createController.text;
    if (name.trim().isEmpty || _isCreating) {
      return;
    }

    setState(() => _isCreating = true);
    try {
      final created = await widget.waterBodyRepository.create(name: name);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(created);
    } catch (error) {
      debugPrint('Failed to create water body: $error');
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vesistön luominen epäonnistui. Yritä uudelleen.'),
          ),
        );
      }
    }
  }

  Future<void> _openManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WaterBodyManagementPage(
          waterBodyRepository: widget.waterBodyRepository,
          fishingSpotRepository: widget.fishingSpotRepository,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _load();
  }

  List<WaterBody> get _filteredAll {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _all;
    }
    return _all
        .where((waterBody) => waterBody.name.toLowerCase().contains(query))
        .toList();
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
            children: [
              Text(
                'Valitse vesistö',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              ..._buildBody(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context) {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return [
        Text(
          errorMessage,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () => unawaited(_load()),
          child: const Text('Yritä uudelleen'),
        ),
      ];
    }

    return [
      if (_nearby.candidates.isNotEmpty) ..._buildNearbySection(context),
      _buildCreateSection(context),
      const SizedBox(height: AppSpacing.lg),
      _buildFullListSection(context),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton(
        onPressed: () => unawaited(_openManagement()),
        child: const Text('Hallitse vesistöjä'),
      ),
    ];
  }

  List<Widget> _buildNearbySection(BuildContext context) {
    return [
      Text('Lähellä', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      RadioGroup<String>(
        groupValue: _selected?.id,
        onChanged: (id) => setState(() {
          _selected = _nearby.candidates.firstWhere(
            (waterBody) => waterBody.id == id,
          );
        }),
        child: Column(
          children: [
            for (final waterBody in _nearby.candidates)
              RadioListTile<String>(
                key: ValueKey('nearbyWaterBody-${waterBody.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(waterBody.name),
                value: waterBody.id,
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      if (_selected != null)
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: const Text('Valitse'),
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
      const Divider(),
      const SizedBox(height: AppSpacing.md),
    ];
  }

  Widget _buildCreateSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Luo uusi vesistö', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _createController,
          enabled: !_isCreating,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Vesistön nimi'),
          onSubmitted: (_) => unawaited(_createAndSelect()),
        ),
        if (_hasExactNameMatch)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Vesistö tällä nimellä on jo olemassa — valitse se listasta?',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: _isCreating ? null : () => unawaited(_createAndSelect()),
            child: const Text('Luo'),
          ),
        ),
      ],
    );
  }

  Widget _buildFullListSection(BuildContext context) {
    final filtered = _filteredAll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Kaikki vesistöt', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Hae vesistöä',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_all.isEmpty)
          const Text('Ei vielä vesistöjä.')
        else if (filtered.isEmpty)
          const Text('Ei hakua vastaavia vesistöjä.')
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final waterBody = filtered[index];
                return ListTile(
                  key: ValueKey('waterBody-${waterBody.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(waterBody.name),
                  onTap: () => Navigator.of(context).pop(waterBody),
                );
              },
            ),
          ),
      ],
    );
  }
}
