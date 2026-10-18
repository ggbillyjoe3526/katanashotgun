class_name WellMap
extends RooftopMap
## SHIN-KAGURA ROOFTOP, vertical update ("The Well", concept A, picked by the
## owner 2026-10-18). The roof's centre is cut open: a 24 m shaft drops 10 m
## to a metro platform, with service blocks and balconies at -5. A torii bridge
## crosses the shaft at +5; a north deck climbs to a shrine tower at +10 and a
## beacon cap at +13; catwalks, a billboard gantry and container stacks break
## up the roof ring. Every step uses the climb heights of design note
## design/vertical-map/heights.md: 1.2 m hop, 3 m mantle, 5 m grab ledge (amber
## lip), 7 m+ sheer (never climbable). The city around it is a CityBackdrop.
## Enemies path over a baked navmesh with leap links (Arena._build_navigation).

const AMBER := Color("ffa21f") # grab-ledge lip: fixed so it reads the same in every palette
const SHAFT := 12.0 # half-width of the shaft
const DECK := 5.0 # catwalks, bridge and north deck
const FLOOR := -10.0 # metro platform
const SERVICE := -5.0 # service blocks and balconies

var m_wall: ShaderMaterial
var m_under: ShaderMaterial
var backdrop: CityBackdrop


func _init() -> void:
	map_name = "SHIN-KAGURA ROOFTOP"
	half = 32.0
	player_spawn = Vector3(0, 0.1, 24)
	boss_spawn = Vector3(0, 0, -17)
	floor_base = FLOOR
	kill_y = -20.0
	enemy_reset = Vector3(0, 6, -17)
	use_navigation = true


func _build_layout() -> void:
	_materials()
	# bigger windows on the far skyline, to match the scale of the backdrop towers
	m_skyline.set_shader_parameter("uv_scale", 0.05)
	m_wall = Psx.lit(Color(pal.floor).lightened(0.16), TexGen.get_tex("chrome"), true, 0.5, {"emission_color": _accent(1), "emission_strength": 0.03})
	m_under = Psx.lit(Color(pal.floor).lightened(0.32), TexGen.get_tex("chrome"), true, 0.35, {"emission_color": _accent(0), "emission_strength": 0.06})
	_roof()
	_shaft()
	_north()
	_side_catwalks()
	_bridge()
	_ring()
	_spawn_sources()
	_edge()
	_skyline()
	var trunk_mat := Psx.lit(Color(pal.floor).lightened(0.12), TexGen.get_tex("noise"), false, 1.0)
	var leaf_mat := Psx.unlit(Color(pal.mountain).lightened(0.1), 1.0, null, {"fog_amount": 0.4})
	for p in [Vector3(-9, 1.2, 25), Vector3(9, 1.2, 25)]:
		_palm(p, trunk_mat, leaf_mat)
	backdrop = CityBackdrop.new()
	add_child(backdrop)
	backdrop.build(self)
	_spawn_list()


# ---------------------------------------------------------------- helpers
## A solid block from y0 to top with a thin grid cap, so floors read as floors.
func _deck(x0: float, x1: float, z0: float, z1: float, y0: float, top: float, wall: Material = null) -> void:
	if top - y0 > 0.2:
		_solid(Vector3(x1 - x0, top - y0 - 0.1, z1 - z0), Vector3((x0 + x1) * 0.5, (y0 + top - 0.1) * 0.5, (z0 + z1) * 0.5), wall if wall else m_wall, 0.0, 1)
	_platform(Vector3(x1 - x0, 0.1, z1 - z0), Vector3((x0 + x1) * 0.5, top - 0.05, (z0 + z1) * 0.5), m_grid)


func _wall(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, mat: Material = null) -> void:
	_solid(Vector3(x1 - x0, y1 - y0, z1 - z0), Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), mat if mat else m_wall, 0.0, 1)


## Amber lip along a grabbable top edge from a to b (axis-aligned, same y).
func _lip(a: Vector3, b: Vector3) -> void:
	var c := (a + b) * 0.5
	var d := b - a
	var size := Vector3(absf(d.x) + 0.14, 0.12, absf(d.z) + 0.14)
	_neon(size, c + Vector3(0, 0.02, 0), AMBER, 3.6)
	_neon(size * Vector3(1, 0.5, 1), c + Vector3(0, -0.35, 0), AMBER, 1.6)


