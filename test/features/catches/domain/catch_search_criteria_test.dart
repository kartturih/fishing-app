import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/catches/domain/catch_search_criteria.dart';
import 'package:fishing_app/features/catches/domain/fish_species.dart';

void main() {
  group('CatchSearchCriteria.isEmpty / hasActiveFilters', () {
    test('default/empty criteria is empty and has no active filters', () {
      const criteria = CatchSearchCriteria.empty;

      expect(criteria.isEmpty, isTrue);
      expect(criteria.hasActiveFilters, isFalse);
      expect(criteria.query, '');
    });

    test('a non-empty query makes isEmpty false, but is not a filter', () {
      const criteria = CatchSearchCriteria(query: 'hauki');

      expect(criteria.isEmpty, isFalse);
      expect(criteria.hasActiveFilters, isFalse);
    });

    test('an active waterBodyId filter is detected', () {
      const criteria = CatchSearchCriteria(waterBodyId: 'water-body-1');

      expect(criteria.isEmpty, isFalse);
      expect(criteria.hasActiveFilters, isTrue);
    });

    test('an active species filter is detected', () {
      const criteria = CatchSearchCriteria(species: FishSpecies.pike);

      expect(criteria.isEmpty, isFalse);
      expect(criteria.hasActiveFilters, isTrue);
    });

    test('an active lureVariantId filter is detected', () {
      const criteria = CatchSearchCriteria(lureVariantId: 'variant-1');

      expect(criteria.isEmpty, isFalse);
      expect(criteria.hasActiveFilters, isTrue);
    });

    test('an active dateFrom filter alone is detected', () {
      final criteria = CatchSearchCriteria(dateFrom: DateTime(2026, 1, 1));

      expect(criteria.isEmpty, isFalse);
      expect(criteria.hasActiveFilters, isTrue);
    });

    test('an active dateTo filter alone is detected', () {
      final criteria = CatchSearchCriteria(dateTo: DateTime(2026, 12, 31));

      expect(criteria.isEmpty, isFalse);
      expect(criteria.hasActiveFilters, isTrue);
    });
  });

  group('CatchSearchCriteria.copyWith', () {
    test('leaves every field unchanged when nothing is passed', () {
      final original = CatchSearchCriteria(
        query: 'hauki',
        waterBodyId: 'water-body-1',
        species: FishSpecies.pike,
        lureVariantId: 'variant-1',
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 12, 31),
      );

      final copy = original.copyWith();

      expect(copy, original);
    });

    test('updates only the query, preserving every filter', () {
      const original = CatchSearchCriteria(
        query: 'hauki',
        waterBodyId: 'water-body-1',
      );

      final copy = original.copyWith(query: 'kuha');

      expect(copy.query, 'kuha');
      expect(copy.waterBodyId, 'water-body-1');
    });

    test('explicitly clears a nullable filter field via an explicit null', () {
      const original = CatchSearchCriteria(waterBodyId: 'water-body-1');

      final copy = original.copyWith(waterBodyId: null);

      expect(copy.waterBodyId, isNull);
    });

    test('distinguishes "not passed" (unchanged) from "explicitly cleared" for '
        'every nullable field', () {
      final original = CatchSearchCriteria(
        species: FishSpecies.pike,
        lureVariantId: 'variant-1',
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 12, 31),
      );

      // Passing no filter parameters at all must leave every field as-is.
      final unchanged = original.copyWith(query: 'kuha');
      expect(unchanged.species, FishSpecies.pike);
      expect(unchanged.lureVariantId, 'variant-1');
      expect(unchanged.dateFrom, DateTime(2026, 1, 1));
      expect(unchanged.dateTo, DateTime(2026, 12, 31));

      // Explicitly passing null clears just that one field.
      final speciesCleared = original.copyWith(species: null);
      expect(speciesCleared.species, isNull);
      expect(speciesCleared.lureVariantId, 'variant-1');
    });

    test('replaces one filter with a new value without affecting others', () {
      const original = CatchSearchCriteria(
        waterBodyId: 'water-body-1',
        lureVariantId: 'variant-1',
      );

      final copy = original.copyWith(waterBodyId: 'water-body-2');

      expect(copy.waterBodyId, 'water-body-2');
      expect(copy.lureVariantId, 'variant-1');
    });

    test('original instance is never mutated by copyWith', () {
      const original = CatchSearchCriteria(query: 'hauki');

      original.copyWith(query: 'kuha');

      expect(original.query, 'hauki');
    });
  });

  group('CatchSearchCriteria.clearFilters', () {
    test('clears every filter but preserves the query', () {
      final original = CatchSearchCriteria(
        query: 'hauki',
        waterBodyId: 'water-body-1',
        species: FishSpecies.pike,
        lureVariantId: 'variant-1',
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 12, 31),
      );

      final cleared = original.clearFilters();

      expect(cleared.query, 'hauki');
      expect(cleared.hasActiveFilters, isFalse);
      expect(cleared.waterBodyId, isNull);
      expect(cleared.species, isNull);
      expect(cleared.lureVariantId, isNull);
      expect(cleared.dateFrom, isNull);
      expect(cleared.dateTo, isNull);
    });

    test('clearing filters on already-filterless criteria is a no-op', () {
      const original = CatchSearchCriteria(query: 'hauki');

      final cleared = original.clearFilters();

      expect(cleared, original);
    });
  });

  group('CatchSearchCriteria equality', () {
    test('two criteria with identical fields are equal', () {
      final a = CatchSearchCriteria(
        query: 'hauki',
        waterBodyId: 'water-body-1',
        species: FishSpecies.pike,
        lureVariantId: 'variant-1',
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 12, 31),
      );
      final b = CatchSearchCriteria(
        query: 'hauki',
        waterBodyId: 'water-body-1',
        species: FishSpecies.pike,
        lureVariantId: 'variant-1',
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 12, 31),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing in query makes two criteria unequal', () {
      const a = CatchSearchCriteria(query: 'hauki');
      const b = CatchSearchCriteria(query: 'kuha');

      expect(a, isNot(b));
    });

    test(
      'differing in exactly one filter field makes two criteria unequal',
      () {
        const a = CatchSearchCriteria(waterBodyId: 'water-body-1');
        const b = CatchSearchCriteria(waterBodyId: 'water-body-2');

        expect(a, isNot(b));
      },
    );

    test('the static empty constant equals a freshly constructed default', () {
      expect(const CatchSearchCriteria(), CatchSearchCriteria.empty);
    });
  });
}
