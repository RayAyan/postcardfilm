# Grade calibration notes

Live recipe: [`Grade.swift`](../PostcardFilm/Processing/Grade.swift) + overlays in [`PolaroidPipeline.swift`](../PostcardFilm/Processing/PolaroidPipeline.swift). Frame: [`FrameGeometry.swift`](../PostcardFilm/Processing/FrameGeometry.swift).

## Locked look

- A little brighter / sunnier (Huji-leaning) — soft exposure lift (~0.32 EV), not digital HDR
- Warm yellow midtones (not orange)
- Lifted blacks (chemical fog) — never true black
- Cream highlights — never paper-white
- Soft contrast; teal-tinged deep shadows
- Extra saturation in dark areas only (`Grade.shadowSaturation()`)
- Soft edges; **no film grain**
- Soft vignette + subtle top-right light leak + tiny highlight bloom
- Cream frame `#F6F1E7`; side/top ~**9%** of image side; bottom strip ~**24%** of canvas height
- Caption ~**30%** of strip height; optional highlighter behind glyphs; photo-well hairline

## What actually renders

`PolaroidPipeline.applyGrade` is the only path a real print takes: `Grade.exposureEV()` via `CIExposureAdjust`, then `Grade.colorMatrix()` as a `CIColorMatrix`, then the `Grade.shadowSaturation()` blend, then a 0.55 blur. `Grade.gradePixel` is the reference recipe used by tests and `Scripts/verify_logic.swift` — it does not touch output.

## How to retune

1. Shoot a reference scene on a physical iPhone (or drop a reference Polaroid scan).
2. Adjust `Grade.colorMatrix()` / `Grade.shadowSaturation()` and pipeline overlays. Keep `gradePixel` in step if the recipe changes direction.
3. Keep XCTest green — mid gray must warm (R > B); near-black must lift; white must cream.
4. Keep `FrameGeometryTests` bands in sync if `sideRatio` / `bottomRatio` change.
5. Device QA: side-by-side with a real Polaroid 600 or the user reference photo.

## Status

Tuned for postcardfilm clarity/vibrance. Still awaiting a locked user reference print for final grade sign-off.
