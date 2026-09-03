# Grade calibration notes

Live recipes: [`FilmStocks.swift`](../PostcardFilm/Processing/FilmStocks.swift) + overlays in [`PolaroidPipeline.swift`](../PostcardFilm/Processing/PolaroidPipeline.swift). House pixel reference: [`Grade.swift`](../PostcardFilm/Processing/Grade.swift). Frame: [`FrameGeometry.swift`](../PostcardFilm/Processing/FrameGeometry.swift).

## The pack (1.1.0)

At shutter the app draws one of five stocks. The user never picks and never sees the name. Persist `filmStock` **and** `filmStrength` on each print so reburn keeps the same emulsion and expression. Non-Original prints also get light **serendipity** jitter seeded by print id (soft grain / edge burn / tiny knob drift) so two shots of the same stock still feel like Polaroid chance.

Research target: muted contrast, creamy highlights, soft chemistry blur, gentle vignette, occasional soft edge burn — not digital-harsh HDR cousins. Pack cousins sit close to Original; most prints should feel soft; only sometimes does a stock lean into its full character.

| Code | Name | Tone role | Daylight feel | Night / flash |
|------|------|-----------|---------------|---------------|
| `onestep` | **Original (v1)** — frozen | Warm house Polaroid | Exact 1.0.0 look (leak + bloom); **no grain / no edge burn** | Same knobs day/night |
| `sun660` | Sun 660 | Soft flash + darker edges | EV ~0.40, **subtle** flash fill (~0.12), vignette ~1.18, soft edge burn | Milder night fill; no double-blow if center already lit |
| `mini9` | Mini 9 | Soft cool Instant | EV ~0.22, contrast ~1.06, mild crush, cool/blue, soft grain | Stays cool, not harsh |
| `natura` | Natura | Mild milky Fuji | EV ~0.40, contrast ~0.88, light lift, green-cyan | Opens more EV + greener shadows |
| `m6` | M6 | Soft dense rangefinder | EV ~0.18, contrast ~1.06, slightly low sat, soft blur ~0.48 | Cooler shadows; still no base leak |

## Three calibration layers

Rendering always runs these layers in order. Retune one layer at a time.

```
ungraded square
  → 1. Scene adaptation   (FilmScene.measure → nightAmount / alreadyFlashed)
  → 2. Stock identity     (FilmStock.recipe day/night knobs)
  → 3. Expression         (FilmExpression.apply — usually gentle, rarely bold)
  → 4. Serendipity        (FilmSerendipity.vary — micro jitter scaled by strength)
  → applyGrade + overlays → cream frame
```

### 1. Scene adaptation

Measure the ungraded square: `meanLuma` + `centerBias` (center − edge). Do not trust iPhone `flashMode` alone — Night mode and auto flash change the pixels first. Sun 660 suppresses double flash when `centerBias > 0.12`.

### 2. Stock identity

Day/night recipes in `FilmStocks.swift` define each cousin’s color matrix, EV, contrast/sat bands, and overlay baselines. **Original (`onestep`) is frozen** — do not retune. Keep the ≥ 0.025 pixel-delta floor vs Original on mid-gray and gradient at **full** strength (`filmStrength = 1.0`).

### 3. Expression (per-print softness)

Invisible strength drawn once at capture, seeded by `printId|stock|expr`:

| Band | Share | Strength |
|------|-------|----------|
| Gentle | ~65% | 0.42…0.62 |
| Medium | ~25% | 0.62…0.82 |
| Bold | ~10% | 0.82…1.00 |

- **Original** always resolves to `1.0` and skips scaling.
- `FilmExpression.apply` pulls harsh knobs (contrast, shadow crush/lift, flash, grain, edge burn, vignette) toward safe anchors more than color identity.
- Color matrix / saturation keep a minimum stock share (`idMix ≈ 0.58 + 0.42·t`) so gentle Mini / Natura / Sun / M6 still read as cousins, not Original.
- Serendipity jitter and rare blur/leak events scale by strength — bold drama is uncommon.
- Persist `filmStrength` on the record. Missing field → `1.0` (legacy full look). Reburn must pass the stored value.

Safe ranges after expression + serendipity (non-Original):

| Knob | Soft floor | Hard ceiling |
|------|------------|--------------|
| contrast | ≥ 0.68 | ≤ 1.12 |
| flashAlpha | 0 | ≤ 0.24 |
| grainAmount | 0 | ≤ 0.06 |
| edgeBurnAmount | 0 | ≤ 0.18 |
| vignetteStrength | ≥ 0.55 | ≤ 1.40 |

## Locked house look (`onestep` / Original)

**Do not retune.** Neutral tone knobs (`contrast`/`saturation` = 1.0, `highlightAmount` = 1.0, `shadowAmount` = 0) so the CI path matches shipped 1.0.0. Expression and serendipity are no-ops for Original.

- A little brighter / sunnier (Huji-leaning) — soft exposure lift (~0.32 EV), not digital HDR
- Warm yellow midtones (not orange)
- Lifted blacks (chemical fog) — never true black
- Cream highlights — never paper-white
- Soft contrast; teal-tinged deep shadows
- Extra saturation in dark areas only
- Soft edges; **no film grain**
- Soft vignette + subtle top-right light leak + tiny highlight bloom
- Cream frame `#F6F1E7`; side/top ~**9%** of image side; bottom strip ~**24%** of canvas height
- Caption ~**30%** of strip height (medium); optional highlighter behind glyphs; photo-well hairline

## What actually renders

`PolaroidPipeline.renderPolaroid` path: measure scene → base recipe → `FilmExpression.apply` → `FilmSerendipity.vary` → `applyGrade` (exposure → matrix → highlight/shadow → colorControls → shadow-sat → blur) → overlays (vignette / flash / leak / bloom / soft edge burn / soft grain) → cream frame. `Grade.gradePixel` is the Original reference for tests and `Scripts/verify_logic.swift` — it does not touch output.

## How to retune

1. Shoot a reference scene on a physical iPhone (or drop a reference Polaroid scan).
2. Adjust **only** the non-Original day/night recipes in `FilmStocks.swift`. Keep `Grade` / `onestep` locked.
3. If prints feel harsh too often, lower expression bands or harshMix — do not flatten stock identity matrices.
4. Keep XCTest green — `FilmStockTests` pixel-delta floor (≥ 0.025 vs Original at full strength) + tone flash/contrast caps + expression distribution / identity tests + existing `GradeTests`.
5. Keep `FrameGeometryTests` bands in sync if `sideRatio` / `bottomRatio` change.
6. Device QA matrix (must look like a mixed pack): daylight outdoor, open shade, indoor tungsten, night no iPhone flash, night with iPhone flash on, backlit. Same scene across all five stocks — if two look the same at strength 1.0, push knobs before shipping. If one looks digitally harsh on most random captures, soften contrast/flash in the base recipe or the expression harshMix first.

## Capture haptics

Sequence in [`Haptics.swift`](../PostcardFilm/Support/Haptics.swift): punchy shutter on press → quiet flash/pipeline → postcard milk with “developing…” (~1.5s) → label fades → milk clears over ~3s (print fades in) with rising `developPulse` across that ~4.5s window → strong `developDone` when the print is fully out. Device check: eyes closed — click, quiet, countdown chemistry, satisfying reveal.

## Status

Original is the shipped 1.0.0 look (frozen). The other four are soft Polaroid cousins pulled close to Original — usually gentle, occasionally a little bolder, always distinct without looking like bad filters.
