extends GutTest
## The Well's world detail (WorldDetail, PuddleMirror; owner's pick of look
## B with C's haze, 2026-10-19): it never changes what a seed plays, its solid
## props stay out of the way, and only puddles and glass reflect.

const SEED := 0x5EED0042

var arena: WellMap


func _build(rain := -1) -> WellMap:
	Game.next_seed = SEED
	Game.reset_run()
	Arena.force_rain = rain
	var w := WellMap.new()
	add_child(w)
	w.build()
	Arena.force_rain = -1
	return w


func before_all() -> void:
	arena = _build(1)


func after_all() -> void:
	arena.queue_free()
	Quality.apply(Quality.DEFAULT)
	WorldDetail.enabled = true


func test_the_seed_plays_the_same() -> void:
	# a bare map and a dressed one roll the same dice: same weather, same signs
	WorldDetail.enabled = false
	var bare := _build()
	var bare_state := Game.rng_map.state
	var bare_rain := bare.rain_level
	WorldDetail.enabled = true
	var dressed := _build()
	assert_eq(Game.rng_map.state, bare_state, "the map's dice end in the same place")
	assert_eq(dressed.rain_level, bare_rain)
	assert_eq(dressed.spawn_points, bare.spawn_points)
	bare.free()
	dressed.free()


func _dist(box: AABB, p: Vector3) -> float:
	var q := Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.z, box.position.z, box.end.z))
	return q.distance_to(Vector2(p.x, p.z))


func test_solid_props_keep_spawns_and_leaps_clear() -> void:
	var d := arena.detail
	assert_gt(d.prop_boxes.size(), 20, "vending machines, vents, benches, lamps...")
	for box in d.prop_boxes:
		var fy := box.position.y
		for p in arena.spawn_points:
			if absf(p.y - fy) < 2.5:
				assert_gte(_dist(box, p), WorldDetail.CLEAR - 0.01, "prop %s clear of spawn %s" % [box, p])
		for l in arena.nav_links:
			for p: Vector3 in l:
				if absf(p.y - fy) < 2.5:
					assert_gte(_dist(box, p), WorldDetail.CLEAR_LINK - 0.01, "prop %s clear of leap %s" % [box, p])


func test_no_prop_is_a_step_to_a_sheer_wall() -> void:
	# 7 m walls stay out of reach: nothing solid to jump from within range
	var d := arena.detail
	for box in d.prop_boxes:
		var fy := box.position.y
		for i in d._map_solids:
			var s: AABB = d._solids[i]
			var rise := s.end.y - fy
			if rise > WorldDetail.REACH and rise <= box.size.y + WorldDetail.REACH + 0.3:
				var dx := maxf(0.0, maxf(s.position.x - box.end.x, box.position.x - s.end.x))
				var dz := maxf(0.0, maxf(s.position.z - box.end.z, box.position.z - s.end.z))
				assert_gte(Vector2(dx, dz).length(), WorldDetail.REACH_RANGE, "prop %s is far from %s" % [box, s])


func test_the_weather_has_its_own_stream() -> void:
	# KI-025: however much the map draws from its stream before the weather
	# roll, a seed keeps its weather
	var a := _build()
	var level := a.rain_level
	a.free()
	Game.next_seed = SEED
	Game.reset_run()
	for i in 7:
		Game.rng_map.randi() # as if the map had drawn more
	var b := WellMap.new()
	add_child(b)
	b.build()
	assert_eq(b.rain_level, level)
	var r := RandomNumberGenerator.new()
	r.seed = hash([SEED, "weather"])
	var roll := r.randf()
	assert_eq(level, 0 if roll < 0.35 else (1 if roll < 0.8 else 2), "rolled from the seed's weather stream")
	b.free()


func test_puddles_follow_the_rain() -> void:
	var dry := _build(0)
	var wet := _build(2)
	assert_gt(dry.detail.puddles, 0, "the metro floor leaks even on a dry night")
	assert_lte(dry.detail.puddles, 6, "no rain: no puddles on the roof")
	assert_gt(arena.detail.puddles, dry.detail.puddles * 5, "light rain")
	assert_gte(wet.detail.puddles, arena.detail.puddles, "heavy rain")
	assert_eq(dry.detail.glass, arena.detail.glass, "glass is there in any weather")
	dry.free()
	wet.free()


func test_no_puddle_lies_inside_a_block() -> void:
	var dry := _build(0)
	assert_gt(dry.detail.puddle_spots.size(), 0)
	for c in dry.detail.puddle_spots:
		# the south service block is solid from the metro floor up (KI-004)
		assert_false(absf(c.x) < 12.0 and c.z > 8.0 and c.y < -9.0, "puddle %s is not under the south service block" % c)
		for b in dry.detail._solids:
			assert_false((b as AABB).has_point(c + Vector3(0, 0.3, 0)), "puddle %s is not inside %s" % [c, b])
	dry.free()


func test_only_water_and_glass_reflect() -> void:
	var water := 0
	for n in arena.find_children("*", "GeometryInstance3D", true, false):
		var m := (n as GeometryInstance3D).material_override as ShaderMaterial
		if m and m.shader and m.shader.resource_path.ends_with("puddle.gdshader"):
			water += 1
			assert_has(arena.detail.mirror.mats, m)
	assert_between(water, 1, 5, "one merged mesh per puddle shape and the glass")
	Graphics.apply(arena)
	assert_false(arena.env.ssr_enabled, "no screen-space reflections on dry floors")


