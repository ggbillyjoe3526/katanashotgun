class_name Boss
extends Enemy
## Every boss. The ninja and the mech live here; the ONI's body and basic
## moves live in enemy.gd, and its newer moves here.
##   ninja  KUROKAGE, BLADE OF THE NULL SIGNAL: telegraphed dash-slash chains, shuriken
##          fans you can deflect, and blinking behind you.
##   mech   TETSUGUMO, CHROME BROODMOTHER: sweeping gatling, missile strikes marked
##          on the floor, stomp shockwaves, and calls reinforcements.
## Both are armoured. Like every boss they never stagger from poise: pressure
## fills their KAMAE bar, and a full bar breaks them for the ONIKIRI blow.
## Souls-style movesets on top (spec §5.6): every boss sidesteps lazy
## ranged play, holds some swings a beat longer, has one area move and one
## RED SIGNAL attack, and leaves a punish window after each big move.

# sidestep: aimed at from range for this long, it steps out of the line
const SIDESTEP_AIM := 0.35
const SIDESTEP_RANGE := 7.0
const SIDESTEP_CONE := 0.1 # radians around the body
const SIDESTEP_CD := 4.0
const GENTLE_SIDESTEP_CD := 6.0
# delayed swings: some windups hold longer; the eyes flare just before the hit
const DELAY_CHANCE := 0.3
const DELAY_MULT := 1.7
const DELAY_FLARE := 0.22
# the run's first boss telegraphs its big moves this much longer
const GENTLE_TELE := 1.25
const RED_CD := 14.0
const AREA_CD := 8.0
const RED_LEN := {"ninja": 0.9, "mech": 1.0, "oni": 1.0}
const PERFECT_KAMAE := 0.15 # dashing through a RED SIGNAL attack
const RED_COLOR := Color(1.0, 0.1, 0.15)
# NULL CROSS
const CROSS_LEN := 18.0
const CROSS_SPEED := 34.0
const CROSS_GAP := 0.25
# DAEMON GRAB
const GRAB_TIME := 0.45
const GRAB_SPEED := 17.0

var dash_dir := Vector3.ZERO
var dash_count := 0
var dash_hit := false
var _line: Node3D = null
var _gat_t := 0.0
var _gat_aim := 0.0
var _legs: Array = []
var _chassis: Node3D
var _barrel_glow: ShaderMaterial
var _pods_glow: ShaderMaterial
var _followup := false
var cycle := 1 # which boss cycle this is (1 = waves 3, 6, 9)
var _aim_t := 0.0
var _sidestep_cd := 0.0
var _side_dir := Vector3.ZERO
var _delay_k := 1.0
var _flared := false
var _red_cd := 6.0
var _area_cd := 4.0
var _area_len := 0.0
var _beeped := false
var _step := 0
var _lines: Array = [] # NULL CROSS: [start, dir] per line
var _lunge := Vector3.ZERO
var _perfect := false
var _hit_done := false
var _red_mark: MeshInstance3D


func setup(k: String, scale_mult := 1.0) -> void:
	kind = k
	is_boss = true
	match k:
		"ninja":
			hp = 2600.0; speed = 5.2; radius = 0.5; height = 2.1; head_y = 1.72
			stagger_time = 2.6; armor = 0.55; xp = 320.0; points = 5000; mass = 3.0; kamae_max = 900.0
			display_name = "KUROKAGE"; subtitle = "BLADE OF THE NULL SIGNAL"; defeat_text = "SHADOW DELETED"
		"mech":
			hp = 4400.0; speed = 2.6; radius = 1.7; height = 3.6; head_y = 2.5
			stagger_time = 3.2; armor = 0.35; xp = 420.0; points = 7000; mass = 14.0; kamae_max = 1400.0
			display_name = "TETSUGUMO"; subtitle = "CHROME BROODMOTHER"; defeat_text = "MACHINE DECOMMISSIONED"
		_:
			super.setup(k, scale_mult)
			return
	_finish_setup(scale_mult)


