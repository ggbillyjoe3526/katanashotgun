# Boss Roster

Living document: how every boss fights. Read it before designing a new boss
or changing an existing one, and update it in the same pull request as the
boss change. William's editable copy is the
[Boss Roster doc](https://claude.ai/code/artifact/d00249e8-dd19-4450-8fd0-d5199683a3b7);
keep the two in step.

## How to use this doc

Three bosses exist today: KUROKAGE, TETSUGUMO and SHUTEN. This page records how each one fights, so a new boss can be checked against them for uniqueness and balance before it is built.

- **Status tags:** **LIVE** = on `main` today. Everything below is LIVE; a future boss change in review is tagged with its PR number until it merges.
- **Numbers** come from the code (`scripts/enemy.gd`, `scripts/boss.gd`, `scripts/boss_kamae.gd`) and spec §5. Damage is against the player's 100 HP, at cycle 1 (first appearance). Where the code and spec disagree, it is flagged.
- **Keep it current:** any change to a boss updates its section and the comparison table in the same piece of work, with a line in the change log at the bottom.

## Rules every boss shares

Every third wave is a boss wave (3, 6, 9...), with no mutator. The first cycle sends the two lighter bosses first, in seeded order, and SHUTEN last at wave 9. Later cycles shuffle all three by seed.

| Rule | Value | Status |
| --- | --- | --- |
| Arrival | "BOSS INCOMING" alarm, then an intro card with name and epithet, own music | LIVE |
| HP scale | 1 + 0.45 × (cycle − 1) + 0.03 × (wave − 3): ×1.00 at wave 3, ×1.18 at wave 9, ×1.72 at wave 12 | LIVE |
| Damage scale | half the HP scale's increase: ×1.09 at wave 9, ×1.36 at wave 12 | LIVE |
| Reinforcements | 1–2 grunts every 7 s (TETSUGUMO 10 s) while fewer than 4 adds are alive | LIVE |
| Enrage | below 50% HP: speed ×1.2, shorter special cooldowns, a roar and "NAME IS ENRAGED" | LIVE |
| Armour | katana hits deal a reduced share until the boss is broken; MASAMUNE EDGE's heavy third cut ignores it; shotgun is never reduced | LIVE |
| Kill payout | "loud, then quiet" death: slow motion, silence, felled line card; BOSS BOUNTY 2000 × wave in the tally | LIVE |
| Rewards | each boss has an ordered list; every kill unlocks its next item (cosmetic only, never random) | LIVE |
| No glory kill | bosses never get a glory kill or poise stagger; Hyakunin-giri doesn't stagger them | LIVE |
| KAMAE posture | pressure fills a bar; full = KAMAE BROKEN, the boss reels for its stagger time + 1.5 s, F lands the ONIKIRI for 20% max HP (kills at ≤ 20%) | LIVE |
| KAMAE fill | katana poise ×1.6 (MASAMUNE EDGE's heavy cut ×1.0), shotgun ×0.6, returned bolt = its damage ×0.5, a glory kill on an add within 15 m = 12% of the bar | LIVE |
| KAMAE drain | after 2.5 s without pressure, 7% of the bar per second | LIVE |
| Sidestep | aimed at from beyond 7 m (+ radius) for 0.35 s, it steps out of the line; cooldown 4 s (6 s for the run's first boss); never up close, never mid-attack | LIVE |
| RED SIGNAL | one heavy move per boss: spinning red diamond, alarm, a beep 0.2 s before it lands, 0.9–1.0 s warning; can't be deflected or traded with. Dashing as its hit connects = PERFECT: slow motion and +15% KAMAE. Cooldown 14 s | LIVE |
| Delayed swings | 30% of melee windups hold 1.7× as long; eyes stay dim, then flare with a hiss 0.22 s before the hit | LIVE |
| Punish windows | every recovery of 0.8 s or more (Tetsugumo's summon included): armour off, eyes dim, KAMAE fills ×1.5 | LIVE |
| Pacing | first cycle (waves 3, 6, 9): area move and RED SIGNAL only once enraged; the run's first boss telegraphs them 25% longer. From wave 12: everything from the start. Area moves cooldown 8 s | LIVE |
| Seeded dice | a boss rolls from hash(run seed × 13 + wave): same seed, same fight | LIVE |

## KUROKAGE, Blade of the Null Signal

The fast duelist: a neon-piped cyber-ninja who tests your eyes and footwork, not your health bar. Lowest HP, smallest body, quickest windups. Root: kurokage, "black shadow". Felled line: **SHADOW DELETED**. Arrives at wave 3 or 6 in the first cycle (seeded), then anywhere in later shuffles.

| Stat | Value |
| --- | --- |
| HP | 2600 |
| KAMAE bar | 900, break lasts 4.1 s |
| Armour | 0.55 (katana deals 55% until broken) |
| Speed | 5.2 m/s (6.2 enraged) |
| Size | radius 0.5 m, height 2.1 m, head at 1.72 m |
| Specials | every 3.2–4.6 s (2.2–3.2 enraged), only beyond 3 m |
| Payout | 5000 points, 320 XP |

| Attack | Telegraph | Damage | Range | Cooldown | Answer |
| --- | --- | --- | --- | --- | --- |
| Dash-slash chain (2 dashes, 3 enraged) | Neon floor line 16 m long that tracks you for the first 60% of a 0.62 s windup (0.42 enraged), then locks; follow-ups windup ×0.6 | 20 + knockback per dash | dash at 30 m/s for up to 0.42 s (about 12 m) | special rotation, 1st of 3 | Step off the line after it locks; punish the 1.0 s recovery at the end |
| Shuriken fan (5, 7 enraged) | 0.75 s windup sound | 10 each | 13 m/s, 0.16 rad spread | special rotation, 3rd of 3 | Slash to deflect back (fills KAMAE), or strafe out of the fan |
| Blink | Smoke and blink sound, invisible for 0.35 s | none itself | reappears 3.2 m behind you | special rotation, 2nd of 3 | Turn on the sound; dash away or slash first |
| Blink strike | One-hit windup 0.45 s right after the blink | 16 | 3.8 m, frontal | follows blink | Dash out or interrupt with the shotgun |
| Melee combo (2 hits, 3 enraged) | Windup 0.45 s, follow-ups 0.3 s | 16 per hit | starts within 3.1 m, hits to 3.8 m, frontal | 1.2–1.8 s | Dash back or sidestep; punish the 0.7 s recovery |

- **Movement:** sprints in from beyond 7 m; inside that he circles you, switching direction every 1–2 s and drifting closer.
- **Enrage (50% HP):** a third dash and third combo hit, 7 shuriken, shorter windups and cooldowns.
- **KAMAE:** the smallest bar. His shuriken fans are the big swing: a deflected fan fills it fast. Katana pressure during combo recoveries does the rest.
- **Moveset:** afterimage sidestep (0.22 s at 18 m/s). **Smoke ring** when you are within 5 m: smoke at his feet, a 5 m full-circle cut 0.7 s later for 18; step out or jump; 0.9 s punish window. RED SIGNAL **NULL CROSS**: he vanishes, three red 18 m lines cross where you stand (60° apart), he reappears at the first and dashes along each in turn (34 m/s, 26 each, 0.25 s between); 1.2 s punish window.
- **Rewards:** KAGEROU EDGE (katana), then KITSUNEBI COIL (shotgun).
- **What makes him different:** the only boss that relocates instantly and attacks from behind. Many small hits, all about reading lines and sounds. The lightest punishment for a mistake.

## TETSUGUMO, Chrome Broodmother

The zone controller: a six-legged spider mech that keeps its distance and fills the arena with bullets, missile rings and her own brood. Biggest body, slowest mover, least armour. Root: tetsu (iron) + kumo (spider), after the tsuchigumo earth-spiders of legend. Felled line: **MACHINE DECOMMISSIONED**. Arrives at wave 3 or 6 in the first cycle (seeded).

| Stat | Value |
| --- | --- |
| HP | 4400 |
| KAMAE bar | 1400, break lasts 4.7 s |
| Armour | 0.35 (katana deals 35% until broken: the heaviest reduction) |
| Speed | 2.6 m/s (3.1 enraged) |
| Size | radius 1.7 m, height 3.6 m, core at 2.5 m, mass 14 |
| Specials | every 4.2–5.6 s (3.0–4.2 enraged), at any range |
| Payout | 7000 points, 420 XP; explodes on death |

| Attack | Telegraph | Damage | Range | Cooldown | Answer |
| --- | --- | --- | --- | --- | --- |
| Sweeping gatling | 0.9 s spin-up, barrel glows brighter | 7 per bolt, 25 bolts over 2 s | 14 m/s, sweeps from one side of you to the other | special rotation, 2nd and 4th of 4 | Deflect the stream (each return fills KAMAE) or run against the sweep; punish the 1.0 s recovery |
| Missile strike (7 rings, 9 enraged) | Beep, pods glow for 0.7 s, then red floor rings; the first lands on you, the rest 2.5–8 m around | 20 per missile | 2.6 m rings, landing 1.5 s after, staggered 0.09 s apart | special rotation, 1st of 4 | Keep moving out of the rings; close in during the 0.9 s recovery |
| Call the brood | Roar | none itself | 3 adds (2 grunts, 1 gunner) 4–7 m from her | special rotation, 3rd of 4; becomes a gatling if more than 6 enemies are alive | Glory-kill the adds near her (each fills 12% of her KAMAE) |
| Stomp | Chassis rises over 0.8 s | 22 | shockwave ring to 12 m at 13 m/s | within 6 m, every 2.5–3.5 s | Jump the ring; punish the 1.0 s recovery |

- **Movement:** holds 8–15 m. Walks in from beyond 15 m, backs off at 70% speed inside 8 m, otherwise strafes at 60% speed, switching every 2–3.5 s. Her reinforcements come every 10 s instead of 7.
- **Enrage (50% HP):** 9 missiles instead of 7, shorter special cooldowns, slightly faster. The gatling and stomp are unchanged.
- **KAMAE:** mid-sized bar. The intended fill is turning her own fire against her: returned gatling bolts and glory kills on her brood. Katana pressure means staying under her stomp.
- **Moveset:** **back-leap** (jumps away, lands with a 7 m shockwave for 12). **EMP field** at any range: three 2.6 m zones (on you and either side) crackle 1.2 s, then stay live 1.8 s, 12 every 0.6 s; jumping clears them. Delayed stomps. RED SIGNAL **BROOD BARRAGE**: a 7.5 m ring of 10 missiles, a 4.5 m ring of 6 and one in the middle (1.2 / 1.6 / 2.0 s, 20 each); both rings share one gap, the way out, opening towards the arena's middle; 1.2 s punish window.
- **Rewards:** KANAYAGO EDGE (katana), then AKAGANE COIL (shotgun).
- **What makes her different:** the only boss that runs away from you and fights through other enemies. Damage comes from the arena (rings, waves, bullet streams), not from contact.

## SHUTEN, the Overclocked Daemon

The heavyweight: a chrome oni that walks you down and hits like a truck. Most HP, biggest single hits, the first-cycle finale at wave 9. Root: Shuten-doji, the oni king of Mount Oe, slain by Minamoto no Raiko with the blade Dojigiri, the namesake of the player's katana. Felled line: **DAEMON PURGED**.

| Stat | Value |
| --- | --- |
| HP | 5200 (6136 at wave 9) |
| KAMAE bar | 1600, break lasts 4.5 s |
| Armour | 0.5 (katana deals 50% until broken) |
| Speed | 4.4 m/s (5.6 enraged) |
| Size | radius 1.05 m, height 3.4 m, head at 2.8 m, mass 9 |
| Specials | every 5–7 s (3.5–5 enraged), only beyond 5 m |
| Payout | 8000 points, 500 XP |

| Attack | Telegraph | Damage | Range | Cooldown | Answer |
| --- | --- | --- | --- | --- | --- |
| Melee combo (2 hits) | Windup 0.7 s, follow-up 0.45 s | 32 per hit + big knockback | starts within 4.45 m, hits to 5.65 m, frontal | 1.3–2.0 s | Dash back out of reach; punish the 0.7 s recovery |
| Leap slam | Roar, leaps toward you (up to 14 m) | 26 | shockwave ring to 24 m at 15 m/s | special rotation, 1st and 3rd (calm) | Jump the ring (hint: "JUMP OVER THE SHOCKWAVE"); punish the 1.0 s recovery |
| Charge | Roar, 0.8 s windup | 30 + heavy knockback | straight line at 15.5 m/s for up to 1.15 s | special rotation, 2nd | Dash sideways; a wall hit shakes the screen; punish the 1.4 s recovery |
| Fan volley (enraged only) | 0.75 s windup | 14 per bolt, 9 bolts | 11 m/s, 0.13 rad spread | special rotation, 3rd (enraged) | Deflect back or strafe out |

- **Movement:** always walks straight at you. No strafing, no retreat.
- **Enrage (50% HP):** speed jumps to 5.6, the fan volley replaces every third leap, shorter special cooldowns. His eyes turn red.
- **KAMAE:** the largest bar. Meant to be filled up close in the recovery windows after his slam and charge, where his reach can't punish you.
- **Moveset:** **shoulder barge** sideways (0.3 s at 14 m/s). **Fissures** within 14 m: five 14 m fire lines crack out in a star from his fist after 0.8 s, 24 each; jump them or stand between. RED SIGNAL **DAEMON GRAB** (from 9.5 m or closer): aims through 70% of a 1.0 s windup, then a 0.45 s lunge at 17 m/s that grabs and hurls for 34; dash through it. A whiffed grab leaves him open 1.8 s.
- **Rewards:** ONIBI EDGE (katana), then RAIKO COIL (shotgun).
- **What makes him different:** the only boss whose single hit takes a third of your health. Few attacks, long windups, huge consequences: a test of patience and punishing.
- **Spec mismatch:** spec §5.2 says a 2–3 hit combo; the code always swings twice.

## Side by side

Each boss owns a different distance and a different answer: KUROKAGE is about reading, TETSUGUMO about movement, SHUTEN about patience. A new boss should claim a row of its own here.

|  | KUROKAGE | TETSUGUMO | SHUTEN |
| --- | --- | --- | --- |
| Role | Fast duelist | Zone controller | Heavyweight bruiser |
| Distance it wants | Mid, circling | Far (8–15 m) | Point blank |
| HP | 2600 | 4400 | 5200 |
| KAMAE bar | 900 | 1400 | 1600 |
| Armour (katana share) | 55% | 35% | 50% |
| Speed (m/s) | 5.2 | 2.6 | 4.4 |
| Biggest single hit | 20 (dash) | 22 (stomp) | 32 (melee) |
| Main threat | Locked dash lines, blink behind you | Bullet streams, missile rings, adds | Heavy combo, leap shockwave, charge |
| Jump answers | none | Stomp ring | Leap slam ring |
| Dash answers | Dash lines, blink strike | Missile rings | Combo, charge |
| Deflect answers (fills KAMAE) | Shuriken fan | Gatling | Fan volley (enraged) |
| Calls adds | no | yes, 3 at a time | no |
| Reinforcement timer | 7 s | 10 s | 7 s |
| Enrage adds | 3rd dash, 3rd hit, wider fan | more missiles | speed 5.6, fan volley |
| Best KAMAE source | Deflected shuriken fans | Returned gatling, brood glory kills | Katana in punish windows |
| Dodge | Afterimage sidestep | Back-leap | Shoulder barge |
| Area move | Smoke ring | EMP field | Fissures |
| RED SIGNAL | NULL CROSS | BROOD BARRAGE | DAEMON GRAB |
| Rewards | KAGEROU EDGE, KITSUNEBI COIL | KANAYAGO EDGE, AKAGANE COIL | ONIBI EDGE, RAIKO COIL |

## Checklist for a new boss

A new boss is ready to build when every line below holds. Copy the list into the boss's own section and tick it there.

**Unique**

- [ ] It wants a distance or fighting style no current boss owns (see Side by side).
- [ ] Its main threat is answered by a different mix of dash, jump and deflect than the others.
- [ ] It has one signature move a player would describe to a friend.
- [ ] Its silhouette reads at a glance against the others, even at 960x540.

**Readable and fair**

- [ ] Every attack has a telegraph you can see or hear: floor mark, glow, pose or sound.
- [ ] No hit lands without a windup of at least 0.3 s; area attacks warn for 0.7 s or more.
- [ ] Every big move ends in a recovery of 0.7 s or more that can be punished.
- [ ] Nothing is unavoidable, and no single hit takes more than about a third of the player's 100 HP.
- [ ] Losing to it feels like being overwhelmed, never cheated.

**Balanced**

- [ ] HP sits inside the current range (2600–5200), justified by its role.
- [ ] Its KAMAE bar scales with how hard it is to pressure (900–1600 today).
- [ ] At least one attack can be deflected or turned against it, so KAMAE has an aggressive route.
- [ ] If it can be the first boss (wave 3), a newcomer can beat it; the hardest moves wait for 50% HP.
- [ ] Enrage at 50% adds pressure, not a new wall.
- [ ] All its randomness comes from the run's seeded dice, so a seed replays the same fight.

**Named and owned**

- [ ] Name follows spec §5.4: a Japanese myth or history root with a cyberpunk epithet, macrons dropped.
- [ ] A felled line in the form NOUN PAST-PARTICIPLE (SHADOW DELETED).
- [ ] Nothing borrowed from FromSoftware or any other IP, and no real tragedies.
- [ ] Name and root added to the spec's naming table (§13).

**Wired in**

- [ ] Rewards list in `scripts/rewards.gd` (cosmetic only).
- [ ] Own boss music track and intro card.
- [ ] This doc updated: its section, the Side by side table and the change log.

## Open questions

- SHUTEN's combo: should it be 2 hits (the code) or 2–3 (the spec)?
- Boss variants (spec §5.4, such as "Kurokage, Ghost Build") and new bosses from the name pool wait until you ask for them.

## Change log

| Date | Change |
| --- | --- |
| 2026-10-18 | Created from `main`, the KAMAE posture PR (#17) and the tougher moveset plan. |
| 2026-10-18 | KAMAE posture and the ONIKIRI are LIVE (PR #17): boss glory kills and the 15% DEATHBLOW are gone. |
| 2026-10-18 | Movesets built (PR #19): sidesteps, delayed swings, punish windows, an area move and a RED SIGNAL per boss, seeded boss dice. |
| 2026-10-18 | KAMAE (#17) and the movesets (#19) merged: every row is LIVE. |
