# MuscleMap — vendored fork

Upstream: https://github.com/melihcolpan/MuscleMap — MIT (see `LICENSE`, copyright © 2026 Melih Colpan).
Forked from **tag 1.6.4** (`7dc0307`, "Fix v1.6.4: center female back view in its viewBox").

Vendored into the app target rather than consumed as a SwiftPM dependency because PinWise needs one
capability upstream does not expose. Kept as a straight copy plus the additions below, so upstream
can be re-diffed: `diff -r <upstream>/Sources/MuscleMap App/iOSApp/Vendor/MuscleMap`.

## Why vendored and not a GitHub fork
All PinWise GitHub work lives on `TavioTheScientist`, but the local `gh` CLI is authenticated as
`octavioarias`, so `gh repo fork` would create the fork under the wrong account. Vendoring keeps the
change revertable in a single PR with no cross-repo or cross-account coordination.

## The addition: region-precise highlights

Upstream keys highlights by `Muscle` alone — `highlights: [Muscle: MuscleHighlight]`, and
`MuscleHighlight` carries no side. `heatmap(_:colorScale:)` even accepts `MuscleIntensity.side` and
then **discards** it. So a left-only injection tinted both sides of a region, and an upper-abdomen
injection filled the entire abdomen.

That is fine for a workout tracker (you train a muscle, not half of one). It is wrong for an
injection map, where PinWise tracks 16 distinct sites split left/right and upper/lower, and the
whole point is showing that you are over-using ONE spot.

Added, all additive — nothing upstream changes behaviour unless the new API is used:

| file | addition |
|---|---|
| `Heatmap/MuscleRegion.swift` *(new)* | `MuscleBand`, `MuscleRegionKey`, `RegionIntensity` |
| `Rendering/BodyRenderer.swift` | `regionHighlights` (defaulted `[:]`); per-PATH fill resolution instead of per-body-part; vertical band classification |
| `Views/BodyView.swift` | `regionHeatmap(_:colorScale:)`, and `regionHighlights` threaded to the renderer |

### How bands work
A body part's `left` / `right` arrays hold several paths that stack vertically (e.g. `.abs` has 4 per
side). The renderer sorts each side's paths by transformed bounding-box `midY` and splits them in
half: the top half is `.upper`, the bottom `.lower`. This is derived from the artwork at render time
rather than hard-coded, so it survives the viewBox re-centering upstream does per gender/side —
which is exactly why a clip-mask approach in PinWise was rejected.

Resolution order per path, falling back so existing callers are unaffected:
1. `regionHighlights[(muscle, pathSide, band)]` — most precise
2. `regionHighlights[(muscle, pathSide, nil)]` — whole side
3. `highlights[muscle]` — upstream behaviour
4. parent-group inheritance (upstream)
5. default fill

### Side semantics — the trap
`left` / `right` in the path data are **IMAGE** positions, not anatomy: `left` has the smaller x in
*both* front and back views (verified across quadriceps, deltoids, gluteal, triceps). On a FRONT view
the image's left is therefore the subject's **right**. Callers must flip for front views; PinWise does
this in `BodyMapView.imageSide(for:)`. Upstream's own `MuscleSide` is left as-is — this note exists so
the convention isn't rediscovered the hard way.

### Scope
`regionHighlights` is threaded to the direct `BodyRenderer` used by `standardBody` — the path a plain
`BodyView` renders, and the one PinWise uses. The animated / pulse / zoomable variants and the
interactive, tooltip and accessibility overlays are untouched: they wrap `BodyRenderer` through their
own initializers, and the overlays handle hit-testing and labels rather than fill. If PinWise ever
enables zoom or pulse on the injection map, region precision would need threading through those
wrappers too — it would silently fall back to muscle-level highlights rather than break.
