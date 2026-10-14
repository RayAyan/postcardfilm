# Open bugs — postcardfilm

Working list for issues found on **`test`** (and reports from TestFlight / production). Shipped fixes land in [`CHANGELOG.md`](../CHANGELOG.md); this file tracks status while work is in flight.

## Persistence (standing rule)

**While the app stays installed, the gallery must never be wiped** — not by TestFlight, App Store updates, Xcode Run, Debug vs Release, or any git branch. Uninstall (or changing the bundle id) is the only full loss iOS allows. In-app delete after the confirm modal is the only allowed intentional delete.

See [`.cursor/rules/gallery-persistence.mdc`](../.cursor/rules/gallery-persistence.mdc). Every bugfix here must stay UI / cache / gesture only — never seed-wipe or `removeItem` the polaroids root.

---

## Bugs

### BUG-001 — Process gallery paging jank (large albums)

| | |
|---|---|
| **Status** | Fixed |
| **Surface** | Gallery → open print → swipe left / right |
| **Repro** | Large album; page between prints — motion feels unsmooth, worse with more prints |
| **Cause** | Page `TabView` built every print; swipe settle re-read index + disk repair; sync PNG decode on miss |
| **Fix** | Lazy horizontal pager (`ScrollView` + `LazyHStack` + paging); in-memory reload; neighbor thumb prefetch |

### BUG-002 — Gallery vertical scroll clunky on older iPhones

| | |
|---|---|
| **Status** | Fixed |
| **Surface** | Gallery grid |
| **Repro** | Older devices: drag over a photo often fails to scroll; system scroll indicator too thin |
| **Cause** | Cell `Button` + long-press fighting `ScrollView`; thin system indicator only |
| **Fix** | Scroll-friendly tap / long-press; analog trailing scroll rail (visible on long albums, expands on touch) |

### BUG-003 — Process paging stuck between two prints

| | |
|---|---|
| **Status** | Fixed |
| **Surface** | Gallery → open print → swipe |
| **Repro** | Swipe left/right leaves two half-prints centered with a gutter in the middle |
| **Cause** | Sliding prev/current/next `TabView` window rebuilt mid-gesture |
| **Fix** | Replaced windowed `TabView` with stable lazy paging `ScrollView` |

### BUG-004 — Gallery scroll rail invisible

| | |
|---|---|
| **Status** | Fixed |
| **Surface** | Gallery grid |
| **Repro** | Custom rail never appears; system indicators also hidden |
| **Cause** | `isNeeded` false from height prefs; faint chrome; indicators hidden unconditionally |
| **Fix** | Show rail when album has ≥7 prints or content overflows; higher-contrast thumb; system indicator fallback for short lists |
