import 'package:flutter/material.dart';

import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/presentation/widgets/lure_catalog_list_page.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/personal_tackle_box/presentation/widgets/personal_tackle_box_page.dart';

/// A single Material 3 tabbed shell for switching between the Lure Catalog
/// and the Personal Tackle Box without returning to the map in between.
///
/// Both tabs render the real, existing screens (`LureCatalogListPage`,
/// `PersonalTackleBoxPage`) in `embedded` mode — this widget supplies the
/// one shared `Scaffold`/`AppBar`/`TabBar`, and each page supplies only its
/// own content. Nothing about either feature's domain, data, or repository
/// layer changes; this is a presentation-only shell, and it lives under
/// `map/` (not inside either feature) for the same reason `MapScreen`
/// already builds the `AddToTackleBoxAction`/`loadOwnedLureVariantIds`
/// glue between them (see TD-016's Key Design Decision 1) — it is the one
/// place these two features are allowed to meet, so neither one depends on
/// the other.
///
/// A `StatelessWidget`: tab selection state is owned entirely by
/// [DefaultTabController], and each tab's own `StatefulWidget` (already
/// responsible for its own loading/search/filter state) is kept alive by
/// `TabBarView` across tab switches, so revisiting a tab does not reload
/// or reset it.
class LureToolsPage extends StatelessWidget {
  const LureToolsPage({
    super.key,
    required this.lureCatalogRepository,
    required this.personalTackleBoxRepository,
    required this.personalTackleBoxPhotoStorage,
    this.lureCatalogDetailsActionsBuilder,
    this.loadOwnedLureVariantIds,
  });

  final LureCatalogRepository lureCatalogRepository;
  final PersonalTackleBoxRepository personalTackleBoxRepository;
  final TackleBoxPhotoStorage personalTackleBoxPhotoStorage;

  /// Forwarded verbatim to the embedded `LureCatalogListPage`. See
  /// `LureCatalogListPage.detailsActionsBuilder`.
  final List<Widget> Function(BuildContext context, LureCatalogEntry entry)?
  lureCatalogDetailsActionsBuilder;

  /// Forwarded verbatim to the embedded `LureCatalogListPage`. See
  /// `LureCatalogListPage.loadOwnedLureVariantIds`.
  final Future<Set<String>> Function()? loadOwnedLureVariantIds;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Viehevälineet'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Viehekatalogi', icon: Icon(Icons.menu_book)),
              Tab(
                text: 'Oma vieherasia',
                icon: Icon(Icons.inventory_2_outlined),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LureCatalogListPage(
              key: const PageStorageKey('lureToolsCatalogTab'),
              repository: lureCatalogRepository,
              detailsActionsBuilder: lureCatalogDetailsActionsBuilder,
              loadOwnedLureVariantIds: loadOwnedLureVariantIds,
              embedded: true,
            ),
            PersonalTackleBoxPage(
              key: const PageStorageKey('lureToolsTackleBoxTab'),
              repository: personalTackleBoxRepository,
              photoStorage: personalTackleBoxPhotoStorage,
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }
}
