extends GutTest
## Ledge climbing (spec §3.1): only ledges the hands can reach are climbed,
## and a jump that clears a ledge cleanly needs no climb. Uses a bare body
## with the player's capsule against plain boxes, on real physics.

const R := 0.4
const G := 26.0

var _body: CharacterBody3D


func before_each() -> void:
	_body = CharacterBody3D.new()
	_body.collision_layer = 2
	_body.collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = R
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	_body.add_child(cs)
	add_child_autofree(_body)


## A 6 m wide box whose near face is `gap` in front of the body (along -Z).
func _wall(top: float, gap := 0.02, bottom := 0.0) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, top - bottom, 4)
	cs.shape = box
	b.add_child(cs)
	b.position = Vector3(0, (top + bottom) * 0.5, -(R + gap + 2.0))
	add_child_autofree(b)


func _find(feet_y: float, vy := 0.0, dir := Vector3.FORWARD) -> Dictionary:
	_body.global_position = Vector3(0, feet_y, 0)
	return LedgeClimb.find(_body, dir, dir, R, vy, G)


func test_apex_gain() -> void:
	assert_almost_eq(LedgeClimb.apex_gain(9.4, G), 1.70, 0.01)
	assert_eq(LedgeClimb.apex_gain(-3.0, G), 0.0)


func test_grabs_a_ledge_within_reach() -> void:
	_wall(2.6)
	await wait_physics_frames(2)
	var found := _find(1.0)
	assert_false(found.is_empty(), "a ledge 1.6 m above the feet is grabbed")
	assert_almost_eq(float(found.get("ledge_y", 0.0)), 2.6, 0.01)


func test_never_grabs_above_reach() -> void:
	_wall(2.6)
	await wait_physics_frames(2)
	assert_true(_find(2.6 - LedgeClimb.REACH - 0.1).is_empty(), "just out of reach")
	assert_false(_find(2.6 - LedgeClimb.REACH + 0.05).is_empty(), "just in reach")


func test_tall_wall_is_never_climbed() -> void:
	_wall(12.0)
	await wait_physics_frames(2)
	for y in [0.5, 2.0, 4.0, 6.0]:
		assert_true(_find(y).is_empty(), "no ledge on a 12 m wall at feet %.1f" % y)


func test_clean_jump_needs_no_climb() -> void:
	_wall(2.0)
	await wait_physics_frames(2)
	# rising at 6 m/s from 1.0 m peaks near 1.7 m: short of 2.0, so climb
	assert_false(_find(1.0, 6.0).is_empty())
	# rising at 9 m/s from 1.0 m peaks near 2.6 m: clears it, no climb
	assert_true(_find(1.0, 9.0).is_empty())


func test_needs_room_on_top() -> void:
	_wall(2.4)
	_wall(4.0, 0.02, 2.9) # a slab 0.5 m over the ledge: no room to stand
	await wait_physics_frames(2)
	assert_true(_find(1.0).is_empty())


func test_must_push_into_the_wall() -> void:
	_wall(2.4)
	await wait_physics_frames(2)
	assert_true(_find(1.0, 0.0, Vector3.ZERO).is_empty(), "no input")
	assert_true(_find(1.0, 0.0, Vector3.BACK).is_empty(), "moving away")
