# ADR-0009: Global Base Map Coverage and Fallback

## Status

Accepted

## Date

2026-07-26

---

## Context

ADR-0008 selected Maanmittauslaitos (MML) raster WMTS as the provider and delivery format for Fishing App's two selectable base maps — Maastokartta and Ilmakuva — and MFS-026/TD-026 implemented that decision. ADR-0008 explicitly named this limitation and deferred it:

> "Non-Finland/global base-map coverage. MML's cartography covers Finland only; behavior outside that coverage (e.g. a global fallback base map) was investigated separately from this decision and from MFS-026/TD-026's implementation, and remains a distinct, not-yet-decided future consideration — not designed, scoped, or committed to here. Any such work would need its own ADR."

This is that ADR.

MML's cartography only covers Finland. `docs/project-status.md`'s Known Limitations section already records this: "Coverage is also Finland-only (MML's own data extent); a global base-map fallback is a not-yet-scoped future consideration." An angler who pans or travels outside Finland today sees a base map that has nothing to show.

### What physical-development investigation already established

Before this ADR was written, the following was verified experimentally, not assumed:

- MML Maastokartta and Ortokuva WMTS work correctly inside Finland.
- A real MML tile request for a location outside MML's coverage (Paris and Stockholm were both tested) returns **HTTP 200**, not an error — with a 116-byte, 256×256 PNG.
- That PNG was inspected directly, at the byte/chunk level (`IHDR`, `PLTE`, `tRNS`, `IDAT`): it is a palette-indexed (PNG color type 3), 1-bit image with a single palette entry (`RGB(0,0,0)`) and a `tRNS` chunk marking that entry's alpha as `0`. Every one of its 65,536 decoded pixels is identical: `RGBA(0, 0, 0, 0)` — fully transparent. There is no partially-opaque pixel and no visible content anywhere in the tile.
- Because every pixel is fully transparent, a raster layer beneath this MML tile remains fully visible through it — the tile contributes nothing to the composited image.
- A request for Haparanda (on the Finnish side of the Sweden/Finland border, immediately adjacent to Swedish territory) returned real MML imagery. This demonstrates that MML's own coverage naturally extends through whichever tiles happen to contain Finnish territory, rather than being clipped at a hard-coded national boundary — MML's service already handles the boundary; the application does not need to.

Together, this means MML already behaves, today, exactly as a well-formed "no data here" raster source should: it returns a valid, correctly-sized, fully transparent tile rather than an error, a placeholder image, or a distorted response. This is the mechanism this ADR's design relies on — restated in full in [Experimentally Verified MML Behavior](#experimentally-verified-mml-behavior) below.

