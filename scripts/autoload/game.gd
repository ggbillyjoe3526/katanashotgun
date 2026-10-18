extends Node
## Global run state: seed, score, combo, XP/levels, upgrades, wave mutator,
## high scores, hitstop and slow-mo.

signal hud_message(text: String, color: Color, big: bool)
signal popup(text: String, color: Color)
signal hint(text: String)

const COMBO_WINDOW := 4.0

var state := "title" # title | playing | levelup | paused | dead
var autostart := false
var mouse_sensitivity := 0.0024
var debug_autoplay := false
var debug_god := false
var debug_no_pause := false
var debug_palette := "" # --palette=NAME or index: force a palette (debug only)

var player: Player
var main: Node
var gore: Gore
var fx: Fx
var arena: Arena
var hud: Hud

# --- the run
var run_seed := 0
var next_seed := -1 # set before a restart to replay a seed
var palette: Dictionary = {}
var rng_map := RandomNumberGenerator.new()
var rng_waves := RandomNumberGenerator.new()
var rng_upgrades := RandomNumberGenerator.new()
var mutator: Dictionary = {}
var wave_damage := 0.0

var score := 0
var combo := 0
var combo_timer := 0.0
var best_combo := 0
var kills := 0
var executions := 0
var headshots := 0
var deflects := 0
var bosses_killed := 0
var bosses_felled: Array = [] # boss kinds felled this run, in order
var level := 1
var xp := 0.0
var xp_next := 60.0
var pending_levelups := 0
var wave := 0
var run_time := 0.0
var upgrades := {}
var hints_shown := {}
var enemy_list: Array = []

## The top 10 lives in the profile (spec §7.4, §11.3).
var high_scores: Array:
	get:
		return Profile.high_scores
var real_dt := 0.016 # this frame's delta in real seconds (ignores slow-mo)
var _wave_start := {}
var last_rank := -1

var _hitstop := 0.0
var _slowmo_left := 0.0
var _slowmo_scale := 1.0
var _last_ticks := 0
var _applied_ts := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_ticks = Time.get_ticks_usec()
	var args := OS.get_cmdline_user_args()
	debug_autoplay = args.has("--autoplay")
	debug_god = args.has("--god")
	debug_no_pause = debug_autoplay or args.has("--showcase") or args.has("--juicetest") or args.has("--palettetour") or args.has("--movetest")
	for a in args:
		if a.begins_with("--seed="):
			var hex := a.substr(7).replace("-", "")
			next_seed = hex.hex_to_int() if hex.length() > 0 else -1
		elif a.begins_with("--palette="):
			debug_palette = a.substr(10)
	Settings.boot()


## Starts a fresh run state. A run is fully described by its seed: the map
## layout, palette, wave line-up, mutators, boss order and augment offers.
func reset_run() -> void:
	if next_seed >= 0:
		run_seed = next_seed
	else:
		run_seed = randi() & 0x7fffffff
	next_seed = -1
	rng_map.seed = hash(run_seed * 3 + 1)
	rng_waves.seed = hash(run_seed * 5 + 2)
	rng_upgrades.seed = hash(run_seed * 7 + 3)
	palette = Palette.pick(rng_map, debug_palette)
	state = "title"
	mutator = {}
	wave_damage = 0.0
	score = 0
	combo = 0
	combo_timer = 0.0
	best_combo = 0
	kills = 0
	executions = 0
	headshots = 0
	deflects = 0
	bosses_killed = 0
	bosses_felled = []
	level = 1
	xp = 0.0
	xp_next = 60.0
	pending_levelups = 0
	wave = 0
	run_time = 0.0
	upgrades = {}
	last_rank = -1
	_wave_start = {}
	_hitstop = 0.0
	_slowmo_left = 0.0
	Engine.time_scale = 1.0
	_applied_ts = 1.0


static func seed_string(s: int) -> String:
	return "%04X-%04X" % [(s >> 16) & 0xFFFF, s & 0xFFFF]


