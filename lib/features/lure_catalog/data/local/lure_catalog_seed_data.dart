import 'package:fishing_app/features/lure_catalog/domain/lure_model.dart';
import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

/// Development seed data for the Lure Catalog: a small, hand-authored
/// dataset for development and testing, not a production catalog. See
/// MFS-015 FR-7 / TD-015.
///
/// Ids are opaque, authored UUID v4 literals (generated once with the
/// project's existing `uuid` package and hardcoded here) — never derived
/// from manufacturer/model/color text, and never generated at runtime. See
/// TD-015's Identity and ID Scheme.
///
/// Bump [currentLureCatalogSeedVersion] whenever any entry below is
/// corrected, or when entries are added/removed. `ensureSeeded()` compares
/// this against each row's stored `seedVersion` to decide whether a
/// correction is needed.
const int currentLureCatalogSeedVersion = 1;

final DateTime _seedAuthoredAt = DateTime.utc(2026, 1, 1);

final List<LureModel> lureCatalogSeedModels = [
  LureModel(
    id: '3149d765-a567-49ec-994b-74179d3171c1',
    manufacturer: 'Rapala',
    productFamily: 'X-Rap',
    modelName: 'X-Rap Shad XRS08',
    lureType: 'crankbait',
    defaultImageReference: 'assets/lure_catalog/placeholder_crankbait.png',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureModel(
    id: '7eb042d9-8826-4e12-bcb4-bc0079f03aee',
    manufacturer: 'Abu Garcia',
    modelName: 'Toby',
    lureType: 'spoon',
    defaultImageReference: 'assets/lure_catalog/placeholder_spoon.png',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureModel(
    id: '5d824c1b-1611-47f5-9724-982a846d5126',
    manufacturer: 'Storm',
    productFamily: 'WildEye',
    modelName: 'Swim Shad',
    lureType: 'swimbait',
    defaultImageReference: 'assets/lure_catalog/placeholder_swimbait.png',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureModel(
    id: 'c5a8db14-e9a0-4d85-ada3-79de1e09d3ad',
    manufacturer: 'Rapala',
    modelName: 'Jigging Rap W5',
    lureType: 'jig',
    defaultImageReference: 'assets/lure_catalog/placeholder_jig.png',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
];

final List<LureVariant> lureCatalogSeedVariants = [
  // X-Rap Shad XRS08 (crankbait) — 4 variants.
  LureVariant(
    id: '442e3a0c-a3f2-49cf-9e8f-751adff94b02',
    lureModelId: '3149d765-a567-49ec-994b-74179d3171c1',
    colorName: 'Hot Craw',
    manufacturerColorCode: 'HCC',
    lengthMillimeters: 80,
    weightGrams: 12,
    minRunningDepthMillimeters: 1500,
    maxRunningDepthMillimeters: 2400,
    buoyancy: 'suspending',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureVariant(
    id: 'a12963ad-e94d-4585-835a-c2673cc0704c',
    lureModelId: '3149d765-a567-49ec-994b-74179d3171c1',
    colorName: 'Silver Shad',
    manufacturerColorCode: 'SSD',
    lengthMillimeters: 80,
    weightGrams: 12,
    minRunningDepthMillimeters: 1500,
    maxRunningDepthMillimeters: 2400,
    buoyancy: 'suspending',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureVariant(
    // Intentionally missing buoyancy.
    id: '8befcbdf-0930-490e-840d-dd60af63f819',
    lureModelId: '3149d765-a567-49ec-994b-74179d3171c1',
    colorName: 'Perch',
    manufacturerColorCode: 'PER',
    lengthMillimeters: 80,
    weightGrams: 12,
    minRunningDepthMillimeters: 1500,
    maxRunningDepthMillimeters: 2400,
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureVariant(
    // Distinguished by variantName only; intentionally missing every other
    // optional field, to exercise missing-data handling.
    id: 'e4be0987-2e2e-402d-85d9-955fc54f9c15',
    lureModelId: '3149d765-a567-49ec-994b-74179d3171c1',
    variantName: 'Glow',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),

  // Toby (spoon) — 3 variants.
  LureVariant(
    id: '2de7edb3-b772-40c9-a51c-75c5f20c233f',
    lureModelId: '7eb042d9-8826-4e12-bcb4-bc0079f03aee',
    colorName: 'Silver',
    manufacturerColorCode: 'S',
    lengthMillimeters: 60,
    weightGrams: 18,
    buoyancy: 'sinking',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureVariant(
    // Intentionally missing manufacturerColorCode.
    id: '20aa5fab-19d8-4163-85fd-e0fef63ea3c6',
    lureModelId: '7eb042d9-8826-4e12-bcb4-bc0079f03aee',
    colorName: 'Copper',
    lengthMillimeters: 65,
    weightGrams: 24,
    buoyancy: 'sinking',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureVariant(
    // Intentionally missing buoyancy.
    id: '09fedc45-c024-4008-bcb1-ff1d4a398c66',
    lureModelId: '7eb042d9-8826-4e12-bcb4-bc0079f03aee',
    colorName: 'Firetiger',
    lengthMillimeters: 50,
    weightGrams: 12,
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),

  // WildEye Swim Shad (swimbait) — 3 variants.
  LureVariant(
    id: 'e3c58f5b-f165-4399-b9f4-b6edcff4809d',
    lureModelId: '5d824c1b-1611-47f5-9724-982a846d5126',
    colorName: 'Emerald Shiner',
    lengthMillimeters: 130,
    weightGrams: 20,
    buoyancy: 'sinking',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureVariant(
    id: '0f5052f8-4a46-4fdc-af9c-a1eed353a98a',
    lureModelId: '5d824c1b-1611-47f5-9724-982a846d5126',
    colorName: 'Bluegill',
    lengthMillimeters: 130,
    weightGrams: 20,
    buoyancy: 'sinking',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureVariant(
    // Distinguished by colorName only; intentionally missing every other
    // optional field.
    id: '3369ff41-4786-4c07-9eed-c37193a8f2e0',
    lureModelId: '5d824c1b-1611-47f5-9724-982a846d5126',
    colorName: 'Golden Shiner',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),

  // Jigging Rap W5 (jig) — 4 variants.
  LureVariant(
    id: 'db8cbcfd-a5ac-41ab-ba1c-3c7429440d7e',
    lureModelId: 'c5a8db14-e9a0-4d85-ada3-79de1e09d3ad',
    colorName: 'Glow Red',
    manufacturerColorCode: 'GR',
    lengthMillimeters: 50,
    weightGrams: 7,
    buoyancy: 'sinking',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureVariant(
    id: '319180d6-5773-461d-9e91-32c0b9f2cb9a',
    lureModelId: 'c5a8db14-e9a0-4d85-ada3-79de1e09d3ad',
    colorName: 'Blue Silver',
    lengthMillimeters: 50,
    weightGrams: 7,
    buoyancy: 'sinking',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureVariant(
    // Intentionally missing buoyancy and manufacturerColorCode.
    id: 'd121d97c-d147-4996-8646-2a89384268df',
    lureModelId: 'c5a8db14-e9a0-4d85-ada3-79de1e09d3ad',
    colorName: 'Perch',
    lengthMillimeters: 50,
    weightGrams: 7,
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
  LureVariant(
    // Distinguished by colorName only; intentionally missing every other
    // optional field.
    id: '67a1b1ab-ce08-4e30-9847-dd7dc6e34e60',
    lureModelId: 'c5a8db14-e9a0-4d85-ada3-79de1e09d3ad',
    colorName: 'Gold',
    createdAt: _seedAuthoredAt,
    updatedAt: _seedAuthoredAt,
  ),
];
