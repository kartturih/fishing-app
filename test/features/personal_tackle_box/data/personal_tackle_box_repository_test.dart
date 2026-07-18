import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';
import 'package:fishing_app/features/personal_tackle_box/data/personal_tackle_box_repository.dart';
import 'package:fishing_app/features/personal_tackle_box/data/storage/tackle_box_photo_storage.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/pending_tackle_box_photo.dart';

/// Fails [store] for every call, simulating a photo-processing failure
/// during [PersonalTackleBoxRepository.add]/`attachPhoto`.
class _FailingStoreStorage extends TackleBoxPhotoStorage {
  _FailingStoreStorage({required super.rootDirectoryProvider});

  @override
  Future<String> store({
    required String tackleBoxEntryId,
    required String sourcePath,
  }) {
    throw const TackleBoxPhotoStorageException('Simulated store failure.');
  }
}

/// Fails [delete] for any relative path in [failOn], otherwise behaves like
/// the real storage. Used to simulate a genuine file-deletion failure.
/// Mirrors `_FailingDeleteStorage` in catch_photo_repository_test.dart.
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

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late TackleBoxPhotoStorage storage;
  late PersonalTackleBoxRepository repository;

  Future<String> writeSourceImage(String name) async {
    final image = img.Image(width: 20, height: 15);
    img.fill(image, color: img.ColorRgb8(5, 5, 5));
    final file = File(p.join(tempDir.path, 'source', name));
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(img.encodeJpg(image));
    return file.path;
  }

  Future<String> writeCorruptSource(String name) async {
    final file = File(p.join(tempDir.path, 'source', name));
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(Uint8List.fromList(List<int>.filled(50, 0)));
    return file.path;
  }

  Future<LureCatalogEntry> seedCatalogVariant({
    String modelId = 'model-1',
    String variantId = 'variant-1',
    String manufacturer = 'Rapala',
    String modelName = 'X-Rap Shad XRS08',
    String colorName = 'Hot Craw',
  }) async {
    await database
        .into(database.lureModels)
        .insert(
          LureModelsCompanion.insert(
            id: modelId,
            manufacturer: manufacturer,
            modelName: modelName,
            lureType: 'crankbait',
            searchText: '$manufacturer $modelName'.toLowerCase(),
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await database
        .into(database.lureVariants)
        .insert(
          LureVariantsCompanion.insert(
            id: variantId,
            lureModelId: modelId,
            colorName: Value(colorName),
            searchText: colorName.toLowerCase(),
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );

    return LureCatalogEntry(
      variant: LureVariant(
        id: variantId,
        lureModelId: modelId,
        colorName: colorName,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
      manufacturer: manufacturer,
      modelName: modelName,
      lureType: 'crankbait',
      modelDefaultImageReference: null,
    );
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'personal_tackle_box_repository_test',
    );
    database = AppDatabase(NativeDatabase.memory());
    storage = TackleBoxPhotoStorage(rootDirectoryProvider: () async => tempDir);
    repository = PersonalTackleBoxRepository(database, storage);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('isOwned', () {
    test('returns false for a variant that has not been added', () async {
      final catalogEntry = await seedCatalogVariant();
      expect(await repository.isOwned(catalogEntry.id), isFalse);
    });

    test('returns true after the variant has been added', () async {
      final catalogEntry = await seedCatalogVariant();
      await repository.add(catalogEntry: catalogEntry);

      expect(await repository.isOwned(catalogEntry.id), isTrue);
    });
  });

  group('add', () {
    test('creates an entry with no photo', () async {
      final catalogEntry = await seedCatalogVariant();

      final result = await repository.add(catalogEntry: catalogEntry);

      expect(result.photoFailed, isFalse);
      expect(result.item.entry.lureVariantId, catalogEntry.id);
      expect(result.item.personalPhotoRelativePath, isNull);
      expect(result.item.catalogEntry.manufacturer, 'Rapala');

      final rows = await database.select(database.tackleBoxEntries).get();
      expect(rows, hasLength(1));
    });

    test('creates an entry with a photo', () async {
      final catalogEntry = await seedCatalogVariant();
      final sourcePath = await writeSourceImage('a.jpg');

      final result = await repository.add(
        catalogEntry: catalogEntry,
        pendingPhoto: PendingTackleBoxPhoto(sourcePath: sourcePath),
      );

      expect(result.photoFailed, isFalse);
      final relativePath = result.item.personalPhotoRelativePath;
      expect(relativePath, isNotNull);
      final file = await storage.resolve(relativePath!);
      expect(file.existsSync(), isTrue);
    });

    test(
      'still creates the entry and reports photoFailed when storage fails',
      () async {
        final failingStorage = _FailingStoreStorage(
          rootDirectoryProvider: () async => tempDir,
        );
        final repositoryWithFailingStorage = PersonalTackleBoxRepository(
          database,
          failingStorage,
        );
        final catalogEntry = await seedCatalogVariant();
        final sourcePath = await writeSourceImage('a.jpg');

        final result = await repositoryWithFailingStorage.add(
          catalogEntry: catalogEntry,
          pendingPhoto: PendingTackleBoxPhoto(sourcePath: sourcePath),
        );

        expect(result.photoFailed, isTrue);
        expect(result.item.personalPhotoRelativePath, isNull);

        final rows = await database.select(database.tackleBoxEntries).get();
        expect(rows, hasLength(1));
      },
    );

    test('still creates the entry when the source image is corrupt', () async {
      final catalogEntry = await seedCatalogVariant();
      final sourcePath = await writeCorruptSource('corrupt.jpg');

      final result = await repository.add(
        catalogEntry: catalogEntry,
        pendingPhoto: PendingTackleBoxPhoto(sourcePath: sourcePath),
      );

      expect(result.photoFailed, isTrue);
      expect(result.item.personalPhotoRelativePath, isNull);
    });

    test('rejects adding an already-owned variant', () async {
      final catalogEntry = await seedCatalogVariant();
      await repository.add(catalogEntry: catalogEntry);

      expect(
        () => repository.add(catalogEntry: catalogEntry),
        throwsA(isA<StateError>()),
      );

      final rows = await database.select(database.tackleBoxEntries).get();
      expect(rows, hasLength(1));
    });
  });

  group('getAll', () {
    test('returns an empty list when nothing is owned', () async {
      expect(await repository.getAll(), isEmpty);
    });

    test(
      'returns owned entries sorted manufacturer -> model -> variant id',
      () async {
        final westin = await seedCatalogVariant(
          modelId: 'model-westin',
          variantId: 'variant-westin',
          manufacturer: 'Westin',
          modelName: 'Swim',
          colorName: 'Official Roach',
        );
        final rapala = await seedCatalogVariant(
          modelId: 'model-rapala',
          variantId: 'variant-rapala',
          manufacturer: 'Rapala',
          modelName: 'X-Rap 10',
          colorName: 'Firetiger',
        );

        // Added in reverse of expected sort order.
        await repository.add(catalogEntry: westin);
        await repository.add(catalogEntry: rapala);

        final items = await repository.getAll();

        expect(items, hasLength(2));
        expect(items[0].catalogEntry.manufacturer, 'Rapala');
        expect(items[1].catalogEntry.manufacturer, 'Westin');
      },
    );

    test('includes an entry whose catalog variant is retired', () async {
      final catalogEntry = await seedCatalogVariant();
      await repository.add(catalogEntry: catalogEntry);

      await (database.update(
        database.lureVariants,
      )..where((t) => t.id.equals(catalogEntry.id))).write(
        LureVariantsCompanion(
          retiredAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      final items = await repository.getAll();
      expect(items, hasLength(1));
      expect(items.single.catalogEntry.id, catalogEntry.id);
    });
  });

  group('getById', () {
    test('returns the item for a known id', () async {
      final catalogEntry = await seedCatalogVariant();
      final result = await repository.add(catalogEntry: catalogEntry);

      final item = await repository.getById(result.item.id);

      expect(item, isNotNull);
      expect(item!.catalogEntry.manufacturer, 'Rapala');
    });

    test('returns null for an unknown id', () async {
      expect(await repository.getById('does-not-exist'), isNull);
    });
  });

  group('remove', () {
    test('deletes the row and its photo file', () async {
      final catalogEntry = await seedCatalogVariant();
      final sourcePath = await writeSourceImage('a.jpg');
      final result = await repository.add(
        catalogEntry: catalogEntry,
        pendingPhoto: PendingTackleBoxPhoto(sourcePath: sourcePath),
      );
      final relativePath = result.item.personalPhotoRelativePath!;

      await repository.remove(result.item.id);

      final rows = await database.select(database.tackleBoxEntries).get();
      expect(rows, isEmpty);
      final file = await storage.resolve(relativePath);
      expect(file.existsSync(), isFalse);
    });

    test('completes successfully for an unknown id', () async {
      await expectLater(repository.remove('does-not-exist'), completes);
    });

    test('preserves the row when file deletion genuinely fails', () async {
      final failingStorage = _FailingDeleteStorage(
        rootDirectoryProvider: () async => tempDir,
      );
      final repositoryWithFailingStorage = PersonalTackleBoxRepository(
        database,
        failingStorage,
      );
      final catalogEntry = await seedCatalogVariant();
      final sourcePath = await writeSourceImage('a.jpg');
      final result = await repositoryWithFailingStorage.add(
        catalogEntry: catalogEntry,
        pendingPhoto: PendingTackleBoxPhoto(sourcePath: sourcePath),
      );
      failingStorage.failOn.add(result.item.personalPhotoRelativePath!);

      await expectLater(
        repositoryWithFailingStorage.remove(result.item.id),
        throwsA(isA<TackleBoxPhotoStorageException>()),
      );

      final rows = await database.select(database.tackleBoxEntries).get();
      expect(rows, hasLength(1));
    });
  });

  group('attachPhoto', () {
    test('attaches a photo to an entry with none', () async {
      final catalogEntry = await seedCatalogVariant();
      final result = await repository.add(catalogEntry: catalogEntry);
      final sourcePath = await writeSourceImage('a.jpg');

      final updated = await repository.attachPhoto(
        tackleBoxEntryId: result.item.id,
        pendingPhoto: PendingTackleBoxPhoto(sourcePath: sourcePath),
      );

      expect(updated.personalPhotoRelativePath, isNotNull);
      final stored = await repository.getById(result.item.id);
      expect(stored!.personalPhotoRelativePath, isNotNull);
    });

    test('rejects a second call on the same entry', () async {
      final catalogEntry = await seedCatalogVariant();
      final result = await repository.add(catalogEntry: catalogEntry);
      final sourcePath = await writeSourceImage('a.jpg');
      await repository.attachPhoto(
        tackleBoxEntryId: result.item.id,
        pendingPhoto: PendingTackleBoxPhoto(sourcePath: sourcePath),
      );

      expect(
        () => repository.attachPhoto(
          tackleBoxEntryId: result.item.id,
          pendingPhoto: PendingTackleBoxPhoto(sourcePath: sourcePath),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects an unknown tackleBoxEntryId', () async {
      final sourcePath = await writeSourceImage('a.jpg');

      expect(
        () => repository.attachPhoto(
          tackleBoxEntryId: 'does-not-exist',
          pendingPhoto: PendingTackleBoxPhoto(sourcePath: sourcePath),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
