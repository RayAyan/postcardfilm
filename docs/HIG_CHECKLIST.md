# Apple HIG / front-end regression — postcardfilm

Walk this on a **physical iPhone** before calling a release done. This is the **front-end half** of regression; logic half is `xcodebuild test` (`PostcardFilmTests`). There is **no XCUITest target**.

Simulator can cover layout, copy, sheets, and the delete modal. Camera, Photos add-only, green camera indicator, and full VoiceOver stay device-only — leave those unchecked if not verified on hardware.

## Permissions (device)

- [ ] Camera prompt appears when Home opens (not before)
- [ ] Denying camera shows in-app card + Open Settings
- [ ] Photos is never asked on launch
- [ ] Download requests **add-only**; deny → alert + Open Settings
- [ ] Green camera-in-use indicator while Home is active (expected)

## Home

- [ ] Live preview fills the square viewfinder
- [ ] Flash on/off on rear (hardware) and front (screen flash); control never disabled
- [ ] Flip camera; selfie preview + capture mirrored; rear not mirrored
- [ ] Shutter ~72 pt; blink + haptic on capture
- [ ] Denied-camera card + Open Settings
- [ ] Tagline centered under viewfinder (`take a photo.`)

## Developing

- [ ] Overlay only on **new captures** (never when opening from Gallery)
- [ ] Reduce Motion shortens / simplifies the hold
- [ ] Serif chrome `developing…`

## Gallery

- [ ] Empty: `no prints yet.` + `take one`
- [ ] Populated: leading-aligned subtext `prints you've kept.` at 20pt inset (`AppTheme.pageGutter`)
- [ ] Equal-size 3-column cells; content fits SE-class width
- [ ] Select / deselect all; long-press enters select; tap toggles
- [ ] Inline select title (not truncated)
- [ ] Centered delete modal: 1 print → `are you sure, delete this print?`; many → `are you sure, delete n prints?`; **delete** + **go back**
- [ ] Multi-download in select mode
- [ ] Interactive pop gesture works

## Process

- [ ] Front strip tap opens editor; photo area does not
- [ ] Back face tap opens note editor; blank back shows wordmark
- [ ] Flip animates (3D; Reduce Motion → fade); strip text covered during flip
- [ ] Gallery paging between prints; capture flow is single-print
- [ ] Share on bottom left; delete + download (`photo.badge.arrow.down`) on the right — no highlighter control
- [ ] Strip / back editors apply live; toolbar is **done** only (no save/cancel)
- [ ] Share sheet exports the **visible** face
- [ ] Download saves the **visible** face
- [ ] Centered delete modal (singular copy); go back dismisses
- [ ] Photos denied alert + Open Settings
- [ ] Missing-print state; edit sheets + custom caption prompt (20 / 200)
- [ ] Hint centered under the print (`processCardGutter`, width-driven size)

## Settings

- [ ] Leading-aligned defaults subheading (`your defaults for new prints…`) on one line, shares 20pt edge with section content
- [ ] Section order: strip text → date format (date mode) → font → size → letter case → highlight (hidden when blank)
- [ ] Strip text chip grids — not checkmarks/toggles
- [ ] No film back note block (back style is per-print only)
- [ ] Custom default preview row when mode is custom
- [ ] Footer centered: `postcardfilm. x.y.z (n)` + credit
- [ ] Triple-tap credit opens mailto
- [ ] Changing defaults does not rewrite existing prints

## Chrome & layout

- [ ] Gallery chip, Settings, Process flip/share/delete/download ≥ 44×44 pt
- [ ] Safe area / Dynamic Island / home indicator respected
- [ ] Portrait only
- [ ] Dynamic Type default + larger sizes: chips still readable (`minimumScaleFactor`)
- [ ] SF Symbols for actions; chrome labels serif + lowercase

## Accessibility

- [ ] VoiceOver: shutter, gallery, settings, process actions, wordmark (`postcardfilm`)
- [ ] Gallery cells announce print + caption (+ back note if present)
- [ ] Delete modal: delete + go back labeled; dismissible
- [ ] Flash VoiceOver label “Flash” + value on/off
- [ ] Reduce Motion: shutter flash / developing / flip
- [ ] Graphite on cream readable on strip and back

## Identity

- [ ] Home screen name: `postcardfilm`
- [ ] Wordmark: `postcardfilm.` (lowercase, no underline)
- [ ] Prints in Documents survive app updates, TestFlight, and Xcode Run (same bundle id) — only uninstall wipes; in-app delete is user-confirmed (`GalleryPersistenceTests`)