func _trim(a: Vector3, b: Vector3, col: Color, energy := 2.6) -> void:
	var d := b - a
	_neon(Vector3(absf(d.x) + 0.1, absf(d.y) + 0.1, absf(d.z) + 0.1), (a + b) * 0.5, col, energy)


func _sign_at(p: Vector3, yaw: float, tex: String, size: Vector2, col: Color, energy := 2.8) -> void:
	var q := Psx.quad(size, Psx.unlit(col, energy, TexGen.get_tex(tex), {"fog_amount": 0.3}), p)
	q.rotation.y = yaw
	add_child(q)
	_halo(p, col, maxf(size.x, size.y) * 1.1, 0.16)


func _cylinder(p: Vector3, r: float, h: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = p + Vector3(0, h * 0.5, 0)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)


func _crate(p: Vector3, h: float, col: Color, rot := 0.0) -> void:
	var size := Vector3(2.6, h, 4.0)
	var mat := Psx.lit(Color(pal.floor).lightened(0.25), TexGen.get_tex("container"), false, 1.0, {"uv_tiling": Vector2(2, 1)})
	_platform(size, p + Vector3(0, h * 0.5, 0), mat, rot)
	_neon_box_edges(p + Vector3(0, h * 0.5, 0), size, rot, col, 2.4)


# ---------------------------------------------------------------- layout
## Roof ring (0) around the shaft opening.
func _roof() -> void:
	_deck(-32, 32, -32, -SHAFT, -1, 0)
	_deck(-32, 32, SHAFT, 32, -1, 0)
	_deck(-32, -SHAFT, -SHAFT, SHAFT, -1, 0)
	_deck(SHAFT, 32, -SHAFT, SHAFT, -1, 0)
	for s in [-1.0, 1.0]:
		_lip(Vector3(-SHAFT, 0, s * SHAFT), Vector3(SHAFT, 0, s * SHAFT))
		_lip(Vector3(s * SHAFT, 0, -SHAFT), Vector3(s * SHAFT, 0, SHAFT))


## The shaft: metro platform (-10), service blocks and balconies (-5), ramps.
func _shaft() -> void:
	var e := SHAFT + 1.0
	_wall(-e, e, -e, -SHAFT, -11, -1, m_under)
	_wall(-e, e, SHAFT, e, -11, -1, m_under)
	_wall(-e, -SHAFT, -SHAFT, SHAFT, -11, -1, m_under)
	_wall(SHAFT, e, -SHAFT, SHAFT, -11, -1, m_under)
	_deck(-SHAFT, SHAFT, -SHAFT, SHAFT, -11, FLOOR)
	for x in [-1.6, 1.6]:
		_trim(Vector3(x, FLOOR + 0.05, -8), Vector3(x, FLOOR + 0.05, 8), _accent(2))
	# service blocks north and south (solid), balconies east and west (on legs)
	_deck(-SHAFT, SHAFT, -SHAFT, -8, FLOOR, SERVICE)
	_deck(-SHAFT, SHAFT, 8, SHAFT, FLOOR, SERVICE)
	_deck(-SHAFT, -8, -8, 8, SERVICE - 0.5, SERVICE)
	_deck(8, SHAFT, -8, 8, SERVICE - 0.5, SERVICE)
	for x in [-8.6, 8.6]:
		for z in [-5.5, 5.5]:
			_wall(x - 0.3, x + 0.3, z - 0.3, z + 0.3, FLOOR, SERVICE - 0.5, m_dark)
	for s in [-1.0, 1.0]:
		_lip(Vector3(-SHAFT, SERVICE, s * 8), Vector3(SHAFT, SERVICE, s * 8))
		_lip(Vector3(s * 8, SERVICE, -8), Vector3(s * 8, SERVICE, 8))
	_ramp(Vector3(5, FLOOR, 1), Vector3(5, SERVICE, -8), 3.0, m_ramp)
	_ramp(Vector3(-5, FLOOR, -1), Vector3(-5, SERVICE, 8), 3.0, m_ramp)
	# balcony ramps fill the balcony's width, so nothing wedges against the wall
	_ramp(Vector3(-10, SERVICE, 7), Vector3(-10, 0, -3), 4.0, m_ramp)
	_ramp(Vector3(10, SERVICE, -7), Vector3(10, 0, 3), 4.0, m_ramp)
	_deck(-SHAFT, -8, -6, -3, -0.5, 0) # landings: ramp top to the roof edge
	_deck(8, SHAFT, 3, 6, -0.5, 0)
	# dressing: neon bands, signs, light
	_trim(Vector3(-11.9, -2.5, -11.8), Vector3(11.9, -2.5, -11.8), _accent(1))
	_trim(Vector3(-11.9, -2.5, 11.8), Vector3(11.9, -2.5, 11.8), _accent(3))
	_trim(Vector3(-11.8, -7.5, -11.9), Vector3(-11.8, -7.5, 11.9), _accent(0))
	_trim(Vector3(11.8, -7.5, -11.9), Vector3(11.8, -7.5, 11.9), _accent(5))
	_sign_at(Vector3(-11.8, -7.5, -5), PI * 0.5, "sign_v%d" % (rng.randi() % 8), Vector2(2.0, 8.0), _accent(3))
	_sign_at(Vector3(11.8, -2.5, 4), -PI * 0.5, "sign_v%d" % (rng.randi() % 8), Vector2(2.0, 8.0), _accent(1))
	_sign_at(Vector3(0, -2.6, 11.8), PI, "sign_h%d" % (rng.randi() % 8), Vector2(9, 2.25), _accent(0))
	_sign_at(Vector3(-4, -7.6, -11.8), 0.0, "sign_h%d" % (rng.randi() % 8), Vector2(9, 2.25), _accent(2))
	_light(Vector3(0, -7, 0), _accent(4), 2.0, 16.0)
	_light(Vector3(-8, -8, -6), _accent(0), 2.0, 12.0)
	_light(Vector3(8, -8, 6), _accent(1), 2.0, 12.0)
	_light(Vector3(0, -2, 0), _accent(0), 1.6, 14.0)
	# geyser pad: metro platform back up to the bridge
	_pad(Vector3(0, FLOOR, 6), Vector3(0, 28.0, -2.5))
	_crate(Vector3(-9.5, FLOOR, -3), 1.2, _accent(5))
	_crate(Vector3(-2.5, FLOOR, -5), 3.0, _accent(4))


