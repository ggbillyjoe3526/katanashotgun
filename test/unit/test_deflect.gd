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
