class_name Soda
## Soda cans (spec §19.1 #11, a dev-only play-test experiment): the INARI
## FOODS drinks found on the map. Each flavour is a short, strong buff, then
## a shorter, milder "crash"; the risk can trades damage taken for score.
## Effects are multipliers (`boosts`, 1.0 = no change) or switches (`flags`)
## that the player, the scoring and the pickups read through Game.boost()
## and Game.boost_flag(). The runtime lives in SodaCans.
##
## Each flavour feeds one or two card builds (Upgrades.BUILDS), so a can can
## say it FITS a build the player owns. Copy stays short: the pickup line in
## the hint lane is the name, then `desc` (keep it under MAX_DESC).

const MAX_HELD := 3
const MAX_DESC := 52

const LIST := [
	{"id": "kaze", "name": "KAZE RUSH", "color": Color(0.55, 1.0, 0.35),
		"desc": "+25% SPEED, DASH 2X FASTER 12S. THEN SLOW DASH 5S",
		"time": 12.0, "boosts": {"speed": 1.25, "dash_recharge": 0.5},
		"crash_time": 5.0, "crash": {"dash_recharge": 1.5}, "builds": ["storm", "ghost"]},
	{"id": "kaminari", "name": "KAMINARI SPARK", "color": Color(0.3, 0.9, 1.0),
		"desc": "KATANA KILLS +1 CELL 15S. THEN SLOW SHOTGUN 5S",
		"time": 15.0, "flags": ["kill_cells"],
		"crash_time": 5.0, "crash": {"shotgun_cd": 1.3}, "builds": ["thunder"]},
	{"id": "shiranui", "name": "SHIRANUI BLAZE", "color": Color(1.0, 0.5, 0.15),
		"desc": "KATANA SETS FOES ON FIRE 12S. THEN SLOW FEET 5S",
		"time": 12.0, "flags": ["ignite"],
		"crash_time": 5.0, "crash": {"speed": 0.85}, "builds": ["inferno"]},
	{"id": "mikazuki", "name": "MIKAZUKI ZERO", "color": Color(0.85, 0.85, 1.0),
		"desc": "HEADSHOTS +50% DAMAGE 15S. THEN -15% DAMAGE 5S",
		"time": 15.0, "boosts": {"headshot": 1.5},
		"crash_time": 5.0, "crash": {"dmg_out": 0.85}, "builds": ["headhunter"]},
	{"id": "akaname", "name": "AKANAME RED", "color": Color(1.0, 0.25, 0.35),
		"desc": "KATANA HITS HEAL 12S. THEN ORBS HEAL HALF 6S",
		"time": 12.0, "flags": ["katana_heal"],
		"crash_time": 6.0, "crash": {"orb_heal": 0.5}, "builds": ["blood"]},
	{"id": "uzume", "name": "UZUME POP", "color": Color(1.0, 0.4, 0.85),
		"desc": "COMBO NEVER DROPS 12S. THEN IT HALVES",
		"time": 12.0, "flags": ["combo_hold"],
		"crash_time": 0.0, "crash": {}, "halve_combo": true, "builds": ["showstopper"]},
	{"id": "gaki", "name": "GAKI BLACK", "color": Color(0.7, 0.45, 1.0),
		"desc": "2X SCORE BUT 2X DAMAGE TAKEN 15S",
		"time": 15.0, "boosts": {"score": 2.0, "dmg_in": 2.0},
		"crash_time": 0.0, "crash": {}, "builds": [], "min_wave": 4},
	{"id": "yuki", "name": "YUKI CHILL", "color": Color(0.6, 0.95, 1.0),
		"desc": "-30% DAMAGE TAKEN 10S. THEN SLOW KATANA 5S",
		"time": 10.0, "boosts": {"dmg_in": 0.7},
		"crash_time": 5.0, "crash": {"katana_cd": 1.25}, "builds": ["ronin"]},
]

## Where cans turn up: none before FIRST_WAVE, none on boss waves (the boss
## is the show), one a wave, two from TWO_FROM.
const FIRST_WAVE := 2
const TWO_FROM := 6
## Akaname Red: health per enemy a katana swing hits.
const KATANA_HEAL := 3.0


static func get_def(id: String) -> Dictionary:
	for f in LIST:
		if f.id == id:
			return f
	return {}


## How many cans wave `w` puts on the map.
static func count_for_wave(w: int, boss_wave: bool) -> int:
	if boss_wave or w < FIRST_WAVE:
		return 0
	return 2 if w >= TWO_FROM else 1


## The flavours wave `w` can deal (the risk can waits for the later waves).
static func pool_for_wave(w: int) -> Array:
	var out := []
	for f in LIST:
		if int(f.get("min_wave", FIRST_WAVE)) <= w:
			out.append(f)
	return out


## The first card build the player owns a card of that this flavour feeds,
## or {} when none does (the pickup line then names no build).
static func fits_build(def: Dictionary, owned: Dictionary) -> Dictionary:
	for b in Upgrades.BUILDS:
		if b.id in def.get("builds", []) and Upgrades.build_count(b, owned) > 0:
			return b
	return {}