# ---------------------------------------------------------------- bodies
func _build_body() -> void:
	if kind == "mech":
		_build_mech()
	else:
		super._build_body()
	# the RED SIGNAL warning: a red diamond over the head
	var sz := 0.42 * clampf(height / 2.1, 1.0, 1.6)
	_red_mark = Psx.box(Vector3.ONE * sz, Psx.unlit(RED_COLOR, 4.0), Vector3(0, height + 1.1, 0))
	_red_mark.rotation = Vector3(PI * 0.25, 0, PI * 0.25)
	_red_mark.visible = false
	add_child(_red_mark)
	if kind == "ninja":
		var s := height / 1.8
		var neon: Color = Game.palette.neon_a
		var neon_b: Color = Game.palette.neon_b
		# long glowing blade in the right hand
		var ar: Node3D = arm_r.get_child(0)
		var blade := Psx.box(Vector3(0.04, 0.04, 1.5) * s, _mat(Color(0.75, 0.78, 0.85), "noise"), Vector3(0, -0.32 * s, 0.7 * s))
		blade.add_child(Psx.box(Vector3(0.05, 0.015, 1.5) * s, Psx.unlit(neon, 3.2), Vector3(0, -0.025 * s, 0)))
		ar.add_child(blade)
		# neon trim and a trailing scarf
		var torso := torso_pivot.get_node("Torso")
		torso.add_child(Psx.box(Vector3(0.5, 0.04, 0.32) * s, Psx.unlit(neon, 2.6), Vector3(0, 0.05 * s, 0)))
		torso.add_child(Psx.box(Vector3(0.04, 0.4, 0.32) * s, Psx.unlit(neon_b, 2.2), Vector3(0.12 * s, 0, 0)))
		for i in 2:
			var scarf := Psx.box(Vector3(0.08, 0.04, 0.9) * s, Psx.unlit(neon, 1.6), Vector3((i - 0.5) * 0.12 * s, 0.32 * s, -0.55 * s))
			scarf.rotation.x = 0.35
			torso.add_child(scarf)
		# neon piping on every limb so the dark suit reads against the floor
		for limb in [arm_l, arm_r, leg_l, leg_r]:
			var mesh: Node3D = limb.get_child(0)
			var strip_col := neon if limb in [arm_l, arm_r] else neon_b
			mesh.add_child(Psx.box(Vector3(0.03, 0.55, 0.03) * s, Psx.unlit(strip_col, 2.6), Vector3(0.07 * s, 0, 0.07 * s)))
			mesh.add_child(Psx.box(Vector3(0.03, 0.55, 0.03) * s, Psx.unlit(strip_col, 2.6), Vector3(-0.07 * s, 0, 0.07 * s)))


func _build_mech() -> void:
	visual = Node3D.new()
	add_child(visual)
	var dark := _mat(Color(0.16, 0.15, 0.2), "panel")
	var plate := _mat(Color(0.32, 0.3, 0.38), "chrome")
	var neon: Color = Game.palette.neon_a
	var neon_c: Color = Game.palette.neon_c
	_eye_color = neon
	_eye_mat = Psx.unlit(Color(1.0, 0.15, 0.2), 3.2, null, {"fog_amount": 0.2})
	_leg_len = 2.3
	# dummies so the humanoid helpers stay safe
	hips = Node3D.new()
	visual.add_child(hips)
	torso_pivot = Node3D.new()
	hips.add_child(torso_pivot)
	leg_l = Node3D.new()
	leg_r = Node3D.new()
	arm_l = Node3D.new()
	arm_r = Node3D.new()
	visual.add_child(leg_l)
	visual.add_child(leg_r)
	visual.add_child(arm_l)
	visual.add_child(arm_r)
	_chassis = Node3D.new()
	_chassis.position.y = 2.3
	visual.add_child(_chassis)
	var body := _part(_chassis, "Torso", Vector3(3.0, 0.9, 3.4), plate, Vector3.ZERO)
	body.add_child(Psx.box(Vector3(3.05, 0.08, 3.45), Psx.unlit(neon, 2.4), Vector3(0, -0.42, 0)))
	_part(_chassis, "Turret", Vector3(1.7, 0.7, 1.9), dark, Vector3(0, 0.75, -0.1))
	head_mesh = _part(_chassis, "Core", Vector3(1.1, 0.55, 0.35), dark, Vector3(0, 0.55, 1.05))
	for i in 3:
		head_mesh.add_child(Psx.box(Vector3(0.18, 0.18, 0.06), _eye_mat, Vector3(-0.32 + i * 0.32, 0.02, 0.18)))
	# gatling on the right
	var gat := _part(_chassis, "Gatling", Vector3(0.45, 0.45, 1.9), dark, Vector3(1.75, 0.2, 0.7))
	_barrel_glow = Psx.unlit(neon_c, 1.0)
	for i in 4:
		var bar := Psx.box(Vector3(0.09, 0.09, 0.8), plate, Vector3(cos(i * PI * 0.5) * 0.14, sin(i * PI * 0.5) * 0.14, 1.25))
		gat.add_child(bar)
	gat.add_child(Psx.box(Vector3(0.36, 0.36, 0.06), _barrel_glow, Vector3(0, 0, 1.66)))
	muzzle = Node3D.new()
	muzzle.position = Vector3(1.75, 0.2, 2.4)
	_chassis.add_child(muzzle)
	# missile pods on the turret
	_pods_glow = Psx.unlit(neon_c, 1.0)
	for sx in [-1.0, 1.0]:
		var pod := _part(_chassis, "Pod", Vector3(0.7, 0.5, 1.0), dark, Vector3(sx * 0.9, 1.25, -0.4))
		for r in 2:
			for c in 3:
				pod.add_child(Psx.box(Vector3(0.14, 0.14, 0.04), _pods_glow, Vector3(-0.2 + c * 0.2, -0.1 + r * 0.2, 0.51)))
	# six legs
	for i in 6:
		var side := -1.0 if i < 3 else 1.0
		var row := i % 3
		var hip := Node3D.new()
		hip.position = Vector3(side * 1.45, 0.0, -1.1 + row * 1.1)
		_chassis.add_child(hip)
		var upper := _part(hip, "LegU", Vector3(1.6, 0.26, 0.26), dark, Vector3(side * 0.75, 0.45, 0))
		upper.rotation.z = side * 0.55
		var knee := Node3D.new()
		knee.position = Vector3(side * 1.45, 0.85, 0)
		hip.add_child(knee)
		var lower := _part(knee, "LegL", Vector3(0.22, 3.0, 0.22), plate, Vector3(side * 0.2, -1.45, 0))
		lower.rotation.z = side * 0.14
		lower.add_child(Psx.box(Vector3(0.24, 0.6, 0.06), Psx.unlit(neon, 2.0), Vector3(0, -0.9, 0.12)))
		_legs.append({"hip": hip, "knee": knee, "phase": (0.0 if (i % 2 == 0) == (side < 0) else PI), "side": side})
	marker = Psx.quad(Vector2(0.8, 0.8), Psx.fx(MARKER_RED, TexGen.get_tex("star"), true, true, true, 2.5), Vector3(0, height + 0.9, 0))
	marker.visible = false
	add_child(marker)


