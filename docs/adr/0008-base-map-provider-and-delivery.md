# ADR-0008: Base Map Provider and Delivery

## Status

Accepted

## Date

2026-07-25

---

## Context

ADR-0002 selected **MapLibre GL** (`maplibre_gl`) as Fishing App's map rendering technology, but deliberately scoped out several decisions for later: offline tile storage, tile provider, map style, coordinate system, GPS implementation, caching strategy, and offline synchronization.

Since ADR-0002, `MapScreen` (`lib/features/map/presentation/map_screen.dart`) has shipped with a single hardcoded base map:

```dart
styleString: 'https://demotiles.maplibre.org/style.json'
```

This is MapLibre's public demo style. It has no relationship to Finland, no Finnish cartographic detail, and was never intended as anything more than a placeholder while the map's other foundations (fishing spots, catches, user location) were built.

Fishing App's primary users are Finnish anglers, and MFS-001's Future Extensions already names offline maps, environmental overlays, custom layers, and route recording as expected future map capabilities. `docs/roadmap.md` §4 similarly names "Richer maps" (offline storage, environmental overlays, custom layers) as an acknowledged future direction. Before any of that can be planned concretely, the application needs a real base map appropriate for its actual use case, and an architectural position on where that base map's data comes from and how it is delivered to the client.

This ADR makes the two decisions ADR-0002 deferred under "Map style" and "Tile provider." It does not revisit the choice of MapLibre GL itself.

### Current architectural constraint this decision must account for

`MapScreen` currently assumes its base style is set exactly once for the widget's lifetime:

- Application-owned fishing-spot markers (a GeoJSON source plus a circle layer and a symbol layer) are added inside `onStyleLoadedCallback`, via `_addFishingSpotMarkers()`.
- That method is guarded by a `_fishingSpotMarkersAdded` boolean that is set to `true` the first time it runs and is **never reset**.

MapLibre re-fires `onStyleLoadedCallback` every time the active style is replaced (a base-style reload tears down and rebuilds the entire style, including every source and layer that had been added onto it). With today's code, that callback would fire again, but `_addFishingSpotMarkers()` would return immediately because the guard is already `true` — so the fishing-spot source/layers would not be re-created, and fishing-spot markers would silently disappear the moment the base map is switched at runtime.

Introducing user-selectable base maps therefore does not merely add a second style option — it introduces the first scenario in this application where the active style changes after the map has already loaded. This ADR records that requirement; it does not solve it (see Consequences and Scope).

---

## Decision

1. **MapLibre GL remains the map rendering technology.** This reaffirms ADR-0002; nothing about the renderer changes.

2. **Finland's National Land Survey (Maanmittauslaitos / MML) is the provider for the initial Finnish base maps.**

3. **MML raster WMTS is used for the initial base maps, not MML vector tiles.** The reason is primarily cartographic: the goal is to present MML's own rendered Maastokartta cartography as MML designed it, rather than build and maintain an equivalent vector style in-house.

4. **Two initial selectable base maps:**
   - MML Maastokartta (topographic map)
   - MML Ortokuva / aerial imagery

5. **Base maps and overlays are conceptually distinct layering concepts:**
   - Exactly one base map is active at a time.
   - Zero or more overlays may exist on top of it, independent of which base map is active.
   - Possible future overlays include hillshade and depth contours. Neither is part of this decision's implementation scope (see Scope).

6. **Application-owned map layers remain a separate, third concept**, distinct from both the base map and any overlay. Fishing-spot markers (and any future application-owned layer) are not part of a base map or an overlay; they belong to the application, not to the map's cartographic source.

### Conceptual layering model

```text
Application-owned layers
────────────────────────
External overlays (future)
────────────────────────
Active base map
```

Exactly one layer occupies the "active base map" slot at any time. The overlay band may be empty (as it is initially) or hold any number of independent overlays. Application-owned layers sit above both and are never destroyed or reconstructed by a change to either band below them — a requirement, not yet a guarantee (see Consequences).

### Credentials and delivery architecture

- MML API credentials must never be committed to source control.
- The initial architecture connects directly from the mobile client to MML over HTTPS. A backend or proxy service is **not** introduced at this stage solely to hide the API key.
- Large-scale production usage may later require reassessing MML's service tier, introducing hosting/proxying, adding caching, or another delivery strategy entirely. That reassessment is out of scope for this decision and is not precluded by it.

