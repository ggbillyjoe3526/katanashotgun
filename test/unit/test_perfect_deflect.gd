extends GutTest
## PERFECT deflects: a slash in the last moment before a bolt lands, and the
## bosses' signature volleys (spec §3.2 Perfect deflect).

const CHEST := Vector3(0, 1, 0)
const HIT := 0.85 # a bolt's radius + 0.5: what touches the player


## An enemy with no body or brain: these tests only need its data.
class StandIn:
	extends Enemy

	func _ready() -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass


func _enemy(k: String) -> Enemy:
	var e := StandIn.new()
	e.setup(k)
	add_child_autofree(e)
	return e


func _bolt(pos: Vector3, vel: Vector3) -> Bolt:
	var b := Bolt.new()
	b.prewarm = true # built but parked: the test drives it by hand
	add_child_autofree(b)
	b.setup(true, pos, vel, 12.0)
	return b


func test_time_to_hit_head_on() -> void:
	var t := Bolt.time_to_hit(Vector3(0, 1, -10), Vector3(0, 0, 10), CHEST, HIT)
	assert_almost_eq(t, (10.0 - HIT) / 10.0, 0.001)


func test_a_bolt_flying_away_never_lands() -> void:
	assert_eq(Bolt.time_to_hit(Vector3(0, 1, -10), Vector3(0, 0, -10), CHEST, HIT), INF)


func test_a_clear_miss_never_lands() -> void:
	# passes 3 m to the side
	assert_eq(Bolt.time_to_hit(Vector3(3, 1, -10), Vector3(0, 0, 10), CHEST, HIT, Bolt.PERFECT_NEAR_MISS), INF)


func test_a_near_miss_counts_at_its_closest_point() -> void:
	# passes 1.2 m to the side: outside the body, inside the near-miss margin
	var t := Bolt.time_to_hit(Vector3(1.2, 1, -10), Vector3(0, 0, 10), CHEST, HIT, Bolt.PERFECT_NEAR_MISS)
	assert_almost_eq(t, 1.0, 0.001)


func test_already_touching_is_zero() -> void:
	assert_eq(Bolt.time_to_hit(Vector3(0, 1, -0.5), Vector3(0, 0, 10), CHEST, HIT), 0.0)


func test_perfect_window_is_the_last_moment() -> void:
	var speed := 11.0 # a gunner's bolt
	var late := _bolt(Vector3(0, 1, -(HIT + speed * Bolt.PERFECT_WINDOW * 0.8)), Vector3(0, 0, speed))
	assert_true(late.in_perfect_window(CHEST), "deflected just before it lands: PERFECT")
	var early := _bolt(Vector3(0, 1, -(HIT + speed * Bolt.PERFECT_WINDOW * 1.5)), Vector3(0, 0, speed))
	assert_false(early.in_perfect_window(CHEST), "a normal deflect earlier than that")


func test_only_hostile_bolts_can_be_perfect() -> void:
	var b := _bolt(Vector3(0, 1, -1.2), Vector3(0, 0, 11))
	b.hostile = false
	assert_false(b.in_perfect_window(CHEST))


func test_a_perfect_return_hits_harder_than_a_normal_one() -> void:
	assert_gt(Bolt.PERFECT_DAMAGE_MULT, Bolt.RETURN_DAMAGE_MULT)


func test_a_signature_volley_pays_its_kamae_hit_once() -> void:
	var boss := _enemy("oni")
	var first := boss.next_signature()
	assert_true(boss.claim_signature(first), "the first perfect on the volley pays")
	assert_false(boss.claim_signature(first), "the rest of that volley does not")
	var second := boss.next_signature()
	assert_ne(first, second)
	assert_true(boss.claim_signature(second), "the next volley pays again")


func test_ordinary_enemies_have_no_signature() -> void:
	var gunner := _enemy("gunner")
	assert_false(gunner.claim_signature(1))


func test_reuse_clears_the_perfect_state() -> void:
	# a pooled bolt must not carry a signature, a perfect or a KAMAE bonus
	# into its next shot
	var b := _bolt(Vector3.ZERO, Vector3.FORWARD * 11.0)
	b.mark_signature(3)
	b.perfect = true
	b.kamae_bonus = Bolt.SIGNATURE_KAMAE
	b.reuse()
	assert_eq(b.volley, 0)
	assert_false(b.perfect)
	assert_eq(b.kamae_bonus, 0.0)
	assert_eq(b._halo_size, 1.0)
	b.mark_signature(4)
	b.setup(true, Vector3.ZERO, Vector3.FORWARD * 11.0, 12.0)
	assert_eq(b.volley, 0, "setup starts every shot ordinary")
