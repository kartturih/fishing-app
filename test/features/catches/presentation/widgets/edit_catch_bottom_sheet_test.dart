import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/catches/domain/fish_species_extensions.dart';
import 'package:fishing_app/features/catches/presentation/widgets/edit_catch_bottom_sheet.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';
import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

class _FailingUpdateCatchRepository extends CatchRepository {
  _FailingUpdateCatchRepository(super.database);

  int updateCallCount = 0;

  @override
  Future<Catch> update({
    required Catch catchModel,
    required FishSpecies species,
    required DateTime caughtAt,
    int? weightGrams,
    int? lengthMillimeters,
  }) async {
    updateCallCount++;
    throw StateError('simulated update failure');
  }
}

class _FailingDeleteCatchRepository extends CatchRepository {
  _FailingDeleteCatchRepository(super.database);

  int deleteCallCount = 0;

  @override
  Future<void> delete(String catchId) async {
    deleteCallCount++;
    throw StateError('simulated delete failure');
  }
}

class _SlowUpdateCatchRepository extends CatchRepository {
  _SlowUpdateCatchRepository(super.database);

  int updateCallCount = 0;
  final Completer<void> gate = Completer<void>();

  @override
  Future<Catch> update({
    required Catch catchModel,
    required FishSpecies species,
    required DateTime caughtAt,
    int? weightGrams,
    int? lengthMillimeters,
  }) async {
    updateCallCount++;
    await gate.future;
    return super.update(
      catchModel: catchModel,
      species: species,
      caughtAt: caughtAt,
      weightGrams: weightGrams,
      lengthMillimeters: lengthMillimeters,
    );
  }
}

class _SlowDeleteCatchRepository extends CatchRepository {
  _SlowDeleteCatchRepository(super.database);

  int deleteCallCount = 0;
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> delete(String catchId) async {
    deleteCallCount++;
    await gate.future;
    return super.delete(catchId);
  }
}

class _EditCatchHarness {
  EditCatchResult? result;