### Offline maps

Offline maps are not part of this decision. ADR-0002 already scoped offline tile storage and offline synchronization as separate future decisions; this ADR does not change that.

---

## Alternatives Considered

None of the following are permanently rejected. They remain available for reconsideration if requirements, scale, budget, or product direction change.

### 1. MML raster WMTS — selected

**Pros:** Delivers MML's own rendered Finnish cartography (Maastokartta, aerial imagery) exactly as MML designed it, with no in-house styling effort. Well-established, standard WMTS protocol that MapLibre GL can consume as a raster source. Matches the initial need (two fixed, official Finnish base maps) without requiring a vector style pipeline.

**Cons:** Raster tiles cannot be restyled, recolored, or have selective vector-layer visibility toggled by the application. Larger tile payloads than vector tiles for equivalent visual detail. Less suited to long-term custom cartography if that is ever wanted.

**Decision:** Selected for the initial implementation. The project explicitly wants MML's existing Maastokartta cartography as rendered by MML, not a self-maintained vector style — the raster/vector trade-off is resolved in favor of raster for that specific reason.

### 2. MML vector tiles

**Pros:** Smaller payloads, client-side restyling, finer per-layer control, and closer alignment with ADR-0002's original long-term rationale for choosing MapLibre (vector rendering, custom styling).

**Cons:** Would require building and maintaining a MapLibre GL style compatible with MML's vector tile schema to reproduce (or deliberately diverge from) MML's own Maastokartta appearance — meaningful ongoing styling effort with no such style existing today.

**Decision:** Not selected for the initial base maps. The project wants MML's rendering as-is; building a vector style is a larger, separate effort that this decision does not take on now. May be revisited once there is a reason to invest in a custom style (e.g. the "richer maps"/custom-layer direction in `docs/roadmap.md` §4).

### 3. MapTiler

**Pros:** Vendor-hosted vector and raster tiles with global coverage, mature MapLibre integration, no infrastructure to operate.

**Cons:** Global/generic cartography rather than Finland-specific detail an angler would recognize (trails, terrain classification, water body detail at the fidelity MML provides); introduces a commercial vendor dependency for the base map itself, which sits less naturally alongside this project's preference (ADR-0002) for vendor independence than an authoritative national data source does.

**Decision:** Not selected. Finland-specific accuracy and MML's authoritative status outweigh MapTiler's global convenience for this application's initial audience. Could be reconsidered for non-Finnish coverage if the application ever expands beyond Finland.

### 4. Mapbox

**Pros:** Mature platform, strong tooling and documentation, global coverage.

