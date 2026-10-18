class_name RooftopMap
extends Arena
## SHIN-KAGURA ROOFTOP: a neon grid plaza on top of the city with a torii
## shrine in the middle, catwalks on both sides and jump pads.
## The run seed moves the cover around (crates, obelisks), recolours everything
## from the palette, varies the signs, skyline and weather.

var m_grid: ShaderMaterial
var m_chrome: ShaderMaterial
var m_dark: ShaderMaterial
var m_ramp: ShaderMaterial
var m_lacquer: ShaderMaterial
var m_windows: ShaderMaterial
var m_skyline: ShaderMaterial


func _init() -> void:
	map_name = "SHIN-KAGURA ROOFTOP"
	half = 32.0
	player_spawn = Vector3(0, 0.1, 24)
	boss_spawn = Vector3(0, 0, -22)


func _build_layout() -> void:
	_materials()
	_floor()
	_perimeter()
	_shrine()
	_catwalks()
	_cover()
	_jump_pads()
	_buildings()
	_skyline()
	_palms()
	_spawns()


func _materials() -> void:
	var base: Color = pal.floor
	m_grid = Psx.lit(base.lightened(0.15), TexGen.get_tex("grid"), true, 0.5, {"emission_from_texture": 2.4, "emission_tint": pal.grid, "fog_end": 110.0})
	m_chrome = Psx.lit(base.lightened(0.35), TexGen.get_tex("chrome"), true, 0.5, {"emission_color": pal.neon_a, "emission_strength": 0.05})
	m_dark = Psx.lit(base.lightened(0.08), TexGen.get_tex("noise"), true, 1.0)
	m_ramp = Psx.lit(base.lightened(0.2), TexGen.get_tex("grate"), true, 1.0, {"emission_from_texture": 0.6, "emission_tint": pal.neon_b})
	var lac: Color = pal.neon_a
	m_lacquer = Psx.lit(lac.darkened(0.25), TexGen.get_tex("lacquer"), true, 0.8, {"emission_color": lac, "emission_strength": 0.35})
	m_windows = Psx.lit(Color(0.85, 0.85, 1.0), TexGen.windows_for(pal, rng.randi() % 1000), true, 0.2, {"emission_from_texture": 1.8, "fog_end": 160.0})
	m_skyline = Psx.lit(Color(0.85, 0.85, 1.0), TexGen.windows_for(pal, 5000 + rng.randi() % 1000), true, 0.12, {"emission_from_texture": 2.0, "fog_start": 50.0, "fog_end": 380.0, "snap": 0.5})


func _floor() -> void:
	var tile := 16.0
	for ix in 4:
		for iz in 4:
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(tile, tile)
			pm.subdivide_width = 15
			pm.subdivide_depth = 15
			mi.mesh = pm
			mi.material_override = m_grid
			mi.position = Vector3(-half + tile * 0.5 + ix * tile, 0, -half + tile * 0.5 + iz * tile)
			add_child(mi)
	_solid(Vector3(half * 2 + 20, 2, half * 2 + 20), Vector3(0, -1, 0), m_grid, 0.0, 0, false)


func _perimeter() -> void:
	var h := 1.1
	var e := half + 0.3
	_solid(Vector3(half * 2 + 1.2, h, 0.6), Vector3(0, h * 0.5, -e), m_chrome)
	_solid(Vector3(half * 2 + 1.2, h, 0.6), Vector3(0, h * 0.5, e), m_chrome)
	_solid(Vector3(0.6, h, half * 2 + 1.2), Vector3(-e, h * 0.5, 0), m_chrome)
	_solid(Vector3(0.6, h, half * 2 + 1.2), Vector3(e, h * 0.5, 0), m_chrome)
	_neon(Vector3(half * 2 + 1.2, 0.09, 0.12), Vector3(0, h + 0.05, -e + 0.25), _accent(0), 3.0)
	_neon(Vector3(half * 2 + 1.2, 0.09, 0.12), Vector3(0, h + 0.05, e - 0.25), _accent(1), 3.0)
	_neon(Vector3(0.12, 0.09, half * 2 + 1.2), Vector3(-e + 0.25, h + 0.05, 0), _accent(3), 3.0)
	_neon(Vector3(0.12, 0.09, half * 2 + 1.2), Vector3(e - 0.25, h + 0.05, 0), _accent(4), 3.0)
	for s in [-1.0, 1.0]:
		_solid(Vector3(half * 2 + 4, 16, 1), Vector3(0, 8, s * (e + 0.5)), null, 0.0, 0, false)
		_solid(Vector3(1, 16, half * 2 + 4), Vector3(s * (e + 0.5), 8, 0), null, 0.0, 0, false)
	var corners := [Vector3(-29, 0, -29), Vector3(29, 0, -29), Vector3(-29, 0, 29), Vector3(29, 0, 29)]
	for k in corners.size():
		var c: Vector3 = corners[k]
		add_child(Psx.box(Vector3(0.3, 6, 0.3), m_dark, c + Vector3(0, 3, 0)))
		var col := _accent([2, 5, 5, 2][k])
		_neon(Vector3(0.6, 0.6, 0.6), c + Vector3(0, 6.2, 0), col, 3.5)
		_halo(c + Vector3(0, 6.2, 0), col, 3.0, 0.5)
		_light(c + Vector3(0, 5.5, 0), col, 1.7, 16.0)


