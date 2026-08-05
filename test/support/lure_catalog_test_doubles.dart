/// Shared Lure Catalog test doubles (TD-028), used across
/// `lure_catalog_repository_test.dart`, `lure_catalog_list_page_test.dart`,
/// and `lure_tools_page_test.dart` — consolidated here (architecture
/// review, Required Fix 2) after all three files had independently
/// duplicated the same three classes under inconsistent names.
///
/// None of these ever touch a real Flutter asset bundle or a real
/// `shared_preferences` platform channel, consistent with this codebase's
/// existing convention of injecting a fake asset source in tests
/// (`syke_bathymetry_tile_source_test.dart`'s own precedent).
library;

import 'package:fishing_app/features/lure_catalog/data/lure_catalog_asset_loader.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_repository.dart';
import 'package:fishing_app/features/lure_catalog/data/lure_catalog_version_store.dart';

/// A test-only stand-in for [LureCatalogAssetLoader] that returns a fixed,
/// mutable [ParsedLureCatalog] instead of reading a real Flutter asset.
/// Mutable so a test can swap the content between successive
/// `ensureSeeded()` calls (e.g. to exercise correction/retirement); callers
/// that only ever seed once may simply never reassign [catalog].
class FakeLureCatalogAssetLoader extends LureCatalogAssetLoader {
  FakeLureCatalogAssetLoader(this.catalog);

  ParsedLureCatalog catalog;

  @override
  Future<ParsedLureCatalog> load({
    String assetFileName = LureCatalogAssetLoader.defaultAssetFileName,
  }) async => catalog;
}

/// A test-only in-memory stand-in for [LureCatalogVersionStore].
class InMemoryLureCatalogVersionStore extends LureCatalogVersionStore {
  int? _stored;

  @override
  Future<int?> loadLastReconciledVersion() async => _stored;

  @override
  Future<void> saveLastReconciledVersion(int version) async {
    _stored = version;
  }
}

/// A [LureCatalogRepository] whose `ensureSeeded()` always reconciles
/// against a fixed [ParsedLureCatalog] and a fresh
/// [InMemoryLureCatalogVersionStore], ignoring whatever loader/version
/// store a caller passes in. Useful directly for widget tests that just
/// need the catalog populated with known content and don't otherwise
/// customize repository behavior — a widget test needing *different*
/// `ensureSeeded()` behavior (e.g. never completing, or controllable
/// `browse()`) should subclass [LureCatalogRepository] itself and reuse
/// [FakeLureCatalogAssetLoader]/[InMemoryLureCatalogVersionStore] directly,
/// rather than extending this class.
class FakeContentLureCatalogRepository extends LureCatalogRepository {
  FakeContentLureCatalogRepository(super.database, this._catalog);

  final ParsedLureCatalog _catalog;

  @override
  Future<void> ensureSeeded({
    LureCatalogAssetLoader assetLoader = const LureCatalogAssetLoader(),
    LureCatalogVersionStore versionStore = const LureCatalogVersionStore(),
  }) {
    return super.ensureSeeded(
      assetLoader: FakeLureCatalogAssetLoader(_catalog),
      versionStore: InMemoryLureCatalogVersionStore(),
    );
  }
}
