class_name Bolt
extends Node3D
## Slow plasma bolts fired by gunners and the boss. Slashing one with the
## katana sends it straight back at whoever fired it: it homes on its shooter
## and hits it, hard (spec §3.2 Deflect).
## Also used for the player's Crimson Wave (kind = "wave", pierces enemies).
## Bolts come from the WaveDirector's pool (`fire_bolt`): a spent bolt hides
## and goes back instead of being freed.

var vel := Vector3.ZERO
var damage := 12.0
var hostile := true
var kind := "bolt"
var life := 4.0
var radius := 0.35
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _halo_mat: ShaderMaterial
var _core_mat: ShaderMaterial
var _hit := {}
var _trail_t := 0.0
## The pool that takes this bolt back when it is spent (null: freed instead).
var pool: WaveDirector = null
## Built ahead of time for a pool: hidden at once.
var prewarm := false
## The enemy or boss that fired this bolt (null for the player's own shots).
var shooter: Enemy = null
## Who a deflected bolt is flying back at (null: it flies straight).
var target: Enemy = null
## The shooter's and target's `spawn_id` when taken: a pooled enemy that
## died and came back as a new spawn is not the same enemy any more.
var _shooter_spawn := 0
var _target_spawn := 0
## Deflected and on its way back (homing while it has a target).
var _returning := false

## A returned bolt hits this many times harder than it was fired.
const RETURN_DAMAGE_MULT := 8.0
const RETURN_MIN_SPEED := 36.0
const RETURN_SPEED_MULT := 2.4
## With the shooter dead, the bolt takes the enemy nearest the aim inside
## this cone (dot product with the aim).
const FALLBACK_MIN_DOT := 0.8
const _NO_HIT := {}


func setup(is_hostile: bool, pos: Vector3, velocity: Vector3, dmg: float, k := "bolt", from: Enemy = null) -> void:
	hostile = is_hostile
	position = pos
	vel = velocity
	damage = dmg
	kind = k
	shooter = from
	_shooter_spawn = from.spawn_id if from else 0
	target = null
	_target_spawn = 0
	_returning = false
	if kind == "wave":
		radius = 1.4
		life = 0.55


## Back to a fresh bolt of the same kind (call `setup` and `activate` after).
func reuse() -> void:
	shooter = null
	target = null
	_returning = false
	vel = Vector3.ZERO
	damage = 12.0
	hostile = true
	life = 4.0
	radius = 0.35
	_hit.clear()
	_trail_t = 0.0
	transform = Transform3D.IDENTITY
	match kind:
		"shuriken":
			var col: Color = Game.palette.get("neon_a", Color(1, 0.2, 0.5))
			_core_mat.set_shader_parameter("color", Color(col.r, col.g, col.b, 1.0))
			_halo_mat.set_shader_parameter("color", Color(col.r, col.g, col.b, 0.7))
		"bolt":
			_core_mat.set_shader_parameter("albedo_color", Color(1.0, 0.55, 0.2))
			_halo_mat.set_shader_parameter("color", Color(1.0, 0.4, 0.1, 0.9))
	if _core:
		_core.scale = Vector3.ONE
		_core.rotation = Vector3.ZERO
	if _halo:
		_halo.scale = Vector3.ONE


## Starts flying (runs on every shot, pooled or new).
func activate() -> void:
	reset_physics_interpolation() # a pooled bolt jumps to the muzzle
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if hostile:
		add_to_group("enemy_projectiles")
	if kind == "wave":
		look_at_from_position(position, position + vel, Vector3.UP)


## Spent: back to the pool, or freed if it has none.
func _finish() -> void:
	if pool == null:
		queue_free()
		return
	if is_in_group("enemy_projectiles"):
		remove_from_group("enemy_projectiles")
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	pool.recycle_bolt(self)


