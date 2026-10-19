class_name WaveDirector
extends Node3D
## Endless arcade waves. Every third wave is a boss fight; the boss order,
## wave line-ups and mutators all come from the run seed. Difficulty keeps
## climbing, so a run ends when you do.
## Enemies, bolts and blade waves live under this node, and it keeps their
## pools (spec §14): grunts, gunners, brutes and bolts are built at load and
## recycled, so a spawn or a shot never builds a node mid-fight.

## Fired between waves, after the tally (and any boss reward card), just
## before `next_wave` starts: the moment a run can be suspended.
signal between_waves(next_wave: int)

const BOSS_EVERY := 3
const BOSS_KINDS := ["ninja", "mech", "oni"]
# Raijin's Storm: a telegraphed strike near the player every few seconds
const STRIKE_FIRST := 3.0
const STRIKE_GAP := Vector2(3.5, 6.0)
const STRIKE_WARN := 1.2
const STRIKE_RADIUS := 2.4
const STRIKE_DAMAGE := 16.0
const STRIKE_SPREAD := 2.5 # metres from the player a strike may land
## Enemies built at load, per kind. The pool grows if a fight needs more.
const ENEMY_PREWARM := {"grunt": 14, "gunner": 6, "brute": 3}
## Bolts built at load, per kind ("wave" is the player's Crimson Wave).
const BOLT_PREWARM := {"bolt": 24, "shuriken": 12, "wave": 4}
## A dead enemy waits this long (game time) before it is handed out again,
## so anything still holding it (a finisher, a deflected bolt) lets go first.
const REUSE_DELAY := 2.5

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
var _rng: RandomNumberGenerator # the wave plan: mutators, line-ups, boss order
var _spawn_rng: RandomNumberGenerator # where and how enemies arrive
var _spawn_index := 0 # spawns so far this wave: each one's dice come from it
var boss_bounty := 0
var last_mutator := "" # never the same mutator twice in a row
var _strike_t := 0.0
var boss_bounty_name := ""
var pending_reward: Dictionary = {} # unlocked by this wave's boss, shown after its tally
var _enemy_pool := {} # kind -> [[Enemy, ready_at]], oldest first
var _bolt_pool := {} # kind -> [Bolt]
var _clock := 0.0


func _ready() -> void:
	_rng = Game.rng_waves
	_spawn_rng = Game.rng_spawns
	Enemy.list_dirty = true
	for kind in ENEMY_PREWARM:
		_enemy_pool[kind] = []
		for i in ENEMY_PREWARM[kind]:
			var e := Enemy.new()
			e.prewarm = true
			e.pool = self
			e.setup(kind, 1.0)
			add_child(e)
			_enemy_pool[kind].append([e, 0.0])
	for kind in BOLT_PREWARM:
		_bolt_pool[kind] = []
		for i in BOLT_PREWARM[kind]:
			var b := Bolt.new()
			b.kind = kind
			b.pool = self
			b.prewarm = true
			add_child(b)
			_bolt_pool[kind].append(b)


## One parked enemy and bolt of each kind, for the shader warm-up.
func warmup_nodes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for kind in _enemy_pool:
		if not _enemy_pool[kind].is_empty():
			out.append(_enemy_pool[kind][0][0])
	for kind in _bolt_pool:
		if not _bolt_pool[kind].is_empty():
			out.append(_bolt_pool[kind][0])
	return out


## Takes a dead pooled enemy back (called from Enemy.die).
func recycle(e: Enemy) -> void:
	_enemy_pool[e.kind].append([e, _clock + REUSE_DELAY])


## Takes a spent bolt back (called by the bolt).
func recycle_bolt(b: Bolt) -> void:
	_bolt_pool[b.kind].append(b)


