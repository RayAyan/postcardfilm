# Animations — postcardfilm

Inventory of every user-visible motion. **Capture / developing timings are frozen** — do not “optimize” shutter blink or milk chemistry for older phones. Browse-path motion (flip, gallery paging, rail, swipe-down) should stay light.

Gallery persistence is unrelated: never wipe prints while tuning motion. See [`.cursor/rules/gallery-persistence.mdc`](../.cursor/rules/gallery-persistence.mdc).

## Rules

1. Prefer short `easeOut` / `easeInOut` over springs on expensive views (3D flip, large PNGs).
2. Never animate in a way that re-decodes PNGs every frame (`ThumbnailCache` + stable views).
3. **Reduce Motion:** shorten flip / dismiss; develop snaps clear (existing behavior).
4. **Do not change** shutter press/blink, screen-flash settle, or developing `labelHold` / `fadeDuration` / haptics without an explicit product decision.
5. No continuous decorative loops (glow, parallax).

## Inventory

| Surface | Motion | File | Curve / duration | Reduce Motion | Status |
|---------|--------|------|------------------|---------------|--------|
| Home | Shutter press scale | [`HomeView.swift`](../PostcardFilm/Features/Home/HomeView.swift) | scale 0.88; blink easeOut 0.06 / easeIn 0.12 | Skips blink theater | **Frozen** |
| Home | Screen flash (selfie) | `ScreenFlash` + Home overlay | Functional brightness + ~150ms settle | Still functional | **Frozen** |
| Capture | Developing milk + label + fade | [`DevelopingOverlay.swift`](../PostcardFilm/Features/Home/DevelopingOverlay.swift) | label ~0.35s; hold 0.8s; milk fade **2.0s** | Instant clear when print ready | **Frozen** (processing) |
| Capture | Develop haptics window | [`Haptics.swift`](../PostcardFilm/Support/Haptics.swift) / CALIBRATION | Across ~2.8s chemistry | Skipped with overlay | **Frozen** |
| Process | Flip 3D rotate | [`ProcessView.swift`](../PostcardFilm/Features/Process/ProcessView.swift) | easeInOut **0.45s**; cover 0.06s beat | easeInOut **0.15s** | Browse — keep feel, light chrome |
| Process | Flip toolbar icon rotate | same | easeInOut 0.45s with `isFlipped` | `.none` | Browse |
| Process | Flip chip press scale | same | easeOut **0.15s** (not spring) | `.none` | Tuned for older GPUs |
| Process | Card shadow during flip | same | Collapsed while `isFlipping` | n/a | Tuned |
| Process | Swipe-down dismiss | same | offset + opacity; easeOut ~0.18s | Instant `dismiss()` | Browse |
| Process | Develop overlay end | same | easeOut 0.25s `isDeveloping` | Same path | Document only |
| Gallery | Select / long-press chrome | [`GalleryView.swift`](../PostcardFilm/Features/Gallery/GalleryView.swift) | easeOut 0.12s | n/a | Light — leave |
| Gallery | Scroll rail expand + thumb track | [`GalleryScrollRail.swift`](../PostcardFilm/Features/Gallery/GalleryScrollRail.swift) | easeOut ~0.16s widen (6→14) + slight thumb grow; springy thumb follow only when not scrubbing | n/a | Scrubs via contentOffset; overlays trailing gutter |
| Gallery→Process | Horizontal page swipe | Process lazy `ScrollView` paging | System paging | n/a | Lazy pages; no extra chrome |
| Shared | Delete confirm fade | [`DeleteConfirmModal.swift`](../PostcardFilm/Features/Shared/DeleteConfirmModal.swift) | opacity easeOut 0.18s | n/a | Leave |
| System | Sheet detent / nav push | UIKit / SwiftUI | Platform | Platform | Note only |

## Browse-path priorities

When something feels hitchy after a print exists, check in order:

1. Flip mid-spin (shadow + spring chrome)
2. Horizontal gallery paging (lazy pages, prefetch, no windowed TabView)
3. Swipe-down vs horizontal (vertical must dominate)
4. Gallery scroll rail (short eases only)

Do **not** shorten developing fade to “fix” jank elsewhere.

## Related

- Design voice / capture motion: [`DESIGN.md`](DESIGN.md)
- Capture haptics detail: [`CALIBRATION.md`](CALIBRATION.md)
- Front-end Reduce Motion checks: [`HIG_CHECKLIST.md`](HIG_CHECKLIST.md)
