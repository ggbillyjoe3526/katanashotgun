extends GutTest
## The vertical Shin-Kagura map (WellMap): stacked floors, spawns and the
## navmesh enemies use to move between levels.

const SEED := 0x5EED0042

var arena: WellMap


func before_all() -> void:
	Game.next_seed = SEED
	Game.reset_run()
	arena = WellMap.new()
	add_child(arena)
	arena.build()
	var map := arena.get_world_3d().navigation_map
	for i in 120:
		await wait_physics_frames(1)
		if NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point(map, arena.player_spawn) != Vector3.ZERO:
			break


func after_all() -> void:
	arena.queue_free()
	Quality.apply(Quality.DEFAULT)


func _reach(from: Vector3, to: Vector3, layers: int) -> bool:
	var path := NavigationServer3D.map_get_path(arena.get_world_3d().navigation_map, from, to, true, layers)
	return path.size() > 0 and path[path.size() - 1].distance_to(to) < 1.5


func test_the_skyline_never_draws_from_the_map_stream() -> void:
	# KI-025: the weather is rolled from the map stream after the skyline is
	# built, so the skyline keeps to its own stream
	assert_eq(arena.backdrop.rng.seed, hash([SEED, "skyline"]))
	var state := Game.rng_map.state
	var city := CityBackdrop.new()
	arena.add_child(city)
	city.build(arena)
	assert_eq(Game.rng_map.state, state, "building a skyline leaves the map's dice alone")
	city.free()


func test_floor_height_picks_the_floor_under_the_caller() -> void:
	# the torii bridge (+5) crosses the shaft above the metro platform (-10);
	# the floors are plated (WorldDetail), so they report the plates' top
	var lift := WorldDetail.LIFT
	assert_almost_eq(arena.floor_height_at(0, 0), 5.0 + lift, 0.01)
	assert_almost_eq(arena.floor_height_at(0, 0, 4.0), -10.0 + lift, 0.01)
	assert_almost_eq(arena.floor_height_at(0, -10, 0.0), -5.0 + lift, 0.01, "north service block")
	assert_almost_eq(arena.floor_height_at(0, 20), 0.0 + lift, 0.01, "roof ring")


func test_falls_reset_below_the_metro_floor() -> void:
	assert_lt(arena.kill_y + 2.0, WellMap.FLOOR - 2.0, "enemies on the metro floor must not be reset")


func test_every_spawn_reaches_the_player() -> void:
	for sp in arena.spawn_points:
		assert_true(_reach(sp, arena.player_spawn, Arena.NAV_WALK | Arena.NAV_LEAP), "spawn %s reaches the player" % sp)


func test_every_level_reaches_every_spawn() -> void:
	for sp in arena.spawn_points:
		assert_true(_reach(arena.player_spawn, sp, Arena.NAV_WALK | Arena.NAV_LEAP), "an enemy can follow the player to %s" % sp)


func test_ramps_alone_join_the_main_levels() -> void:
	# without leaps (how the autoplay bot moves): metro, service, roof, bridge, catwalk, deck, tower
	for p in [Vector3(0, -10, 0), Vector3(0, -5, -10), Vector3(0, 5, 0), Vector3(24.5, 5, 0), Vector3(0, 5, -23), Vector3(4, 10, -26)]:
		assert_true(_reach(arena.player_spawn, p, Arena.NAV_WALK), "ramps lead to %s" % p)


func test_leap_links_land_on_the_navmesh() -> void:
	var map := arena.get_world_3d().navigation_map
	for l in arena.nav_links:
		for end in l:
			var q := NavigationServer3D.map_get_closest_point(map, end)
			assert_lt(Vector2(q.x - end.x, q.z - end.z).length(), 0.6, "link end %s is walkable" % end)
			assert_lt(absf(q.y - end.y), 1.0, "link end %s is on its floor" % end)


func test_spawn_points_are_clear() -> void:
	var space := arena.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	for sp in arena.spawn_points:
		q.transform = Transform3D(Basis.IDENTITY, sp + Vector3(0, 1.0, 0))
		assert_eq(space.intersect_shape(q, 1).size(), 0, "spawn %s is not inside a wall" % sp)
		var drop := arena.spawn_clearance(sp)
		if drop > 1.0:
			var ray := PhysicsRayQueryParameters3D.create(sp + Vector3(0, 0.5, 0), sp + Vector3(0, drop + 2.0, 0), 1)
			assert_true(space.intersect_ray(ray).is_empty(), "sky drop at %s has open sky" % sp)


func test_ground_spawns_walk_out() -> void:
	assert_gt(arena.ground_spawns.size(), 0)
	for g in arena.ground_spawns:
		assert_has(arena.spawn_points, g)
		assert_lt(arena.spawn_clearance(g), 1.0)


func test_geyser_pads_on_every_level() -> void:
	# owner, 2026-10-22: pads on every level, not only the metro platform
	var levels := {}
	for jp in arena.jump_pads:
		levels[snappedf(jp.pos.y, 0.1)] = true
	for y in [WellMap.FLOOR, WellMap.SERVICE, 0.0, WellMap.DECK]:
		assert_true(levels.has(y), "a geyser pad at %s m" % y)