func _shrine() -> void:
	var top := 2.4
	_platform(Vector3(12, top, 12), Vector3(0, top * 0.5, 0), m_chrome)
	_ramp(Vector3(0, 0, -13.5), Vector3(0, top, -6), 4.0, m_ramp)
	_ramp(Vector3(0, 0, 13.5), Vector3(0, top, 6), 4.0, m_ramp)
	_neon_box_edges(Vector3(0, top * 0.5, 0), Vector3(12, top, 12), 0.0, pal.neon_a, 3.0, true)
	for s in [-1.0, 1.0]:
		_neon(Vector3(12.1, 0.06, 0.06), Vector3(0, 0.03, s * 6.05), pal.neon_b, 2.4)
		_neon(Vector3(0.06, 0.06, 12.1), Vector3(s * 6.05, 0.03, 0), pal.neon_b, 2.4)
	var red: Color = pal.neon_a
	var g := Node3D.new()
	g.position = Vector3(0, top, 0)
	add_child(g)
	for s in [-1.0, 1.0]:
		var pil := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.32
		cm.bottom_radius = 0.38
		cm.height = 5.6
		cm.radial_segments = 8
		cm.rings = 4
		pil.mesh = cm
		pil.material_override = m_lacquer
		pil.position = Vector3(s * 3.3, 2.8, 0)
		g.add_child(pil)
		_neon(Vector3(0.08, 5.4, 0.08), Vector3(s * 3.3, 2.8, 0.36), red, 4.0, g)
		_neon(Vector3(0.08, 5.4, 0.08), Vector3(s * 3.3, 2.8, -0.36), red, 4.0, g)
		add_child(Psx.box(Vector3(1.0, 0.4, 1.0), m_dark, Vector3(s * 3.3, top + 0.2, 0)))
		var col := StaticBody3D.new()
		var csh := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.8, 5.6, 0.8)
		csh.shape = bs
		col.add_child(csh)
		col.position = Vector3(s * 3.3, top + 2.8, 0)
		add_child(col)
	g.add_child(Psx.box(Vector3(9.6, 0.5, 0.8), m_lacquer, Vector3(0, 5.75, 0)))
	g.add_child(Psx.box(Vector3(10.4, 0.25, 1.0), m_dark, Vector3(0, 6.1, 0)))
	g.add_child(Psx.box(Vector3(7.8, 0.35, 0.45), m_lacquer, Vector3(0, 4.5, 0)))
	_neon(Vector3(9.6, 0.07, 0.07), Vector3(0, 5.48, 0.42), red, 4.5, g)
	_neon(Vector3(9.6, 0.07, 0.07), Vector3(0, 5.48, -0.42), red, 4.5, g)
	_neon(Vector3(10.4, 0.07, 0.07), Vector3(0, 6.25, 0.5), pal.neon_c, 4.0, g)
	_neon(Vector3(7.8, 0.07, 0.07), Vector3(0, 4.3, 0.25), pal.neon_b, 4.0, g)
	var plaque := Psx.quad(Vector2(0.9, 1.4), Psx.unlit(pal.neon_c, 2.2, TexGen.get_tex("sign_v%d" % (rng.randi() % 8))), Vector3(0, 5.1, 0.26))
	g.add_child(plaque)
	_light(Vector3(0, top + 4.0, 2.5), red, 2.6, 18.0)
	_light(Vector3(0, top + 4.0, -2.5), red, 2.6, 18.0)
	_halo(Vector3(0, top + 5.4, 0), red, 12.0, 0.25)


