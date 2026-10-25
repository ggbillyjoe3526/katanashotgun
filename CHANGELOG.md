# Changelog

What changed in each version of KATANA / SHOTGUN, newest first, in plain
words. Each release's section becomes its GitHub Release notes, so headings
must look like `## 0.1 Dev 2 (2026-10-18)`: the version name from
`VERSIONING.md`.

Don't edit this file for a change: add a note to `changelog.d/` instead (its
`README.md` says how). At release time `tools/changelog.sh release` gathers
those notes into a new section here.

## 0.1 Dev 3 (2026-10-25)

### Enemies fight with weapons you can read
- Every grunt now carries a nata, a long cleaver with a neon edge, and every brute a studded kanabo club. No enemy hurts you just by standing close any more: you see the weapon raised, then swung.
- Each attack telegraphs on the weapon itself: a glint at its tip as the windup starts, the edge heating to red, then a white-hot blow and a red arc where it cut.
- When something hits you, a red arrow round your crosshair points at it.

### Hits you can feel
- Every hit you land flashes an X round the crosshair with a sharp tick: gold for a shotgun headshot, red with a deeper knock for a kill.
- A slightly longer freeze on impact (longer on a kill), enemies flinching back from your blows, the view jolting along your cut, and a bright streak across each body the katana cuts.

### Aim assist
- New AIM ASSIST setting (Settings, Controls), on by default. A slash that would hit nothing pulls you onto an enemy just out of reach, and a shotgun blast that only just misses bends onto the body. Turn it off for pure aim.

### Hands, a bigger katana and a wider view
- You can now see your hands: armoured cyber hands grip the katana's handle and the shotgun, finger on the trigger. Their light lines take your weapon look's colour.
- The katana is bigger and turned so you see the flat of the blade instead of a thin edge, held upright on the left.
- The view no longer feels zoomed in: your eyes sit at proper head height, level with a grunt's, and both weapons are smaller and tucked into the corners so more of the city shows. Your body is the same size, so jumps, ledge grabs and plunges work as before.

### Bosses arrive where you can see them
- Every boss now drops in right where you're looking, usually on your own floor, and lands with a slam and a shake. No more turning round looking for Kurokage.
- Bosses no longer throw themselves off ledges: Kurokage's dash-slash, Shuten's charge and the NULL CROSS lines stop at the edge, and sidesteps only go where there is floor, so a boss never ends up in the pit leaving you to wait.
- Kurokage only starts a dash-slash when he can actually reach you, and Shuten saves his leap, charge and fan volley for when he's close and on your level.
- Shuten and other big bodies now step down off ledges into the pit properly instead of getting stuck on the edge.

### Geyser pads on every level
- Eight new geyser pads on The Well: two on the service ledges, four on the roof and one at the north end of each side catwalk. Each throws you about 9 m straight up, so every level now has a launch into a plunge attack.
- Steer while you fly to land on the level above, or hold nothing and drop back onto the pad.
- A pad now only fires when you stand on its own floor, never from the floor underneath it.

### Pit ramps out of the way
- The two ramps in The Well's metro pit now run along the service walls and end straight on the balconies, so the middle of the pit is open floor.
- A lit wall a hop high guards the bottom of each ramp's open side, so you can't trip on the ramp's edge any more.
- The pit's geyser pad and its 3 m crate moved a little to make room.

### No more snagging on small props
- On The Well's roof you no longer catch on low clutter mid-sprint. Skylights now sit flush with the floor, so you run straight across them.
- The small crate rows and air-con boxes are now a clear hop high (1.2 m), so they read as something to jump, not something to trip on.
- The pipe benches along the roof edge now back right onto the parapet.