func test_geyser_pads_stand_clear() -> void:
	var space := arena.get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	for jp in arena.jump_pads:
		var p: Vector3 = jp.pos
		var r: float = jp.r
		# the whole pad stands on its own floor (plates aside: its cell is bare)
		for k in 8:
			var e := p + Vector3(r, 0, 0).rotated(Vector3.UP, k * TAU / 8.0)
			assert_almost_eq(arena.floor_height_at(e.x, e.z, p.y + 0.5), p.y, 0.1, "pad %s is on one floor" % p)
		# open air over its middle for the whole launch and a body's height
		# above that (the metro pad's edge is under the bridge it throws you to)
		var rise: float = jp.launch.y * jp.launch.y / (2.0 * Player.GRAVITY)
		shape.radius = r * 0.5
		shape.height = rise + 2.0
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.3 + shape.height * 0.5, 0))
		assert_eq(space.intersect_shape(q, 1).size(), 0, "nothing over the pad at %s" % p)
		# never under the roof of the edge walls: the launch can't carry anyone off the map
		assert_lt(p.y + rise + Player.DOUBLE_JUMP_VEL * Player.DOUBLE_JUMP_VEL / (2.0 * Player.GRAVITY), 26.0, "pad %s stays under the edge walls" % p)
		# enemies arrive and leap clear of it
		for sp in arena.spawn_points:
			if absf(sp.y - p.y) < 2.5:
				assert_gt(Vector2(sp.x - p.x, sp.z - p.z).length(), 3.0, "pad %s is clear of spawn %s" % [p, sp])
		for l in arena.nav_links:
			for end in l:
				if absf(end.y - p.y) < 2.5:
					assert_gt(Vector2(end.x - p.x, end.z - p.z).length(), 2.5, "pad %s is clear of leap spot %s" % [p, end])
		assert_gt(Vector2(arena.boss_spawn.x - p.x, arena.boss_spawn.z - p.z).length(), 5.0, "pad %s is clear of the boss" % p)
		assert_gt(Vector2(arena.player_spawn.x - p.x, arena.player_spawn.z - p.z).length(), 4.0, "pad %s is clear of the start" % p)


func test_traffic_follows_the_quality_preset() -> void:
	Quality.apply("low")
	assert_eq(arena.backdrop._cars.visible_instance_count, Quality.cap("traffic"))
	Quality.apply("high")
	assert_eq(arena.backdrop._cars.visible_instance_count, mini(Quality.cap("traffic"), arena.backdrop._cars.instance_count))
	# the spec and wiki say MEDIOCRE and INSANE both show every car
	for q in ["medium", "high"]:
		assert_eq(Quality.CAPS[q].traffic, arena.backdrop._cars.instance_count, q)


func test_graphics_presets_reach_the_well() -> void:
	# the lamp haze is MEDIOCRE's; WEAK leaves the map as built
	assert_gt(arena.find_children("*", "OmniLight3D", true, false).size(), 0, "the Well has lamps")
	Quality.apply("medium")
	var haze: Array = arena.get_meta(&"gfx_haze", [])
	assert_gt(haze.size(), 0)
	assert_true(haze.all(func(q): return q.visible))
	Quality.apply("low")
	assert_true(haze.all(func(q): return not q.visible))


func test_backdrop_traffic_stays_out_of_global_illumination() -> void:
	var movers := arena.backdrop.find_children("*", "MultiMeshInstance3D", true, false).filter(
		func(m): return (m as MultiMeshInstance3D).multimesh.instance_count > 0 and m.custom_aabb.size.x > 300.0)
	assert_eq(movers.size(), 1, "the traffic MultiMesh")
	assert_eq(movers[0].gi_mode, GeometryInstance3D.GI_MODE_DISABLED)


## Where a boss would drop in for a player standing at `feet` facing `facing`
## (spec §5.1), with the eye where the camera sits.
func _drop(feet: Vector3, facing: Vector3, room := 1.0) -> Vector3:
	return arena.boss_drop_point(feet + Vector3(0, 1.6, 0), feet, facing, room)


func _in_sight(feet: Vector3, at: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(feet + Vector3(0, 1.6, 0), at + Vector3(0, 1.2, 0), 1)
	return arena.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func test_a_boss_drops_in_where_you_are_looking() -> void:
	# William waited and looked around for KUROKAGE: it always dropped on the
	# north roof, often behind him
	for facing in [Vector3(0, 0, -1), Vector3(1, 0, -1).normalized(), Vector3(-1, 0, 0)]:
		var feet := arena.player_spawn
		var at := _drop(feet, facing)
		var flat := Vector3(at.x - feet.x, 0, at.z - feet.z)
		assert_ne(at, arena.boss_spawn, "not the fixed spot, facing %s" % facing)
		assert_between(flat.length(), 6.0, 20.0, "near, facing %s" % facing)
		assert_lt(rad_to_deg(flat.angle_to(facing)), Arena.BOSS_DROP_VIEW + 0.1, "in view, facing %s" % facing)
		assert_almost_eq(at.y, arena.floor_height_at(feet.x, feet.z, feet.y + 0.5), 0.3, "on your floor, facing %s" % facing)
		assert_true(_in_sight(feet, at), "in sight, facing %s" % facing)


func test_with_your_back_to_the_wall_it_still_lands_near_you() -> void:
	var feet := arena.player_spawn
	var at := _drop(feet, Vector3(0, 0, 1), 2.2) # facing the south edge, Tetsugumo's room
	assert_ne(at, arena.boss_spawn)
	assert_lt(Vector2(at.x - feet.x, at.z - feet.z).length(), 20.5)
	assert_true(_in_sight(feet, at))


func test_from_the_pit_it_lands_where_you_can_see_it() -> void:
	for facing in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0)]:
		var feet := Vector3(0, WellMap.FLOOR + WorldDetail.LIFT, 0)
		var at := _drop(feet, facing, 1.6)
		assert_ne(at, arena.boss_spawn, "facing %s" % facing)
		assert_true(_in_sight(feet, at), "in sight, facing %s" % facing)
