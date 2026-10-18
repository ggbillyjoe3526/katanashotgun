# KATANA / SHOTGUN (Godot 4.7)

Arcade first-person cyberpunk horde shooter: a katana in your left hand, an
arc shotgun (a "shotgun taser") in your right. Endless seeded runs, a boss
every third wave, glory kills, and a local high-score table. Design notes are
in `DESIGN.md`; the full build spec (the source of truth) is `spec.md`. The game
started from the v0.3 prototype and is a desktop game (Windows first, then Mac
and Linux).

## Play it
- **Windows:** download the installer or the portable zip from the
  [Releases page](https://github.com/ggbillyjoe3526/katanashotgun/releases).
- **In Godot:** install Godot **4.7.2** (standard, not .NET), choose *Import*,
  pick this folder's `project.godot`, then press F5.

| Control | Action |
|---|---|
| Mouse | Look |
| LMB (or J) | Katana: 3-hit combo, cleaves, **katana kills charge the shotgun** |
| RMB (or K) | Arc shotgun: lightning spread, staggers, headshots ×2 |
| F (near a staggered enemy) | **Glory kill**: a first-person finisher, heals, +3 cells (bosses: a 15% deathblow). A gold "F GLORY KILL" prompt shows when one is in reach |
| Slash an incoming bolt | **Deflect** it back |
| WASD / arrows | Move |
| Space | Jump / double jump |
| Shift (or Q) | Dash (invulnerable) |
| Esc | Pause · `[` `]` mouse sensitivity · F11 fullscreen |
| After a run | Type initials if you made the table · **R** retry the same seed · click for a new run |

## How a run works
Each run gets a seed (shown on the HUD, as `XXXX-XXXX`). The seed decides the
map, colour palette, weather, cover layout, wave line-ups, mutators, boss order
and level-up offers. Waves never end and keep getting harder. Every third wave is
a boss (Kurokage, Tetsugumo or Shuten). Scores are saved locally (top 10) with
your initials, wave and seed.

## Project layout
```
scenes/main.tscn            entry scene (everything else is built in code)
scripts/main.gd             boot + game-state flow (title, pause, level-up, death)
scripts/autoload/game.gd    run seed, score/combo, XP, mutator, high scores, hitstop
scripts/autoload/sfx.gd     sound pools + music director (playlist, boss themes)
scripts/player.gd           movement, katana, arc shotgun, glory kills, deflects
scripts/viewmodel.gd        first-person weapons, glory-kill poses, arc shotgun
scripts/enemy.gd            grunt / gunner / brute / Shuten (oni): AI, poise, armour
scripts/boss.gd             Kurokage (ninja) and Tetsugumo (spider mech)
scripts/bolt.gd             bolts and shuriken (deflectable), Crimson Wave
scripts/wave_director.gd    endless waves, boss waves, mutators, reinforcements
scripts/mutators.gd         seeded wave modifiers
scripts/upgrades.gd         the 14 level-up augments (seeded offers)
scripts/palette.gd          the five synthwave palettes
scripts/arena.gd            base class for maps (helpers, sky, weather, lightning)
scripts/maps/rooftop.gd     Shin-Kagura Rooftop (seeded cover, signs, skyline)
scripts/maps/map_registry.gd   list of maps; the seed picks one
scripts/gore.gd             blood droplets, floor splats, gibs, geysers, scorch marks
scripts/fx.gd               damage numbers, tracers, telegraphs, missiles, explosions
scripts/hud.gd              HUD, title, boss intros, level-up, death screen, initials
scripts/juice.gd            game feel: stamps, wave intro, tally, cards, cut-ins, FINISH
scripts/ui/                 cyberpunk UI pieces: tech panels, glitch text, cut-in,
                            data streaks, kill bursts
scripts/tex_gen.gd          procedural pixel textures
scripts/psx.gd              material factory for the retro look
shaders/                    PSX lit/unlit/cutout, effects, synthwave sky, post
assets/audio/               SFX (tools/gen_audio.py)
assets/music/               soundtrack (tools/gen_music.py)
assets/fonts/               Orbitron, Chakra Petch, Share Tech Mono, Michroma (SIL OFL)
installer/                  Windows installer script (Inno Setup) and icon
tools/                      smoke and unit test runners, notices, release-notes helper,
                            icon and audio generators
test/unit/                  unit tests (Gut); never exported
addons/gut/                 Gut test framework (MIT); never exported
THIRD_PARTY_NOTICES.txt     licences for the engine and fonts, shipped with every download
gdlintrc                    gdlint settings
.github/                    CI (checks on every PR) and the release workflow
```

## Adding a map
1. Create `scripts/maps/your_map.gd` with `class_name YourMap` and `extends Arena`.
2. In `_init()` set `map_name`, `half` (arena half-size), `player_spawn` and
   `boss_spawn`. In `_build_layout()` build the level with the helpers
   (`_platform`, `_ramp`, `_solid`, `_neon`, `_neon_box_edges`, `_light`, …),
   fill `spawn_points` and `jump_pads`, and use `pal` for colours and `rng` for
   seeded variation.
3. Add it to `MAPS` in `scripts/maps/map_registry.gd`.

## Checks and releases
- **Every pull request** runs these checks in GitHub Actions:
  - `tools/smoke_test.sh`: Godot imports the project, the autoplay bot plays,
    and any script error fails it.
  - `tools/unit_tests.sh`: the Gut tests in `test/unit/` (settings in
    `.gutconfig.json`).
  - The licence notices: `THIRD_PARTY_NOTICES.txt` must match what
    `tools/make_notices.gd` writes.
  - `gdlint scripts test tools` (gdtoolkit 4.5.0, settings in `gdlintrc`).
  Run them locally the same way (set `GODOT=` to your Godot binary if `godot`
  isn't on PATH).
- **Licence notices:** after adding a font or other third-party asset, or
  changing the Godot version, run
  `godot --headless --path . -s res://tools/make_notices.gd` and commit
  `THIRD_PARTY_NOTICES.txt`. The installer and every zip ship it next to the
  game.
- **Version:** set once, as `config/version` in `project.godot`, with names
  like `0.1 Dev 1`, `0.1 Beta 2` and `0.1`. `VERSIONING.md` explains the
  scheme and how a name becomes a tag (`v0.1-dev.1`).
- **Releases** (`.github/workflows/release.yml`): open *Actions → Release →
  Run workflow* on `main` to release the version in `project.godot` (or push
  its matching tag). It runs the smoke test, exports Windows, Linux and
  macOS, builds the Windows installer, checks it installs and uninstalls, and
  publishes a GitHub Release with `KatanaShotgun-v0.1-dev.1-Windows-Setup.exe`,
  `-Windows-Portable.zip`, `-Linux.zip` and `-macOS.zip`. The release notes
  come from that version's section of `CHANGELOG.md`, which a release gathers
  from the one-file-per-change notes in `changelog.d/`. A pull request that
  touches the pipeline does a dry run: everything is built and attached to
  the run, nothing is published.
- **Local export** (needs the 4.7.2 export templates):
  `godot --headless --path . --export-release "Windows Desktop" build/windows/KatanaShotgun.exe`

## Debug flags
Pass after `--` on the command line:
- `--autoplay` a bot plays and logs stats · `--god` no damage
- `--wave=6` start at a wave · `--seed=1234-5678` play a specific seed
- `--showcase` (add `--bosses` for the boss line-up) scripted model/gore scene
- `--juicetest` plays every presentation moment back to back (intro, combos,
  tally, FINISH + boss card, level-up, boss name card, kill tags, hint, death);
  `--boss=ninja|mech|oni` forces a boss
- `--palettetour` four fixed views of the arena for checking colour, then
  quits; `--palette=2` (`0`-`4`, or a quoted name like `--palette="SUNSET DRIVE"`) forces a palette, in the tour
  or a normal run

```
godot --path . -- --autoplay --god --wave=3 --seed=1234-5678
tools/smoke_test.sh                                              # smoke test
tools/unit_tests.sh                                              # unit tests
```

## Regenerating audio
`python3 tools/gen_audio.py` (SFX) and `python3 tools/gen_music.py` (soundtrack).
Both need numpy, scipy and ffmpeg. `python3 tools/make_icon.py` rebuilds
`installer/icon.ico` from `icon.svg` (needs Pillow).
