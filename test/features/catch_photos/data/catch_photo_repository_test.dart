import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catch_photos/data/storage/catch_photo_storage.dart';
import 'package:fishing_app/features/catch_photos/domain/catch_photo_limits.dart';
import 'package:fishing_app/features/catch_photos/domain/pending_catch_photo.dart';
import 'package:fishing_app/features/catches/data/catch_repository.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/fishing_spots/data/fishing_spot_repository.dart';

/// Returns a fixed id on every call, used to force a primary-key collision so
/// the database insert fails after the file has already been written.
class _FixedUuid extends Uuid {
  const _FixedUuid(this.fixedId);

  final String fixedId;

  @override
  String v4({Map<String, dynamic>? options, V4Options? config}) => fixedId;
}

/// Fails [delete] for any relative path in [failOn], otherwise behaves like
/// the real storage. Used to simulate a genuine file-deletion failure.
class _FailingDeleteStorage extends CatchPhotoStorage {
  _FailingDeleteStorage({required super.rootDirectoryProvider});

  final Set<String> failOn = {};

  @override
  Future<void> delete(String relativePath) async {
    if (failOn.contains(relativePath)) {
      throw const CatchPhotoStorageException('Simulated deletion failure.');
    }
    return super.delete(relativePath);
  }
}

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late CatchPhotoStorage storage;
  late CatchPhotoRepository repository;
  late FishingSpotRepository fishingSpotRepository;
  late CatchRepository catchRepository;
  late String catchId;

  Future<String> writeSourceImage(
    String name, {
    int width = 20,
    int height = 15,
  }) async {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(5, 5, 5));
    final file = File(p.join(tempDir.path, 'source', name));
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(img.encodeJpg(image));
    return file.path;
  }

  Future<String> writeCorruptSource(String name) async {
    final file = File(p.join(tempDir.path, 'source', name));
    file.parent.createSync(recursive: true);
    await file.writeAsBytes(List<int>.filled(200, 0));
    return file.path;
  }

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('catch_photo_repository');
    database = AppDatabase(NativeDatabase.memory());
    await database
        .into(database.waterBodies)
        .insert(
          WaterBodiesCompanion.insert(
            id: 'water-body-1',
            name: 'Test Water Body',
            createdAt: 0,
          ),
        );
    storage = CatchPhotoStorage(rootDirectoryProvider: () async => tempDir);
    repository = CatchPhotoRepository(database, storage);
    fishingSpotRepository = FishingSpotRepository(database);
    catchRepository = CatchRepository(database);

    final fishingSpot = await fishingSpotRepository.create(
      name: 'Test Spot',
      latitude: 61.0,
      longitude: 25.0,
      waterBodyId: 'water-body-1',
    );
    final createdCatch = await catchRepository.create(
      fishingSpotId: fishingSpot.id,
      species: FishSpecies.pike,
      caughtAt: DateTime(2026, 7, 17),
    );
    catchId = createdCatch.id;
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('getByCatchId', () {
    test('returns an empty list for a Catch with no photos', () async {
      expect(await repository.getByCatchId(catchId), isEmpty);
    });

    test('returns photos for a Catch in stable order', () async {
      final first = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('a.jpg'),
        ),
      );
      final second = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('b.jpg'),
        ),
      );

      final photos = await repository.getByCatchId(catchId);

      expect(photos.map((p) => p.id).toList(), [first.id, second.id]);
      expect(photos[0].sortOrder, lessThan(photos[1].sortOrder));
    });

    test('only returns photos for the requested Catch', () async {
      // Identifiers are derived from DateTime.now().microsecondsSinceEpoch; a
      // tiny delay avoids colliding with the Catch created in setUp.
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final otherSpot = await fishingSpotRepository.create(
        name: 'Other Spot',
        latitude: 60.0,
        longitude: 24.0,
        waterBodyId: 'water-body-1',
      );
      final otherCatch = await catchRepository.create(
        fishingSpotId: otherSpot.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 7, 16),
      );

      await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('a.jpg'),
        ),
      );
      await repository.add(
        catchId: otherCatch.id,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('b.jpg'),
        ),
      );

      final photos = await repository.getByCatchId(catchId);
      final otherPhotos = await repository.getByCatchId(otherCatch.id);

      expect(photos, hasLength(1));
      expect(otherPhotos, hasLength(1));
      expect(photos.single.catchId, catchId);
      expect(otherPhotos.single.catchId, otherCatch.id);
    });

    test('rejects an empty catchId', () async {
      expect(() => repository.getByCatchId(''), throwsArgumentError);
    });
  });

  group('add', () {
    test('persists a single photo', () async {
      final photo = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('a.jpg'),
        ),
      );

      expect(photo.catchId, catchId);
      expect(photo.sortOrder, 0);
      final stored = await repository.getByCatchId(catchId);
      expect(stored, hasLength(1));
      expect(stored.single.id, photo.id);
    });

    test('assigns unique, stable IDs across multiple photos', () async {
      final first = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('a.jpg'),
        ),
      );
      final second = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('b.jpg'),
        ),
      );

      expect(first.id, isNotEmpty);
      expect(second.id, isNotEmpty);
      expect(first.id, isNot(second.id));
    });

    test('assigns the next sort order after existing photos', () async {
      final first = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('a.jpg'),
        ),
      );
      final second = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('b.jpg'),
        ),
      );

      expect(first.sortOrder, 0);
      expect(second.sortOrder, 1);
    });

    test('rejects a sixth photo once the maximum is reached', () async {
      for (var i = 0; i < maxCatchPhotos; i++) {
        await repository.add(
          catchId: catchId,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: await writeSourceImage('$i.jpg'),
          ),
        );
      }

      expect(
        () => repository.add(
          catchId: catchId,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: 'unused-because-limit-checked-first.jpg',
          ),
        ),
        throwsStateError,
      );
      expect(await repository.getByCatchId(catchId), hasLength(maxCatchPhotos));
    });

    test('creates no database row when file processing fails', () async {
      await expectLater(
        repository.add(
          catchId: catchId,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: await writeCorruptSource('corrupt.jpg'),
          ),
        ),
        throwsA(isA<CatchPhotoDecodeException>()),
      );

      expect(await repository.getByCatchId(catchId), isEmpty);
    });

    test('removes the stored file when the database insert fails', () async {
      const collidingId = 'fixed-id';
      final collidingRepository = CatchPhotoRepository(
        database,
        storage,
        uuid: const _FixedUuid(collidingId),
      );
      // Occupy the id with a photo on a different catch first. A tiny delay
      // avoids the new Catch id colliding with the one created in setUp
      // (ids are derived from DateTime.now().microsecondsSinceEpoch).
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final otherSpot = await fishingSpotRepository.create(
        name: 'Other Spot',
        latitude: 60.0,
        longitude: 24.0,
        waterBodyId: 'water-body-1',
      );
      final otherCatch = await catchRepository.create(
        fishingSpotId: otherSpot.id,
        species: FishSpecies.zander,
        caughtAt: DateTime(2026, 7, 16),
      );
      await collidingRepository.add(
        catchId: otherCatch.id,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('first.jpg'),
        ),
      );

      await expectLater(
        collidingRepository.add(
          catchId: catchId,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: await writeSourceImage('second.jpg'),
          ),
        ),
        throwsA(anything),
      );

      // No row was created for this catch, and the file that was written
      // for the failed attempt was cleaned up.
      expect(await repository.getByCatchId(catchId), isEmpty);
      final leftoverFile = File(
        p.join(tempDir.path, 'catch_photos', catchId, '$collidingId.jpg'),
      );
      expect(leftoverFile.existsSync(), isFalse);

      // The pre-existing photo on the other catch is untouched.
      expect(await repository.getByCatchId(otherCatch.id), hasLength(1));
    });

    test('rejects an empty catchId', () async {
      expect(
        () => repository.add(
          catchId: '',
          pendingPhoto: const PendingCatchPhoto(sourcePath: 'unused.jpg'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('addMany', () {
    test('returns an empty result for empty input', () async {
      final result = await repository.addMany(
        catchId: catchId,
        pendingPhotos: const [],
      );

      expect(result.added, isEmpty);
      expect(result.failedCount, 0);
      expect(result.hasFailures, isFalse);
    });

    test('adds multiple photos with the correct Catch association', () async {
      final result = await repository.addMany(
        catchId: catchId,
        pendingPhotos: [
          PendingCatchPhoto(sourcePath: await writeSourceImage('a.jpg')),
          PendingCatchPhoto(sourcePath: await writeSourceImage('b.jpg')),
        ],
      );

      expect(result.added, hasLength(2));
      expect(result.failedCount, 0);
      for (final photo in result.added) {
        expect(photo.catchId, catchId);
      }
    });

    test('reports partial success when one photo fails to process', () async {
      final result = await repository.addMany(
        catchId: catchId,
        pendingPhotos: [
          PendingCatchPhoto(sourcePath: await writeSourceImage('a.jpg')),
          PendingCatchPhoto(sourcePath: await writeCorruptSource('bad.jpg')),
          PendingCatchPhoto(sourcePath: await writeSourceImage('b.jpg')),
        ],
      );

      expect(result.added, hasLength(2));
      expect(result.failedCount, 1);
      expect(result.hasFailures, isTrue);
      expect(await repository.getByCatchId(catchId), hasLength(2));
    });

    test(
      'truncates to the remaining capacity and counts the rest as failed',
      () async {
        final pending = [
          for (var i = 0; i < maxCatchPhotos + 2; i++)
            PendingCatchPhoto(sourcePath: await writeSourceImage('$i.jpg')),
        ];

        final result = await repository.addMany(
          catchId: catchId,
          pendingPhotos: pending,
        );

        expect(result.added, hasLength(maxCatchPhotos));
        expect(result.failedCount, 2);
        expect(
          await repository.getByCatchId(catchId),
          hasLength(maxCatchPhotos),
        );
      },
    );

    test('rejects an empty catchId', () async {
      expect(
        () => repository.addMany(catchId: '', pendingPhotos: const []),
        throwsArgumentError,
      );
    });
  });

  group('delete', () {
    test('deletes an existing photo and its file', () async {
      final photo = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('a.jpg'),
        ),
      );
      final file = await repository.resolveFile(photo);
      expect(file.existsSync(), isTrue);

      await repository.delete(photo.id);

      expect(await repository.getByCatchId(catchId), isEmpty);
      expect(file.existsSync(), isFalse);
    });

    test('completes successfully for a missing photo row', () async {
      await expectLater(repository.delete('does-not-exist'), completes);
    });

    test('removes the row when its file is already missing on disk', () async {
      final photo = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('a.jpg'),
        ),
      );
      final file = await repository.resolveFile(photo);
      file.deleteSync();

      await expectLater(repository.delete(photo.id), completes);
      expect(await repository.getByCatchId(catchId), isEmpty);
    });

    test(
      'preserves the row when a genuine file-deletion failure occurs',
      () async {
        final failingStorage = _FailingDeleteStorage(
          rootDirectoryProvider: () async => tempDir,
        );
        final failingRepository = CatchPhotoRepository(
          database,
          failingStorage,
        );
        final photo = await failingRepository.add(
          catchId: catchId,
          pendingPhoto: PendingCatchPhoto(
            sourcePath: await writeSourceImage('a.jpg'),
          ),
        );
        failingStorage.failOn.add(photo.relativePath);

        await expectLater(
          failingRepository.delete(photo.id),
          throwsA(isA<CatchPhotoStorageException>()),
        );

        expect(await repository.getByCatchId(catchId), hasLength(1));
      },
    );

    test('rejects an empty photoId', () async {
      expect(() => repository.delete(''), throwsArgumentError);
    });
  });

  group('deleteFilesForCatch', () {
    test('removes files but keeps the CatchPhoto rows', () async {
      final first = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('a.jpg'),
        ),
      );
      final second = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('b.jpg'),
        ),
      );
      final firstFile = await repository.resolveFile(first);
      final secondFile = await repository.resolveFile(second);

      await repository.deleteFilesForCatch(catchId);

      expect(firstFile.existsSync(), isFalse);
      expect(secondFile.existsSync(), isFalse);
      final remaining = await repository.getByCatchId(catchId);
      expect(remaining.map((p) => p.id), [first.id, second.id]);
    });

    test('completes successfully for a Catch with no photos', () async {
      await expectLater(repository.deleteFilesForCatch(catchId), completes);
    });

    test('rejects an empty catchId', () async {
      expect(() => repository.deleteFilesForCatch(''), throwsArgumentError);
    });
  });

  group('deleteAllForCatch', () {
    test('removes all photos and files for a Catch with photos', () async {
      final first = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('a.jpg'),
        ),
      );
      final second = await repository.add(
        catchId: catchId,
        pendingPhoto: PendingCatchPhoto(
          sourcePath: await writeSourceImage('b.jpg'),
        ),
      );
      final firstFile = await repository.resolveFile(first);
      final secondFile = await repository.resolveFile(second);

      await repository.deleteAllForCatch(catchId);

      expect(await repository.getByCatchId(catchId), isEmpty);
      expect(firstFile.existsSync(), isFalse);
      expect(secondFile.existsSync(), isFalse);
    });

    test('completes successfully for a Catch with no photos', () async {
      await expectLater(repository.deleteAllForCatch(catchId), completes);
    });

    test('rejects an empty catchId', () async {
      expect(() => repository.deleteAllForCatch(''), throwsArgumentError);
    });
  });
}