**Cons:** Commercial vendor with usage-based billing and its own terms of service; ADR-0002 already rejected a comparable vendor (Google Maps Flutter) for similar reasons (vendor lock-in, reduced long-term flexibility, tension with this project's offline-first philosophy). The same reasoning applies here.

**Decision:** Not selected, consistent with ADR-0002's existing stance against vendor-locked commercial map platforms as the primary data source.

### 5. Direct use of OpenStreetMap public tile servers

**Pros:** No cost, no API key, immediately available, large existing community.

**Cons:** OSM's public tile infrastructure is provided for light, general use and has an explicit usage policy that discourages embedding directly in a distributed mobile application without a dedicated agreement; does not provide the Finland-specific Maastokartta/aerial cartography this project specifically wants; offers no operational guarantee suitable for a production application.

**Decision:** Not selected. Does not meet the Finland-specific cartographic goal, and is not an appropriate long-term dependency for a distributed application without a separate arrangement. Could remain useful as a fallback or development-only convenience, but is not adopted as a decision here.

---

## Consequences

### Positive

- The application gains a real, Finland-appropriate base map (Maastokartta) in place of MapLibre's generic demo style, directly serving anglers navigating actual Finnish terrain and water.
- An official aerial-imagery option becomes available alongside the topographic map.
- The base-map / overlay / application-layer distinction gives future work (hillshade, depth contours, and application features like fishing spots) a clear conceptual home, before any of them is built.
- Using MML's authoritative, rendered cartography avoids the cost of designing and maintaining an in-house vector style.
- Keeping the client-to-MML connection direct (no proxy) keeps the initial implementation simple and matches this project's current scale; the door is explicitly left open to add a proxy or caching layer later without this decision needing to be reversed.

### Trade-offs

- Raster base maps cannot be restyled or have individual cartographic layers toggled by the application — accepted in exchange for using MML's cartography as-is.
- An MML API credential now exists as an operational concern: it must be kept out of source control, which constrains how configuration is built in TD-026 (the injection mechanism itself is intentionally left to that TD, not decided here).
- Direct client-to-MML calls mean the application's request volume, and any rate limit or terms-of-service constraint MML applies, are exposed directly to however many devices run the app; revisiting this (proxy, caching, different service tier) is anticipated, not ruled out.
- Two selectable base maps, plus a future overlay band, plus application-owned layers, add real UI and state-management surface area (selection, persistence, restoration) that did not exist when there was only one hardcoded style — the extent of that surface area is intentionally not designed by this ADR.

### Important architectural consequence: application-owned layers must survive a base-style reload

Selecting between two base maps at runtime means `MapScreen`'s style will change after the map has already loaded and after fishing-spot markers have already been added — a scenario the current implementation was never built for (see Context). MapLibre destroys all sources and layers belonging to the outgoing style when the style is replaced, and `MapScreen`'s existing `_fishingSpotMarkersAdded` guard is a one-time, whole-widget-lifetime flag, not a per-style-load flag.

This ADR records the following as a hard requirement on the eventual implementation, without prescribing the mechanism:

- Every application-owned layer (fishing-spot markers today; any future application-owned layer) must be restorable after **every** base-style reload, not only the first style load.
- The exact mechanism (resetting the guard, restructuring how/when markers are (re-)added, or another approach entirely) is left to TD-026. This ADR deliberately does not solve it here, to avoid designing an unnecessarily large abstraction before the actual base-map-selection feature (a future MFS/TD) defines the full set of requirements the mechanism needs to satisfy.

---

## Scope

This decision defines:

- MapLibre GL remains the rendering technology (reaffirming ADR-0002).
- MML as the provider of the initial Finnish base maps.
- Raster WMTS, not vector tiles, as the delivery format for those initial base maps.
- The two initial selectable base maps: MML Maastokartta and MML Ortokuva/aerial imagery.
- The conceptual separation of base map, overlay, and application-owned layers, and that exactly one base map is active at a time while overlays are zero-or-more.
- That MML credentials must never be committed to source control.
- That the initial architecture calls MML directly from the mobile client over HTTPS, with no backend/proxy introduced solely to hide the API key.
- The requirement that application-owned layers must be restorable after every base-style reload, as a constraint on future implementation.

This decision does not define:

- Exact UI layout for base-map or overlay selection.
- Popup or detail-view implementation for any layer.
- Preview assets (thumbnails, icons) for base-map selection.
- How the selected base map is persisted.
- Exact Flutter classes, widgets, or providers to introduce.
- Exact WMTS URL templates or request parameters.
- The API-key injection mechanism.
- The depth-contour data provider.
- Hillshade implementation.
- Offline map implementation.
- Non-Finland/global base-map coverage. MML's cartography covers Finland only; behavior outside that coverage (e.g. a global fallback base map) was investigated separately from this decision and from MFS-026/TD-026's implementation, and remains a distinct, not-yet-decided future consideration — not designed, scoped, or committed to here. Any such work would need its own ADR (see Alternatives Considered §3, which already anticipated MapTiler being "reconsidered for non-Finnish coverage if the application ever expands beyond Finland").

These topics are left to a future MFS and TD (not yet created).

---

## Implementation Notes

Product behavior for base-map/overlay selection is specified by MFS-026. Technical implementation — the exact mechanism for making application-owned layers restorable across base-style reloads, WMTS request construction, and API-key handling — is described by TD-026, now implemented, architecture-reviewed, and physically validated (see `docs/project-status.md`). This ADR documents why MML raster WMTS was chosen and how base maps, overlays, and application-owned layers relate architecturally; it deliberately does not specify database schema, code structure, or UI design, and TD-026's own Implementation Notes are the authoritative record of implementation-time detail and deviation, not this ADR.

---

## References

- https://maplibre.org/
- https://pub.dev/packages/maplibre_gl
- https://www.maanmittauslaitos.fi/en
- https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/expert-users/product-descriptions/open-data-wmts-service
- https://www.ogc.org/standard/wmts/
- docs/adr/0002-map-technology.md
