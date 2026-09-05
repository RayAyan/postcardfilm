# Changelog strategy — postcardfilm

Two audiences, one source of truth.

| Audience | Where | Voice |
|----------|--------|--------|
| Repo / TestFlight notes | [`CHANGELOG.md`](../CHANGELOG.md) | Keep a Changelog, factual, lowercase brand names |
| App Store “What’s New” | drafted from the release section at cut time | short, lowercase, a little poetic — not a bullet dump |
| Quick index | [`VERSIONS.md`](VERSIONS.md) | one row per store / TestFlight build |

## Semver (this app)

`MAJOR.MINOR.PATCH` in `project.yml` only (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`). `Info.plist` reads those via `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`. Build number **always increments** for every upload to App Store Connect — even if marketing version stays the same.

| Bump | When |
|------|------|
| **patch** (`1.0.1`) | bug fixes, copy tweaks, grade calibration, screenshot refresh |
| **minor** (`1.1.0`) | new user-facing capability (new caption mode, new screen, back-of-print features that are new to users) |
| **major** (`2.0.0`) | breaking change to saved prints / settings migration users must notice, or a deliberate “new product” cut |

First public App Store ship can stay **1.0.0** with a high build number; fold everything under `[Unreleased]` into that cut before tagging.

## Keep a Changelog rules

File: repo root `CHANGELOG.md`.

1. Always have an `[Unreleased]` section at the top.
2. While working, append under **Added** / **Changed** / **Fixed** / **Removed** only — no dates in Unreleased.
3. One bullet = one user- or developer-visible change. Prefer “why it matters” over file names.
4. Do **not** log chores (xcodegen regenerate, formatting-only, WIP experiments).
5. Brand strings stay lowercase: `postcardfilm`, not `PostcardFilm` (except target / scheme names if needed for clarity).

Categories:

- **Added** — new capability
- **Changed** — existing behavior or copy that users will notice
- **Fixed** — bugs
- **Removed** — features or settings taken away

## App Store “What’s New”

At release cut, write 2–5 short lines from the changelog — not the whole list.

Rules:

- all lowercase
- no “bug fixes and performance improvements” unless that is literally all that shipped
- lead with feeling or the one thing users will try first
- optional closing line that sounds like the product (`just postcardfilm.` is fine once, not every release)

Example for a first 1.0.0:

```
hello. take a photo. write on the strip. keep a little stack of prints that never leave your phone.
```

Example for a later minor:

```
flip the print. write on the back.
brighter film grade. gallery select that actually selects.
```

Paste that into App Store Connect → version → What’s New. Keep the full detail in `CHANGELOG.md`.

## Cut a release (checklist)

1. **QA** — walk [`HIG_CHECKLIST.md`](HIG_CHECKLIST.md) on a physical iPhone.
2. **Changelog** — move `[Unreleased]` bullets into `## [x.y.z] - YYYY-MM-DD`. Leave an empty `[Unreleased]` stub.
3. **What’s New** — draft the short App Store blurb (save it under the release heading as an HTML comment, or in the GitHub Release body).
4. **Version** — set `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in [`project.yml`](../project.yml). Run `xcodegen generate`. (`Info.plist` picks them up automatically.)
5. **Index** — append a row to [`VERSIONS.md`](VERSIONS.md).
6. **Links** — update compare URLs at the bottom of `CHANGELOG.md`.
7. **Tag** — `git tag -a vx.y.z -m "postcardfilm x.y.z"` on the ship commit (after `main` is the candidate), push tags.
8. **GitHub Release** — paste changelog section + What’s New.
9. **Archive** — Xcode → Archive from **`main`** → upload. Attach build in App Store Connect.
10. **After Distribute** — PR **`main` → `release`** (merge commit only). See [`BRANCHING.md`](BRANCHING.md).

## Branch habit

Canonical rules: [`BRANCHING.md`](BRANCHING.md).

- **`test`** — GitHub default; all day-to-day work; land changelog bullets as you go.
- **`main`** — App Store candidate only (merge `test` → `main` when ready to upload / wait for approval).
- **`release`** — live store ledger (currently **1.0.0**). Update **only** by merging `main` → `release` after approval + Distribute. No direct commits; no merges from `test`.
- Hotfixes: fix on `test`, promote through `main`, then `main` → `release` after distribute.

## Don’t duplicate

| Don’t | Do instead |
|-------|------------|
| Long What’s New that mirrors every bullet | Short poem-ish blurb; detail stays in CHANGELOG |
| Only update VERSIONS.md | Always update CHANGELOG first |
| Reuse the same build number | Increment `CURRENT_PROJECT_VERSION` every upload |
| Put marketing screenshots in the changelog | Note “App Store screenshots refreshed” as one Changed/Added line |