### Quality of life
- Esc now closes the pause screen too, and the click that closes it no longer swings the katana or fires the shotgun.
- When a wave is down to its last three foes, small orange arrows at the screen's edge point to the ones you can't see, and a chevron marks far ones on screen. A boss off screen gets a bigger arrow.
- Walk off a ledge and press jump a split second late: it's now a full jump, and you keep your double jump.
- A quick shotgun click just before the gun is ready now fires as soon as it can, instead of being lost.
- An empty shotgun now says "NO CHARGE / USE THE BLADE", and holds it long enough to read.
- The pause screen has HOW TO PLAY, RESTART (same seed) and MAIN MENU. MAIN MENU saves the run so CONTINUE picks it up.
- NEW RUN on the title and DEFAULTS in Settings now ask for a second click, so one stray click can't throw away a saved run or your key bindings.
- HOW TO PLAY now covers the plunge, ledge climbing and the boss's KAMAE bar, and shows your own keys after you rebind them.
- The [ and ] keys now show the new mouse sensitivity for a moment. New COMFORT settings: crosshair size and colour.
- Pressing dash with no charge left now flashes the dash lights red with a dull clunk.
- Below 30% health a quiet heartbeat plays under the music.

### Back to the main menu after a run
- The results screen now has MAIN MENU in the top-left corner. Click it or press Esc to go back to the title screen instead of starting another run.

### One retro look
- RETRO LOOK in Settings > Video is now just LIGHT or OFF. The chunky FULL look is gone; if you had it picked, the game starts on LIGHT.

### Bug fixes
- A wave no longer ends while its last enemies are still dropping in. If you cleared the field just before the final group arrived, the tally used to start with them still alive.
- The white impact frames in glory kills now last their intended time instead of being cut to a single frame by the hit freeze, and screen flashes no longer jump ahead when a hit freeze starts.
- A boss or brute shockwave still rolling outward can no longer hurt you once the wave is clear.
- Continuing a saved run after a boss fell (if you quit before the next wave) no longer pays that boss's reward a second time.
- Switching to another window (Alt+Tab) now always pauses the game.
- Dying within a few seconds of a boss kill no longer brings the fight music and the boss's farewell card back over the death screen.
- A continued run now keeps its combo.
- The Well no longer stays brighter for the rest of a storm after the first lightning strike.
- High-score initials now type the letters printed on your keyboard (AZERTY and other layouts).
- Climbing a ledge right after a slash lunge no longer flings you off the top.
- Cut-off grunt arms no longer flash or change colour along with the next grunt.
- Enemies on The Well's service blocks now walk out of the freight lifts drawn for them.
- Puddle reflections no longer trail a frame behind the camera.
- A damaged save file is now always kept aside, never deleted, and a replayed seed with the same score puts your initials on the right row.
- A slash or dash pressed during a glory kill, or right as a ledge climb starts, now fires the moment it ends instead of being lost.
- Jump pressed just before you land, and dash pressed just before a charge comes back, now still go off (a short input buffer).
- A glory kill from a ledge or mid-jump can no longer leave you stuck inside the ledge or wall below; you finish beside the enemy where there is room.
- Enemies can now follow you onto the water tanks, the stairwell hut and the east end of the billboard gantry on The Well.
- The enemy count no longer goes over the wave's limit.
- The score no longer flashes as if you'd scored when you continue a saved run.
- A save file that another program is holding open is no longer mistaken for a damaged one: the game waits a moment for it, and if it is still busy the title says so and that session saves nothing instead of starting your profile over.
- Saving keeps the old backup safe even if the backup step fails, and a profile from a newer version of the game stays safely copied aside.
- A puddle no longer sits inside the solid block at the bottom of The Well.
- The weather on each seed is now locked in for good: future changes to the map can no longer change a seed's rain. This was a one-time change, so a seed from 0.1 Dev 2 may now have different rain, and the city towers around The Well are arranged differently.

### Soda cans play-test switch fixed
- Turning SODA CANS on in the DEV menu (F10, RUN tab) on the title screen now gives you cans in the run you start next. Before, it only worked after restarting the game, so no can ever showed up.
- Turning it on during a run now brings cans from the next wave. That run then makes no top 10 entry, like any run with cans.
- Reminder: the first can turns up on wave 2, and boss waves never have cans. Look for a tall light pillar in the can's colour.

## 0.1 Dev 2 (2026-10-20)

### Seeds you can trust
- The same seed now always gives the same waves. Before, how you played a wave could change the next waves' enemies and mutators, so a friend on your seed could face a different run.
- Seeds from 0.1 Dev 1 play differently now.
- Shotgun spread, enemy attack timing and health orb drops now follow the seed too.
- Fixed enemies that came out of a tunnel in a group sometimes getting stuck in the metro tunnel roof, which stopped the wave from ever ending.

