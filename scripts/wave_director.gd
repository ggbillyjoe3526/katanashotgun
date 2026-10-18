class_name WaveDirector
extends Node3D
## Endless arcade waves. Every third wave is a boss fight; the boss order,
## wave line-ups and mutators all come from the run seed. Difficulty keeps
## climbing, so a run ends when you do.
## Enemies, bolts and blade waves live under this node.

## Fired between waves, after the tally (and any boss reward card), just
## before `next_wave` starts: the moment a run can be suspended.
signal between_waves(next_wave: int)

const BOSS_EVERY := 3
const BOSS_KINDS := ["ninja", "mech", "oni"]

var wave := 0
var queue: Array = []
var spawn_t := 0.0
var phase := "idle"
var phase_t := 0.0
var boss: Enemy = null
var boss_kind := ""
var _adds_t := 0.0
var _boss_cycle: Array = []
var _cycle_count := 0
var _cleanup: Array = []
var _cleanup_t := 0.0
var _rng: RandomNumberGenerator
var boss_bounty := 0
var boss_bounty_name := ""
var pending_reward: Dictionary = {} # unlocked by this wave's boss, shown after its tally


func _ready() -> void:
	_rng = Game.rng_waves


func start(first_wave := 1) -> void:
	wave = first_wave - 1
	_next_wave()


func hostiles_left() -> int:
	return queue.size() + Game.enemy_list.size()


func is_boss_wave(w: int) -> bool:
	return w % BOSS_EVERY == 0


func hp_scale(w: int) -> float:
	return 1.0 + 0.06 * (w - 1) + 0.05 * maxf(0.0, w - 9)


func _next_boss() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boss="):
			return a.substr(7)
	if _boss_cycle.is_empty():
		_cycle_count += 1
		if _cycle_count == 1:
			# first cycle ramps up: the two lighter bosses in seeded order, ONI last
			_boss_cycle = ["ninja", "mech"]
			if _rng.randf() < 0.5:
				_boss_cycle.reverse()
			_boss_cycle.append("oni")
		else:
			_boss_cycle = BOSS_KINDS.duplicate()
			for i in range(_boss_cycle.size() - 1, 0, -1):
				var j := _rng.randi_range(0, i)
				var tmp = _boss_cycle[i]
				_boss_cycle[i] = _boss_cycle[j]
				_boss_cycle[j] = tmp
	return _boss_cycle.pop_front()


func _next_wave() -> void:
	wave += 1
	Game.wave = wave
	Game.wave_damage = 0.0
	Game.begin_wave_stats()
	boss_bounty = 0
	boss_bounty_name = ""
	phase = "intro"
	phase_t = 6.0 # fallback; the HUD's countdown normally ends the intro
	if is_boss_wave(wave):
		Game.mutator = {}
		boss_kind = _next_boss()
		queue = []
		Game.hud.wave_intro(wave, "BOSS INCOMING", Color(Game.palette.neon_a), true)
		Sfx.play("alarm", -3.0)
	else:
		Game.mutator = Mutators.roll(_rng, wave)
		queue = _composition(wave)
		var sub := ""
		if not Game.mutator.is_empty():
			# two lines: the name and its score, then what it does
			sub = "%s  //  SCORE x%.1f\n%s" % [Game.mutator.name, Game.mutator.score, Game.mutator.desc]
		Game.hud.wave_intro(wave, sub, Color.WHITE, false)
		Sfx.play("riser", -6.0)
	Game.arena.set_storm(bool(Game.mut("storm", false)))
	if wave == 1:
		Game.hint.emit("KATANA KILLS CHARGE THE SHOTGUN  -  KEEP BOTH HANDS BUSY")


