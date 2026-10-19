extends GutTest
## Ground spawns (tunnels, lifts, hatches) have a roof over them, so enemies
## walk out instead of dropping in. The rest of a spawn group lands up to
## 2 m to the side and must walk out too: dropped from 9 m, it stuck in the
## tunnel roof and the wave could never be cleared.

var arena: Arena


func before_each() -> void:
	arena = Arena.new()
	arena.ground_spawns = [Vector3(-10.5, -10, 0)]


func after_each() -> void:
	arena.free()


func test_a_ground_spawn_walks_out() -> void:
	assert_eq(arena.spawn_clearance(Vector3(-10.5, -10, 0)), 0.3)


func test_the_rest_of_its_group_walks_out_too() -> void:
	for off in [Vector3(2, 0, 2), Vector3(-2, 0, -2), Vector3(-1.7, 0, -1.6), Vector3(1.5, 0, 1.0)]:
		assert_eq(arena.spawn_clearance(Vector3(-10.5, -10, 0) + off), 0.3, str(off))


func test_open_ground_drops_from_the_sky() -> void:
	assert_eq(arena.spawn_clearance(Vector3(-20, 0, -16)), 9.0)
	# right above the tunnel, on the level over it: still a sky drop
	assert_eq(arena.spawn_clearance(Vector3(-10.5, -5, 0)), 9.0)