func _catwalks() -> void:
	var h := 3.2
	for s in [-1.0, 1.0]:
		var x: float = s * 24.5
		_platform(Vector3(5, 0.45, 30), Vector3(x, h - 0.225, 0), m_chrome)
		for lz in [-12.5, -6.25, 0.0, 6.25, 12.5]:
			for lx in [-2.0, 2.0]:
				_solid(Vector3(0.5, h - 0.45, 0.5), Vector3(x + lx, (h - 0.45) * 0.5, lz), m_dark, 0.0, 1)
		_ramp(Vector3(x, 0, 22.5), Vector3(x, h, 15), 5.0, m_ramp)
		_ramp(Vector3(x, 0, -22.5), Vector3(x, h, -15), 5.0, m_ramp)
		var col := _accent(1) if s < 0 else _accent(3)
		_neon(Vector3(0.08, 0.08, 30), Vector3(x - s * 2.52, h + 0.04, 0), col, 3.0)
		_neon(Vector3(0.08, 0.08, 30), Vector3(x - s * 2.52, h - 0.45, 0), col, 2.0)
		for i in 7:
			add_child(Psx.box(Vector3(0.12, 1.0, 0.12), m_dark, Vector3(x + s * 2.4, h + 0.5, -13.5 + i * 4.5)))
		_neon(Vector3(0.08, 0.08, 30), Vector3(x + s * 2.4, h + 1.0, 0), _accent(2) if s < 0 else _accent(5), 2.2)
		_light(Vector3(x - s * 3.0, h + 2.0, -8), col, 1.6, 13.0)
		_light(Vector3(x - s * 3.0, h + 2.0, 8), col, 1.6, 13.0, s > 0)


