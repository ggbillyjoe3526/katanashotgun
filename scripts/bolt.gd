class_name Bolt
extends Node3D
## Slow plasma bolts fired by gunners and the boss. Slashing one with the
## katana deflects it back as a lethal, staggering shot.
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


func setup(is_hostile: bool, pos: Vector3, velocity: Vector3, dmg: float, k := "bolt") -> void:
	hostile = is_hostile
	position = pos
	vel = velocity
	damage = dmg
	kind = k
	if kind == "wave":
		radius = 1.4
		life = 0.55


## Back to a fresh bolt of the same kind (call `setup` and `activate` after).
func reuse() -> void:
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


func deflect(dir: Vector3) -> void:
	if not hostile:
		return
	hostile = false
	remove_from_group("enemy_projectiles")
	# light auto-aim toward the enemy closest to the crosshair
	var best: Enemy = null
	var best_dot := 0.96
	for e in Game.enemy_list:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector3 = (e.global_position + Vector3(0, e.height * 0.6, 0)) - global_position
		var d := dir.dot(to.normalized())
		if d > best_dot:
			best_dot = d
			best = e
	if best:
		dir = ((best.global_position + Vector3(0, best.height * 0.6, 0)) - global_position).normalized()
	vel = dir * maxf(vel.length() * 2.4, 36.0)
	damage = 95.0
	life = 2.0
	if kind == "shuriken":
		_core_mat.set_shader_parameter("color", Color(0.4, 1.0, 1.0, 1.0))
	else:
		_core_mat.set_shader_parameter("albedo_color", Color(0.4, 1.0, 1.0))
	_halo_mat.set_shader_parameter("color", Color(0.3, 0.9, 1.0, 0.9))
	Game.deflects += 1
	Sfx.play("deflect", 0.0)
	Game.hitstop(0.07)
	Game.popup.emit("DEFLECT!", Color(0.4, 1.0, 1.0))
	Game.gore.sparks(global_position, dir, 18, Color(0.6, 1.8, 2.0))


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_finish()
		return
	var from := global_position
	var to := from + vel * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var res := space.intersect_ray(q)
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
			var c: Vector3 = e.global_position + Vector3(0, e.height * 0.55, 0)
			if _seg_dist(from, to, c) < radius + e.radius + e.height * 0.25:
				_hit[e] = true
				if kind == "wave":
					e.take_hit(damage, "wave", vel.normalized(), false, damage * 0.5, 4.0)
				else:
					e.take_hit(damage, "deflect", vel.normalized(), false, 140.0, 12.0)
					Game.gore.sparks(to, -vel.normalized(), 14, Color(0.6, 1.8, 2.0))
					_finish()
					return


static func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var t := 0.0
	var l2 := ab.length_squared()
	if l2 > 0.0:
		t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
