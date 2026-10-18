#!/usr/bin/env bash
# Prints the CHANGELOG.md section for one version (used as release notes).
# Usage: tools/changelog_section.sh 0.3.1
# Sections start with a heading like "## v0.3.1 (2026-10-18)".
set -euo pipefail
VER="${1#v}"
cd "$(dirname "$0")/.."
section=$(awk -v ver="$VER" '
  /^## / { if (found) exit; if ($2 == "v" ver || $2 == ver) { found = 1; next } }
  found { print }
' CHANGELOG.md)
if [ -n "${section//[[:space:]]/}" ]; then
  printf '%s\n' "$section"
else
  echo "See CHANGELOG.md for what changed."
fi
cat <<'NOTE'

---
**Windows:** download the `Windows-Setup.exe` to install, or the `Windows-Portable.zip` to run without installing. Windows may say "Windows protected your PC" because the game isn't code-signed yet: click **More info**, then **Run anyway**.
NOTE
