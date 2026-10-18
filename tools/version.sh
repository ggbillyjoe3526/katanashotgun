#!/usr/bin/env bash
# The game's version is set in ONE place: config/version in project.godot,
# written the way players see it ("0.1 Dev 1", "0.1 Beta 2", "0.1").
# VERSIONING.md explains the scheme. This prints the other forms the release
# pipeline needs, one per line:
#   name=0.1 Dev 1     what players see (title screen, installer, release title)
#   tag=0.1-dev.1      the git tag after its "v", and the download file names
#   number=0.1.1.1     Windows version number: four numbers that always go up
#   prerelease=true    Dev and Beta builds are GitHub pre-releases
# Usage: tools/version.sh               (reads project.godot)
#        tools/version.sh "0.1 Beta 2"  (checks and converts a given name)
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="${1-$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)}"
NUM='(0|[1-9][0-9]{0,3})'
if ! [[ "$NAME" =~ ^${NUM}\.${NUM}(\ (Dev|Beta)\ ([1-9][0-9]{0,3}))?$ ]]; then
  echo "::error::'$NAME' is not a version like '0.1 Dev 1', '0.1 Beta 2' or '0.1' (see VERSIONING.md)" >&2
  exit 1
fi
MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
N="${BASH_REMATCH[5]}"
case "${BASH_REMATCH[4]}" in
  Dev)  TAG="$MAJOR.$MINOR-dev.$N";  NUMBER="$MAJOR.$MINOR.1.$N"; PRE=true ;;
  Beta) TAG="$MAJOR.$MINOR-beta.$N"; NUMBER="$MAJOR.$MINOR.2.$N"; PRE=true ;;
  *)    TAG="$MAJOR.$MINOR";         NUMBER="$MAJOR.$MINOR.3.0";  PRE=false ;;
esac
printf 'name=%s\ntag=%s\nnumber=%s\nprerelease=%s\n' "$NAME" "$TAG" "$NUMBER" "$PRE"
