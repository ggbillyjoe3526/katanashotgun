class_name CityBackdrop
extends Node3D
## The living city around a rooftop map: towers with lit windows, neon trim,
## signs, billboards and corporation logos, plus things that move (flying-car
## traffic, a monorail, a blimp, sweeping searchlights and a slowly drifting
## sun). Presentation only: it draws one number from the map stream and keeps
## its own RNG, so it can never shift gameplay. Cheap to draw: tower bodies,
## neon trim and traffic are MultiMeshes; nothing here casts light. Its
## CityWatch makes the city react to the run (news drones, live screens).

const LOGO_FONT := preload("res://assets/fonts/orbitron_900.woff2")
## Invented corporations (spec §13 naming: Japanese root + cyberpunk trade).
const CORPS := [
	["AMATERASU", "DYNAMICS"], ["TENGU", "AEROSPACE"], ["INARI", "FOODS"],
	["TSUKUYOMI", "MEDIA"], ["OMOIKANE", "SYSTEMS"], ["KAPPA", "HYDRO"],
]
const TRAFFIC_LANES := [
	# radius, height, speed (m/s, sign = direction), cars
	[45.0, 13.0, 18.0, 6], [57.0, 22.0, -24.0, 8], [118.0, 36.0, 30.0, 12], [140.0, 52.0, -24.0, 14],
]
const SUN_DRIFT := 0.35 # radians either side of the seeded azimuth, kept inside the skyline gap
const SUN_PERIOD := 600.0 # seconds for one sweep there and back

var arena: Arena
var pal: Dictionary
var rng := RandomNumberGenerator.new()
var accents: Array = []
var m_tower: ShaderMaterial
var _strips := {} # Color -> Array[Transform3D], batched into one MultiMesh per colour
var _towers: Array[Transform3D] = []
var _cars: MultiMesh
var _car_state: Array = [] # [lane index, angle]
var _train: Node3D
var _train_x := 0.0
var _blimp: Node3D
var _blimp_a := 0.0
var _beams: Array[Node3D] = []
var _sun_base := 0.0
var _t := 0.0
var watch: CityWatch


func build(a: Arena) -> void:
	arena = a
	pal = a.pal
	accents = pal.accents
	rng.seed = a.rng.randi()
	m_tower = Psx.lit(Color(0.85, 0.85, 1.0), TexGen.windows_for(pal, rng.randi() % 1000), true, 0.045, {"emission_from_texture": 1.9, "fog_start": 60.0, "fog_end": 300.0})
	_sun_base = float(a.sky_mat.get_shader_parameter("sun_azimuth"))
	_ring_towers()
	_traffic()
	_monorail()
	_blimp_build()
	_searchlights()
	watch = CityWatch.new()
	add_child(watch)
	watch.build(self) # before the flush: its masts and frames join the batches
	_flush_batches()
	# things that move stay out of INSANE's global illumination
	for n: Node in [_train, _blimp] + _beams:
		Graphics.moving(n)


