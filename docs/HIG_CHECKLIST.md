# Apple HIG audit checklist — postcardfilm

Walk this on a **physical iPhone** before calling a release done.

## Permissions

- [ ] Camera prompt appears when Home opens (not before)
- [ ] Denying camera shows in-app card + Open Settings
- [ ] Photos is never asked on launch
- [ ] Download requests **add-only**; deny → alert + Open Settings
- [ ] Green camera-in-use indicator while Home is active (expected)

## Hit targets & layout

- [ ] Gallery chip, Settings (Home), Process flip, flash, delete, download ≥ 44×44 pt
- [ ] Shutter is ~72 pt
- [ ] Content fits SE-class width without horizontal scroll
- [ ] Safe area / Dynamic Island / home indicator respected
- [ ] Gallery cells are equal size

## Navigation & system chrome

- [ ] Interactive pop gesture works on Gallery, Process, Settings
- [ ] Opening a print from Gallery never shows Developing (only new captures do)
- [ ] Flip animates the print (3D; Reduce Motion → short fade)
- [ ] Delete uses confirmation dialog (destructive) on Process; Gallery has Select toolbar + long-press select / select all / batch delete
- [ ] No share sheet on Process
- [ ] Download saves only the visible face (front, or back when a note exists)
- [ ] Settings uses inset grouped list (checkmarks + Toggle); no highlight toggle
- [ ] SF Symbols for actions; chrome labels are serif small-caps

## Accessibility

- [ ] VoiceOver: shutter, gallery, settings, process actions, wordmark (`postcardfilm`)
- [ ] Gallery cells announce print + caption (+ back note if present)
- [ ] Reduce Motion skips shutter flash / shortens developing hold / simplifies flip
- [ ] Flash auto shows “A” badge (not color alone)
- [ ] Graphite on cream remains readable on strip and back (including thin reverse border)

## Identity & motion

- [ ] Home screen name: `postcardfilm`
- [ ] Wordmark: `postcardfilm.` (lowercase, no underline)
- [ ] Shutter blink + haptic on capture; Developing… in serif small-caps (capture only)
- [ ] Tiny settings disclaimer: not affiliated with polaroid or fujifilm
- [ ] Prints in Documents survive app updates (same bundle id)
