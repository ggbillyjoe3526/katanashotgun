# Known issues

Every bug we know about that is **still open**, in one place. William checks
the "Needs William" items on his PC; Claude threads pick up the "Needs Claude"
items; "Needs a decision" items wait for William's call before anyone fixes
them. Fixed bugs move to [Resolved](#resolved) at the bottom, so an ID always
leads somewhere.

**How to use it**
- **Before fixing a bug**, look here first: it may already have an ID, a repro
  and a suspected cause.
- **Found a new bug?** Add it under the right section with the next free ID
  (`KI-` plus three digits; IDs are never reused or renumbered).
- **Fixed one?** Move its entry to Resolved in the same PR as the fix, with
  the PR number, and add a `changelog.d/` note if players would notice.
- **Severity:** **high** breaks a run, loses progress or breaks a rule the
  game promises (seeds are law, saves never lost); **medium** is wrong
  behaviour a player can hit in normal play; **low** is rare, cosmetic,
  dev-only or latent (can't happen today but would after a likely change).
- **Repro** gives a seed and wave where one is known. Play a seed with
  `S` on the title screen, or `godot --path . -- --seed=XXXX-XXXX --wave=N`.
- Cloud threads can't play the game or measure frame rates: anything about
  feel, looks or speed is marked "Needs William".

Last full bug pass: 2026-10-23 (whole game, every script).

---

## Needs William (play it on the PC)

### KI-001 Inputs during a glory kill are dropped
- **Severity:** low
- **Symptom:** pressing slash, dash or jump while a glory kill finisher plays
  does nothing afterwards; the same goes for a press on the exact frame a
  ledge climb starts. (A slash or dash pressed during a ledge climb *is*
  kept and fires when the climb ends.)
- **Repro:** any seed, wave 1-2. Stagger a grunt, press F, and mash the
  katana during the finisher. Does the first slash after it feel swallowed?
- **Suspected cause:** `scripts/player.gd` `_physics_process` returns early
  while `gk_target` is set, before the dash, jump and katana reads, and
  nothing buffers those presses (the climb path does buffer them).
- **Next:** William says whether it feels wrong. If so, Claude buffers the
  last press during the finisher the way `_update_climb` does.

### KI-002 Jump and dash have no input buffer
- **Severity:** low
- **Symptom:** Space pressed a few frames before landing, or Shift pressed
  just before a dash charge refills, is lost. The spec buffers only the
  katana and F.
- **Repro:** any seed, wave 1: jump, and press Space again just before you
  land. Does it ever fail to jump?
- **Suspected cause:** `scripts/player.gd` reads `is_action_just_pressed`
  for jump and dash on that frame only.
- **Next:** William's feel check; if it bites, a short buffer (about 0.1 s)
  is a small change, and the spec would gain the rule.

### KI-003 Enemies can't follow you onto three ledges on The Well
- **Severity:** low
- **Symptom:** three grab lips have no enemy jump link: the water-tank
  platform (north-west roof, near x -27, z -25), the stairwell hut roof
  (south-west, near x -21, z 22) and the east edge of the south gantry. Melee
  enemies may mill below instead of climbing after you.
- **Repro:** any seed, wave 2+: climb onto the water tanks and wait. Do
  grunts and brutes reach you, or is it a safe spot?
- **Suspected cause:** `scripts/maps/well.gd` `_links()` has no `[low,
  high]` pair for the lips at well.gd's `_lip(Vector3(-27, 8, -25) ...)`,
  `_lip(Vector3(-21, 3, 22) ...)` and `_lip(Vector3(21, DECK, 23) ...)`.
- **Next:** if it is a safe spot, Claude adds the links (and checks them with
  the navmesh unit test); if William likes them as player-only perches, the
  doc comment changes instead.

### KI-004 A puddle hides under the south service block
- **Severity:** low (looks)
- **Symptom:** one fixed puddle decal near the bottom of the shaft sits
  mostly under the south service block.
- **Repro:** any seed with rain, wave 1: walk the shaft floor under the
  south service block (x 0, z 9.5).
- **Suspected cause:** `scripts/maps/world_detail.gd` places its fixed
  puddle spots by floor height only and never checks the map's solid blocks.
- **Next:** William confirms it shows; Claude skips spots that overlap a
  solid.

### KI-005 Frame-time costs that need a profile on real hardware
- **Severity:** low (no measured hitch yet)
- **Symptom:** none seen. The code sweep found small allocations in hot
  paths that could add up on the 2015 laptop target (spec §14): lightning
  arcs rebuilt every 0.022 s (`fx.gd`), a ray query object per pellet
  (`player.gd`) and per bolt per tick (`bolt.gd`), shockwaves, telegraph
  lines and missile rings built from new meshes and materials each time
  (`fx.gd`), and HUD text and colour overrides re-set every frame (`hud.gd`).
- **Repro:** WEAK preset, any seed, wave 8+ with a gunner fan and a boss:
  watch for hitches in the F3 overlay (1% lows).
- **Next:** William runs `tools/perf_bench.sh` or plays with the overlay on
  the laptop; Claude fixes the worst ones first, measured (project rule:
  measure before optimising).

### KI-006 You can get wedged in two corners of The Well
- **Severity:** medium (if a player can hit it; the bot does)
- **Symptom:** in two 10-minute bot runs the player stood still for a long
  time with its fall speed climbing (to -340 m/s) as if falling, while not
  moving: once in the pit under the north service block by the west wall
  (about x -11.8, y -10, z -9), once at the outer edge of the east ramp to
  the roof (about x 12.2, y -3.4, z -3). The bot then couldn't reach the last
  enemies and one wave stalled for 5 minutes. It happens on `main` too.
- **Repro:** any seed, wave 1. Walk into those two spots (in the pit, under
  the north service block, push into the west wall; on the east ramp, push
  off its outer edge against the shaft wall). Do you get stuck, or slide out? Jump out.
- **Suspected cause:** the capsule rests on an edge between two surfaces
  that both count as wall, so `is_on_floor()` stays false and gravity keeps
  adding up. Map collision in `scripts/maps/well.gd` (ramp edge, the
  service block's pillars) or `scripts/player.gd` floor settings.
- **Next:** William says whether a player gets caught; then Claude closes the
  gap in the collision (and, either way, can cap the fall speed so a stuck
  body doesn't build up a huge one).

---

## Needs Claude (another attempt in a later thread)

### KI-010 An unreadable save file is treated as a damaged one
- **Severity:** medium
- **Symptom:** if `profile.json` exists but can't be opened at launch (for
  example an antivirus or sync tool holding it), the game treats it as
  damaged. With no readable backup it moves the files aside and starts a
  new profile; the new profile's first save can then be the copy loaded
  next time, even though the old file was fine.
- **Repro:** not reproducible in the cloud; needs a file lock on Windows.
- **Suspected cause:** `scripts/save/save_file.gd` `read_text()` returns ""
  for a file that exists but won't open, and `read()` counts it as found but
  bad. `profile.gd` then quarantines.
- **Next:** tell "can't open" apart from "damaged": keep the profile
  read-only for the session (no saves over it) and warn, rather than starting
  fresh. Needs a unit test with a file that can't be opened.

### KI-011 A failed backup rotation loses the old backup
- **Severity:** low
- **Symptom:** none seen. When saving, the old `.bak` is deleted before the
  current file is renamed into its place, and the rename's result isn't
  checked. If that rename fails, the save goes ahead without a backup.
- **Suspected cause:** `scripts/save/save_file.gd` `write()`.
- **Next:** rename the old backup aside first and only drop it once the
  rotation worked.

### KI-012 A newer-version profile keeps only its first copy
- **Severity:** low
- **Symptom:** loading a profile written by a newer build keeps a copy as
  `profile.json.v<N>`, but only the first time; later loads of a newer file
  don't refresh it.
- **Suspected cause:** `scripts/autoload/profile.gd` `_keep_copy` skips when
  the copy exists.
- **Next:** stamp the copy name, or overwrite it when the content differs.

### KI-013 A profile that fails to migrate pushes the old file into the backup
- **Severity:** low
- **Symptom:** a migration that fails starts a fresh profile and saves it,
  which rotates the unmigratable file into `.bak` and drops the older
  backup. The `.v<N>` copy still holds the data.
- **Suspected cause:** `scripts/autoload/profile.gd` load path after
  `migrate()` returns {}.
- **Next:** quarantine instead of saving over it.

### KI-014 The enemy count can go up to two over the wave's cap
- **Severity:** low
- **Symptom:** a spawn group of one to three enemies is let in when the
  field is one or two under the cap, so the cap (8 + 2 per wave, up to 22)
  can be passed by two.
- **Suspected cause:** `scripts/wave_director.gd` "spawning" phase checks
  the cap once, then spawns the whole group.
- **Next:** decide whether to trim the group (changes how a seed's waves
  arrive, not the plan) or keep it and write the soft cap into the spec.

### KI-015 The score jumps on CONTINUE
- **Severity:** low (looks)
- **Symptom:** after continuing a suspended run, the score label pops gold
  and big for a moment, as if points were just scored.
- **Repro:** any seed: quit during wave 2's break, CONTINUE on the title.
- **Suspected cause:** `scripts/hud.gd` `on_run_resumed()` sets the shown
  score but not `_last_target`.
- **Next:** set both; small fix.

### KI-016 The autoplay bot isn't reproducible
- **Severity:** low (test tooling only)
- **Symptom:** two bot runs of the same seed play differently, because the
  bot steers by the wall clock and picks timings from the presentation
  random stream. Wave plans still match (that's what `seed_check.sh`
  compares), so this only matters for debugging a bot run.
- **Suspected cause:** `scripts/player.gd` `_autoplay` (`Time.get_ticks_msec`
  and `Game.rng_fx`).
- **Next:** give the bot its own stream seeded from the run seed and use
  run time.

### KI-017 Dev-only soda-can and dev-menu slips
- **Severity:** low (dev only)
- A resumed run picks up the current session's SODA CANS switch even when
  the run started without cans (`scripts/main.gd` sets `cans_run` only to
  true), and an abandoned cans run is paid with the live `Game.cans_run`
  (`scripts/autoload/profile.gd` `finish_run`).
- The dev menu's PALETTE row shows "?" when the game was launched with
  `--palette=NAME` (`scripts/ui/dev_menu.gd`).
- The dev menu's KILL ALL can clear a wave inside its intro, and the
  intro's leftover timers then drive the next intro (`scripts/juice.gd`
  `wave_intro` callbacks carry no id).
- When a can is finished, its popped lid and fizz vanish mid-air
  (`scripts/viewmodel_can.gd`).

### KI-018 Latent code traps (can't happen today)
- **Severity:** low
- `scripts/ui/tech_button.gd` keeps the label it had at `_ready()`; a later
  `text` change is undone the next time the button disarms.
- `scripts/ui/run_card.gd` reads its SubViewport after two frame awaits
  without checking it still exists (only at teardown).
- `scripts/viewmodel.gd` checks only `led_0` of the shotgun model's cell
  lights; a model whose later lights aren't meshes would crash `set_cells`.
- `scripts/maps/city_backdrop.gd` seeds itself with one draw from the map
  stream, and the weather roll comes after the backdrop build. Harmless
  now, but a backdrop change that drew more would shift every seed's
  weather. Fixing it changes weather for existing seeds, so it needs the
  "Needs a decision" sign-off below.
- `scripts/enemy.gd` reads a `heal_kill` mutator value that no mutator
  sets (Blood Moon uses `exec_heal`), so that branch never runs.
- The unit test `test_a_cut_short_red_signal_never_leaves_the_boss_hidden`
  (`test/unit/test_boss_moveset.gd`) leaves one orphan node behind (Gut
  reports it; the test still passes).
- Bolt trail drops share the blood droplet budget, so a screen full of
  bolts can thin out blood and sparks (`scripts/bolt.gd`, `scripts/gore.gd`).

---

## Needs a decision (William)

### KI-020 Idaten Drive refills every dash charge
- **Severity:** low
- **Symptom:** taking Idaten Drive gives +1 maximum dash charge and also
  refills all charges at once. The spec says "+1 dash charge"; Fujin adds
  exactly one.
- **Where:** `scripts/player.gd` `on_upgrade("idaten")`.
- **Decision:** keep the refill as a small treat (then the spec says so), or
  match the spec.

### KI-021 A mutator can't come back two waves later
- **Severity:** low
- **Symptom:** the spec says a wave never repeats the previous wave's
  mutator. The code also blocks X, (no mutator), X, because it remembers
  the last mutator rolled rather than the last wave's.
- **Where:** `scripts/wave_director.gd` with `scripts/mutators.gd`.
- **Decision:** changing it changes the mutators of shared seeds, so it is
  William's call (or the spec adopts the stricter rule).

### KI-022 NEW HI-SCORE never flashes on the very first run
- **Severity:** low
- **Symptom:** with an empty top 10, the run's NEW HI-SCORE cut-in never
  plays, though the results screen still says NEW BEST.
- **Where:** `scripts/hud.gd` (`best > 0` in the cut-in check).
- **Decision:** probably deliberate (no score to beat yet); confirm.

### KI-023 The Well's cover is the same on every seed
- **Severity:** low
- **Symptom:** props and cover on The Well (vending machines, lamps, crates,
  shrines, planters) are placed the same way for every seed; only palette,
  weather, signs, skyline and puddles change. The goal doc says the seed
  decides cover.
- **Where:** `scripts/maps/world_detail.gd` (fixed-seed local RNG; the code
  says the layout is meant to stay the same).
- **Decision:** a fixed hand-made layout (as built) or seeded cover.

### KI-024 Pasted text like "2024 1225" is read as a seed
- **Severity:** low
- **Symptom:** the seed box accepts any two groups of four hex digits, so a
  pasted date fills it. The player sees the digits before pressing PLAY.
- **Where:** `scripts/ui/seed_entry.gd` loose pattern.
- **Decision:** probably fine as is (friends type seeds with spaces).

---

## Resolved

| ID | Bug | Fixed in |
|---|---|---|
| KI-100 | A wave could end while its last group of enemies was still dropping in (field empty when the last group spawned) | bug pass, 2026-10-23 |
| KI-101 | Hit freeze cut glory-kill impact frames to a single frame and made screen flashes jump ahead | bug pass, 2026-10-23 |
| KI-102 | A shockwave still rolling out could hurt you during the wave tally | bug pass, 2026-10-23 |
| KI-103 | Continuing a run after a boss fell, before its wave's break ended, paid the boss reward again | bug pass, 2026-10-23 |
| KI-104 | Alt-tab didn't pause if the window kept the mouse captured | bug pass, 2026-10-23 |
| KI-105 | Dying within five seconds of a boss kill brought combat music and the boss card back over the death screen | bug pass, 2026-10-23 |
| KI-106 | A suspended run came back with combo 0 | bug pass, 2026-10-23 |
| KI-107 | After a storm's first lightning, The Well stayed brighter for the rest of the run | bug pass, 2026-10-23 |
| KI-108 | High-score initials came out wrong on AZERTY and other non-QWERTY keyboards | bug pass, 2026-10-23 |
| KI-109 | Ledge-climbing out of an aim-assist lunge could fling you off the top | bug pass, 2026-10-23 |
| KI-110 | Enemies' path timing depended on earlier runs in the same session (same seed, different routes) | bug pass, 2026-10-23 |
| KI-111 | Cut-off grunt arms kept flashing and changing colour with the next grunt | bug pass, 2026-10-23 |
| KI-112 | A hit during a shock gave a late white flash when the shock ended | bug pass, 2026-10-23 |
| KI-113 | Tetsugumo could slide sideways in the air until he landed after a sidestep | bug pass, 2026-10-23 |
| KI-114 | The combo's screen heat stayed on over the death and results screens | bug pass, 2026-10-23 |
| KI-115 | Puddle reflections lagged a frame (engine warning about the mirror camera) | bug pass, 2026-10-23 |
| KI-116 | Enemies on The Well's service blocks came out of a wall 8 m from the freight lift drawn for them | bug pass, 2026-10-23 |
| KI-117 | A damaged save file was deleted when a good backup existed, instead of moved aside | bug pass, 2026-10-23 |
| KI-118 | Equal high scores (a replayed seed) could put your initials on the older row | bug pass, 2026-10-23 |
| KI-119 | Two debug flags looked up every frame (soda-can test, FINISH splash log); an unused wall-clock timer in Game | bug pass, 2026-10-23 |
