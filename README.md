# KATANA / SHOTGUN (Godot 4.7)

Arcade first-person cyberpunk horde shooter: a katana in your left hand, an
arc shotgun (a "shotgun taser") in your right. Endless seeded runs, a boss
every third wave, glory kills, and a local high-score table. Design notes are
in `DESIGN.md`; the full build spec (the source of truth) is `spec.md`. The
player guide is the [wiki](https://github.com/ggbillyjoe3526/katanashotgun/wiki)
(source in `docs/wiki/`). The game
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
| F (near a staggered enemy) | **Glory kill**: a first-person finisher, heals, +3 cells. A gold "F GLORY KILL" prompt shows when one is in reach |
| F (dropping from high ground onto a foe) | **Plunge**: drive the katana down into it. Counts as a glory kill. A gold "F PLUNGE" prompt shows when one is lined up |
| F (near a boss with its KAMAE broken) | **ONIKIRI**: bosses have no glory kill. Keep attacking to fill the KAMAE bar under their HP; a full bar breaks them, and F takes 20% of their HP (or kills at 20% or less) |
| Slash an incoming bolt | **Deflect** it back |
| WASD / arrows | Move |
| Space | Jump / double jump. Jump at a ledge just out of reach and hold forward to **climb** it |
| Shift (or Q) | Dash (invulnerable) |
| Esc | Pause · `[` `]` mouse sensitivity · F11 fullscreen |
| Tab (title or pause) | **Settings**: volumes, video, mouse and keys, comfort |
| Q twice (title) | **Quit the game**; or click QUIT GAME twice on the title, pause or Settings screen |
| After a run | Type initials if you made the table · **R** retry the same seed · click for a new run · **P** save a run card (a picture of the run with its seed) |

## How a run works
Each run gets a seed (shown on the HUD, as `XXXX-XXXX`). The seed decides the
map, colour palette, weather, cover layout, wave line-ups, mutators, boss order
and level-up offers. Waves never end and keep getting harder. Every third wave is
a boss (Kurokage, Tetsugumo or Shuten). Scores are saved locally (top 10) with
your initials, wave and seed.

Every run pays XP into your **Player Level**, which keeps rising across runs.
Bosses unlock new weapon looks; pick them on the title or pause screen with
**1** (katana edge) and **2** (shotgun coil). The game saves on its own; if you quit
mid-run, the title offers **CONTINUE RUN** from the start of the wave you were
on (**N** starts a new run instead). Saves live in
`%APPDATA%\KatanaShotgun\` on Windows (`profile.json`, `run.json`, each with a
`.bak` copy).

## Project layout
```
scenes/main.tscn            entry scene (everything else is built in code)
scripts/main.gd             boot + game-state flow (title, pause, level-up, death)
scripts/autoload/game.gd    run seed, score/combo, XP, mutator, hitstop
scripts/autoload/profile.gd the saved profile: Player Level, unlocks, top 10, settings,
                            the suspended run (files in scripts/save/)
scripts/save/               crash-safe save files, migrations, run snapshots, XP formula
scripts/rewards.gd          boss rewards (cosmetic weapon looks)
scripts/autoload/sfx.gd     sound pools + music director (playlist, boss themes)
scripts/player.gd           movement, katana, arc shotgun, glory kills, deflects
scripts/viewmodel.gd        first-person weapons, glory-kill poses, arc shotgun
scripts/enemy.gd            grunt / gunner / brute / Shuten (oni): AI, poise, armour
scripts/boss.gd             Kurokage (ninja) and Tetsugumo (spider mech)
scripts/bolt.gd             bolts and shuriken (deflectable), Crimson Wave
scripts/wave_director.gd    endless waves, boss waves, mutators, reinforcements
scripts/mutators.gd         seeded wave modifiers
scripts/upgrades.gd         the 24 level-up augments and their builds (seeded offers)
scripts/palette.gd          the five synthwave palettes
scripts/arena.gd            base class for maps (helpers, sky, weather, lightning, navmesh)
scripts/maps/well.gd        Shin-Kagura Rooftop, vertical: metro pit to beacon tower
scripts/maps/city_backdrop.gd  the living city: towers, logos, traffic, monorail, sun
scripts/maps/rooftop.gd     the flat rooftop (base class of well.gd, not in rotation)
scripts/maps/map_registry.gd   list of maps; the seed picks one
scripts/gore.gd             blood droplets, floor splats, gibs, geysers, scorch marks
scripts/fx.gd               damage numbers, tracers, telegraphs, missiles, explosions
scripts/hud.gd              HUD, title, boss intros, level-up, death screen, initials
scripts/settings.gd         player settings: load, save, apply, key rebinding
scripts/juice.gd            game feel: stamps, wave intro, tally, cards, cut-ins, FINISH
scripts/ui/                 cyberpunk UI pieces: tech panels, glitch text, cut-in,
                            data streaks, kill bursts, the settings screen
scripts/tex_gen.gd          procedural pixel textures
scripts/psx.gd              material factory for the retro look
shaders/                    PSX lit/unlit/cutout, effects, synthwave sky, post
scripts/audio/              sound cue, music track and voice pool classes
assets/audio/               SFX and rain beds (tools/gen_audio.py); cues/ holds one
                            settings file per sound; README.md is the audio how-to
assets/music/               soundtrack (tools/gen_music.py); tracks/ holds one settings
                            file per piece
default_bus_layout.tres     the audio mix: Master, Music, SFX, Ambience, UI buses
assets/fonts/               Jersey 10, Orbitron, Michroma (SIL OFL)
installer/                  Windows installer script (Inno Setup) and icon
tools/                      smoke and unit test runners, notices, release-notes helper,
                            icon and audio generators
test/unit/                  unit tests (Gut); never exported
docs/wiki/                  the player wiki, one page per file (published on merge)
docs/boss-roster.md         how every boss fights (read before changing a boss)
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
  - `tools/changelog.sh check`: the changelog notes in `changelog.d/` (one new
    file per change instead of editing `CHANGELOG.md`; see its `README.md`).
  - `python3 tools/wiki.py check`: the player wiki in `docs/wiki/` (links,
    sidebar, every card, mutator, boss and reward mentioned; see its
    `README.md`). Merging to `main` publishes it to the GitHub wiki.
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

## Settings
Open with **Tab** or the SETTINGS button on the title or pause screen.
- **Audio:** volume for Master, Music, Sound effects, Ambience and Menus/HUD.
- **Video:** window mode (full screen at your screen's resolution by
  default, windowed, or exclusive full screen), VSync (off by default), frame
  cap (unlimited by default, or 60 to 360), graphics preset (WEAK, MEDIOCRE,
  INSANE), render scale (50
  to 100% of the 3D view), field of view (70 to 110, default 88). At any
  resolution the 3D view keeps its 960x540 pixel look, upscaled without
  smoothing (exact 4x blocks on 4K, 2x on 1080p).
- **Controls:** mouse sensitivity and two keys or mouse buttons per action.
  Taking a key another action uses swaps the two. Esc and F11 stay fixed.
- **Comfort:** screen shake and flash strength. Below 100% flashes, impact
  frames don't strobe.

Everything is done with the mouse: click a tab, click the left or right half
of an option, drag or scroll a slider. To rebind, click a slot and press the
new key (or click the slot with the mouse button you want); right-click a slot
to clear it. DEFAULTS resets the tab, BACK (or Esc) closes. Settings are saved in
your profile (`profile.json`, see above), so they get the same backup.

## Debug flags
Pass after `--` on the command line:
- `--autoplay` a bot plays and logs stats · `--god` no damage
- `--wave=6` start at a wave · `--seed=1234-5678` play a specific seed
- `--augments=idaten,fujin,inazuma` start with those level-up cards
  (`wave:2` for rank 2, `all` for every card at max rank); ids are in
  `scripts/upgrades.gd`
- `--continue` resume the suspended run (with `--autoplay`, from `user://debug/`).
  Debug runs keep their own profile in `user://debug/`, never the player's
- `--showcase` (add `--bosses` for the boss line-up) scripted model/gore scene
- `--juicetest` plays every presentation moment back to back (intro, combos,
  tally, FINISH + boss card, boss reward card, level-up, boss name card, kill
  tags, hint, death and the Player Level roll-up);
  `--boss=ninja|mech|oni` forces a boss
- `--movetest` (with `--headless --fixed-fps 60`) runs the scripted movement
  course: jump heights, ledge climbs, walls too tall to climb, plunges
- `--palettetour` four fixed views of the arena for checking colour, then
  quits; `--palette=2` (`0`-`4`, or a quoted name like `--palette="SUNSET DRIVE"`) forces a palette, in the tour
  or a normal run
- `--mutator=grudge` forces that wave mutator on every regular wave (ids in
  `scripts/mutators.gd`)
- `--cardtour` deals every level-up card, three at a time, then quits
- `--settings=audio|video|controls|comfort` opens the settings screen on the
  title at that tab
- `--record-mix=DIR` records each audio bus to `DIR/<bus>.wav` on quit, to
  measure the mix (use with `--write-movie` so audio follows game time)
- `--quality=low|medium|high` effect-count preset · `--perf` perf overlay
  plus a log line every 2 s and a summary at exit
- **F3** toggles the perf overlay (fps, frame time, draw calls, nodes) in any
  build
- `--uiaudit` runs alongside anything above and prints a `[uiaudit]` line for
  any text that leaves the screen, spills out of or across a panel, or
  overlaps other text (and a count at exit)

```
godot --path . -- --autoplay --god --wave=3 --seed=1234-5678
tools/smoke_test.sh                                              # smoke test
tools/unit_tests.sh                                              # unit tests
tools/movement_test.sh                                           # movement course
tools/perf_bench.sh render 7 2400                                # perf probe (draw calls, node churn)
godot --headless --path . --resolution 960x540 --quit-after 20000 -- --autoplay --uiaudit
```

## Regenerating audio
`python3 tools/gen_audio.py` (SFX) and `python3 tools/gen_music.py` (soundtrack).
`python3 tools/gen_audio.py rain` rebuilds only the rain beds. Needs numpy,
scipy and ffmpeg. Mix levels live in `default_bus_layout.tres` (spec §10.1).
Each sound and track has a settings file (`assets/audio/cues/`,
`assets/music/tracks/`); `assets/audio/README.md` explains how to drop in
professional audio, and `godot --headless --path . -s res://tools/make_audio_data.gd`
creates the files for new sounds.
Both need numpy, scipy and ffmpeg. `python3 tools/make_icon.py` rebuilds
`installer/icon.ico` from `icon.svg` (needs Pillow).
