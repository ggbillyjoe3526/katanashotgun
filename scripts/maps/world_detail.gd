class_name WorldDetail
extends RefCounted
## The Well's detail pass (owner's pick 2026-10-19: look "B" with "C"'s haze
## and light, design/world-detail in the project files). Built once per map:
## - Shapes: raised floor plates over the grid (lit seams between them, some
##   cells left open), trims and ribs on walls, copper pipes, AC units,
##   vending machines, lit shutters, blade signs, roof vents, skylights, a
##   small shrine, antennas, cables with paper lanterns across the shaft.
## - Air and light: coloured haze, mist in the shaft and a cloud deck below
##   the roof edge, light pools and beams under lamps, street lamps, steam,
##   floating dust, baked contact shadows at every wall foot.
## - Water (after the weather is rolled): rain puddles where water would
##   collect, and skylight glass. Only those reflect (PuddleMirror); every
##   other surface stays matte.
## Everything is merged into one mesh per material. Anything a body would
## walk into is solid and only placed where it can't block a spawn, a leap
## link or a ramp, or make a sheer wall climbable (`_free`). Its own random
## numbers: the run's dice are never touched, so seeds play as before.

const LIFT := 0.05 # floor plates' top above the grid cap
const RAISED := 0.07 # the odd service plate sits higher
const CELL := 2.0 # plates sit on the 2 m grid
## Gameplay points keep this much floor clear of solid props (metres).
const CLEAR := 2.5
const CLEAR_LINK := 1.5
const CLEAR_BOSS := 5.0
## The climb rules (design/vertical-map/heights.md): a body reaches 6 m above
## the floor it jumps from; walls of 7 m and more must stay out of reach.
const REACH := 6.0
const REACH_RANGE := 5.0 # how far a jump carries a body towards a wall
const MIRROR_LAYER := 1 << 19
## Floor props are flat enough to run over (no collider) or at least a hop
## high, never knee height in between: a sprint must not stop on something
## the player didn't see as an obstacle (owner's play-test, 2026-10-24).
const FLUSH := 0.08
const HOP := 1.2
const BENCH := 31.75 # pipe benches' centre line, backed onto the parapet

## Off for a bare map (tests compare against it; `--nodetail` for a look or
## a frame-rate comparison).
static var enabled := not OS.get_cmdline_user_args().has("--nodetail")

var a: WellMap
var pal: Dictionary
var r := RandomNumberGenerator.new()
## Counts, for tests and the debug log.
var props := 0
var puddles := 0
var puddle_spots: Array[Vector3] = [] # each puddle's centre, for tests
var glass := 0
var mirror: PuddleMirror
var prop_boxes: Array[AABB] = [] # every solid prop, for tests

var _boxes: Array = [] # the map's box colliders before dressing: {pos, size, mat}
var _solids: Array[AABB] = [] # every collider, the map's and the props' (and the skylights)
var _map_solids := 0 # how many of _solids are the map's own
var _lips: Array[AABB] = [] # amber grab lips: their faces stay clean
var _floor_neon: Array[AABB] = [] # neon strips lying on a floor: no plate over them
var _keep: Array[Vector3] = [] # spawn points, player and pad spots
var _links: Array[Vector3] = [] # leap link ends
var _open_cells: Array[Vector3] = [] # floor cells without a plate (water collects there)
var _drains: Array[Vector3] = []
var _panes: Array = [] # [centre, half size] of skylight glass
var _st := {} # Material -> SurfaceTool
var _prim := {} # primitive arrays, by key
var _extras: Array[Node3D] = [] # hidden on WEAK: beams, steam, dust
var _pools: Array = [] # [floor point, colour] under each street lamp
var _haze: Color

# shared materials
var m_trim: ShaderMaterial
var m_pipe: ShaderMaterial
var m_steel: ShaderMaterial
var m_unit: ShaderMaterial
var m_vend: ShaderMaterial
var m_door: ShaderMaterial
var m_led: ShaderMaterial
var m_paper: ShaderMaterial
var m_post: ShaderMaterial
var m_pane: ShaderMaterial
var m_pool: ShaderMaterial
var m_beam: ShaderMaterial
var m_shadow: ShaderMaterial
var m_mist: ShaderMaterial
var m_mist_patch: ShaderMaterial
var m_signs: Array[ShaderMaterial] = []


## The haze colour for a palette: its fog, nudged towards an accent and lighter,
## so the far city fades into coloured air.
static func haze(p: Dictionary) -> Color:
	return Color(p.fog).lerp(p.accents[3], 0.2).lightened(0.07)


func _init(map: WellMap) -> void:
	a = map
	pal = map.pal
	r.seed = 0x57E11 # the layout is the same every run; puddles follow the seed
	_haze = haze(pal)


## Shapes, light and air. Called at the end of the layout, before the navmesh
## is baked, so enemies path around the solid props.
func build() -> void:
	_gather()
	_materials()
	_walls()
	_roof()
	_cables()
	_lamps()
	_plating() # after the props: they stand on the bare floor
	_air()
	_commit()


## Puddles and the reflections, once the run's rain level is known.
func build_weather() -> void:
	_puddles()
	_commit()
	var cb := _on_quality
	Quality.on_changed(cb)
	a.tree_exiting.connect(func() -> void: Quality.off_changed(cb), CONNECT_ONE_SHOT)
	_on_quality(Quality.preset)


func _on_quality(id: String) -> void:
	for n in _extras:
		if is_instance_valid(n):
			n.visible = id != "low"


# ---------------------------------------------------------------- gather
func _gather() -> void:
	for body in a.find_children("*", "StaticBody3D", true, false):
		if a.backdrop.is_ancestor_of(body):
			continue
		for cs in body.get_children():
			if not (cs is CollisionShape3D):
				continue
			var sh := (cs as CollisionShape3D).shape
			var xf := (cs as Node3D).global_transform
			if sh is BoxShape3D:
				var s := (sh as BoxShape3D).size
				_solids.append(xf * AABB(-s * 0.5, s))
				if (body as Node3D).rotation.y == 0.0:
					var mesh: MeshInstance3D = null
					for k in body.get_children():
						if k is MeshInstance3D:
							mesh = k
					_boxes.append({"pos": xf.origin, "size": s, "mat": mesh.material_override if mesh else null})
			elif sh is CylinderShape3D:
				var cy := sh as CylinderShape3D
				var e := Vector3(cy.radius, cy.height * 0.5, cy.radius)
				_solids.append(AABB(xf.origin - e, e * 2.0))
	for n in a.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.material_override as ShaderMaterial
		if not (mi.mesh is BoxMesh) or m == null or m.shader != Psx.shader("psx_unlit") or a.backdrop.is_ancestor_of(mi):
			continue
		var s := (mi.mesh as BoxMesh).size
		var box := mi.global_transform * AABB(-s * 0.5, s)
		if m.get_shader_parameter("albedo_color") == WellMap.AMBER:
			_lips.append(box)
		elif box.size.y < 0.4 and absf(a.floor_height_at(box.get_center().x, box.get_center().z, box.position.y + 0.2) - box.position.y) < 0.15:
			_floor_neon.append(box)
	_map_solids = _solids.size()
	_keep.append_array(a.spawn_points)
	_keep.append(a.player_spawn)
	for jp in a.jump_pads:
		_keep.append(jp.pos)
	for l in a.nav_links:
		_links.append(l[0])
		_links.append(l[1])


