# Grade calibration notes

Live recipes: [`FilmStocks.swift`](../PostcardFilm/Processing/FilmStocks.swift) + overlays in [`PolaroidPipeline.swift`](../PostcardFilm/Processing/PolaroidPipeline.swift). House pixel reference: [`Grade.swift`](../PostcardFilm/Processing/Grade.swift). Frame: [`FrameGeometry.swift`](../PostcardFilm/Processing/FrameGeometry.swift).

## The pack — Kodachrome family (artist labels)

At shutter the app draws one of five stocks. The user never picks and never sees the name. Persist `filmStock` **and** `filmStrength` on each print so reburn keeps the same emulsion and expression. Every cousin inherits **Kodachrome grammar**: denser darks, forward reds/oranges, restrained blues. **No grain overlay** (the old low-res noise tile read as pixelation on bright whites). Serendipity still jitters **brightness / contrast / edges** by print id.

DEBUG / docs labels (never in product UI):

| Code | Artist | Tone role | Daylight feel | Night / flash |
|------|--------|-----------|---------------|---------------|
| `onestep` | **Matisse** — house K64 | Sunny-day Kodachrome | Forward red, sat ~1.08, contrast ~1.04, rim vignette ~0.65 | Expression bands + serendipity EV jitter |
| `sun660` | **Van Gogh** | Golden / dusk warmth | Soft fill (~0.10), rim vignette ~0.80, edge burn | Milder night fill; no double-blow if center already lit |
| `mini9` | **Picasso** | Cool blues, reds forward | Deeper blues, closed darks | Stays cool, not cyan |
| `natura` | **Monet** | Olive Polaroid foliage | Cooler green (not yellow lawn), contrast ~1.04, denser darks | Slightly more EV at night; shadows stay closed |
| `m6` | **Rembrandt** | Densest Dmax | Lower EV, deepest shadows | Cooler shadows; reds still pop |

**Developer only:** on Debug builds from git branch `test`, Home shows an **auto / manual** chip that can force a stock + gentle/medium/bold expression before shutter (skips random draw only; Developing unchanged). Never on `main` / `release` / Release Archive. See [`.cursor/rules/film-debug-picker.mdc`](../.cursor/rules/film-debug-picker.mdc).

Research target: Kodachrome 64 slide look — rich reds, gold oranges, closed shadows, luminous greens behind reds, deep grey-blue skies. **No** fake corner light-leak, **no** cream bloom hotspot, **no** circular inner vignette. Outdoor edge darkening (`edgeBurn`) and rim-only vignette are fine.

## Three calibration layers

Rendering always runs these layers in order. Retune one layer at a time.

```
ungraded square
  → 1. Scene adaptation   (FilmScene.measure → nightAmount / alreadyFlashed / meanChroma)
  → 2. Stock identity     (FilmStock.recipe day/night knobs + chroma sat bump)
  → 3. Expression         (FilmExpression.apply — usually gentle, rarely bold; optional depth kiss)
  → 4. Serendipity        (FilmSerendipity.vary — EV / contrast / edges; never leak or grain)
  → applyGrade + overlays → cream frame
```

### 1. Scene adaptation

Measure the ungraded square: `meanLuma`, `centerBias` (center − edge), `meanChroma`. Van Gogh (`sun660`) suppresses double flash when `centerBias > 0.12`. Low chroma (`< 0.12`) adds a modest saturation bump so dull gray/green frames do not go flat; colourful brick+sky scenes get no extra punch.

### 2. Stock identity

Day/night recipes in `FilmStocks.swift` define each cousin’s color matrix, EV, contrast/sat bands, and rim-vignette baselines. House Matisse (`onestep`) is the Kodachrome 64 daylight recipe. Keep the ≥ 0.025 pixel-delta floor vs Matisse on mid-gray and gradient at **full** strength (`filmStrength = 1.0`).

### 3. Expression (per-print softness)

Invisible strength drawn once at capture, seeded by `printId|stock|expr` — **all five stocks**, including Matisse:

| Band | Share | Strength |
|------|-------|----------|
| Gentle | ~65% | 0.42…0.62 |
| Medium | ~25% | 0.62…0.82 |
| Bold | ~10% | 0.82…1.00 |