### Play a friend's seed
- New **PLAY A SEED** button on the title screen (or press S): type or paste a friend's seed and start a run on it. No more editing a shortcut.
- Pasting is forgiving: a whole line like "SEED 1A2B-3C4D" works, and the dash fills itself in when you type.
- **COPY** your seed from the pause screen or the results screen (or press C), ready to paste to a friend.

### A cleaner fight screen
- The in-fight HUD is redesigned: no more panels in the corners and no more text piling up on itself.
- Your health, cells and dashes now sit in a square frame round the crosshair: health up the left edge, one block per cell up the right, dash charges along the bottom, with the numbers beside it. The middle stays open, so you can always see what you are aiming at.
- Your combo and the F prompt sit under the frame; kill tags (HEADSHOT, RETURN TO SENDER...) stack just right of it.
- Every kind of message has its own place and a new one replaces the old: big moments like X10 COMBO and KAMAE BROKEN just under the top row, warnings and hints at the bottom centre (warnings in red).
- The wave intro, the boss's name card and the cut-ins now show near the top of the screen, clear of your crosshair. The boss reward card deals in at the bottom.
- The best score is no longer on the fight screen (the title and results screens show it); NEW HI-SCORE still flashes when you pass it.

### Cleaner menus
- The title, pause, level-up and results screens get the same clean look as the fight screen: plain words to click on the left, the city left in view, and panels only where there is a table.
- Every menu choice is a word you can click; it lights white with a cyan bar when you point at it. QUIT asks once more before it quits.
- Title: START RUN (or CONTINUE and NEW RUN when a run is saved), PLAY A SEED, HI-SCORES, ARMORY, HOW TO PLAY, SETTINGS and QUIT. The high scores, the armory and the controls now open beside the menu instead of all showing at once. Your best score and Player Level sit in the bottom corner.
- Pause: RESUME, ARMORY, SETTINGS and QUIT GAME, your builds in the top right corner, and the seed with COPY at the bottom.
- The armory can now be changed with the mouse: click a row to change your katana edge or shotgun coil.
- Level-up cards are redrawn to the new design and keep their full text: a coloured ribbon with the card's tag and key, the name, its rank, what it does, and its builds along the bottom. Choosing a card asks "TAKE ...? CLICK AGAIN" in a box under the cards.
- Results: every stat on one plate, the high-score table beside it with your row lit (type your initials straight into it), NEW BEST under your score, and your Player Level and seed below. RETRY SEED, NEW RUN, RUN CARD and COPY SEED are words along the bottom.

### Flashier big moments
- Combo milestones, glory kills and the ONIKIRI now arrive on a blade cut: a slash crosses the top of the screen, the word slams onto a leaning plate, and the plate is sliced in half when it leaves. Big ones slice the picture itself for a moment.
- Glory kills get three cuts across the screen and angled black bars, and their points now show under GLORY KILL instead of in the kill tags.
- Kill tags, warnings, LEVEL UP, KAMAE BROKEN and the boss's entrance now look like a pirate broadcast taking over the city's screens: solid neon blocks with dark letters and hard shadows, test-card colour bars, rolling picture glitches and torn-strip exits.
- MISSILES INBOUND and other warnings take over the bottom of the screen as a red emergency band with hazard stripes.
- A boss's name now scrolls across the screen in huge outlined letters while its card is up.
- FINISH keeps its look, and the world behind it now turns into a red-and-black negative.
- The flash comfort setting turns off the new colour bars, static and negatives; the screen shake setting calms the picture cuts and rolls.

### A more detailed rooftop
- The Shin-Kagura rooftop is built up: raised floor plates with lit seams, pipes, air-con units, vending machines, lit shop shutters, hanging signs, roof vents, skylights, a small shrine, and cables with paper lanterns across the shaft.
- Coloured haze over the city, mist in the shaft and below the roof edge, pools of lamp light, light beams, steam and floating dust.
- Rain leaves puddles where water would really collect, and only puddles and skylight glass reflect the neon. More rain, more puddles; a clear night leaves only the metro floor wet.
- Floors no longer look wet on INSANE graphics: dry surfaces stay matte on every preset.
- WEAK graphics keeps the new shapes and haze but skips the reflections, dust, steam and beams.
- Vending machines, vents, street lamps, skylight frames and the pipe benches by the parapet are solid. They never block a spawn, a ramp or an enemy's leap spot.