func _materials() -> void:
	var amb: Color = Color(pal.ambient).lightened(0.4)
	var sl := {"self_light": 0.75, "self_tint": amb}
	# the map's own surfaces get a soft pre-lit glow so their new detail reads
	for m in [a.m_wall, a.m_under, a.m_dark, a.m_chrome]:
		(m as ShaderMaterial).set_shader_parameter("self_light", 0.5)
		(m as ShaderMaterial).set_shader_parameter("self_tint", amb)
	m_trim = Psx.lit(Color(0.55, 0.55, 0.62).lerp(pal.ambient, 0.3), TexGen.get_tex("chrome"), true, 0.5, sl.merged({"emission_color": a._accent(3), "emission_strength": 0.04}))
	m_pipe = Psx.lit(Color(0.78, 0.5, 0.36), TexGen.get_tex("chrome"), false, 1.0, sl.merged({"uv_tiling": Vector2(1, 4)}))
	m_steel = Psx.lit(Color(0.3, 0.3, 0.36), TexGen.get_tex("noise"), true, 1.0, sl)
	m_unit = Psx.lit(Color(0.6, 0.62, 0.66), TexGen.get_tex("grate"), true, 1.0, sl.merged({"emission_from_texture": 0.3, "emission_tint": a._accent(1)}))
	m_post = Psx.lit(Color(pal.floor).lightened(0.3), TexGen.get_tex("noise"), false, 1.0)
	m_vend = Psx.unlit(Color(1, 1, 1), 1.25, TexGen.get_tex("vend"), {"fog_amount": 0.3})
	m_door = Psx.unlit(Color(1, 1, 1), 1.2, TexGen.get_tex("door"), {"fog_amount": 0.3})
	m_led = Psx.unlit(Color(1, 1, 1), 3.0, null, {"fog_amount": 0.3, "use_vertex_color": true})
	m_paper = Psx.unlit(Color(1, 1, 1), 1.15, null, {"fog_amount": 0.3, "use_vertex_color": true})
	m_pane = Psx.unlit(a._accent(1).darkened(0.55), 1.4, TexGen.get_tex("grate"), {"fog_amount": 0.3})
	for i in 4:
		m_signs.append(Psx.unlit(Color(1, 1, 1), 2.2, TexGen.get_tex("sign_v%d" % i), {"fog_amount": 0.3, "use_vertex_color": true}))
	m_pool = _vc(Psx.fx(Color(1, 1, 1), TexGen.get_tex("pool"), true))
	m_beam = _vc(Psx.fx(Color(1, 1, 1), TexGen.get_tex("beam"), true))
	m_shadow = _vc(Psx.fx(Color(0, 0, 0, 1), TexGen.get_tex("ao"), false))
	m_mist = _vc(Psx.fx(Color(1, 1, 1), TexGen.get_tex("mist_tile"), false))
	m_mist_patch = _vc(Psx.fx(Color(1, 1, 1), TexGen.get_tex("mist"), false))


static func _vc(m: ShaderMaterial) -> ShaderMaterial:
	m.set_shader_parameter("use_vertex_color", true)
	return m


# ---------------------------------------------------------------- geometry
## Adds a primitive (unit size, shaped by `xf`) to the merged mesh of `mat`.
func _add(key: String, xf: Transform3D, mat: Material, col := Color.WHITE) -> void:
	var arr: Array = _prim.get(key, [])
	if arr.is_empty():
		arr = _make_prim(key)
		_prim[key] = arr
	var st: SurfaceTool = _st.get(mat)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[mat] = st
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var nb := xf.basis.inverse().transposed()
	for i: int in arr[Mesh.ARRAY_INDEX]:
		st.set_color(col)
		st.set_normal((nb * n[i]).normalized())
		st.set_uv(uv[i])
		st.add_vertex(xf * v[i])


## "box", "quad" (2 x 2, facing +Z) or "cyl:<bottom radius>:<segments>"
## (top radius 1, height 1).
static func _make_prim(key: String) -> Array:
	var pm: PrimitiveMesh
	if key == "box":
		pm = BoxMesh.new()
	elif key == "quad":
		var q := QuadMesh.new()
		q.size = Vector2(2, 2)
		pm = q
	else:
		var parts := key.split(":")
		var c := CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = float(parts[1])
		c.height = 1.0
		c.radial_segments = int(parts[2])
		c.rings = 1
		pm = c
	return pm.get_mesh_arrays()


func _box(size: Vector3, pos: Vector3, mat: Material, rot := 0.0, col := Color.WHITE) -> void:
	_add("box", Transform3D(Basis(Vector3.UP, rot) * Basis.from_scale(size), pos), mat, col)


## A cylinder from its centre: radii at top and bottom, height, along `basis` Y.
func _cyl(r_top: float, r_bot: float, h: float, basis: Basis, pos: Vector3, mat: Material, seg := 8, col := Color.WHITE) -> void:
	var key := "cyl:%.3f:%d" % [r_bot / r_top, seg]
	_add(key, Transform3D(basis * Basis.from_scale(Vector3(r_top, h, r_top)), pos), mat, col)


## A quad from its centre, with `right` and `up` half-extent vectors.
func _quad(c: Vector3, right: Vector3, up: Vector3, mat: Material, col := Color.WHITE) -> void:
	var nrm := right.normalized().cross(up.normalized()).normalized()
	_add("quad", Transform3D(Basis(right, up, nrm), c), mat, col)


## True if a puddle at `c` would lie mostly inside a solid block (the fixed
## metro spots are placed by floor height alone): its centre, or half its
## corners, at ankle height inside any collider.
func _under_solid(c: Vector3, hx: float, hz: float, ang: float) -> bool:
	var pts: Array[Vector3] = [c]
	for q in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(-hx, hz), Vector2(hx, hz)]:
		var o: Vector2 = (q as Vector2).rotated(-ang) * 0.7
		pts.append(c + Vector3(o.x, 0, o.y))
	var inside := 0
	for i in pts.size():
		var p := pts[i] + Vector3(0, 0.3, 0)
		for b in _solids:
			if (b as AABB).has_point(p):
				if i == 0:
					return true
				inside += 1
				break
	return inside >= 2


