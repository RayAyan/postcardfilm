# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Brand constants (`Brand`) and design guidelines ([`docs/DESIGN.md`](docs/DESIGN.md))
- Caption fonts (Serif / Modern / Script / Typewriter) + per-print highlight toggle on Process
- Custom caption popup with visible 40-character limit
- Classic shutter flash blink + dual shutter haptic
- Polaroid light leak + highlight bloom; clearer/more vibrant grade
- App icon (B&W instant camera)
- Gallery equal-size cells; home thumb + Gallery chip; screen taglines
- Shadow-weighted saturation in the grade (`Grade.shadowSaturation()`) so dark frames stop reading flat
- App Store assets in `Marketing/AppStore/iphone-6.5/`, captured via a DEBUG screenshot harness
- Independent date + note on each print (calendar picker + note sheet); strip layouts for date-only / note-only / both
- Flipable Polaroid reverse with up to 200-character back note; custom front caption capped at 20
- Process **flip the film** control; capture-date stamp on the strip; thin graphite border on the cream reverse
- Brighter Huji-leaning Polaroid grade (~0.32 EV + higher matrix bias)
- Reliable gallery multi-select (SwiftUI buttons + `GallerySelectionLogic` tests)

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

- Caption highlight toggle from Settings (Process control remains; default on)
- Caption and date case explanatory footers in Settings (the rows now show what they do)
- Settings About section (version / credit / “photos stay on this phone”) — replaced by footer version + credit
- Dual date+note strip editor (replaced by front caption + flip-to-back note)
- Share button on Process
- Settings **save to photos when i shoot**
- Settings disclaimer / not-affiliated line (triple-tap credit mailto remains)

## [1.0.0] - 2026-08-29

### Added

- Native SwiftUI iPhone app (iOS 17+), zero React Native / Android
- Home camera (AVFoundation) with square viewfinder, flip, flash, developing hold
- Polaroid 600 grade (Core Image) + cream frame + strip caption
- Local gallery (3-column mini Polaroids)
- Process screen: delete, Photos add-only download, share sheet, caption reburn
- Settings: caption mode, date format, save-on-capture, about + version
- XCTest suites for grade / frame / caption / index / settings
- README, CHANGELOG, HIG checklist, calibration notes

### Removed

- Expo / React Native / Jest / Node toolchain
- Any Android target or dependency

[Unreleased]: https://github.com/local/postcardfilm/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/local/postcardfilm/releases/tag/v1.0.0
