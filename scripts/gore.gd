class_name Gore
extends Node3D
## Blood and guts. Droplets are a single MultiMesh simulated on the CPU, floor
## splats are a ring buffer of decals, and gibs are the enemy's own body parts
## flying free with simple physics. Everything is pooled and capped so hordes
## stay fast in the browser.

const MAX_DROPS := 1800
const MAX_DECALS := 520
const MAX_GIBS := 110
const GRAVITY := 24.0

var _mm: MultiMesh
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _floor := PackedFloat32Array()
var _size := PackedFloat32Array()
var _kind := PackedByteArray() # 0 blood, 1 spark, 2 ember
var _n := 0

var _decals: MultiMesh
var _decal_i := 0
var _decal_count := 0

var _gibs: Array = []
var _emitters: Array = []
var _mists: Array = []
var _mist_mat: ShaderMaterial
var _chunk_mesh: BoxMesh
var _chunk_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_pos.resize(MAX_DROPS)
	_vel.resize(MAX_DROPS)
	_life.resize(MAX_DROPS)
	_floor.resize(MAX_DROPS)
	_size.resize(MAX_DROPS)
	_kind.resize(MAX_DROPS)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	_mm.mesh = bm
	_mm.instance_count = MAX_DROPS
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.material_override = Psx.unlit(Color.WHITE, 1.0, null, {"use_vertex_color": true, "fog_amount": 0.5, "near_discard": 1.4})
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 200, 400))
	add_child(mmi)

	_decals = MultiMesh.new()
	_decals.transform_format = MultiMesh.TRANSFORM_3D
	_decals.use_colors = true
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	_decals.mesh = pm
	_decals.instance_count = MAX_DECALS
	_decals.visible_instance_count = 0
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = _decals
	var dm := Psx.cutout(Color(1, 1, 1), TexGen.get_tex("splat"))
	dmi.material_override = dm
	dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dmi.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 200, 400))
	add_child(dmi)

	_mist_mat = Psx.fx(Color(0.55, 0.0, 0.03, 0.75), TexGen.get_tex("glow"), false, true)
	_chunk_mesh = BoxMesh.new()
	_chunk_mesh.size = Vector3(0.16, 0.12, 0.14)
	_chunk_mat = Psx.lit(Color(0.45, 0.03, 0.05), TexGen.get_tex("noise"))


# ---------------------------------------------------------------- droplets
func _blood_color() -> Color:
	var k := _rng.randf_range(0.4, 1.0)
	return Color(0.7 * k, 0.015 * k, 0.035 * k)


func spawn_drop(p: Vector3, v: Vector3, life: float, size: float, kind := 0, color := Color(0, 0, 0, 0)) -> void:
	var i := _n
	if _n >= MAX_DROPS:
		i = _rng.randi() % MAX_DROPS
	else:
		_n += 1
	_pos[i] = p
	_vel[i] = v
	_life[i] = life
	_size[i] = size
	_kind[i] = kind
	_floor[i] = Game.arena.floor_height_at(p.x, p.z) if Game.arena else 0.0
	if _floor[i] > p.y + 0.05:
		_floor[i] = 0.0
	if color.a == 0.0:
		color = _blood_color() if kind == 0 else Color(1.6, 1.3, 0.5)
	_mm.set_instance_color(i, color)


func burst(p: Vector3, dir: Vector3, count: int, speed := 6.0, spread := 0.6, up := 2.0, size := 0.07) -> void:
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.UP
	for k in count:
		var rv := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
		var v := (d + rv * spread).normalized() * speed * _rng.randf_range(0.35, 1.25) + Vector3(0, up * _rng.randf(), 0)
		spawn_drop(p, v, _rng.randf_range(0.8, 1.6), size * _rng.randf_range(0.6, 1.5))


func sparks(p: Vector3, normal: Vector3, count := 8, color := Color(0, 0, 0, 0)) -> void:
	for k in count:
		var rv := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
		var v := (normal + rv * 0.9).normalized() * _rng.randf_range(4, 11)
		spawn_drop(p, v, _rng.randf_range(0.15, 0.4), _rng.randf_range(0.03, 0.06), 1, color)


func embers(p: Vector3, count := 3) -> void:
	for k in count:
		var v := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(1.5, 4.0), _rng.randf_range(-1, 1))
		spawn_drop(p + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0, 1.4), _rng.randf_range(-0.3, 0.3)), v, _rng.randf_range(0.3, 0.6), 0.06, 2, Color(2.0, 0.7, 0.15))


