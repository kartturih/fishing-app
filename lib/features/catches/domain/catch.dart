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
    this.lureVariantId,
  }) : assert(
         weightGrams == null || weightGrams > 0,
         'weightGrams must be greater than zero when provided',
       ),
       assert(
         lengthMillimeters == null || lengthMillimeters > 0,
         'lengthMillimeters must be greater than zero when provided',
       ),
       assert(
         lureVariantId == null || lureVariantId != '',
         'lureVariantId must not be empty when provided',
       );

  final String id;
  final String fishingSpotId;
  final FishSpecies species;
  final DateTime caughtAt;
  final int? weightGrams;
  final int? lengthMillimeters;
  final String? lureVariantId;
  final DateTime createdAt;
  final DateTime updatedAt;
}
