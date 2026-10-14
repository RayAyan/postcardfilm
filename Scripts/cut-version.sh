#!/usr/bin/env bash
# Bump marketing version + build in project.yml, regenerate Xcode project,
# append docs/VERSIONS.md, print App Store What’s New paste block.
#
# Usage:
#   Scripts/cut-version.sh 1.2.0
#   Scripts/cut-version.sh 1.2.0 --build 3
#   Scripts/cut-version.sh 1.2.0 --notes "five quiet film looks"
#   Scripts/cut-version.sh minor|major|patch   # bump from current marketing version
#
# Does not edit CHANGELOG.md — move [Unreleased] bullets by hand (or AI), then
# paste What’s New into the ## [x.y.z] HTML comment. See docs/CHANGELOG_STRATEGY.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_YML="${ROOT}/project.yml"
VERSIONS_MD="${ROOT}/docs/VERSIONS.md"

VERSION_ARG="${1:-}"
shift || true
BUILD_ARG=""
NOTES="TestFlight / App Store candidate"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) BUILD_ARG="${2:-}"; shift 2 ;;
    --notes) NOTES="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "${VERSION_ARG}" ]]; then
  echo "usage: Scripts/cut-version.sh <x.y.z|major|minor|patch> [--build N] [--notes \"…\"]" >&2
  exit 1
fi

current_marketing="$(sed -n 's/^[[:space:]]*MARKETING_VERSION: "\([^"]*\)"/\1/p' "${PROJECT_YML}" | head -1)"
current_build="$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION: "\([^"]*\)"/\1/p' "${PROJECT_YML}" | head -1)"

if [[ -z "${current_marketing}" || -z "${current_build}" ]]; then
  echo "could not read MARKETING_VERSION / CURRENT_PROJECT_VERSION from project.yml" >&2
  exit 1
fi

IFS=. read -r maj min pat <<<"${current_marketing}"
maj="${maj:-0}"; min="${min:-0}"; pat="${pat:-0}"

case "${VERSION_ARG}" in
  major) VERSION="$((maj + 1)).0.0" ;;
  minor) VERSION="${maj}.$((min + 1)).0" ;;
  patch) VERSION="${maj}.${min}.$((pat + 1))" ;;
  *)
    if [[ ! "${VERSION_ARG}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "version must be x.y.z (got: ${VERSION_ARG})" >&2
      exit 1
    fi
    VERSION="${VERSION_ARG}"
    ;;
esac

if [[ -n "${BUILD_ARG}" ]]; then
  BUILD="${BUILD_ARG}"
else
  BUILD="$((current_build + 1))"
fi

# macOS sed -i needs ''
sed -i '' "s/MARKETING_VERSION: \"${current_marketing}\"/MARKETING_VERSION: \"${VERSION}\"/" "${PROJECT_YML}"
sed -i '' "s/CURRENT_PROJECT_VERSION: \"${current_build}\"/CURRENT_PROJECT_VERSION: \"${BUILD}\"/" "${PROJECT_YML}"

if command -v xcodegen >/dev/null 2>&1; then
  (cd "${ROOT}" && xcodegen generate)
else
  echo "warning: xcodegen not found — project.yml updated; run xcodegen generate yourself" >&2
fi

TODAY="$(date +%Y-%m-%d)"
# Insert new row after the table header separator line.
if ! grep -q "| ${TODAY} | ${VERSION} | ${BUILD} |" "${VERSIONS_MD}"; then
  awk -v row="| ${TODAY} | ${VERSION} | ${BUILD} | main (App Store / TestFlight candidate) | ${NOTES} |" '
    BEGIN { done = 0 }
    /^\| Date \| Version \| Build \|/ { print; next }
    /^\|------/ && !done { print; print row; done = 1; next }
    { print }
  ' "${VERSIONS_MD}" > "${VERSIONS_MD}.tmp" && mv "${VERSIONS_MD}.tmp" "${VERSIONS_MD}"
fi

cat <<EOF

cut version → ${VERSION} (${BUILD})
  project.yml  MARKETING_VERSION=${VERSION}  CURRENT_PROJECT_VERSION=${BUILD}
  docs/VERSIONS.md  row added for ${TODAY}

next:
  1. Finish CHANGELOG.md  ## [${VERSION}] - ${TODAY}  (move bullets out of [Unreleased])
  2. Paste What’s New into that section as an HTML comment
  3. Commit on test → PR → main → Archive from main for TestFlight

suggested What’s New (edit freely):

five quiet looks of film. denser darks. warmer reds.
a soft fold when there's a note behind.
gallery that keeps up — your prints stay on the phone.

EOF
