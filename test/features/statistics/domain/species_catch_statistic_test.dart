import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/fish_species.dart';
import 'package:fishing_app/features/statistics/domain/species_catch_statistic.dart';

void main() {
  test('constructs successfully with a positive catchCount', () {
    final statistic = SpeciesCatchStatistic(
      species: FishSpecies.pike,
      catchCount: 3,
    );
    expect(statistic.species, FishSpecies.pike);
    expect(statistic.catchCount, 3);
  });

  test('rejects a zero catchCount', () {
    expect(
      () => SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: 0),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a negative catchCount', () {
    expect(
      () => SpeciesCatchStatistic(species: FishSpecies.pike, catchCount: -1),
      throwsA(isA<AssertionError>()),
    );
  });
}