## Fires a bolt from the pool: hostile bolts and shuriken from enemies, or
## the player's Crimson Wave. Returns it so the caller can adjust it.
## `from` is the enemy firing it; a deflect sends the bolt back to it.
func fire_bolt(is_hostile: bool, pos: Vector3, velocity: Vector3, dmg: float, k := "bolt", from: Enemy = null) -> Bolt:
	var free: Array = _bolt_pool[k]
	if free.is_empty():
		var nb := Bolt.new()
		nb.pool = self
		nb.setup(is_hostile, pos, velocity, dmg, k, from)
		add_child(nb)
		return nb
	var b: Bolt = free.pop_back()
	b.reuse()
	b.setup(is_hostile, pos, velocity, dmg, k, from)
	b.activate()
	return b


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
	plan_wave(wave)
	_strike_t = STRIKE_FIRST
	boss_bounty = 0
	boss_bounty_name = ""
	phase = "intro"
	phase_t = 6.0 # fallback; the HUD's countdown normally ends the intro
	if is_boss_wave(wave):
		Game.hud.wave_intro(wave, "BOSS INCOMING", Color(Game.palette.neon_a), true)
		Sfx.play("alarm", -3.0)
	else:
		var sub := ""
		if not Game.mutator.is_empty():
			# two lines: the name and its score, then what it does
			sub = "%s  //  SCORE x%.1f\n%s" % [Game.mutator.name, Game.mutator.score, Game.mutator.desc]
		Game.hud.wave_intro(wave, sub, Color.WHITE, false)
		Sfx.play("riser", -6.0)
	Game.arena.set_storm(bool(Game.mut("storm", false)))
	if Game.debug_autoplay:
		# tools/seed_check.sh compares these lines between two runs of a seed
		print("[plan] wave %d mut=%s boss=%s lineup=%s" % [wave, Game.mutator.get("id", "-"), boss_kind if is_boss_wave(wave) else "-", _lineup_code()])
	if wave == 1:
		Game.hint.emit("KATANA KILLS CHARGE THE SHOTGUN  -  KEEP BOTH HANDS BUSY")


## Seeds are law (spec §7.5): reseeds the wave streams from the seed and `w`,
## then rolls the wave's plan (its mutator and line-up, or its boss). Only
## the seed and the plans of the waves before decide it, never how they
## were played.
func plan_wave(w: int) -> void:
	Game.seed_wave(w)
	_spawn_index = 0
	if is_boss_wave(w):
		Game.mutator = {}
		boss_kind = _next_boss()
		queue = []
		return
	Game.mutator = Mutators.roll(_rng, w, last_mutator)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mutator="):
			# debug: force one on every regular wave (the roll still draws)
			Game.mutator = Mutators.get_def(a.substr(10))
	if not Game.mutator.is_empty():
		last_mutator = Game.mutator.id
	queue = _composition(w)


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


## The queued line-up as one letter per enemy (g grunt, n gunner, b brute),
## for the autoplay log.
func _lineup_code() -> String:
	var out := ""
	for item in queue:
		out += {"grunt": "g", "gunner": "n", "brute": "b"}.get(item[0], "?")
	return out


func _max_alive() -> int:
	return int(mini(8 + wave * 2, 22) * float(Game.mut("max_alive", 1.0)))


func _pick_spawn() -> Vector3:
	var p := Game.player.global_position
	var cands: Array[Vector3] = []
	for sp in Game.arena.spawn_points:
		var d := sp.distance_to(p)
		if d > 11.0 and d < 46.0:
			cands.append(sp)
	if cands.is_empty():
		return Game.arena.spawn_points[_spawn_rng.randi() % Game.arena.spawn_points.size()]
	return cands[_spawn_rng.randi() % cands.size()]


func _spawn(kind: String, scale: float, pos: Vector3, before_ready := Callable()) -> Enemy:
	var at := pos + Vector3(0, minf(7.0 + _spawn_rng.randf() * 2.0, Game.arena.spawn_clearance(pos)), 0)
	# each enemy's own dice (timers, strafing, drops) come from the seed, the
	# wave and its place in the wave's spawn order
	_spawn_index += 1
	var dice := hash([Game.run_seed, wave, _spawn_index, "dice"]) & 0x7fffffff
	var free: Array = _enemy_pool.get(kind, [])
	if not free.is_empty() and free[0][1] <= _clock:
		# only horde kinds are pooled, so `before_ready` (bosses) never runs here
		assert(not before_ready.is_valid(), "pooled spawns take no before_ready")
		var pe: Enemy = free.pop_front()[0]
		pe.reuse()
		pe.setup(kind, scale)
		pe.dice_seed = dice
		pe.position = at
		pe.activate()
		return pe
	var e: Enemy
	if kind in BOSS_KINDS:
		e = Boss.new()
	else:
		e = Enemy.new()
	if _enemy_pool.has(kind):
		e.pool = self
	e.setup(kind, scale)
	e.dice_seed = dice
	e.position = at
	if before_ready.is_valid():
		before_ready.call(e)
	add_child(e)
	return e


