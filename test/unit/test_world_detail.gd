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
