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


func test_floor_height_picks_the_floor_under_the_caller() -> void:
	# the torii bridge (+5) crosses the shaft above the metro platform (-10)
	assert_almost_eq(arena.floor_height_at(0, 0), 5.0, 0.01)
	assert_almost_eq(arena.floor_height_at(0, 0, 4.0), -10.0, 0.01)
	assert_almost_eq(arena.floor_height_at(0, -10, 0.0), -5.0, 0.01, "north service block")
	assert_almost_eq(arena.floor_height_at(0, 20), 0.0, 0.01, "roof ring")


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


func test_traffic_follows_the_quality_preset() -> void:
	Quality.apply("low")
	assert_eq(arena.backdrop._cars.visible_instance_count, Quality.cap("traffic"))
	Quality.apply("high")
	assert_eq(arena.backdrop._cars.visible_instance_count, mini(Quality.cap("traffic"), arena.backdrop._cars.instance_count))