# ---------------------------------------------------------------- towers
## A ring of towers around the roof, each turned so one face looks at the
## arena: lit windows, setbacks, crowns, neon trim, signs and logos.
func _ring_towers() -> void:
	var count := 18
	var logo_slots := [1, 4, 7, 11, 14, 16]
	for i in count:
		var ang := TAU * float(i) / count + rng.randf_range(-0.08, 0.08)
		# north (-z) is where the sun sets: keep towers there lower and further
		var north := absf(angle_difference(ang, -PI * 0.5)) < 0.5
		var dist := rng.randf_range(72.0, 92.0) + (16.0 if north else 0.0)
		var c := Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		var w := rng.randf_range(12.0, 20.0)
		var d := rng.randf_range(12.0, 18.0)
		var h := rng.randf_range(30.0, 66.0) * (0.55 if north else 1.0)
		var yaw := atan2(-c.x, -c.z) # local +z faces the arena
		var basis := Basis(Vector3.UP, yaw)
		var base_y := -40.0
		_tower_box(c, basis, Vector3(w, h - base_y, d), base_y)
		var top := h
		var face := basis * Vector3(0, 0, d * 0.5 + 0.06)
		var col: Color = accents[i % accents.size()]
		var col2: Color = accents[(i + 2) % accents.size()]
		# corner strips and a few floor bands
		for sx in [-1.0, 1.0]:
			_strip(c + basis * Vector3(sx * w * 0.5, (top + base_y) * 0.5, d * 0.5), basis, Vector3(0.18, top - base_y, 0.18), col)
		for k in rng.randi_range(1, 3):
			var by := rng.randf_range(4.0, top - 6.0)
			_strip(c + face + Vector3(0, by, 0), basis, Vector3(w, 0.16, 0.12), col2)
		_strip(c + basis * Vector3(0, top, d * 0.5), basis, Vector3(w + 0.2, 0.2, 0.2), col)
		# setback upper block
		if rng.randf() < 0.55:
			var w2 := w * rng.randf_range(0.5, 0.7)
			var d2 := d * rng.randf_range(0.5, 0.7)
			var h2 := rng.randf_range(8.0, 20.0)
			_tower_box(c, basis, Vector3(w2, h2, d2), top)
			_strip(c + basis * Vector3(0, top + h2, d2 * 0.5), basis, Vector3(w2 + 0.2, 0.2, 0.2), col2)
			top += h2
		_crown(c, basis, top, w, d, col2)
		# signs on the arena-facing face
		var sign_count := rng.randi_range(1, 3)
		for k in sign_count:
			var kind := rng.randi() % 3
			var sx2 := rng.randf_range(-w * 0.35, w * 0.35)
			var sy := rng.randf_range(6.0, h - 10.0)
			var p := c + basis * Vector3(sx2, sy, d * 0.5 + 0.3)
			var sc: Color = accents[rng.randi() % accents.size()]
			match kind:
				0:
					_sign(p, yaw, "sign_v%d" % (rng.randi() % 8), Vector2(3.6, 14.4), sc, 2.8)
				1:
					_sign(p, yaw, "sign_h%d" % (rng.randi() % 8), Vector2(16, 4), sc, 2.8)
				_:
					_sign(p, yaw, "ad%d" % (rng.randi() % 6), Vector2(18, 9), Color(1, 1, 1), 1.5)
		if i in logo_slots:
			_logo(c + basis * Vector3(0, top - 9.0, d * 0.5 + 0.4), yaw, CORPS[logo_slots.find(i)], col)


func _tower_box(c: Vector3, basis: Basis, size: Vector3, y0: float) -> void:
	_towers.append(Transform3D(basis.scaled(size), c + Vector3(0, y0 + size.y * 0.5, 0)))


## Rooftop dressing on a tower: an antenna with a blinking beacon, a water
## tower, a helipad ring or a rooftop billboard.
func _crown(c: Vector3, basis: Basis, top: float, w: float, d: float, col: Color) -> void:
	match rng.randi() % 4:
		0:
			var mh := rng.randf_range(8.0, 18.0)
			_strip(c + Vector3(0, top + mh * 0.5, 0), basis, Vector3(0.3, mh, 0.3), Color(0.25, 0.25, 0.32))
			var beacon := Psx.box(Vector3(0.9, 0.9, 0.9), Psx.unlit(Color("ff2a3a"), 3.5, null, {"flicker": 0.7, "fog_amount": 0.1}), c + Vector3(0, top + mh, 0))
			add_child(beacon)
		1:
			var tank := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 2.4
			cm.bottom_radius = 2.4
			cm.height = 4.0
			cm.radial_segments = 8
			tank.mesh = cm
			tank.material_override = Psx.lit(Color(pal.floor).lightened(0.25), TexGen.get_tex("noise"), true, 0.5)
			tank.position = c + basis * Vector3(w * 0.2, top + 2.5, -d * 0.15)
			add_child(tank)
			_strip(c + basis * Vector3(w * 0.2, top + 4.55, -d * 0.15), basis, Vector3(4.9, 0.12, 4.9), col)
		2:
			_strip(c + Vector3(0, top + 0.15, 0), basis, Vector3(w * 0.6, 0.12, 0.25), col)
			_strip(c + Vector3(0, top + 0.15, 0), basis, Vector3(0.25, 0.12, d * 0.6), col)
		_:
			var p := c + basis * Vector3(0, top + 4.5, d * 0.25)
			_strip(p + basis * Vector3(-5.5, -2.0, 0), basis, Vector3(0.3, 5.0, 0.3), Color(0.25, 0.25, 0.32))
			_strip(p + basis * Vector3(5.5, -2.0, 0), basis, Vector3(0.3, 5.0, 0.3), Color(0.25, 0.25, 0.32))
			_sign(p + Vector3(0, 1.0, 0), atan2(basis.z.x, basis.z.z), "ad%d" % (rng.randi() % 6), Vector2(12, 6), Color(1, 1, 1), 1.6)


