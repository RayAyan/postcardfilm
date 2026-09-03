# Design guidelines — postcardfilm

Single source for visual and voice decisions. Code tokens live in `PostcardFilm/Theme/`.

## Brand

| Token | Value |
|-------|--------|
| Name | `postcardfilm` (no space, lowercase) |
| Wordmark | `postcardfilm.` |
| Bundle | `com.postcardfilm.app` |
| Display name | `postcardfilm` |

Constants: [`Brand.swift`](../PostcardFilm/Theme/Brand.swift).

## Typography

All **app UI** chrome goes through [`Typography.swift`](../PostcardFilm/Theme/Typography.swift) → `AppType`:

| Token | Use |
|-------|-----|
| `display` | Wordmark, developing, major titles |
| `body` | Primary labels, buttons, list rows |
| `caption` | Quiet notes under viewfinder / print |
| `micro` | Gallery chip, tiny chrome |

Rules:

1. Always `.system(..., design: .serif)` for UI.
2. Apply `.appChromeText()` (`.textCase(.lowercase)` + tracking) to chrome labels — not text fields, not print strip burns.
3. SF Symbols stay system (not serif).
4. All chrome copy is lowercase.

**Print strip** fonts via `CaptionFont` (serif / modern / script / typewriter). Caption text on the print keeps the user’s typing case.

## Color

[`Colors.swift`](../PostcardFilm/Theme/Colors.swift) — `AppTheme`:

- App chrome: near-black surface, cream text
- Print card: paper `#F6F1E7`, graphite caption, optional highlighter

## Voice (copy)

All lowercase. Examples from `Brand`:

- Home: `take a photo. write something on it.`
- Gallery: `prints you've kept.`
- Process: `tap the strip. write something.`
- Back: `write on the back.`
- Developing: `developing…` (new captures only)
- Brand: `postcardfilm.`

## Strip and reverse

- Front strip: single caption line (date / custom / blank). Custom text max **20** characters; date captions use the full formatted date. Optional highlighter. Settings defaults live under **film front caption**.
- Process: tap the print for strip editor (date / custom / blank / font / letter case). Top-trailing **flip** turns the cream reverse (darker graphite border). Back note sheet includes font. Develop reveal is 3s and clipped to the Polaroid.
- Download saves only the face you're looking at (front or back; blank reverse renders on the fly).
- Gallery: **select** toolbar; tap toggles many prints; long-press enters select (SwiftUI, multi-select reliable).
- Settings footer shows `postcardfilm. <version>` and `made by ayan ray in dublin.` (triple-tap credit opens mailto). Settings is reached from Home, not Process.

## Polaroid look

See [`CALIBRATION.md`](CALIBRATION.md). **the pack** (1.1.0): five camera-named stocks drawn at shutter — no picker, no settings row, no strip label. Users never see the emulsion name.

## Changing the design

1. Edit `Theme/` (`Brand`, `AppType`, `AppTheme`) — avoid one-off fonts/colors in views.
2. Update this file if voice or rules change.
3. Keep XCTest brand/frame/grade suites green.
