# ADR-0002: Map Technology

## Status

Accepted

## Date

2026-07-15

---

## Context

Fishing App is built around an **offline-first** architecture.

The map is the central feature of the application and will later support:

- GPS positioning
- Fishing spots
- Catch locations
- Route visualization
- Custom map layers
- Offline maps
- Environmental data overlays

The selected map technology must support long-term product development rather than only the MVP.

---

## Decision

Fishing App will use **MapLibre GL** as its map rendering technology.

The Flutter implementation will use the **maplibre_gl** package.

---

## Alternatives Considered

### flutter_map

#### Pros

- Easy to integrate
- Mature Flutter ecosystem
- Good documentation
- Vendor independent

#### Cons

- Primarily raster tile based
- Limited map styling capabilities
- Less suitable for advanced future GIS features

#### Decision

Rejected because the long-term roadmap favors vector maps, custom styling, and richer map functionality.

---

### Google Maps Flutter

#### Pros

- Mature platform
- High-quality map data
- Stable Flutter support

#### Cons

- Requires API keys and billing
- Vendor lock-in
- Limited offline capabilities
- Does not align with the project's offline-first philosophy

#### Decision

Rejected due to vendor dependency and reduced long-term flexibility.

---

## Rationale

MapLibre provides:

- Open-source ecosystem
- Vendor independence
- Vector map rendering
- Custom map styling
- Support for custom layers
- Excellent long-term scalability
- Compatibility with future offline map solutions

Although the initial integration is slightly more complex than some alternatives, it minimizes future migration risk and aligns with the project's architectural goals.

---

## Consequences

### Positive

- Supports the offline-first architecture
- Vendor independent
- Highly customizable
- Scalable for future GIS features
- Suitable for custom overlays and map layers
- Future-proof architecture

### Trade-offs

- More complex initial setup
- Flutter package exposes fewer features than native MapLibre
- Offline map implementation requires additional architecture later

---

## Scope

This decision only selects the map rendering technology.

The following topics will be decided separately:

- Offline tile storage
- Tile provider
- Map style
- Coordinate system
- GPS implementation
- Caching strategy
- Offline synchronization

---

## References

- https://maplibre.org/
- https://pub.dev/packages/maplibre_gl
- https://docs.fleaflet.dev/
- https://pub.dev/packages/google_maps_flutter