func _ready() -> void:
	if kind == "wave":
		_build_wave()
	elif kind == "shuriken":
		var col: Color = Game.palette.get("neon_a", Color(1, 0.2, 0.5))
		_core_mat = Psx.fx(Color(col.r, col.g, col.b, 1.0), TexGen.get_tex("star"), true, false, false, 2.6)
		_core = MeshInstance3D.new()
		add_child(_core)
		for k in 2:
			var q := Psx.quad(Vector2(0.7, 0.7), _core_mat)
			q.rotation.x = -PI * 0.5 if k == 0 else 0.0
			_core.add_child(q)
		_halo_mat = Psx.fx(Color(col.r, col.g, col.b, 0.7), TexGen.get_tex("glow"), true, true, false, 1.2)
		_halo = Psx.quad(Vector2(1.2, 1.2), _halo_mat)
		add_child(_halo)
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		sm.radial_segments = 6
		sm.rings = 3
		_core = MeshInstance3D.new()
		_core.mesh = sm
		_core_mat = Psx.unlit(Color(1.0, 0.55, 0.2), 3.0, null, {"fog_amount": 0.2})
		_core.material_override = _core_mat
		add_child(_core)
		_halo_mat = Psx.fx(Color(1.0, 0.4, 0.1, 0.9), TexGen.get_tex("glow"), true, true, false, 1.4)
		_halo = Psx.quad(Vector2(1.3, 1.3), _halo_mat)
		add_child(_halo)
	if prewarm:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	activate()


func _build_wave() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Fx.arc_mesh(1.6, 0.55, 0.32, -2.2, -0.9)
	mi.material_override = Psx.fx(Color(1.0, 0.1, 0.2, 1.0), null, true, false, false, 2.2)
	mi.material_override.set_shader_parameter("use_vertex_color", true)
	add_child(mi)
	_core = mi


## `split` is a Yata Mirror copy: it flies at its parent's speed and makes
## no fuss of its own (no count, popup, sound or hitstop).
func deflect(dir: Vector3, split := false) -> void:
	if not hostile:
		return
	hostile = false
	remove_from_group("enemy_projectiles")
	if split:
		# a Yata Mirror copy: already at return speed and damage, no target
		life = 2.0
		vel = dir * vel.length()
	else:
		var speed := maxf(vel.length() * RETURN_SPEED_MULT, RETURN_MIN_SPEED)
		var from_enemy: Variant = shooter if _same_spawn(shooter, _shooter_spawn) else null
		_set_target(pick_return_target(from_enemy, global_position, dir, Game.enemy_list))
		_returning = target != null
		if target:
			dir = (aim_point(target) - global_position).normalized()
			# long enough to reach the shooter wherever it stands, with margin
			life = clampf(global_position.distance_to(aim_point(target)) / speed + 1.0, 2.0, 6.0)
		else:
			life = 2.0
		vel = dir * speed
		damage *= RETURN_DAMAGE_MULT
	if kind == "shuriken":
		_core_mat.set_shader_parameter("color", Color(0.4, 1.0, 1.0, 1.0))
	else:
		_core_mat.set_shader_parameter("albedo_color", Color(0.4, 1.0, 1.0))
	_halo_mat.set_shader_parameter("color", Color(0.3, 0.9, 1.0, 0.9))
	if split:
		return
	Game.deflects += 1
	Sfx.play("deflect", 0.0)
	Game.hitstop(0.07)
	if Game.hud and Game.hud.post:
		Game.hud.post.flash(0.12)
	Game.popup.emit("DEFLECT!", Color(0.4, 1.0, 1.0))
	Game.gore.sparks(global_position, dir, 18, Color(0.6, 1.8, 2.0))


## Where a returned bolt aims on an enemy's body.
static func aim_point(e: Enemy) -> Vector3:
	return e.global_position + Vector3(0, e.height * 0.6, 0)


## Untyped on purpose: a freed enemy can't be passed as an `Enemy`.
static func _alive(e: Variant) -> bool:
	return is_instance_valid(e) and not e.dead and e.is_inside_tree()


## Alive and still the same spawn it was when we took it (pooled enemies
## come back as new spawns).
static func _same_spawn(e: Variant, spawn: int) -> bool:
	return _alive(e) and e.spawn_id == spawn


