import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/data/catch_mapper.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';

class CatchRepository {
  CatchRepository(this._database, [this._mapper = const CatchMapper()]);

  final AppDatabase _database;
  final CatchMapper _mapper;

  Future<Catch> create({
    required String fishingSpotId,
    required FishSpecies species,
    required DateTime caughtAt,
    int? weightGrams,
    int? lengthMillimeters,
  }) async {
    if (fishingSpotId.isEmpty) {
      throw ArgumentError.value(
        fishingSpotId,
        'fishingSpotId',
        'must not be empty',
      );
    }
    _validateMeasurements(
      weightGrams: weightGrams,
      lengthMillimeters: lengthMillimeters,
    );

    final now = DateTime.now();
    final catchModel = Catch(
      id: _generateId(),
      fishingSpotId: fishingSpotId,
      species: species,
      caughtAt: caughtAt,
      weightGrams: weightGrams,
      lengthMillimeters: lengthMillimeters,
      createdAt: now,
      updatedAt: now,
    );

    await _database
        .into(_database.catches)
        .insert(_mapper.toCompanion(catchModel));
    return catchModel;
  }

  Future<Catch> update({
    required Catch catchModel,
    required FishSpecies species,
    required DateTime caughtAt,
    int? weightGrams,
    int? lengthMillimeters,
  }) async {
    _validateMeasurements(
      weightGrams: weightGrams,
      lengthMillimeters: lengthMillimeters,
    );

    final updatedCatch = Catch(
      id: catchModel.id,
      fishingSpotId: catchModel.fishingSpotId,
      species: species,
      caughtAt: caughtAt,
      weightGrams: weightGrams,
      lengthMillimeters: lengthMillimeters,
      createdAt: catchModel.createdAt,
      updatedAt: DateTime.now(),
    );

    await _database
        .update(_database.catches)
        .replace(_mapper.toCompanion(updatedCatch));
    return updatedCatch;
  }

  Future<void> delete(String catchId) async {
    if (catchId.isEmpty) {
      throw ArgumentError.value(catchId, 'catchId', 'must not be empty');
    }

    await (_database.delete(
      _database.catches,
    )..where((t) => t.id.equals(catchId))).go();
  }

  Future<List<Catch>> getByFishingSpotId(String fishingSpotId) async {
    final query = _database.select(_database.catches)
      ..where((t) => t.fishingSpotId.equals(fishingSpotId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.caughtAt),
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);

    final rows = await query.get();
    return [for (final row in rows) _mapper.toDomain(row)];
  }

  Future<Catch?> getById(String id) async {
    final row = await (_database.select(
      _database.catches,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    return row == null ? null : _mapper.toDomain(row);
  }

  void _validateMeasurements({
    required int? weightGrams,
    required int? lengthMillimeters,
  }) {
    if (weightGrams != null && weightGrams <= 0) {
      throw ArgumentError.value(
        weightGrams,
        'weightGrams',
        'must be greater than zero',
      );
    }
    if (lengthMillimeters != null && lengthMillimeters <= 0) {
      throw ArgumentError.value(
        lengthMillimeters,
        'lengthMillimeters',
        'must be greater than zero',
      );
    }
  }

  String _generateId() => 'catch-${DateTime.now().microsecondsSinceEpoch}';
}
