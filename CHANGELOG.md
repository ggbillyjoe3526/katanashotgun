# Changelog

What changed in each version of KATANA / SHOTGUN, newest first, in plain
words. Each release's section becomes its GitHub Release notes, so headings
must look like `## v0.3.1 (2026-10-18)`.

## Unreleased

### The project moves into GitHub
- The v0.3 prototype is now the starting point of the real game, with its spec
  and design doc alongside it.
- Every change is now checked automatically: a bot plays the game in the cloud
  and any script error fails the check.
- Releases are automatic: one click (or a version tag) builds a Windows
  installer, a portable Windows zip, and Linux and macOS zips, and publishes
  them on the GitHub Releases page.
- The title screen now shows the game's version in the bottom-right corner.
- The game can now be exported for macOS as well as Windows and Linux. The old
  web build was removed: this is a desktop game.
- Every download now includes `THIRD_PARTY_NOTICES.txt`, the licences for the
  Godot engine and the game's fonts.
- More automatic checks on every change: tests that the same seed always gives
  the same run, and a code style check.

## v0.3.0 (prototype)
- Every core mechanic: DOJIGIRI katana, RAIJIN-12 arc shotgun, dash, double
  jump, deflects, stagger and six glory kills.
- Endless seeded waves with mutators, a boss every third wave (Kurokage,
  Tetsugumo, Shuten), combo, end-of-wave tally and a local top 10.
- The Shin-Kagura Rooftop map, the retro PS1 look, the cyberpunk UI and
  placeholder audio.
