extends Node
## The player's profile and the suspended run (spec §11.3): Player Level and
## XP, boss-reward unlocks, equipped cosmetics, the top 10, settings and
## lifetime stats. Saves on its own at the end of every run, on every unlock,
## shortly after a settings change, and on quit. Files go through SaveFile,
## so a crash at any point leaves a good copy. Spec §11.3.

signal changed

const VERSION := 1
const RUN_VERSION := 1
const PROFILE_FILE := "profile.json"
const RUN_FILE := "run.json"
const MAX_SCORES := 10
const SETTINGS_DELAY := 0.5 # seconds: a burst of slider moves writes once
const LIFETIME_KEYS := ["runs", "kills", "glory_kills", "headshots", "deflects", "bosses", "best_wave", "best_combo", "best_score"]

var dir := "user://"
var player_level := 1
var player_xp := 0
var unlocks: Array = []
var equipped := {"katana": "", "shotgun": ""}
var high_scores: Array = [] # [{name, score, wave, seed}], best first
var lifetime := {}
var boss_kills := {} # boss kind -> times felled, lifetime
var play_time := 0.0
var settings := {}
var loaded_from := "" # main | tmp | backup | new | legacy (for tests and logs)
var last_save_ok := true

var _save_in := -1.0
var _has_run := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dir = _default_dir()
	load_profile()


## Debug runs and tests keep their own profile, so they never touch the
## player's.
func _default_dir() -> String:
	var args := OS.get_cmdline_user_args()
	for a in ["--autoplay", "--juicetest", "--showcase"]:
		if args.has(a):
			return "user://debug"
	for a in OS.get_cmdline_args():
		if a.contains("gut_cmdln"):
			return "user://test"
	return "user://"


## Points the profile at another folder and loads from it (tests use this).
func use_dir(path: String) -> void:
	dir = path
	load_profile()


func profile_path() -> String:
	return dir.path_join(PROFILE_FILE)


func run_path() -> String:
	return dir.path_join(RUN_FILE)


# ---------------------------------------------------------------- load / save
func load_profile() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	_save_in = -1.0
	var path := profile_path()
	var r := SaveFile.read(path, "profile")
	var data := {}
	if r.ok:
		data = r.data
		loaded_from = r.source
		var v: int = r.version
		if v < VERSION:
			# keep the old file as it was, in case a migration ever goes wrong
			_keep_copy(path, ".v%d" % v)
			data = ProfileMigrations.migrate(data, v, VERSION)
			if data.is_empty():
				# no way up from this version: start fresh, the .v copy keeps it
				push_warning("save: can't migrate profile version %d" % v)
				loaded_from = "new"
		elif v > VERSION:
			# written by a newer build: read what we understand, and keep the
			# original so going back to the newer build loses nothing
			_keep_copy(path, ".v%d" % v)
			push_warning("save: profile is version %d, this build knows %d" % [v, VERSION])
	else:
		if r.found:
			# every copy is damaged: move them aside (never delete) and start over
			push_warning("save: no readable profile copy; starting a new one")
			SaveFile.quarantine(path)
		data = _legacy_or_empty()
	_from_dict(data)
	_has_run = not load_suspended_run().is_empty()
	if loaded_from != "main":
		save_now()
	changed.emit()


func _legacy_or_empty() -> Dictionary:
	var legacy := dir.path_join(ProfileMigrations.LEGACY_SCORES)
	if FileAccess.file_exists(legacy):
		loaded_from = "legacy"
		var v0 := ProfileMigrations.from_legacy_scores(SaveFile.read_text(legacy))
		return ProfileMigrations.migrate(v0, 0, VERSION)
	loaded_from = "new"
	return ProfileMigrations.migrate({}, 0, VERSION)


func _keep_copy(path: String, suffix: String) -> void:
	if not FileAccess.file_exists(path + suffix) and FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + suffix)


