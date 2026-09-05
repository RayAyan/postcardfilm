# Native SwiftUI iPhone app

This repo is **postcardfilm** — a native SwiftUI project.

- Open `PostcardFilm.xcodeproj` in Xcode.
- Regenerate with `xcodegen generate` after editing `project.yml`.
- Do not add Node, Expo, React Native, or Android targets.
- Print text style UI: see `.cursor/rules/print-text-editor.mdc` and `docs/DESIGN.md` (shared `PrintTextStyleControls`).
- **Branches:** default / day-to-day work is **`test`**. Do not commit on **`main`** (App Store candidate) or **`release`** (live ledger; merge-only from `main` after Distribute). See [`docs/BRANCHING.md`](docs/BRANCHING.md).