## Reinforcements, called by bosses (the mech radios for help).
func spawn_adds(n: int, near: Vector3) -> void:
	for i in n:
		var a := _spawn_rng.randf() * TAU
		var p := near + Vector3(cos(a), 0, sin(a)) * _spawn_rng.randf_range(4.0, 7.0)
		var lim := Game.arena.half - 2.0
		p.x = clampf(p.x, -lim, lim)
		p.z = clampf(p.z, -lim, lim)
		p.y = near.y
		p = Game.arena.safe_point(p)
		_spawn("grunt" if i % 3 != 2 else "gunner", hp_scale(wave), p)


func _spawn_boss() -> void:
	var cycle_scale := 1.0 + 0.45 * (_cycle_count - 1) + 0.03 * (wave - 3)
	boss = _spawn(boss_kind, cycle_scale, Game.arena.boss_spawn, func(b: Boss) -> void:
		b.cycle = _cycle_count
		# the boss's own dice come from the seed without drawing from the
		# wave stream, so the same seed gives the same fight
		b.dice_seed = hash(Game.run_seed * 13 + wave) & 0x7fffffff)
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
	_clock += delta
	if Enemy.list_dirty:
		Enemy.list_dirty = false
		Game.enemy_list = get_tree().get_nodes_in_group("enemies")
	if Game.state != "playing":
		return
	if not _cleanup.is_empty():
		_cleanup_t -= delta
		if _cleanup_t <= 0.0:
			_cleanup_t = 0.12
			var e = _cleanup.pop_front()
			if is_instance_valid(e) and not e.dead:
				e.die("explode", Vector3(Game.rng_fx.randf_range(-1, 1), 0, Game.rng_fx.randf_range(-1, 1)))
	if phase in ["spawning", "boss"] and Game.mut("strikes", false):
		_storm_strikes(delta)
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
				var group := mini(_spawn_rng.randi_range(1, 3), queue.size())
				for i in group:
					var item: Array = queue.pop_front()
					var off := Vector3(_spawn_rng.randf_range(-2.0, 2.0), 0, _spawn_rng.randf_range(-2.0, 2.0)) if i > 0 else Vector3.ZERO
					_spawn(item[0], item[1], sp + off)
				spawn_t = maxf(0.8, 1.8 - wave * 0.06) * float(Game.mut("spawn_rate", 1.0))
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
			# a level-up earned on the last kills opens after the tally, before
			# the reward card and the next wave's intro (they never share the screen)
			if (Game.hud.tally_ready() or phase_t <= 0.0) and Game.pending_levelups == 0:
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


## Raijin's Storm: lightning picks a spot near the player (from the hazard
## stream), rings it red for STRIKE_WARN seconds, then hits everything there.
func _storm_strikes(delta: float) -> void:
	_strike_t -= delta
	if _strike_t > 0.0:
		return
	var r := Game.rng_hazards
	_strike_t = r.randf_range(STRIKE_GAP.x, STRIKE_GAP.y)
	var a := r.randf() * TAU
	var p := Game.player.global_position + Vector3(cos(a), 0, sin(a)) * r.randf_range(0.0, STRIKE_SPREAD)
	Game.fx.missile_strike(p, STRIKE_WARN, STRIKE_RADIUS, STRIKE_DAMAGE, "lightning")


## End-of-wave tally, chips x mult: what you did this wave adds chips, the
## wave number, a flawless clear and the mutator multiply them.
func _wave_cleared() -> void:
	phase = "clear"
	Game.fx.clear_strikes()
	phase_t = 12.0 # fallback; the HUD's tally normally ends the clear phase
	var st := Game.wave_stats()
	var rows: Array = [["WAVE CLEAR", "", 250 * wave]]
	for spec in [["KILLS", "kills", 25], ["GLORY KILLS", "executions", 200], ["HEADSHOTS", "headshots", 75], ["DEFLECTS", "deflects", 100], ["PERFECT DEFLECTS", "perfect_deflects", 150]]:
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
