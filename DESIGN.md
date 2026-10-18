# KATANA / SHOTGUN — Design Doc (v0.3, prototype)

> An arcade, first-person cyberpunk horde shooter. Doom (2016) brutality and
> glory kills, Diablo-style "numbers go up", Balatro-style payoffs, and a
> score chase. Every run is seeded and unique; the goal is to get further and
> score higher. **The vibe: pure adrenaline, a constant dopamine hit, deeply
> satisfying and visually overwhelming.**

This is a prototype and concept-development build. The final game is a full
desktop game made in Godot, not a browser game.

## The pitch in one line
A chrome-armed ronin with the DŌJIGIRI thermal katana in one hand and the RAIJIN-12
arc shotgun (a "shotgun taser") in the other, carving through endless gangs on
the neon rooftops of **Shin-Kagura**. **The blade charges the gun; the gun sets
up the blade.**

## Pillars
1. **Simple, rewarding, endlessly replayable.** Few mechanics, all of them
   deep. Avoid scope creep: no new systems unless they serve the core loop.
2. **Easy to play, rewarding to master.** It should always be easy and fun.
   It has the feel of a skill shooter (quick reactions, crisp hit feedback,
   aim that matters) but it is not competitive or esports-hard. Skill and
   experience pay off in score and spectacle, not in being allowed to play.
3. **Every kill is a show.** Hitstop, glory kills, dismemberment, blood
   geysers, big numbers, impact frames, screen shake.
4. **Arcade score chase.** Endless waves, combo multiplier, wave mutators that
   trade risk for score, flawless bonuses, a local top-10 with initials.
5. **Seeded runs.** The seed decides map layout, palette, weather, wave
   line-ups, mutators, boss order and augment offers. Share a seed, race a friend.
6. **Presentation first.** Visuals, audio, UI and game feel are where the
   effort goes: synthwave neon world, retro PS1/PS2 rendering, cyberpunk UI.

## Influences (what to take from each)
| Source | Take | Don't take |
|---|---|---|
| Doom (2016) | Speed, brutality, glory kills, "push forward" combat | Its pace exactly (ours is a bit calmer) |
| Diablo 3/4 | Hordes, levelling, simple builds, numbers going up | Grinding, complex builds, loot |
| Counter-Strike / Valorant | Crisp hit feedback, headshots matter, quick reactions | Competitive difficulty |
| Sekiro / Bloodborne | Over-the-top killshots and gore, deathblows | Punishing difficulty |
| FromSoftware | The slow, solemn "boss felled" / "you died" card | Its fonts and wording |
| Balatro | Payoffs that build suspense, count-ups, chips x mult | Its look |
| Persona 5 | The energy: cut-ins, all-out finish, kinetic UI | Its look (no ransom notes, no red/black shards) |
| Cyberpunk 2077 | Swords in a neon cyberpunk city | — |

## Core loop
**Hands (final):** the **katana is in the LEFT hand (LMB)** and the **shotgun
in the RIGHT hand (RMB)**, so each mouse button matches its hand. This is how
the prototype already works.

| Verb | Input | What it does |
|---|---|---|
| Slash | LMB | 3-hit katana combo, cleaves. **Katana kills charge the shotgun (+1 cell)** |
| Blast | RMB | Arc shotgun: hitscan "pellets" drawn as lightning, headshots x2, **staggers** |
| Glory kill | F near a staggered enemy | First-person finisher (see below): heals 20, +3 cells. On bosses: a 15% deathblow |
| Deflect | Slash an incoming bolt | Sends it back as a lethal, staggering shot |
| Dash | Shift | 2 charges, invulnerable while dashing |
| Jump | Space (x2) | Double jump, jump pads |

### The arc shotgun (RAIJIN-12)
- A futuristic "shotgun taser". Gameplay is exactly a shotgun: a spread of
  hitscan pellets, damage falloff, stagger, knockback and shotgun gore.
