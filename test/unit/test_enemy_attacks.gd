extends GutTest
## Enemy attacks and hit feel (spec §4, §3.9): every wave enemy visibly holds
## its weapon, the weapon's edge is the telegraph, and aim assist only ever
## helps toward a foe that is really close to the crosshair.


## An enemy with no body or brain: the aim assist tests only need where it stands.
class StandIn:
	extends Enemy

	func _ready() -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass


func _built(kind: String) -> Enemy:
	var e := Enemy.new()
	e.setup(kind)
	e.prewarm = true # built and parked, as a pool does at load
	add_child_autofree(e)
	return e


func _stand_in(pos: Vector3, kind := "grunt") -> Enemy:
	var e := StandIn.new()
	e.setup(kind)
	add_child_autofree(e)
	e.global_position = pos
	return e


func test_every_wave_enemy_holds_a_weapon() -> void:
	for kind in ["grunt", "gunner", "brute"]:
		var e := _built(kind)
		assert_not_null(e._weapon, "%s has a weapon" % kind)
		assert_not_null(e._weapon_glow, "%s's weapon has a glowing edge" % kind)
		assert_true(e._weapon.visible, "%s's weapon shows" % kind)
		assert_true(e._weapon_tip.is_inside_tree(), "%s's weapon has a tip" % kind)


func test_a_grunt_is_armed_on_every_spawn() -> void:
	# pooled grunts re-roll their looks on every spawn; none comes back unarmed
	var e := _built("grunt")
	for i in 20:
		e.reuse()
		e.setup("grunt")
		assert_true(e._weapon.visible)
		assert_true(e._weapon_glow != null)


func test_the_edge_heats_through_the_windup() -> void:
	var e := _built("brute")
	e._set_weapon_heat(0.0)
	var cold: float = e._weapon_glow.get_shader_parameter("energy")
	e._set_weapon_heat(1.0)
	var hot: float = e._weapon_glow.get_shader_parameter("energy")
	assert_gt(hot, cold * 3.0, "white-hot when the blow lands")
	var c: Color = e._weapon_glow.get_shader_parameter("albedo_color")
	assert_gt(c.b, 0.6, "white-hot, not just red")


func test_the_red_arc_ends_where_the_blow_reaches() -> void:
	# standing outside the arc must mean the blow missed (the owner's "close = hurt")
	for kind in ["grunt", "brute"]:
		var e := _built(kind)
		var reach := e.strike_reach()
		assert_almost_eq(e.radius * 0.4 + e.swing_radius(reach), reach, 0.001, kind)


func test_a_cut_short_windup_cools_the_edge() -> void:
	var e := _built("grunt")
	e._set_state(Enemy.S.WINDUP)
	e._set_weapon_heat(0.9)
	e._set_state(Enemy.S.STAGGER)
	var energy: float = e._weapon_glow.get_shader_parameter("energy")
	assert_almost_eq(energy, 1.4, 0.01, "back to its idle glow")


func test_lunge_picks_a_foe_just_out_of_reach() -> void:
	var near := _stand_in(Vector3(0, 0, -4.6))
	var origin := Vector3(0, 1.55, 0)
	assert_eq(Player.assist_lunge_pick(origin, Vector3.FORWARD, [near], 3.4), near)


func test_lunge_leaves_foes_in_reach_far_or_off_to_the_side() -> void:
	var origin := Vector3(0, 1.55, 0)
	var in_reach := _stand_in(Vector3(0, 0, -2.5))
	var too_far := _stand_in(Vector3(0, 0, -8.0))
	var aside := _stand_in(Vector3(4.0, 0, -4.0)) # 45 degrees off the crosshair
	var dead := _stand_in(Vector3(0.3, 0, -4.4))
	dead.dead = true
	assert_null(Player.assist_lunge_pick(origin, Vector3.FORWARD, [in_reach, too_far, aside, dead], 3.4))


func test_lunge_prefers_the_foe_nearest_the_crosshair() -> void:
	var origin := Vector3(0, 1.55, 0)
	var ahead := _stand_in(Vector3(0, 0, -5.0))
	var off := _stand_in(Vector3(1.8, 0, -4.2))
	assert_eq(Player.assist_lunge_pick(origin, Vector3.FORWARD, [off, ahead], 3.4), ahead)


func test_a_near_miss_blast_bends_onto_the_body() -> void:
	var origin := Vector3(0, 1.55, 0)
	var e := _stand_in(Vector3(0.8, 0, -10.0)) # crosshair passes 0.35 m off its side
	var bent := Player.assist_shot_dir(origin, Vector3.FORWARD, [e])
	assert_false(bent.is_equal_approx(Vector3.FORWARD), "the blast bends")
	# the bent centre now passes inside the body
	var t := (e.global_position.z - origin.z) / bent.z
	var at := origin + bent * t
	assert_lt(absf(at.x - e.global_position.x), e.radius)
	assert_lt(Vector3.FORWARD.angle_to(bent), Player.ASSIST_SHOT_MAX + 0.001)


func test_a_clear_miss_or_a_hit_is_left_alone() -> void:
	var origin := Vector3(0, 1.55, 0)
	var wide := _stand_in(Vector3(2.5, 0, -10.0))
	assert_eq(Player.assist_shot_dir(origin, Vector3.FORWARD, [wide]), Vector3.FORWARD)
	var on := _stand_in(Vector3(0.2, 0, -10.0))
	assert_eq(Player.assist_shot_dir(origin, Vector3.FORWARD, [on, wide]), Vector3.FORWARD)
	var behind := _stand_in(Vector3(0.6, 0, 10.0))
	assert_eq(Player.assist_shot_dir(origin, Vector3.FORWARD, [behind]), Vector3.FORWARD)


func test_assist_keeps_the_height_you_aimed_at() -> void:
	# aimed just over the head: the blast bends to the head, not the chest
	var e := _stand_in(Vector3(0.0, 0, -10.0))
	e.radius = 0.1 # thin, so the crosshair is off to its side
	var origin := Vector3(0.3, 1.55, 0)
	var bent := Player.assist_shot_dir(origin, Vector3(0, 0.02, -1).normalized(), [e])
	var t := (e.global_position.z - origin.z) / bent.z
	var at := origin + bent * t
	assert_gt(at.y, e.global_position.y + e.head_y - 0.1, "still a headshot")


func test_aim_assist_is_saved_and_defaults_on() -> void:
	var saved := Settings.to_dict()
	Settings.reset_controls()
	assert_true(Settings.aim_assist)
	Settings.aim_assist = false
	var d := Settings.to_dict()
	Settings.aim_assist = true
	Settings.from_dict(d)
	assert_false(Settings.aim_assist)
	Settings.from_dict({"aim_assist": "yes"}) # wrong type: kept as it was
	assert_false(Settings.aim_assist)
	Settings.from_dict(saved)
