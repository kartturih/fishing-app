import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/map/style_restoration_tracker.dart';

void main() {
  test('initial state: applied is 0, nothing restored yet', () {
    final tracker = StyleRestorationTracker();
    expect(tracker.applied, 0);
    expect(tracker.isRestoredForCurrentGeneration, isFalse);
  });

  test('initial load: markRestored(0) is accepted for the initial style', () {
    final tracker = StyleRestorationTracker();
    tracker.markRestored(0);
    expect(tracker.isRestoredForCurrentGeneration, isTrue);
  });

  test('repeated switching: each applied style is restored once', () {
    final tracker = StyleRestorationTracker();
    tracker.markRestored(0);

    final gen1 = tracker.recordStyleApplied();
    expect(tracker.isRestoredForCurrentGeneration, isFalse);
    tracker.markRestored(gen1);
    expect(tracker.isRestoredForCurrentGeneration, isTrue);

    final gen2 = tracker.recordStyleApplied();
    expect(tracker.isRestoredForCurrentGeneration, isFalse);
    tracker.markRestored(gen2);
    expect(tracker.isRestoredForCurrentGeneration, isTrue);
  });

  test('a duplicate callback for the same already-restored generation is a '
      'harmless no-op (guards against a duplicate-add crash)', () {
    final tracker = StyleRestorationTracker();
    final gen = tracker.recordStyleApplied();
    tracker.markRestored(gen);
    expect(tracker.isRestoredForCurrentGeneration, isTrue);

    // Simulate onStyleLoadedCallback firing again for the same style.
    tracker.markRestored(gen);
    expect(tracker.isRestoredForCurrentGeneration, isTrue);
  });

  test('the exact race: a delayed callback captured for an older generation '
      'cannot satisfy the restoration guard for the newer style actually '
      'applied', () {
    final tracker = StyleRestorationTracker();

    // Maastokartta -> Ilmakuva requested; its style is applied.
    final ilmakuvaGeneration = tracker.recordStyleApplied();

    // Before Ilmakuva's own markers are restored, a *second* switch
    // (Ilmakuva -> Maastokartta) is requested and its style is also
    // applied -- e.g. the user switched again very quickly.
    final maastokarttaGeneration = tracker.recordStyleApplied();
    expect(maastokarttaGeneration, isNot(ilmakuvaGeneration));

    // A delayed onStyleLoadedCallback belonging to the *first* switch
    // (Ilmakuva) now finally fires and tries to mark its own, older
    // generation as restored.
    tracker.markRestored(ilmakuvaGeneration);

    // It must NOT satisfy the guard for the style that is actually
    // applied now (Maastokartta) -- otherwise that style's own, real
    // callback would be skipped as "already restored" and its markers
    // would never be added.
    expect(tracker.isRestoredForCurrentGeneration, isFalse);

    // The real callback for the currently-applied style then runs and
    // correctly marks it restored.
    tracker.markRestored(maastokarttaGeneration);
    expect(tracker.isRestoredForCurrentGeneration, isTrue);
  });

  test('the initial generation (0) is governed by exactly the same '
      'isStale/markRestored contract as any later generation — a slow '
      'initial style load must converge the same way a switch does, with '
      'no special-casing by generation number (physical-device regression: '
      'markers appeared after a switch but not on first launch)', () {
    final tracker = StyleRestorationTracker();

    // Generation 0 is applied from construction: MapScreen's initial load
    // never calls recordStyleApplied() for it (see _initializeBaseMap).
    expect(tracker.applied, 0);
    expect(tracker.isStale(0), isFalse);
    expect(tracker.isRestoredForCurrentGeneration, isFalse);

    // Many failed convergence attempts against generation 0 (as a slow
    // cold start would produce) do not change tracker state on their own.
    expect(tracker.isStale(0), isFalse);
    expect(tracker.isRestoredForCurrentGeneration, isFalse);

    tracker.markRestored(0);
    expect(tracker.isRestoredForCurrentGeneration, isTrue);

    // A later switch bumps the generation; the exact same contract governs
    // it — generation 0 was never a special case.
    final gen1 = tracker.recordStyleApplied();
    expect(tracker.isStale(0), isTrue);
    expect(tracker.isRestoredForCurrentGeneration, isFalse);
    tracker.markRestored(gen1);
    expect(tracker.isRestoredForCurrentGeneration, isTrue);
  });

  test('isStale reports true only once a newer style has been applied', () {
    final tracker = StyleRestorationTracker();
    final gen = tracker.recordStyleApplied();

    expect(tracker.isStale(gen), isFalse);

    tracker.recordStyleApplied();
    expect(tracker.isStale(gen), isTrue);
  });

  test('rapid switching does not create duplicates: only the final generation '
      'ever gets marked restored, regardless of how many were applied in '
      'between', () {
    final tracker = StyleRestorationTracker();
    tracker.markRestored(0);

    int? lastGeneration;
    for (var i = 0; i < 5; i++) {
      lastGeneration = tracker.recordStyleApplied();
    }
    // Only the callback for the final, currently-applied generation
    // should be able to mark restoration complete.
    for (var i = 0; i < lastGeneration!; i++) {
      tracker.markRestored(i);
      expect(tracker.isRestoredForCurrentGeneration, isFalse);
    }
    tracker.markRestored(lastGeneration);
    expect(tracker.isRestoredForCurrentGeneration, isTrue);
  });

  group('FishingSpotLayerPresence', () {
    const sourceId = 'fishing-spots-source';
    const circleLayerId = 'fishing-spots-circle-layer';
    const symbolLayerId = 'fishing-spots-symbol-layer';

    FishingSpotLayerPresence presenceFrom({
      Iterable<String> sourceIds = const [],
      Iterable<String> layerIds = const [],
    }) {
      return FishingSpotLayerPresence.from(
        sourceIds: sourceIds,
        layerIds: layerIds,
        sourceId: sourceId,
        circleLayerId: circleLayerId,
        symbolLayerId: symbolLayerId,
      );
    }

    test('nothing present: not complete, and only the source should be '
        'attempted first (layers depend on it)', () {
      final presence = presenceFrom();

      expect(presence.isComplete, isFalse);
      expect(presence.shouldAddSource, isTrue);
      expect(presence.shouldAddCircleLayer, isFalse);
      expect(presence.shouldAddSymbolLayer, isFalse);
    });

    test('partial state: source exists, both layers missing -- not complete, '
        'both layers (now unblocked by the source) should be attempted', () {
      final presence = presenceFrom(sourceIds: [sourceId]);

      expect(presence.isComplete, isFalse);
      expect(presence.shouldAddSource, isFalse);
      expect(presence.shouldAddCircleLayer, isTrue);
      expect(presence.shouldAddSymbolLayer, isTrue);
    });

    test('partial state: source and circle layer exist, only the symbol '
        'layer (the label) is missing -- not complete, only the missing '
        'layer should be attempted', () {
      final presence = presenceFrom(
        sourceIds: [sourceId],
        layerIds: [circleLayerId],
      );

      expect(presence.isComplete, isFalse);
      expect(presence.shouldAddSource, isFalse);
      expect(presence.shouldAddCircleLayer, isFalse);
      expect(presence.shouldAddSymbolLayer, isTrue);
    });

    test('converging: nothing -> source only -> source + circle -> complete, '
        'each step attempting only what the previous step left missing', () {
      final step1 = presenceFrom();
      expect(step1.shouldAddSource, isTrue);

      final step2 = presenceFrom(sourceIds: [sourceId]);
      expect(step2.shouldAddSource, isFalse);
      expect(step2.shouldAddCircleLayer, isTrue);
      expect(step2.shouldAddSymbolLayer, isTrue);

      final step3 = presenceFrom(
        sourceIds: [sourceId],
        layerIds: [circleLayerId],
      );
      expect(step3.shouldAddCircleLayer, isFalse);
      expect(step3.shouldAddSymbolLayer, isTrue);

      final step4 = presenceFrom(
        sourceIds: [sourceId],
        layerIds: [circleLayerId, symbolLayerId],
      );
      expect(step4.isComplete, isTrue);
    });

    test(
      'complete state: everything present -- isComplete is true and '
      'nothing should be (re-)attempted, preventing a duplicate-add error',
      () {
        final presence = presenceFrom(
          sourceIds: [sourceId],
          layerIds: [circleLayerId, symbolLayerId],
        );

        expect(presence.isComplete, isTrue);
        expect(presence.shouldAddSource, isFalse);
        expect(presence.shouldAddCircleLayer, isFalse);
        expect(presence.shouldAddSymbolLayer, isFalse);
      },
    );

    test('unrelated source/layer ids from other styles are ignored', () {
      final presence = presenceFrom(
        sourceIds: ['mml-base-source'],
        layerIds: ['mml-base-layer'],
      );

      expect(presence.hasSource, isFalse);
      expect(presence.hasCircleLayer, isFalse);
      expect(presence.hasSymbolLayer, isFalse);
      expect(presence.isComplete, isFalse);
    });
  });
}