## Seeded cover: a handful of neon crates and obelisks from a pool of slots.
func _cover() -> void:
	var crate_slots := [
		[Vector3(-12, 0, -20), 0.3], [Vector3(13, 0, -21), -0.2], [Vector3(-15, 0, 18.5), 1.4],
		[Vector3(14, 0, 17), 0.15], [Vector3(-8, 0, -26), 1.57], [Vector3(9, 0, 26), 1.57],
		[Vector3(-18, 0, -6), 0.0], [Vector3(18, 0, 7), 0.0], [Vector3(0, 0, -27), 1.57],
		[Vector3(-19, 0, 12), 0.0], [Vector3(19, 0, -12), 0.0],
	]
	for i in range(crate_slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = crate_slots[i]
		crate_slots[i] = crate_slots[j]
		crate_slots[j] = tmp
	var count := rng.randi_range(4, 6)
	for i in count:
		var p: Vector3 = crate_slots[i][0]
		var r: float = crate_slots[i][1]
		var size := Vector3(2.6, 2.7, 6.5)
		var mat := Psx.lit(Color(pal.floor).lightened(0.25), TexGen.get_tex("container"), false, 1.0, {"uv_tiling": Vector2(2, 1)})
		var pos := p + Vector3(0, size.y * 0.5, 0)
		_platform(size, pos, mat, r)
		_neon_box_edges(pos, size, r, _accent(i), 2.4)
		if i == 0:
			# a stacked crate for verticality
			var pos2 := pos + Vector3(0, size.y, 0)
			_platform(size, pos2, mat, r)
			_neon_box_edges(pos2, size, r, _accent(i + 3), 2.4)
	# neon obelisks: one of three layouts
	var layouts := [
		[Vector3(-14, 0, -9), Vector3(14, 0, -9), Vector3(-14, 0, 9), Vector3(14, 0, 9)],
		[Vector3(-10, 0, -16), Vector3(10, 0, -16), Vector3(-10, 0, 16), Vector3(10, 0, 16)],
		[Vector3(-15, 0, -6), Vector3(15, 0, 6), Vector3(-6, 0, 20), Vector3(6, 0, -20)],
	]
	var layout: Array = _pick(layouts)
	var i := 0
	for p in layout:
		var q: Vector3 = p
		_solid(Vector3(1.4, 8, 1.4), q + Vector3(0, 4, 0), m_chrome)
		var col := _accent(i + 3)
		for cx in [-0.72, 0.72]:
			for cz in [-0.72, 0.72]:
				_neon(Vector3(0.08, 7.5, 0.08), q + Vector3(cx, 4, cz), col, 3.5, null, 0.3 if (i == 2 and cx > 0 and cz > 0) else 0.0)
		_neon(Vector3(1.6, 0.1, 1.6), q + Vector3(0, 8.05, 0), _accent(i + 1), 3.0)
		_light(q + Vector3(0, 3.0, 0), col, 1.8, 12.0, i == 2)
		i += 1


func _jump_pads() -> void:
	var defs := [
		[Vector3(-17, 0, 0), Vector3(-8.0, 17.0, 0)],
		[Vector3(17, 0, 0), Vector3(8.0, 17.0, 0)],
		[Vector3(-9, 0, 0), Vector3(5.0, 16.0, 0)],
		[Vector3(9, 0, 0), Vector3(-5.0, 16.0, 0)],
	]
	var col: Color = pal.neon_c
	var pad_mat := Psx.unlit(col, 2.2, TexGen.get_tex("jumppad"), {"fog_amount": 0.3})
	for d in defs:
		var p: Vector3 = d[0]
		var base := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.35
		cm.bottom_radius = 1.45
		cm.height = 0.16
		cm.radial_segments = 12
		base.mesh = cm
		base.material_override = m_dark
		base.position = p + Vector3(0, 0.08, 0)
		add_child(base)
		var top := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(2.4, 2.4)
		top.mesh = pm
		top.material_override = pad_mat
		top.position = p + Vector3(0, 0.17, 0)
		add_child(top)
		for k in 2:
			var beam := Psx.quad(Vector2(2.4, 3.5), Psx.fx(Color(col.r, col.g, col.b, 0.25), TexGen.get_tex("glow"), true, false, false, 0.8), p + Vector3(0, 1.8, 0))
			beam.rotation.y = k * PI * 0.5
			add_child(beam)
		_light(p + Vector3(0, 1.0, 0), col, 1.2, 6.0)
		jump_pads.append({"pos": p, "r": 1.35, "launch": d[1]})


func _buildings() -> void:
	var defs := [
		[Vector3(-26, 0, -43), Vector3(24, 30, 14)],
		[Vector3(27, 0, -43), Vector3(26, 34, 14)],
		[Vector3(-22, 0, 44), Vector3(30, 16, 14)],
		[Vector3(20, 0, 45), Vector3(32, 21, 16)],
		[Vector3(43, 0, -12), Vector3(14, 38, 30)],
		[Vector3(44, 0, 19), Vector3(16, 25, 24)],
		[Vector3(-44, 0, -10), Vector3(16, 54, 28)],
		[Vector3(-43, 0, 21), Vector3(14, 23, 26)],
	]
	for d in defs:
		var c: Vector3 = d[0]
		var s: Vector3 = d[1]
		s.y *= rng.randf_range(0.8, 1.25)
		var pos := c + Vector3(0, s.y * 0.5 - 12.0, 0)
		add_child(Psx.box(s, m_windows, pos, 4))
		_neon_box_edges(pos, s, 0.0, _pick(pal.accents), 2.0, true)
	# neon signs and billboards facing the arena (texture, colour and flicker are seeded)
	var spots := [
		[Vector3(-20, 14, -35.9), 0.0, "v"], [Vector3(6, 20, -36.9), 0.0, "v"], [Vector3(-4, 9, -36.9), 0.0, "h"],
		[Vector3(20, 12, -35.9), 0.0, "ad"], [Vector3(35.9, 15, -14), -PI * 0.5, "v"], [Vector3(35.9, 10, 10), -PI * 0.5, "ad"],
		[Vector3(-35.9, 18, -6), PI * 0.5, "ad"], [Vector3(-35.9, 8, 16), PI * 0.5, "h"], [Vector3(-12, 3, 36.9), PI, "h"],
		[Vector3(14, 6, 36.9), PI, "v"],
	]
	for sp in spots:
		var kind: String = sp[2]
		var col: Color = _pick(pal.accents)
		var tex_name := ""
		var size := Vector2.ZERO
		var energy := 2.8
		match kind:
			"v":
				tex_name = "sign_v%d" % (rng.randi() % 8)
				size = Vector2(2.4, 9.6)
			"h":
				tex_name = "sign_h%d" % (rng.randi() % 8)
				size = Vector2(12, 3)
			_:
				tex_name = "ad%d" % (rng.randi() % 6)
				size = Vector2(14, 7)
				col = Color(1, 1, 1)
				energy = 1.4
		var flick := 0.45 if rng.randf() < 0.2 else 0.0
		var q := Psx.quad(size, Psx.unlit(col, energy, TexGen.get_tex(tex_name), {"flicker": flick, "fog_amount": 0.35}), sp[0])
		q.rotation.y = sp[1]
		add_child(q)
		_halo(sp[0] + Vector3.FORWARD.rotated(Vector3.UP, sp[1]) * -0.5, col, maxf(size.x, size.y) * 1.3, 0.2)
	var holo := Psx.quad(Vector2(60, 30), Psx.unlit(_accent(4), 0.9, TexGen.get_tex("ad%d" % (rng.randi() % 6)), {"flicker": 0.15, "fog_amount": 0.15}), Vector3(rng.randf_range(-60, 60), 70, -150))
	holo.rotation.y = rng.randf_range(-0.3, 0.3)
	add_child(holo)


func _skyline() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	var count := 110
	mm.instance_count = count
	var beacons: Array[Vector3] = []
	for i in count:
		var ang := rng.randf() * TAU
		# leave a gap to the north so the sun shows between the towers
		var north := absf(angle_difference(ang, -PI * 0.5)) < 0.35
		var dist := rng.randf_range(75, 190) + (80.0 if north else 0.0)
		var w := rng.randf_range(10, 26)
		var h := rng.randf_range(25, 130) * (0.45 if north else 1.0)
		var p := Vector3(cos(ang) * dist, h * 0.5 - 20.0, sin(ang) * dist)
		var b := Basis(Vector3.UP, rng.randf() * PI).scaled(Vector3(w, h, rng.randf_range(10, 26)))
		mm.set_instance_transform(i, Transform3D(b, p))
		if rng.randf() < 0.25:
			beacons.append(p + Vector3(0, h * 0.5 + 1.0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m_skyline
	add_child(mmi)
	var beacon_mat := Psx.unlit(_accent(5), 3.0, null, {"flicker": 0.6, "fog_amount": 0.1})
	for bpos in beacons:
		add_child(Psx.box(Vector3(1.2, 1.2, 1.2), beacon_mat, bpos))


## Neon palm trees: the synthwave signature, planted just outside the barrier.
func _palms() -> void:
	var trunk_mat := Psx.lit(Color(pal.floor).lightened(0.12), TexGen.get_tex("noise"), false, 1.0)
	var leaf_mat := Psx.unlit(Color(pal.mountain).lightened(0.1), 1.0, null, {"fog_amount": 0.4})
	var spots := [Vector3(-36, 0, -36), Vector3(36, 0, -36), Vector3(-36, 0, 36), Vector3(36, 0, 36), Vector3(-36, 0, 0), Vector3(36, 0, 0)]
	for p in spots:
		if rng.randf() < 0.25:
			continue
		_palm(p, trunk_mat, leaf_mat)


func _palm(p: Vector3, trunk_mat: Material, leaf_mat: Material) -> void:
	var tree := Node3D.new()
	tree.position = p
	tree.rotation.y = rng.randf() * TAU
	add_child(tree)
	var h := rng.randf_range(7.0, 10.0)
	var lean := rng.randf_range(0.04, 0.1)
	var top := Vector3.ZERO
	for k in 8:
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22 - k * 0.012
		cm.bottom_radius = 0.26 - k * 0.012
		cm.height = h / 8.0 + 0.05
		cm.radial_segments = 6
		cm.rings = 1
		seg.mesh = cm
		seg.material_override = trunk_mat
		top = Vector3(lean * k * k * 0.4, h / 8.0 * (k + 0.5), 0)
		seg.position = top
		seg.rotation.z = -lean * k * 0.8
		tree.add_child(seg)
	var crown := top + Vector3(0, h / 16.0, 0)
	var glow: Color = _pick(pal.accents)
	for f in 8:
		var frond := Node3D.new()
		frond.position = crown
		frond.rotation = Vector3(0, f * TAU / 8.0 + rng.randf_range(-0.2, 0.2), 0)
		tree.add_child(frond)
		var leaf := Psx.box(Vector3(0.12, 0.06, 3.2), leaf_mat, Vector3(0, -0.5, 1.5))
		leaf.rotation.x = 0.5
		frond.add_child(leaf)
		var rim := Psx.box(Vector3(0.05, 0.05, 3.1), Psx.unlit(glow, 2.2, null, {"fog_amount": 0.3}), Vector3(0, -0.46, 1.52))
		rim.rotation.x = 0.5
		frond.add_child(rim)


func _spawns() -> void:
	spawn_points = [
		Vector3(-28, 0, -28), Vector3(0, 0, -29), Vector3(28, 0, -28),
		Vector3(-29.5, 0, -6), Vector3(29.5, 0, 6), Vector3(-29.5, 0, 10), Vector3(29.5, 0, -10),
		Vector3(-28, 0, 28), Vector3(0, 0, 29.5), Vector3(28, 0, 28),
		Vector3(-18, 0, -28), Vector3(18, 0, -28), Vector3(-18, 0, 28.5), Vector3(18, 0, 28.5),
		Vector3(-24.5, 3.2, -8), Vector3(24.5, 3.2, 8), Vector3(-24.5, 3.2, 9), Vector3(24.5, 3.2, -9),
	]
