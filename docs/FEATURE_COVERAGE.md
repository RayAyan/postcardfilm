# Feature coverage — postcardfilm

Maps shipping features to logic tests, front-end checks ([`HIG_CHECKLIST.md`](HIG_CHECKLIST.md)), and design rules ([`DESIGN.md`](DESIGN.md)). No XCUITest target — front-end is the checklist + manual/simulator walk.

| Area | Feature | Logic tests | Front-end | Design rule |
|------|---------|-------------|-----------|-------------|
| Home | Square viewfinder, shutter, haptics | — (device) | HIG Home | DESIGN Capture / Shell |
| Home | Flash on/off; rear vs screen | `FlashPlanTests` | HIG Home | DESIGN Capture |
| Home | Flip; mirrored selfie | `CameraFacingTests` | HIG Home | DESIGN Capture |
| Home | Camera denied | — | HIG Permissions / Home | Brand strings |
| Capture | Developing overlay (capture only) | — | HIG Developing | DESIGN Capture / Voice |
| Capture | the pack (5 stocks, no UI) | `FilmStockTests` | HIG Identity (implicit) | DESIGN Polaroid look |
| Gallery | Grid + leading subtext | `FrameGeometryTests` (frame) | HIG Gallery | DESIGN Alignment |
| Gallery | Empty state | — | HIG Gallery | Brand |
| Gallery | Select / long-press / drag-paint / batch delete | `GallerySelectionTests` | HIG Gallery | DESIGN Strip and reverse |
| Gallery | Batch download checkmark + delete fade | — | HIG Gallery | ANIMATIONS Gallery |
| Gallery | Analog scroll rail + scroll-friendly cells | — | HIG Gallery | DESIGN Alignment / [`docs/BUGS.md`](BUGS.md) |
| Home | Gallery chip debounce after pop; camera warm under Gallery | — | HIG Chrome | DESIGN Strip and reverse |
| Gallery / Process | Downsampled thumb cache (grid 480 / process 1400) + async load | `ThumbnailCacheTests` | HIG Performance | ANIMATIONS decode rule |
| Gallery | Note dog-ear fold on cells with back note | — | HIG Gallery | DESIGN Strip and reverse |
| Gallery | Multi-download (front + back when noted) | — | HIG Gallery | DESIGN Strip and reverse |
| Gallery | Index / recovery | `PolaroidIndexTests` | HIG Identity persistence | — |
| Gallery | Persistence until uninstall | `GalleryPersistenceTests` | HIG Identity | DESIGN Brand / gallery-persistence rule |
| Process | Strip/back edit (live apply, done only), flip | `CaptionTests` (dirty-check) | HIG Process | DESIGN Strip and reverse |
| Process | Gallery paging + swipe-down dismiss | `GalleryPagingTests` | HIG Process | DESIGN Strip and reverse / [`docs/BUGS.md`](BUGS.md) |
| Process | Highlight via Settings / strip sheet | `PipelineSmokeTests` | HIG Process / Settings | DESIGN Strip and reverse |
| Process | Share left / delete + download (both faces if note) | pipeline | HIG Process | DESIGN Strip and reverse |
| Process | Edit sheet scroll prefers list | — | HIG Process | DESIGN Strip and reverse |
| Settings | Font chips serif / script / typewriter | `CaptionTests` | HIG Settings | DESIGN Typography |
| Process | Centered delete modal | `BrandTests` (copy) | HIG Process / Gallery | DESIGN Alignment / Delete |
| Process | Caption / back note limits | `CaptionTests` | HIG Process | DESIGN Strip and reverse |
| Settings | Strip defaults + chips | `AppSettingsTests` | HIG Settings | DESIGN + print-text rule |
| Settings | Defaults subheading | `BrandTests` | HIG Settings | DESIGN Alignment / Settings UX |
| Settings | Version + build footer | `BrandTests` | HIG Settings | DESIGN Strip and reverse |
| Settings | Defaults do not mutate prints | `AppSettingsTests` | HIG Settings | print-text Product |

When adding a user-visible feature: add a logic test if pure; add a HIG checkbox; update DESIGN if a principle is new.