  Future<void> open(
    WidgetTester tester,
    FishingSpot fishingSpot,
    Catch catchModel,
    CatchRepository catchRepository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await EditCatchBottomSheet.show(
                  context,
                  fishingSpot,
                  catchModel,
                  catchRepository,
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
  }
}

Future<void> _selectSpecies(WidgetTester tester, FishSpecies species) async {
  await tester.tap(find.byType(DropdownButtonFormField<FishSpecies>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(species.finnishName).last);
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase database;
  late CatchRepository catchRepository;
  late FishingSpotRepository fishingSpotRepository;
  late FishingSpot fishingSpot;
  late Catch existingCatch;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    catchRepository = CatchRepository(database);
    fishingSpotRepository = FishingSpotRepository(database);
    fishingSpot = await fishingSpotRepository.create(
      name: 'Merrasjärvi',
      latitude: 61.0,
      longitude: 25.0,
    );
    existingCatch = await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 14, 18, 34),
      weightGrams: 3200,
      lengthMillimeters: 780,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('initial values', () {
    testWidgets('prefills species, weight, and length from the catch', (
      tester,
    ) async {
      final harness = _EditCatchHarness();
      await harness.open(tester, fishingSpot, existingCatch, catchRepository);

      expect(find.text('Merrasjärvi'), findsOneWidget);
      expect(find.text('Hauki'), findsOneWidget);
      expect(find.text('3.2'), findsOneWidget);
      expect(find.text('78'), findsOneWidget);
    });

    testWidgets('shows empty weight and length when not set', (tester) async {
      final catchWithoutMeasurements = await catchRepository.create(
        fishingSpotId: fishingSpot.id,
        species: FishSpecies.perch,
        caughtAt: DateTime(2026, 7, 10, 21, 10),
      );

      final harness = _EditCatchHarness();
      await harness.open(
        tester,
        fishingSpot,
        catchWithoutMeasurements,
        catchRepository,
      );

      final weightField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(0),
      );
      final lengthField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(1),
      );

      expect(weightField.controller!.text, isEmpty);
      expect(lengthField.controller!.text, isEmpty);
    });
  });

  testWidgets('allows changing the species and saves it', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(tester, fishingSpot, existingCatch, catchRepository);

    await _selectSpecies(tester, FishSpecies.zander);
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    expect(harness.result, isA<CatchUpdated>());
    final updated = (harness.result! as CatchUpdated).catchModel;
    expect(updated.species, FishSpecies.zander);

    final stored = await catchRepository.getById(existingCatch.id);
    expect(stored!.species, FishSpecies.zander);
  });

  testWidgets('accepts a comma decimal separator for weight', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(tester, fishingSpot, existingCatch, catchRepository);

    await tester.enterText(find.byType(TextFormField).at(0), '2,5');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    final updated = (harness.result! as CatchUpdated).catchModel;
    expect(updated.weightGrams, 2500);
  });

  testWidgets('accepts a period decimal separator for length', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(tester, fishingSpot, existingCatch, catchRepository);

    await tester.enterText(find.byType(TextFormField).at(1), '68.5');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    final updated = (harness.result! as CatchUpdated).catchModel;
    expect(updated.lengthMillimeters, 685);
  });

  testWidgets('allows clearing an existing weight', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(tester, fishingSpot, existingCatch, catchRepository);

    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    final updated = (harness.result! as CatchUpdated).catchModel;
    expect(updated.weightGrams, isNull);
  });

  testWidgets('allows clearing an existing length', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(tester, fishingSpot, existingCatch, catchRepository);

    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    final updated = (harness.result! as CatchUpdated).catchModel;
    expect(updated.lengthMillimeters, isNull);
  });

  testWidgets('rejects zero weight and keeps the sheet open', (tester) async {
    final harness = _EditCatchHarness();
    await harness.open(tester, fishingSpot, existingCatch, catchRepository);

    await tester.enterText(find.byType(TextFormField).at(0), '0');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    expect(harness.result, isNull);
    expect(find.text('Painon täytyy olla suurempi kuin 0'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('shows an error and preserves values when save fails', (
    tester,
  ) async {
    final failingRepository = _FailingUpdateCatchRepository(database);
    final harness = _EditCatchHarness();
    await harness.open(tester, fishingSpot, existingCatch, failingRepository);

    await tester.enterText(find.byType(TextFormField).at(0), '5');
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pumpAndSettle();

    expect(harness.result, isNull);
    expect(
      find.text('Saaliin tallentaminen epäonnistui. Yritä uudelleen.'),
      findsOneWidget,
    );
    expect(find.text('5'), findsOneWidget);
    expect(failingRepository.updateCallCount, 1);
  });

  testWidgets('prevents duplicate save taps', (tester) async {
    final slowRepository = _SlowUpdateCatchRepository(database);
    final harness = _EditCatchHarness();
    await harness.open(tester, fishingSpot, existingCatch, slowRepository);

    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('editCatchSaveButton')));
    await tester.pump();

    expect(slowRepository.updateCallCount, 1);

    slowRepository.gate.complete();
    await tester.pumpAndSettle();

    expect(harness.result, isA<CatchUpdated>());
  });

  group('delete', () {
    testWidgets('shows a confirmation dialog', (tester) async {
      final harness = _EditCatchHarness();
      await harness.open(tester, fishingSpot, existingCatch, catchRepository);

      await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
      await tester.pumpAndSettle();

      expect(find.text('Poistetaanko saalis?'), findsOneWidget);
      expect(find.text('Toimintoa ei voi perua.'), findsOneWidget);
    });

    testWidgets('cancelling keeps the sheet open and does not delete', (
      tester,
    ) async {
      final harness = _EditCatchHarness();
      await harness.open(tester, fishingSpot, existingCatch, catchRepository);

      await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Peruuta'));
      await tester.pumpAndSettle();

      expect(harness.result, isNull);
      expect(find.text('Merrasjärvi'), findsOneWidget);
      expect(await catchRepository.getById(existingCatch.id), isNotNull);
    });

    testWidgets('confirming deletes the catch and closes the sheet', (
      tester,
    ) async {
      final harness = _EditCatchHarness();
      await harness.open(tester, fishingSpot, existingCatch, catchRepository);

      await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista').last);
      await tester.pumpAndSettle();

      expect(harness.result, isA<CatchDeleted>());
      expect((harness.result! as CatchDeleted).catchId, existingCatch.id);
      expect(await catchRepository.getById(existingCatch.id), isNull);
    });

    testWidgets('shows an error and keeps the sheet open when delete fails', (
      tester,
    ) async {
      final failingRepository = _FailingDeleteCatchRepository(database);
      final harness = _EditCatchHarness();
      await harness.open(tester, fishingSpot, existingCatch, failingRepository);

      await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista').last);
      await tester.pumpAndSettle();

      expect(harness.result, isNull);
      expect(
        find.text('Saaliin poistaminen epäonnistui. Yritä uudelleen.'),
        findsOneWidget,
      );
      expect(failingRepository.deleteCallCount, 1);
    });

    testWidgets('prevents duplicate delete taps', (tester) async {
      final slowRepository = _SlowDeleteCatchRepository(database);
      final harness = _EditCatchHarness();
      await harness.open(tester, fishingSpot, existingCatch, slowRepository);

      await tester.tap(find.byKey(const Key('editCatchDeleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista').last);
      await tester.pump();

      expect(slowRepository.deleteCallCount, 1);

      // The sheet's own Delete button is now disabled while deleting; a
      // second tap attempt must not trigger a second repository call.
      await tester.tap(
        find.byKey(const Key('editCatchDeleteButton')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(slowRepository.deleteCallCount, 1);

      slowRepository.gate.complete();
      await tester.pumpAndSettle();

      expect(harness.result, isA<CatchDeleted>());
    });
  });
}
