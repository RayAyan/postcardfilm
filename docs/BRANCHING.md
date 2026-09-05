# Branching — postcardfilm

Three branches. Only **`test`** is for day-to-day work.

| Branch | Role |
|--------|------|
| **`test`** | GitHub **default**. All development. Clones, PRs, and agents work here. |
| **`main`** | App Store **candidate** only. Archive / upload / wait for approval from here. Not the default. No feature work. |
| **`release`** | **Live store ledger.** What is actually on the App Store after you hit Distribute. Read-only except merge from `main`. |

```text
test  --(ready to upload)-->  main  --(approved + Distribute)-->  release
 ^                                                                  |
 |------------------------ stay on test ---------------------------|
```

## Hard rules

1. **Always work on `test`.** Do not commit on `main` or `release`.
2. **`release` updates only via PR `main` → `release`**, after App Store approval **and** you tap Distribute.
3. **Never** open a PR from `test` (or any other branch) into `release`. CI (`release-branch-guard`) and the GitHub ruleset reject that.
4. Merge into `release` with a **merge commit** only (no squash, no rebase). The ruleset allows `merge` only.
5. Nobody “works on” `release`. It documents ships; it is not a base for ongoing work.

## Flow

1. Develop on **`test`**. Land changelog bullets as you go.
2. When ready to upload / wait for approval: open PR **`test` → `main`**, merge, Archive from `main`, upload to App Store Connect. Switch back to **`test`** immediately for the next version.
3. When the build is **approved and you hit Distribute**: open PR **`main` → `release`**, merge (merge commit). Tag `vx.y.z` on that ship if not already tagged.
4. Stay on **`test`**.

## Hotfixes

Still **no commits on `release`**. Fix on `test` (optionally compare against `release` for the live code), land on `main`, submit / distribute, then merge **`main` → `release`**.

If `main` already has a next minor you have **not** distributed, do **not** merge `main` → `release` until `main` matches the binary you actually distributed.

## Current (after 1.0.0 ship)

- **`release`** points at **1.0.0** (build 1) — tag `v1.0.0` — live on the App Store.
- **`main`** is the **1.1.0** (build 2) App Store candidate (the pack + Process/Settings polish). Archive / upload from here when ready.
- **`test`** stays the day-to-day branch; keep landing work here and promote to `main` when the next candidate is ready.

See also: [CHANGELOG_STRATEGY.md](CHANGELOG_STRATEGY.md) (semver, What’s New, cut checklist).