func _animate(delta: float, spd: float) -> void:
	if kind != "mech":
		super._animate(delta, spd)
		return
	walk_phase += spd * delta * 1.6
	var k := 1.0 - exp(-10.0 * delta)
	var lift := 0.0
	match state:
		S.STOMP_WINDUP, S.AREA_WINDUP:
			lift = clampf(state_t / (0.8 * _delay_k), 0.0, 1.0) * 0.8
		S.STAGGER:
			lift = -0.9
		S.SIDESTEP:
			lift = 0.5
		S.MISSILE_WINDUP:
			_pods_glow.set_shader_parameter("energy", 1.0 + clampf(state_t / 0.7, 0.0, 1.0) * 5.0)
		S.RED_WINDUP:
			_pods_glow.set_shader_parameter("energy", 1.0 + clampf(state_t / _red_len(), 0.0, 1.0) * 7.0)
	if state != S.MISSILE_WINDUP and state != S.RED_WINDUP:
		_pods_glow.set_shader_parameter("energy", 1.0)
	_chassis.position.y = lerpf(_chassis.position.y, 2.3 + lift + sin(walk_phase * 2.0) * 0.05, k)
	_chassis.rotation.x = lerpf(_chassis.rotation.x, (0.25 if state == S.STAGGER else 0.0), k)
	for leg in _legs:
		var ph: float = walk_phase + leg.phase
		var moving := clampf(spd / maxf(speed, 0.1), 0.0, 1.0)
		leg.hip.rotation.y = sin(ph) * 0.35 * moving * leg.side
		leg.knee.rotation.z = maxf(0.0, cos(ph)) * 0.3 * moving * leg.side


# ---------------------------------------------------------------- AI
func _windup_time() -> float:
	var base := 0.0
	if kind == "ninja":
		base = 0.3 if _followup else 0.45
	elif kind == "mech":
		base = 0.6
	else:
		base = super._windup_time()
	return base * _delay_k


func _physics_process(delta: float) -> void:
	if not dead and not frozen:
		_boss_tick(delta)
	super._physics_process(delta)


func _set_state(s: S) -> void:
	super._set_state(s)
	if s == S.WINDUP or s == S.STOMP_WINDUP:
		# a held swing: the pose rises slower and the eyes stay dim until
		# just before it lands, so mashing dash early gets punished
		_delay_k = DELAY_MULT if _rng.randf() < DELAY_CHANCE else 1.0
		_flared = false
		if _delay_k > 1.0:
			_eye_mat.set_shader_parameter("energy", 1.0)
	elif s == S.RECOVER and recover_time >= 0.8:
		# the punish window after a big move
		exposed_t = recover_time + (0.2 if _gentle() else 0.0)
		_eye_mat.set_shader_parameter("energy", 0.8)
	elif s == S.CHASE:
		_eye_mat.set_shader_parameter("energy", 6.0 if enraged else 3.0)


## The run's first boss is the gentlest: longer telegraphs on its big moves.
func _gentle() -> bool:
	return cycle <= 1 and Game.bosses_killed == 0


func _tele() -> float:
	return GENTLE_TELE if _gentle() else 1.0


## The first cycle keeps its area move and RED SIGNAL for after the enrage.
func _big_moves_on() -> bool:
	return cycle >= 2 or enraged


func _red_len() -> float:
	return float(RED_LEN.get(kind, 1.0)) * _tele()


func _boss_tick(delta: float) -> void:
	_sidestep_cd -= delta
	_red_cd -= delta
	_area_cd -= delta
	_track_aim(delta)
	_red_mark.visible = state == S.RED_WINDUP
	if _red_mark.visible:
		_red_mark.rotation.y += delta * 4.0
		_red_mark.scale = Vector3.ONE * (1.0 + 0.2 * sin(state_t * 18.0))
	# a held swing flares its eyes and hisses just before it lands
	if _delay_k > 1.0 and not _flared and (state == S.WINDUP or state == S.STOMP_WINDUP):
		var wt := _windup_time() if state == S.WINDUP else 0.8 * _delay_k
		if state_t >= wt - DELAY_FLARE:
			_flared = true
			_eye_mat.set_shader_parameter("energy", 7.0)
			Sfx.play_at("windup", global_position, 0.0, 1.8)