func decal(p: Vector3, size: float, dark := false) -> void:
	var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, 1, size))
	var y := p.y + 0.015 + float(_decal_i % 7) * 0.003
	_decals.set_instance_transform(_decal_i, Transform3D(b, Vector3(p.x, y, p.z)))
	var k := _rng.randf_range(0.5, 0.85) * (0.6 if dark else 1.0)
	_decals.set_instance_color(_decal_i, Color(0.7 * k, 0.02 * k, 0.04 * k, 1))
	_decal_i = (_decal_i + 1) % MAX_DECALS
	_decal_count = mini(_decal_count + 1, MAX_DECALS)
	_decals.visible_instance_count = _decal_count


func scorch(p: Vector3, size: float) -> void:
	var fh := Game.arena.floor_height_at(p.x, p.z)
	if fh > p.y + 0.5:
		fh = 0.0
	var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, 1, size))
	_decals.set_instance_transform(_decal_i, Transform3D(b, Vector3(p.x, fh + 0.02 + float(_decal_i % 7) * 0.003, p.z)))
	_decals.set_instance_color(_decal_i, Color(0.05, 0.04, 0.07, 1))
	_decal_i = (_decal_i + 1) % MAX_DECALS
	_decal_count = mini(_decal_count + 1, MAX_DECALS)
	_decals.visible_instance_count = _decal_count


func pool(p: Vector3, size: float) -> void:
	var fh := Game.arena.floor_height_at(p.x, p.z)
	if fh > p.y + 0.5:
		fh = 0.0
	decal(Vector3(p.x, fh, p.z), size, true)
	for k in 4:
		decal(Vector3(p.x + _rng.randf_range(-1, 1) * size * 0.5, fh, p.z + _rng.randf_range(-1, 1) * size * 0.5), size * _rng.randf_range(0.3, 0.6))


# ---------------------------------------------------------------- mist / emitters
func mist(p: Vector3, size := 1.2, count := 2) -> void:
	for k in count:
		var mat: ShaderMaterial = _mist_mat.duplicate()
		var q := Psx.quad(Vector2.ONE, mat, p + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.2, 0.3), _rng.randf_range(-0.3, 0.3)))
		q.scale = Vector3.ONE * size * 0.4
		add_child(q)
		_mists.append({"n": q, "m": mat, "t": 0.0, "life": _rng.randf_range(0.35, 0.6), "s": size * _rng.randf_range(0.8, 1.4)})
	while _mists.size() > 40:
		_mists.pop_front().n.queue_free()


func emitter(target: Node3D, offset: Vector3, dir: Vector3, rate: float, duration: float, speed := 7.0, spread := 0.25) -> void:
	_emitters.append({"node": target, "off": offset, "dir": dir, "rate": rate, "t": duration, "acc": 0.0, "speed": speed, "spread": spread})


# ---------------------------------------------------------------- gibs
func add_gib(node: Node3D, vel: Vector3, spin: Vector3, bleed := 1.0, half_h := 0.15) -> void:
	add_child(node)
	_gibs.append({"n": node, "v": vel, "spin": spin, "life": 0.0, "bleed": bleed, "rest": false, "hh": half_h})
	while _gibs.size() > MAX_GIBS:
		var old: Dictionary = _gibs.pop_front()
		if is_instance_valid(old.n):
			old.n.queue_free()


func chunks(p: Vector3, count: int, speed := 7.0) -> void:
	for k in count:
		var mi := MeshInstance3D.new()
		mi.mesh = _chunk_mesh
		mi.material_override = _chunk_mat
		mi.scale = Vector3.ONE * _rng.randf_range(0.6, 1.6)
		mi.position = p + Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2))
		var v := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.3, 1.4), _rng.randf_range(-1, 1)).normalized() * speed * _rng.randf_range(0.5, 1.2)
		add_gib(mi, v, Vector3(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12), _rng.randf_range(-12, 12)), 0.6, 0.07)


