# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

How we cut releases, write App Store “What’s New”, and bump versions:
[`docs/CHANGELOG_STRATEGY.md`](docs/CHANGELOG_STRATEGY.md).

## [Unreleased]

<!-- App Store What’s New (draft when cutting): keep short, lowercase, poetic. -->

### Added

- Persisted per-print `dateFormat` so reburn / strip edits keep the format used at capture
- Persisted per-print `captionLetterCase` so strip letter case round-trips in Process
- Resilient capture ladder (retry + flash-off fallback) and pre-armed flash settings
- **the pack** — five camera-named film stocks (`onestep` / Original, `sun660`, `mini9`, `natura`, `m6`); at shutter the app draws one at random; user never chooses; stock persisted so reburn keeps the emulsion
- Adaptive film expression — invisible per-print strength (~65% gentle / ~25% medium / ~10% bold) softens harsh knobs while keeping stock color identity; Original stays frozen; strength persisted for reburn
- Strip caption highlight default (on / off) in Settings + per-print in the strip editor sheet
- Strip caption size default (small / medium / large) in Settings + per-print in Process
- Gallery multi-download in select mode
- Process share via the system share sheet (visible face)
- Settings defaults subheading (`your defaults for new prints.`)
- Centered delete confirm modal (Process + Gallery) with delete / go back
- Feature coverage map ([`docs/FEATURE_COVERAGE.md`](docs/FEATURE_COVERAGE.md)) linking tests, HIG, and design rules

### Changed

- Process print uses more screen width (`processCardGutter`) with a shared canvas aspect lock — no 340pt height cap
- Flip covers burned text instantly and syncs face/hit-target from angle; live reburns no longer tear down `PolaroidThumb` via `.id`
- Settings / Process sheets share `PrintSectionHeader` + plain-list gutters; Settings subheading stays one line
- Front strip editor includes date-format chips; per-print `captionLetterCase` persists; back-note sentence case burns correctly
- Settings / Gallery share a **20pt** page gutter; section headers and chips align with the large title
- Settings section order: strip text → date format → font → size → letter case → highlight (last; hidden when blank)
- Process strip / back note editors apply live; toolbar is **done** only (no save/cancel)
- Process action bar: share on the left; delete + download (`photo.badge.arrow.down`) on the right — highlighter control removed
- Camera session no longer stops mid-flash when Process pushes (deferred stop while capture in flight)
- Settings footer shows marketing version **and** build (`postcardfilm. 1.1.0 (2)`); `Info.plist` reads versions from `project.yml` build settings
- Expanded HIG checklist into a full front-end regression set; DESIGN documents alignment, flash, facing, chips, delete modal
- Home tagline shortened to `take a photo.`
- Settings exposes strip text defaults only (no film back note block); back note style is per-print after capture
- Flash is on/off only (no auto): rear camera fires hardware flash; front camera uses screen flash (white overlay + full brightness); control stays enabled on every facing — never “unavailable”
- Pack stocks pushed apart with hard tone roles (bright flash / punchy Instax / flat Fuji / dense Leica); Original (`onestep`) stays the frozen 1.0.0 look
- Pack softened toward real Polaroid (muted contrast, subtler flash fill, soft grain + edge burn, per-print serendipity); Original still frozen
- Pack pulled closer to Original — less contrast/crush/flash/vignette; color cousins kept; Original still frozen
- Calibration is three layers: scene adaptation → stock identity → weighted expression (plus scaled serendipity)
- Capture haptics: shutter on press; rising develop pulses across ~2.8s Polaroid fade; reveal thump when milk clears
- Capture transition: quick shutter flash → postcard milk → “developing…” 0.8s → 2s slow print fade-in (no wipe)
- Gallery Process: page-style swipe between prints (not nav pop); capture develop flow unchanged
- Process: tap white strip to edit caption; tap back face for note; shared print-text style controls (font/size/case, optional highlight) across Settings front + Process sheets
- Print-text options use compact chip grids (mode / font / highlight / size / case / date format) in Settings and Process sheets
- Back note gains size + letter case (per print)
- Camera preview resumes after backgrounding / session interruption
- Long dates zero-pad the day (`03 jan 2026`)
- Gallery select uses an inline title (no truncated “S…”) and caches thumbs for smoother scroll
- Front camera preview and capture are mirrored (WYSIWYG selfie)

### Fixed

- Opening or dismissing the strip / back-note editor with no edits no longer re-burns the print (removes the front-image flicker on Done)
- Settings no longer shows duplicated font / size / letter case grids (removed film back note defaults block)
- Print flip covers burned strip/note text during the turn so caption does not warp mid-spin
- Front camera + screen flash: wait for session/AE after brightness jump and silently retry once on not-ready so the first shutter captures
- Camera flip no longer unmirrors the current preview before switching; selfie preview/capture stay mirrored, rear does not
- Gallery restores prints still on disk when `index.json` fails to decode or omits folders (unknown film/font values no longer empty the gallery)
- Rear flash no longer fails capture when Process pushes mid-exposure

### Removed

- Process bottom-left highlighter control (highlight lives in Settings + strip sheet)
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