## North deck (+5), shrine tower (+10), beacon cap (+13), water tanks (+8)
## and an antenna terrace (+6.2): the high ground, stepped so every level is
## a hop, a mantle or a grab from the one below.
func _north() -> void:
	_deck(-27, 27, -31, -22, 0, DECK)
	_lip(Vector3(-27, DECK, -22), Vector3(27, DECK, -22))
	for s in [-1.0, 1.0]:
		_ramp(Vector3(s * 14, 0, -14), Vector3(s * 14, DECK, -22), 4.0, m_ramp)
	# shrine tower: grab ledge from the deck, ramp up its west side
	_deck(-7, 7, -31, -25, DECK, 10)
	_lip(Vector3(-7, 10, -25), Vector3(7, 10, -25))
	_lip(Vector3(7, 10, -31), Vector3(7, 10, -25))
	_ramp(Vector3(-17, DECK, -28.5), Vector3(-7, 10, -28.5), 3.0, m_ramp)
	_sign_at(Vector3(0, 7.5, -24.9), 0.0, "sign_h%d" % (rng.randi() % 8), Vector2(10, 2.5), _accent(0))
	_trim(Vector3(-7, 5.1, -24.95), Vector3(7, 5.1, -24.95), _accent(4))
	# beacon cap: a 3 m mantle on top of the tower, the highest point on the map
	_deck(-2.5, 2.5, -30, -27, 10, 13)
	_neon_box_edges(Vector3(0, 11.5, -28.5), Vector3(5, 3, 3), 0.0, _accent(2), 2.6, true)
	add_child(Psx.box(Vector3(0.3, 6.0, 0.3), m_dark, Vector3(0, 16, -28.5)))
	_neon(Vector3(0.8, 0.8, 0.8), Vector3(0, 19.2, -28.5), _accent(0), 4.0)
	_halo(Vector3(0, 19.2, -28.5), _accent(0), 6.0, 0.5)
	_light(Vector3(0, 13, -26), _accent(0), 2.4, 18.0)
	# west: water-tank platform (+8, a mantle from the deck); tanks top out at +11
	_deck(-27, -18, -31, -25, DECK, 8)
	_lip(Vector3(-27, 8, -25), Vector3(-18, 8, -25))
	var tank_mat := Psx.lit(Color(pal.floor).lightened(0.28), TexGen.get_tex("noise"), true, 0.5)
	for x in [-24.5, -20.5]:
		_cylinder(Vector3(x, 8, -28), 1.6, 3.0, tank_mat)
		_neon(Vector3(3.3, 0.1, 3.3), Vector3(x, 11.0, -28), _accent(1), 2.4)
	# east: antenna terrace (+6.2, a hop) with dishes
	_deck(16, 27, -31, -25, DECK, 6.2)
	for x in [19.0, 24.0]:
		add_child(Psx.box(Vector3(0.25, 4.0, 0.25), m_dark, Vector3(x, 8.2, -28)))
		var dish := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.4
		cm.bottom_radius = 0.2
		cm.height = 0.6
		cm.radial_segments = 10
		dish.mesh = cm
		dish.material_override = m_chrome
		dish.position = Vector3(x, 10.2, -28)
		dish.rotation = Vector3(0.9, 0.3 * x, 0)
		add_child(dish)
		_neon(Vector3(0.25, 0.25, 0.25), Vector3(x, 10.5, -27.7), _accent(5), 4.0)
	_trim(Vector3(-27, 4.9, -21.95), Vector3(27, 4.9, -21.95), _accent(3), 2.0)