## A flat quad lying on the floor.
func _decal(c: Vector3, hx: float, hz: float, mat: Material, col := Color.WHITE, ang := 0.0) -> void:
	_quad(c, Vector3.RIGHT.rotated(Vector3.UP, ang) * hx, Vector3.FORWARD.rotated(Vector3.UP, ang) * hz, mat, col)


func _commit() -> void:
	for mat in _st:
		var mi := MeshInstance3D.new()
		mi.mesh = (_st[mat] as SurfaceTool).commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.add_child(mi)
		if mat == m_beam:
			_extras.append(mi)
	_st.clear()


# ---------------------------------------------------------------- placement
## Whether a solid prop (box `half` around `c`, standing on `fy`) fits: on
## one floor, inside nothing, clear of spawns, leap links, pads and ramps,
## and not a step up to a wall that must stay out of reach.
func _free(c: Vector3, half: Vector3, fy: float) -> bool:
	var box := AABB(c - half, half * 2.0)
	var flat := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	for q in [Vector2(flat.position.x, flat.position.y), Vector2(flat.end.x, flat.position.y), Vector2(flat.position.x, flat.end.y), flat.end, flat.get_center()]:
		if absf(a.floor_height_at(q.x, q.y, fy + 0.1) - fy) > 0.02:
			return false # hangs over an edge or a step
	var inner := box.grow(-0.02)
	inner.position.y += 0.06
	inner.size.y -= 0.06
	for s in _solids:
		if s.intersects(inner):
			return false
	for p in _keep:
		if absf(p.y - fy) < 2.5 and _dist(flat, p) < CLEAR:
			return false
	if absf(a.boss_spawn.y - fy) < 2.5 and _dist(flat, a.boss_spawn) < CLEAR_BOSS:
		return false
	for p in _links:
		if absf(p.y - fy) < 2.5 and _dist(flat, p) < CLEAR_LINK:
			return false
	var rad := maxf(half.x, half.z)
	for rp in a._ramps:
		var ra: Vector3 = rp.a
		var rb: Vector3 = rp.b
		var ab := Vector2(rb.x - ra.x, rb.z - ra.z)
		var ap := Vector2(c.x - ra.x, c.z - ra.z)
		var t := ap.dot(ab) / ab.length_squared()
		var over := (1.5 + rad) / ab.length() # keep the landing at each end free
		if t > -over and t < 1.0 + over and absf(ap.cross(ab)) / ab.length() < float(rp.w) * 0.5 + rad + 0.5 and fy > minf(ra.y, rb.y) - 1.0 and fy < maxf(ra.y, rb.y) + 1.0:
			return false
	var top := box.end.y - fy
	for s in _solids:
		var rise := s.end.y - fy
		if rise > REACH and rise <= top + REACH + 0.3 and _dist_rect(flat, s) < REACH_RANGE:
			return false
	return true


static func _dist(rect: Rect2, p: Vector3) -> float:
	var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.z, rect.position.y, rect.end.y))
	return q.distance_to(Vector2(p.x, p.z))


static func _dist_rect(rect: Rect2, s: AABB) -> float:
	var dx := maxf(0.0, maxf(s.position.x - rect.end.x, rect.position.x - s.end.x))
	var dz := maxf(0.0, maxf(s.position.z - rect.end.y, rect.position.y - s.end.z))
	return Vector2(dx, dz).length()


## A box collider for a placed prop (the visible parts are drawn separately),
## turned rot about the vertical; _solids keeps its upright bounds.
func _solid(c: Vector3, half: Vector3, rot := 0.0, part := false) -> void:
	a._solid(half * 2.0, c, null, rot, 0, false)
	var co := absf(cos(rot))
	var si := absf(sin(rot))
	var b := Vector3(co * half.x + si * half.z, half.y, si * half.x + co * half.z)
	_solids.append(AABB(c - b, b * 2.0))
	prop_boxes.append(_solids[-1])
	if not part:
		props += 1


## A post's collider: a thin cylinder.
func _post_solid(base: Vector3, rad: float, h: float) -> void:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	body.position = base + Vector3(0, h * 0.5, 0)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = rad
	sh.height = h
	cs.shape = sh
	body.add_child(cs)
	a.add_child(body)
	_solids.append(AABB(base - Vector3(rad, 0, rad), Vector3(rad * 2.0, h, rad * 2.0)))
	prop_boxes.append(_solids[-1])
	props += 1


# ---------------------------------------------------------------- walls
const SIDES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]


## Whether an amber grab lip runs along this face's top: those stay clean
## (no signs or units in the way of the climb, nothing hiding the lip).
func _grab_face(p: Vector3, s: Vector3, side: int, top: float) -> bool:
	var nrm := SIDES[side]
	var off: float = s.x * 0.5 if side < 2 else s.z * 0.5
	var edge := p + nrm * off
	var probe := AABB(Vector3(edge.x - 0.3, top - 0.5, edge.z - 0.3), Vector3(0.6, 1.0, 0.6))
	if side < 2:
		probe.position.z = p.z - s.z * 0.5
		probe.size.z = s.z
	else:
		probe.position.x = p.x - s.x * 0.5
		probe.size.x = s.x
	for l in _lips:
		if l.intersects(probe):
			return true
	return false


func _walls() -> void:
	var leds: Array[Color] = []
	for i in 6:
		leds.append(a._accent(i))
	for b in _boxes:
		var s: Vector3 = b.size
		var p: Vector3 = b.pos
		if s.y < 0.8 or not (b.mat in [a.m_wall, a.m_under, a.m_dark]):
			continue
		var top := p.y + s.y * 0.5
		var bot := p.y - s.y * 0.5
		# a cornice and a band, kept below the grab lips' glow
		if s.y >= 1.5:
			_box(Vector3(s.x + 0.32, 0.2, s.z + 0.32), Vector3(p.x, top - 0.6, p.z), m_trim)
			_box(Vector3(s.x + 0.14, 0.1, s.z + 0.14), Vector3(p.x, top - 0.95, p.z), m_trim)
		if s.y > 2.2:
			_box(Vector3(s.x + 0.16, 0.35, s.z + 0.16), Vector3(p.x, bot + 0.175, p.z), m_steel)
		for side in 4:
			_dress_face(p, s, side, top, bot, leds)


