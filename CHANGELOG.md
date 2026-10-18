# Changelog

What changed in each version of KATANA / SHOTGUN, newest first, in plain
words. Each release's section becomes its GitHub Release notes, so headings
must look like `## 0.1 Dev 2 (2026-10-18)`: the version name from
`VERSIONING.md`.

## Unreleased

### Settings
- A settings screen, opened with Tab or the SETTINGS button on the title and
  pause screens. It has volume sliders for master, music, sound effects,
  ambience and menus; window mode, VSync, frame cap, quality, render scale
  and field of view; mouse sensitivity and key rebinding (two keys per
  action, mouse buttons too); and comfort sliders for screen shake and
  flashes.
- Everything works with the mouse or the keyboard, applies at once and is
  remembered next time. F11 and the `[` `]` sensitivity keys are remembered
  too.
- Turning flashes below 100% also stops the impact frames from strobing.

### Glory kills on F
- Glory kills are now your call: when an enemy is staggered and close, a
  gold "F  GLORY KILL" prompt appears under the crosshair (on bosses it says
  "DEATHBLOW"), and the enemy's marker turns gold. Press F to finish it,
  just like Doom.
- Slashing a staggered enemy just cuts it (hard), so you choose between a
  quick kill and the full finisher with its health and cells.
- F can be pressed a moment early and still counts. You can move it to
  another key in Settings.

### A city in every colour
- The rooftop no longer drowns in purple. Each of the five colour schemes now
  has six strong neon colours (pinks, cyans, ambers, electric blues, acid
  greens, orange-reds), and the signs, tubes, crates, catwalks, obelisks,
  palm trees and lit windows spread across all of them.
- Skies run through at least two colours (a deep blue top, a hot middle, a
  bright horizon) and the haze and shadows are darker and more neutral, so
  the neon pops instead of everything sharing one tint.
- The same seed still gives the same colour scheme and the same rooftop.

### Version names
- The game is now version **0.1 Dev 1** (the title screen used to say
  V0.3.0). Updates go 0.1 Dev 2, Dev 3 and on, then 0.1 Beta 1, Beta 2, and
  the full release is 0.1. The title screen, the installer and the download
  names all use these names.

### Text you can actually read
- Every number and word on screen is bigger and sits on a dark plate or
  outline, so it reads over any part of the city.
- Glitch effects only play as text arrives and leaves. While it is on screen
  it holds still: no scrambling, flicker or shaking, and numbers (the wave,
  the countdown, combo, score and payouts) never turn into random symbols.
- The HUD corners no longer overlap: wave and hostiles top-left, best score
  and the boss bar top-centre, score and combo top-right. The seed moved to
  the pause screen.
- The wave intro fits inside its panel, with the mutator on two clear lines,
  and the 3-2-1 and FIGHT land below it instead of on top.
- The end-of-wave payout has clean rows, bigger chips and multiplier boxes,
  and a total that counts up without shaking.
- Boss name cards, the boss-defeated line, FINISH and the cut-ins are clean
  and still, each held long enough to read. Only one message shows in a spot
  at a time.
- Kill tags stack neatly on dark plates, repeats count up ("DEFLECT! x3"),
  and "NO CHARGE" no longer blinks. Damage numbers are bigger.
- Level-up cards, the title screen and the results screen use readable sizes
  too.

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
