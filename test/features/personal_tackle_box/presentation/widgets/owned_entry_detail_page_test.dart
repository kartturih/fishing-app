import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/pending_tackle_box_photo.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_item.dart';
import 'package:fishing_app/features/personal_tackle_box/presentation/widgets/owned_entry_detail_page.dart';

/// Pumps and lets a multi-step real dart:io chain (photo file resolution/
/// decode, file deletion) advance to completion. A single tester.pump()
/// only drains microtasks already queued at that instant; real asynchronous
/// file I/O resolves on the actual event loop, so this interleaves short
/// real-time windows (via tester.runAsync) with pumps until the widget
/// settles. Mirrors the identical helper in edit_catch_bottom_sheet_test.dart
/// / catch_photo_viewer_test.dart.
Future<void> _pumpUntilSettledWithRealIO(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Fails [delete] for any relative path in [failOn]. Mirrors
/// `_FailingDeleteStorage` in personal_tackle_box_repository_test.dart.
class _FailingDeleteStorage extends TackleBoxPhotoStorage {
  _FailingDeleteStorage({required super.rootDirectoryProvider});

  final Set<String> failOn = {};

  @override
  Future<void> delete(String relativePath) async {
    if (failOn.contains(relativePath)) {
      throw const TackleBoxPhotoStorageException('Simulated deletion failure.');
    }
    return super.delete(relativePath);
  }
}

class _DetailHarness {
  bool? removed;

  Future<void> open(
    WidgetTester tester,
    TackleBoxItem item,
    PersonalTackleBoxRepository repository,
    TackleBoxPhotoStorage storage,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                removed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => OwnedEntryDetailPage(
                      item: item,
                      repository: repository,
                      photoStorage: storage,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntilSettledWithRealIO(tester);
  }
}

void main() {
  late AppDatabase database;
  late Directory tempDir;
  late TackleBoxPhotoStorage storage;
  late PersonalTackleBoxRepository repository;

  // Real dart:io File operations (inside TackleBoxPhotoStorage.store) never
  // resolve when awaited directly inside a testWidgets() body — the special
  // test zone blocks real Timer/IO completion unless the call runs through
  // tester.runAsync. This is unrelated to (and stricter than) the "needs a
  // few real-time windows after pumping" pattern used elsewhere in this
  // codebase (e.g. edit_catch_bottom_sheet_test.dart's
  // _pumpUntilSettledWithRealIO): a bare await with no runAsync anywhere in
  // its call chain hangs forever, not just slowly.
  Future<TackleBoxItem> seedAndAddEntry(
    WidgetTester tester, {
    String? photoSourcePath,
  }) async {
    await database
        .into(database.lureModels)
        .insert(
          LureModelsCompanion.insert(
            id: 'model-1',
            manufacturer: 'Rapala',
            modelName: 'X-Rap Shad XRS08',
            lureType: 'crankbait',
            searchText: 'rapala x-rap shad xrs08',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await database
        .into(database.lureVariants)
        .insert(
          LureVariantsCompanion.insert(
            id: 'variant-1',
            lureModelId: 'model-1',
            colorName: const Value('Hot Craw'),
            searchText: 'hot craw',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    final catalogEntry = LureCatalogEntry(
      variant: LureVariant(
        id: 'variant-1',
        lureModelId: 'model-1',
        colorName: 'Hot Craw',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
      manufacturer: 'Rapala',
      modelName: 'X-Rap Shad XRS08',
      lureType: 'crankbait',
      modelDefaultImageReference: null,
    );

    final result = await tester.runAsync(
      () => repository.add(
        catalogEntry: catalogEntry,
        pendingPhoto: photoSourcePath == null
            ? null
            : PendingTackleBoxPhoto(sourcePath: photoSourcePath),
      ),
    );
    return result!.item;
  }

  String writeSourceImage(String name) {
    final image = img.Image(width: 20, height: 15);
    img.fill(image, color: img.ColorRgb8(5, 5, 5));
    final file = File(p.join(tempDir.path, 'source', name));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodeJpg(image));
    return file.path;
  }

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('owned_entry_detail_page');
    storage = TackleBoxPhotoStorage(rootDirectoryProvider: () async => tempDir);
    repository = PersonalTackleBoxRepository(database, storage);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('renders catalog details and falls back to catalog image', (
    tester,
  ) async {
    final item = await seedAndAddEntry(tester);
    final harness = _DetailHarness();

    await harness.open(tester, item, repository, storage);

    expect(find.text('Rapala X-Rap Shad XRS08'), findsOneWidget);
    expect(find.text('Rapala'), findsOneWidget);
    expect(find.text('Hot Craw'), findsOneWidget);
    expect(find.byIcon(Icons.phishing), findsOneWidget);
  });

  testWidgets('renders the personal photo when present', (tester) async {
    final sourcePath = writeSourceImage('a.jpg');
    final item = await seedAndAddEntry(tester, photoSourcePath: sourcePath);
    final harness = _DetailHarness();

    await harness.open(tester, item, repository, storage);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.phishing), findsNothing);
    expect(
      find.bySemanticsLabel('Oma kuva: Rapala X-Rap Shad XRS08'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the remove confirmation keeps the entry', (
    tester,
  ) async {
    final item = await seedAndAddEntry(tester);
    final harness = _DetailHarness();
    await harness.open(tester, item, repository, storage);

    await tester.tap(find.byKey(const Key('removeTackleBoxEntryButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Peruuta'));
    await tester.pumpAndSettle();

    expect(harness.removed, isNull);
    expect(find.byType(OwnedEntryDetailPage), findsOneWidget);
    expect(await repository.getById(item.id), isNotNull);
  });

  testWidgets('confirming remove deletes the entry and pops with true', (
    tester,
  ) async {
    final item = await seedAndAddEntry(tester);
    final harness = _DetailHarness();
    await harness.open(tester, item, repository, storage);

    await tester.tap(find.byKey(const Key('removeTackleBoxEntryButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poista'));
    await tester.pumpAndSettle();

    expect(harness.removed, isTrue);
    expect(find.byType(OwnedEntryDetailPage), findsNothing);
    expect(await repository.getById(item.id), isNull);
  });

  testWidgets(
    'a remove failure keeps the entry, shows an error, and re-enables the action',
    (tester) async {
      final sourcePath = writeSourceImage('a.jpg');
      final item = await seedAndAddEntry(tester, photoSourcePath: sourcePath);
      final failingStorage = _FailingDeleteStorage(
        rootDirectoryProvider: () async => tempDir,
      );
      failingStorage.failOn.add(item.personalPhotoRelativePath!);
      final failingRepository = PersonalTackleBoxRepository(
        database,
        failingStorage,
      );
      final harness = _DetailHarness();
      await harness.open(tester, item, failingRepository, failingStorage);

      await tester.tap(find.byKey(const Key('removeTackleBoxEntryButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poista'));
      await _pumpUntilSettledWithRealIO(tester);

      expect(harness.removed, isNull);
      expect(find.byType(OwnedEntryDetailPage), findsOneWidget);
      expect(
        find.text('Poistaminen epäonnistui. Yritä uudelleen.'),
        findsOneWidget,
      );
      expect(await failingRepository.getById(item.id), isNotNull);

      final removeButton = tester.widget<IconButton>(
        find.byKey(const Key('removeTackleBoxEntryButton')),
      );
      expect(removeButton.onPressed, isNotNull);
    },
  );
}
