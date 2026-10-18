# Changelog

What changed in each version of KATANA / SHOTGUN, newest first, in plain
words. Each release's section becomes its GitHub Release notes, so headings
must look like `## 0.1 Dev 2 (2026-10-18)`: the version name from
`VERSIONING.md`.

Don't edit this file for a change: add a note to `changelog.d/` instead (its
`README.md` says how). At release time `tools/changelog.sh release` gathers
those notes into a new section here.

## 0.1 Dev 1 (2026-10-18)

### Graphics presets: WEAK, MEDIOCRE and INSANE
- The Quality setting is now **Graphics**, with three presets that change how the game looks, not just how many effects it shows.
- **WEAK** is the game's look so far, made for older PCs.
- **MEDIOCRE** (the new default) adds wider neon glow, a soft haze around every lamp, smoother edges and more blood per kill.
- **INSANE** goes all out: light that bounces off the neon onto the floors, wet floors that reflect the city, real fog lit by the lamps, soft shadows and shading in every corner, and even more blood per kill. It needs a strong graphics card and a game restart (Settings offers a RESTART GAME button).
- If you were on HIGH, you're now on MEDIOCRE, which looks the same and better.

### Glory kills on F
- Glory kills are now your call: when an enemy is staggered and close, a
  gold "F  GLORY KILL" prompt appears under the crosshair and the enemy's
  marker turns gold. Press F to finish it, just like Doom.
- Slashing a staggered enemy just cuts it (hard), so you choose between a
  quick kill and the full finisher with its health and cells.
- F can be pressed a moment early and still counts, and it can be rebound
  in Settings.

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

### Climb, plunge and a higher double jump
- Jump at a ledge that's just out of reach and keep pushing toward it: your
  hands grab the edge and you pull yourself up. Only ledges you could really
  reach count (up to about 2 m above your feet), so tall walls stay tall.
- Plunge: drop from high ground onto an enemy below, look at it and a gold
  "F  PLUNGE" prompt appears. Press F to dive down and drive the katana
  through it. It's a glory kill (health, cells and score), with its own kill
  tag, SAKAHOKO DROP. It also works in the air after a jump pad launches
  you. A plain jump from the enemy's own floor doesn't count. Brutes need
  staggering first, and bosses can't be plunged.
- The double jump goes much higher: about 4 m at the top instead of about
  3 m, and it gives you a small push toward the keys you're holding. Hold
  no keys and it goes straight up.
- Smoother on fast screens: your movement and the camera now glide between
  game updates instead of stepping 60 times a second, so a 144 or 240 Hz
  monitor shows every frame of a run, jump, dash or climb.

### Shin-Kagura goes vertical
- The rooftop now has six floor heights. The centre is cut open down to a metro platform 10 m below, with service ledges halfway down. A torii bridge crosses the gap, and the north side climbs to a shrine tower and a beacon at the top.
- New spots on the roof: a stairwell hut, a billboard gantry, crate stacks and a tall vent you can't climb.
- Amber edges mark the ledges you can grab. Every level also has a ramp.
- Enemies come from more places: metro tunnels, freight lifts, roof hatches and sky drops on every level.
- Enemies now follow you between levels. They take the ramps, drop off ledges, and crouch before leaping up a ledge so you can see it coming.
- The city around the roof is alive: lit windows, neon signs, ads, corporation logos, flying cars, a monorail, a blimp, searchlights, and a sun that slowly moves.
- Lower quality settings show fewer flying cars.

### A player wiki
- The game now has a wiki on GitHub: how to play, every control, the
  weapons, glory kills and movement, every enemy and boss with their stats
  and attacks, all 24 level-up cards and the nine builds, the wave mutators,
  scoring, seeds, the Player Level and boss rewards, saving, settings, the
  map, these patch notes and the roadmap.
- It is kept up to date with the game: every update that changes what you
  see in play updates the wiki too, and the patch notes there come straight
  from this changelog.

### Sharper text
- Small text, card text and numbers now use Jersey 10, a true pixel font: every letter has even one-pixel strokes, so nothing smudges together ("1/3" no longer reads "V3"), on any screen size up to 4K.
- Counters, scores and tables use fixed-width digits, so they hold still while they count.
- The big titles keep their cyberpunk faces.
- Settings text sits centred in its boxes, and the title screen no longer peeks out from behind the settings panel.