## Turn an enemy's body parts into flying gibs. `mode` decides the show.
func dismember(enemy: Enemy, mode: String, dir: Vector3, headshot := false) -> void:
	var center := enemy.global_position + Vector3(0, enemy.height * 0.55, 0)
	var size_k := enemy.height / 1.8
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() < 0.01:
		flat = -enemy.global_basis.z
	flat = flat.normalized()
	var parts := enemy.get_gib_parts()
	var head: Node3D = enemy.get_head()
	var neck_node: Node3D = null
	for part in parts:
		var src: Node3D = part
		var g: Node3D = src.duplicate()
		var gt := src.global_transform
		g.transform = gt
		var is_head := src == head
		var is_torso := src.name == "Torso"
		var v := Vector3.ZERO
		var spin := Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
		var bleed := 0.8
		var side_sign := signf((gt.origin - center).dot(flat.cross(Vector3.UP))) if mode == "split" else 0.0
		match mode:
			"headpop":
				# glory kill: shotgun under the chin, the head is gone
				if is_head:
					chunks(gt.origin, 9, 9.0)
					burst(gt.origin, Vector3.UP + flat * 0.4, 70, 9.0, 0.7, 3.0, 0.08)
					mist(gt.origin, 1.8, 4)
					continue
				v = flat * 1.2 + Vector3(0, 0.6, 0)
				spin *= 0.2
				bleed = 2.2
			"split":
				# glory kill: cleaved in two, the halves fall apart sideways
				if side_sign == 0.0:
					side_sign = 1.0 if _rng.randf() < 0.5 else -1.0
				v = flat.cross(Vector3.UP) * side_sign * _rng.randf_range(3.0, 5.0) + Vector3(0, _rng.randf_range(1.5, 3.5), 0)
				spin = Vector3(0, 0, -side_sign * _rng.randf_range(4, 9)).rotated(Vector3.UP, atan2(flat.x, flat.z))
				bleed = 2.4
			"execution":
				if is_head:
					v = Vector3(0, 11.0, 0) + flat * 2.5
					spin *= 1.6
					bleed = 2.0
				elif is_torso:
					v = flat * 1.5 + Vector3(0, 1.0, 0)
					spin *= 0.25
					bleed = 2.5
				else:
					v = flat * _rng.randf_range(1, 3) + Vector3(0, _rng.randf_range(1, 3), 0)
			"shotgun", "explode", "deflect":
				var out := (gt.origin - center).normalized()
				v = (flat * 9.0 + out * 6.0 + Vector3(0, 4.5, 0)) * _rng.randf_range(0.6, 1.2)
				spin *= 1.8
				if is_head and headshot:
					chunks(gt.origin, 6, 8.0)
					burst(gt.origin, Vector3.UP + flat, 40, 7.0, 0.8, 3.0, 0.08)
					mist(gt.origin, 1.4, 3)
					continue
			"katana":
				if is_head or is_torso or src.name.begins_with("Arm"):
					v = flat * _rng.randf_range(4, 7) + Vector3(0, _rng.randf_range(3, 6), 0)
				else:
					v = flat * 1.0 + Vector3(0, 1.0, 0)
					spin *= 0.4
				bleed = 1.4
			_:
				v = flat * 4.0 + Vector3(0, 3.0, 0)
		add_gib(g, v, spin, bleed, 0.12 * size_k)
		if is_torso:
			neck_node = g
	# the blood show
	match mode:
		"headpop":
			if neck_node:
				emitter(neck_node, Vector3(0, 0.45 * size_k, 0), Vector3.UP, 160.0, 2.0, 11.0, 0.18)
			burst(center + Vector3(0, 0.6, 0), Vector3.UP, 90, 8.0, 0.5, 3.0, 0.08)
			pool(center, 3.4 * size_k)
		"split":
			var side2 := flat.cross(Vector3.UP)
			burst(center, side2, 90, 9.0, 0.4, 3.0, 0.08)
			burst(center, -side2, 90, 9.0, 0.4, 3.0, 0.08)
			burst(center + Vector3(0, 0.6, 0), Vector3.UP, 120, 11.0, 0.3, 4.0, 0.09)
			chunks(center, 10, 7.0)
			mist(center, 2.8 * size_k, 5)
			pool(center, 4.0 * size_k)
		"execution":
			if neck_node:
				emitter(neck_node, Vector3(0, 0.3 * size_k, 0), Vector3.UP, 120.0, 1.8, 9.0, 0.28)
			burst(center + Vector3(0, 0.4, 0), Vector3.UP, 120, 9.0, 0.5, 4.0, 0.09)
			chunks(center, 8, 6.0)
			mist(center + Vector3(0, 0.5, 0), 2.6, 4)
			pool(center, 3.4 * size_k)
		"shotgun", "explode", "deflect":
			burst(center, flat + Vector3(0, 0.3, 0), int(110 * size_k), 10.0, 0.7, 3.0, 0.08)
			chunks(center, int(10 * size_k), 9.0)
			mist(center, 2.2 * size_k, 4)
			pool(center + flat * 1.5, 2.6 * size_k)
		"katana":
			var side := flat.cross(Vector3.UP)
			burst(center, side + flat * 0.5, 70, 9.0, 0.35, 2.0, 0.08)
			burst(center, -side + flat * 0.5, 40, 6.0, 0.5, 2.0, 0.07)
			if neck_node:
				emitter(neck_node, Vector3(0, 0.3 * size_k, 0), Vector3.UP, 60.0, 0.9, 6.5, 0.4)
			chunks(center, 4, 5.0)
			mist(center, 1.8 * size_k, 3)
			pool(center, 2.2 * size_k)
		_:
			burst(center, flat, 60, 7.0, 0.6, 3.0)
			pool(center, 2.0 * size_k)


