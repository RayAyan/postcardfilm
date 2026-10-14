# Native SwiftUI iPhone app

This repo is **postcardfilm** — a native SwiftUI project.

- Open `PostcardFilm.xcodeproj` in Xcode.
- Regenerate with `xcodegen generate` after editing `project.yml`.
- Do not add Node, Expo, React Native, or Android targets.
- Print text style UI: see `.cursor/rules/print-text-editor.mdc` and `docs/DESIGN.md` (shared `PrintTextStyleControls`).
- **Gallery persistence:** prints in Documents survive TestFlight / App Store / Xcode Run until uninstall — see `.cursor/rules/gallery-persistence.mdc`. Never wipe `Documents/polaroids`.
- **Branches:** default / day-to-day work is **`test`**. **`main`** = TestFlight / App Store candidate (Archive from here). **`release`** = production ledger only — merge `main` → `release` **only when the human explicitly says production shipped** (not for TestFlight). After promote to `main`, switch back to `test`. See [`docs/BRANCHING.md`](docs/BRANCHING.md) and `.cursor/rules/branching.mdc`.
- **Film debug picker:** Home Manual stock control is DEBUG + `test` only — never on `main` / TestFlight / App Store. See `.cursor/rules/film-debug-picker.mdc`.