func _set_target(e: Enemy) -> void:
	target = e
	_target_spawn = e.spawn_id if e else 0


## The enemy a deflected bolt flies back at: the one that fired it while it
## lives, otherwise the living enemy nearest the aim (null if none is close
## to it, and the bolt flies straight).
static func pick_return_target(from_enemy: Variant, pos: Vector3, dir: Vector3, enemies: Array) -> Enemy:
	if _alive(from_enemy):
		return from_enemy
	var best: Enemy = null
	var best_dot := FALLBACK_MIN_DOT
	for e in enemies:
		if not _alive(e):
			continue
		var d := dir.dot((aim_point(e) - pos).normalized())
		if d > best_dot:
			best_dot = d
			best = e
	return best


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_finish()
		return
	if _returning:
		_steer()
	var from := global_position
	var to := from + vel * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	# a bolt on its way back to its shooter is never stopped by cover
	var res: Dictionary = _NO_HIT if _returning else space.intersect_ray(q)
	if not res.is_empty() and kind != "wave":
		Game.gore.sparks(res.position, res.normal, 10, Color(1.8, 0.8, 0.3) if hostile else Color(0.6, 1.8, 2.0))
		Sfx.play_at("bolt_hit", res.position, -6.0)
		_finish()
		return
	global_position = to
	if kind == "wave":
		var k := life / 0.55
		_core.scale = Vector3.ONE * (1.0 + (1.0 - k) * 0.6)
		_core.material_override.set_shader_parameter("intensity", 2.2 * k)
	else:
		_halo.scale = Vector3.ONE * (1.0 + sin(life * 40.0) * 0.15)
		if kind == "shuriken":
			_core.rotate_y(delta * 25.0)
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.03
			Game.gore.spawn_drop(global_position, Vector3.ZERO, 0.15, 0.08, 1, Color(1.8, 0.7, 0.2) if hostile else Color(0.5, 1.6, 2.0))
	if hostile:
		var p := Game.player
		if p and not p.dead:
			var c := p.global_position + Vector3(0, 1.0, 0)
			if _seg_dist(from, to, c) < radius + 0.5:
				p.take_damage(damage, from)
				Game.gore.sparks(to, -vel.normalized(), 8)
				_finish()
	else:
		for e in Game.enemy_list:
			if not is_instance_valid(e) or e.dead or _hit.has(e):
				continue
			# a returned bolt passes everyone else on its way to its target
			if _returning and e != target:
				continue
			var c: Vector3 = e.global_position + Vector3(0, e.height * 0.55, 0)
			if _seg_dist(from, to, c) < radius + e.radius + e.height * 0.25:
				_hit[e] = true
				if kind == "wave":
					e.take_hit(damage, "wave", vel.normalized(), false, damage * 0.5, 4.0)
				else:
					var killed: bool = e.take_hit(damage, "deflect", vel.normalized(), false, 140.0, 12.0)
					Game.gore.sparks(to, -vel.normalized(), 14, Color(0.6, 1.8, 2.0))
					# the payback lands: a cyan flash on the body and a crack;
					# a kill also gets a beat of hitstop (not every hit, so a
					# returned gatling stream doesn't stutter)
					Game.fx.impact(to, -vel.normalized(), true)
					Sfx.play_at("bolt_hit", to, 0.0)
					if killed:
						Game.hitstop(0.05)
					_finish()
					return


## Keeps a returned bolt locked on its target. If the target dies first,
## the bolt takes the next enemy along its path, or flies on straight.
func _steer() -> void:
	if not _same_spawn(target, _target_spawn):
		_set_target(pick_return_target(null, global_position, vel.normalized(), Game.enemy_list))
		if target == null:
			_returning = false
			return
	vel = (aim_point(target) - global_position).normalized() * vel.length()


static func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var t := 0.0
	var l2 := ab.length_squared()
	if l2 > 0.0:
		t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