func mut(key: String, default: Variant) -> Variant:
	return mutator.get(key, default)


func rank(id: String) -> int:
	return upgrades.get(id, 0)


func hitstop(duration: float) -> void:
	_hitstop = maxf(_hitstop, duration)


func slowmo(scale: float, duration: float) -> void:
	_slowmo_scale = scale
	_slowmo_left = maxf(_slowmo_left, duration)


func combo_mult() -> float:
	return 1.0 + minf(combo * 0.1, 4.0)


func score_mult() -> float:
	return combo_mult() * float(mut("score", 1.0))


func register_kill(base_points: int, xp_amount: float, tag := "", tag_color := Color.WHITE) -> void:
	kills += 1
	combo += 1
	combo_timer = COMBO_WINDOW
	best_combo = maxi(best_combo, combo)
	var pts := int(base_points * score_mult())
	score += pts
	# a tiny tick that climbs in pitch as the combo grows
	Sfx.play("tick", -11.0, 1.0 + minf(combo, 40) * 0.03, 0.0)
	if tag != "":
		popup.emit("%s +%d" % [tag, pts], tag_color)
	add_xp(xp_amount)


func add_score(pts: int) -> void:
	score += pts


## Remembers the run totals at the start of a wave so the end-of-wave tally
## can show what happened during this wave only.
func begin_wave_stats() -> void:
	_wave_start = {"kills": kills, "executions": executions, "headshots": headshots, "deflects": deflects}


func wave_stats() -> Dictionary:
	var out := {}
	for k in ["kills", "executions", "headshots", "deflects"]:
		out[k] = int(get(k)) - int(_wave_start.get(k, 0))
	return out


func add_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = 60.0 + (level - 1) * 40.0
		pending_levelups += 1


func show_hint_once(key: String, text: String) -> void:
	if hints_shown.has(key):
		return
	hints_shown[key] = true
	hint.emit(text)


# ---------------------------------------------------------------- high scores
func best_score() -> int:
	return Profile.best_score()


func qualifies(s: int) -> bool:
	return Profile.qualifies(s)


## Keeps the run's score the moment it ends, as "---" until initials are
## typed, so quitting on the results screen can't lose it. Sets last_rank
## (-1 if it didn't make the top 10).
func record_score() -> void:
	last_rank = -1
	if qualifies(score):
		last_rank = Profile.add_score({"name": "---", "score": score, "wave": wave, "seed": seed_string(run_seed)})


## Names the entry record_score() kept and returns its table position.
func submit_score(initials: String) -> int:
	if last_rank >= 0:
		Profile.rename_score(last_rank, initials)
	return last_rank


## This run's totals, as Profile.finish_run() and the snapshot read them.
func run_stats() -> Dictionary:
	return {"score": score, "wave": wave, "bosses": bosses_killed, "kills": kills, "glory_kills": executions,
		"headshots": headshots, "deflects": deflects, "best_combo": best_combo, "time": run_time,
		"boss_kinds": bosses_felled.duplicate()}


func _process(delta: float) -> void:
	# delta arrives scaled by last frame's time_scale; undo that to get real
	# time (works in Movie Maker renders too, unlike the wall clock)
	real_dt = minf(delta / maxf(_applied_ts, 0.001), 0.1)
	if get_tree().paused:
		Engine.time_scale = 1.0
		_applied_ts = 1.0
		return
	if _hitstop > 0.0:
		_hitstop -= real_dt
	if _slowmo_left > 0.0:
		_slowmo_left -= real_dt
	var ts := 1.0
	if _slowmo_left > 0.0:
		ts = _slowmo_scale
	if _hitstop > 0.0:
		ts = minf(ts, 0.04)
	if state == "dead":
		ts = minf(ts, 0.35)
	Engine.time_scale = ts
	_applied_ts = ts
	if state == "playing":
		run_time += real_dt
		if combo > 0:
			combo_timer -= real_dt
			if combo_timer <= 0.0:
				combo = 0
