#!/usr/bin/env bash
# Prints the CHANGELOG.md section for one version (used as release notes).
# Usage: tools/changelog_section.sh "0.1 Dev 2"
# Sections start with a heading like "## 0.1 Dev 2 (2026-10-18)" (the version
# name from VERSIONING.md). Before a release, rename "## Unreleased" to that
# heading. If no section matches, the Unreleased section is used and CI shows
# a warning.
set -euo pipefail
NAME="$1"
cd "$(dirname "$0")/.."
section_for() {
  awk -v h="## $1" '
    /^## / {
      if (found) exit
      if ($0 == h || index($0, h " (") == 1) { found = 1; next }
    }
    found { print }
  ' CHANGELOG.md
}
section=$(section_for "$NAME")
if [ -z "${section//[[:space:]]/}" ]; then
  section=$(section_for "Unreleased")
  echo "::warning::CHANGELOG.md has no '## $NAME' section; using '## Unreleased' for the release notes" >&2
fi
if [ -n "${section//[[:space:]]/}" ]; then
  printf '%s\n' "$section"
else
  echo "See CHANGELOG.md for what changed."
fi
cat <<'NOTE'

---
**Windows:** download the `Windows-Setup.exe` to install, or the `Windows-Portable.zip` to run without installing. Windows may say "Windows protected your PC" because the game isn't code-signed yet: click **More info**, then **Run anyway**.

**macOS:** unzip and move the app to Applications. The first time, right-click it and choose **Open** (the build isn't notarized yet).

**Linux:** unzip and run `KatanaShotgun.x86_64`.
NOTE
