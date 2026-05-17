# Globe Design — "The Architect's Globe"

Design specification for replacing the current educational choropleth globe with a
premium matte-sphere globe aligned to the Stepped design language.

## Current state — what's wrong

| Problem | Detail |
|---------|--------|
| Choropleth fills | Visited countries are solid `primaryContainer` blocks. Reads as population-density map, not premium travel app. |
| Ocean colors | Generic blue-gray (`#1E2B3F` → `#13202F` → `#0A1422`). Zero relationship to app color DNA (`nightForest` #121816, moss/parchment palette). |
| Sphere surface | 3-stop radial gradient on a circle. No texture, no materiality. Glossy "globus" feel. |
| Borders | Thin 0.42–0.85px strokes. Reads as SVG vector outline, not intentional design. |
| Pin markers | Flat colored circles (`visitedPin`, `pinCore`). Looks like debug overlay. |
| Atmosphere | Single ring using `scheme.primary` at ~18% alpha, 10% overshoot. Afterthought. |
| Rim | Flat `outlineVariant` circle stroke. No light response. |
| No idle animation | Globe is static when not touched. App's other screens use animation liberally. |
| No frosted container | Globe sits directly on surface background. Every other card in app uses `FrostedSquircle`. |

## App design language (reference)

Source: `lib/theme/app_theme.dart`

- **Dark surface**: `nightForest` (#121816) deep green-black
- **Surface containers**: `nightSurface` (#1B2320) for low, #202926 for mid, #27322E for high
- **Primary**: `moss` (#43655B), `mossSoft` (#8FB3A7) accents
- **Secondary**: `lake` (#436274), `lakeSoft` (#C4E4F9)
- **Tertiary**: `earth` (#695D40), warm brass #C8B38C
- **Typography**: Georgia serif for headlines, high letter-spacing on labels
- **Shapes**: Squircle with 22–38px corner radius everywhere
- **Materials**: Frosted glass (`FrostedSquircle` with `ImageFiltered` backdrop blur), matte finishes, low-alpha colored overlays, never opaque blocks
- **Animation curves**: `easeOutCubic`, durations 260–460ms

## Design target: "The Architect's Globe"

Think of a physical globe in a high-end architect's office or private library — dark
matte-finished ocean, subtle brass/gold accents, countries rendered as tactile relief
rather than colored-in blocks. Understated, luxurious, cohesive with the moss/forest
palette.

---

## 1. Ocean — matte textured sphere

### 1.1 Color palette

Replace `_GlobePalette` ocean stops to anchor in `nightForest`:

```
oceanHighlight: #1E2E28  (nightForest + slight moss lift)
oceanBase:      #141F1A  (nightForest midpoint)
oceanDeep:      #0C1410  (near-black with moss undertone)
```

Rationale: The ocean is the largest visible surface. Tying it to `nightForest` makes
the globe feel like it belongs to the app, not a disconnected component.

### 1.2 Noise/grain texture overlay

Paint a pre-generated noise image over the sphere at 2–4% opacity to kill the glossy
"plastic globus" look and give a matte, paper-like finish.

Implementation approach:

```dart
// Generate once at startup, cache as dart:ui Image
// Seeded noise — 256×256 grayscale pixels, each pixel random 0–255
// Paint as overlay circle with low opacity
final noisePaint = Paint()
  ..shader = ImageShader(noiseImage, TileMode.repeated, TileMode.repeated)
  ..color = Colors.white.withValues(alpha: 0.02);
canvas.drawCircle(center, globeRadius, noisePaint);
```

The noise image can be generated with `dart:ui decodeImageFromPixels` using a
seeded random generator (deterministic, no per-frame cost after first frame).

### 1.3 Multi-layer depth

Current sphere uses a single 3-stop gradient. Replace with two overlapping gradients
for a more convincing 3D illusion:

- **Layer 1 — base ocean**: Off-center radial, warm-cool split. Highlight slightly
  off-center to the upper-left, deep shadow to lower-right.
- **Layer 2 — terminator hint**: Very subtle darker crescent on one side to suggest
  a light terminator (like a sphere under studio lighting, not harsh sunlight).

### 1.4 Rim light (upper-left catch light)

Already partially implemented (`_paintSphereSurface` draws a rim light gradient).
Enhance: make it warmer, slightly larger, and tint with `mossSoft` at very low alpha
to catch the app's accent color.

---

## 2. Countries — relief rendering, not choropleth

This is the single biggest design upgrade. Instead of "visited = color A,
unvisited = color B", all land uses the same base fill, and visit status is
communicated through elevation and subtle glow.

### 2.1 Base land fill

All land polygons use a consistent warm-gray/sand fill that references the app's
light-mode `parchment` (#F4F1E8) desaturated into dark mode:

```
landFill: #2C2820  (warm dark gray with earth undertone, ~90% opacity)
landBorder: #5A5246 (subtle warm border, ~50% opacity)
```

This is the "terrain base" — it should read as matte land sitting on a matte ocean.

### 2.2 Visited — raised relief

Visited countries get a **subtle inner highlight on the light-facing edge**,
creating a shallow emboss/relief effect. This makes visited countries appear
slightly raised from the globe surface — tactile, premium, understated.

Implementation approach:

```dart
// For each visited ring, after painting base fill:
// 1. Paint thin highlight along edges where the face normal points toward light
// 2. Light direction = upper-left (matches rim light position)
// 3. Use a slightly warmer/more saturated version of landFill as highlight color
//    visitedHighlight: #8FB3A7 at 12-18% alpha (mossSoft tint)
```

Alternative cheaper approach (no per-vertex normal calculation):

- Paint visited land with the same base fill
- Paint a thin inner glow stroke in `mossSoft` at low opacity (12–15%)
- The moss green tint communicates "visited" without the choropleth block-color look

### 2.3 Selected — focused glow

Selected country gets:

1. Base land fill (same as all other countries)
2. Soft under-glow: paint the filled polygon a second time with `maskFilter` blur
   (Gaussian, sigma ~4–6px) using `mossSoft` at ~25% alpha
3. Crisp border on top in `mossSoft` at ~80% alpha, slightly thicker stroke
4. Optional: pulse the glow opacity with a subtle sine animation

The glow-underlay + crisp-border technique is the same pattern used in premium map
UIs (Mapbox Studio, Dark Sky, etc.).

### 2.4 Unvisited — minimal presence

Unvisited countries should be visible but recessive:
- Same base land fill
- Very thin, low-opacity border (thinner than current `defaultStroke`)
- No glow, no highlight

### 2.5 Stroke width refinement

Current stroke widths scale with `baseRadius`. Keep the scaling but tighten values:

```
defaultStroke:  0.35–0.55px  (recessive, barely-there)
visitedStroke:  0.55–0.75px  (subtle but intentional)
selectedStroke: 0.80–1.20px  (clear, confident)
```

All strokes use `StrokeJoin.round` + `StrokeCap.round` (already in place).

---

## 3. Markers — luminous dots

Replace the flat colored pin circles with small luminous dots.

### 3.1 Design

Small (2–5px radius) dots with a soft radial glow:

```dart
// Glow underlay
final glowPaint = Paint()
  ..shader = Gradient.radial(center, radius * 3, [
    markerColor.withValues(alpha: 0.5),
    markerColor.withValues(alpha: 0.0),
  ]);
canvas.drawCircle(center, radius * 3, glowPaint);

// Crisp core
canvas.drawCircle(center, radius, Paint()..color = markerColor);
```

### 3.2 Colors

```
visitedDot:  mossSoft (#8FB3A7) at 85% alpha
selectedDot: tertiary (#C8B38C / warm brass) at 90% alpha
```

### 3.3 Placement

Only mark visited/selected countries. One dot per country, placed at the centroid
of the largest visible ring (already implemented — keep this logic).

---

## 4. Atmosphere — layered ambient halo

Replace the single-ring atmosphere with a two-layer system:

### 4.1 Inner glow (tight to sphere edge)

- Radius: sphere + 2–3% overshoot
- Color: `mossSoft` at 6–10% alpha
- Function: subtle colored rim separation between globe and background

### 4.2 Outer halo (soft diffusion)

- Radius: sphere + 8–12% overshoot
- Color: `lakeSoft` (#C4E4F9) at 2–4% alpha (cool contrast to warm moss)
- Function: soft atmospheric diffusion, makes the globe feel like it's in space

### 4.3 Color rationale

Inner glow uses `primary` (moss) — warm, cohesive. Outer halo uses `secondary`
(lake) — cool contrast that creates depth. The warm/cool split at the globe edge
is a classic premium rendering technique (Apple's product renders use it heavily).

---

## 5. Rim — polished edge ring

Replace the flat `outlineVariant` stroke with a rim that responds to light:

### 5.1 Gradient-based rim

Instead of a solid color stroke, use a `SweepGradient` or paint two arcs:

- Upper-left 180°: lighter, tinted with `mossSoft` at 30–40% alpha
- Lower-right 180°: darker, `outlineVariant` at 20–25% alpha

This creates the illusion of a polished metal or glass rim catching directional
light — the same material principle as the frosted glass borders in your UI.

### 5.2 Width

`baseRadius * 0.008` (slightly thicker than current 0.006) clamped to 1.0–3.0px.
A slightly more confident rim reads as intentional design rather than anti-aliasing
artifact.

---

## 6. Idle micro-animation — "breathing" globe

When no user interaction is active, the globe should slowly rotate to feel alive.

### 6.1 Behavior

- Very subtle rotation around the polar axis: ±0.015–0.025 radians amplitude
- Sinusoidal ease-in-out over 8–12 seconds
- Pauses immediately on any user interaction (pointer down)
- Resumes 3–4 seconds after last interaction ends (pointer up, inertia stops)

### 6.2 Implementation

The `AnimationController` + `TickerProviderStateMixin` infrastructure already exists
in `_GlobeWidgetState`. Add a separate `_idleAnimationController` that drives a
sine-based offset added to `_rotation`:

```dart
// In _handleInertiaTick or a dedicated idle tick:
if (!_isInteracting && !_isAnimating) {
  _rotation = _baseRotation + sin(_idlePhase) * _idleAmplitude;
}
```

### 6.3 Constants

```
idleAmplitude: 0.02 rad
idlePeriod: 10 seconds
idleResumeDelay: 3 seconds after last interaction
```

---

## 7. Container — frosted backdrop card

The globe widget currently sits directly on `colorScheme.surface`. Every other
information-dense card in the app uses `FrostedSquircle` with backdrop blur.

### 7.1 Globe card container

Wrap the globe in a frosted glass card that floats above the surface:

```dart
FrostedSquircle(
  radius: 36,
  blurSigma: 20,
  color: colorScheme.surface.withValues(alpha: 0.45),
  borderColor: colorScheme.primaryContainer.withValues(alpha: 0.10),
  shadowColor: colorScheme.secondary.withValues(alpha: 0.08),
  child: GlobeWidget(...),
)
```

### 7.2 Placement in map_screen.dart

The card sits behind the globe, centered, with padding that accounts for the top
bar and bottom dock. The `_MapAtmosphere` gradient overlay (lines 428–463 in
`map_screen.dart`) already creates a vignette effect — the frosted card would sit
beneath that gradient, adding a mid-layer.

### 7.3 Alternative: globe with integrated background

If a separate card widget complicates the z-ordering (globe → card → atmosphere),
the frosted effect can be painted directly as an additional paint step in
`GlobePainter` — a frosted-square behind the sphere. But the widget approach is
cleaner.

---

## 8. Performance — what changes

### 8.1 New per-frame costs

| Addition | Cost | Notes |
|----------|------|-------|
| Noise texture overlay | 1 drawCircle blit | Pre-rendered 256×256 image, cached |
| Inner edge highlight for visited | 1 extra drawPath per visited ring | Only visible rings, already in render queue |
| Selected glow underlay | 1 drawPath with maskFilter | Only 1 ring at a time |
| Luminous dot glow | 1–2 drawCircle with radial gradient per marker | ~5–20 markers, cheap |
| Layered atmosphere | 1 extra drawRect | Trivial |
| Idle animation tick | 1 extra Ticker | Same pattern as inertia ticker |

### 8.2 No changes to

- Per-vertex projection loop (no new trig)
- LOD switching (still 2 levels, zoom < 2.8 → lod 0)
- Culling (centroid depth + viewport rect checks unchanged)
- Silhouette clipping (computeSilhouettePoint unchanged)
- Hit testing (_hitTestRing unchanged)

### 8.3 Budget

Total estimated per-frame cost increase: < 15% on the CustomPainter. The noise
image and atmosphere changes are one-time setup costs. The per-ring extra draws
only affect visible rings (already the tightest part of the pipeline).

---

## 9. Implementation order

1. **`_GlobePalette` recolor** (globe_painter.dart lines 755–828) — ocean stops,
   land fill, borders, markers. Highest impact, lowest risk. ~30 lines changed.

2. **Noise texture** (globe_painter.dart, new method `_paintOceanTexture`) —
   generate seeded noise image, paint overlay. ~40 lines added.

3. **Atmosphere layers** (globe_painter.dart `_paintAtmosphere`) — split into
   inner glow + outer halo. ~20 lines changed.

4. **Relief rendering for visited** (globe_painter.dart `_paintRing`) — add
   highlight pass for visited rings. ~25 lines added.

5. **Selected glow underlay** (globe_painter.dart `_paintRing`) — maskFilter
   under-draw for selected ring. ~15 lines added.

6. **Luminous markers** (globe_painter.dart `_paintMarkers`) — replace flat
   circles with glow + core. ~20 lines changed.

7. **Gradient rim** (globe_painter.dart `_paintRim`) — replace solid stroke
   with light-responsive edge. ~20 lines changed.

8. **Idle animation** (globe_widget.dart) — add idle Ticker. ~50 lines added.

9. **Frosted container** (globe_widget.dart or map_screen.dart) — wrap globe
   in FrostedSquircle. ~15 lines changed.

---

## 10. Color reference table

```
                    Current                     →  Target
Ocean highlight     #1E2B3F (generic navy)      →  #1E2E28 (nightForest + moss)
Ocean base          #13202F (generic dark blue)  →  #141F1A (nightForest mid)
Ocean deep          #0A1422 (generic near-black) →  #0C1410 (near-black moss)
Land fill           #2A3A4F (blue-gray)          →  #2C2820 (warm earth gray)
Land border         #7B8FA8 (blue-gray)          →  #5A5246 (warm subtle)
Visited fill        primaryContainer (amber/teal) →  same as land fill + moss edge
Visited border      primary                      →  mossSoft at 30-40% alpha
Selected fill       tertiaryContainer (peach)    →  same as land fill + glow
Selected border     tertiary                     →  mossSoft at 70-80% alpha
Atmosphere          primary                      →  inner: mossSoft, outer: lakeSoft
Rim                 outlineVariant               →  gradient: mossSoft → outlineVariant
Ambient shadow      scheme.shadow                →  scheme.shadow (keep)
```

---

## 11. Files affected

| File | Scope of change |
|------|----------------|
| `lib/features/map/globe/globe_painter.dart` | Primary. Palette, ocean, atmosphere, rings, markers, rim — ~150 lines total |
| `lib/features/map/globe/globe_widget.dart` | Secondary. Idle animation, optional frosted wrapper — ~65 lines |
| `lib/features/map/map_screen.dart` | Minor. Frosted container placement (if done at widget level) — ~20 lines |
| `lib/features/map/globe/globe_projection.dart` | No changes |
| `lib/features/map/globe/globe_country_data.dart` | No changes |
| `lib/features/friends/widgets/read_only_globe_card.dart` | Inherits changes from GlobePainter palette changes automatically |

---

## 12. Design validation checklist

Before considering the redesign complete, verify:

- [ ] Ocean reads as matte, not glossy — noise texture visible at 200% zoom but not at normal viewing distance
- [ ] Visited countries distinguishable from unvisited without relying on color blocks
- [ ] Selected country clearly visually dominant (glow + thicker border)
- [ ] Atmosphere integrates globe with dark surface (no hard edge)
- [ ] Rim catches light directionally (upper-left lighter)
- [ ] Idle animation is barely noticeable — "did something just move?" not "it's spinning"
- [ ] Frosted card (if added) reads as floating above surface, not sitting on it
- [ ] All LOD levels render correctly (zoom in/out transitions)
- [ ] Performance: no frame drops at zoom 1.0 with 200+ countries visible
- [ ] Color harmony with the rest of the app (globe sits in dark mode next to moss/parchment UI)
- [ ] Light mode renders acceptably (secondary priority — app is dark-first)