func _side_catwalks() -> void:
	for s in [-1.0, 1.0]:
		var x0: float = 22.0 if s > 0 else -27.0
		_deck(x0, x0 + 5.0, -22, 20, DECK - 0.45, DECK)
		for z in [-16.0, -6.0, 4.0, 14.0]:
			_wall(x0 + 0.5, x0 + 1.0, z - 0.25, z + 0.25, 0, DECK - 0.45, m_dark)
			_wall(x0 + 4.0, x0 + 4.5, z - 0.25, z + 0.25, 0, DECK - 0.45, m_dark)
		_ramp(Vector3(x0 + 2.5, 0, 27), Vector3(x0 + 2.5, DECK, 20), 4.0, m_ramp)
		var inner: float = x0 if s > 0 else x0 + 5.0
		var outer: float = x0 + 5.0 if s > 0 else x0
		_lip(Vector3(inner, DECK, -22), Vector3(inner, DECK, 20))
		for i in 11:
			add_child(Psx.box(Vector3(0.1, 1.0, 0.1), m_dark, Vector3(outer, DECK + 0.5, -22 + i * 4.2)))
		_trim(Vector3(outer, DECK + 1.0, -22), Vector3(outer, DECK + 1.0, 20), _accent(1) if s > 0 else _accent(0))
		_light(Vector3(x0 + 2.5, DECK + 2.0, -6), _accent(3) if s > 0 else _accent(5), 1.6, 13.0)


## The torii bridge across the shaft at +5, with a 10 x 10 platform mid-way.
func _bridge() -> void:
	_deck(-22, 22, -2, 2, DECK - 0.5, DECK)
	_deck(-5, 5, -5, 5, DECK - 0.5, DECK)
	for z in [-2.05, 2.05]:
		_trim(Vector3(-22, DECK - 0.05, z), Vector3(22, DECK - 0.05, z), _accent(2))
		_trim(Vector3(-22, DECK - 0.5, z), Vector3(22, DECK - 0.5, z), _accent(1))
	_torii(Vector3(0, DECK, 0), 0.9, PI * 0.5)


func _torii(p: Vector3, sc: float, rot: float) -> void:
	var g := Node3D.new()
	g.position = p
	g.rotation.y = rot
	g.scale = Vector3.ONE * sc
	add_child(g)
	var red: Color = pal.neon_a
	for s in [-1.0, 1.0]:
		g.add_child(Psx.box(Vector3(0.7, 5.6, 0.7), m_lacquer, Vector3(s * 3.3, 2.8, 0)))
		_neon(Vector3(0.08, 5.4, 0.08), Vector3(s * 3.3, 2.8, 0.38), red, 4.0, g)
		var col := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.7, 5.6, 0.7) * sc
		cs.shape = bs
		col.add_child(cs)
		col.position = p + Basis(Vector3.UP, rot) * Vector3(s * 3.3 * sc, 2.8 * sc, 0)
		add_child(col)
	g.add_child(Psx.box(Vector3(9.6, 0.5, 0.8), m_lacquer, Vector3(0, 5.75, 0)))
	g.add_child(Psx.box(Vector3(10.4, 0.25, 1.0), m_dark, Vector3(0, 6.1, 0)))
	g.add_child(Psx.box(Vector3(7.8, 0.35, 0.45), m_lacquer, Vector3(0, 4.5, 0)))
	_neon(Vector3(10.4, 0.07, 0.07), Vector3(0, 6.25, 0.5), pal.neon_c, 4.0, g)
	_neon(Vector3(9.6, 0.07, 0.07), Vector3(0, 5.48, 0.42), red, 4.5, g)
	_light(p + Vector3(0, 4, 2), red, 2.4, 16.0)
	_halo(p + Vector3(0, 5.4 * sc, 0), red, 10.0 * sc, 0.25)