## Counts how long the player has held its sights on the boss from range.
func _track_aim(delta: float) -> void:
	var p := Game.player
	if p == null or p.dead or p.cam == null:
		_aim_t = 0.0
		return
	var to := global_position + Vector3(0, height * 0.6, 0) - p.cam.global_position
	var d := to.length()
	if d < SIDESTEP_RANGE + radius or (-p.cam.global_basis.z).angle_to(to) > SIDESTEP_CONE + atan(radius / d):
		_aim_t = 0.0
		return
	_aim_t += delta


func _chase(dist: float, dir: Vector3, delta: float) -> Vector3:
	if _try_sidestep(dir) or _try_big_move(dist, dir):
		return Vector3.ZERO
	match kind:
		"ninja":
			return _chase_ninja(dist, dir, delta)
		"mech":
			return _chase_mech(dist, dir, delta)
	return super._chase(dist, dir, delta)


func _enrage_check() -> void:
	if not enraged and hp < max_hp * 0.5:
		enraged = true
		speed *= 1.2
		Sfx.play("roar", 2.0, 1.2 if kind == "ninja" else 0.5)
		Game.hud_message.emit("%s IS ENRAGED" % display_name, Color(1, 0.2, 0.3), false)
		_eye_mat.set_shader_parameter("energy", 6.0)


func _chase_ninja(dist: float, dir: Vector3, delta: float) -> Vector3:
	_enrage_check()
	if special_cd <= 0.0 and dist > 3.0:
		special_cd = _rng.randf_range(2.2, 3.2) if enraged else _rng.randf_range(3.2, 4.6)
		special_seq += 1
		match special_seq % 3:
			0, 1:
				if special_seq % 3 == 1:
					dash_count = 3 if enraged else 2
					_begin_dash_windup(dir)
				else:
					_set_state(S.VOLLEY_WINDUP)
					Sfx.play_at("windup", global_position, 0.0, 1.6)
			2:
				_set_state(S.BLINK)
				Game.fx.smoke(global_position + Vector3(0, 1.0, 0), 2.0)
				Sfx.play_at("blink", global_position, 0.0)
		return Vector3.ZERO
	if dist < 2.6 + radius and attack_cd <= 0.0:
		combo_left = 3 if enraged else 2
		_followup = false
		_set_state(S.WINDUP)
		Sfx.play_at("windup", global_position, -2.0, 1.4)
		return Vector3.ZERO
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe = -strafe
		strafe_t = _rng.randf_range(1.0, 2.0)
	if dist > 7.0:
		return dir * speed
	return (Vector3(-dir.z, 0, dir.x) * strafe * 0.85 + dir * 0.35).normalized() * speed


func _begin_dash_windup(dir: Vector3) -> void:
	_set_state(S.DASH_WINDUP)
	dash_dir = dir
	if _line and is_instance_valid(_line):
		_line.queue_free()
	_line = Game.fx.telegraph_line(global_position, dir, 16.0, 0.7, Game.palette.neon_a)
	Sfx.play_at("windup", global_position, 2.0, 0.9)


func _chase_mech(dist: float, dir: Vector3, delta: float) -> Vector3:
	_enrage_check()
	if special_cd <= 0.0:
		special_cd = _rng.randf_range(3.0, 4.2) if enraged else _rng.randf_range(4.2, 5.6)
		special_seq += 1
		var pick := special_seq % 4
		if pick == 3 and Game.enemy_list.size() > 6:
			pick = 0
		match pick:
			0, 2:
				_set_state(S.GATLING)
				_gat_aim = -0.5 if _rng.randf() < 0.5 else 0.5
				Sfx.play_at("windup", global_position, 2.0, 0.5)
			1:
				_set_state(S.MISSILE_WINDUP)
				Sfx.play_at("beep", global_position, 0.0)
			3:
				Game.main.director.spawn_adds(3, global_position)
				Sfx.play("roar", 0.0, 0.45)
				recover_time = 0.8
				_set_state(S.RECOVER)
		return Vector3.ZERO
	if dist < 6.0 and attack_cd <= 0.0:
		attack_cd = _rng.randf_range(2.5, 3.5)
		_set_state(S.STOMP_WINDUP)
		Sfx.play_at("windup", global_position, 2.0, 0.4)
		return Vector3.ZERO
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe = -strafe
		strafe_t = _rng.randf_range(2.0, 3.5)
	if dist > 15.0:
		return dir * speed
	if dist < 8.0:
		return -dir * speed * 0.7
	return Vector3(-dir.z, 0, dir.x) * strafe * speed * 0.6


