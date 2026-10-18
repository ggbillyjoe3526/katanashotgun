class_name Progression
## Player Level (spec §11.1): XP paid into the profile at the end of every
## run. It unlocks nothing and never changes difficulty. The formula and
## pace are an open decision (spec §19); these are the defaults until the
## owner picks: the first level comes after a short first run, later levels
## take a few good runs each, and nothing is ever grindy.

const XP_PER_WAVE := 60 # each wave cleared
const XP_PER_BOSS := 250
const XP_PER_KILL := 4
const XP_PER_GLORY := 15
const SCORE_PER_XP := 500 # +1 XP per this many points

const LEVEL_BASE := 400 # XP from level 1 to 2
const LEVEL_STEP := 150 # each level after needs this much more
const LEVEL_STEP_CAP := 30 # ...up to level 31, then the need stops growing


## XP for one run, from its stats, as [label, xp] rows (zero rows dropped).
static func run_xp(stats: Dictionary) -> Array:
	var cleared := maxi(int(stats.get("wave", 0)) - 1, 0)
	var rows := [
		["WAVES CLEARED", cleared * XP_PER_WAVE],
		["BOSSES FELLED", int(stats.get("bosses", 0)) * XP_PER_BOSS],
		["KILLS", int(stats.get("kills", 0)) * XP_PER_KILL],
		["GLORY KILLS", int(stats.get("glory_kills", 0)) * XP_PER_GLORY],
		["SCORE", int(stats.get("score", 0)) / SCORE_PER_XP],
	]
	return rows.filter(func(r): return int(r[1]) > 0)


static func total(rows: Array) -> int:
	var t := 0
	for r in rows:
		t += int(r[1])
	return t


static func xp_to_next(level: int) -> int:
	return LEVEL_BASE + LEVEL_STEP * mini(maxi(level, 1) - 1, LEVEL_STEP_CAP)


## Adds `gained` XP to (level, xp). Returns [level, xp] after.
static func apply(level: int, xp: int, gained: int) -> Array:
	level = maxi(level, 1)
	xp = maxi(xp, 0) + maxi(gained, 0)
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
	return [level, xp]