### A new DOJIGIRI katana
- The katana has a new, detailed model: a dark slab blade with a glowing
  edge, and a one-piece open-frame hilt with a glowing core, finger spur,
  bolts and a textured grip.
- It looks sharp with RETRO LOOK OFF or LIGHT (fine scratches, brushed steel,
  heat tint near the edge) and keeps the PS1 style on FULL.
- Your equipped katana look still colours the glowing edge.

### A new RAIJIN-12 shotgun
- The arc shotgun has a new, detailed model: an angular receiver, two flat
  barrels with a square emitter, slanted cooling vents and a square drum of
  power cells that turns a quarter turn after every blast, in red, gunmetal
  and off-white.
- It looks sharp with RETRO LOOK OFF or LIGHT (worn edges, scratches, grime,
  muzzle soot, small markings) and keeps the PS1 style on FULL.
- Your equipped shotgun look still colours the coils, cells and charge lights.
- The shotgun sits a little further right, clear of the frame round the
  crosshair, and the katana is turned so its glowing edge faces right.

### A softer retro look
- New RETRO LOOK setting in Settings > Video: OFF, LIGHT or FULL.
- LIGHT is the new default: the world is drawn twice as sharp (crisp square
  pixels, 960x540 on a 1080p or 4K screen), with gentler wobble, smooth
  textures and only a faint dither, scanline and colour fringe.
- FULL is the old, chunky PS1 look, unchanged. OFF is a clean, full
  resolution picture.
- Saved settings move to LIGHT.

### Run cards
- New: press P on the results screen (or click RUN CARD) to save a picture of your run: score, wave, bosses felled, builds, your best moment and the seed, in your run's neon colours.
- Cards go in your Pictures folder, in KatanaShotgun. Press O (or click OPEN FOLDER) to open it with the card picked out, ready to drop into Discord or a text.

### Perfect deflect (play-test)
- Slash an enemy shot in the last moment before it hits you for a PERFECT DEFLECT: a ringing clang, a white flash, and the shot flies back white-hot for 12 times its damage instead of 8.
- A perfect deflect gives 2 cells instead of 1 and adds a PERFECT DEFLECTS row (150 each) to the end-of-wave tally.
- Every boss now fires one signature volley that glows white: Kurokage's shuriken fan, a big round at the end of Tetsugumo's gatling sweep, and Shuten's enraged fan volley. Perfect-deflect it and the boss loses 20% of its KAMAE bar.
- A hurt boss now steadies itself more slowly: its KAMAE bar drains slower the less health it has left, down to under a third of the speed near death.
- Deflecting early still works exactly as before. This is an experiment: it may be retuned or removed after play-testing.

### The city is watching (new, to try out)
- News drones gather around the roof as your combo climbs, keep their lights on you, flash their cameras at big combos and fly off once the combo breaks.
- Big city screens show your score, kills and combo live, and the best initials and score saved for the seed you're playing.
- Beat a seed's record and every screen says NEW BEST.
- WEAK graphics sends fewer drones; none of it changes a fight.

### Soda cans (developer test only)
- A first version of soda cans to play-test: INARI FOODS drinks that turn up on the map from wave 2, glowing in their flavour's colour.
- Walk into a can to carry it (up to 3), press E to drink and the mouse wheel to pick which one: the shotgun drops, the katana cuts the top off and you down it in one go.
- Eight flavours, each a short, strong boost and then a milder sugar crash, from faster dashes and healing cuts to double score for double damage taken.
- Switched off unless turned on in the hidden developer menu (F10), and runs with cans don't enter the top 10.

### Developer menu for testing
- A hidden DEV menu on F10 for testing and play tests: god mode, an autoplay
  bot, game speed, start wave, forced bosses and mutators, and quick actions
  like skipping a wave.
- Runs that use its cheats are marked DEV RUN and never reach the top 10 or
  give XP or unlocks.

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