func _custom_state(_dist: float, dir: Vector3, delta: float) -> Array:
	var p := Game.player
	match state:
		S.DASH_WINDUP:
			var wt := 0.42 if enraged else 0.62
			if dash_count < (3 if enraged else 2):
				wt *= 0.6
			if state_t < wt * 0.6:
				dash_dir = dir
				if _line and is_instance_valid(_line):
					_line.global_position = global_position + Vector3(0, 0.05, 0)
					_line.look_at(global_position + dash_dir + Vector3(0, 0.05, 0), Vector3.UP)
			if state_t >= wt:
				if _line and is_instance_valid(_line):
					_line.queue_free()
				dash_hit = false
				_set_state(S.DASH)
				Sfx.play_at("dash", global_position, 2.0, 0.8)
			return [Vector3.ZERO, dash_dir]
		S.DASH:
			if int(state_t * 40.0) % 2 == 0:
				Game.gore.sparks(global_position + Vector3(0, 1.0, 0), -dash_dir, 2, Color(Game.palette.neon_a) * 1.6)
			if not dash_hit and global_position.distance_to(p.global_position) < radius + 1.3 and absf(p.global_position.y - global_position.y) < 2.0:
				dash_hit = true
				p.take_damage(20.0 * damage_mult, global_position)
				p.knockback(dash_dir * 8.0 + Vector3.UP * 3.0)
				Sfx.play("slice", 0.0, 0.8)
			if state_t > 0.42 or (state_t > 0.1 and is_on_wall()):
				dash_count -= 1
				if dash_count > 0:
					_begin_dash_windup(dir)
				else:
					recover_time = 1.0
					_set_state(S.RECOVER)
			return [dash_dir * 30.0, dash_dir]
		S.BLINK:
			if state_t < 0.35:
				visual.visible = false
				collision_layer = 0
				return [Vector3.ZERO, dir]
			# reappear behind the player
			var back := -p.global_basis.z
			back.y = 0.0
			var target := p.global_position - back.normalized() * 3.2
			var lim := Game.arena.half - 2.0
			target.x = clampf(target.x, -lim, lim)
			target.z = clampf(target.z, -lim, lim)
			target.y = p.global_position.y + 0.2
			global_position = target
			visual.visible = true
			collision_layer = 4
			Game.fx.smoke(global_position + Vector3(0, 1.0, 0), 2.0)
			Sfx.play_at("blink", global_position, 2.0, 1.3)
			combo_left = 1
			_followup = false
			_set_state(S.WINDUP)
			var to := p.global_position - global_position
			return [Vector3.ZERO, Vector3(to.x, 0, to.z).normalized()]
		S.GATLING:
			var spin := 0.9
			_barrel_glow.set_shader_parameter("energy", 1.0 + clampf(state_t / spin, 0.0, 1.0) * 5.0)
			if state_t > spin:
				_gat_t -= delta
				var k := clampf((state_t - spin) / 2.0, 0.0, 1.0)
				if _gat_t <= 0.0:
					_gat_t = 0.08
					var aim_dir := dir.rotated(Vector3.UP, lerpf(_gat_aim, -_gat_aim, k))
					var origin := muzzle.global_position
					var target := p.global_position + Vector3(0, 0.9, 0)
					var d := (target - origin)
					var flat_len := Vector2(d.x, d.z).length()
					var v := (aim_dir * flat_len + Vector3(0, d.y, 0)).normalized()
					Game.main.director.fire_bolt(true, origin, v * 14.0, 7.0 * damage_mult, "bolt", self)
					Sfx.play_at("gatling", origin, -4.0)
				if state_t > spin + 2.0:
					_barrel_glow.set_shader_parameter("energy", 1.0)
					recover_time = 1.0
					_set_state(S.RECOVER)
			return [Vector3.ZERO, dir]
		S.MISSILE_WINDUP:
			if state_t > 0.7:
				var n := 9 if enraged else 7
				for i in n:
					var off := Vector3.ZERO
					if i > 0:
						var a := _rng.randf() * TAU
						off = Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.5, 8.0)
					var t := p.global_position + off
					t.x = clampf(t.x, -Game.arena.half + 1.0, Game.arena.half - 1.0)
					t.z = clampf(t.z, -Game.arena.half + 1.0, Game.arena.half - 1.0)
					Game.fx.missile_strike(t, 1.5 + i * 0.09, 2.6, 20.0 * damage_mult)
				Game.gore.sparks(global_position + Vector3(0, 3.6, 0), Vector3.UP, 24, Color(Game.palette.neon_c) * 1.6)
				Sfx.play_at("missile", global_position, 4.0)
				Game.show_hint_once("missile", "MISSILES INBOUND - GET OUT OF THE RED CIRCLES")
				recover_time = 0.9
				_set_state(S.RECOVER)
			return [Vector3.ZERO, dir]
		S.STOMP_WINDUP:
			if state_t > 0.8 * _delay_k:
				Game.fx.shockwave(global_position, 12.0, 13.0, 22.0 * damage_mult)
				Sfx.play_at("slam", global_position, 4.0, 0.8)
				Game.player.add_trauma(0.6)
				Game.gore.sparks(global_position + Vector3(0, 0.2, 0), Vector3.UP, 30, Color(Game.palette.neon_c) * 1.6)
				recover_time = 1.0
				_set_state(S.RECOVER)
			return [Vector3.ZERO, dir]
		S.SIDESTEP:
			return _sidestep_state(dir)
		S.RED_WINDUP:
			return _red_windup_state(dir)
		S.RED_ACT:
			return _red_act_state(dir)
		S.AREA_WINDUP:
			if state_t >= _area_len:
				_area_release()
			return [Vector3.ZERO, dir if kind != "ninja" else Vector3(sin(face_yaw), 0, cos(face_yaw))]
	return [Vector3.ZERO, dir]


