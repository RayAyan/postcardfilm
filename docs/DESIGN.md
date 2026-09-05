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
- Forced dark mode; portrait only

## Alignment

- Large-title screens (Gallery, Settings) use a muted **leading** subheading at **20pt** horizontal inset (`AppTheme.pageGutter`) — same edge as list chips and section headers.
- Intentionally **centered**: Home tagline, Settings version/credit footer, empty/denied cards, Process hint under the print.
- List section headers are leading-aligned chrome captions.
- Destructive confirms use a **centered** modal (not a bottom action sheet).
- Process hint sits under a width-driven print (`processCardGutter`), `caption(13)`, `AppTheme.taglineGap` (14pt) below — same band as Home’s viewfinder → tagline.

## Voice (copy)

All lowercase. Examples from `Brand`:

- Home: `take a photo.`
- Gallery: `prints you've kept.`
- Settings: `your defaults for new prints.`
- Process: `tap the strip. write something.`
- Back: `write on the back.`
- Developing: `developing…` (new captures only)
- Delete one: `are you sure, delete this print?`
- Delete many: `are you sure, delete n prints?`
- Brand: `postcardfilm.`

## Shell & chrome

- Forced dark; portrait-only.
- Hit targets ≥ 44pt; shutter ~72pt.
- SF Symbols for actions; chrome labels use serif + `.appChromeText()`.

## Capture

- Flash is **on/off only** (no auto). Rear camera: hardware flash. Front camera: screen flash (white overlay + full brightness). The flash control is never disabled or dimmed. Capture keeps the session alive through exposure (deferred stop), pre-arms flash settings, and retries with a flash-off fallback so users almost never see a capture-failed alert.
- Selfie preview and capture are **mirrored**; rear camera is not.
- Capture motion: shutter blink → postcard milk → `developing…` → slow print fade-in. Reduce Motion shortens / simplifies.
- **the pack**: five camera-named stocks drawn at shutter — no picker, no settings row, no strip label. Users never see the emulsion name.

## Strip and reverse

- Front strip: single caption line (date / custom / blank). Custom text max **20** characters; date captions use the full formatted date. Optional highlighter. Settings defaults live under **strip text** (mode), then **date format** (when mode is date), then **font / size / letter case / highlight**. Highlight is hidden when mode is blank.
- Process: **tap only the white strip** to edit the front caption (photo area does not open the editor). Top-trailing **flip** turns the cream reverse (darker graphite border). Tap the back face to edit the note. During flip, burned strip/note text is covered with paper then restored so it does not warp mid-spin. Flip is 3D; Reduce Motion → short fade.
- **Shared print text style** (font / size / letter case; optional highlight for strip) is one control surface of **chip grids** — Settings front defaults and Process front/back sheets use `PrintTextStyleControls` / `CaptionModeGrid`. Add new text-style options there, not as forked list UIs. Chips, not checkmarks/toggles.
- Process edit sheets apply live (debounced reburn); toolbar is a single **done** — no save/cancel. Custom caption prompt is the same. Dismiss with no edits skips reburn (no image flicker).
- Settings = defaults for the *next* capture only. One page-level leading subheading explains that; Process edit sheets omit it. Back note style is per-print only (no Settings UI); each print stores its own overrides (`dateFormat`, `backFont`, `backFontSize`, `backLetterCase` included). Silent `AppSettings` seeds new notes.
- Gallery Process pages horizontally between prints (edge swipe does not pop); capture develop flow stays single-print.
- Process action bar: **share** on the left; **delete** + **download** (`photo.badge.arrow.down`) on the right. Share and download apply to the **visible face** (front or back; blank reverse renders on the fly). Highlight is edited only in Settings / strip sheet — no bottom-left highlighter.
- Delete confirm: shared centered modal (`DeleteConfirmModal`) — `are you sure, delete this print?` or `are you sure, delete n prints?`; buttons **delete** and **go back**. Not a system confirmation dialog.
- Gallery: **select** toolbar; tap toggles many prints; long-press enters select; select-all / batch delete / multi-download.
- Settings footer shows `postcardfilm. <marketing> (<build>)` and `made by ayan ray in dublin.` (triple-tap credit opens mailto). Settings is reached from Home, not Process.

## Polaroid look

See [`CALIBRATION.md`](CALIBRATION.md). **the pack** (1.1.0): five camera-named stocks drawn at shutter — no picker, no settings row, no strip label. Users never see the emulsion name.

## Changing the design

1. Edit `Theme/` (`Brand`, `AppType`, `AppTheme`) — avoid one-off fonts/colors in views.
2. Update this file if voice or rules change.
3. Keep XCTest brand/frame/grade suites green.
4. Walk [`HIG_CHECKLIST.md`](HIG_CHECKLIST.md) before release (front-end half of regression).