func test_weak_turns_the_mirror_and_extras_off() -> void:
	var mirror := arena.detail.mirror
	Quality.apply("low")
	assert_eq(mirror.vp.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	assert_false(mirror.mats[0].get_shader_parameter("mirror"))
	assert_true(arena.detail._extras.all(func(e): return not e.visible), "no dust, steam or beams")
	Quality.apply("medium")
	assert_eq(mirror.vp.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	assert_true(mirror.mats[0].get_shader_parameter("mirror"))
	assert_true(arena.detail._extras.all(func(e): return e.visible))


func test_plated_floors_report_the_plates() -> void:
	# blood, telegraphs and gibs sit on the plates, not under them
	assert_almost_eq(arena.floor_height_at(-20, 20), WorldDetail.LIFT, 0.001)
	assert_almost_eq(arena.floor_height_at(16, 19.5), 3.0, 0.001, "a container top is not plated")


func test_no_floor_prop_is_knee_high() -> void:
	# owner's play-test (2026-10-24): a sprint kept catching on low props.
	# Props are flush (no collider) or a hop high; benches back onto the parapet.
	var d := arena.detail
	for box in d.prop_boxes:
		var mid := box.get_center()
		if box.position.y > arena.floor_height_at(mid.x, mid.z, box.position.y + 0.1) + 0.1:
			continue # a part on top of another (a vent's cap)
		var top := box.end.y
		for other in d.prop_boxes:
			if other.position.y >= box.position.y - 0.01 and other.position.y <= box.end.y + 0.01 and other.intersects(box.grow(0.01)):
				top = maxf(top, other.end.y)
		var rise := top - box.position.y
		var wall := arena.half - 0.1 # the parapet's inner face is at half
		var at_edge := maxf(absf(box.position.x), absf(box.end.x)) >= wall or maxf(absf(box.position.z), absf(box.end.z)) >= wall
		assert_true(rise >= WorldDetail.HOP - 0.01 or at_edge, "prop %s is a hop high (%.2f m) or backs onto the parapet" % [box, rise])


func test_a_sprint_never_stops_at_knee_height() -> void:
	# a player-sized capsule runs every way from a grid of floor spots; on a
	# flat floor nothing lower than a hop may stop it (walls, the parapet and
	# the map's 1.2 m hops are meant to)
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.floor_max_angle = deg_to_rad(50)
	body.floor_snap_length = 0.35
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = Player.CAPSULE_RADIUS
	cap.height = Player.CAPSULE_HEIGHT
	cs.shape = cap
	cs.position.y = Player.CAPSULE_HEIGHT * 0.5
	body.add_child(cs)
	arena.add_child(body)
	await wait_physics_frames(2)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	var space := arena.get_world_3d().direct_space_state
	var dt := 1.0 / 60.0
	var snags: Array[String] = []
	var x := -30.0
	while x <= 30.0:
		var z := -30.0
		while z <= 30.0:
			var below := INF
			for level in 4:
				var fy := arena.floor_height_at(x, z, below)
				if fy < -20.0:
					break
				below = fy - 0.5
				var start := Vector3(x, fy + 0.05, z)
				q.transform = Transform3D(Basis(), start + Vector3(0, Player.CAPSULE_HEIGHT * 0.5 + 0.05, 0))
				if not space.intersect_shape(q, 1).is_empty():
					continue
				for i in 8:
					var snag := _sprint(body, start, Vector3.FORWARD.rotated(Vector3.UP, i * PI / 4.0), dt)
					if snag != "":
						snags.append(snag)
			z += 3.0
		x += 3.0
	body.free()
	assert_true(snags.is_empty(), "nothing knee-high stops a sprint:\n" + "\n".join(snags))


func _sprint(body: CharacterBody3D, start: Vector3, dir: Vector3, dt: float) -> String:
	body.global_position = start
	body.velocity = Vector3.ZERO
	var prev := start
	for step in 40:
		var vy := 0.0 if body.is_on_floor() else body.velocity.y - 30.0 * dt
		body.velocity = dir * Player.WALK_SPEED + Vector3(0, vy, 0)
		body.move_and_slide()
		var moved := Vector2(body.global_position.x - prev.x, body.global_position.z - prev.z).length()
		prev = body.global_position
		if step < 3 or moved > Player.WALK_SPEED * dt * 0.35 or not body.is_on_floor() or body.get_floor_normal().y < 0.99:
			continue
		for k in body.get_slide_collision_count():
			var c := body.get_slide_collision(k)
			if c.get_normal().dot(-dir) < 0.5:
				continue
			var rise := c.get_position().y - body.global_position.y
			var top := rise
			var hit := c.get_collider_shape() as CollisionShape3D
			if hit and hit.shape is ConvexPolygonShape3D and body.global_position.y > WellMap.FLOOR + 1.0:
				continue # a roof ramp's side (KI-028); the pit's ramps are guarded
			if hit and hit.shape is BoxShape3D:
				top = hit.global_position.y + (hit.shape as BoxShape3D).size.y * 0.5 - body.global_position.y
			var edge := maxf(absf(body.global_position.x), absf(body.global_position.z)) > arena.half - 1.1 # the parapet, benches backed onto it
			if top > 0.15 and top < 0.99 and not edge: # 1 m beside the bridge: KI-029
				return "stopped at %s heading %s by a %.2f m block" % [body.global_position.snapped(Vector3(0.1, 0.1, 0.1)), dir.snapped(Vector3(0.1, 0.1, 0.1)), top]
		return ""
	return ""