# ---------------------------------------------------------------- sidestep
## Hanging back and aiming from range makes the boss step out of the line;
## pressure up close never does.
func _try_sidestep(dir: Vector3) -> bool:
	if _aim_t < SIDESTEP_AIM or _sidestep_cd > 0.0:
		return false
	_aim_t = 0.0
	_sidestep_cd = GENTLE_SIDESTEP_CD if _gentle() else SIDESTEP_CD
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	_side_dir = Vector3(-dir.z, 0, dir.x) * side
	var chest := global_position + Vector3(0, height * 0.5, 0)
	match kind:
		"ninja": # an afterimage of smoke where he stood
			Game.fx.smoke(chest, 1.4)
			Sfx.play_at("blink", global_position, -2.0, 1.5)
		"mech": # jumps back and lands with a small shockwave
			_side_dir = (-dir + _side_dir * 0.4).normalized()
			velocity.y = 9.0
			Sfx.play_at("windup", global_position, 2.0, 0.6)
		_: # a shoulder barge to the side
			Sfx.play("roar", -4.0, 0.9)
	_set_state(S.SIDESTEP)
	_log_move("sidestep")
	return true


func _sidestep_state(dir: Vector3) -> Array:
	match kind:
		"ninja":
			if state_t > 0.22:
				_set_state(S.CHASE)
			return [_side_dir * 18.0, dir]
		"mech":
			if state_t > 0.2 and is_on_floor():
				Game.fx.shockwave(global_position, 7.0, 14.0, 12.0 * damage_mult)
				Sfx.play_at("slam", global_position, 0.0, 1.0)
				recover_time = 0.5
				_set_state(S.RECOVER)
			return [_side_dir * 10.0, dir]
	if int(state_t * 30.0) % 2 == 0:
		Game.gore.sparks(global_position + Vector3(0, 0.2, 0), -_side_dir + Vector3.UP * 0.4, 2)
	if state_t > 0.3:
		_set_state(S.CHASE)
	return [_side_dir * 14.0, dir]


# ---------------------------------------------------------------- big moves
func _try_big_move(dist: float, dir: Vector3) -> bool:
	if not _big_moves_on():
		return false
	if _red_cd <= 0.0 and dist > 3.0 and dist < 22.0:
		_red_cd = RED_CD * _rng.randf_range(0.9, 1.2)
		_begin_red(dir)
		return true
	var reach: float = {"ninja": 5.0, "mech": 30.0, "oni": 14.0}.get(kind, 0.0)
	if _area_cd <= 0.0 and dist < reach:
		_area_cd = AREA_CD * _rng.randf_range(0.9, 1.2)
		_begin_area(dir)
		return true
	return false


## The RED SIGNAL: a red diamond, an alarm, then a move that can't be
## deflected or traded with. Get clear, or dash through it for a PERFECT.
func _begin_red(dir: Vector3) -> void:
	_step = 0
	_perfect = false
	_hit_done = false
	_beeped = false
	_lunge = dir
	_set_state(S.RED_WINDUP)
	Sfx.play("alarm", -6.0, 1.5)
	Game.show_hint_once("red_signal", "RED SIGNAL: GET CLEAR, OR DASH THROUGH IT AT THE LAST MOMENT")
	_log_move("red")
	if kind == "ninja":
		_plan_cross()


## NULL CROSS: he vanishes, and three neon lines cross where the player
## stands; he will dash along each in turn.
func _plan_cross() -> void:
	var c := Game.player.global_position
	var a := _rng.randf() * PI
	var lim := Game.arena.half - 1.5
	_lines.clear()
	for i in 3:
		var d := Vector3(cos(a + i * PI / 3.0), 0, sin(a + i * PI / 3.0))
		var start := c - d * CROSS_LEN * 0.5
		start.x = clampf(start.x, -lim, lim)
		start.z = clampf(start.z, -lim, lim)
		_lines.append([start, d])
		Game.fx.telegraph_line(start, d, CROSS_LEN, _red_len() + 3.0 * (CROSS_LEN / CROSS_SPEED + CROSS_GAP), RED_COLOR)
	visual.visible = false
	collision_layer = 0
	Game.fx.smoke(global_position + Vector3(0, 1.0, 0), 2.0)
	Sfx.play_at("blink", global_position, 0.0)


