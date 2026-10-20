class_name Arena
extends Node3D
## Base class for every map. A map subclass builds its layout in `_build_layout()`
## using the helpers here; this class handles the parts every map shares:
## environment and sky from the run palette, weather, lightning, the floor-height
## query used by gore, and spawn/jump-pad bookkeeping.
## New maps: subclass Arena in scripts/maps/ and register it in map_registry.gd.

## A spawn group lands within this many metres of its spawn point (the
## director's +-2 m offsets, and the second grunt a boss wave sends in).
const GROUND_SPAWN_REACH := 3.0
const PICKUP_TOP := 12.0 # soda cans sit no higher than this (metres)
const PICKUP_CLEAR := 2.2 # ...with this much open air above them

var map_name := "UNNAMED"
var half := 32.0
var player_spawn := Vector3(0, 0.1, 24)
var boss_spawn := Vector3(0, 0, -22)
var spawn_points: Array[Vector3] = []
var jump_pads: Array = []
var rain: CPUParticles3D
var pal: Dictionary
var rng: RandomNumberGenerator
var env: Environment
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var rain_level := 1 # 0 none, 1 light, 2 heavy
## Debug and tests: the weather every map gets (-1 = rolled from the seed).
static var force_rain := -1
var floor_base := 0.0 # what floor_height_at returns where no platform or ramp is
var kill_y := -10.0 # the player falls back to the spawn below this; enemies 2 m higher
var enemy_reset := Vector3(0, 6, -20) # where an enemy that fell off the map comes back
var ground_spawns: Array[Vector3] = [] # spawn points enemies walk out of instead of dropping onto
var use_navigation := false # bake a navmesh so enemies path between levels
var nav_links: Array = [] # [low, high] leap points between levels, added by the map
var nav_region: NavigationRegion3D
const NAV_WALK := 1 # navigation layer: floors and ramps
const NAV_LEAP := 2 # navigation layer: leap links (enemies only; the autoplay bot walks)

var _platforms: Array = [] # {c: Vector2, hx, hz, rot, h, mat, lift}
var _ramps: Array = []     # {a: Vector3, b: Vector3, w}
var _pickup_spots: Array[Vector3] = []
var _pickup_spots_done := false
var _flicker_lights: Array = []
var _t := 0.0
var _storm := false
var _lightning_t := 3.0
var _flash := 0.0


func build() -> void:
	pal = Game.palette
	rng = Game.rng_map
	Psx.fog_color = pal.fog
	_setup_environment()
	_build_layout()
	if use_navigation:
		_build_navigation()
	_build_rain()
	_after_weather()
	Graphics.attach(self) # the quality preset's lighting, now and on change


## Override in a map subclass.
func _build_layout() -> void:
	pass


## Override in a map subclass: dressing that depends on the run's weather
## (rain_level is rolled after the layout). Runs before Graphics attaches;
## nothing here may collide, since the navmesh is already baked.
func _after_weather() -> void:
	pass


func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("top_color", pal.sky_top)
	sky_mat.set_shader_parameter("mid_color", pal.sky_mid)
	sky_mat.set_shader_parameter("horizon_color", pal.sky_horizon)
	sky_mat.set_shader_parameter("sun_top", pal.sun_top)
	sky_mat.set_shader_parameter("sun_bottom", pal.sun_bottom)
	sky_mat.set_shader_parameter("mountain_color", pal.mountain)
	sky_mat.set_shader_parameter("rim_color", pal.grid)
	sky_mat.set_shader_parameter("ground_color", pal.floor)
	sky_mat.set_shader_parameter("sun_azimuth", rng.randf_range(-0.35, 0.35))
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = pal.ambient
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 1.05
	env.glow_strength = 1.1
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = pal.sun_bottom.lerp(Color.WHITE, 0.4)
	moon.light_energy = 0.45
	moon.rotation = Vector3(-0.5, PI, 0.0)
	moon.shadow_enabled = false
	add_child(moon)