func _sign(p: Vector3, yaw: float, tex: String, size: Vector2, col: Color, energy: float) -> void:
	var flick := 0.45 if rng.randf() < 0.18 else 0.0
	var q := Psx.quad(size, Psx.unlit(col, energy, TexGen.get_tex(tex), {"flicker": flick, "fog_amount": 0.3, "fog_end": 300.0}), p)
	q.rotation.y = yaw
	add_child(q)


## A corporation logo: a neon mark and the name in two lines.
func _logo(p: Vector3, yaw: float, corp: Array, col: Color) -> void:
	var root := Node3D.new()
	root.position = p
	root.rotation.y = yaw
	root.scale = Vector3.ONE * 1.8
	add_child(root)
	var mark := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.5
	tm.outer_radius = 2.1
	tm.rings = 12
	tm.ring_segments = 4
	mark.mesh = tm
	mark.rotation.x = PI * 0.5
	mark.material_override = Psx.unlit(col, 3.0, null, {"fog_amount": 0.2, "fog_end": 300.0})
	mark.position = Vector3(0, 2.6, 0)
	root.add_child(mark)
	var dot := Psx.box(Vector3(1.0, 1.0, 0.2), Psx.unlit(Color(1, 1, 1), 2.5, null, {"fog_amount": 0.2}), Vector3(0, 2.6, 0))
	dot.rotation.z = PI * 0.25
	root.add_child(dot)
	for k in 2:
		var l := Label3D.new()
		l.text = corp[k]
		l.font = LOGO_FONT
		l.font_size = 64 if k == 0 else 40
		l.pixel_size = 0.05
		l.outline_size = 0
		l.shaded = false
		l.double_sided = false
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.modulate = (col if k == 0 else Color(1, 1, 1)) * 2.2
		l.position = Vector3(0, -0.6 - k * 2.6, 0)
		root.add_child(l)


# ---------------------------------------------------------------- traffic
func _traffic() -> void:
	var mesh := ArrayMesh.new()
	_car_part(mesh, Vector3(1.8, 0.7, 4.0), Vector3.ZERO, Psx.lit(Color(pal.floor).lightened(0.3), TexGen.get_tex("chrome"), false, 1.0))
	_car_part(mesh, Vector3(1.6, 0.2, 0.1), Vector3(0, 0.05, -2.02), Psx.unlit(Color(1.0, 0.95, 0.85), 4.0, null, {"fog_amount": 0.15}))
	_car_part(mesh, Vector3(1.6, 0.2, 0.1), Vector3(0, 0.05, 2.02), Psx.unlit(Color("ff2a3a"), 4.0, null, {"fog_amount": 0.15}))
	var under: Color = accents[1]
	_car_part(mesh, Vector3(1.4, 0.06, 3.4), Vector3(0, -0.38, 0), Psx.unlit(under, 3.0, null, {"fog_amount": 0.2}))
	_car_part(mesh, Vector3(0.9, 0.12, 9.0), Vector3(0, 0.05, 6.6), Psx.fx(Color(1.0, 0.15, 0.25, 0.35), null, true))
	var total := 0
	for lane in TRAFFIC_LANES:
		total += int(lane[3])
	_cars = MultiMesh.new()
	_cars.transform_format = MultiMesh.TRANSFORM_3D
	_cars.mesh = mesh
	_cars.instance_count = total
	for li in TRAFFIC_LANES.size():
		var n: int = TRAFFIC_LANES[li][3]
		for k in n:
			_car_state.append([li, TAU * float(k) / n + rng.randf_range(-0.15, 0.15)])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _cars
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-160, 0, -160), Vector3(320, 70, 320))
	Graphics.moving(mmi)
	add_child(mmi)
	_update_cars(0.0)
	_on_quality(Quality.preset)
	Quality.on_changed(_on_quality)


