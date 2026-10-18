extends GutTest
## Deflected bolts go back to whoever fired them (spec §3.2 Deflect).


## An enemy with no body or brain: these tests only need where it stands.
class StandIn:
	extends Enemy

	func _ready() -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass


func _enemy(pos: Vector3) -> Enemy:
	var e := StandIn.new()
	e.setup("gunner")
	add_child_autofree(e)
	e.global_position = pos
	return e


func test_returns_to_its_shooter() -> void:
	var shooter := _enemy(Vector3(0, 0, -20))
	var in_the_way := _enemy(Vector3(0, 0, -5))
	# aimed straight at the nearer enemy, it still goes back to the shooter
	var dir := (Bolt.aim_point(in_the_way) - Vector3.ZERO).normalized()
	assert_eq(Bolt.pick_return_target(shooter, Vector3.ZERO, dir, [shooter, in_the_way]), shooter)


func test_dead_shooter_falls_back_to_enemy_along_the_aim() -> void:
	var shooter := _enemy(Vector3(0, 0, -20))
	shooter.dead = true
	var ahead := _enemy(Vector3(1, 0, -12))
	var behind := _enemy(Vector3(0, 0, 12))
	var picked := Bolt.pick_return_target(shooter, Vector3.ZERO, Vector3.FORWARD, [shooter, ahead, behind])
	assert_eq(picked, ahead)


func test_no_target_when_nobody_is_near_the_aim() -> void:
	var off_to_the_side := _enemy(Vector3(15, 0, -2))
	assert_null(Bolt.pick_return_target(null, Vector3.ZERO, Vector3.FORWARD, [off_to_the_side]))


func test_freed_shooter_is_not_a_target() -> void:
	var shooter := StandIn.new()
	shooter.free()
	assert_null(Bolt.pick_return_target(shooter, Vector3.ZERO, Vector3.FORWARD, []))


func test_setup_sets_and_clears_the_shooter() -> void:
	# a pooled bolt is set up again for every shot: no stale shooter or target
	var shooter := _enemy(Vector3(0, 0, -10))
	var b := Bolt.new()
	b.setup(true, Vector3.ZERO, Vector3.FORWARD * 11.0, 12.0, "bolt", shooter)
	assert_eq(b.shooter, shooter)
	b.target = shooter
	b.setup(true, Vector3.ZERO, Vector3.FORWARD * 11.0, 12.0)
	assert_null(b.shooter)
	assert_null(b.target)
	b.free()


func _returning_bolt(at: Enemy) -> Bolt:
	var b := Bolt.new()
	b.prewarm = true # built but parked: the test drives it by hand
	add_child_autofree(b)
	b.global_position = Vector3.ZERO
	b.vel = Vector3.FORWARD * 36.0
	b._set_target(at)
	b._returning = true
	return b


func test_a_respawned_shooter_is_a_different_enemy() -> void:
	# pooled enemies come back as new spawns; the bolt must not chase that
	var shooter := _enemy(Vector3(0, 0, -10))
	shooter.spawn_id = 5
	var b := Bolt.new()
	b.setup(true, Vector3.ZERO, Vector3.FORWARD * 11.0, 12.0, "bolt", shooter)
	assert_true(Bolt._same_spawn(shooter, b._shooter_spawn))
	shooter.spawn_id = 6
	assert_false(Bolt._same_spawn(shooter, b._shooter_spawn))
	b.free()


func test_takes_the_next_enemy_when_its_target_dies() -> void:
	var first := _enemy(Vector3(0, 0, -10))
	var next := _enemy(Vector3(0.5, 0, -16))
	var old_list := Game.enemy_list
	Game.enemy_list = [first, next]
	var b := _returning_bolt(first)
	first.dead = true
	b._steer()
	assert_eq(b.target, next)
	assert_true(b._returning)
	next.dead = true
	b._steer()
	assert_null(b.target)
	assert_false(b._returning, "nobody left: it flies straight and walls stop it again")
	Game.enemy_list = old_list


func test_freed_target_is_let_go() -> void:
	var boss := StandIn.new()
	boss.setup("gunner")
	add_child(boss)
	var old_list := Game.enemy_list
	Game.enemy_list = []
	var b := _returning_bolt(boss)
	boss.free() # bosses aren't pooled: they are freed when they die
	b._steer()
	assert_false(b._returning)
	Game.enemy_list = old_list


func test_mirror_copy_keeps_its_heading_and_damage() -> void:
	# a Yata Mirror copy fans out beside the returning bolt: no target, and
	# it keeps the speed and damage it was made with
	var shooter := _enemy(Vector3(0, 0, -20))
	var b := Bolt.new()
	b.prewarm = true
	add_child_autofree(b)
	b.setup(true, Vector3.ZERO, Vector3.FORWARD * 36.0, 96.0, "bolt", shooter)
	var dir := Vector3.FORWARD.rotated(Vector3.UP, 0.35)
	b.deflect(dir, true)
	assert_false(b.hostile)
	assert_null(b.target)
	assert_almost_eq(b.vel.length(), 36.0, 0.01)
	assert_almost_eq(b.vel.normalized().dot(dir), 1.0, 0.001)
	assert_eq(b.damage, 96.0)
