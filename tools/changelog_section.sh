#!/usr/bin/env bash
# Prints the CHANGELOG.md section for one version (used as release notes).
# Usage: tools/changelog_section.sh "0.1 Dev 2"
# Sections start with a heading like "## 0.1 Dev 2 (2026-10-18)" (the version
# name from VERSIONING.md). Before a release, `tools/changelog.sh release`
# writes that section from the fragments in changelog.d/. If no section
# matches, the fragments are used as they are and CI shows a warning.
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
  section=$(tools/changelog.sh unreleased)
  echo "::warning::CHANGELOG.md has no '## $NAME' section; using the notes in changelog.d/ (run tools/changelog.sh release before releasing)" >&2
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