## Fewer flying cars on lower presets: the outer lanes empty first.
func _on_quality(_id: String) -> void:
	_cars.visible_instance_count = mini(Quality.cap("traffic"), _cars.instance_count)


func _exit_tree() -> void:
	Quality.off_changed(_on_quality)


func _car_part(mesh: ArrayMesh, size: Vector3, offset: Vector3, mat: Material) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var arrays := bm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] += offset
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


func _update_cars(delta: float) -> void:
	for i in _car_state.size():
		var s: Array = _car_state[i]
		var lane: Array = TRAFFIC_LANES[s[0]]
		var r: float = lane[0]
		var speed: float = lane[2]
		s[1] = fposmod(float(s[1]) + speed / r * delta, TAU)
		var a: float = s[1]
		var pos := Vector3(cos(a) * r, float(lane[1]) + sin(a * 3.0 + r) * 1.5, sin(a) * r)
		var fwd := Vector3(-sin(a), 0, cos(a)) * signf(speed)
		# local -z is the nose
		var basis := Basis.looking_at(fwd, Vector3.UP)
		_cars.set_instance_transform(i, Transform3D(basis, pos))


# ---------------------------------------------------------------- monorail
func _monorail() -> void:
	var z := 50.0 # between the roof and the tower ring, so it passes close
	var y := 8.0
	_strip(Vector3(0, y - 0.9, z), Basis.IDENTITY, Vector3(420, 0.8, 1.6), Color(0.22, 0.22, 0.3))
	_strip(Vector3(0, y - 0.5, z - 0.85), Basis.IDENTITY, Vector3(420, 0.12, 0.12), accents[2])
	for x in range(-200, 201, 25):
		_strip(Vector3(x, y - 25.0, z), Basis.IDENTITY, Vector3(1.2, 48.0, 1.2), Color(0.18, 0.18, 0.25))
	_train = Node3D.new()
	_train.position = Vector3(-200, y, z)
	add_child(_train)
	var body := Psx.lit(Color(0.75, 0.78, 0.9), TexGen.get_tex("chrome"), false, 1.0)
	var glow := Psx.unlit(Color(1.0, 0.92, 0.75), 2.6, null, {"fog_amount": 0.2})
	for k in 4:
		var x := -k * 13.0
		_train.add_child(Psx.box(Vector3(12.4, 2.6, 2.8), body, Vector3(x, 0.4, 0)))
		_train.add_child(Psx.box(Vector3(11.0, 0.7, 2.9), glow, Vector3(x, 0.7, 0)))
	_train.add_child(Psx.box(Vector3(0.2, 0.5, 2.0), Psx.unlit(accents[0], 4.0), Vector3(6.3, 0.2, 0)))