### Bosses fight back harder
- Bosses now read you: hang back and aim at them from range and they step out of the line. Kurokage leaves an afterimage, Tetsugumo leaps back with a shockwave, Shuten barges aside.
- Some of their swings hold a beat longer before they land. Watch for the eyes to flare.
- Each boss has an area attack: Kurokage's smoke ring, Tetsugumo's EMP field, and Shuten's fissures of fire. Each one shows on the floor first, so you can step out or jump it.
- Each boss has a RED SIGNAL attack, warned by a red diamond and an alarm: Kurokage's NULL CROSS, Tetsugumo's BROOD BARRAGE (find the gap in the rings) and Shuten's DAEMON GRAB. Dash through it at the last moment for a PERFECT, which slows time and fills their KAMAE bar.
- After every big attack a boss is left open for a moment with its armour down, and hits fill its KAMAE faster.
- On your first trip through the bosses they hold the area and RED SIGNAL attacks back until they're enraged, and the very first boss warns you longer.

### Settings work with the mouse
- Clicks in the settings screen now land: tabs, options, sliders, key slots
  and the BACK, DEFAULTS and QUIT GAME buttons all respond to the mouse.
- The settings screen is mouse only. Click a key slot, then press the new key;
  right-click a slot to clear it.

### Easier-to-read level-up cards
- The level-up cards use larger, plain white text on a solid dark plate, so
  the name and description stand out against the fight behind them.
- Card descriptions are shorter and say only what the card does.
- Cards no longer sway or tilt once they are dealt, so the text stays sharp.
  Hovering or selecting a card lifts it and lights its border instead.

### Quit the game from its menus
- A QUIT GAME button on the title screen, the pause screen and the settings
  screen closes the game, saving your progress and settings first. Q works on
  the title screen too.
- It asks for a second press, so a stray click never quits by accident.

### More wave mutators
- Seven new wave mutators, so waves feel more different from each other:
  ONRYO'S GRUDGE (the dead burst a moment later), KABUTO PLATE (armoured
  grunts and gunners: blast, then slash), MATSURI RUSH (the combo timer runs
  twice as fast), KANASHIBARI (slow dash recharge), HANNYA'S WRATH (wounded
  enemies enrage), UMIBOZU SWELL (the whole wave comes at once) and SENRYO
  BOUNTY (headshots and glory kills pay double, other kills half).
- RAIJIN'S STORM now has real lightning: a red ring marks where a strike
  will land near you, then it hits everything inside. It pays x1.4 now.
- The same mutator never comes up two waves in a row, and the harshest ones
  wait until wave 3 or 4. Red rings still waiting when a wave ends are
  defused, so nothing hits you during the score tally.
- IDATEN'S HASTE is now called OKURI-INU HUNT, and JOROGUMO'S BITE is gone
  (it played too much like AKATSUKI).

### Break a boss's stance
- Bosses no longer get glory kills. Instead each boss has a gold KAMAE bar under its health bar.
- Keep attacking to fill it: katana hits fill it fastest, shotgun blasts and returned shuriken or bullets help, and glory kills on enemies near the boss give it a big push. Back off for a few seconds and it slowly drains.
- When the bar fills, the boss's stance breaks with a heavy clang and "KAMAE BROKEN". It reels for a few seconds: press F for the ONIKIRI, a brutal finisher that takes a fifth of its health, or kills it outright when it is low.

### Return to sender
- A deflected shot now flies straight back to the enemy or boss that fired it and always hits them, even if they moved or ducked behind cover.
- If the shooter is already dead, the shot finds the enemy closest to where you're aiming.
- Returned shots hit harder the stronger the shot was, and land with a cyan flash and a crack.

### Full screen, any resolution, any frame rate
- The game now starts full screen at your screen's own resolution, up to 4K
  and beyond, and keeps its chunky PS1/PS2 pixel look: on a 4K screen every
  game pixel is a sharp 4x4 block, never blurred.
- The frame rate is unlimited out of the box (VSync off), so a 240 Hz screen
  gets every frame it can show. The frame cap still offers 60, 75, 120, 144,
  165, 240 and 360, and VSync can be switched on in Settings.
- The Video tab names the screen it detected. Windowed mode (F11) opens at a
  sharp whole-number size that fits your screen.

### Faster, heavier music
- The stand-in soundtrack is rewritten to match the game's speed: combat
  tracks run at 140 to 152 beats per minute, boss themes go faster still,
  and the title theme has a beat.
- It is now dark electronic bass music: heavy talking wobble basses, deep
  sub, hard pumping kicks and claps, hypnotic synth patterns, laser zaps,
  and phrase endings that stutter, tape-stop, reverse and bitcrush.