- Matisse lerps from a soft house anchor → full `FilmRecipe.onestep`; bold (`1.0`) matches today’s house look.
- Cousins lerp harsh knobs toward house anchors; **leak, bloom, and grain always stay 0**.
- **Depth kiss:** ~18% of prints (seeded `printId|stock|depthkiss`) get a tiny contrast bump + darker shadows (+ optional vignette) — no hue / green / yellow shift. Reburn-stable.
- Persist `filmStrength` on the record. Missing field → `1.0` (legacy full look). Reburn must pass the stored value.

Safe ranges after expression + serendipity:

| Knob | Soft floor | Hard ceiling |
|------|------------|--------------|
| contrast | ≥ 0.90 | ≤ 1.18 |
| flashAlpha | 0 | ≤ 0.28 |
| grainAmount | 0 | 0 |
| edgeBurnAmount | 0 | ≤ 0.18 |
| vignetteStrength | ≥ 0.45 | ≤ 1.15 |
| leakAlpha / bloomAlpha | 0 | 0 |

## Locked house look (`onestep` / Matisse)

Kodachrome 64 daylight — retuned from the old Polaroid fog + corner leak.

- Sunny exposure (~0.28 EV) with denser darks (slight negative `shadowAmount`)
- Forward red / gold orange midtones; restrained blue
- Cream highlights — never paper-white
- Soft chemistry blur (~0.42); **no grain overlay**
- Rim-only vignette (~0.65); **no leak, no bloom**
- Cream frame `#F6F1E7`; side/top ~**9%** of image side; bottom strip ~**24%** of canvas height
- Caption ~**30%** of strip height (medium); optional highlighter behind glyphs; photo-well hairline

## What actually renders

`PolaroidPipeline.renderPolaroid` path: measure scene → base recipe (+ chroma sat) → `FilmExpression.apply` (incl. optional depth kiss) → `FilmSerendipity.vary` → `applyGrade` (exposure → matrix → highlight/shadow → colorControls → shadow-sat → blur) → overlays (rim vignette / optional flash / edge burn) → cream frame. Leak, bloom, and grain draw helpers remain but never fire (`alpha = 0`). `Grade.gradePixel` is the house reference for tests — it does not touch output directly.

## How to retune

1. Shoot a reference scene on a physical iPhone (or drop a reference Kodachrome scan).
2. Adjust day/night recipes in `FilmStocks.swift` and/or house `Grade.colorMatrix` / `FilmRecipe.onestep`.
3. If prints feel harsh too often, lower expression bands or harshMix — do not reintroduce leak/bloom.
4. Keep XCTest green — `FilmStockTests` (artist roles, Matisse expression, depth kiss, Monet olive locks, pixel-delta ≥ 0.025, pipeline stock×strength loop) + `GradeTests` + `PipelineSmokeTests` + `FilmDebugPickerTests`.
5. Keep `FrameGeometryTests` bands in sync if `sideRatio` / `bottomRatio` change.
6. Device QA matrix: daylight outdoor, open shade, indoor tungsten, night no iPhone flash, night with flash on, backlit. Same scene across all five stocks — if two look the same at strength 1.0, push knobs before shipping.

## Capture haptics

Sequence in [`Haptics.swift`](../PostcardFilm/Support/Haptics.swift): punchy shutter on press → quiet flash/pipeline → postcard milk with “developing…” (~0.8s) → label fades → milk clears over ~2s (print fades in) with rising `developPulse` across that ~2.8s window → strong `developDone` when the print is fully out. Device check: eyes closed — click, quiet, countdown chemistry, satisfying reveal. Motion inventory (do not shorten this chemistry for “perf”): [`ANIMATIONS.md`](ANIMATIONS.md).

## Status

The pack is a **Kodachrome family** with DEBUG artist labels (Matisse / Van Gogh / Picasso / Monet / Rembrandt). Fake Polaroid corner-sun, inner circular vignette, and grain overlay are retired. Brightness / contrast chance remain; occasional depth kiss (contrast + darker darks) in expression.
