import 'package:drift/drift.dart';

import 'package:fishing_app/core/database/app_database.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';

class CatchMapper {
  const CatchMapper();

  Catch toDomain(CatchEntity row) {
    return Catch(
      id: row.id,
      fishingSpotId: row.fishingSpotId,
      species: _speciesFromStored(row.species),
      caughtAt: DateTime.fromMillisecondsSinceEpoch(row.caughtAt),
      weightGrams: row.weightGrams,
      lengthMillimeters: row.lengthMillimeters,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  CatchesCompanion toCompanion(Catch catchModel) {
    return CatchesCompanion.insert(
      id: catchModel.id,
      fishingSpotId: catchModel.fishingSpotId,
      species: catchModel.species.name,
      caughtAt: catchModel.caughtAt.millisecondsSinceEpoch,
      weightGrams: Value(catchModel.weightGrams),
      lengthMillimeters: Value(catchModel.lengthMillimeters),
      createdAt: catchModel.createdAt.millisecondsSinceEpoch,
      updatedAt: catchModel.updatedAt.millisecondsSinceEpoch,
    );
  }

  FishSpecies _speciesFromStored(String storedValue) {
    return FishSpecies.values.firstWhere(
      (species) => species.name == storedValue,
      orElse: () => throw StateError('Unsupported fish species: $storedValue'),
    );
  }
}