func _dress_face(p: Vector3, s: Vector3, side: int, top: float, bot: float, leds: Array[Color]) -> void:
	var nrm := SIDES[side]
	var len: float = s.z if side < 2 else s.x
	var off: float = s.x * 0.5 if side < 2 else s.z * 0.5
	var along: Vector3 = Vector3.BACK if side < 2 else Vector3.RIGHT
	var rot: float = 0.0 if side >= 2 else PI * 0.5
	var probe := p + nrm * (off + 0.4)
	var fy := maxf(bot, a.floor_height_at(probe.x, probe.z, top - 0.3))
	var h := top - fy
	if h < 2.2 or len < 3.0:
		return
	var face := p + nrm * off
	var clean := _grab_face(p, s, side, top)
	# vertical ribs every ~3.2 m
	var n := int(len / 3.2)
	for i in range(1, n + 1):
		var t := -len * 0.5 + len * float(i) / float(n + 1)
		var c := face + along * t + nrm * 0.09
		_box(Vector3(0.34, h - 0.7, 0.18) if side >= 2 else Vector3(0.18, h - 0.7, 0.34), Vector3(c.x, fy + (h - 0.7) * 0.5, c.z), m_trim)
	if clean:
		return
	# pipe runs with brackets, overhead
	if h >= 3.5 and r.randf() < 0.75:
		for k in (1 if h < 6.0 else 2):
			var y := fy + (maxf(2.5, h * 0.62) if k == 0 else maxf(3.1, h * 0.8))
			if y > top - 0.8:
				continue
			var rad := 0.11 if k == 0 else 0.16
			var c := face + nrm * 0.32
			var basis := Basis.looking_at(along, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
			_cyl(rad, rad, len - 0.6, basis, Vector3(c.x, y, c.z), m_pipe)
			for i in int(len / 2.0):
				var bc := face + along * (-len * 0.5 + 1.0 + i * 2.0) + nrm * 0.16
				_box(Vector3(0.12, 0.12, 0.34) if side >= 2 else Vector3(0.34, 0.12, 0.12), Vector3(bc.x, y - rad, bc.z), m_steel)
	# AC units with a status light, above head height
	if h >= 3.8 and r.randf() < 0.8:
		for i in r.randi_range(1, 2 if len < 8.0 else 4):
			var t := r.randf_range(-len * 0.5 + 1.2, len * 0.5 - 1.2)
			var y := fy + r.randf_range(2.95, maxf(3.0, h - 0.8))
			if y + 0.45 > top - 0.3:
				continue
			var c := face + along * t + nrm * 0.3
			_box(Vector3(1.3, 0.9, 0.6), Vector3(c.x, y, c.z), m_unit, rot)
			_box(Vector3(0.08, 0.08, 0.04), c + nrm * 0.31 + along * 0.45 + Vector3(0, 0.3, 0), m_led, rot, leds[r.randi() % leds.size()])
	# street level: vending machines (solid) or a lit shutter with an awning
	var u := r.randf()
	if fy <= bot + 0.01 and len > 4.0:
		var t := r.randf_range(-len * 0.5 + 1.5, len * 0.5 - 1.5)
		var c := face + along * t
		if u < 0.45:
			for k in r.randi_range(1, 2):
				var vc := c + along * (k * 1.1) + nrm * 0.45
				var half := Vector3(0.5, 0.95, 0.4) if side >= 2 else Vector3(0.4, 0.95, 0.5)
				var centre := Vector3(vc.x, fy + 0.95, vc.z)
				if not _free(centre, half, fy):
					continue
				_solid(centre, half)
				_box(half * 2.0, centre, m_steel)
				var fc := vc + nrm * 0.41
				_quad(Vector3(fc.x, fy + 0.95, fc.z), Vector3.UP.cross(nrm) * 0.46, Vector3.UP * 0.9, m_vend)
		elif u < 0.8 and h >= 3.0:
			var dc := c + nrm * 0.03
			_quad(Vector3(dc.x, fy + 1.25, dc.z), Vector3.UP.cross(nrm) * 0.75, Vector3.UP * 1.25, m_door)
			_box(Vector3(1.8, 0.15, 0.6) if side >= 2 else Vector3(0.6, 0.15, 1.8), Vector3(c.x, fy + 2.65, c.z) + nrm * 0.3, m_steel)
	# hanging blade signs, overhead
	if h >= 4.1 and r.randf() < 0.7:
		var hh := clampf((h - 2.6) * 0.5, 0.9, 1.5)
		var t := r.randf_range(-len * 0.5 + 1.0, len * 0.5 - 1.0)
		var sc := face + along * t + nrm * 0.75
		var y := fy + 2.3 + hh
		var sm: Material = m_signs[r.randi() % m_signs.size()]
		var col := a._accent(r.randi() % 8)
		_quad(Vector3(sc.x, y, sc.z), nrm * 0.6, Vector3.UP * hh, sm, col)
		_quad(Vector3(sc.x, y, sc.z), -nrm * 0.6, Vector3.UP * hh, sm, col)
		_box(Vector3(0.06, 0.06, 1.3) if side >= 2 else Vector3(1.3, 0.06, 0.06), Vector3(sc.x, y + hh + 0.05, sc.z), m_steel)


# ---------------------------------------------------------------- roof
func _roof() -> void:
	# pipe runs on stands along the parapet, in 6 m stretches (solid benches),
	# backed onto it so the edge stays one straight wall
	for sgn in [-1.0, 1.0]:
		for axis in 2:
			for i in 10:
				var t := -30.0 + i * 6.0 + 3.0
				var c: Vector3 = Vector3(t, 0.0, sgn * BENCH) if axis == 0 else Vector3(sgn * BENCH, 0.0, t)
				var half := Vector3(3.0, 0.45, 0.25) if axis == 0 else Vector3(0.25, 0.45, 3.0)
				if not _free(c + Vector3(0, 0.45, 0), half, 0.0):
					continue
				_solid(c + Vector3(0, 0.45, 0), half)
				var along := Vector3.RIGHT if axis == 0 else Vector3.BACK
				var basis := Basis.looking_at(along, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
				var inward: Vector3 = (Vector3.FORWARD * sgn if axis == 0 else Vector3.LEFT * sgn)
				for k in 2:
					_cyl(0.13, 0.13, 5.9, basis, c + Vector3(0, 0.45 + k * 0.32, 0) + inward * (k * 0.1), m_pipe)
				for j in 3:
					var bc := c + along * (j * 2.0 - 2.0) + Vector3(0, 0.25, 0)
					_box(Vector3(0.1, 0.5, 0.4) if axis == 0 else Vector3(0.4, 0.5, 0.1), bc, m_steel)
	# vents, AC boxes and stacked crates by the parapet
	var leds: Array[Color] = []
	for i in 6:
		leds.append(a._accent(i))
	for p in [Vector3(-28, 0, -18), Vector3(-29, 0, 14), Vector3(28, 0, -15), Vector3(28.5, 0, 19), Vector3(-7, 0, 29), Vector3(22, 0, 29), Vector3(-25, 0, 29), Vector3(28, 0, 3), Vector3(-28, 0, -3)]:
		match r.randi() % 3:
			0:
				if _free(p + Vector3(0, 0.7, 0), Vector3(0.62, 0.7, 0.62), p.y):
					_solid(p + Vector3(0, 0.55, 0), Vector3(0.32, 0.55, 0.32))
					_solid(p + Vector3(0, 1.25, 0), Vector3(0.62, 0.18, 0.62), 0.0, true)
					_cyl(0.32, 0.32, 1.1, Basis(), p + Vector3(0, 0.55, 0), m_pipe)
					_cyl(0.05, 0.62, 0.35, Basis(), p + Vector3(0, 1.25, 0), m_steel)
			1:
				var ang := r.randf() * PI
				var hh := HOP * 0.5
				var half := Vector3(absf(cos(ang)) * 0.8 + absf(sin(ang)) * 0.5, hh, absf(sin(ang)) * 0.8 + absf(cos(ang)) * 0.5)
				if _free(p + Vector3(0, hh, 0), half, p.y):
					_solid(p + Vector3(0, hh, 0), Vector3(0.8, hh, 0.5), ang)
					_box(Vector3(1.6, 1.0, 1.0), p + Vector3(0, 0.5, 0), m_unit, ang)
					_box(Vector3(1.4, HOP - 1.0, 0.8), p + Vector3(0, 1.0 + (HOP - 1.0) * 0.5, 0), m_steel, ang) # fan housing
					_box(Vector3(0.1, 0.1, 0.1), p + Vector3(0, 0.95, 0) + Vector3(0.5, 0, 0.51).rotated(Vector3.UP, ang), m_led, ang, leds[r.randi() % leds.size()])
			2:
				# a row of three crates with two on top: hop height, not knee height
				var hh := HOP * 0.5
				if _free(p + Vector3(0, hh, 0), Vector3(1.25, hh, 0.45), p.y):
					_solid(p + Vector3(0, hh, 0), Vector3(1.25, hh, 0.45))
					for k in 3:
						_box(Vector3(0.7, 0.6, 0.7), p + Vector3(k * 0.8 - 0.8, 0.3, 0), m_steel, r.randf_range(-0.1, 0.1))
					for k in 2:
						_box(Vector3(0.7, 0.6, 0.7), p + Vector3(k * 0.8 - 0.4, 0.9, 0), m_steel, 0.08 - k * 0.16)
	# drains: flat, in an open floor cell (water gathers round them)
	for p in [Vector3(-6, 0, 20), Vector3(6, 0, -19), Vector3(-20, 0, -12), Vector3(19, 0, 12), Vector3(0, 0, 16)]:
		_drains.append(p)
		_cyl(0.6, 0.6, 0.04, Basis(), p + Vector3(0, 0.02, 0), m_steel, 10)
	# skylights: flush with the floor, a thin frame you run straight over, with
	# a dim lit pane and glass on top (no collider: nothing to catch a foot on)
	for p in [Vector3(-24, 0, 16), Vector3(24, 0, -4), Vector3(-22, 0, -20), Vector3(23, 0, 20), Vector3(11.5, 5, -29.5)]:
		if not _free(p + Vector3(0, 0.3, 0), Vector3(1.5, 0.3, 1.0), p.y):
			continue
		_solids.append(AABB(p + Vector3(-1.5, 0, -1.0), Vector3(3.0, 0.6, 2.0))) # keeps props and puddles off it
		_box(Vector3(3.0, FLUSH, 2.0), p + Vector3(0, FLUSH * 0.5, 0), m_steel)
		_box(Vector3(2.6, 0.02, 1.6), p + Vector3(0, FLUSH + 0.01, 0), m_pane)
		_panes.append([p + Vector3(0, FLUSH + 0.025, 0), Vector2(1.3, 0.8)])
	# a small shrine (hokora), on the first spot that is clear
	for hp in [Vector3(-12, 5, -29.5), Vector3(21.5, 6.2, -30), Vector3(-24.5, 0, 30.5)]:
		if _free(hp + Vector3(0, 0.9, 0), Vector3(0.85, 0.9, 0.75), hp.y):
			_solid(hp + Vector3(0, 0.9, 0), Vector3(0.85, 0.9, 0.75))
			_box(Vector3(1.6, 0.4, 1.4), hp + Vector3(0, 0.2, 0), m_steel)
			_box(Vector3(1.2, 1.0, 1.0), hp + Vector3(0, 0.9, 0), a.m_lacquer)
			_box(Vector3(1.7, 0.12, 1.5), hp + Vector3(0, 1.48, 0), m_steel)
			_box(Vector3(1.0, 0.3, 1.2), hp + Vector3(0, 1.66, 0), m_steel)
			break
	# antennas on the tower and the catwalks' outer edges (thin: not solid)
	for p in [Vector3(5.5, 10, -30.5), Vector3(-5.5, 10, -30.5), Vector3(-26.8, 5, 18), Vector3(26.8, 5, -20)]:
		_box(Vector3(0.08, 3.5, 0.08), p + Vector3(0, 1.75, 0), m_steel)
		_box(Vector3(0.8, 0.06, 0.06), p + Vector3(0, 2.8, 0), m_steel)
		_box(Vector3(0.6, 0.06, 0.06), p + Vector3(0, 3.2, 0), m_steel)
		_box(Vector3(0.12, 0.12, 0.12), p + Vector3(0, 3.55, 0), m_led, 0.0, a._accent(0))


## Cables across the shaft and the roof, with paper lanterns.
func _cables() -> void:
	var red: Color = pal.neon_a
	var paper := Color(1.0, 0.86, 0.66)
	var lines := [
		[Vector3(-12, 9.5, -12), Vector3(12, 9.5, 12), 1.8, true],
		[Vector3(-12, 9.0, 12), Vector3(12, 9.0, -12), 1.5, true],
		[Vector3(-29.5, 9.2, -31), Vector3(-24.5, 6.0, 20), 2.0, false],
		[Vector3(29.5, 9.2, -31), Vector3(24.5, 6.0, 20), 2.0, false],
		[Vector3(-7, 13.0, -25), Vector3(-22, 6.0, 0), 1.2, true],
		[Vector3(7, 13.0, -25), Vector3(22, 6.0, 0), 1.2, true],
		[Vector3(-32, 7.0, 31), Vector3(32, 9.5, 31.5), 2.5, false],
		[Vector3(-22, 7.5, 20), Vector3(22, 7.5, 20), 2.6, true],
	]
	for l in lines:
		var p0: Vector3 = l[0]
		var p1: Vector3 = l[1]
		var sag: float = l[2]
		var segs := 18
		var prev := p0
		for i in range(1, segs + 1):
			var t := float(i) / segs
			var q := p0.lerp(p1, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
			var d := q - prev
			var dn := d.normalized()
			var basis := Basis.looking_at(dn, Vector3.UP if absf(dn.y) < 0.95 else Vector3.RIGHT)
			_add("box", Transform3D(basis * Basis.from_scale(Vector3(0.05, 0.05, d.length() + 0.02)), (prev + q) * 0.5), m_steel)
			if l[3] and i % 2 == 0 and i < segs:
				var lp := q + Vector3(0, -0.45, 0)
				var lit := (i / 2) % 2 == 0
				_cyl(0.17, 0.2, 0.42, Basis(), lp, m_paper, 8, Color(red.r, red.g, red.b) * 0.9 if lit else paper)
				_cyl(0.12, 0.12, 0.06, Basis(), lp + Vector3(0, 0.24, 0), m_steel)
				_cyl(0.12, 0.12, 0.06, Basis(), lp + Vector3(0, -0.24, 0), m_steel)
			prev = q


## Street lamps (solid posts): an emissive head, a pool of light and a soft
## beam under it. No real light: the map's own lamps do the lighting.
func _lamps() -> void:
	var spots := [
		Vector3(-27, 0, 12), Vector3(-27, 0, -14), Vector3(27, 0, -14), Vector3(27, 0, 13),
		Vector3(-14, 0, 27), Vector3(6, 0, 27), Vector3(-10, 0, -19.5), Vector3(10.5, 0, -19.5),
		Vector3(-23.5, 5, -23.8), Vector3(23.5, 5, -23.8), Vector3(-10.5, -10, -6.5), Vector3(10.5, -10, 6.5),
		Vector3(-10, -5, 10), Vector3(10, -5, -10),
	]
	for i in spots.size():
		var lp: Vector3 = spots[i]
		if not _free(lp + Vector3(0, 1.8, 0), Vector3(0.12, 1.8, 0.12), lp.y):
			continue
		_post_solid(lp, 0.12, 3.6)
		var col: Color = [Color(1.0, 0.78, 0.5), a._accent(1), a._accent(0), Color(1.0, 0.78, 0.5)][i % 4]
		_box(Vector3(0.14, 3.6, 0.14), lp + Vector3(0, 1.8, 0), m_post)
		_box(Vector3(0.7, 0.12, 0.3), lp + Vector3(0.3, 3.6, 0), m_post)
		_box(Vector3(0.5, 0.08, 0.22), lp + Vector3(0.4, 3.52, 0), m_led, 0.0, col)
		_pools.append([Vector3(lp.x + 0.4, lp.y, lp.z), col])
		_beam(lp + Vector3(0.4, 3.5, 0), lp + Vector3(0.4, 0, 0), 1.3, col, 0.12)


# ---------------------------------------------------------------- floor plates
## Floors become raised plates (lit grid seams between them), with grates,
## painted plates and the odd higher service plate. Some cells stay open (the
## grid floor shows, and rain collects there). Plated floors report the
## plates' top from Arena.floor_height_at.
func _plating() -> void:
	var amb: Color = Color(pal.ambient).lightened(0.4)
	var sl := {"self_light": 1.1, "self_tint": amb}
	var m_plate := Psx.lit(Color(0.95, 0.95, 1.05), TexGen.get_tex("panel"), true, 0.5, sl)
	var m_plate2 := Psx.lit(Color(0.62, 0.66, 0.78), TexGen.get_tex("panel"), true, 0.5, sl)
	var m_grate := Psx.lit(Color(0.55, 0.55, 0.62), TexGen.get_tex("grate"), true, 1.0, sl.merged({"emission_from_texture": 0.5, "emission_tint": pal.grid}))
	var m_paint := Psx.lit(Color(0.75, 0.6, 0.18), TexGen.get_tex("hazard"), true, 0.5, sl)
	var marks: Array[Vector3] = a.ground_spawns.duplicate() # hatches, lifts, pads: bare cells
	for jp in a.jump_pads:
		marks.append(jp.pos)
	for pl in a._platforms:
		if pl.mat != a.m_grid or pl.rot != 0.0 or pl.hx * pl.hz * 4.0 < 6.0:
			continue
		var top: float = pl.h
		var c: Vector2 = pl.c
		var x0 := CELL * ceilf((c.x - pl.hx) / CELL)
		var z0 := CELL * ceilf((c.y - pl.hz) / CELL)
		var x := x0
		while x + CELL <= c.x + pl.hx + 0.01:
			var z := z0
			while z + CELL <= c.y + pl.hz + 0.01:
				var cc := Vector3(x + 1.0, top, z + 1.0)
				var u := r.randf()
				z += CELL
				if _drained(cc):
					_open_cells.append(cc)
					continue
				if _bare(cc, marks):
					continue
				if u > 0.93:
					_open_cells.append(cc)
					continue
				var m: Material = m_plate if (int(cc.x) / 2 + int(cc.z) / 2) % 5 != 0 else m_plate2
				var hgt := LIFT
				if u < 0.12:
					m = m_grate
					hgt = 0.02
				elif u < 0.16:
					m = m_paint
				elif u < 0.2:
					hgt = RAISED
				_box(Vector3(1.8, hgt, 1.8), cc + Vector3(0, hgt * 0.5, 0), m)
			x += CELL
		pl.lift = LIFT


## A drain sits in this cell: it stays open, and water gathers there.
func _drained(cc: Vector3) -> bool:
	for d in _drains:
		if absf(d.y - cc.y) < 0.5 and absf(d.x - cc.x) <= 1.0 and absf(d.z - cc.z) <= 1.0:
			return true
	return false


## A cell left without a plate: a hatch, a lift, a pad, or a neon strip.
func _bare(cc: Vector3, marks: Array[Vector3]) -> bool:
	for m in marks:
		if absf(m.y - cc.y) < 0.5 and absf(m.x - cc.x) < 2.0 and absf(m.z - cc.z) < 2.0:
			return true
	var cell := AABB(cc + Vector3(-1.0, -0.1, -1.0), Vector3(2.0, 0.3, 2.0))
	for n in _floor_neon:
		if n.intersects(cell):
			return true
	return false


# ---------------------------------------------------------------- air and light
func _air() -> void:
	# the far city fades into the haze sooner
	for n in a.find_children("*", "GeometryInstance3D", true, false):
		var m := (n as GeometryInstance3D).material_override as ShaderMaterial
		if m == null or m.get_shader_parameter("fog_end") == null:
			continue
		if float(m.get_shader_parameter("fog_end")) > 150.0:
			m.set_shader_parameter("fog_start", 25.0)
			m.set_shader_parameter("fog_end", 260.0)
	a.env.ambient_light_energy = 0.7
	for pc in _pools: # street lamps
		var at: Vector3 = pc[0]
		var col: Color = pc[1]
		_decal(Vector3(at.x, a.floor_height_at(at.x, at.z, at.y + 0.5) + 0.04, at.z), 4.5, 4.5, m_pool, Color(col.r, col.g, col.b, 0.5))
	# a pool of light on the floor under every lamp, and brighter lamps
	for l in a.find_children("*", "OmniLight3D", true, false):
		var ol: OmniLight3D = l
		if a.backdrop.is_ancestor_of(ol):
			continue
		var p := ol.global_position
		var fy := a.floor_height_at(p.x, p.z, p.y)
		var rad := clampf(ol.omni_range * 0.55, 3.0, 9.0) * clampf(1.0 - (p.y - fy) / 22.0, 0.4, 1.0)
		var c := ol.light_color
		_decal(Vector3(p.x, fy + 0.04, p.z), rad, rad, m_pool, Color(c.r, c.g, c.b, 0.55))
		ol.light_energy *= 1.5
		for fl in a._flicker_lights:
			if fl[0] == ol:
				fl[1] *= 1.5
	# neon strips near a floor throw a glow strip onto it
	for n in a.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var m := mi.material_override as ShaderMaterial
		if a.backdrop.is_ancestor_of(mi) or not (mi.mesh is BoxMesh) or m == null or m.shader != Psx.shader("psx_unlit"):
			continue
		var s: Vector3 = (mi.mesh as BoxMesh).size * mi.global_basis.get_scale()
		var p := mi.global_position
		var long := maxf(s.x, s.z)
		if long < 2.5 or s.y > 0.5:
			continue
		var fy := a.floor_height_at(p.x, p.z, p.y - 0.05)
		if p.y - fy > 4.5 or p.y - fy < 0.2:
			continue
		var col: Color = m.get_shader_parameter("albedo_color")
		var w := 1.6 + (p.y - fy) * 0.4
		var along := Vector3.RIGHT if s.x > s.z else Vector3.BACK
		var across := Vector3.BACK if s.x > s.z else Vector3.RIGHT
		_quad(Vector3(p.x, fy + 0.035, p.z), along * (long * 0.5 + w * 0.5), across * w, m_pool, Color(col.r, col.g, col.b, 0.35 * (1.0 - (p.y - fy) / 6.0)))
	_mist()
	_beams()
	_steam()
	_dust()
	_contact_shadows(0.8)


func _mist() -> void:
	var col: Color = Color(pal.fog).lerp(pal.accents[3], 0.3).lightened(0.35)
	# the shaft fills with low coloured mist
	for k in 3:
		_decal(Vector3(0, [-9.55, -8.9, -8.0][k], 0), 12.0, 12.0, m_mist, Color(col.r, col.g, col.b, [0.32, 0.22, 0.14][k]))
	# a cloud deck below the roof edge: the city drops away into haze
	for ix in range(-3, 4):
		for iz in range(-3, 4):
			if absi(ix) <= 1 and absi(iz) <= 1:
				continue
			_decal(Vector3(ix * 40.0, -7.0, iz * 40.0), 20.0, 20.0, m_mist, Color(col.r, col.g, col.b, 0.55))
			_decal(Vector3(ix * 40.0 + 13, -2.5, iz * 40.0 + 7), 20.0, 20.0, m_mist, Color(col.r, col.g, col.b, 0.35))
	# low ground mist on the roof ring
	for p in [Vector3(-22, 0.3, 26), Vector3(20, 0.3, -16), Vector3(-24, 0.3, -14), Vector3(24, 0.3, 14), Vector3(0, 5.3, -27), Vector3(-6, 0.3, 18)]:
		var sz := r.randf_range(5.0, 8.0)
		_decal(p, sz, sz * 0.7, m_mist_patch, Color(col.r, col.g, col.b, 0.28))


## Crossed additive quads: a soft beam from `from` towards `to`.
func _beam(from: Vector3, to: Vector3, w0: float, col: Color, inten: float) -> void:
	var d := to - from
	var dn := d.normalized()
	var side := dn.cross(Vector3.UP if absf(dn.y) < 0.95 else Vector3.RIGHT).normalized()
	for k in 3:
		_quad((from + to) * 0.5, side.rotated(dn, k * PI / 3.0) * w0, -d * 0.5, m_beam, Color(col.r, col.g, col.b, inten))


func _beams() -> void:
	# downlights into the shaft from the rim
	for p in [Vector3(-11, -1.2, -11), Vector3(11, -1.2, 11), Vector3(11, -1.2, -11), Vector3(-11, -1.2, 11)]:
		_beam(p, Vector3(p.x * 0.55, -10, p.z * 0.55), 1.8, a._accent(1 if p.x > 0 else 4), 0.22)
	# the torii's glow down onto the bridge, a floodlight onto the big ad
	_beam(Vector3(0, 10.5, 0), Vector3(0, 5, 0), 3.0, pal.neon_a, 0.18)
	_beam(Vector3(16, 3.2, 25), Vector3(16, 13, 28.8), 3.0, a._accent(4), 0.16)
	# searchlights from the north pylons into the sky
	_beam(Vector3(-30, 9.2, -31), Vector3(-55, 70, -90), 2.0, Color(0.85, 0.9, 1.0), 0.2)
	_beam(Vector3(30, 9.2, -31), Vector3(75, 75, -60), 2.0, Color(0.85, 0.9, 1.0), 0.2)
	# lamp cones under the side catwalks
	for s in [-1.0, 1.0]:
		for z in [-12.0, 0.0, 12.0]:
			_beam(Vector3(s * 24.5, 4.4, z), Vector3(s * 24.5, 0, z), 1.6, a._accent(3 if s > 0 else 5), 0.14)


func _steam() -> void:
	var m := Psx.fx(Color(0.9, 0.88, 1.0, 0.16), TexGen.get_tex("mist"), false, true)
	for src in [Vector3(16.75, 7.7, 7), Vector3(-19.5, 4.3, 24.5), Vector3(-10.3, -9.5, 0), Vector3(10.3, -9.5, 0), Vector3(-24.5, 0.2, -11)]:
		for k in 6:
			var q := Psx.quad(Vector2(1.0 + k * 0.9, 1.0 + k * 0.9), m, src + Vector3(k * 0.25, k * 0.9, -k * 0.15))
			a.add_child(q)
			_extras.append(q)


func _dust() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	mm.mesh = qm
	mm.instance_count = 600
	for i in mm.instance_count:
		var p: Vector3
		if i < 300:
			p = Vector3(r.randf_range(-12, 12), r.randf_range(-10, 4), r.randf_range(-12, 12))
		else:
			p = Vector3(r.randf_range(-30, 30), r.randf_range(0.3, 9), r.randf_range(-30, 30))
		mm.set_instance_transform(i, Transform3D(Basis(), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Psx.fx(Color(1.0, 0.9, 0.8, 1.0), TexGen.get_tex("glow"), true, true, false, 0.9)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(mmi)
	_extras.append(mmi)


## Baked contact shadows: a dark fade up each wall foot and out across the
## floor beside it (the PS1 trick for "this sits on the ground").
func _contact_shadows(strength: float) -> void:
	var col := Color(0, 0, 0, strength)
	for b in _boxes:
		var s: Vector3 = b.size
		var p: Vector3 = b.pos
		if s.y < 0.5:
			continue
		var top := p.y + s.y * 0.5
		for side in 4:
			var nrm := SIDES[side]
			var half_w: float = s.z * 0.5 if side < 2 else s.x * 0.5
			var off: float = s.x * 0.5 if side < 2 else s.z * 0.5
			var along: Vector3 = Vector3.BACK if side < 2 else Vector3.RIGHT
			var probe := p + nrm * (off + 0.4)
			var fy := a.floor_height_at(probe.x, probe.z, top - 0.3)
			if fy >= top - 0.3 or fy < p.y - s.y * 0.5 - 0.01:
				continue
			var h := minf(1.6, (top - fy) * 0.6)
			var face := p + nrm * (off + 0.02)
			_quad(Vector3(face.x, fy + h * 0.5, face.z), along * half_w, Vector3.UP * h * 0.5, m_shadow, col)
			var fl := p + nrm * (off + 0.45)
			_quad(Vector3(fl.x, fy + 0.03, fl.z), along * half_w, nrm * 0.45, m_shadow, col)


# ---------------------------------------------------------------- water
## Puddles only where rain would really collect: open floor cells and drains,
## along the parapet foot and the foot of tall walls, low spots on the roof,
## and the metro floor (it leaks, so it is wet even on a dry night). Their
## number follows the run's rain; skylight glass is always there.
func _puddles() -> void:
	var rain := a.rain_level
	var w := r.seed ^ (Game.rng_map.seed if Game.rng_map else 0)
	r.seed = w # puddle shapes vary by seed; nothing else is rolled after this
	var mats: Array[ShaderMaterial] = []
	for k in ["puddle0", "puddle1", "puddle2", "puddle_cell", ""]:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/puddle.gdshader")
		if k != "":
			m.set_shader_parameter("mask_tex", TexGen.get_tex(k))
			m.set_shader_parameter("use_mask", true)
		m.set_shader_parameter("ripple", TexGen.get_tex("mist_tile"))
		m.set_shader_parameter("fog_color", _haze)
		m.set_shader_parameter("sky_tint", Color(pal.sky_mid).darkened(0.3))
		mats.append(m)
	var pane: ShaderMaterial = mats[4]
	pane.set_shader_parameter("water", a._accent(1).darkened(0.8))
	pane.set_shader_parameter("amount", 0.55)
	pane.set_shader_parameter("alpha_max", 0.85)
	var k := 1.25 if rain >= 2 else 1.0
	var spots: Array = [] # [centre, half x, half z, material index]
	if rain > 0:
		for c in _open_cells:
			spots.append([c + Vector3(0, 0.012, 0), 1.0, 1.0, 3])
		for d in _drains:
			spots.append([d, r.randf_range(1.4, 2.0) * k, r.randf_range(1.1, 1.6) * k, r.randi() % 3])
		for s in [-1.0, 1.0]:
			for i in 5:
				var t := r.randf_range(-27, 27)
				spots.append([Vector3(t, 0, s * 30.0), r.randf_range(1.6, 2.8) * k, 0.8, r.randi() % 3])
				spots.append([Vector3(s * 30.0, 0, t), 0.8, r.randf_range(1.6, 2.8) * k, r.randi() % 3])
		for b in _boxes:
			var sz: Vector3 = b.size
			if sz.y < 2.5 or r.randf() > (1.0 if rain >= 2 else 0.75):
				continue
			var p: Vector3 = b.pos
			var side := r.randi() % 4
			var nrm := SIDES[side]
			var off: float = sz.x * 0.5 if side < 2 else sz.z * 0.5
			var q := p + nrm * (off + 1.2)
			var fy := a.floor_height_at(q.x, q.z, p.y + sz.y * 0.5 - 0.3)
			if fy < p.y - sz.y * 0.5 - 0.01:
				continue
			var len := r.randf_range(1.6, 3.0) * k
			spots.append([Vector3(q.x, fy, q.z), len if side >= 2 else 1.1, 1.1 if side >= 2 else len, r.randi() % 3])
		for q in [Vector3(-14, 0, 15), Vector3(-10, 0, 21), Vector3(-17, 0, 10), Vector3(14, 0, 18), Vector3(-4, 0, -16), Vector3(20, 0, -12), Vector3(-22, 0, 4)]:
			spots.append([q, r.randf_range(1.6, 2.6) * k, r.randf_range(1.2, 2.0) * k, r.randi() % 3])
	for q in [Vector3(-9.5, -10, 0.5), Vector3(9.5, -10, -0.5), Vector3(-2, -10, 3), Vector3(3, -10, -2.5), Vector3(0.5, -10, 9.5), Vector3(-7, -10, -7)]:
		spots.append([q, r.randf_range(1.2, 2.2) * k, r.randf_range(1.0, 1.8) * k, r.randi() % 3])
	for sp in spots:
		var c: Vector3 = sp[0]
		if Vector2(c.x - a.player_spawn.x, c.z - a.player_spawn.z).length() < 2.5:
			continue
		var ang := r.randf() * TAU if sp[3] != 3 else 0.0
		var hx: float = sp[1]
		var hz: float = sp[2]
		if sp[3] != 3:
			# lies flat on one floor: no water hanging over an edge or up a step
			var fy := a.floor_height_at(c.x, c.z, c.y + 0.5)
			var ok := true
			for q in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(-hx, hz), Vector2(hx, hz)]:
				var o: Vector2 = (q as Vector2).rotated(-ang) * 0.7
				if absf(a.floor_height_at(c.x + o.x, c.z + o.y, c.y + 0.5) - fy) > 0.03:
					ok = false
			if not ok:
				continue
			c.y = fy + 0.015
		if _under_solid(c, hx, hz, ang):
			continue
		_decal(c, hx, hz, mats[sp[3]], Color.WHITE, ang)
		puddles += 1
		puddle_spots.append(c)
	for g in _panes:
		_decal(g[0], (g[1] as Vector2).x, (g[1] as Vector2).y, pane)
		glass += 1
	mirror = PuddleMirror.new()
	a.add_child(mirror)
	mirror.setup(a, mats)