## Roof-ring features: a stairwell hut, a billboard gantry, container stacks,
## a sheer vent tower and planters, so the ground floor has its own heights.
func _ring() -> void:
	# south-west stairwell hut (3 m mantle) with air-con units (hops) on top
	_deck(-21, -15, 22, 28, 0, 3, m_dark)
	_lip(Vector3(-21, 3, 22), Vector3(-15, 3, 22))
	for p in [Vector3(-19.5, 3, 24.5), Vector3(-17, 3, 26.5)]:
		_solid(Vector3(1.6, 1.2, 1.6), p + Vector3(0, 0.6, 0), m_chrome)
		_neon(Vector3(1.0, 0.06, 1.0), p + Vector3(0, 1.23, 0), _accent(1), 2.0)
	# south-east billboard gantry (+5 on legs) with a big ad facing the arena
	_deck(11, 21, 23, 29, DECK - 0.5, DECK)
	for x in [11.5, 20.5]:
		for z in [23.5, 28.5]:
			_wall(x - 0.3, x + 0.3, z - 0.3, z + 0.3, 0, DECK - 0.5, m_dark)
	_lip(Vector3(11, DECK, 23), Vector3(21, DECK, 23))
	_lip(Vector3(21, DECK, 23), Vector3(21, DECK, 29))
	for x in [11.6, 20.4]:
		add_child(Psx.box(Vector3(0.4, 8.0, 0.4), m_dark, Vector3(x, DECK + 4.0, 29.2)))
	var ad := Psx.quad(Vector2(10, 5.0), Psx.unlit(Color(1, 1, 1), 1.8, TexGen.get_tex("ad%d" % (rng.randi() % 6)), {"fog_amount": 0.2}), Vector3(16, DECK + 5.5, 29.0))
	ad.rotation.y = PI
	add_child(ad)
	_neon_box_edges(Vector3(16, DECK + 5.5, 29.05), Vector3(10.2, 5.2, 0.1), 0.0, _accent(4), 3.0)
	_light(Vector3(16, DECK + 3.0, 26.0), _accent(4), 1.8, 12.0)
	_crate(Vector3(16, 0, 19.5), 3.0, _accent(2), 1.57) # step up: 3 m, then 2 m to the gantry
	# west: a 3 m container and a 6 m stack (mantle, mantle) under the catwalk
	_crate(Vector3(-17, 0, -7), 3.0, _accent(3))
	_crate(Vector3(-17, 0, 4.3), 3.0, _accent(0))
	_crate(Vector3(-17, 3, 4.3), 3.0, _accent(5))
	# east: a sheer 7 m vent tower (never climbable) and a hop crate
	_wall(15, 18.5, 5, 9, 0, 7.5, m_dark)
	_sign_at(Vector3(14.9, 4.0, 7), -PI * 0.5, "sign_v%d" % (rng.randi() % 8), Vector2(2.2, 6.0), _accent(5))
	var fan := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 1.4
	fm.bottom_radius = 1.4
	fm.height = 0.3
	fm.radial_segments = 10
	fan.mesh = fm
	fan.material_override = m_chrome
	fan.position = Vector3(16.75, 7.6, 7)
	add_child(fan)
	_crate(Vector3(18.5, 0, -7), 1.2, _accent(2), 1.57)
	# north strip and south planters
	_crate(Vector3(-6, 0, -17), 1.2, _accent(4), 1.57)
	_crate(Vector3(8, 0, -16), 3.0, _accent(1), 0.2)
	for x in [-9.0, 9.0]:
		_solid(Vector3(5, 1.2, 2.4), Vector3(x, 0.6, 25), m_chrome)
		_platform(Vector3(5, 0.05, 2.4), Vector3(x, 1.2, 25), m_dark)
		_neon_box_edges(Vector3(x, 0.6, 25), Vector3(5, 1.2, 2.4), 0.0, _accent(0 if x < 0 else 3), 2.2, true)