func save_now() -> bool:
	_save_in = -1.0
	last_save_ok = SaveFile.write(profile_path(), "profile", VERSION, to_dict())
	return last_save_ok


func save_soon(delay := SETTINGS_DELAY) -> void:
	_save_in = delay if _save_in < 0.0 else minf(_save_in, delay)


func _process(_delta: float) -> void:
	tick(Game.real_dt)


## Counts down a pending save in real seconds (slow-mo doesn't stretch it).
func tick(dt: float) -> void:
	if _save_in >= 0.0:
		_save_in -= dt
		if _save_in < 0.0:
			save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if _save_in >= 0.0:
			save_now()


func to_dict() -> Dictionary:
	var life := lifetime.duplicate()
	life["boss_kills"] = boss_kills.duplicate()
	life["play_time"] = play_time
	return {
		"player": {"level": player_level, "xp": player_xp},
		"unlocks": unlocks.duplicate(),
		"equipped": equipped.duplicate(),
		"high_scores": high_scores.duplicate(true),
		"lifetime": life,
		"settings": settings.duplicate(true),
	}


## Reads a profile dict defensively: anything missing or the wrong type falls
## back to its default, so a hand-edited or half-migrated file still loads.
func _from_dict(d: Dictionary) -> void:
	var p: Dictionary = _dict(d.get("player"))
	player_level = maxi(int(p.get("level", 1)), 1)
	player_xp = maxi(int(p.get("xp", 0)), 0)
	unlocks = []
	for id in _arr(d.get("unlocks")):
		if id is String and not Rewards.get_def(id).is_empty() and not unlocks.has(id):
			unlocks.append(id)
	var eq: Dictionary = _dict(d.get("equipped"))
	equipped = {}
	for slot in ["katana", "shotgun"]:
		var id := str(eq.get(slot, ""))
		equipped[slot] = id if unlocks.has(id) else ""
	high_scores = []
	for e in _arr(d.get("high_scores")):
		if e is Dictionary and e.has("score"):
			high_scores.append({"name": str(e.get("name", "---")).left(3), "score": int(e.score), "wave": int(e.get("wave", 0)), "seed": str(e.get("seed", ""))})
	_sort_scores()
	var life: Dictionary = _dict(d.get("lifetime"))
	lifetime = {}
	for k in LIFETIME_KEYS:
		lifetime[k] = maxi(int(life.get(k, 0)), 0)
	boss_kills = {}
	var bk: Dictionary = _dict(life.get("boss_kills"))
	for k in bk:
		boss_kills[str(k)] = maxi(int(bk[k]), 0)
	play_time = maxf(float(life.get("play_time", 0.0)), 0.0)
	settings = _dict(d.get("settings")).duplicate(true)


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _arr(v: Variant) -> Array:
	return v if v is Array else []


# ---------------------------------------------------------------- settings
func get_settings_dict() -> Dictionary:
	return settings.duplicate(true)


func store_settings(d: Dictionary) -> void:
	settings = d.duplicate(true)
	save_soon()


# ---------------------------------------------------------------- progress
func xp_to_next() -> int:
	return Progression.xp_to_next(player_level)


## Pays a finished run into the profile and saves. `stats` holds score,
## wave, bosses, kills, glory_kills, headshots, deflects, best_combo, time and
## boss_kinds (the bosses felled). Returns what the results screen counts up.
func finish_run(stats: Dictionary) -> Dictionary:
	var rows := Progression.run_xp(stats)
	var gained := Progression.total(rows)
	var before := [player_level, player_xp]
	var after := Progression.apply(player_level, player_xp, gained)
	player_level = after[0]
	player_xp = after[1]
	lifetime.runs += 1
	for k in [["kills", "kills"], ["glory_kills", "glory_kills"], ["headshots", "headshots"], ["deflects", "deflects"], ["bosses", "bosses"]]:
		lifetime[k[0]] += int(stats.get(k[1], 0))
	lifetime.best_wave = maxi(lifetime.best_wave, int(stats.get("wave", 0)))
	lifetime.best_combo = maxi(lifetime.best_combo, int(stats.get("best_combo", 0)))
	lifetime.best_score = maxi(lifetime.best_score, int(stats.get("score", 0)))
	play_time += float(stats.get("time", 0.0))
	save_now()
	changed.emit()
	return {"rows": rows, "xp_gained": gained, "level_before": before[0], "xp_before": before[1],
		"level_after": player_level, "xp_after": player_xp, "levels_gained": player_level - before[0]}


