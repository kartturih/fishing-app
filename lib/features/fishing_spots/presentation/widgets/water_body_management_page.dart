import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/data/water_body_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body_with_spot_count.dart';

/// A minimal, focused surface to view, rename, and (when empty) delete
/// water bodies — no filters, no sorting beyond the fixed alphabetical
/// order, no statistics. See MFS-024 FR-16, TD-024 §9.
class WaterBodyManagementPage extends StatefulWidget {
  const WaterBodyManagementPage({
    super.key,
    required this.waterBodyRepository,
    required this.fishingSpotRepository,
  });

  final WaterBodyRepository waterBodyRepository;
  final FishingSpotRepository fishingSpotRepository;

  @override
  State<WaterBodyManagementPage> createState() =>
      _WaterBodyManagementPageState();
}

class _WaterBodyManagementPageState extends State<WaterBodyManagementPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<WaterBodyWithSpotCount> _waterBodies = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final waterBodies = await widget.waterBodyRepository
          .loadAllWithSpotCounts();
      if (!mounted) {
        return;
      }
      setState(() {
        _waterBodies = waterBodies;
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

  Future<void> _rename(WaterBodyWithSpotCount entry) async {
    // Not manually disposed: the dialog's exit animation can still be
    // rendering this TextField's controller for a frame or two after
    // showDialog's Future resolves, and disposing it immediately here
    // raced that animation. A plain TextEditingController holds no ticker
    // or other resource that requires prompt disposal for a single,
    // short-lived dialog.
    final controller = TextEditingController(text: entry.waterBody.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Muokkaa nimeä'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nimi'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Peruuta'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Tallenna'),
          ),
        ],
      ),
    );

    if (newName == null || newName.trim().isEmpty || !mounted) {
      return;
    }

    try {
      await widget.waterBodyRepository.rename(
        id: entry.waterBody.id,
        name: newName,
      );
      if (!mounted) {
        return;
      }
      await _load();
    } catch (error) {
      debugPrint('Failed to rename water body: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nimen tallentaminen epäonnistui. Yritä uudelleen.'),
          ),
        );
      }
    }
  }

  Future<void> _delete(WaterBodyWithSpotCount entry) async {
    if (entry.fishingSpotCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vesistöä ei voi poistaa'),
          content: Text(
            'Vesistössä "${entry.waterBody.name}" on ${entry.fishingSpotCount} '
            'kalastuspaikkaa. Siirrä tai poista ne ensin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poistetaanko vesistö?'),
        content: Text(
          'Poistetaanko "${entry.waterBody.name}"? Toimintoa ei voi perua.',
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

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.waterBodyRepository.delete(entry.waterBody.id);
      if (!mounted) {
        return;
      }
      await _load();
    } catch (error) {
      debugPrint('Failed to delete water body: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vesistön poistaminen epäonnistui. Yritä uudelleen.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vesistöt')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => unawaited(_load()),
                child: const Text('Yritä uudelleen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_waterBodies.isEmpty) {
      return const Center(child: Text('Ei vielä vesistöjä.'));
    }

    return ListView.builder(
      key: const Key('waterBodyManagementList'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _waterBodies.length,
      itemBuilder: (context, index) => _buildRow(context, _waterBodies[index]),
    );
  }

  Widget _buildRow(BuildContext context, WaterBodyWithSpotCount entry) {
    return Card(
      key: ValueKey('waterBodyRow-${entry.waterBody.id}'),
      child: ExpansionTile(
        title: Text(entry.waterBody.name),
        subtitle: Text('${entry.fishingSpotCount} kalastuspaikkaa'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Muokkaa nimeä',
              onPressed: () => unawaited(_rename(entry)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Poista',
              onPressed: () => unawaited(_delete(entry)),
            ),
          ],
        ),
        children: [_buildMemberFishingSpots(entry)],
      ),
    );
  }

  Widget _buildMemberFishingSpots(WaterBodyWithSpotCount entry) {
    return FutureBuilder<List<FishingSpot>>(
      future: widget.fishingSpotRepository.getByWaterBodyId(entry.waterBody.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('Kalastuspaikkojen lataaminen epäonnistui.'),
          );
        }
        final spots = snapshot.data ?? const <FishingSpot>[];
        if (spots.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('Ei kalastuspaikkoja.'),
          );
        }
        return Column(
          children: [
            for (final spot in spots)
              ListTile(
                key: ValueKey('waterBodyMemberSpot-${spot.id}'),
                dense: true,
                title: Text(spot.name),
              ),
          ],
        );
      },
    );
  }
}
