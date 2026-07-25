/// Tracks which style-application "generation" application-owned map
/// content (fishing-spot markers/layers) has been restored for.
///
/// `onStyleLoadedCallback` must only be allowed to mark restoration
/// complete for the style generation that is *actually applied* to
/// MapLibreMap at the moment it fires — never for whichever generation
/// happened to be the latest *requested* when the callback fired. Those
/// two moments can drift apart: a base-map switch bumps "requested" the
/// instant the user picks a choice, but the corresponding style file still
/// has to be prepared (async I/O) before it is actually handed to
/// `MapLibreMap`. A delayed/stale callback captured against the "requested"
/// counter could therefore satisfy the guard for a style that was never
/// really applied, causing the style that *is* actually active to have its
/// own restoration silently skipped.
///
/// Kept as a small, standalone, MapLibre-independent class (two integers
/// and four narrow methods) specifically so this race can be unit-tested
/// without a real native map surface — not a general map-layer framework.
class StyleRestorationTracker {
  int _applied = 0;
  int _restoredFor = -1;

  /// The generation of the style currently applied (i.e. actually handed
  /// to `MapLibreMap` via its `styleString`).
  int get applied => _applied;

  /// Call the moment a new style is actually applied to `MapLibreMap` —
  /// inside the same `setState` that changes `styleString` — never merely
  /// because a switch was *requested*. Returns the new generation.
  int recordStyleApplied() => ++_applied;

  /// Whether markers have already been restored for the generation
  /// currently applied. `onStyleLoadedCallback` should skip its work when
  /// this is true, to avoid a duplicate-add crash from a repeated or stale
  /// callback for a style that was already handled.
  bool get isRestoredForCurrentGeneration => _restoredFor == _applied;

  /// Marks restoration complete for [generation] — but only if it is still
  /// the currently-applied generation. A delayed callback that captured an
  /// older generation number must not be able to satisfy this guard for
  /// whatever style is actually active by the time its own async work
  /// finishes.
  void markRestored(int generation) {
    if (generation == _applied) {
      _restoredFor = generation;
    }
  }

  /// Whether in-flight async work captured for [generation] is now stale —
  /// a newer style has since been applied, so that work's result should be
  /// discarded rather than acted on.
  bool isStale(int generation) => generation != _applied;
}

/// A pure snapshot of which application-owned fishing-spot style objects
/// (one GeoJSON source, two layers) currently exist in the active style,
/// and what — if anything — should still be attempted.
///
/// Waiting for the native style to report "fully loaded" before *starting*
/// the add sequence does not prove the add calls themselves succeeded: the
/// native Android implementation's `addSource`/`addLayer` methods can still
/// silently no-op (log a warning, add nothing, throw nothing) if the style
/// stops being "fully loaded" partway through, and `addLayer` — unlike
/// `addGeoJsonSource`, which already guards itself against this — throws if
/// asked to add a layer id that already exists. Restoration must therefore
/// be verified after the fact by querying what is actually present, and any
/// retry must add only what is confirmed missing, never something already
/// there. Kept as a small, standalone, MapLibre-independent class
/// specifically so this convergence logic can be unit-tested without a real
/// native map surface.
class FishingSpotLayerPresence {
  const FishingSpotLayerPresence({
    required this.hasSource,
    required this.hasCircleLayer,
    required this.hasSymbolLayer,
  });

  /// Builds a snapshot from the current source/layer id lists (as returned
  /// by `MapLibreMapController.getSourceIds()`/`getLayerIds()`) and the
  /// three ids this application owns.
  factory FishingSpotLayerPresence.from({
    required Iterable<String> sourceIds,
    required Iterable<String> layerIds,
    required String sourceId,
    required String circleLayerId,
    required String symbolLayerId,
  }) {
    final layerIdSet = layerIds.toSet();
    return FishingSpotLayerPresence(
      hasSource: sourceIds.contains(sourceId),
      hasCircleLayer: layerIdSet.contains(circleLayerId),
      hasSymbolLayer: layerIdSet.contains(symbolLayerId),
    );
  }

  final bool hasSource;
  final bool hasCircleLayer;
  final bool hasSymbolLayer;

  /// True only once all three required objects are confirmed present —
  /// the sole condition under which restoration may be marked complete.
  bool get isComplete => hasSource && hasCircleLayer && hasSymbolLayer;

  /// The source should be (re-)added if and only if it is missing.
  bool get shouldAddSource => !hasSource;

  /// A layer is only ever attempted once its source is confirmed present —
  /// referencing a source that does not exist is itself invalid — and only
  /// if it isn't already there (re-adding an existing layer id throws
  /// natively, unlike re-adding an existing source, which is a safe no-op).
  bool get shouldAddCircleLayer => hasSource && !hasCircleLayer;

  bool get shouldAddSymbolLayer => hasSource && !hasSymbolLayer;
}