func _red_windup_state(dir: Vector3) -> Array:
	var wl := _red_len()
	var face := dir
	match kind:
		"ninja":
			face = _lines[0][1]
			if not visual.visible and state_t >= wl * 0.6:
				_blink_to(_lines[0][0])
		"oni":
			# aims until late in the windup, then commits
			if state_t < wl * 0.7:
				_lunge = dir
			face = _lunge
	if not _beeped and state_t >= wl - 0.2:
		_beeped = true
		Sfx.play_at("beep", global_position, 4.0, 1.4)
	if state_t >= wl:
		match kind:
			"mech":
				_brood_barrage()
				recover_time = 1.2
				_set_state(S.RECOVER)
			_:
				_set_state(S.RED_ACT)
				Sfx.play_at("dash", global_position, 4.0, 0.7)
	return [Vector3.ZERO, face]


func _red_act_state(_dir: Vector3) -> Array:
	if kind == "ninja":
		var d: Vector3 = _lines[_step][1]
		var dash_len := CROSS_LEN / CROSS_SPEED
		if state_t < dash_len:
			if int(state_t * 40.0) % 2 == 0:
				Game.gore.sparks(global_position + Vector3(0, 1.0, 0), -d, 2, RED_COLOR * 1.6)
			_red_contact(radius + 1.3, 26.0, d * 9.0 + Vector3.UP * 3.0)
			return [d * CROSS_SPEED, d]
		if _step >= _lines.size() - 1:
			recover_time = 1.2
			_set_state(S.RECOVER)
			return [Vector3.ZERO, d]
		if state_t >= dash_len + CROSS_GAP * _tele():
			_step += 1
			_hit_done = false
			_blink_to(_lines[_step][0])
			_set_state(S.RED_ACT)
			Sfx.play_at("dash", global_position, 4.0, 0.8)
		return [Vector3.ZERO, _lines[mini(_step + 1, _lines.size() - 1)][1]]
	# DAEMON GRAB: a lunge that grabs and hurls whoever it catches
	if state_t < GRAB_TIME:
		if int(state_t * 30.0) % 2 == 0:
			Game.gore.sparks(global_position + Vector3(0, 0.2, 0), -_lunge + Vector3.UP * 0.4, 2)
		_red_contact(radius + 1.4, 38.0, _lunge * 14.0 + Vector3.UP * 9.0)
		return [_lunge * GRAB_SPEED, _lunge]
	# a whiffed grab leaves him wide open
	recover_time = 1.2 if _hit_done else 1.8
	_set_state(S.RECOVER)
	return [Vector3.ZERO, _lunge]


func _blink_to(at: Vector3) -> void:
	var p := Game.player
	global_position = Vector3(at.x, p.global_position.y + 0.2, at.z)
	reset_physics_interpolation()
	visual.visible = true
	collision_layer = 4
	Game.fx.smoke(global_position + Vector3(0, 1.0, 0), 2.0)
	Sfx.play_at("blink", global_position, 2.0, 1.3)


## A RED SIGNAL attack connecting. Dashing through it is a PERFECT dodge.
func _red_contact(reach: float, dmg: float, push: Vector3) -> void:
	if _hit_done:
		return
	var p := Game.player
	var rel := p.global_position - global_position
	if Vector2(rel.x, rel.z).length() > reach or absf(rel.y) > 2.2:
		return
	_hit_done = true
	if p.dash_t > 0.0:
		_perfect_dodge()
		return
	p.take_damage(dmg * damage_mult, global_position)
	p.knockback(push)
	if kind == "oni":
		Game.hitstop(0.1)
		p.add_trauma(0.8)
		Sfx.play_at("slam", global_position, 4.0, 0.7)
		Sfx.play("roar", 0.0, 0.7)


func _perfect_dodge() -> void:
	if _perfect:
		return
	_perfect = true
	Game.hud.stamp("PERFECT", Color(0.4, 1.0, 1.0), 14, {"anchor": Vector2(0.5, 0.5), "off": Vector2(0, -44), "hold": 0.7, "shake": 4.0, "pitch": 1.3})
	Sfx.play("deflect", 0.0, 1.4, 0.0)
	Game.slowmo(0.35, 0.4)
	press_kamae(kamae.max_value * PERFECT_KAMAE)


## BROOD BARRAGE: two rings of missiles close in around the player, then one
## lands in the middle. Each ring has the same gap: that is the way out.
func _brood_barrage() -> void:
	var c := Game.player.global_position
	var gap := _rng.randf() * TAU
	var t := _tele()
	_missile_ring(c, 7.5, 12, gap, 1.2 * t)
	_missile_ring(c, 4.5, 8, gap, 1.6 * t)
	Game.fx.missile_strike(c, 2.0 * t, 2.6, 20.0 * damage_mult)
	Game.gore.sparks(global_position + Vector3(0, 3.6, 0), Vector3.UP, 30, RED_COLOR * 1.6)
	Sfx.play_at("missile", global_position, 6.0, 0.8)


func _missile_ring(c: Vector3, r: float, n: int, gap: float, delay: float) -> void:
	var lim := Game.arena.half - 1.0
	# slots 0 and 1 sit either side of `gap` and are left out
	for k in range(2, n):
		var a := gap + TAU * (k - 0.5) / n
		var at := c + Vector3(cos(a), 0, sin(a)) * r
		at.x = clampf(at.x, -lim, lim)
		at.z = clampf(at.z, -lim, lim)
		Game.fx.missile_strike(at, delay + k * 0.01, 2.6, 20.0 * damage_mult)


