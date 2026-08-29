# postcardfilm

Take a photo. It comes out as a Polaroid. Date on the white strip. Save, share, or throw it away.

**Native iPhone app (SwiftUI).** Not affiliated with Polaroid or Fujifilm. Photos stay on your phone — no accounts, no cloud, no Android.

## Requirements

- macOS with Xcode 16+
- Physical iPhone on iOS 17+ for camera QA (simulator has no real camera)
- Apple Developer account for device installs / TestFlight
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) if you edit `project.yml`

## Open & run

```bash
open PostcardFilm.xcodeproj
```

In Xcode:

1. Select your **physical iPhone** as the run destination.
2. Set your Team under Signing & Capabilities for target `PostcardFilm`.
3. Hit Run (▶).

Regenerate after editing [`project.yml`](project.yml):

```bash
xcodegen generate
```

Build from the CLI (simulator SDK, no destination dance):

```bash
xcodebuild -project PostcardFilm.xcodeproj -target PostcardFilm \
  -sdk iphonesimulator -arch arm64 CODE_SIGNING_ALLOWED=NO build
```

## Project map

| Path | Role |
|------|------|
| `PostcardFilm/Features/Home/` | Camera (AVFoundation), shutter, developing hold |
| `PostcardFilm/Features/Gallery/` | 3-column local gallery |
| `PostcardFilm/Features/Process/` | Delete / download (visible face) / caption + flip back |
| `PostcardFilm/Features/Settings/` | Film front caption defaults, date format, version footer |
| `PostcardFilm/Processing/` | Polaroid 600 grade, frame geometry, caption, pipeline |
| `PostcardFilm/Store/` | Documents index + files |
| `PostcardFilm/Settings/` | UserDefaults preferences |
| `PostcardFilmTests/` | XCTest unit tests |
| `Scripts/verify_logic.swift` | Host smoke check for grade/frame math |

## Tests

In Xcode: Product → Test (⌘U), or:

```bash
xcodebuild test -scheme PostcardFilm -destination 'platform=iOS Simulator,name=iPhone 17'
```

Host-side smoke check (no simulator required):

```bash
swift Scripts/verify_logic.swift
```

## Versioning

- Marketing version / build: `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in [`project.yml`](project.yml) and `Info.plist` (`1.0.0` / `1`)
- Shown in Settings footer as `postcardfilm. 1.0.0`

### Cut a release

1. Move `[Unreleased]` entries in `CHANGELOG.md` to `[x.y.z] - YYYY-MM-DD`
2. Bump versions in `project.yml` + `Info.plist`, run `xcodegen generate`
3. Append a row to `docs/VERSIONS.md`
4. Tag `vx.y.z`

### Store screenshots

App Store assets live in `Marketing/AppStore/iphone-6.5/` (1284 × 2778, no alpha). The Simulator has no camera, so a DEBUG-only harness ([`ScreenshotHarness.swift`](PostcardFilm/App/ScreenshotHarness.swift)) seeds prints from square JPEGs in the app container's `Documents/_seed` and pins one screen:

```bash
xcrun simctl launch <device> com.postcardfilm.app -SCREENSHOTS -SCREENSHOT_SCREEN gallery
xcrun simctl io <device> screenshot --type=png shot.png
```

Screens: `home`, `developing`, `process`, `gallery`, `settings`. Use an iPhone 14 Plus / 12 Pro Max device type — its 3x screen is exactly the 6.5" upload size.

## Privacy

- Camera: used to take prints (`NSCameraUsageDescription`)
- Photos: **add-only** when you tap Download on Process (`NSPhotoLibraryAddUsageDescription`)
- No full library access, no analytics, no accounts

## Device QA / HIG

Walk [`docs/HIG_CHECKLIST.md`](docs/HIG_CHECKLIST.md) on a physical iPhone. Grade notes: [`docs/CALIBRATION.md`](docs/CALIBRATION.md). Design system: [`docs/DESIGN.md`](docs/DESIGN.md).

## License

See [LICENSE](LICENSE).