## Visible spawn sources: metro tunnels, freight lifts, roof hatches.
func _spawn_sources() -> void:
	for s in [-1.0, 1.0]:
		_tunnel(Vector3(s * (SHAFT - 0.3), FLOOR, 0), Vector3(-s, 0, 0))
		_lift(Vector3(s * -4, SERVICE, s * (SHAFT - 0.2)), Vector3(0, 0, -s))
	_lift(Vector3(-18, 0, 21.8), Vector3(0, 0, -1))
	for p in [Vector3(-24.5, 0, -11), Vector3(24.5, 0, 9), Vector3(-11, DECK, -23.5)]:
		_hatch(p)


func _tunnel(c: Vector3, facing: Vector3) -> void:
	var w := 6.0
	var h := 4.0
	var col := Color("ff3b2f")
	var root := Node3D.new()
	root.position = c
	root.rotation.y = atan2(facing.x, facing.z)
	add_child(root)
	root.add_child(Psx.box(Vector3(w, h, 0.4), Psx.unlit(Color(0.02, 0.0, 0.03), 1.0), Vector3(0, h * 0.5, -0.1)))
	root.add_child(Psx.quad(Vector2(w * 0.8, h * 0.8), Psx.fx(col, TexGen.get_tex("glow"), true, false, false, 1.4), Vector3(0, h * 0.45, 0.15)))
	for s in [-1.0, 1.0]:
		_neon(Vector3(0.14, h, 0.14), Vector3(s * w * 0.5, h * 0.5, 0.2), col, 3.0, root)
	_neon(Vector3(w, 0.14, 0.14), Vector3(0, h, 0.2), col, 3.0, root)
	_light(c + facing * 2.0 + Vector3(0, 2, 0), col, 2.2, 12.0)


func _lift(c: Vector3, facing: Vector3) -> void:
	var col: Color = _accent(1)
	var root := Node3D.new()
	root.position = c
	root.rotation.y = atan2(facing.x, facing.z)
	add_child(root)
	root.add_child(Psx.box(Vector3(3.0, 3.4, 0.3), Psx.unlit(Color(0.03, 0.12, 0.16), 1.0), Vector3(0, 1.7, 0)))
	for s in [-1.0, 1.0]:
		_neon(Vector3(0.12, 3.6, 0.12), Vector3(s * 1.6, 1.8, 0.2), col, 3.2, root)
	_neon(Vector3(3.3, 0.12, 0.12), Vector3(0, 3.6, 0.2), col, 3.2, root)
	_neon(Vector3(0.06, 3.2, 0.06), Vector3(0, 1.7, 0.18), col, 1.5, root)


func _hatch(p: Vector3) -> void:
	var col: Color = _accent(4)
	add_child(Psx.box(Vector3(2.0, 0.1, 2.0), Psx.unlit(Color(0.02, 0.06, 0.02), 1.0), p + Vector3(0, 0.05, 0)))
	_neon_box_edges(p + Vector3(0, 0.08, 0), Vector3(2.0, 0.05, 2.0), 0.0, col, 3.0, true)


func _pad(p: Vector3, launch: Vector3) -> void:
	var col: Color = pal.neon_c
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
	top.material_override = Psx.unlit(col, 2.2, TexGen.get_tex("jumppad"), {"fog_amount": 0.3})
	top.position = p + Vector3(0, 0.17, 0)
	add_child(top)
	for k in 2:
		var beam := Psx.quad(Vector2(2.4, 5.0), Psx.fx(Color(col.r, col.g, col.b, 0.25), TexGen.get_tex("glow"), true, false, false, 0.8), p + Vector3(0, 2.5, 0))
		beam.rotation.y = k * PI * 0.5
		add_child(beam)
	_light(p + Vector3(0, 1.0, 0), col, 1.4, 7.0)
	jump_pads.append({"pos": p, "r": 1.35, "launch": launch})


