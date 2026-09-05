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
| Gallery | Select / long-press / batch delete | `GallerySelectionTests` | HIG Gallery | DESIGN Strip and reverse |
| Gallery | Multi-download | — | HIG Gallery | DESIGN Strip and reverse |
| Gallery | Index / recovery | `PolaroidIndexTests` | HIG Identity persistence | — |
| Process | Strip/back edit (live apply, done only), flip | `CaptionTests` (dirty-check) | HIG Process | DESIGN Strip and reverse |
| Process | Gallery paging | — | HIG Process | DESIGN Strip and reverse |
| Process | Highlight via Settings / strip sheet | `PipelineSmokeTests` | HIG Process / Settings | DESIGN Strip and reverse |
| Process | Share left / delete + download right | pipeline | HIG Process | DESIGN Strip and reverse |
| Process | Centered delete modal | `BrandTests` (copy) | HIG Process / Gallery | DESIGN Alignment / Delete |
| Process | Caption / back note limits | `CaptionTests` | HIG Process | DESIGN Strip and reverse |
| Settings | Strip defaults + chips | `AppSettingsTests` | HIG Settings | DESIGN + print-text rule |
| Settings | Defaults subheading | `BrandTests` | HIG Settings | DESIGN Alignment / Settings UX |
| Settings | Version + build footer | `BrandTests` | HIG Settings | DESIGN Strip and reverse |
| Settings | Defaults do not mutate prints | `AppSettingsTests` | HIG Settings | print-text Product |

When adding a user-visible feature: add a logic test if pure; add a HIG checkbox; update DESIGN if a principle is new.