func _composition(w: int) -> Array:
	var scale := hp_scale(w)
	var grunts := int((5 + w * 2) * float(Game.mut("grunt_count", 1.0)))
	var gunners := 0 if w < 2 else int(mini(1 + (w - 2), 9) * float(Game.mut("gunner_count", 1.0)))
	var brutes := 0 if w < 4 else 1 + (w - 4) / 3
	brutes += int(Game.mut("extra_brutes", 0))
	var rest := []
	for i in grunts:
		rest.append(["grunt", scale])
	for i in gunners:
		rest.append(["gunner", scale])
	for i in range(rest.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	for i in brutes:
		var at := _rng.randi_range(rest.size() / 3, rest.size())
		rest.insert(at, ["brute", scale])
	return rest


func _max_alive() -> int:
	return mini(8 + wave * 2, 22)


func _pick_spawn() -> Vector3:
	var p := Game.player.global_position
	var cands: Array[Vector3] = []
	for sp in Game.arena.spawn_points:
		var d := sp.distance_to(p)
		if d > 11.0 and d < 46.0:
			cands.append(sp)
	if cands.is_empty():
		return Game.arena.spawn_points[_rng.randi() % Game.arena.spawn_points.size()]
	return cands[_rng.randi() % cands.size()]


func _spawn(kind: String, scale: float, pos: Vector3) -> Enemy:
	var e: Enemy
	if kind in ["ninja", "mech"]:
		e = Boss.new()
	else:
		e = Enemy.new()
	e.setup(kind, scale)
	e.position = pos + Vector3(0, 7.0 + _rng.randf() * 2.0, 0)
	add_child(e)
	return e


## Reinforcements, called by bosses (the mech radios for help).
func spawn_adds(n: int, near: Vector3) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var p := near + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(4.0, 7.0)
		var lim := Game.arena.half - 2.0
		p.x = clampf(p.x, -lim, lim)
		p.z = clampf(p.z, -lim, lim)
		p.y = 0.0
		_spawn("grunt" if i % 3 != 2 else "gunner", hp_scale(wave), p)


func _spawn_boss() -> void:
	var cycle_scale := 1.0 + 0.45 * (_cycle_count - 1) + 0.03 * (wave - 3)
	boss = _spawn(boss_kind, cycle_scale, Game.arena.boss_spawn)
	Game.main.boss = boss
	Game.hud.show_boss_intro(boss.display_name, boss.subtitle)
	Sfx.play("boss_intro", 0.0)
	Sfx.play_boss_music(boss_kind)
	Game.show_hint_once("kamae", "KEEP ATTACKING TO FILL ITS KAMAE BAR - A FULL BAR BREAKS IT")
	_adds_t = 8.0


func on_boss_killed(b: Enemy) -> void:
	# the bounty is paid out in the end-of-wave tally
	boss_bounty = 2000 * wave
	boss_bounty_name = b.display_name
	# the boss's minions short out on the spot, then pop in a chain reaction
	_cleanup = Game.enemy_list.duplicate()
	for e in _cleanup:
		if is_instance_valid(e) and e != b:
			e.frozen = true
			e.shock(3.0)
	_cleanup_t = 0.6
	boss = null


func _physics_process(delta: float) -> void:
	Game.enemy_list = get_tree().get_nodes_in_group("enemies")
	if Game.state != "playing":
		return
	if not _cleanup.is_empty():
		_cleanup_t -= delta
		if _cleanup_t <= 0.0:
			_cleanup_t = 0.12
			var e = _cleanup.pop_front()
			if is_instance_valid(e) and not e.dead:
				e.die("explode", Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	match phase:
		"intro":
			phase_t -= delta
			if Game.hud.intro_ready() or phase_t <= 0.0:
				phase = "boss" if is_boss_wave(wave) else "spawning"
				spawn_t = 0.0
				if phase == "boss":
					_spawn_boss()
		"spawning":
			spawn_t -= delta
			var alive := Game.enemy_list.size()
			if not queue.is_empty() and spawn_t <= 0.0 and alive < _max_alive():
				var sp := _pick_spawn()
				var group := mini(_rng.randi_range(1, 3), queue.size())
				for i in group:
					var item: Array = queue.pop_front()
					var off := Vector3(_rng.randf_range(-2.0, 2.0), 0, _rng.randf_range(-2.0, 2.0)) if i > 0 else Vector3.ZERO
					_spawn(item[0], item[1], sp + off)
				spawn_t = maxf(0.8, 1.8 - wave * 0.06)
			if queue.is_empty() and alive == 0:
				_wave_cleared()
		"boss":
			if boss != null and is_instance_valid(boss) and not boss.dead:
				_adds_t -= delta
				var adds := Game.enemy_list.size() - 1
				if _adds_t <= 0.0:
					_adds_t = 7.0 if boss_kind != "mech" else 10.0
					if adds < 4:
						var sp := _pick_spawn()
						_spawn("grunt", hp_scale(wave), sp)
						if adds < 2:
							_spawn("grunt", hp_scale(wave), sp + Vector3(1.5, 0, 1.0))
			elif _cleanup.is_empty() and Game.enemy_list.is_empty() and Game.hud.card_ready():
				_wave_cleared()
		"clear":
			phase_t -= delta
			if Game.hud.tally_ready() or phase_t <= 0.0:
				if pending_reward.is_empty():
					_end_break()
				else:
					# spec §11.2: the reward card follows the boss tally
					phase = "reward"
					phase_t = 8.0 # fallback; the card normally ends the phase
					Game.hud.show_reward(pending_reward)
					pending_reward = {}
		"reward":
			phase_t -= delta
			if Game.hud.reward_ready() or phase_t <= 0.0:
				_end_break()


func _end_break() -> void:
	between_waves.emit(wave + 1)
	_next_wave()


## End-of-wave tally, chips x mult: what you did this wave adds chips, the
## wave number, a flawless clear and the mutator multiply them.
func _wave_cleared() -> void:
	phase = "clear"
	phase_t = 12.0 # fallback; the HUD's tally normally ends the clear phase
	var st := Game.wave_stats()
	var rows: Array = [["WAVE CLEAR", "", 250 * wave]]
	for spec in [["KILLS", "kills", 25], ["GLORY KILLS", "executions", 200], ["HEADSHOTS", "headshots", 75], ["DEFLECTS", "deflects", 100]]:
		var n: int = st[spec[1]]
		if n > 0:
			rows.append([spec[0], "%d X %d" % [n, spec[2]], n * int(spec[2])])
	if boss_bounty > 0:
		rows.append(["BOSS BOUNTY", boss_bounty_name, boss_bounty])
	var chips := 0
	for r in rows:
		chips += int(r[2])
	var flawless := Game.wave_damage <= 0.0
	var mults: Array = [["WAVE %d" % wave, 1.0 + 0.1 * wave]]
	if flawless:
		mults.append(["FLAWLESS", 1.5])
	var ms := float(Game.mut("score", 1.0))
	if not Game.mutator.is_empty() and ms != 1.0:
		mults.append([str(Game.mutator.name), ms])
	var mult := 1.0
	for m in mults:
		mult *= float(m[1])
	var total := int(round(chips * mult))
	Game.add_score(total)
	if Game.debug_autoplay:
		print("[tally] wave %d chips=%d mult=%.2f total=%d rows=%s" % [wave, chips, mult, total, str(rows)])
	Game.hud.show_tally({"title": "WAVE %02d // CLEAR" % wave, "rows": rows, "chips": chips, "mults": mults, "total": total, "flawless": flawless, "boss": boss_bounty > 0})
	Sfx.play("wave_clear", -5.0)
	Game.player.add_cells(2)
	Game.mutator = {}
	Game.arena.set_storm(false)