## Parapet with neon, invisible walls, and pylons on the two north corners.
func _edge() -> void:
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
		_solid(Vector3(half * 2 + 4, 30, 1), Vector3(0, 13, s * (e + 0.5)), null, 0.0, 0, false)
		_solid(Vector3(1, 30, half * 2 + 4), Vector3(s * (e + 0.5), 13, 0), null, 0.0, 0, false)
	for c in [Vector3(-30, 0, -31), Vector3(30, 0, -31)]:
		add_child(Psx.box(Vector3(0.3, 9, 0.3), m_dark, c + Vector3(0, 4.5, 0)))
		var col := _accent(2 if c.x < 0 else 5)
		_neon(Vector3(0.6, 0.6, 0.6), c + Vector3(0, 9.2, 0), col, 3.5)
		_halo(c + Vector3(0, 9.2, 0), col, 3.0, 0.5)


func _spawn_list() -> void:
	# metro tunnels, freight lifts, the hut lift and the roof hatches: enemies walk out
	ground_spawns = [
		Vector3(-10.5, FLOOR, 0), Vector3(10.5, FLOOR, 0), Vector3(-4, SERVICE, -10.5), Vector3(4, SERVICE, 10.5),
		Vector3(-24.5, 0, -11), Vector3(24.5, 0, 9), Vector3(-18, 0, 20.5), Vector3(-11, DECK, -23.5),
	]
	spawn_points = ground_spawns.duplicate()
	spawn_points.append_array([
		# sky drops: open roof and high ground
		Vector3(-20, 0, -16), Vector3(20, 0, -18), Vector3(-12, 0, 29), Vector3(16, 0, 14), Vector3(0, 0, -18),
		Vector3(12, DECK, -26), Vector3(-24.5, DECK, 8), Vector3(24.5, DECK, -8), Vector3(16, DECK, 25.5), Vector3(4.5, 10, -28),
	])
	_links()


## Leap links for enemy pathing: [low, high] pairs 1.3 m either side of each
## amber grab lip (and the hop and mantle onto the antenna terrace and beacon cap).
func _links() -> void:
	var o := 1.3
	# metro to the service blocks, clear of the metro ramps, crates and the pad
	for x in [-6.0, 1.0]:
		nav_links.append([Vector3(x, FLOOR, -8 + o), Vector3(x, SERVICE, -8 - o)])
	for x in [-2.5, 6.0]:
		nav_links.append([Vector3(x, FLOOR, 8 - o), Vector3(x, SERVICE, 8 + o)])
	# metro to the balconies (the balconies' own ramps lead on to the roof)
	for z in [3.0, 6.0]:
		nav_links.append([Vector3(8 - o, FLOOR, z), Vector3(8 + o, SERVICE, z)])
	for z in [-3.0, -6.0]:
		nav_links.append([Vector3(-8 + o, FLOOR, z), Vector3(-8 - o, SERVICE, z)])
	# service blocks to the roof
	for x in [-6.0, 6.0]:
		for s in [-1.0, 1.0]:
			nav_links.append([Vector3(x, SERVICE, s * (SHAFT - o)), Vector3(x, 0, s * (SHAFT + o))])
	for x in [-20.0, -4.0, 9.0, 19.0]:
		nav_links.append([Vector3(x, 0, -22 + o), Vector3(x, DECK, -22 - o)]) # roof to north deck
	for z in [-14.0, -4.0, 9.0]: # clear of the bridge (z -2 to 2) and the crates below
		for s in [-1.0, 1.0]:
			nav_links.append([Vector3(s * (22 - o), 0, z), Vector3(s * (22 + o), DECK, z)]) # roof to side catwalks
	nav_links.append([Vector3(-3, DECK, -25 + o), Vector3(-3, 10, -25 - o)]) # deck to shrine tower
	nav_links.append([Vector3(7 + o, DECK, -28), Vector3(7 - o, 10, -28)])
	nav_links.append([Vector3(4.2, 10, -28.5), Vector3(1.2, 13, -28.5)]) # tower to beacon cap
	nav_links.append([Vector3(21.5, DECK, -25 + o), Vector3(21.5, 6.2, -25 - o)]) # deck to antenna terrace
	nav_links.append([Vector3(16, 0, 23 - o), Vector3(16, DECK, 23 + o)]) # roof to billboard gantry
