# Changelog

What changed in each version of KATANA / SHOTGUN, newest first, in plain
words. Each release's section becomes its GitHub Release notes, so headings
must look like `## v0.3.1 (2026-10-18)`.

## Unreleased

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

### Nothing spills out or piles up
- Text stays inside its panels and never sits on other text: the big moments
  (FINISH, the wave payout, the boss cards, the wave intro, level-up) now
  take turns instead of stacking.
- The level-up screen and the pause screen replace the HUD instead of
  covering half of it. Pausing freezes the big messages until you resume.
- A level-up earned on a wave's last kills opens after the payout, before
  the next wave starts.
- Long tips wrap onto two lines instead of running off the screen, and the
  results numbers line up in a column.

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

## v0.3.0 (prototype)
- Every core mechanic: DOJIGIRI katana, RAIJIN-12 arc shotgun, dash, double
  jump, deflects, stagger and six glory kills.
- Endless seeded waves with mutators, a boss every third wave (Kurokage,
  Tetsugumo, Shuten), combo, end-of-wave tally and a local top 10.
- The Shin-Kagura Rooftop map, the retro PS1 look, the cyberpunk UI and
  placeholder audio.
