import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/catch_filter_options.dart';
import 'package:fishing_app/features/catches/domain/catch_search_criteria.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_filter_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/domain/water_body.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

void main() {
  final waterBodyA = WaterBody(
    id: 'water-body-1',
    name: 'Merrasjärvi',
    createdAt: DateTime(2026, 1, 1),
  );
  final waterBodyB = WaterBody(
    id: 'water-body-2',
    name: 'Näsijärvi',
    createdAt: DateTime(2026, 1, 1),
  );
  final lure = LureCatalogEntry(
    variant: LureVariant(
      id: 'variant-1',
      lureModelId: 'model-1',
      colorName: 'Firetiger',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    manufacturer: 'Rapala',
    modelName: 'X-Rap Shad',
    lureType: 'jerkbait',
    modelDefaultImageReference: null,
  );

  final filterOptions = CatchFilterOptions(
    waterBodies: [waterBodyA, waterBodyB],
    species: const [FishSpecies.pike, FishSpecies.zander],
    lures: [lure],
  );

  /// Opens the sheet and returns a getter for its eventual result (`null`
  /// until the sheet is dismissed). The sheet's four filter sections
  /// (water body, species, lure, date range) plus its action row do not
  /// fit within the default 800x600 test viewport, leaving "Käytä"/
  /// "Tyhjennä suodattimet" below the fold and unhittable — mirrors
  /// catch_details_page_test.dart's identical fix for its own taller form.
  Future<CatchSearchCriteria? Function()> openSheet(
    WidgetTester tester, {
    CatchSearchCriteria initialCriteria = CatchSearchCriteria.empty,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CatchSearchCriteria? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await CatchFilterBottomSheet.show(
                  context,
                  filterOptions: filterOptions,
                  initialCriteria: initialCriteria,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    return () => result;
  }

  testWidgets('renders every water body, species, and lure option', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Merrasjärvi'), findsOneWidget);
    expect(find.text('Näsijärvi'), findsOneWidget);
    expect(find.text('Hauki'), findsOneWidget);
    expect(find.text('Kuha'), findsOneWidget);
    expect(find.text('Rapala X-Rap Shad'), findsOneWidget);
  });

  testWidgets('applying a selected water body returns updated criteria', (
    tester,
  ) async {
    final result = await openSheet(
      tester,
      initialCriteria: const CatchSearchCriteria(query: 'hauki'),
    );

    await tester.tap(
      find.byKey(const Key('waterBodyFilterOption-water-body-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('applyFiltersButton')));
    await tester.pumpAndSettle();

    expect(result(), isNotNull);
    expect(result()!.waterBodyId, 'water-body-1');
    expect(
      result()!.query,
      'hauki',
      reason: 'the text query must be preserved',
    );
  });

  testWidgets('selecting "Ei valintaa" clears a previously active filter', (
    tester,
  ) async {
    final result = await openSheet(
      tester,
      initialCriteria: const CatchSearchCriteria(species: FishSpecies.pike),
    );

    await tester.tap(find.byKey(const Key('speciesFilterOption-none')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('applyFiltersButton')));
    await tester.pumpAndSettle();

    expect(result()!.species, isNull);
  });

  testWidgets(
    '"Tyhjennä suodattimet" clears every filter but preserves the query',
    (tester) async {
      final result = await openSheet(
        tester,
        initialCriteria: const CatchSearchCriteria(
          query: 'hauki',
          waterBodyId: 'water-body-1',
          species: FishSpecies.pike,
        ),
      );

      await tester.tap(find.byKey(const Key('clearFiltersButton')));
      await tester.pumpAndSettle();

      expect(result()!.query, 'hauki');
      expect(result()!.hasActiveFilters, isFalse);
    },
  );

  testWidgets('the date range control shows "Ei aikaväliä" when unset', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Ei aikaväliä'), findsOneWidget);
    expect(find.byKey(const Key('clearDateRangeButton')), findsNothing);
  });

  testWidgets('a pre-set date range is displayed, and can be cleared without '
      'affecting other filters', (tester) async {
    final result = await openSheet(
      tester,
      initialCriteria: CatchSearchCriteria(
        species: FishSpecies.pike,
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 1, 31),
      ),
    );

    expect(find.byKey(const Key('clearDateRangeButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clearDateRangeButton')));
    await tester.pumpAndSettle();

    expect(find.text('Ei aikaväliä'), findsOneWidget);

    await tester.tap(find.byKey(const Key('applyFiltersButton')));
    await tester.pumpAndSettle();

    expect(result()!.dateFrom, isNull);
    expect(result()!.dateTo, isNull);
    expect(
      result()!.species,
      FishSpecies.pike,
      reason: 'clearing only the date range must not touch other filters',
    );
  });
}