- Real, professionally made music will replace these stand-ins later.

### Level-up builds
- The level-up cards now change how you fight instead of adding a few
  percent. There are 24 cards, from shotgun arcs that leap between enemies
  to a 9 m glory-kill leap, a dash that recharges a cell, and a blade whose
  third cut breaks armour.
- Cards come in nine builds of three, such as STORM RUNNER (blast, dash,
  recharge, never stop moving) or EXECUTIONER (chain glory kills across the
  rooftop). Each card shows its builds at the bottom.
- A card that links to one you already own wears a gold RECOMMENDED tab, and
  once you own a build card every level-up offers at least one card that
  links to it. Linking two cards says so, and completing a build stamps its
  name. The pause screen lists your builds.
- Offers are still decided by the seed: the same seed and the same picks
  give the same cards.
- Picking a card is now deliberate: the first click (or 1, 2, 3) selects a
  card and lifts it, and a second click, the same key again or Enter takes
  it. Clicks from the fight in the first moment after the cards appear are
  ignored, so you can't grab one by accident.
- Changed cards: Masamune Edge now makes every third cut a heavy one instead
  of +35% damage; Raijin's Fork makes arcs leap between enemies instead of
  adding arcs; Idaten Drive gives +1 dash and a cell per dash, but no longer
  speeds up the dash recharge; Vampiric Steel became Chimatsuri Steel;
  Fujin Bank became Inazuma Overload; High Voltage is now called Ikazuchi
  Surge and Feedback Loop is Fujin's Return. Long Reach is gone.

### Sound that never gets cut off
- Your shotgun, blade and enemy warning sounds always play, even in the
  biggest crowd: gore and background noise make way for them instead of
  cutting them off.
- Behind the scenes, every sound and piece of music now has its own settings
  file, ready for the professional soundtrack and sound effects to drop in.
  Music can build in layers as your combo climbs and when a boss is enraged,
  once tracks with layers arrive.

### Your progress is saved
- A **Player Level** now rises after every run. The results screen counts your
  XP into the level bar, and each new level gets its own fanfare. It shows on
  the title screen too. It unlocks nothing and never changes difficulty.
- The in-run level is now labelled **RUN LV** so the two never mix.
- **Bosses drop rewards.** Each boss unlocks new weapon looks: glowing katana
  edges and shotgun coils in new colours. Pick them on the title or pause screen
  with **1** and **2**. They are cosmetic only.
- **Quit mid-run and carry on later.** The game saves between waves; next time,
  the title offers **CONTINUE RUN** (or press **N** for a new run).
- The game saves itself after every run, every unlock and on quit. Saves are
  checked when loaded and keep a backup, so a crash or power cut never wipes
  your progress. Your old high scores come with you.
- Your high score is kept the moment a run ends, even if you quit before
  typing your initials.

### A cleaner mix you can hear the music through
- The music now leads the mix. Gunfire, blades and gore sit just under it,
  menu and score sounds under that, and the weather far behind.
- The game no longer clips: loud fights stop distorting.
- The rain is no longer a wall of white noise. It is soft patter, drops and
  drips that come and go, tucked well under the music, and heavy rain adds
  weight instead of hiss.
- Glory kills, big explosions, boss slams and boss entrances briefly pull
  the music back so they land.
- Music, effects, ambience and menu sounds each have their own channel, ready
  for the volume sliders in the settings menu.

### Smoother fights
- Enemies, bolts, blood, gibs, damage numbers, lightning arcs, smoke, health
  orbs and kill tags are now reused instead of being built and thrown away
  for every hit and kill, so big fights don't stutter.
- Every combat shader is prepared while the game loads, so the first
  shotgun blast, kill or explosion no longer causes a hitch.
- Each graphics preset caps how much blood, gibs, smoke and sparks pile up
  on screen, so weaker PCs keep a smooth frame rate.
- Press F3 to show a performance overlay: frame rate, frame time and draw
  calls.

### Settings
- A settings screen, opened with Tab or the SETTINGS button on the title and
  pause screens. It has volume sliders for the sound channels; window mode,
  VSync, frame cap, render scale and field of view; mouse sensitivity and key
  rebinding (two keys per action, mouse buttons too, including F for glory
  kills); and comfort sliders for screen shake and flashes.
- Everything applies at once and is remembered next time. F11 and the `[` `]` sensitivity keys are remembered
  too.
- Turning flashes below 100% also stops the impact frames from strobing.

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