## Records a boss kill and unlocks that boss's next reward, if any. Saves at
## once (spec §11.2). Returns the reward unlocked, or {}.
func boss_felled(kind: String) -> Dictionary:
	boss_kills[kind] = int(boss_kills.get(kind, 0)) + 1
	var reward := Rewards.next_for_boss(kind, unlocks)
	if not reward.is_empty():
		unlocks.append(reward.id)
	save_now()
	changed.emit()
	return reward


func unlock(id: String) -> bool:
	if unlocks.has(id) or Rewards.get_def(id).is_empty():
		return false
	unlocks.append(id)
	save_now()
	changed.emit()
	return true


func is_unlocked(id: String) -> bool:
	return unlocks.has(id)


func get_equipped(slot: String) -> String:
	return str(equipped.get(slot, ""))


func equip(slot: String, id: String) -> void:
	if (id != "" and not unlocks.has(id)) or get_equipped(slot) == id:
		return
	equipped[slot] = id
	save_now()
	changed.emit()


## Equips the next owned look for a slot (stock first), for the title menu.
func cycle_equipped(slot: String) -> String:
	var opts := Rewards.choices(slot, unlocks)
	var i := opts.find(get_equipped(slot))
	equip(slot, opts[(i + 1) % opts.size()])
	return get_equipped(slot)


# ---------------------------------------------------------------- high scores
func _sort_scores() -> void:
	high_scores.sort_custom(func(a, b): return int(a.score) > int(b.score))
	if high_scores.size() > MAX_SCORES:
		high_scores.resize(MAX_SCORES)


func best_score() -> int:
	return int(high_scores[0].score) if high_scores.size() > 0 else 0


func qualifies(s: int) -> bool:
	if s <= 0:
		return false
	return high_scores.size() < MAX_SCORES or s > int(high_scores[-1].score)


## Adds an entry, saves, and returns its table position (-1 if it fell off).
func add_score(entry: Dictionary) -> int:
	high_scores.append(entry)
	_sort_scores()
	save_now()
	changed.emit()
	return high_scores.find(entry)


func rename_score(rank: int, initials: String) -> void:
	if rank < 0 or rank >= high_scores.size():
		return
	high_scores[rank].name = initials.left(3)
	save_now()
	changed.emit()


# ---------------------------------------------------------------- suspended run
func has_suspended_run() -> bool:
	return _has_run


func suspend_run(snapshot: Dictionary) -> bool:
	var ok := SaveFile.write(run_path(), "run", RUN_VERSION, snapshot)
	_has_run = _has_run or ok
	return ok


## The saved run, or {} if there is none or it can't be read. A damaged run
## file is moved aside rather than deleted.
func load_suspended_run() -> Dictionary:
	var r := SaveFile.read(run_path(), "run")
	if not r.ok:
		if r.found:
			SaveFile.quarantine(run_path())
		_has_run = false
		return {}
	_has_run = true
	if int(r.version) != RUN_VERSION:
		# run snapshots are short-lived; one from another format can't resume
		push_warning("save: run snapshot version %d can't resume" % int(r.version))
		_has_run = false
		return {}
	return r.data


## Deletes the run snapshot: called when a run ends, so reloading can't undo
## a death.
func clear_suspended_run() -> void:
	SaveFile.remove(run_path())
	_has_run = false