## Area moves: a telegraphed floor hazard (BossHazard), the boss holding its
## pose until it goes off, then a punish window.
func _begin_area(dir: Vector3) -> void:
	var t := _tele()
	var hazards: Array[BossHazard] = []
	match kind:
		"ninja": # SMOKE RING: smoke at his feet, then a full-circle cut
			_area_len = 0.55 * t
			var h := BossHazard.zone(global_position, 5.0, _area_len, 18.0 * damage_mult, Color(Game.palette.neon_a))
			h.sound = "swing2"
			hazards.append(h)
			Game.fx.smoke(global_position + Vector3(0, 0.4, 0), 2.6)
			Sfx.play_at("windup", global_position, 2.0, 1.2)
		"mech": # EMP FIELD: three live zones around the player
			_area_len = 0.6
			var c := Game.player.global_position
			var a := _rng.randf() * TAU
			for i in 3:
				var at := c
				if i > 0:
					at += Vector3(cos(a + i * PI), 0, sin(a + i * PI)) * _rng.randf_range(3.5, 5.0)
				hazards.append(BossHazard.zone(at, 2.6, 1.2 * t, 12.0 * damage_mult, Color(0.3, 0.9, 1.0), 1.8))
			Sfx.play_at("beep", global_position, 2.0, 0.7)
		_: # FISSURES: fire lines crack out in a star from his fist
			_area_len = 0.8 * t
			for i in 5:
				var d := dir.rotated(Vector3.UP, i * TAU / 5.0)
				hazards.append(BossHazard.line(global_position + d * radius, d, 14.0, 1.6, _area_len, 24.0 * damage_mult, Color(1.0, 0.4, 0.1)))
			Sfx.play("roar", 0.0, 0.8)
	for h in hazards:
		get_parent().add_child(h)
	_set_state(S.AREA_WINDUP)
	_log_move("area")


func _log_move(move: String) -> void:
	if Game.debug_autoplay:
		print("[boss] %s %s hp=%.0f/%.0f cycle=%d enraged=%s frame=%d" % [kind, move, hp, max_hp, cycle, enraged, Engine.get_frames_drawn()])


func _area_release() -> void:
	match kind:
		"ninja":
			Game.gore.sparks(global_position + Vector3(0, 1.0, 0), Vector3.UP, 30, Color(Game.palette.neon_a) * 1.6)
			recover_time = 0.9
		"mech":
			recover_time = 0.8
		_:
			Sfx.play_at("slam", global_position, 4.0, 0.8)
			Game.player.add_trauma(0.5)
			recover_time = 1.0
	_set_state(S.RECOVER)


func _attack(dist: float, dir: Vector3) -> void:
	if kind != "ninja":
		super._attack(dist, dir)
		return
	var p := Game.player
	var fwd := Vector3(sin(face_yaw), 0, cos(face_yaw))
	knock += fwd * 7.0
	Sfx.play_at("swing%d" % (combo_left % 3), global_position, 0.0, 0.9)
	Game.gore.sparks(global_position + fwd * 2.0 + Vector3(0, 1.2, 0), fwd, 8, Color(Game.palette.neon_a) * 1.6)
	if dist < 3.3 + radius and absf(p.global_position.y - global_position.y) < 2.2 and fwd.dot(dir) > 0.25:
		p.take_damage(16.0 * damage_mult, global_position)
	combo_left -= 1
	if combo_left > 0:
		_followup = true
		_set_state(S.WINDUP)
		return
	recover_time = 0.7
	attack_cd = _rng.randf_range(1.2, 1.8)
	_set_state(S.RECOVER)


func _volley(dir: Vector3) -> void:
	if kind != "ninja":
		super._volley(dir)
		return
	var origin := global_position + Vector3(0, height * 0.6, 0)
	var target := Game.player.global_position + Vector3(0, 1.0, 0)
	var aim := (target - origin).normalized()
	var n := 7 if enraged else 5
	for i in n:
		Game.main.director.fire_bolt(true, origin + dir * radius, aim.rotated(Vector3.UP, (i - (n - 1) * 0.5) * 0.16) * 13.0, 10.0 * damage_mult, "shuriken", self)
	Sfx.play_at("shuriken", global_position, 2.0)
	Game.show_hint_once("bolt", "SLASH INCOMING BOLTS TO DEFLECT THEM")


func die(source: String, dir: Vector3, headshot := false) -> void:
	if dead:
		return
	if _line and is_instance_valid(_line):
		_line.queue_free()
	if kind == "mech":
		var c := global_position + Vector3(0, 2.4, 0)
		for k in 4:
			Game.fx.explosion(c + Vector3(randf_range(-1.5, 1.5), randf_range(-0.6, 0.8), randf_range(-1.5, 1.5)), 0.0, false)
		source = "explode"
	super.die(source, dir, headshot)