> **This assumption was subsequently disproved by broader physical Android testing and is no longer relied upon for Maastokartta — see [Revision Note 2](#revision-note-2-the-transparent-mml-fallback-assumption-was-disproved-by-physical-testing).** The three spot-checks above (Paris, Stockholm, Haparanda) were genuine, accurately observed — they are not wrong as individual data points. What they failed to capture is behavior at broader geographic scale: physical testing across larger areas (panning through Sweden and the Baltic region, particularly at low zoom) found MML rendering opaque gray/white blocks and visible tile/coverage-boundary artifacts instead of the uniformly transparent behavior a handful of point samples suggested. This section is kept as an accurate historical record of what was actually tested and observed at the time — not deleted — but Decision item 6 and the Maastokartta mechanism below have been revised in response; do not re-derive a "rely on MML transparency" design from this section alone.

### The product problem

The map must provide useful worldwide coverage instead of becoming visually empty the moment an angler moves outside MML's Finland-only extent — without requiring the angler to switch to some separate "world map" mode, and without losing MML Maastokartta/Ilmakuva as the primary, user-facing, selectable Finnish base maps established by MFS-026. Since MML's transparent no-data tiles already reveal whatever is beneath them, the natural design is to place a worldwide base layer *underneath* the selected MML layer, so that outside Finland the global layer simply shows through, with no application-side Finland-boundary logic of any kind.

---

## Decision

1. **Two distinct worldwide-coverage compositions are introduced — one per existing user-facing base-map choice — rather than one shared worldwide layer used identically underneath both selections.** This revises this ADR's original framing (a single global layer beneath whichever MML map is selected); see [Revision Note](#revision-note-two-compositions-not-one) below for why.

   - **Maastokartta:** MapTiler Outdoor is added as a worldwide underlay beneath MML Maastokartta. It is not a separate mode the user switches into; it is always present. **Revised by physical testing (see [Revision Note 2](#revision-note-2-the-transparent-mml-fallback-assumption-was-disproved-by-physical-testing)):** MML is no longer included in Maastokartta's composition purely because it happens to be the selected map — its inclusion was gated by an explicit geographic check (an approximate Finland region, with hysteresis) evaluated against the current viewport, not by relying on MML's own tile-transparency behavior outside that region. **Further revised by physical testing (see [Revision Note 3](#revision-note-3-the-region-check-alone-is-not-sufficient--low-zoom-viewport-extent-also-matters)):** MML was additionally gated on the current camera zoom being at or above an activation threshold, since the geographic check alone does not account for how much area a low-zoom viewport visibly covers. **Superseded by direct pixel-level evidence (see [Revision Note 4](#revision-note-4-viewport-level-workarounds-are-replaced-by-pixel-level-masking-of-mmls-own-tiles)):** both viewport-based mechanisms above are replaced by making MML's own out-of-coverage pixels transparent before MapLibre ever receives them, via a small, app-local (on-device, loopback-only) tile-transformation step. MML's raster source becomes unconditionally present in Maastokartta's composition whenever configured — exactly as MapTiler Outdoor already is — with correctness enforced per-pixel, not per-viewport.
   - **Ilmakuva:** MapTiler Satellite Hybrid becomes the complete worldwide base map for this selection — inside Finland and everywhere else alike. **MML Ortokuva is not used by the Ilmakuva selection in this milestone.** MML Ortokuva may be reconsidered in a future milestone (e.g. layered above MapTiler Satellite Hybrid within Finland only, mirroring Maastokartta's own composition) — that is not designed, scoped, or committed to here.

2. **MapTiler is selected as the worldwide provider for both compositions**, serving two distinct roles: a topographic/outdoor worldwide underlay for Maastokartta, and a complete worldwide aerial/satellite base map for Ilmakuva.

3. **Both are delivered as MapTiler raster tiles**, consumed directly by the existing MapLibre GL renderer (ADR-0002), via MapTiler's documented raster XYZ tile endpoint (`https://api.maptiler.com/maps/{mapId}/{tileSize}/{z}/{x}/{y}.{format}?key={apiKey}`) — **not** MapTiler's hosted vector `style.json`, which this ADR originally named as the delivery mechanism. This is a deliberate revision, made during TD-027 authoring once the underlying MapLibre plugin's actual capabilities were investigated: using MapTiler's remote style document as the application's base style would make the *entire* map's ability to load dependent on that one remote fetch succeeding, undermining this ADR's own failure-independence principle (below). Consuming MapTiler as an ordinary raster tile source — embedded in the same kind of locally-authored style document MML's own tiles already use — avoids that coupling entirely. See TD-027 §0/§3 for the full investigation and reasoning.

4. **The client connects directly to MapTiler over HTTPS, with no backend or proxy**, mirroring ADR-0008's existing stance for MML: a proxy is not introduced at this stage solely to hide an API key. MapTiler's own terms already anticipate this exact usage pattern (see [Credential and Security Implications](#credential-and-security-implications)). **This is unaffected by Revision Note 4's on-device MML tile-transformation step** (below): that mechanism is not a backend or proxy in the sense this item and ADR-0008 use those words — it is not a remote, developer-operated server; it never leaves the device; it exists to make out-of-coverage pixels transparent (a genuine rendering necessity Revision Note 4 establishes), not to hide MML's API key, which was never treated as a problem needing hiding (ADR-0008). That the key also never needs to appear in the on-device MapLibre style URL as a side effect of this mechanism is a welcome property, not its purpose.

5. **MML Maastokartta and Ilmakuva remain the only user-facing, selectable base-map choices (MFS-026).** MapTiler is not a third selectable option, not a "world map mode," and is not exposed as a user choice anywhere, for either composition. It is an architectural layer (or, for Ilmakuva, the entire base map) the user never directly selects by name.

6. ~~No manually maintained Finland boundary/polygon/mask is introduced.~~ **Superseded for Maastokartta — see [Revision Note 2](#revision-note-2-the-transparent-mml-fallback-assumption-was-disproved-by-physical-testing), [Revision Note 3](#revision-note-3-the-region-check-alone-is-not-sufficient--low-zoom-viewport-extent-also-matters), and [Revision Note 4](#revision-note-4-viewport-level-workarounds-are-replaced-by-pixel-level-masking-of-mmls-own-tiles).** For Ilmakuva, this remains true unchanged: no boundary logic of any kind is needed, since MapTiler Satellite Hybrid is used uniformly, everywhere, with nothing to switch on at any border. For Maastokartta, a Finland/Åland coverage geometry is now a permanent, required part of this ADR's design — its role has changed twice since first introduced: originally a per-viewport *switching* input (Revision Notes 2/3, now superseded), it is, as of Revision Note 4, the geometry a small on-device process uses to decide, per pixel, whether a given point of MML's own raster tiles should be visible at all. The polygon itself did not need to change for this — only what consults it did.

### Revision Note: two compositions, not one

This ADR was originally written around a single global MapTiler layer, used identically underneath whichever of Maastokartta/Ilmakuva was selected, with an explicit decision that "Ilmakuva does not imply worldwide satellite imagery." That framing has been superseded by a subsequent product decision: Ilmakuva now uses MapTiler Satellite Hybrid as its complete worldwide base map (not merely as a fallback underneath MML Ortokuva), while Maastokartta keeps the original underlay composition with MapTiler Outdoor beneath MML Maastokartta. See [Why Ilmakuva Uses MapTiler Satellite Hybrid Directly](#why-ilmakuva-uses-maptiler-satellite-hybrid-directly-not-as-an-underlay) for the reasoning, and [Consequences](#consequences) for the trade-offs this introduces (in particular, Ilmakuva's rendering now changes within Finland too, not only outside it, and Ilmakuva loses the dual-provider failure independence Maastokartta retains).

### Revision Note 2: the transparent-MML-fallback assumption was disproved by physical testing

This ADR's original mechanism for Maastokartta relied entirely on MML's own tiles being reliably, fully transparent outside Finland (verified via three spot-checks: Paris, Stockholm, and a Haparanda border check — see [Experimentally Verified MML Behavior](#experimentally-verified-mml-behavior)). **Physical Android testing has since shown this does not hold at broader geographic scale.** Observed behavior included:

- MML coverage extending irregularly beyond Finland's actual territory, in ways the three original spot-checks did not surface.
- Some no-data/partial-coverage areas rendering as opaque gray or white blocks instead of the fully transparent tile the original verification found — MapTiler Outdoor beneath them was hidden, not shown through.
- Visible large tile/coverage-boundary artifacts around Sweden, the Baltic region, and elsewhere.
- At low zoom levels, MML's actual coverage appearing as a distinct, irregular block/shape drawn over the worldwide MapTiler map, rather than blending in seamlessly.
- The net result: Maastokartta's worldwide experience was visually broken in a way this ADR's original design did not anticipate and cannot excuse — the map must not look broken outside Finland, which was the entire point of this ADR.

**This directly invalidates Decision item 6 and the original Maastokartta mechanism for that reason alone** — not because "no boundary" was a bad instinct in general (it kept the original design pleasingly simple, and remains entirely correct for Ilmakuva, where physical testing found no equivalent problem and this ADR's original reasoning is preserved unchanged), but because the specific empirical claim it depended on ("MML's own transparency reliably marks its own boundary") turned out to be false at the scale this application actually needs it to hold.

**Revised decision for Maastokartta:** MML's raster source is no longer included in Maastokartta's style merely because Maastokartta is selected. Its inclusion is now gated by an explicit, application-owned geographic check — an approximate Finland region (not a raw rectangular bounding box; see reasoning below), evaluated with hysteresis against the current viewport center, recomputed on camera-idle. MapTiler Outdoor's own presence is **not** viewport-gated — it remains the constant, always-present underlay for Maastokartta regardless of location, preserving this ADR's original failure-independence guarantee (MML can still fail even deep inside Finland, and MapTiler Outdoor must still be there as backup).

**Why an approximate Finland polygon, not a rectangular bounding box:** Finland's actual territory is long, narrow, and irregular — a wide southern/coastal region plus a much narrower northwestern arm reaching toward Lapland, plus an archipelago extending into the Baltic Sea. Any single axis-aligned rectangle drawn tightly enough to include all of Finland necessarily also includes large areas of Sweden, Norway, Russia, and the Baltic Sea — precisely the regions physical testing found the bug in. A rectangular bounding box was considered and rejected for this reason: it would not reliably fix the reported problem, only relocate where it happens to be visible. A modest, simplified polygon approximating Finland's real outline (not a survey-grade boundary — a coarse, public-domain-sourced simplification is sufficient) avoids this while remaining a "simple robust mechanism" in the spirit of this ADR's original design goal. See TD-027 for the resulting design (the polygon/hysteresis mechanism itself, exact vertex sourcing, and margin tuning are TD/implementation concerns, not decided at the ADR level).

**This does not reopen Ilmakuva.** Physical testing found MapTiler Satellite Hybrid working correctly worldwide, including within Finland, with no equivalent artifact. Ilmakuva's design (Decision item 1's second bullet, [Why Ilmakuva Uses MapTiler Satellite Hybrid Directly](#why-ilmakuva-uses-maptiler-satellite-hybrid-directly-not-as-an-underlay)) is unchanged by this revision.

### Revision Note 3: the region check alone is not sufficient — low-zoom viewport extent also matters

Revision Note 2's geographic region check was known, at the time it was written, to carry one accepted simplification: it evaluates only the viewport's *center point* against the Finland/Åland region, not the full visible area. TD-027 §3A/§14 recorded this explicitly as an accepted risk, to be "revisit[ed] only if physical testing shows this produces a genuinely confusing result." **Further physical Android testing has now shown exactly that.**

With Maastokartta selected and the viewport center legitimately inside Finland, zooming out far enough still produces the same class of defect Revision Note 2 was written to fix — large opaque gray/white areas and visible tile/coverage-boundary artifacts — even though the region check itself reports "active" and does not flicker. The mechanism is different from Revision Note 2's original finding, but the visible symptom is the same:

- Finland's own real extent (roughly 540 km east–west at its narrowest useful measure, roughly 1,150 km north–south) is finite. At low enough zoom, the viewport visibly covers a geographic area larger than Finland's own footprint, regardless of where its center sits.
- The region check (Revision Note 2) only ever produces one binary answer — "MML is part of this composition" or "it is not" — for the *entire* style. It has no way to express "MML is fine for the middle of this view but not for its edges," because the composition-level check was never designed to reason about viewport extent, only viewport center.
- Once MML's layer is part of the composition at all, MapLibre requests and renders its tiles across the *whole* visible area, including the portions that extend beyond Finland's actual territory — exactly where MML's own edge/no-data rendering was already shown (Revision Note 2) not to be reliably transparent.

**This is not a failure of the region polygon, the hysteresis margin, or the point-in-polygon/nearest-edge logic.** All of that continues to correctly answer "is this specific point inside Finland" — and continues to do so unmodified. The gap is that "is the *center point* inside Finland" is not the same question as "is the *entire visible viewport* free of area outside Finland," and only the first question was ever being asked.

**Revised decision:** a third, independent condition is added to MML's inclusion in Maastokartta's composition, alongside the existing credential check and the existing geographic region check:

```text
MML active = configured AND geographic-region-active AND zoom >= activation threshold
```

The zoom condition is deliberately **not** implemented as a third Dart-side check feeding the same style-regeneration pipeline the geographic check uses. Investigation (TD-027 §3B) found that MapLibre's own style specification already provides a purpose-built mechanism for exactly this: a raster **layer's** `minzoom` property (distinct from a raster *source's* `minzoom`, which has different, weaker semantics — see TD-027 §3B for the verified distinction) causes MapLibre to fully hide that layer below the given zoom, natively, with no tile request and no application code involved. Setting this once, statically, in the already-generated MML layer JSON achieves the required `AND zoom >= threshold` term with **zero** new Dart-side state, zero new regeneration triggers, and therefore no new zoom-hysteresis concern to design — a materially smaller addition than a zoom-driven counterpart to the existing region mechanism would have been. See TD-027 §3B for the full investigation, why source-level `minzoom` alone was rejected, and the exact activation threshold (an explicit, not-yet-resolved pre-implementation verification item, pending a physical test — not guessed).

**This does not change or replace Revision Note 2's mechanism.** `MmlCoverageRegion`, its polygon data, and its asymmetric entry/exit hysteresis are unchanged and remain necessary — they answer a different question (is the viewport's *location* inside Finland) than the zoom gate does (is the viewport's *extent*, at the current zoom, small enough that MML's content can be trusted to fill it cleanly). Both conditions must hold for MML to be included; either alone is insufficient.

**This does not reopen Ilmakuva.** The low-zoom viewport-extent problem is specific to Maastokartta's MML layer — Ilmakuva has no MML content and no boundary-dependent behavior of any kind, and physical testing found no equivalent zoom-related defect for it. Ilmakuva's design is unaffected by this revision.

### Revision Note 4: viewport-level workarounds are replaced by pixel-level masking of MML's own tiles

Revision Notes 2 and 3 both worked around the same underlying limitation: MML's WMTS tiles are not reliably transparent outside Finland, so *something* at the composition level had to decide, per viewport, whether MML belonged in the style at all — first by location (Revision Note 2), then additionally by zoom (Revision Note 3). Both were genuine, reasoned engineering responses to real, physically-observed defects. **Direct pixel-level analysis of real MML tiles has since shown a more fundamental fact that neither revision could see from the outside: the defect is baked into the tile pixels themselves, at the PNG format level, and no purely compositional (viewport-based) workaround — however precisely tuned — could ever have produced a pixel-clean result.**

**What was verified, directly, from real MML WMTS responses (not inferred):**

- Four representative z=6 tiles (Finland interior; the Finland/Russia border near Imatra; the Finland/Sweden border near Tornio; a tile over Åland/the SW archipelago) were decoded and inspected byte-for-byte. **None contained a PNG `tRNS` chunk or alpha channel of any kind — every pixel in all four tiles was 100% opaque**, confirmed both by raw PNG chunk parsing and by full RGBA pixel counts.
- The Imatra tile — straddling the Finland/Russia border — was **69.81% a single, flat, textureless RGB(204,204,204) gray**, confirmed by direct visual inspection to correspond exactly to Russian territory: zero roads, zero place names, zero cartographic variation of any kind. This is MML's own server-side rendering of "nothing to show here," delivered as an ordinary opaque gray fill, not as transparency.
- Connected-component analysis of that same gray color found it forms **one single, edge-touching blob covering 69.48% of the tile** at Imatra, versus the **largest legitimate occurrence of the same gray value inside a genuine Finnish-interior tile: 7 pixels (0.01% of the tile), scattered across 386 disconnected fragments, none touching a tile edge** — i.e. incidental use (most likely anti-aliasing on line/text features), not an area fill. This matters directly for what Revision 4 below can and cannot safely do with that observation.

**This directly proves — not merely suggests — that ordinary MapTiler-underneath/MML-on-top layer stacking can never produce a clean border, at any zoom, under any viewport-based inclusion rule.** No decision about *whether* MML's layer is present in the style can fix pixels that are already opaque *within* that layer. Revision Note 3's own closing line — "the true 'MML content visually fills the viewport with no non-Finland padding' crossover... requires real visual inspection, which is exactly why a physical test was recommended" — turned out to be looking for a threshold that doesn't reliably exist as a clean line at all: the gray is present at the pixel level regardless of zoom; it simply becomes a larger fraction of the visible frame at lower zoom.

**MapLibre's own rendering stack was separately investigated and confirmed incapable of fixing this from the client side either.** Direct inspection of the MapLibre style specification, the plugin's exposed API, and MapLibre Native's own compiled raster shader (`raster.fragment.glsl`, the GPU code that actually runs for every raster layer on our pinned Android 13.3.0 / iOS 6.27.0 builds) found:

- No raster paint property (opacity, hue-rotate, brightness, saturation, contrast, resampling, fade-duration — the complete, verified list) can map a specific source color to transparency or derive alpha from a pixel's own RGB.
- No "clip" or "mask" layer type exists in MapLibre for 2D raster content.
- A native escape hatch (`CustomLayer`) exists on Android but is documented, verbatim, as *"Experimental feature. Do not use."* — forking or extending the renderer to add color-keyed or geometry-masked rendering was evaluated and rejected as substantially more complex, less portable, and less maintainable than processing tiles on-device before MapLibre ever sees them.

**Revised decision:** Maastokartta's composition changes from "decide whether to include MML's raster source, per viewport" to **"always include MML's raster source, but serve it through a small, app-local tile-transformation step that makes genuinely out-of-coverage pixels transparent before MapLibre requests them."** MML's raster source becomes unconditionally present in Maastokartta's style whenever configured — exactly as MapTiler Outdoor already is — with the actual geographic correctness enforced per-tile, not per-viewport:

```text
MML pixel is opaque  ⟺  that pixel's real-world location is within the approved Finland/Åland coverage geometry
MML pixel is transparent  ⟺  outside it
```

This eliminates the entire class of problem both Revision Note 2 and Revision Note 3 existed to manage: there is no longer a binary "is MML in the composition" decision to make per viewport, so there is nothing for a hysteresis margin to stabilize and nothing for a zoom threshold to gate. **`MmlCoverageRegion`'s viewport-center classification and asymmetric hysteresis, and Revision Note 3's zoom-activation-threshold mechanism, are both superseded by this revision** — not because either was designed incorrectly, but because both were solving the best available version of a problem that direct pixel evidence has now shown has a more fundamental, and more completely solvable, root cause. See TD-027 §3C for the full local tile-masking design, and TD-027's Revision History for the complete migration plan (what is removed, what is kept, and why).

**This does not reopen Ilmakuva or change ADR-0009's use of MapTiler.** Ilmakuva has no MML content at any revision. MapTiler Outdoor's unconditional presence beneath MML, and the two-provider failure-independence guarantee this ADR already established, are unchanged — if anything, strengthened, since MapTiler is now visible through *every* pixel MML doesn't legitimately occupy, not merely through whichever viewports a coarser check happened to exclude MML from entirely.

### Layer / composition model

ADR-0008 established a three-band conceptual model:

```text
Application-owned layers
────────────────────────
External overlays (future)
────────────────────────
Active base map
```

This ADR does not remove or reorder those three bands, but the "active base map" band is now composed differently depending on which of the two user-facing choices is active — it is no longer one uniform composition applied to either selection:

```text
Maastokartta:
Application-owned layers            (fishing spots, etc. — ADR-0008, unchanged)
────────────────────────
External overlays                   (SYKE bathymetry depth contours — ADR-0008's slot, now built by TD-027 §20–§27; hillshade remains unbuilt)
────────────────────────
Composed base map:
    Selected MML layer (Maastokartta)   (MML's own cartography — user-selected)
    MapTiler Outdoor                    (worldwide underlay — always present, not user-selectable)

Ilmakuva:
Application-owned layers            (fishing spots, etc. — ADR-0008, unchanged)
────────────────────────
External overlays                   (SYKE bathymetry depth contours — ADR-0008's slot, now built by TD-027 §20–§27; hillshade remains unbuilt)
────────────────────────
Composed base map:
    MapTiler Satellite Hybrid            (the complete worldwide base map — selecting "Ilmakuva" selects this)
```

For Maastokartta, MML remains the primary, selected Finnish cartographic layer the angler actually chose, and MapTiler Outdoor supplies worldwide coverage beneath it, exactly as this ADR originally decided. For Ilmakuva, MapTiler Satellite Hybrid *is* the base map in its entirety in this milestone — there is no MML sub-layer to compose it with. Neither composition introduces "an application overlay" in ADR-0008's sense on its own — that term names the separate SYKE bathymetry/future-hillshade band (now partly built, by TD-027 §20–§27), which this ADR does not touch.

This ADR still does not specify the technical mechanism used to build either composition (a locally generated MapLibre style document with the appropriate raster source(s) per selection, or another approach). That mechanism belongs to TD-027.

### Why MapTiler

MapTiler was verified, from current official sources, against every criterion this decision needed:

- **MapLibre-compatible delivery:** MapTiler documents raster XYZ tile delivery for both Outdoor and Satellite Hybrid, consumable by the existing MapLibre GL rendering stack (ADR-0002) as an ordinary raster source. No renderer change is needed.
- **Relevant worldwide coverage for both roles:** MapTiler offers a purpose-built "Outdoor" style line (style id `outdoor-v4`) with hiking/biking trails, contour lines, hillshade, and terrain detail for the Maastokartta underlay; and a "Satellite Hybrid" style (style id `hybrid-v4`) that bakes in labels, roads, and place names over its aerial/satellite imagery — meaning it functions as a complete, self-contained aerial base map for Ilmakuva with no separate label layer needed.
- **Authentication model:** A per-account API key, supplied as a `key` query parameter on the tile URL — structurally identical to how MML's own `api-key` parameter is already used (TD-026 §0), so the existing configuration pattern (a build-time credential, never committed) extends naturally rather than requiring a new mechanism. One MapTiler credential covers both the Outdoor and Satellite Hybrid roles — they are the same provider account, not two separate integrations.
- **Licensing/attribution:** A small, on-screen attribution notice (`© MapTiler © OpenStreetMap contributors`, both linked) is required while either MapTiler product is displayed, plus a visible MapTiler logo on the free tier. MapTiler's own terms explicitly permit this to be presented behind a one-tap contextual popup on space-constrained mobile screens, rather than demanding permanent on-screen text — compatible with a mobile map UI. MapTiler's official copyright page does not require any additional imagery-provider-specific attribution text (e.g. naming Maxar or Airbus by name) beyond this standard notice, for either product.
- **Pricing/free tier:** The free plan (100,000 API requests/month, 5,000 map-loading sessions/month, no card required) applies uniformly to all of MapTiler's preset styles, including Outdoor and Satellite Hybrid — no separate paid tier or differential quota was found for satellite/aerial imagery specifically. On the free plan, exceeding a quota simply pauses service until the next month rather than generating a surprise bill.
- **Caching/offline terms:** MapTiler's Cloud Terms explicitly permit storing results in "a temporary personal cache (browser cache, mobile app cache, etc.) for use by a single end-user only," while prohibiting server-side caching, bulk/batch tile downloading, and redistribution without a separate MapTiler Server license. This applies identically to both products.
- **Direct client delivery reasonableness:** MapTiler's own terms name "mobile app cache" as an expected client-side usage pattern, and its API-key model is designed for direct-from-client use (with the customer responsible for monitoring/rotating their own key) — the same shape of trust model ADR-0008 already accepted for MML.

No fact used above was assumed from prior knowledge; all were checked against MapTiler's current official product pages, pricing page, terms pages, and copyright page (see [References](#references)).

### Why Ilmakuva Uses MapTiler Satellite Hybrid Directly, Not As an Underlay

Unlike Maastokartta (where MML's own topographic cartography is worth preserving as the primary in-Finland experience, with MapTiler filling the gap outside it), Ilmakuva's purpose — letting the angler visually recognize a shoreline, island, or bay from above — is served by a single, consistent worldwide aerial/satellite product, without needing to also compose it with MML's Finland-only Ortokuva. Using MapTiler Satellite Hybrid uniformly:

- Avoids a second, aerial-specific underlay/compositing mechanism (MML Ortokuva plus a worldwide aerial fallback) in addition to Maastokartta's topographic one, keeping the overall design smaller than building two independent-but-similar underlay mechanisms.
- Avoids introducing a visible quality/style seam exactly at Finland's border for the Ilmakuva selection specifically, which a "MML Ortokuva inside, MapTiler outside" composition would otherwise create.
- Matches this milestone's explicit, current product decision: MML Ortokuva is not used for Ilmakuva here. Reconsidering MML Ortokuva for Ilmakuva later (e.g. layering it above MapTiler Satellite Hybrid, within Finland only, mirroring Maastokartta's own composition) remains available as a future milestone, not foreclosed by this decision.

**This means Ilmakuva's rendering changes within Finland too, compared to the currently shipped MFS-026/TD-026 behavior**, which shows MML's own official Ortokuva aerial photography there. This is a deliberate, explicit product trade-off recorded here, not an oversight — see [Consequences](#consequences) for the resolution quality and failure-independence implications.

---

## Alternatives Considered

None of the following are permanently rejected. As with ADR-0008's own alternatives, they remain available for reconsideration if requirements, scale, budget, or product direction change.

### 1. MapTiler — selected

See [Why MapTiler](#why-maptiler) above. Selected because it satisfies every verified requirement (MapLibre compatibility, relevant worldwide/outdoor coverage, a credential model consistent with the project's existing MML pattern, workable attribution, a viable free tier, and terms compatible with direct client delivery) with no need for a proxy, a new renderer, or a disproportionate infrastructure investment.

### 2. Mapbox

**Pros:** Mature platform, strong tooling/documentation, global coverage, native MapLibre-adjacent heritage (MapLibre itself is a fork of pre-v2 Mapbox GL JS).

**Cons:** Commercial vendor with usage-based billing and its own terms of service. ADR-0002 already rejected Google Maps Flutter, and ADR-0008 already rejected Mapbox itself as the *Finnish* base-map provider, both for vendor lock-in and reduced long-term flexibility reasons. Nothing about the narrower "global fallback layer" role changes that calculus, and MapTiler already satisfies every requirement this role needs.

**Decision:** Not selected, for the same reasons ADR-0008 already declined Mapbox, applied to this narrower role.

### 3. Direct use of OpenStreetMap public tile servers

**Pros:** No cost, no API key, immediately available.

**Cons:** Identical to ADR-0008's own assessment of this option: OSM's public tile infrastructure is provided for light, general use and its usage policy explicitly discourages embedding directly in a distributed mobile application without a dedicated agreement; it offers no operational guarantee suitable for a production application. Adopting it here would recreate, for the global layer, the exact dependency risk ADR-0008 already declined to accept for the Finnish layer.

**Decision:** Not selected, consistent with ADR-0008's Alternative 5. Remains a reasonable fallback/development-only convenience, not an adopted production dependency.

### 4. Keeping MML-only coverage (status quo)

**Pros:** No new vendor, no new credential, no new cost, zero implementation effort.

**Cons:** Does not solve the actual product problem this ADR exists to address — the map remains visually empty the instant an angler moves outside Finland, which is exactly the gap `docs/project-status.md`'s Known Limitations and ADR-0008's own deferred item both already identify as unresolved.

**Decision:** Not selected. Recorded here as the explicit "do nothing" baseline this ADR improves on, not because it is unworkable in principle, but because it fails the stated product goal.

### 5. Building/hosting our own global tile infrastructure

**Pros:** Full control, no third-party terms, no per-request cost ceiling, no external outage risk.

**Cons:** Requires standing up and operating tile-generation and tile-serving infrastructure at a global scale (e.g., processing worldwide OpenStreetMap extracts and running a dedicated tile server), a categorically larger undertaking than the API-key-hiding proxy ADR-0008 already declined to introduce for a much smaller problem. This is disproportionate to this project's current scale (no production users yet, per `docs/project-status.md`) and would introduce exactly the kind of backend/infrastructure commitment both ADR-0002 (offline-first, vendor-independent but pragmatic) and ADR-0008 (no proxy "solely to hide the API key," direct-to-provider by default) have consistently avoided until a concrete need forces it.

**Decision:** Not selected, on proportionality grounds — not on the grounds that it would be technically impossible. Could be revisited if MapTiler's terms, pricing, or availability ever become unworkable at a materially larger scale than exists today.

---

## Credential and Security Implications

- A new MapTiler API key is required, obtained from a developer's own MapTiler account.
- The MapTiler key must never be committed to source control, exactly like the existing MML key (ADR-0008/TD-026). It is expected to reuse the same build-time-configuration convention TD-026 already established (a value supplied at build time, never hardcoded, logged, or checked in) — the exact mechanism (whether the same `--dart-define` pattern or another approach) is left to the future TD, not decided here.
- The initial architecture calls MapTiler directly from the mobile client over HTTPS. A backend or proxy is **not** introduced at this stage solely to hide this key, mirroring ADR-0008's identical decision for MML and for the same reason: MapTiler's own terms already name direct client/mobile-app usage as an expected pattern, and the customer (not MapTiler) is responsible for monitoring and protecting their own key — the same trust model already accepted for MML.
- As with MML, this means the application's request volume and MapTiler's own rate limits/terms are now also exposed directly to however many devices run the app. Revisiting this (a proxy, caching layer, or different plan) is anticipated as a future possibility, not ruled out, exactly as ADR-0008 already anticipated for MML.

---

## Licensing and Attribution Implications

- MapTiler requires an on-screen attribution notice (`© MapTiler © OpenStreetMap contributors`, both linked, plus a visible MapTiler logo on the free tier this project currently uses) while its map data is displayed, for both Outdoor and Satellite Hybrid alike. Its own terms explicitly accommodate small mobile screens: the attribution may sit behind a one-tap contextual popup rather than needing to be permanently visible full text, provided it remains reachable with one tap from the map.
- **Attribution obligations now differ by selection, since the two compositions no longer both include MML:**
  - **Maastokartta:** carries **two** distinct attributions — MML's existing, already-implemented `MapAttribution` (TD-026), and MapTiler's, for its Outdoor underlay.
  - **Ilmakuva:** carries **only** MapTiler's attribution. MML's attribution must **not** be shown while Ilmakuva is selected, since MML data is not part of that composition in this milestone — showing it would misattribute content that is not actually present.
- This ADR establishes that these obligations exist and must be correctly scoped per selection; it deliberately does not design how they are jointly presented (a combined notice, two separate small notices, a shared tap-to-expand panel, or another approach) — that is a future MFS/TD UI concern.
- MapTiler's official copyright page does not require any additional imagery-provider-specific attribution text (e.g. naming Maxar or Airbus) beyond its standard notice, for its satellite/aerial products.
- Removing or hiding MapTiler's attribution is not permitted without MapTiler's written consent (or switching to a different data source) — this constrains any future "clean map" UI idea; it is recorded here so it is not rediscovered as a surprise later.

---

## Cost and Scaling Implications

- MapTiler's free plan (100,000 API requests/month, 5,000 map-loading sessions/month, no credit card required) is judged sufficient for continued development and early small-scale use, consistent with this project's current state (no production users yet, per `docs/project-status.md`).
- On the free plan, exceeding a quota pauses the service until the next monthly cycle rather than producing an unexpected bill — a materially safer failure mode for a project at this stage than usage-based overage billing would be.
- A paid "Flex" plan (starting at $30/month, with higher session/request quotas) exists if real usage later grows beyond the free tier. Adopting it is not decided here and is not currently needed.
- As with MML (ADR-0008), larger-scale production usage may later require reassessing MapTiler's plan tier, introducing caching, or another delivery strategy — anticipated, not precluded, and explicitly out of scope for this decision.

---

## Offline and Caching Implications

- MapTiler's Cloud Terms explicitly permit an ordinary client-side "mobile app cache" for a single end-user's own use — the normal caching behavior any MapLibre-based tile client already performs is within terms.
- MapTiler's terms explicitly prohibit server-side caching, and bulk/batch tile downloading or redistribution, without a separate commercial MapTiler Server license.
- This ADR does **not** treat MapTiler as an offline-map solution. Offline maps remain the separate, deferred future concern ADR-0002 and ADR-0008 already established; nothing here changes that position, and this milestone does not attempt to make the global layer (or the MML layer) available without network access.
- Recorded for future reference only, not decided or scoped now: MapTiler's terms describe a commercial-subscription path (bundling a MapTiler Server license) that could become relevant *if* real offline-map support is ever pursued. This is noted so it is not lost, not so it is treated as a current decision.
- **(Revision Note 4)** The on-device MML tile-transformation step introduced below maintains its own small, bounded, LRU-evictable cache of already-masked tile output, purely as an ordinary performance optimization (avoiding re-fetching and re-processing a tile already seen this session or a recent one) — the same category of "ordinary client-side caching for a single end-user's own use" MML's and MapTiler's terms already permit and this project already relies on elsewhere. This is explicitly **not** offline-map support: the cache has no user-facing "download for offline use" affordance, has no guarantee any given tile remains cached, and does not change this ADR's position that offline maps remain a separate, deferred future concern.

---

## Failure Behavior

Failure independence now applies differently to each selection, since Ilmakuva no longer has a second, independent provider to fall back on:

- **Maastokartta** retains this ADR's original two-provider independence: MML and MapTiler Outdoor are served by two separate, independent third-party services. A failure or unavailability of one must not unnecessarily destroy usable coverage from the other. This guarantee comes specifically from MapTiler Outdoor's presence being unconditional — never gated by anything MML-related, at any revision.
  - If MapTiler is unreachable or fails, MML Maastokartta (and everything within its actual coverage, i.e., Finland) must remain unaffected and usable.
  - If MML is unreachable or fails, MapTiler Outdoor should not be assumed to fail with it merely because the two are visually composited together — they are independent network dependencies, not a single combined request.
  - **(Revision Note 4)** The on-device tile-transformation step MML's raster source is now served through must not become a shared point of failure for MapTiler: MapTiler's tiles are fetched directly by MapLibre from MapTiler's own delivery infrastructure and never pass through this step at all. A failure, crash, or slow response from the on-device step affects only MML's own visible content (which degrades to "not currently rendering there," letting MapTiler Outdoor beneath show through — a graceful, already-familiar-looking outcome, not a new failure mode the angler has to learn) — never MapTiler's.
- **Ilmakuva** has only one base-imagery provider (MapTiler Satellite Hybrid) in this milestone — there is no second provider for it to fail independently *of*. Failure independence for Ilmakuva instead means: a failure of MapTiler Satellite Hybrid must not prevent application-owned content (fishing-spot markers, controls, other entry points) from remaining as usable as reasonably possible, even though the base imagery itself has no fallback. This is a real, accepted asymmetry between the two selections — see [Consequences](#consequences).
- This ADR does not design the retry logic, error messaging, or loading-state UI for either composition. MFS-026's existing treatment of MML failure/loading states (FR-14 through FR-17) is the precedent an eventual MFS for this feature is expected to extend with an equivalent treatment for both compositions — left entirely to that future MFS/TD.

---

## Consequences

### Positive

- The map becomes usefully populated worldwide, not just inside Finland, directly closing the gap `docs/project-status.md`'s Known Limitations and ADR-0008 both already flagged as open.
- The angler never needs to select a separate "world map" mode — coverage composition is entirely architectural and invisible as a user-facing choice, satisfying the stated product goal directly.
- ~~No manually maintained Finland boundary/polygon is introduced~~ — **no longer accurate for Maastokartta, see [Revision Note 2](#revision-note-2-the-transparent-mml-fallback-assumption-was-disproved-by-physical-testing)**; remains true for Ilmakuva, which needs no boundary logic at all.
- MapLibre GL remains the sole renderer (ADR-0002 unaffected); both MML and MapTiler are consumed through the same existing rendering stack.
- **(Revision Note 4)** The Finland/Åland border and coastline are now visually correct at the pixel level, at any zoom, with both providers simultaneously visible in the same viewport where appropriate — a materially better result than either prior revision could achieve by construction, since both worked at the viewport level and MML's own tiles are not reliably transparent at that granularity (the specific defect Revision Note 4 traces directly to real pixel evidence).
- The Maastokartta and Ilmakuva selector (MFS-026) is fully preserved as the user-facing choice mechanism; for Maastokartta, this ADR is purely additive beneath MML's own cartography. (For Ilmakuva specifically, this ADR does replace MML Ortokuva's role in this milestone — see [Why Ilmakuva Uses MapTiler Satellite Hybrid Directly](#why-ilmakuva-uses-maptiler-satellite-hybrid-directly-not-as-an-underlay) and [Trade-offs](#trade-offs) — but the *selector itself*, and the "Ilmakuva" name/choice the angler makes, are unchanged.)
- Cost and credential handling extend an already-established pattern (a second build-time API key, direct-to-provider calls) rather than introducing a new architectural shape.

### Trade-offs

- **An explicit, application-owned geographic boundary is required for Maastokartta**, reversing this ADR's original "no manually maintained Finland boundary" position (see [Revision Note 2](#revision-note-2-the-transparent-mml-fallback-assumption-was-disproved-by-physical-testing)). This adds real design/maintenance surface (a polygon requiring sourcing) the original design believed it could avoid entirely. Accepted because the alternative — continuing to rely on MML's own unreliable transparency behavior — was shown to produce a visibly broken map, which is a worse outcome than the added mechanism's complexity. **As of Revision Note 4, this polygon's role has changed from a per-viewport switching input to a per-pixel masking input — see below.**
- ~~A zoom-activation threshold is now also required for Maastokartta's MML inclusion (Revision Note 3), on top of the geographic boundary above.~~ **Superseded by Revision Note 4 — kept here as an accurate record of what Revision 3 required, not because it still applies.** Pixel-level masking makes MML's rendering correct at every zoom by construction; there is no longer a separate zoom condition to design, tune, or maintain.
- **(Revision Note 4) A small, app-local (on-device, loopback-only) tile-transformation process is now required for Maastokartta's MML source.** This is new design/implementation/maintenance surface beyond either prior revision's boundary/zoom mechanisms — real image-processing logic, a local HTTP listener, and a dedicated on-device cache, none of which existed before. It replaces, rather than adds to, Revision Notes 2 and 3's mechanisms (both are removed as a direct consequence, not kept alongside this one) — see TD-027 §3C for the full accounting of what is removed versus what is newly required. Accepted because it is the only mechanism found, of everything investigated (including native MapLibre/GPU-level alternatives, which were evaluated and rejected as more complex and less maintainable — TD-027 §3C), capable of actually achieving a pixel-clean border, which viewport-level workarounds structurally cannot.
- A second commercial vendor dependency is introduced for the base map, in addition to MML. This sits in some tension with ADR-0002's general preference for vendor independence — accepted here because MML fundamentally cannot supply non-Finland coverage, and because building/hosting an equivalent in-house (Alternative 5) is disproportionate at this project's current scale.
- Attribution obligations must now be correctly scoped per selection (both MML's and MapTiler's for Maastokartta; only MapTiler's for Ilmakuva) — a small but real increase in UI/legal surface area beyond what MFS-026 alone required, and one that must not be gotten wrong in the Ilmakuva direction (showing MML attribution for content MML did not actually supply).
- **Ilmakuva loses the dual-provider failure independence Maastokartta retains.** Because Ilmakuva no longer uses MML at all in this milestone, a MapTiler outage (or a missing/invalid MapTiler credential) leaves Ilmakuva with no base-imagery fallback whatsoever — unlike Maastokartta, which still has MML as a working alternative within Finland. This is an accepted, explicit trade-off of using one worldwide provider directly for Ilmakuva rather than composing it with MML as Maastokartta does; application-owned content (fishing spots, controls) remains the only thing guaranteed to keep working in that scenario.
- **Ilmakuva's image quality/resolution within Finland is no longer guaranteed to match MML's own dedicated Finnish aerial photography.** MML Ortokuva is Finland-specific, high-resolution aerial imagery; MapTiler's satellite/aerial imagery is a global product whose resolution varies by region (as low as 2m/px in much of the world, with higher resolution — down to centimeters — only in some areas). Whether MapTiler's coverage over Finland specifically is visually comparable to what anglers currently see from MML Ortokuva has not been confirmed and should be checked before this ships (see TD-027 for the corresponding verification item).
- Two independent external services still underlie Maastokartta's composition (MML, MapTiler Outdoor); this is mitigated by treating their failure modes as independent by design, not by assuming either service is more reliable than it is. Ilmakuva has only one.
- A second API credential (shared across both MapTiler roles) must be provisioned, kept out of source control, and monitored, mirroring the existing operational overhead already accepted for the MML key.
- This ADR does not resolve the technical mechanism for compositing tile sources into what reads as one continuous base map for either selection; that real design work is deferred to TD-027.

---

## Relationship to ADR-0002 and ADR-0008

- **ADR-0002 (Map Technology):** MapLibre GL remains the rendering technology; this decision changes nothing about the renderer. MapTiler is selected in part *because* its MapLibre GL Native/JS support is mature and well-documented, directly satisfying ADR-0002's original vector/custom-styling rationale — a rationale ADR-0008 could not fully exercise for the Finnish layer (which deliberately uses MML's own raster rendering as-is) but which applies naturally here, since there is no equivalent "preserve an authority's official rendering" constraint for a global fallback layer.
- **ADR-0008 (Base Map Provider and Delivery):** This ADR does not reopen or revise ADR-0008's decisions for the **Maastokartta** selection — MML Maastokartta remains its provider, raster WMTS remains its delivery format, and the direct-client-to-provider/no-proxy/credential-never-committed stance is reaffirmed and extended (not replaced) to cover MapTiler as well. This ADR specifically resolves the one item ADR-0008 explicitly named and deferred: "non-Finland/global base-map coverage... remains a distinct, not-yet-decided future consideration... Any such work would need its own ADR." This is that ADR.
  For **Ilmakuva** specifically, this ADR does go further than ADR-0008's Alternative 3 originally anticipated: ADR-0008 assessed MapTiler only as *not selected* for Finland's base maps, with a noted possibility it "could be reconsidered for non-Finnish coverage if the application ever expands beyond Finland." This ADR now selects MapTiler Satellite Hybrid as Ilmakuva's *entire* worldwide base map, including within Finland — a genuine replacement of MML Ortokuva for this selection in this milestone, not merely an underlay beneath it. MML Ortokuva itself is not deprecated or removed from the project; it is simply not used by the Ilmakuva selection here, and remains available for reconsideration by a future milestone.

---

## Scope

This decision defines:

- That Maastokartta's composition is a global, worldwide MapTiler Outdoor layer added beneath the selected MML Maastokartta base map (unchanged from this ADR's original decision).
- That Ilmakuva's composition is MapTiler Satellite Hybrid used directly as the complete worldwide base map, with MML Ortokuva not used by this selection in this milestone.
- MapTiler as the provider for both roles, delivered as raster XYZ tiles (not MapTiler's hosted vector style document) — a revision from this ADR's original delivery-format decision, made once TD-027's investigation showed the remote-style approach would undermine failure independence.
- Direct client-to-MapTiler HTTPS delivery, with no backend/proxy introduced solely to hide the API key.
- That MapTiler's API credential must never be committed to source control, and that one credential covers both the Outdoor and Satellite Hybrid roles.
- That MML Maastokartta and Ilmakuva remain the only user-facing, selectable base-map choices; MapTiler is not user-selectable in either composition.
- That no manually maintained boundary/polygon/mask is introduced for Ilmakuva (unchanged; it has no coverage-dependent behavior at all).
- **That an explicit, application-owned Finland/Åland coverage geometry underlies Maastokartta's MML rendering** — required because neither MML's own transparent no-data tile behavior (Revision Note 2) nor a viewport-center-plus-zoom switching rule built on top of it (Revision Note 3) was shown to be reliable, and direct pixel-level evidence (Revision Note 4) subsequently showed *why*: MML's own out-of-coverage tiles are opaque, not transparent, so no viewport-level rule could ever have produced a clean result. As of Revision Note 4, this ADR requires that geometry to be used to make out-of-coverage MML pixels transparent **before MapLibre renders them**, via a small on-device process — not to decide, per viewport, whether MML's source belongs in the style at all. MapTiler Outdoor's own presence remains unconditional throughout.
- ~~That Maastokartta's inclusion of MML is additionally gated on the camera's current zoom being at or above an activation threshold (Revision Note 3).~~ **Superseded by Revision Note 4, kept here as a historical record.** Pixel-level masking is correct at every zoom by construction; no separate zoom condition exists.
- The expectation that Maastokartta's two providers (MML, MapTiler Outdoor) must be able to fail independently of one another; and that Ilmakuva's single provider (MapTiler Satellite Hybrid) failing must not prevent application-owned content from remaining as usable as reasonably possible.
- That Maastokartta's attribution must satisfy both MML and MapTiler; that Ilmakuva's attribution must satisfy only MapTiler, and must not show MML attribution for content MML did not supply.

This decision does **not** define, and defers to a future MFS and TD (not yet created, beyond what TD-027 already designs):

- The exact technical mechanism for compositing either provider combination into what reads as one continuous base map (e.g., source/layer structure within a locally generated MapLibre style document, zoom-range/tile-pyramid alignment between providers, or another approach).
- The exact geographic definition of Maastokartta's coverage geometry (vertex data/source, precision, any coastal/territorial-water buffering) and the exact mechanism that applies it to MML's tiles (the on-device tile-transformation process's internal design — classification, masking algorithm, caching, lifecycle) — this ADR establishes only that out-of-coverage MML pixels must become transparent before rendering, and that a rectangular bounding box is not sufficient; TD-027 §3C owns the concrete design.
- ~~The exact zoom value at which MML activates~~ — no longer applicable; superseded by Revision Note 4.
- The exact UI treatment for presenting the per-selection attribution requirements.
- Loading, transition, and failure/error UX for either composition, and how it relates to MFS-026's existing MML loading/failure treatment.
- The API-key configuration/injection mechanism for MapTiler (whether it reuses TD-026's `--dart-define` convention or another approach).
- Any database schema, persistence, or migration impact, if a future TD determines one is needed (none is assumed here).
- Offline map support for any layer — remains a separate, not-yet-scoped future concern (ADR-0002, ADR-0008), unchanged by this decision.
- Hillshade, or any other future overlay named by ADR-0008 beyond SYKE bathymetry — untouched by this decision. (SYKE bathymetry itself was subsequently designed and built by TD-027 §20–§27, unrelated to this ADR's own MapTiler/fallback scope.)
- Whether and how MML Ortokuva might be reintroduced for the Ilmakuva selection in a future milestone — explicitly left open, not foreclosed, and not designed here.

---

## Experimentally Verified MML Behavior

This section applies to the **Maastokartta** composition specifically (MapTiler Outdoor beneath MML Maastokartta). It is not relevant to Ilmakuva's composition, which does not use MML at all and therefore has no transparent-tile/boundary behavior to rely on in the first place.

This decision's "no manual Finland boundary needed" design for Maastokartta rests on the following, verified directly (not assumed) during physical-development investigation prior to this ADR:

- A live MML tile request for a location outside MML's coverage (tested against Paris and Stockholm) returns HTTP 200 with a valid, correctly-sized 256×256 PNG — never an error, a broken image, or a distorted response.
- That PNG is a palette-indexed (PNG color type 3), 1-bit image with exactly one palette entry (black, `RGB(0,0,0)`) and a `tRNS` transparency chunk giving that entry alpha `0`. Every one of its 65,536 pixels decodes to `RGBA(0, 0, 0, 0)` — the entire tile is fully transparent, with no partial-opacity pixels anywhere.
- Because the tile is fully transparent, a raster or vector layer placed beneath it in the same MapLibre composition remains completely visible through it — an MML no-data tile contributes nothing to the rendered image.
- A request for Haparanda (Finnish territory immediately adjacent to the Swedish border) returned genuine MML imagery, confirming MML's own service coverage naturally follows Finland's actual territorial extent tile-by-tile, rather than being clipped at some coarser or application-assumed boundary. The application does not need to know, encode, or maintain where that boundary is.

This was expected to produce the correct visual result with no additional application-side masking logic: within Finland, MML's real cartography opaque and covering the global layer entirely; immediately outside it, MML's own transparent no-data tiles letting the global layer show through with no seam-detection code required. **Physical Android testing at broader geographic scale subsequently disproved this expectation** — see [Revision Note 2](#revision-note-2-the-transparent-mml-fallback-assumption-was-disproved-by-physical-testing) for what was actually observed and the resulting design change. This section's own bullet points above remain an accurate record of what was tested and found at the time; only the conclusion drawn from them (that this alone is a sufficient, general-purpose switching mechanism) has been withdrawn.

---

## References

- https://maplibre.org/
- https://pub.dev/packages/maplibre_gl
- https://www.maptiler.com/cloud/pricing/
- https://docs.maptiler.com/maplibre-gl-native-android/
- https://docs.maptiler.com/maplibre-gl-native-ios/
- https://www.maptiler.com/terms/cloud/
- https://www.maptiler.com/maps/outdoor/
- https://www.maptiler.com/maps/satellite/
- https://www.maptiler.com/copyright/
- https://docs.maptiler.com/cloud/api/maps/
- https://docs.maptiler.com/guides/map-design/attribution/add-attribution/
- https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/expert-users/product-descriptions/open-data-wmts-service
- docs/adr/0002-map-technology.md
- docs/adr/0008-base-map-provider-and-delivery.md
- docs/specifications/MFS-026-selectable-mml-base-maps.md
- docs/technical-designs/TD-026-selectable-mml-base-maps.md
- docs/technical-designs/TD-027-worldwide-base-map-coverage.md
