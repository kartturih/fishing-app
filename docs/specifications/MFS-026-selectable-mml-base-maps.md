# MFS-026 — Selectable MML Base Maps

## Status

Implemented — architecture-reviewed and approved, all automated tests passing (878/878), `flutter analyze` clean (8 pre-existing/accepted info-level lints, none introduced by this milestone), and physical Android testing completed successfully. See TD-026 for the technical design and its Implementation Notes for full detail (including several post-implementation UX refinement rounds — floating-control sizing, the selector's redesign to a vertical image-only layout, and its preview images' replacement with real MML-derived crops — all discovered and resolved through physical Android testing rounds, not designed here), and `docs/project-status.md` for the validation record.

## Related

- Depends on: MFS-001 — Map Feature (the `MapScreen`/`MapLibreMap` foundation this milestone replaces the default style on)
- Depends on: MFS-002 — Map Controls (the existing floating-control convention this milestone's layers control follows, placed in a different screen corner)
- Depends on: MFS-004 — Fishing Spot Foundation (the GeoJSON-backed fishing-spot markers this milestone requires to survive a base-map switch)
- Depends on: ADR-0002 — Map Technology (MapLibre GL as the rendering technology; unchanged by this milestone)
- Depends on: ADR-0008 — Base Map Provider and Delivery (authoritative for **why** MML raster WMTS was chosen over vector tiles/MapTiler/Mapbox/OSM, and for the direct-client-to-MML, no-proxy delivery architecture; this specification does not repeat that reasoning — see [Conceptual Model](#conceptual-model))
- Precedes: future overlay milestones named only as future extensions by ADR-0008 (hillshade, depth contours) — not numbered, not scoped, and not designed here

---

## Purpose

Replace the current placeholder base map — MapLibre's public demo style (`https://demotiles.maplibre.org/style.json`), hardcoded in `MapScreen` since MFS-001 — with two real, Finland-appropriate base maps supplied by Maanmittauslaitos (MML), and let the angler switch between them from the map itself. This also establishes the base-map selection UX (a floating layers control and a compact selector) that future map layers — overlays such as hillshade or depth contours — can build on, without designing those future layers now.

---

## User Value

An angler navigating real Finnish terrain and water gets no practical value from MapLibre's generic demo map. A topographic map (Maastokartta) lets them read terrain, water bodies, and trails the way they would on any outdoor map; aerial imagery (Ilmakuva) lets them visually recognize a shoreline, an island, or a specific bay from above. Letting them switch between the two, instantly and without losing their fishing spots, makes the existing map screen genuinely useful for planning and executing a fishing trip — the core purpose the project charter and MFS-001 already set out for the map, finally delivered with real map content.

---

## Scope

### In Scope

- Two selectable MML base maps: Maastokartta and Ilmakuva.
- Maastokartta as the default base map for a user with no saved selection.
- A floating layers control in the upper-right area of the map.
- A compact, anchored visual selector, opened from that control, offering both base-map choices with a preview, a label, and a clear indication of the active choice.
- Immediate, save-free switching between the two base maps.
- Remembering the selected base map across normal application restarts.
- Preserving all existing map functionality (fishing-spot markers/labels, fishing-spot tap interaction, adding fishing spots, location controls, and every existing `MapScreen` entry point) across a base-map switch, without requiring the user to leave and reopen the Map screen.
- Sensible, non-technical user-facing behavior for initial base-map loading, switching between base maps, temporary network/tile failure, and missing MML configuration.
- Required MML attribution, visible while an MML base map is active.

### Out of Scope

See [Out of Scope](#out-of-scope-1) for the complete list. Notably: depth contours, hillshade, offline map downloads/caching, additional base-map providers, MML vector maps, custom Fishing App vector styling, property boundaries/identifiers, traffic/cycling/public-transport layers, map search, navigation/routing, backend/proxy infrastructure, and any redesign of existing fishing-spot functionality.

---

## User Stories

**As an angler**
I want the map to show real Finnish terrain instead of a generic demo map
So that I can actually read the landscape, water bodies, and trails around where I plan to fish.

**As an angler**
I want to switch to an aerial photo of the area
So that I can visually recognize a specific shoreline, island, or bay from above.

**As an angler**
I want to switch base maps with one or two taps, right from the map
So that I don't have to dig through a settings screen while I'm out on the water.

**As an angler**
I want my chosen base map to still be selected the next time I open the app
So that I don't have to reselect it every single time I go fishing.

**As an angler**
I want my fishing spots to still be there, still tappable, and still addable after switching base maps
So that changing how the map looks never costs me my existing data or workflow.

**As an angler**
I want a clear, understandable message if the map imagery can't load
So that I'm not confused by a blank map or a confusing technical error while I'm trying to fish.

---

## Conceptual Model

This section resolves the product-level questions this specification must answer before Technical Design work begins, following the same discipline established by MFS-022/MFS-024/MFS-025's own Conceptual Model sections. ADR-0008 is authoritative for the underlying provider/delivery architecture; this section only restates what is necessary to specify user-facing behavior, and does not re-argue that decision.

### The current default is a placeholder, not a decision to preserve

`MapScreen`'s `build()` currently constructs its `MapLibreMap` with a literal, hardcoded `styleString: 'https://demotiles.maplibre.org/style.json'` — MapLibre's own public demo style, adopted in MFS-001 only because the map's other foundations needed something to render against. This milestone's Maastokartta base map replaces that literal as the application's default. Once this milestone is implemented, the demo style must no longer be reachable as a user-facing default under any normal circumstance (see [FR-2](#fr-2--default-base-map) and the failure-handling requirements in [Loading and Failure Behavior](#loading-and-failure-behavior) for the one narrow exception: a missing/broken configuration, which is a failure state, not a design default).

### "Ilmakuva" and ADR-0008's "Ortokuva / aerial imagery" name the same product

ADR-0008 refers to the second base map by its technical/product name, "Ortokuva / aerial imagery." This specification uses **Ilmakuva** as the user-facing Finnish label, consistent with this application's existing UI-text convention (`docs/development-rules.md`: "All user-visible UI text must be written in Finnish") and with how Finnish speakers commonly refer to aerial photography. Both names refer to the same underlying MML data product; Technical Design is free to use either name internally, but **Ilmakuva** is the label the angler sees.

### Three separate layering concepts, only one of which this milestone builds

ADR-0008 establishes a three-part conceptual layering model:

```text
Application-owned layers
────────────────────────
External overlays (future)
────────────────────────
Active base map
```

This milestone implements only the **active base map** band (exactly one of Maastokartta/Ilmakuva active at a time) and confirms the existing **application-owned layers** band (fishing-spot markers) keeps working across a change to the band below it. The **external overlays** band (future hillshade, future depth contours) is not built here — it is mentioned only so that the layers control and selector introduced by this milestone are understood as the first piece of a UX that later overlay milestones are expected to extend, not redesign. Nothing about how an overlay would eventually be added or toggled is specified in this document.

### Switching the base map is the first time `MapScreen`'s style changes after the map has already loaded

ADR-0008 documents a specific existing constraint: `MapScreen` adds fishing-spot markers (a GeoJSON source plus a circle layer and a symbol layer) from `onStyleLoadedCallback`, guarded by a `_fishingSpotMarkersAdded` flag that is set once and never reset. MapLibre destroys every source and layer belonging to the outgoing style whenever the active style is replaced. Until this milestone, `MapScreen`'s style was never replaced after the initial load, so this never mattered in practice.

This milestone is the feature that makes the base map replaceable at runtime for the first time. It therefore inherits, as a hard product requirement, exactly what ADR-0008 already committed to: **switching between Maastokartta and Ilmakuva must not cause fishing-spot markers, labels, or any other application-owned map content to disappear, and must not require the user to leave and reopen the Map screen to get them back.** This specification states that requirement as binding (see [FR-9](#fr-9--fishing-spot-markers-and-labels-survive-a-base-map-switch) and [Architecture Constraints](#architecture-constraints)); exactly how it is achieved (resetting the existing guard, restructuring when/how markers are (re-)added, or another approach) is left to Technical Design, per ADR-0008's own Implementation Notes.

### The layers control is additive to the existing map controls, not a replacement for them

MFS-002 already established a bottom-right column of floating action buttons (settings, add fishing spot, current location / selection-mode controls) via `MapControls`. This milestone's layers control is placed in the **upper-right** area of the map instead — a different corner, deliberately, so the two control groups do not compete for the same space or require redesigning `MapControls`. This milestone does not modify `MapControls`, its existing buttons, or their behavior in any way; it only adds a new, independent floating control elsewhere on the map.

### Persistence is a requirement on behavior, not on mechanism

The product requirement is narrow and observable: if an angler selects Ilmakuva, fully closes the application, and later reopens it, Ilmakuva must still be the active base map — without the angler repeating the selection. This specification deliberately does not say whether that is stored in the existing Drift database, a lightweight local key-value store, or any other mechanism; see [Persistence Behavior](#persistence-behavior) and [Design Notes](#design-notes).

### "Sensible failure behavior" means the angler is never blocked or confused, not that every failure is invisible

MML tile/style requests can fail like any network request, and the MML API credential itself could be missing or invalid in a given build/environment. This specification requires that neither failure mode ever surfaces a technical detail (a URL, an API key, a stack trace, an HTTP status code, or a provider-specific error string) to the angler, and that the application's own data (fishing spots, catches, and every other existing feature) remains as usable as reasonably possible even while base-map imagery cannot load. It does not require that failures be silent or invisible — a clear, calm, Finnish-language message is expected; see [Loading and Failure Behavior](#loading-and-failure-behavior).

---

## Functional Requirements

### FR-1 — Two Selectable Base Maps

The map must offer exactly two selectable base maps: **Maastokartta** and **Ilmakuva**, both sourced from MML per ADR-0008.

### FR-2 — Default Base Map

Maastokartta must be the active base map for a user who has no previously saved selection. The MapLibre demo style (`https://demotiles.maplibre.org/style.json`) must no longer be reachable as the user-facing default once this milestone is implemented.

### FR-3 — Floating Layers Control

A floating control using a layers-style icon must be shown in the upper-right area of the map. It must not unnecessarily consume permanent map space beyond the control itself (i.e., no permanently visible panel or list — only the control until it is activated).

### FR-4 — Compact Anchored Selector

Activating the layers control must open a compact selector, visually anchored near the control (not a separate full-screen page, and not a modal that obscures the whole map). The exact presentation (popover, small panel, or similar) is a Technical Design/implementation concern.

### FR-5 — Visual Base-Map Choices

The selector must present both base-map choices, each with a small visual preview representing that map type and a short text label ("Maastokartta" / "Ilmakuva"). The preview is a UI representation of the map type, not a separate live map render.

**Final implementation note:** following physical Android testing feedback that a visible text label alongside a small icon-sized preview looked cluttered, the shipped selector conveys each choice's name through accessible `Semantics` only, not visible on-screen text — the preview itself (enlarged, and a real recognizable crop of that base map's own MML cartography rather than illustrative artwork) identifies the choice directly. This still satisfies this requirement's underlying intent (each choice is visually and accessibly identifiable) but deviates from its literal "short text label" wording; see TD-026 Implementation Notes for the full reasoning and licensing basis for using real MML-derived preview crops.

### FR-6 — Active Selection Indication

The selector must clearly indicate which of the two base maps is currently active, distinguishable from the inactive choice.

### FR-7 — Immediate Switching, No Save Action

Selecting a base map from the selector must switch the visible map immediately, with no separate Save/Apply/Confirm action. The selector's active-selection indication must update to reflect the new choice immediately.

### FR-8 — Selection Persistence

The angler's selected base map must be remembered across a normal application restart (the app is fully closed and later reopened): the previously selected base map must be active again with no reselection required. The storage mechanism is not prescribed by this specification (see [Persistence Behavior](#persistence-behavior)).

### FR-9 — Fishing-Spot Markers and Labels Survive a Base-Map Switch

Existing fishing-spot markers and their name labels must remain visible immediately after switching between Maastokartta and Ilmakuva, with no requirement to leave and reopen the Map screen to restore them (see [Conceptual Model](#switching-the-base-map-is-the-first-time-mapscreens-style-changes-after-the-map-has-already-loaded)).

### FR-10 — Fishing-Spot Tap Interaction Continues to Work

Tapping a fishing-spot marker to open its existing details view must continue to work identically after any base-map switch.

### FR-11 — Adding Fishing Spots Continues to Work

Both existing fishing-spot creation flows (from the current location, and by selecting a point on the map) must continue to work identically regardless of which base map is currently active, and regardless of a base-map switch having just occurred.

### FR-12 — Location Controls Continue to Work

The existing current-location control and its camera-centering behavior must continue to work identically regardless of the active base map.

### FR-13 — Other Map Screen Entry Points Continue to Work

Every other existing entry point reachable from the Map screen (at minimum: Lure Tools, Statistics, Catch Search) must continue to work identically, unaffected by this milestone.

### FR-14 — Initial Base-Map Loading

While the active base map (whether the default Maastokartta or a previously saved selection) is loading for the first time in a session, the user must see sensible, non-jarring loading behavior — not a blank, broken-looking map with no indication anything is happening.

### FR-15 — Switching Loading Behavior

While switching from one base map to the other, the user must see sensible loading/transition behavior — not a jarring blank flash presented with no explanation, and not a state that looks broken or unresponsive.

### FR-16 — Temporary Network/Tile Failure Handling

If MML base-map tiles are temporarily unavailable (e.g., no network connection, or a transient failure), the application must not crash, must not show a technical error, and must present a clear, calm, Finnish-language indication that map imagery is currently unavailable. Application-owned map content (fishing-spot markers, controls, and other entry points) must remain as usable as reasonably possible under this condition.

### FR-17 — Missing MML Configuration Handling

If the MML API credential/configuration is missing or invalid (e.g., an unconfigured development or test build), the application must not crash, must not expose the missing/invalid credential, URL, or any provider-specific error detail, and must present a clear, calm, Finnish-language indication that map imagery is currently unavailable. Application-owned map content must remain as usable as reasonably possible under this condition, exactly as in [FR-16](#fr-16--temporary-network-tile-failure-handling).

### FR-18 — Required Attribution

The map UI must display the attribution required for MML map data whenever an MML base map is active, in a manner appropriate for a mobile map application. Exact placement, wording, and implementation are left to Technical Design (TD-026); this requirement is user-facing/legal, not technical (see [Attribution](#attribution)).

### FR-19 — No Out-of-Scope Functionality Introduced

This milestone must not introduce any capability listed in [Out of Scope](#out-of-scope-1) — in particular, no overlay (hillshade, depth contours), no offline map download/caching, no additional base-map provider, and no MML vector-tile-based base map.

---

## UI Expectations

- The layers control sits in the upper-right area of the map, using a layers-style icon (e.g., a stacked-layers glyph), consistent in visual weight with the existing bottom-right `MapControls` floating action buttons (MFS-002) without needing to match them exactly.
- The control itself is the only thing permanently visible — no panel, list, or preview is shown until the control is activated.
- Activating the control opens a small, visually anchored selector near the control — not a full-screen page, not a modal sheet that covers the whole map, and not a separate route/navigation entry.
- The selector shows exactly two choices (Maastokartta, Ilmakuva), each with a small preview image/graphic and a short Finnish text label, and a clear visual treatment (e.g., a highlight, border, or checkmark — exact styling not fixed here) showing which one is currently active.
- Selecting a choice applies immediately and updates the active indication immediately; there is no separate confirm step.
- Dismissing the selector without making a new choice (e.g., tapping elsewhere) leaves the previously active base map unchanged.
- Attribution is visible on-screen whenever an MML base map is active, in a manner that does not obstruct normal map interaction.
- All user-visible text is Finnish, consistent with the application's existing UI text convention.
- Exact pixel dimensions, colors, animations, and Flutter widget classes are explicitly not specified here — they belong to Technical Design/implementation.

---

## Navigation

This milestone introduces no new screen, route, or navigation entry point. It adds one new floating control and its anchored selector directly on top of the existing Map screen — the same screen `MapScreen` already renders. No change is made to `MapScreen`'s AppBar, its existing entry points (Lure Tools, Statistics, Catch Search), or `MapControls`' existing bottom-right buttons.

---

## Persistence Behavior

- The angler's selected base map must be remembered across a normal application restart (full close and later reopen), per [FR-8](#fr-8--selection-persistence).
- A user who has never made a selection sees Maastokartta as the default, per [FR-2](#fr-2--default-base-map).
- This specification intentionally does not prescribe the storage mechanism (e.g., the existing Drift database, a lightweight local key-value store, or any other approach) — that choice, including whether a new dependency is needed, is a Technical Design (TD-026) decision.
- This requirement covers only a normal application restart. Behavior after the application's local data is explicitly cleared (e.g., an OS-level "clear app data" action) is not specified here and may reasonably fall back to the default.

---

## Loading and Failure Behavior

| Situation | Required user-facing behavior |
|---|---|
| Initial base-map load (app just opened, default or previously saved base map loading for the first time) | Sensible loading indication; no blank, broken-looking map with no explanation ([FR-14](#fr-14--initial-base-map-loading)). |
| Switching between Maastokartta and Ilmakuva | Sensible loading/transition behavior; no jarring, unexplained blank flash and no appearance of being broken or unresponsive ([FR-15](#fr-15--switching-loading-behavior)). |
| Temporary network failure / map tiles unavailable | No crash; no technical detail (URL, HTTP status, provider error string) shown; a clear, calm, Finnish-language message that map imagery is currently unavailable; application-owned map content remains as usable as reasonably possible ([FR-16](#fr-16--temporary-network-tile-failure-handling)). |
| Missing or invalid MML configuration/API credential | No crash; the missing/invalid credential, URL, or any provider-specific error detail is never exposed; the same clear, calm, Finnish-language "map imagery unavailable" treatment as a network failure; application-owned map content remains as usable as reasonably possible ([FR-17](#fr-17--missing-mml-configuration-handling)). |

In every row above, "application-owned map content remains as usable as reasonably possible" means, at minimum, that fishing-spot markers/labels, fishing-spot tap interaction, adding fishing spots, location controls, and other Map screen entry points do not become entirely unusable purely because external base-map imagery failed to load. The exact visual treatment when base-map imagery is unavailable (e.g., a neutral background versus another approach) is a Technical Design decision.

Under no circumstance may any of the four situations above surface an API key, a raw request URL, a stack trace, or a provider-specific/technical error message to the user.

---

## Attribution

The map UI must provide the attribution required for the MML map data it displays, whenever an MML base map (Maastokartta or Ilmakuva) is active. This is stated here as a user-facing and legal requirement only. Exact attribution text, placement, styling, and how it is technically rendered/kept in sync with the active base map are Technical Design (TD-026) concerns, not resolved in this specification.

---

## Data Ownership

- `app-structure.md` names "Map configuration" as a planned `core/` responsibility; today, no such `core/map` code exists, and `MapScreen` hardcodes its style directly. Whether the base-map/selector logic this milestone introduces belongs in a new `core/map` area, stays within the existing `features/map` feature, or some combination of the two is a Technical Design/architecture-review decision, not resolved here — mirroring how MFS-024 and MFS-025 each left an equivalent placement question to their own Technical Design.
- No existing domain model, schema, or repository contract in `fishing_spots`, `catches`, or any other feature changes as a result of this milestone.
- Fishing-spot marker rendering logic (`_addFishingSpotMarkers`, `_addFishingSpotFeature`, and related methods in `MapScreen`) is expected to require modification so it can run again after every base-style reload, not only once — per [Conceptual Model](#switching-the-base-map-is-the-first-time-mapscreens-style-changes-after-the-map-has-already-loaded) — but the exact code change is a Technical Design concern.

---

## Empty, Loading, and Error States

See [Loading and Failure Behavior](#loading-and-failure-behavior) for the map-imagery-specific states this milestone introduces. Beyond those:

- The layers-control selector itself has no "empty" state — exactly two choices are always offered.
- If the persisted base-map preference is unreadable or corrupt for any reason, the application must fall back to the default (Maastokartta) rather than fail to load the map or crash.

---

## Edge Cases

- Opening the selector while a base-map switch from a previous selection is still visually settling must not allow a confusing double-switch or an inconsistent active indication; the selector must always reflect the actually-active base map.
- Switching base maps in rapid succession (e.g., tapping Ilmakuva, then immediately Maastokartta) must leave the map showing whichever base map was selected last, with no intermediate flash left stuck on screen.
- Adding a fishing spot immediately after switching base maps must succeed exactly as it does without a preceding switch.
- Tapping an existing fishing-spot marker immediately after switching base maps must open its details exactly as it does without a preceding switch.
- A first-ever launch with no saved preference and no network connection must still present Maastokartta as the intended default, degrading per [FR-16](#fr-16--temporary-network-tile-failure-handling) if it cannot load, rather than silently substituting Ilmakuva or the old demo style.
- Losing network connectivity mid-session, after a base map has already loaded successfully, must not remove already-rendered map imagery or application-owned content already on screen; it only affects imagery that has not yet loaded (e.g., not-yet-fetched tiles at a new zoom/pan position).

---

## Accessibility Expectations

- The layers control exposes an accessible label (e.g., "Karttatasot") distinguishing it from the existing bottom-right map controls.
- Each base-map choice in the selector exposes an accessible label conveying both its name and whether it is currently active, not only a visual indication.
- The selector's open/closed state and its choices are reachable and operable via the platform's standard accessibility services, consistent with this application's existing accessibility conventions.
- Attribution text remains legible and does not rely on color alone to be readable.

---

## Feature Ownership and Placement

Following the existing feature-first structure and this project's architecture rules (ADR-0001, ADR-0002, ADR-0008; `docs/development-rules.md`):

- No repository interface, DAO, service layer, or use-case layer is introduced, consistent with every prior milestone in this project.
- No new architectural layer is introduced beyond what ADR-0008 already establishes (base map / overlay / application-owned layers as a conceptual, not necessarily code-level, distinction).
- Exact implementation design — where base-map/selector code lives (`features/map` versus a new `core/map` area), the exact mechanism making fishing-spot layers restorable across style reloads, the persistence mechanism, the selector's widget structure, and attribution rendering — is a Technical Design (TD-026) concern, out of scope for this specification.

---

## Acceptance Criteria

1. Maastokartta is available as a selectable base map.
2. Ilmakuva is available as a selectable base map.
3. A user with no previously saved base-map selection sees Maastokartta active by default.
4. The MapLibre demo style is not reachable as the user-facing default once this milestone is implemented.
5. A floating layers control, using a layers-style icon, is visible in the upper-right area of the Map screen and is reachable directly from the map with no additional navigation.
6. The layers control does not permanently occupy map space beyond the control itself.
7. Activating the layers control opens a compact selector, anchored near the control, showing both Maastokartta and Ilmakuva.
8. Each of the two choices shows a small visual preview identifying it; per FR-5's final implementation note, the choice's name is conveyed through accessible semantics rather than a visible on-screen text label, and the preview is a real, recognizable crop of that base map's own MML cartography.
9. The selector clearly and visually distinguishes the currently active base map from the inactive one.
10. Selecting the inactive base map switches the visible map to it immediately, with no separate Save/Apply action.
11. The selector's active-selection indication updates immediately after a new base map is selected.
12. After a normal application restart, the previously selected base map (e.g., Ilmakuva) is active again with no reselection required.
13. Existing fishing-spot markers and their labels remain visible immediately after switching between Maastokartta and Ilmakuva, with no need to leave and reopen the Map screen.
14. Tapping a fishing-spot marker continues to open its existing details view correctly after a base-map switch.
15. Creating a fishing spot from the current location, and by selecting a point on the map, both continue to work correctly regardless of the active base map or a preceding switch.
16. The current-location control and camera centering continue to work correctly regardless of the active base map.
17. The existing Lure Tools, Statistics, and Catch Search entry points on the Map screen continue to work correctly, unaffected by this milestone.
18. Required MML attribution is visible on-screen whenever an MML base map is active.
19. A temporary failure to load external base-map imagery (e.g., no network) does not crash the application, shows no technical detail, presents a clear Finnish-language message, and leaves application-owned map content (markers, controls, other entry points) as usable as reasonably possible.
20. A missing or invalid MML configuration/API credential does not crash the application, never exposes the credential or any technical detail, and presents the same clear Finnish-language "map imagery unavailable" treatment.
21. No depth-contour, hillshade, offline-map, additional-provider, MML-vector-tile, or other out-of-scope capability listed in [Out of Scope](#out-of-scope-1) is present.
22. `flutter analyze` passes.
23. Automated tests cover: default base map with no saved selection, selection switching and its immediate effect, persistence across a simulated restart, fishing-spot marker/label/tap/add continuity across a base-map switch, and the non-technical presentation of both failure scenarios (network failure and missing configuration).
24. Physical Android testing is completed for this milestone.

---

## Out of Scope

- Depth contours
- Hillshade
- Offline map downloads
- Offline tile caching
- Additional base-map providers beyond MML
- MML vector maps (raster WMTS only, per ADR-0008)
- Custom Fishing App vector styling
- Property boundaries
- Property identifiers
- Traffic layers
- Cycling layers
- Public transport layers
- Map search
- Navigation/routing
- Backend/proxy infrastructure (per ADR-0008, the client connects to MML directly)
- Any redesign of existing fishing-spot functionality (creation, editing, deletion, or statistics)
- Exact WMTS request construction and the API-key injection mechanism (ADR-0008 is authoritative on the architecture; the concrete mechanism belongs to TD-026)
- Exact attribution wording/placement implementation, preview image assets, persistence storage implementation, and exact Flutter widget classes (all TD-026/implementation concerns — see [Design Notes](#design-notes))

Future overlays such as depth contours and hillshade are acknowledged only as future extensions (see [Future Extensions](#future-extensions)); their implementation is not specified anywhere in this document.

---

## Architecture Constraints

Restated here from ADR-0008, as binding constraints on Technical Design, not merely aspirational:

- MapLibre GL remains the rendering technology (ADR-0002); this milestone does not change it.
- Maastokartta and Ilmakuva are delivered as MML raster WMTS, not MML vector tiles (ADR-0008).
- The initial architecture connects directly from the mobile client to MML over HTTPS; no backend or proxy is introduced solely to hide the API key at this stage (ADR-0008).
- MML API credentials must never be committed to source control (ADR-0008).
- Application-owned map layers (fishing-spot markers today; any future application-owned layer) must be restorable after **every** base-style reload, not only the first style load — the specific mechanism is a TD-026 decision, but the requirement itself is binding (ADR-0008, [Conceptual Model](#switching-the-base-map-is-the-first-time-mapscreens-style-changes-after-the-map-has-already-loaded)).
- No new database table, column, or schema version is assumed by this specification; if Technical Design determines one is needed for persistence, that is its decision to make and justify, not a requirement imposed here.

---

## Relationship to Previous MFS Documents and ADRs

- **MFS-001 (Map Feature)** introduced the `MapScreen`/`MapLibreMap` foundation and its placeholder demo style, which this milestone replaces as the default.
- **MFS-002 (Map Controls)** established the floating-control pattern (`MapControls`, bottom-right) this milestone's upper-right layers control sits alongside without modifying.
- **MFS-004 (Fishing Spot Foundation)** established the GeoJSON-backed fishing-spot marker rendering this milestone requires to survive a base-map switch.
- **ADR-0002 (Map Technology)** selected MapLibre GL and explicitly deferred map style and tile provider to a later decision.
- **ADR-0008 (Base Map Provider and Delivery)** made that deferred decision — MML raster WMTS, Maastokartta and Ilmakuva/Ortokuva, direct-to-MML delivery, and the base map/overlay/application-owned-layers conceptual model this specification builds the user-facing feature on top of, without repeating its rationale.

---

## Dependencies

- Flutter, Dart, `maplibre_gl` — all already in use (ADR-0002).
- MML raster WMTS as the base-map data source (ADR-0008); no new external service beyond what ADR-0008 already establishes.
- A mechanism for persisting the selected base-map preference across restarts is required by [FR-8](#fr-8--selection-persistence); whether this uses an existing dependency (Drift) or introduces a new lightweight local-storage package is a Technical Design (TD-026) decision, not fixed here.
- No repository interface, DAO, service layer, or use-case layer is introduced, consistent with `docs/development-rules.md`.

---

## Future Extensions

This milestone is expected to support, in later milestones, if real usage demonstrates the need:

- Overlay layers such as hillshade and depth contours, built on top of the base-map/overlay/application-owned-layers conceptual model this milestone establishes the base-map half of (ADR-0008). Neither is designed or scoped here.
- Additional base-map providers or styles, if a real need beyond Maastokartta/Ilmakuva emerges.
- Offline map storage, already named as a future direction by MFS-001 and explicitly deferred by both ADR-0002 and ADR-0008.
- A richer base-map/overlay management surface, if the number of selectable layers grows beyond what a compact anchored selector comfortably supports.

---

## Design Notes

This section records the open judgment calls this specification surfaces explicitly rather than resolving unilaterally, following the same discipline established by MFS-022/MFS-024/MFS-025's own Design Notes sections.

**Feature ownership placement is not settled here.** `app-structure.md` anticipates a `core/map` area for "Map configuration" that does not exist yet. Whether this milestone is the moment that area is created, or whether its logic stays inside `features/map` for now, is left to Technical Design/architecture review.

**The exact mechanism for surviving a base-style reload is not settled here.** ADR-0008 and this specification both require that application-owned layers survive every base-map switch, but deliberately leave the concrete approach (resetting `_fishingSpotMarkersAdded`, restructuring when markers are added, or another approach entirely) to TD-026 — resolving it here would risk designing a larger abstraction than the actual implementation needs.

**The persistence mechanism is not settled here.** Whether the selected base map is stored via the existing Drift database, a new lightweight key-value store, or another approach is left entirely to Technical Design, per this specification's explicit instruction not to prescribe storage.

**Exact attribution presentation is not settled here.** This specification fixes only that MML attribution must be visibly present while an MML base map is active; wording, placement, and rendering mechanism belong to TD-026.

**Preview image assets are not specified here.** FR-5 requires "a small visual preview representing the map type" for each choice; whether this is a static bundled image, a small illustrative graphic, or something else is left entirely to Technical Design/implementation.

**An ADR is not needed for this milestone.** The architectural decision this feature depends on — provider, delivery format, and the base map/overlay/application-owned-layers model — was already made in ADR-0008. This milestone only defines the user-facing feature built on top of that decision; it introduces no new architectural layer, no new persistent domain entity, and no change to the application's primary navigation, so it does not independently warrant its own ADR.
