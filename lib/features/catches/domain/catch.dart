import 'package:fishing_app/features/catches/domain/fish_species.dart';

class Catch {
  const Catch({
    required this.id,
    required this.fishingSpotId,
    required this.species,
    required this.caughtAt,
    required this.createdAt,
    required this.updatedAt,
    this.weightGrams,
    this.lengthMillimeters,
  }) : assert(
         weightGrams == null || weightGrams > 0,
         'weightGrams must be greater than zero when provided',
       ),
       assert(
         lengthMillimeters == null || lengthMillimeters > 0,
         'lengthMillimeters must be greater than zero when provided',
       );

  final String id;
  final String fishingSpotId;
  final FishSpecies species;
  final DateTime caughtAt;
  final int? weightGrams;
  final int? lengthMillimeters;
  final DateTime createdAt;
  final DateTime updatedAt;
}
