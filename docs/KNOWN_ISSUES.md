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

Last full bug pass: 2026-10-23 (whole game, every script); a second try at
every open entry followed the same day.

---

## Needs William (play it on the PC)

### KI-005 Frame-time costs that need a profile on real hardware
- **Severity:** low (no measured hitch yet)
- **Symptom:** none seen. The code sweep found small allocations in hot
  paths that could add up on the 2015 laptop target (spec §14). Still open:
  lightning arcs rebuilt every 0.022 s (`fx.gd`); shockwaves, telegraph
  lines and missile rings built from new meshes and materials each time
  (`fx.gd`); HUD label text re-set every frame (`hud.gd`). Already done
  (second try, 2026-10-23): pellets and bolts reuse one ray query each, HUD
  colours are only set when they change, and bolt trails stop when the blood
  droplet budget is full, so bolts can't thin out the blood.
- **Repro:** WEAK preset, any seed, wave 8+ with a gunner fan and a boss:
  watch for hitches in the F3 overlay (1% lows).
- **Next:** William runs `tools/perf_bench.sh` or plays with the overlay on
  the laptop; Claude fixes the worst ones first, measured (project rule:
  measure before optimising).

---

## Needs Claude (another attempt in a later thread)

Nothing open. (The second try on 2026-10-23 fixed every entry that was
here; see Resolved.)

---

## Needs a decision (William)

Nothing waiting. (William decided KI-020 to KI-025 on 2026-10-23; see
Resolved.)

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
| KI-120 | Dev-only: SODA CANS switched on at the title never reached the run started from that title (the cans system read the switch once, when the title was built), so no can ever appeared until the game was restarted; switched on mid-run, it did nothing for that run | soda cans fix, 2026-10-24 |
| KI-001 | A slash or dash pressed during a glory kill, or on the frame a ledge climb starts, did nothing afterwards (now kept and fired the moment it ends; a jump there is still dropped, as you hop clear anyway) | bug pass second try, 2026-10-23 |
| KI-002 | Jump pressed just before landing, or dash pressed just before a charge came back, was lost (both now buffered for 0.12 s) | bug pass second try, 2026-10-23 |
| KI-003 | Enemies couldn't follow you onto the water tanks, the stairwell hut or the east edge of the billboard gantry on The Well | bug pass second try, 2026-10-23 |
| KI-004 | A puddle lay inside the south service block on The Well (puddles now skip any spot inside a solid) | bug pass second try, 2026-10-23 |
| KI-006 | Wedged in two corners of The Well: a glory kill from a ledge (or mid-jump) could end with you inside the ledge or wall below; the end spot now needs room for your body (as the plunge already did), and fall speed is capped at 50 m/s | bug pass second try, 2026-10-23 |
| KI-010 | A save file that couldn't be opened (held by an antivirus or sync tool) was treated as damaged; now it is tried again for about a second, then the session plays read-only, nothing is written over it, and the title says PROFILE FILE BUSY | bug pass second try, 2026-10-23 |
| KI-011 | A failed backup rotation could lose the old backup | bug pass second try, 2026-10-23 |
| KI-012 | A profile from a newer build kept only its first copy (now refreshed whenever it changes, from the copy actually loaded) | bug pass second try, 2026-10-23 |
| KI-013 | A profile that failed to migrate was rotated into the backup (now moved aside, never saved over) | bug pass second try, 2026-10-23 |
| KI-014 | The enemy count could go up to two over the wave's cap (spawn groups are now trimmed to the cap, as the spec says; the wave plan is unchanged, but where enemies appear inside a wave that hits the cap can differ from older builds) | bug pass second try, 2026-10-23 |
| KI-015 | The score label flashed as if points were scored on CONTINUE | bug pass second try, 2026-10-23 |
| KI-016 | The autoplay bot steered by the wall clock (now run time). Its dice stay unseeded on purpose: `seed_check.sh` plays two different bot runs to prove the wave plan doesn't depend on play | bug pass second try, 2026-10-23 |
| KI-017 | Dev-only: a resumed run took the session's SODA CANS switch, an abandoned cans run could set a best score, PALETTE showed "?" after `--palette=NAME`, KILL ALL inside a wave intro left its timers driving the next intro, a finished can's lid and fizz vanished mid-air | bug pass second try, 2026-10-23 |
| KI-018 | Latent: a button's label set after it was built was undone on disarm, the run card read a viewport that might be gone, only the first shotgun cell light was checked, a dead `heal_kill` branch in enemies, an orphan node in a boss unit test (the backdrop stream became KI-025) | bug pass second try, 2026-10-23 |
| KI-020 | Idaten Drive refills every dash charge when you take it: kept as a small treat, now written into the spec and the Level-Up Cards wiki page | William's call, 2026-10-23 |
| KI-021 | A mutator can't come back two waves later (X, none, X): kept; the spec now says "never repeats the last mutator rolled", so shared seeds don't change | William's call, 2026-10-23 |
| KI-022 | NEW HI-SCORE doesn't flash on the very first run: kept (nothing to beat yet); the spec and wiki say so, and the results screen still says NEW BEST | William's call, 2026-10-23 |
| KI-023 | The Well's cover is the same on every seed: kept, a hand-made layout tuned around the leap links, pads and spawns; the spec and the Seeds wiki page no longer say the seed moves cover | William's call, 2026-10-23 |
| KI-024 | Pasted text like "2024 1225" is read as a seed: kept loose on purpose (you see the digits before PLAY); written into the spec | William's call, 2026-10-23 |
| KI-025 | The weather was rolled from the map's stream after the whole map build, so a change to the skyline (or anything built before it) would shift seeds' weather: the weather and the backdrop towers now each have their own stream from the seed; many seeds' weather and every seed's backdrop towers changed once (0.1 Dev 3) | William's call, 2026-10-23 |
