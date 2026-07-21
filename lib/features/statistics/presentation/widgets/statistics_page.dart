import 'package:flutter/material.dart';

import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/statistics/data/general_catch_statistics_repository.dart';
import 'package:fishing_app/features/statistics/data/lure_statistics_repository.dart';
import 'package:fishing_app/features/statistics/data/species_statistics_repository.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/general_catch_statistics_tab.dart';
import 'package:fishing_app/features/statistics/presentation/widgets/lure_statistics_tab.dart';

/// Tabbed shell for the Statistics feature. Two tabs: Catches (MFS-020,
/// first, default) and Lure Statistics (MFS-019, second, unchanged) — see
/// TD-020 Key Design Decision 10.
///
/// Unlike `LureToolsPage` (TD-016), which exists specifically as the one
/// place two otherwise-independent features are allowed to meet, this shell
/// and its tabs all belong to the `statistics` feature — see TD-019's Key
/// Design Decision 7.
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({
    super.key,
    required this.generalCatchStatisticsRepository,
    required this.lureStatisticsRepository,
    required this.speciesStatisticsRepository,
    required this.catchRepository,
    required this.catchPhotoRepository,
    required this.lureCatalogRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
  });

  final GeneralCatchStatisticsRepository generalCatchStatisticsRepository;
  final LureStatisticsRepository lureStatisticsRepository;

  /// Forwarded to [GeneralCatchStatisticsTab], needed only to open Species
  /// Statistics from a Species List row (MFS-021) — this page has no use
  /// for it itself.
  final SpeciesStatisticsRepository speciesStatisticsRepository;

  /// Forwarded to [GeneralCatchStatisticsTab], needed only to open Catch
  /// Details from a largest-catch entry (FR-5) — this page has no use for
  /// them itself.
  final CatchRepository catchRepository;
  final CatchPhotoRepository catchPhotoRepository;
  final LureCatalogRepository lureCatalogRepository;
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tilastot'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Saalistilastot', icon: Icon(Icons.set_meal)),
              Tab(text: 'Viehetilastot', icon: Icon(Icons.bar_chart)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            GeneralCatchStatisticsTab(
              repository: generalCatchStatisticsRepository,
              speciesStatisticsRepository: speciesStatisticsRepository,
              catchRepository: catchRepository,
              catchPhotoRepository: catchPhotoRepository,
              lureCatalogRepository: lureCatalogRepository,
              personalTackleBoxRepository: personalTackleBoxRepository,
              personalTackleBoxPhotoStorage: personalTackleBoxPhotoStorage,
            ),
            LureStatisticsTab(repository: lureStatisticsRepository),
          ],
        ),
      ),
    );
  }
}
