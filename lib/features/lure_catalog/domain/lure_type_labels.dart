/// Display-label lookup for the open, stable string codes used by
/// `LureModel.lureType` and `LureVariant.buoyancy`.
///
/// Unlike `FishSpecies`, these codes are not a closed set the application
/// fully controls — they are effectively open-ended (manufacturer- and,
/// eventually, server-catalog-driven), so an unrecognized code must never
/// throw or block loading/browsing/search/filtering/display. It falls back
/// to a humanized version of the raw code instead. See MFS-015 / TD-015.
///
/// The Finnish labels below are a draft, not an authoritative translation
/// (for example "vaappu" is used for both `crankbait` and `wobbler`, which
/// is imprecise) — treat this the same way `FishSpecies`' catalog was
/// treated in MFS-009: a placeholder needing a review pass.
const Map<String, String> _knownLureTypeLabels = {
  'crankbait': 'Vaappu',
  'jerkbait': 'Jerkki',
  'spinnerbait': 'Spinneribeitti',
  'spinner': 'Lusikka',
  'spoon': 'Lusikka',
  'soft_plastic': 'Muovivetouistin',
  'jig': 'Jigi',
  'swimbait': 'Uimavetouistin',
  'topwater': 'Pintauistin',
  'wobbler': 'Vaappu',
};

String lureTypeDisplayLabel(String code) {
  return _knownLureTypeLabels[code] ?? _humanizeUnknownCode(code);
}

const Map<String, String> _knownBuoyancyLabels = {
  'floating': 'Uiva',
  'suspending': 'Neutraali',
  'slow_sinking': 'Hitaasti uppoava',
  'sinking': 'Uppoava',
};

String buoyancyDisplayLabel(String code) {
  return _knownBuoyancyLabels[code] ?? _humanizeUnknownCode(code);
}

String _humanizeUnknownCode(String code) {
  final withSpaces = code.replaceAll('_', ' ').trim();
  if (withSpaces.isEmpty) {
    return code;
  }
  return withSpaces[0].toUpperCase() + withSpaces.substring(1);
}
