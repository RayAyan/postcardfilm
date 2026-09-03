# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

How we cut releases, write App Store “What’s New”, and bump versions:
[`docs/CHANGELOG_STRATEGY.md`](docs/CHANGELOG_STRATEGY.md).

## [Unreleased]

<!-- App Store What’s New (draft when cutting): keep short, lowercase, poetic. -->

### Added

- **the pack** — five camera-named film stocks (`onestep` / Original, `sun660`, `mini9`, `natura`, `m6`); at shutter the app draws one at random; user never chooses; stock persisted so reburn keeps the emulsion
- Adaptive film expression — invisible per-print strength (~65% gentle / ~25% medium / ~10% bold) softens harsh knobs while keeping stock color identity; Original stays frozen; strength persisted for reburn
- Process highlighter toggle (bottom left) to add/remove caption highlight on a print
- Strip caption size default (small / medium / large) in Settings + per-print in Process
- Gallery multi-download in select mode
- Process share via the system share sheet (visible face)

### Changed

- Pack stocks pushed apart with hard tone roles (bright flash / punchy Instax / flat Fuji / dense Leica); Original (`onestep`) stays the frozen 1.0.0 look
- Pack softened toward real Polaroid (muted contrast, subtler flash fill, soft grain + edge burn, per-print serendipity); Original still frozen
- Pack pulled closer to Original — less contrast/crush/flash/vignette; color cousins kept; Original still frozen
- Calibration is three layers: scene adaptation → stock identity → weighted expression (plus scaled serendipity)
- Capture haptics: punchy shutter + rising develop pulses + strong reveal settle
- Capture haptics: shutter on press; rising develop pulses across ~4.5s Polaroid fade; reveal thump when milk clears
- Capture transition: quick shutter flash → postcard milk → “developing…” 1.5s → 3s slow print fade-in (no wipe)
- Camera preview resumes after backgrounding / session interruption
- Process download icon optically aligned with share/trash
- Process highlighter always visible; yellow chip when on
- Long dates zero-pad the day (`03 jan 2026`)
- Gallery select uses an inline title (no truncated “S…”) and caches thumbs for smoother scroll
- Front camera preview and capture are mirrored (WYSIWYG selfie)

### Fixed

- Camera flip no longer unmirrors the current preview before switching; selfie preview/capture stay mirrored, rear does not
- Gallery restores prints still on disk when `index.json` fails to decode or omits folders (unknown film/font values no longer empty the gallery)

### Removed

## [1.0.0] - 2026-09-01

First public App Store release.

<!-- App Store What’s New:
hello. take a photo. write on the strip. keep a little stack of prints that never leave your phone.
-->

### Added

- Native SwiftUI iPhone app (iOS 17+), zero React Native / Android
- Home camera (AVFoundation) with square viewfinder, flip, flash, developing hold
- Polaroid 600 grade (Core Image) + cream frame + strip caption
- Local gallery (3-column mini Polaroids)
- Process screen: delete, Photos add-only download, caption reburn
- Flipable Polaroid reverse with up to 200-character back note; custom front caption capped at 20
- Process **flip the film** control; capture-date stamp on the strip; thin graphite border on the cream reverse
- Independent date + note on each print (calendar picker + note sheet); strip layouts for date-only / note-only / both
- Caption fonts (Serif / Modern / Script / Typewriter) + per-print highlight toggle on Process
- Custom caption popup with visible character limit
- Classic shutter flash blink + dual shutter haptic
- Polaroid light leak + highlight bloom; brighter Huji-leaning grade (~0.32 EV + higher matrix bias)
- Shadow-weighted saturation in the grade (`Grade.shadowSaturation()`) so dark frames stop reading flat
- App icon (B&W instant camera)
- Gallery equal-size cells; home thumb + Gallery chip; screen taglines
- Brand constants (`Brand`) and design guidelines ([`docs/DESIGN.md`](docs/DESIGN.md))
- App Store assets in `Marketing/AppStore/iphone-6.5/`, captured via a DEBUG screenshot harness
- Reliable gallery multi-select (SwiftUI buttons + `GallerySelectionLogic` tests)
- XCTest suites for grade / frame / caption / index / settings
- README, CHANGELOG, HIG checklist, calibration notes

### Changed

- Product rename to **postcardfilm** (targets `PostcardFilm`, bundle `com.postcardfilm.app`)
- UI chrome: serif + faux small caps via `AppType` / `appChromeText()`
- Frame proportions closer to Polaroid 600 (side ~9%, strip ~24%); larger strip type
- Wordmark `postcardfilm.` (no underline, no space)
- Gallery subtext: `prints you've kept.`
- Settings/caption sheet font rows render in their own face (serif / modern / script / typewriter)
- Settings date case rows render in the case they apply (`lowercase` / `Sentence Case`)
- Typed `PrintRoute` so gallery opens never re-run Developing
- Process hint restored: `tap the strip. write something.`
- Settings caption section renamed **film front caption**; disclaimer is tiny muted text
- Download saves only the currently visible face

### Removed

- Expo / React Native / Jest / Node toolchain
- Any Android target or dependency
- Caption highlight toggle from Settings (Process control remains; default on)
- Caption and date case explanatory footers in Settings (the rows now show what they do)
- Settings About section (version / credit / “photos stay on this phone”) — replaced by footer version + credit
- Dual date+note strip editor (replaced by front caption + flip-to-back note)
- Share button on Process
- Settings **save to photos when i shoot**
- Settings disclaimer / not-affiliated line (triple-tap credit mailto remains)

[Unreleased]: https://github.com/RayAyan/postcardfilm/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/RayAyan/postcardfilm/releases/tag/v1.0.0
