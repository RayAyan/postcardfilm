# Branching — postcardfilm

Three branches. Only **`test`** is for day-to-day work.

| Branch | Role |
|--------|------|
| **`test`** | GitHub **default**. All development. Clones, PRs, and agents work here. |
| **`main`** | App Store / **TestFlight candidate** only. Archive / upload from here. Not the default. No feature work. |
| **`release`** | **Live production ledger.** What is actually shipping to customers on the App Store after Distribute. Agents never touch it unless the human explicitly says production has shipped. |

```text
test  --(ready for TestFlight / review)-->  main  --(you say: production shipped)-->  release
 ^                                                                              |
 |------------------------------ stay on test ----------------------------------|
```

## Hard rules

1. **Always work on `test`.** Do not commit on `main` or `release`.
2. **Never touch `release` unless the human explicitly says** the build is **live in production** (Distribute / customers can get it). TestFlight, “approved,” or “on App Store Connect” alone is **not** enough. Do not open or merge `main` → `release` until that explicit instruction.
3. **`release` updates only via PR `main` → `release`**, and only after that human production-shipped instruction. Merge commit only (no squash, no rebase).
4. **Never** open a PR from `test` (or any other branch) into `release`. CI (`release-branch-guard`) and the GitHub ruleset reject that.
5. Nobody “works on” `release`. It documents ships; it is not a base for ongoing work.
6. After promoting **`test` → `main`** (or Archiving from `main`), **switch back to `test` immediately** for the next work.
7. **Film debug picker (Manual / artist stock force):** **DEBUG + git branch `test` only.** It must **never** appear on `main`, `release`, TestFlight, or App Store. Gates: `#if DEBUG` + `BuildChannel.isTestBranch` (see [`.cursor/rules/film-debug-picker.mdc`](../.cursor/rules/film-debug-picker.mdc)). Merging `test` → `main` may keep the source file; runtime/Archive must still hide it. Never strip those gates on `main`.
8. **Gallery persistence:** TestFlight / App Store / Xcode Run from any branch only replaces the binary. **iOS OS upgrades** keep the same Documents container (app must stay installed; bundle id `com.postcardfilm.app`). `Documents/polaroids` stays until the user **uninstalls**. Archive is always **Release**; branch does not flip Debug/Release. Never wipe the polaroids root. See [`.cursor/rules/gallery-persistence.mdc`](../.cursor/rules/gallery-persistence.mdc).

## Flow

1. Develop on **`test`**. Land changelog bullets as you go.
2. When ready for TestFlight / App Store review: open PR **`test` → `main`**, merge, Archive from **`main`**, upload to App Store Connect. **Switch back to `test` immediately.**
3. TestFlight and review happen from **`main`**. Do **not** merge to `release` at this stage.
4. When the human says the build is **in production** (Distribute / live for customers): open PR **`main` → `release`**, merge (merge commit). Tag `vx.y.z` if needed. Stay on / return to **`test`**.

## Hotfixes

Still **no commits on `release`**. Fix on `test`, land on `main`, ship, then merge **`main` → `release` only when the human confirms production**.

If `main` already has a next minor you have **not** distributed, do **not** merge `main` → `release` until `main` matches the binary you actually distributed.

## Current

- **`release`** points at **1.0.0** (build 1) — tag `v1.0.0` — live on the App Store.
- **`main` / `test`** candidate line: **1.2.0** (build 3) — five film looks, notes fold, calmer gallery. Archive from **`main`** for TestFlight.
- **`test`** stays the day-to-day branch.

See also: [CHANGELOG_STRATEGY.md](CHANGELOG_STRATEGY.md) (semver, What’s New, cut checklist), [`.cursor/rules/branching.mdc`](../.cursor/rules/branching.mdc).
