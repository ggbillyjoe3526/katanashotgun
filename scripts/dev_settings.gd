class_name DevSettings
## The hidden developer settings (spec §16), flipped in the DEV menu (F10,
## scripts/ui/dev_menu.gd). Not a player feature: nothing on screen points
## to it.
## Nothing here is saved but the SODA CANS switch: every other setting lasts
## until the game closes, so a cheat left on never slips into tomorrow's real
## run. A run played with any setting that changes play on is a dev run
## (Game.dev_run): no top 10 entry, no XP, no unlocks. SODA CANS is a feature
## being play-tested rather than a cheat, so it is kept (in settings.json, as
## dev_cans) and a run with it keeps its XP and unlocks; it only skips the top
## 10 (Game.cans_run). The plain-look switch that lived here is now the
## player's RETRO LOOK setting (RetroLook, Settings.retro_look).

## The key that opens the menu, in the title, a run and the pause screen.
## Kept out of key rebinding (Settings.RESERVED_KEYS).
const KEY := KEY_F10
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0]
const MAX_START_WAVE := 30

static var speed := 1.0 # game speed while playing (UI and juice keep real time)
static var start_wave := 1 # the wave the next run starts at
static var boss := "" # every boss wave brings this boss ("" = the seed's)
static var mutator := "" # every regular wave gets this mutator ("" = the seed's)
static var hide_hud := false # the in-run HUD hides (for clean captures)
static var cans := false # soda cans spawn, from the next run (spec §19.1 #11); saved
static var can_flavour := "" # every soda can is this flavour ("" = the seed's)


## Puts every dev setting back to normal (the menu's DEFAULTS).
static func reset() -> void:
	speed = 1.0
	start_wave = 1
	boss = ""
	mutator = ""
	hide_hud = false
	cans = false
	can_flavour = ""
	Game.debug_god = false
	Game.set_autoplay(false)
	Game.debug_palette = ""


## Whether any setting that changes how a run plays is on. While one is,
## the run in progress becomes a dev run.
static func cheating() -> bool:
	return Game.debug_god or Game.debug_autoplay or speed != 1.0 or start_wave > 1 \
		or boss != "" or mutator != "" or can_flavour != ""


## Whether any dev setting is on at all (the corner tag shows then).
static func any_on() -> bool:
	return cheating() or hide_hud or cans or Game.debug_palette != ""


## Short names of the dev settings that are on, for the corner tag.
static func active_tags() -> PackedStringArray:
	var out := PackedStringArray()
	if Game.debug_god:
		out.append("GOD")
	if Game.debug_autoplay:
		out.append("BOT")
	if speed != 1.0:
		out.append("SPEED %d%%" % roundi(speed * 100.0))
	if start_wave > 1:
		out.append("START W%d" % start_wave)
	if boss != "":
		out.append("BOSS %s" % boss.to_upper())
	if mutator != "":
		out.append("MUTATOR %s" % str(Mutators.get_def(mutator).get("name", mutator)))
	if cans:
		out.append("SODA CANS")
	if can_flavour != "":
		out.append("CANS %s" % str(Soda.get_def(can_flavour).get("name", can_flavour)))
	if Game.debug_palette != "":
		out.append("PALETTE")
	if hide_hud:
		out.append("NO HUD")
	return out

