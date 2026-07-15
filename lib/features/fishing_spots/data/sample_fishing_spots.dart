import 'package:fishing_app/features/fishing_spots/domain/fishing_spot.dart';

// Temporary development-only data.
// This list is the in-memory, session-only store of fishing spots: it
// starts with these sample entries and grows with user-created spots for
// the lifetime of the running app. It will be replaced by repository-backed
// persistence once local storage is introduced and must not be treated as
// permanent storage.
final List<FishingSpot> sampleFishingSpots = [
  FishingSpot(
    id: 'sample-1',
    name: 'Kallavesi Bay',
    latitude: 62.8980,
    longitude: 27.6782,
    createdAt: DateTime(2026, 6, 1),
  ),
  FishingSpot(
    id: 'sample-2',
    name: 'Päijänne Shoreline',
    latitude: 61.6167,
    longitude: 25.5667,
    createdAt: DateTime(2026, 6, 5),
  ),
  FishingSpot(
    id: 'sample-3',
    name: 'Saimaa Inlet',
    latitude: 61.2833,
    longitude: 28.0833,
    createdAt: DateTime(2026, 6, 10),
  ),
];