func _blimp_build() -> void:
	_blimp = Node3D.new()
	add_child(_blimp)
	var hull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 10
	sm.rings = 6
	hull.mesh = sm
	hull.scale = Vector3(9.0, 8.0, 28.0)
	hull.material_override = Psx.lit(Color(pal.floor).lightened(0.35), TexGen.get_tex("chrome"), false, 1.0, {"fog_start": 60.0, "fog_end": 260.0})
	_blimp.add_child(hull)
	for s in [-1.0, 1.0]:
		var screen := Psx.quad(Vector2(30, 10), Psx.unlit(Color(1, 1, 1), 1.8, TexGen.get_tex("ad%d" % (rng.randi() % 6)), {"fog_amount": 0.15, "fog_end": 260.0}), Vector3(s * 9.3, -0.5, 0))
		screen.rotation.y = s * PI * 0.5
		_blimp.add_child(screen)
	_blimp.add_child(Psx.box(Vector3(0.4, 0.4, 0.4), Psx.unlit(Color("ff2a3a"), 4.0, null, {"flicker": 0.8}), Vector3(0, -8.2, -10)))
	_blimp_a = rng.randf() * TAU
	_place_blimp()


func _place_blimp() -> void:
	var r := 150.0
	_blimp.position = Vector3(cos(_blimp_a) * r, 72.0, sin(_blimp_a) * r)
	_blimp.rotation.y = -_blimp_a


func _searchlights() -> void:
	var mat := Psx.fx(Color(0.75, 0.85, 1.0, 0.16), TexGen.get_tex("glow"), true)
	for k in 3:
		var a := rng.randf() * TAU
		var root := Node3D.new()
		root.position = Vector3(cos(a) * 125.0, 10.0, sin(a) * 125.0)
		add_child(root)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 7.0
		cm.bottom_radius = 0.6
		cm.height = 160.0
		cm.radial_segments = 8
		cm.cap_top = false
		cm.cap_bottom = false
		cone.mesh = cm
		cone.material_override = mat
		cone.position = Vector3(0, 80.0, 0)
		var pivot := Node3D.new()
		pivot.rotation = Vector3(rng.randf_range(0.25, 0.5), rng.randf() * TAU, 0)
		pivot.add_child(cone)
		root.add_child(pivot)
		_beams.append(pivot)


# ---------------------------------------------------------------- batching
## A neon (or dark) box of `size` along `basis`'s own axes, batched with
## every other box of its colour; CityWatch adds its masts and screen frames
## this way.
func add_strip(pos: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	if not _strips.has(col):
		_strips[col] = []
	_strips[col].append(Transform3D(basis * Basis.from_scale(size), pos))


func _strip(pos: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	if not _strips.has(col):
		_strips[col] = []
	_strips[col].append(Transform3D(basis.scaled(size), pos))


func _flush_batches() -> void:
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for col in _strips:
		var list: Array = _strips[col]
		var lum: float = col.get_luminance()
		var mat: Material = Psx.unlit(col, 3.0, null, {"fog_amount": 0.3, "fog_end": 300.0}) if lum > 0.35 or col.s > 0.4 else Psx.lit(col, null, false, 1.0, {"fog_end": 300.0})
		add_child(_multi(unit, mat, list))
	add_child(_multi(unit, m_tower, _towers))
	_strips.clear()
	_towers.clear()


func _multi(mesh: Mesh, mat: Material, list: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


# ---------------------------------------------------------------- motion
func _process(delta: float) -> void:
	_t += delta
	_update_cars(delta)
	_train_x += 34.0 * delta
	if _train_x > 460.0:
		_train_x = -rng.randf_range(0.0, 200.0) # a gap before the next train
	_train.position.x = -230.0 + _train_x
	_blimp_a += 0.012 * delta
	_place_blimp()
	for i in _beams.size():
		_beams[i].rotation.y += (0.25 + i * 0.07) * delta * (1.0 if i % 2 == 0 else -1.0)
	var sweep := sin(_t * TAU / SUN_PERIOD)
	arena.sky_mat.set_shader_parameter("sun_azimuth", clampf(_sun_base + sweep * SUN_DRIFT * 0.5, -SUN_DRIFT, SUN_DRIFT))
	arena.sky_mat.set_shader_parameter("sun_height", 0.1 + 0.05 * cos(_t * TAU / SUN_PERIOD))
