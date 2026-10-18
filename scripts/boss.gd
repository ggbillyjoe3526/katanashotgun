class_name Boss
extends Enemy
## The two newer bosses. The ONI lives in enemy.gd.
##   ninja  KUROKAGE, BLADE OF THE NULL SIGNAL: telegraphed dash-slash chains, shuriken
##          fans you can deflect, and blinking behind you.
##   mech   TETSUGUMO, CHROME BROODMOTHER: sweeping gatling, missile strikes marked
##          on the floor, stomp shockwaves, and calls reinforcements.
## Both are armoured: shotgun them to stagger, then execute for a deathblow.

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


func setup(k: String, scale_mult := 1.0) -> void:
	kind = k
	is_boss = true
	match k:
		"ninja":
			hp = 2600.0; speed = 5.2; radius = 0.5; height = 2.1; head_y = 1.72; poise = 290.0
			stagger_time = 2.6; armor = 0.55; xp = 320.0; points = 5000; mass = 3.0
			display_name = "KUROKAGE"; subtitle = "BLADE OF THE NULL SIGNAL"; defeat_text = "SHADOW DELETED"
		"mech":
			hp = 4400.0; speed = 2.6; radius = 1.7; height = 3.6; head_y = 2.5; poise = 560.0
			stagger_time = 3.2; armor = 0.35; xp = 420.0; points = 7000; mass = 14.0
			display_name = "TETSUGUMO"; subtitle = "CHROME BROODMOTHER"; defeat_text = "MACHINE DECOMMISSIONED"
		_:
			super.setup(k, scale_mult)
			return
	_finish_setup(scale_mult)


# ---------------------------------------------------------------- bodies
func _build_body() -> void:
	if kind == "mech":
		_build_mech()
		return
	super._build_body()
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
	marker = Psx.quad(Vector2(0.8, 0.8), Psx.fx(Color(1.0, 0.05, 0.1), TexGen.get_tex("star"), true, true, true, 2.5), Vector3(0, height + 0.9, 0))
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
		S.STOMP_WINDUP:
			lift = clampf(state_t / 0.8, 0.0, 1.0) * 0.8
		S.STAGGER:
			lift = -0.9
		S.MISSILE_WINDUP:
			_pods_glow.set_shader_parameter("energy", 1.0 + clampf(state_t / 0.7, 0.0, 1.0) * 5.0)
	if state != S.MISSILE_WINDUP:
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
	if kind == "ninja":
		return 0.3 if _followup else 0.45
	if kind == "mech":
		return 0.6
	return super._windup_time()


func _chase(dist: float, dir: Vector3, delta: float) -> Vector3:
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


func _custom_state(dist: float, dir: Vector3, delta: float) -> Array:
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
					var b := Bolt.new()
					b.setup(true, origin, v * 14.0, 7.0 * damage_mult)
					get_parent().add_child(b)
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
			if state_t > 0.8:
				Game.fx.shockwave(global_position, 12.0, 13.0, 22.0 * damage_mult)
				Sfx.play_at("slam", global_position, 4.0, 0.8)
				Game.player.add_trauma(0.6)
				Game.gore.sparks(global_position + Vector3(0, 0.2, 0), Vector3.UP, 30, Color(Game.palette.neon_c) * 1.6)
				recover_time = 1.0
				_set_state(S.RECOVER)
			return [Vector3.ZERO, dir]
	return [Vector3.ZERO, dir]


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
		var b := Bolt.new()
		b.setup(true, origin + dir * radius, aim.rotated(Vector3.UP, (i - (n - 1) * 0.5) * 0.16) * 13.0, 10.0 * damage_mult, "shuriken")
		get_parent().add_child(b)
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
