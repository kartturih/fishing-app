/// The two MML base maps this milestone supports. Deliberately not an
/// extensible provider registry — MFS-026 explicitly scopes this to exactly
/// Maastokartta and Ilmakuva; a third base map or a different provider is a
/// future milestone's decision, not something this enum is pre-built to
/// accommodate speculatively.
enum BaseMap {
  maastokartta,
  ilmakuva;

  static const BaseMap fallback = BaseMap.maastokartta;

  /// User-facing Finnish label (MFS-026 FR-5).
  String get label => switch (this) {
    BaseMap.maastokartta => 'Maastokartta',
    BaseMap.ilmakuva => 'Ilmakuva',
  };

  /// MML's own WMTS layer identifier for this base map. Verified directly
  /// from MML's live `WMTSCapabilities.xml` (TD-026 §0).
  String get mmlLayerId => switch (this) {
    BaseMap.maastokartta => 'maastokartta',
    BaseMap.ilmakuva => 'ortokuva',
  };

  /// Bundled static preview asset for the selector (MFS-026 FR-5) — a
  /// center-cropped, downsampled still of a real MML tile (zoom 13, the
  /// Nuuksio lake/forest area), not illustrative artwork. No live tile
  /// request is ever made to show this preview; the source tiles were
  /// fetched once, outside the app and outside this repository, using the
  /// developer's own MML API key, which never entered this codebase.
  /// Reused under MML's CC BY 4.0 license (creating and sharing adapted/
  /// cropped derivatives is permitted; attribution is satisfied by the
  /// single always-visible `MapAttribution` notice already shown on the
  /// same map screen this selector overlays — CC BY 4.0 §3(a)(2) allows one
  /// reasonable, consolidated notice "based on the medium, means, and
  /// context," rather than a separate one per derived asset).
  ///
  /// Ilmakuva's preview is `.jpg`, not `.png` — its source is a
  /// photographic aerial tile, which compresses far smaller as JPEG with no
  /// visible quality loss at this size; Maastokartta's flat cartographic
  /// style compresses better as a quantized PNG. This mirrors MML's own
  /// per-layer format choice for the live tiles themselves (`.png` for
  /// Maastokartta, `.jpg` for Ortokuva).
  String get previewAssetPath => switch (this) {
    BaseMap.maastokartta => 'assets/map/maastokartta_preview.png',
    BaseMap.ilmakuva => 'assets/map/ilmakuva_preview.jpg',
  };

  /// MML's WMTS tile file extension for this base map — verified from live
  /// GetCapabilities (TD-026 §0): Maastokartta's tiles are `image/png`
  /// (`.png`), Ortokuva's are `image/jpeg` (`.jpg`). Dates from the raster
  /// WMTS delivery path (the now-retired `MmlStyleFactory`, TD-027 §25);
  /// unused by the current MML v21 vector delivery path, which has no
  /// per-file-extension raster tile URL to build. Retained, not removed —
  /// see this codebase's own precedent (`WorldwideStyleFactory.sykeDepthAreasLayerId`)
  /// for keeping a no-longer-called identifier rather than deleting real,
  /// previously load-bearing detail.
  String get tileFileExtension => switch (this) {
    BaseMap.maastokartta => '.png',
    BaseMap.ilmakuva => '.jpg',
  };

  /// The dataset-name element MML's CC BY 4.0 attribution requires — not
  /// the WMTS layer id (`mmlLayerId`), which is a technical identifier, not
  /// a human-readable dataset name suitable for attribution text.
  String get _mmlDatasetName => switch (this) {
    BaseMap.maastokartta => 'Maastokartta',
    BaseMap.ilmakuva => 'Ortokuva',
  };

  /// The attribution sentence shown by `MapAttribution` whenever this base
  /// map is active (MFS-026 FR-18).
  ///
  /// MML's CC BY 4.0 license requires three elements — the licensor's name
  /// (Maanmittauslaitos), the dataset's name, and the period MML supplied
  /// the dataset — not one fixed universal sentence. This follows the exact
  /// three-element pattern MML's own license page demonstrates by example
  /// ("sisältää Maanmittauslaitoksen Maastotietokannan 06/2014 aineistoa").
  ///
  /// MML's own example addresses a downloaded dataset snapshot (dated to
  /// the month it was downloaded). This feature instead consumes a
  /// continuously updated live tile service, which has no equivalent
  /// discrete "supply date." The current year is used as the "period
  /// supplied" element — a reasonable, license-compliant reading for a live
  /// service (TD-026 §2), not an MML-published exact string for this
  /// scenario.
  String get attributionText =>
      'Sisältää Maanmittauslaitoksen $_mmlDatasetName-aineistoa '
      '${DateTime.now().year}';
}