# ---------------------------------------------------------------- update
func _physics_process(delta: float) -> void:
	_update_drops(delta)
	_update_gibs(delta)
	_update_emitters(delta)
	_update_mists(delta)


func _update_drops(delta: float) -> void:
	var g := Vector3(0, -GRAVITY * delta, 0)
	var i := 0
	while i < _n:
		_life[i] -= delta
		var k := _kind[i]
		var v := _vel[i] + (g if k == 0 else g * 0.6)
		var p := _pos[i] + v * delta
		var dead := _life[i] <= 0.0
		if not dead and p.y <= _floor[i]:
			if k == 0 and _rng.randf() < 0.22:
				decal(Vector3(p.x, _floor[i], p.z), _size[i] * _rng.randf_range(3.0, 8.0))
			dead = true
		if dead:
			_n -= 1
			if i != _n:
				_pos[i] = _pos[_n]
				_vel[i] = _vel[_n]
				_life[i] = _life[_n]
				_floor[i] = _floor[_n]
				_size[i] = _size[_n]
				_kind[i] = _kind[_n]
				_mm.set_instance_color(i, _mm.get_instance_color(_n))
			continue
		_pos[i] = p
		_vel[i] = v
		var s := _size[i]
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s * (1.0 + minf(v.length() * 0.08, 1.5)), s)), p))
		i += 1
	_mm.visible_instance_count = _n


func _update_gibs(delta: float) -> void:
	var i := 0
	while i < _gibs.size():
		var gb: Dictionary = _gibs[i]
		var n: Node3D = gb.n
		if not is_instance_valid(n):
			_gibs.remove_at(i)
			continue
		gb.life += delta
		if gb.life > 14.0:
			n.position.y -= delta * 0.4
			if gb.life > 16.0:
				n.queue_free()
				_gibs.remove_at(i)
				continue
		if not gb.rest:
			gb.v.y -= GRAVITY * delta
			var p: Vector3 = n.global_position + gb.v * delta
			if absf(p.x) > 31.6:
				p.x = signf(p.x) * 31.6
				gb.v.x *= -0.4
			if absf(p.z) > 31.6:
				p.z = signf(p.z) * 31.6
				gb.v.z *= -0.4
			var fh := Game.arena.floor_height_at(p.x, p.z) if Game.arena else 0.0
			if fh > n.global_position.y + 0.3:
				fh = 0.0
			if p.y - gb.hh < fh:
				p.y = fh + gb.hh
				if gb.v.y < -3.0:
					if gb.bleed > 0.0:
						decal(Vector3(p.x, fh, p.z), _rng.randf_range(0.5, 1.1))
					gb.v.y = -gb.v.y * 0.28
					gb.v.x *= 0.55
					gb.v.z *= 0.55
					gb.spin *= 0.5
				else:
					gb.v = Vector3.ZERO
					gb.rest = true
			n.global_position = p
			var sp: Vector3 = gb.spin
			if sp.length() > 0.01:
				n.global_basis = Basis(sp.normalized(), sp.length() * delta) * n.global_basis
			if gb.bleed > 0.0:
				gb.bleed -= delta
				if _rng.randf() < 0.7:
					spawn_drop(p, gb.v * 0.3 + Vector3(_rng.randf_range(-1, 1), 0.5, _rng.randf_range(-1, 1)), 1.0, 0.06)
		i += 1


func _update_emitters(delta: float) -> void:
	var i := 0
	while i < _emitters.size():
		var e: Dictionary = _emitters[i]
		e.t -= delta
		if e.t <= 0.0 or not is_instance_valid(e.node):
			_emitters.remove_at(i)
			continue
		var node: Node3D = e.node
		var origin: Vector3 = node.global_transform * e.off
		var dir: Vector3 = (node.global_basis * e.dir).normalized()
		if dir.y < 0.2:
			dir = (dir + Vector3.UP).normalized()
		e.acc += e.rate * delta * clampf(e.t, 0.2, 1.0)
		while e.acc >= 1.0:
			e.acc -= 1.0
			var rv: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * e.spread
			spawn_drop(origin, (dir + rv).normalized() * e.speed * _rng.randf_range(0.6, 1.2), 1.4, 0.075)
		i += 1


func _update_mists(delta: float) -> void:
	var i := 0
	while i < _mists.size():
		var m: Dictionary = _mists[i]
		m.t += delta
		var k: float = m.t / m.life
		if k >= 1.0:
			m.n.queue_free()
			_mists.remove_at(i)
			continue
		m.n.scale = Vector3.ONE * m.s * (0.4 + k * 0.9)
		m.n.position.y -= delta * 0.4
		m.m.set_shader_parameter("color", Color(0.55, 0.0, 0.03, 0.75 * (1.0 - k)))
		i += 1