# ---------------------------------------------------------------- helpers
func _solid(size: Vector3, pos: Vector3, mat: Material, rot_y := 0.0, subdiv := 2, show := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = rot_y
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	if show:
		body.add_child(Psx.box(size, mat, Vector3.ZERO, subdiv))
	add_child(body)
	return body


func _platform(size: Vector3, pos: Vector3, mat: Material, rot_y := 0.0) -> StaticBody3D:
	var b := _solid(size, pos, mat, rot_y)
	_platforms.append({"c": Vector2(pos.x, pos.z), "hx": size.x * 0.5, "hz": size.z * 0.5, "rot": rot_y, "h": pos.y + size.y * 0.5, "mat": mat, "lift": 0.0})
	return b


## Solid wedge ramp from a (low end, on the ground) up to b (high end).
## Solid all the way down so nothing can get wedged underneath it.
func _ramp(a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var flat := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var side := flat.cross(Vector3.UP).normalized() * width * 0.5
	var lo_l := a - side
	var lo_r := a + side
	var hi_l := b - side
	var hi_r := b + side
	var base_l := Vector3(hi_l.x, a.y, hi_l.z)
	var base_r := Vector3(hi_r.x, a.y, hi_r.z)
	var tris := [
		[lo_l, hi_l, hi_r], [lo_l, hi_r, lo_r],
		[base_l, base_r, hi_r], [base_l, hi_r, hi_l],
		[lo_l, base_l, hi_l], [lo_r, hi_r, base_r],
		[lo_l, lo_r, base_r], [lo_l, base_r, base_l],
	]
	var centroid := (lo_l + lo_r + hi_l + hi_r + base_l + base_r) / 6.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for t in tris:
		var v0: Vector3 = t[0]
		var v1: Vector3 = t[1]
		var v2: Vector3 = t[2]
		var outward := (v0 + v1 + v2) / 3.0 - centroid
		# Godot front faces are clockwise: the raw cross product must point inward.
		if (v1 - v0).cross(v2 - v0).dot(outward) > 0.0:
			var tmp := v1
			v1 = v2
			v2 = tmp
		for v in [v0, v1, v2]:
			st.set_uv(Vector2(v.x, v.z) * 0.5)
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := ConvexPolygonShape3D.new()
	sh.points = PackedVector3Array([lo_l, lo_r, hi_l, hi_r, base_l, base_r])
	cs.shape = sh
	body.add_child(cs)
	add_child(body)
	_ramps.append({"a": a, "b": b, "w": width})


func _neon(size: Vector3, pos: Vector3, color: Color, energy := 3.0, parent: Node3D = null, flicker := 0.0) -> MeshInstance3D:
	var mi := Psx.box(size, Psx.unlit(color, energy, null, {"flicker": flicker, "fog_amount": 0.3}), pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


## Neon tubes along the 12 edges of a box (centre `c`, size `s`, yaw `rot`).
func _neon_box_edges(c: Vector3, s: Vector3, rot: float, color: Color, energy := 2.6, top_only := false) -> void:
	var root := Node3D.new()
	root.position = c
	root.rotation.y = rot
	add_child(root)
	var t := 0.07
	var hx := s.x * 0.5
	var hy := s.y * 0.5
	var hz := s.z * 0.5
	for sy in ([1.0] if top_only else [-1.0, 1.0]):
		for sz in [-1.0, 1.0]:
			_neon(Vector3(s.x + t, t, t), Vector3(0, sy * hy, sz * hz), color, energy, root)
		for sx in [-1.0, 1.0]:
			_neon(Vector3(t, t, s.z + t), Vector3(sx * hx, sy * hy, 0), color, energy, root)
	if not top_only:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_neon(Vector3(t, s.y, t), Vector3(sx * hx, 0, sz * hz), color, energy, root)


func _light(pos: Vector3, color: Color, energy: float, rng_range: float, flicker := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_range
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	add_child(l)
	if flicker:
		_flicker_lights.append([l, energy])
	return l


func _halo(pos: Vector3, color: Color, size: float, intensity := 0.6) -> void:
	var q := Psx.quad(Vector2(size, size), Psx.fx(color, TexGen.get_tex("glow"), true, true, false, intensity), pos)
	add_child(q)


func _pick(arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]


## Accent colour i of the run palette (wraps), for spreading hues over a map.
func _accent(i: int) -> Color:
	var acc: Array = pal.accents
	return acc[posmod(i, acc.size())]


## Height of the floor at (x, z): the highest platform or ramp top at or
## below `below`, so stacked floors give the one under the caller. A floor
## dressed with plates (WorldDetail) reports the plates' top, so blood,
## telegraphs and gibs sit on them.
func floor_height_at(x: float, z: float, below := INF) -> float:
	var h := floor_base
	for p in _platforms:
		if p.h > below:
			continue
		var d: Vector2 = Vector2(x, z) - p.c
		if p.rot != 0.0:
			d = d.rotated(p.rot)
		if absf(d.x) <= p.hx and absf(d.y) <= p.hz:
			h = maxf(h, p.h + p.lift)
	for r in _ramps:
		var a: Vector3 = r.a
		var b: Vector3 = r.b
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(x - a.x, z - a.z)
		var len2 := ab.length_squared()
		var t := ap.dot(ab) / len2
		if t < 0.0 or t > 1.0:
			continue
		var lateral := absf(ap.cross(ab)) / sqrt(len2)
		var rh := lerpf(a.y, b.y, t)
		if lateral <= r.w * 0.5 and rh <= below:
			h = maxf(h, rh)
	return h


## Where soda cans may appear (SodaCans): the middle of every platform top
## that is inside the map, open to the sky for a body's height and no higher
## than PICKUP_TOP, plus the spawn points on the edges. Worked out once, in
## build order, so the same seed always sees the same list.
func pickup_spots() -> Array[Vector3]:
	if _pickup_spots_done:
		return _pickup_spots
	_pickup_spots_done = true
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 1
	var cands: Array[Vector3] = []
	for p in _platforms:
		if p.hx >= 0.6 and p.hz >= 0.6:
			cands.append(Vector3(p.c.x, p.h, p.c.y))
	cands.append_array(spawn_points)
	for c in cands:
		if absf(c.x) > half - 1.5 or absf(c.z) > half - 1.5 or c.y > PICKUP_TOP or c.y < floor_base - 0.5:
			continue
		# nothing over the spot for a body's height, and the floor is really there
		q.from = c + Vector3(0, PICKUP_CLEAR, 0)
		q.to = c - Vector3(0, 0.4, 0)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or absf(hit.position.y - c.y) > 0.2:
			continue
		var dup := false
		for o in _pickup_spots:
			if o.distance_to(c) < 2.0:
				dup = true
		if not dup:
			# on top of any floor plates
			_pickup_spots.append(Vector3(c.x, floor_height_at(c.x, c.z, hit.position.y + 0.01), c.z))
	return _pickup_spots


## How far above a spawn point an enemy appears (the director rolls 7-9 m).
## Ground spawns (tunnels, lifts, hatches) have a roof over them: walk out.
## That covers the rest of a spawn group too, which lands up to
## GROUND_SPAWN_REACH metres away (it used to drop from 9 m into the roof
## and stay wedged there, so the wave never ended).
func spawn_clearance(p: Vector3) -> float:
	for g in ground_spawns:
		if absf(g.y - p.y) < 0.5 and Vector2(g.x - p.x, g.z - p.z).length() <= GROUND_SPAWN_REACH:
			return 0.3
	return 9.0


# ---------------------------------------------------------------- navigation
## The nearest walkable point to `p` (on the navmesh), or `p` itself on maps
## without one. Keeps teleports and reinforcements out of walls and the pit.
func safe_point(p: Vector3) -> Vector3:
	if nav_region == null:
		return p
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return p
	var q := NavigationServer3D.map_get_closest_point(map, p)
	return Vector3(q.x, q.y - 0.4, q.z) # the navmesh sits about half a metre above the floor


## Bake a navmesh from the map's static colliders and add the leap links.
## Enemies path over it (Enemy._steer); maps opt in with use_navigation.
func _build_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.filter_baking_aabb = AABB(Vector3(-half - 2.0, -16.0, -half - 2.0), Vector3(half * 2.0 + 4.0, 40.0, half * 2.0 + 4.0))
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav_region = NavigationRegion3D.new()
	nav_region.navigation_mesh = nm
	nav_region.navigation_layers = NAV_WALK | NAV_LEAP
	add_child(nav_region)
	for l in nav_links:
		var link := NavigationLink3D.new()
		link.bidirectional = true
		link.start_position = l[0]
		link.end_position = l[1]
		link.enter_cost = 4.0 # ramps win unless the leap saves real distance
		link.navigation_layers = NAV_LEAP
		add_child(link)


# ---------------------------------------------------------------- weather
func _build_rain() -> void:
	rain = CPUParticles3D.new()
	rain.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF # follows the player every frame
	rain.amount = 700
	rain.lifetime = 0.9
	rain.preprocess = 1.0
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(22, 0.5, 22)
	rain.direction = Vector3(0.12, -1, 0.05)
	rain.spread = 2.0
	rain.initial_velocity_min = 24.0
	rain.initial_velocity_max = 28.0
	rain.gravity = Vector3(0, -12, 0)
	rain.particle_flag_align_y = true
	var am := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var ax := Vector3(0.012, 0, 0) if k == 0 else Vector3(0, 0, 0.012)
		var up := Vector3(0, 0.32, 0)
		var v := [-ax - up, ax - up, ax + up, -ax + up]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(v[idx])
	st.commit(am)
	rain.mesh = am
	var rc: Color = pal.neon_b.lerp(Color.WHITE, 0.5)
	rain.material_override = Psx.fx(Color(rc.r, rc.g, rc.b, 0.3), null, false)
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)
	var roll := rng.randf()
	rain_level = 0 if roll < 0.35 else (1 if roll < 0.8 else 2)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rain="): # debug: force the weather (the roll above still happens)
			force_rain = clampi(int(arg.substr(7)), 0, 2)
	if force_rain >= 0:
		rain_level = force_rain
	_apply_rain()


func _apply_rain() -> void:
	var lvl := 2 if _storm else rain_level
	var amt := 320 if lvl == 1 else 760
	if rain.amount != amt:
		rain.amount = amt
	rain.emitting = lvl > 0
	Sfx.set_rain(lvl)


func set_storm(on: bool) -> void:
	if _storm == on:
		return
	_storm = on
	_lightning_t = 1.5
	_apply_rain()


func _process(delta: float) -> void:
	_t += delta
	if rain and Game.player:
		rain.global_position = Game.player.global_position + Vector3(0, 13, 0)
	for fl in _flicker_lights:
		var l: OmniLight3D = fl[0]
		var n := sin(_t * 23.0 + l.position.x) * sin(_t * 7.3 + l.position.z)
		l.light_energy = fl[1] * (0.25 if n > 0.82 else 1.0)
	if _storm:
		_lightning_t -= delta
		if _lightning_t <= 0.0:
			_lightning_t = Game.rng_fx.randf_range(3.0, 8.0)
			_flash = 1.0
			Sfx.play("thunder", -2.0, 1.0, 0.15)
			if Game.hud and Game.hud.post:
				Game.hud.post.flash(0.35)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		var k := _flash * (0.6 + 0.4 * sin(_t * 60.0))
		moon.light_energy = 0.45 + k * 4.0
		env.ambient_light_energy = 0.95 + k * 1.5
	elif moon.light_energy != 0.45:
		moon.light_energy = 0.45
		env.ambient_light_energy = 0.95