- Presentation: each pellet is a jagged, forking lightning arc. Wall hits
  spark blue. Enemies hit flicker blue with small arcs crawling over them.
  Kills come with blue sparks, smoke and a last arc.
- The model has three electrode prongs, glowing capacitor coils around an
  open barrel core, and a drum of six power cells that turns one cell per
  blast. The coils flare on a shot, sit dim while recharging, then hum.
  With no charge left they sputter. Idle arcs crackle between the prongs.
- Ammo is **cells** (shown as little power cells). Katana kills charge them.
  Below 2 cells, they slowly recharge on their own.
- Sound: an electric crack with a crackling discharge, a buzz and a deep
  thump; a capacitor whine climbing into a clack as the drum turns; a fizzle
  when empty.

### Glory kills (Doom 2016 style)
- Press F when a staggered enemy is in reach (a gold "F GLORY KILL" prompt
  shows under the crosshair and that enemy's marker turns gold). The camera
  locks on, you lunge in, and a short
  contextual finisher (about 0.7–0.95 s) plays while you are invulnerable.
  The world runs in slow motion; the finisher runs in real time.
- The finisher depends on the situation:
  - **Front A:** run it through with the katana, then the shotgun under the chin (the head pops).
  - **Front B:** take the head off with a slash, then blast the chest.
  - **From behind:** stab through the back, then rip the blade up (it splits in two).
  - **From the air:** falling overhead cut (split in two).
  - **Brute:** climb up, chop the skull, blast down into the neck.
  - **Boss:** an X-cut, then a point-blank blast. It takes 15%, unless that is the killing blow.
- Presentation: cinematic bars, data streaks, impact frames on each hit,
  hitstop, a hop back out of the gore when it ends.

## Run structure (arcade)
- **Difficulty rises the further the player gets.** Every wave is harder than
  the last: more enemies, tougher compositions, more health and damage, more
  aggressive mutators, tougher bosses each cycle. The opening waves of every
  run stay easy and welcoming (low floor); going deep is where skill shows
  (high ceiling). Content earned from boss rewards (new maps, boss variants,
  mutators) can bring tougher challenges too. The persistent Player Level
  never changes difficulty. (Partly built: waves scale now; the full curve is
  still to be designed.)
- Waves never end. **Every 3rd wave is a boss**, with reinforcements.
  - **Kurokage, Blade of the Null Signal** (the ninja): telegraphed
    dash-slash chains, deflectable shuriken fans, blinking behind you.
    Felled line: **SHADOW DELETED**.
  - **Tetsugumo, Chrome Broodmother** (the spider mech): a six-legged mech
    with a sweeping gatling, missile strikes marked by red rings, stomps, and
    calls for her brood (reinforcements). Felled line: **MACHINE DECOMMISSIONED**.
  - **Shuten, the Overclocked Daemon** (the oni): combos, charges, jumpable
    shockwaves, bolt fans. Felled line: **DAEMON PURGED**.
  - First cycle: the two lighter bosses in seeded order, then Shuten. Later
    cycles are shuffled, and each cycle is tougher.

### Boss names (FromSoftware-style, cyberpunk theme)
Every boss gets its own unique name, the way FromSoftware names bosses, but
themed for cyberpunk. Never reuse FromSoftware names; they are only a
reference for the grammar. The patterns:
- **Name, the Epithet:** "Shuten, the Overclocked Daemon".
- **Name, Title of Something:** "Kurokage, Blade of the Null Signal".
- **Name, Title:** "Tetsugumo, Chrome Broodmother".
- **Title + Name:** "Overseer Halvard", "Netrunner Vex".
- **A descriptive name for a thing or group:** "Gridlock Sentries", "the Static Choir".
- **Ominous and abstract:** "The Signal That Hungers", "Mother Server".

Cyberpunk vocabulary to draw on: chrome, neon, static, signal, null, ghost,
daemon, kernel, root, firmware, cipher, wetware, overclocked, synthetic,
augment, syndicate, grid, ICE, deadlink, mirrorcode. Mixed with the Japanese
flavour of Shin-Kagura: shogun, ronin, oni, kage, daimyo.

**Variants** (boss rewards) keep the name and change the epithet or add a
state, like FromSoftware's two-phase or "inner" versions:
"Kurokage, Ghost Build", "Tetsugumo, Queen of the Scrapyard",
"Shuten, Unbound". Each gets its own felled line.

**Name pool for future bosses** (ideas, all original):
- The Firmware Pontiff
- Overseer Halvard, Warden of the Grid
- Netrunner Vex, the ICE Breaker
- Gridlock Sentries
- Sister Nyx, Mother of Clones
- The Last Executive
- Mirrorcode, the Copied Self (fights with your own moves)
- Okaasan, Matriarch of the Syndicate
- Raiko, the Voltage Maiden
- The Signal That Hungers
- Iron Shogun Daimyo-X
- Deadlink Hydra
- The Static Choir
- Ghostwire Ronin
- Mother Server
- Baron Kessler, Augment Collector
- Carbon Saint Ilse
- Kernel Wraith of the Undercity
- **Mutators** (seeded, about 2 in 3 regular waves): Idaten's Haste, Muramasa's
  Curse, Akatsuki, Yomi Blackout, Hyakki Yakō, Teppō Volley, Kanabō Vanguard,
  Raijin's Storm, Jorōgumo's Bite. Each shows its score multiplier.
- **Scoring:** kill points x combo (up to x5) x mutator during the wave, then
  the **end-of-wave tally**:
  - Chips: wave clear 250 x wave, kills x25, glory kills x200, headshots x75,
    deflects x100, boss bounty 2000 x wave.
  - Mult: (1 + 0.1 x wave), then x1.5 for a flawless wave, then x the mutator.
  - Payout = chips x mult.
- **High scores:** local top 10 with 3-letter initials, plus wave and seed.
  After a run, **R** retries the same seed and a click starts a new one.


## Naming bible: Japanese history and myth, in chrome
**Every name in the game** draws on Japanese history and mythology, not just
bosses: maps, weapons, enemies, mutators, augments, items and rewards. The
formula is *a Japanese mythic or historical root + a cyberpunk twist*. Keep
names readable: usually one Japanese word per name, paired with an English
epithet or description. The meaning is explained in a short codex line (a
later feature) so players learn the myth behind each name.

Sources to draw from:
- **Kami and Shinto:** Amaterasu, Susanoo, Tsukuyomi, Raijin and Fūjin,
  Izanagi and Izanami, Hachiman (war), Idaten (speed), kagura (sacred dance),
  torii, shimenawa, Takamagahara (the High Plain of Heaven), Yomi (the land
  of the dead).
- **Yōkai and folklore:** oni, tengu, kappa, tsuchigumo (earth spiders),
  jorōgumo, nue, gashadokuro, yūrei, onryō, kitsune, tanuki, tsukumogami,
  Yamata no Orochi, the Dragon Palace (Ryūgū-jō) of Urashima Tarō.
- **History and legend:** the Sengoku period, daimyō and shōguns, rōnin,
  shinobi, the 47 rōnin, Minamoto no Raikō and his four guardians,
  Yoshitsune and the tengu of Mount Kurama, the Tōkaidō road, legendary
  swordsmiths (Masamune, Muramasa) and named blades.
- Avoid real tragedies and wartime references (no kamikaze), and anything
  that is someone else's well-known IP name.

Names already in the game, and their roots:
| Name | Root |
|---|---|
| Shin-Kagura (the city) | *Kagura*, the sacred Shinto dance for the kami: "New Kagura" |
| Kurokage | "black shadow", the shinobi |
| Tetsugumo | "iron spider", a play on the *tsuchigumo* earth-spider yōkai (and the clans the old court called by that name) |
| Shuten | *Shuten-dōji*, the oni king of Mount Ōe slain by Minamoto no Raikō |
| RAIJIN-12 (arc shotgun) | *Raijin*, the god of thunder and lightning |

Adopted names (in the game since v0.3; in-game text drops the macrons, e.g. DOJIGIRI, HYAKKI YAKO):
- **The katana:** *DŌJIGIRI*, after Dōjigiri Yasutsuna, the blade said to
  have killed Shuten-dōji. A thermal blade, and a story link to the
  Shuten boss.
- **Maps** (names reserved for the future maps):
  - **Tōkaidō Expressway:** the horizontal corridor map, named after the old Edo–Kyoto highway.
  - **Takamagahara Spire:** the vertical megastructure, a climb to "heaven".
  - **Ryūgū Arcade:** the mall/arcade interior, after the Dragon Palace.
  - **Kurama Dojo:** the dojo in the rain, after the tengu mountain.
- **Enemies:** grunts *Ashigaru* (foot soldiers), gunners *Teppō* (the
  matchlock corps), brutes *Kanabō* (after the oni's iron club).
- **Mutators** (keep the plain-English description underneath):
  - Overdrive → **IDATEN'S HASTE**
  - Glass Cannon → **MURAMASA'S CURSE**
  - Blood Moon → **AKATSUKI** (the red dawn)
  - Brownout → **YOMI BLACKOUT**
  - Swarm → **HYAKKI YAKŌ** (the night parade of a hundred demons)
  - Sniper Nest → **TEPPŌ VOLLEY**
  - Ironclad → **KANABŌ VANGUARD**
  - Neon Storm → **RAIJIN'S STORM**
  - Vampire → **JORŌGUMO'S BITE**
- **Augments:** Monoblade → **Masamune Edge**, Crimson Wave → **Susanoo's
  Wave**, Phantom Cut → **Kage Step**, Chain Glory → **Hyakunin-giri** (a
  hundred-man cut), Overclocked Legs → **Idaten Drive**, Chrome Heart →
  **Kongō Heart** (vajra, unbreakable), Forked Lightning → **Raijin's Fork**,
  Capacitor Bank → **Fūjin Bank**, Plasma Burn → **Kagutsuchi Flame** (the
  fire kami). Keep the rest unless a better myth fits.
- **Variants and future bosses** should follow the same rule. Example:
  "Orochi Protocol, the Eight-Headed Network"; "Jorōgumo, Silk-Server
  Matriarch"; "Gashadokuro, the Scrapyard Colossus"; "Nue, Chimera of the
  Grid"; "Tamamo, Nine-Tailed Phantom of the Wire".
## Progression & saving (CRITICAL, not built yet)
The high score is not the only thing the player is chasing. A persistent
**Player Level** keeps rising across runs, and the game must save so progress
is never lost.

### Player Level (persistent)
- Every run pays XP into the profile when it ends (score, waves reached,
  bosses felled, glory kills and so on). That XP raises the Player Level.
- The player must **see** it rise. After each run the results screen counts
  XP into the level bar (a Balatro-style roll-up), and every level gained gets
  a celebration (a holographic cut-in, a stamp, a sound). The level shows on
  the title screen and the run summary.
- Simple and never grindy: a steady pace, with the first few levels landing fast.
- It is separate from the in-run level (LV, which unlocks augments and resets
  every run). Label them clearly, for example "PLAYER LV 23" vs "RUN LV 7".
- **Levels unlock nothing.** They exist purely to show progression.

### Boss rewards (the only unlocks)
- Felling a boss can earn a **reward**. Rewards are the only thing that
  unlocks anything, and they add no new mechanics or features.
- The pool: cosmetics, new maps, palettes, weapon and katana skins, mutators,
  boss variants. No stat boosts, so seeded high scores stay comparable.
- Show it right after the boss tally (a cut-in and an item card) and save it
  to the profile at once. Unlocked maps, palettes and mutators join the seeded
  pools; skins and cosmetics are picked from a simple menu.

### Saving
- **Profile save:** Player Level, XP, unlocks, high scores, settings, lifetime
  stats. Saved automatically at the end of every run, on unlock, when
  settings change and on quit.
- **Run save (suspend and resume):** quitting mid-run or the game closing must
  not lose the run. Snapshot between waves (seed, wave, score, combo, run
  level, augments, HP, cells, RNG states). On launch, offer CONTINUE RUN.
  Delete the snapshot when the run ends, so a death can't be undone.
- **Robustness:** versioned format with migrations, atomic writes (temp file
  then rename), one backup, never wipe a profile when loading fails.
- Saves live in `user://` (its own folder, `KatanaShotgun`); later Steam Cloud.

## Look & feel
- **World:** retro PS1/PS2. A 960x540 internal resolution, subtle vertex
  wobble, affine texture warp, per-vertex lighting, light Bayer dither, VHS
  chromatic fringe and scanlines. Synthwave neon: five seeded palettes (Sunset
  Drive, Miami Nights, Ultraviolet, Blood Chrome, Toxic Tokyo) colour the sky,
  striped sun, mountains, neon, floor grid, fog and windows. Seeded weather;
  the Neon Storm mutator adds lightning.
- **Colour direction (feedback, to fix later):** the current palettes lean
  too heavily toward purple. The game must be vibrant, neon and bold, with
  **multiple strong colours on screen at all times** (cyan, magenta, hot
  pink, electric blue, acid green, amber, orange-red and so on), never a
  single-hue wash. Every scene needs contrasting accents: signs, neon tubes,
  UI, effects and the sky should not all share one hue. Purple can be one
  colour among many, not the base of everything.
- **Palette unlocks:** palettes earned from boss rewards could be *tints* on
  top of the multi-colour base (a warm sunset tint, a toxic green tint, a
  cold chrome tint), so every palette stays colourful rather than becoming
  one colour.
- **UI: cyberpunk, drawn pixel-retro.** All UI/UX and text are cyberpunk style
  and use our own visual language, not Persona 5's:
  - Faces: Orbitron 900 (display, big numbers), Chakra Petch (labels),
    Share Tech Mono (data, seeds, rolling numbers), Michroma (the big cards).
    They are rendered at the UI's low internal resolution (480x270) with no
    antialiasing and nearest upscaling, so they look pixelated like the 3D
    world.
  - Tech panels: dark glass with chamfered corners, thin neon outlines,
    corner brackets, scanlines and small data tags ("> SYS.EVENT").
  - Glitch text: heavy letters that decode out of random characters, with an
    RGB split, jitter and screen-tear slices, only on the way in and out.
- **Readability rule (feedback, CRITICAL):** the UI must follow the aesthetic
  *and* be readable. The current text effects are too messy. Anything that
  flashes on screen must be **instantly readable**; the player should never
  feel they missed something. Rules:
  - Glitch effects only on the way in and out. Text must be clean and still
    while it is held: no scrambling, jitter or tears during the hold.
  - Decode-in at most about 0.1 s, and never on numbers that matter (score,
    payouts, HP, cells, combo, wave). Numbers stay crisp and stable.
  - The RGB split is a subtle accent, not a double image. No overlapping
    copies that blur the letters.
  - Minimum sizes: nothing important below the readable pixel size at
    480x270. Small data text (tags like "> SYS.EVENT") is decoration only
    and must never carry information the player needs.
  - High contrast: a clean outline or dark plate behind every word, and
    no busy patterns (hex grids, scanlines, data columns) directly behind
    text.
  - One message per screen area at a time. New messages replace old ones
    instead of stacking, and messages never overlap each other.
  - Hold long enough to read (roughly 0.5 s plus 0.05 s per character for
    important messages), in fixed, predictable places.
  - Keep wording short: one to three words for flashes.
- **Game feel ("juice"):** it should be visually overwhelming, but the
  information inside it stays readable (see the rule above).
  - Wave intro: a tech panel snaps open, WAVE 04 decodes in, the mutator types
    itself out on two lines (name and score, then what it does), then a 3-2-1
    countdown and a FIGHT slam below the panel with data streaks and an
    impact frame.
  - Kills: neon pixel fragments and a target-lock ring burst from the body;
    a pitch-rising tick per kill; the combo label pops and heats up.
  - Combo milestones (x10, x20, x30, x50, x75, x100...): a glitch stamp. From
    x20 up, a holographic cut-in: a comm-feed window with a neon wireframe
    of the protagonist's visored mask, a scan bar and data text.
  - Combo heat: the screen heats up as the combo climbs (more fringe and
    saturation, halftone pixels creeping in from the edges).
  - End-of-wave tally (Balatro-style): rows deal in, chips and mult boxes
    count up, multipliers punch in, the total counts up faster and faster,
    then cashes out with a slam, confetti and a score roll-up.
  - Boss killed: loud, then quiet. First a "system breach" FINISH splash (red
    overlay, hex grid, scrolling warning chevrons, hex data, tears). Then a
    hard cut to silence and slow motion while the souls-style line fades in:
    a dark band, one line of letter-spaced text decoding out of glitch noise,
    a slow zoom and a long fade. The tally follows, with fireworks.
  - Death: the same card reads **FLATLINED** in red over a heart-monitor
    flatline, then the stats count up line by line and the score rolls up
    and slams.
  - Level-up: cards deal in with a spin, sway, tilt toward the cursor, and the
    pick punches while the others drop away.
  - Title: KATANA and SHOTGUN fly in, and a neon blade cuts the "/" between them.

## Audio
- Six procedurally composed combat tracks (own key, tempo, progression,
  groove, lead and melodies, arranged in sections), shuffled per run and
  crossfaded. One theme per boss, plus a title theme. The music cuts to
  silence when a boss dies and when you die.
- **Mix priority (feedback, to fix):** **music is the focus**, then combat
  SFX, then ambience. Ambience (rain, wind, city hum, neon buzz) is fine
  but must sit far back in the mix and never become a constant hiss. The
  prototype's rain loop reads as an annoying "white noise" bed: it is too
  loud, too broadband and too constant. Fix: much lower rain (around
  -24 dB or quieter, ducked under music), filtered so it isn't full-band
  hiss, built from varied droplet/patter layers instead of flat noise, and
  allowed to come and go. Heavy rain should be felt, not heard over the
  music. Same for any other ambient bed, and for noise built into the
  generated music and SFX.

### Soundtrack quality bar (requirement for the real game)
- The procedural tracks are **placeholders** for prototyping only. They test
  pacing, crossfades and the music director. They are not the soundtrack.
- The final music must be high production quality and professional: top
  tier, never basic, boring or low effort. It is a headline feature, the way
  Doom (2016) and Persona 5 treat theirs.
- Properly composed, arranged, mixed and mastered tracks by a
  composer/producer, or licensed. Layered synths, live or high-end sampled
  instruments where they fit, punchy professional drums, dynamic range that
  holds up on headphones and speakers.
- Style target: high-energy synthwave/darksynth fused with heavy, aggressive
  elements for combat; distinct boss themes; a memorable title theme.
- Must work with the systems in place: stems or intensity layers so it can
  react (boss phases, combo heat, the hush after a boss dies), loop points for
  boss and title tracks, and enough combat tracks that runs never repeat.
- Sound effects get the same bar: the generated SFX are stand-ins.

## Maps
- One map for now (Shin-Kagura Rooftop). Maps extend `Arena` and register in
  `MapRegistry`; the seed picks one.
- Future ideas (not now):
  - **Horizontal / corridor:** a long, open, procedurally generated stretch
    (an elevated highway, a market street) that feels like charging down a
    corridor but stays open.
  - **Vertical / megastructure:** start at the bottom of a cyberpunk
    skyscraper and fight floor by floor to the top.
  - Also: a highway overpass, an arcade/mall interior, a dojo in the rain.

## Tech
- Godot 4.7, Compatibility renderer (OpenGL 3.3 / GLES3), chosen because it
  runs on the widest range of old and weak hardware. Mobile or Forward+ are
  options only if profiling shows a clear win without dropping low-end
  support. It exports to Windows, Mac and Linux.
- Procedural textures, meshes, SFX and music: `tools/gen_audio.py` and
  `tools/gen_music.py` regenerate the audio.

## Performance (REQUIREMENT)
The game must be incredibly well optimised and smooth, in the way
Counter-Strike, League of Legends and Valorant run well even on old, weak
hardware. That is **not** a compromise on visual quality: the game isn't
realistic, and its art direction (neon, retro PS1/PS2, cyberpunk UI, juice)
carries the look. Cheap to render, expensive-looking on screen.

Targets:
- **Low-end** (e.g. a 2015-era laptop with integrated graphics): a locked
  60 fps at the default internal resolution.
- **Mid-range:** 144+ fps. **High-end:** 240+ fps, uncapped.
- Steady frame pacing with **no hitches**: no stutter from shader
  compilation, loading or garbage spikes during combat. 1% lows matter more
  than averages.
- **Low input latency:** the mouse feels instant. Offer uncapped / VSync /
  frame-cap options and a low-latency mode.
- Fast boot and fast load (seconds), a small install, low RAM use.

How (guidelines for the build):
- The retro look helps: a low internal 3D resolution (960x540, with a
  render-scale option), small nearest-filtered textures, simple shaders,
  per-vertex lighting, no real-time shadows by default.
- Keep draw calls low: MultiMesh for repeated things (skyline, gore
  droplets and decals are already MultiMesh), merged static level geometry,
  shared materials.
- **No per-frame allocation in combat:** pool enemies, bolts, effects, damage
  numbers, arcs and UI stamps instead of creating and freeing nodes (the
  prototype still creates some on the fly; fix this).
- Hard caps on everything that can pile up (particles, decals, gibs, arcs,
  sparks) with oldest-first recycling. Scale the caps by quality preset.
- Warm up and precompile every shader/material at load (Godot's
  ubershaders/pipeline caches), so the first explosion never hitches.
- Fixed physics tick with simple collision shapes. Keep AI cheap
  (time-sliced updates for far enemies).
- Move hot loops (gore simulation, many-enemy AI) to typed GDScript, C# or
  GDExtension if profiling says so.
- Quality presets (Low/Medium/High) that cut effect counts and render scale,
  never the art style. Even Low still looks like the game.
- Profile on real low-end hardware throughout development, with a frame-time
  budget per system and an on-screen perf overlay (fps, frame time, draw
  calls) in debug builds.

## Weapon looks (notes for future reference)
- **Katana:** it will look like the **Thermal Katana from Cyberpunk 2077**: a
  heated blade whose edge glows red-hot orange. Use it as the visual
  reference, but make our own design rather than a copy. The current katana
  (cyan glowing edge) is a placeholder.
- **Shotgun:** the look is undecided. The current RAIJIN-12 arc shotgun
  model (prongs, coils, cell drum) is a placeholder that shows the
  "shotgun taser" idea.

## Art assets (note for later)
- Everything is built in code from primitive meshes for now. That is enough
  for the prototype; no models should be made yet.
- If custom 3D models would clearly improve things later, the developer can
  model them in Blender. They should stay low-detail (low poly, small
  textures) because the game is low-res by design.
- Pipeline when that happens: export glTF (.glb) from Blender, import into
  Godot, apply the existing PSX materials (`Psx.lit`, vertex snapping, affine
  UVs) so models match. Keep the code-built versions as fallbacks until each
  model is approved.

## Not planned (to avoid scope creep)
- New weapons, new mechanics or complex builds. The core stays katana + arc
  shotgun + dash + jump.
