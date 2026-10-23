extends GutTest
## Boss movesets (spec §5.6): the floor hazards hit what they show, jumping
## clears them, and the first cycle keeps its big moves for after the enrage.


func test_zone_covers_its_ring() -> void:
	var h := BossHazard.zone(Vector3.ZERO, 2.6, 1.0, 10.0, Color.RED)
	assert_true(h.covers(Vector3(2.0, 0, 0)))
	assert_false(h.covers(Vector3(3.5, 0, 0)))
	assert_false(h.covers(Vector3(0, 1.5, 0)), "a jump clears it")
	h.jumpable = false
	assert_true(h.covers(Vector3(0, 1.5, 0)))
	h.free()


func test_line_covers_its_strip_only() -> void:
	var h := BossHazard.line(Vector3.ZERO, Vector3(1, 0, 0), 14.0, 1.6, 0.8, 10.0, Color.RED)
	assert_true(h.covers(Vector3(7.0, 0, 0.5)))
	assert_false(h.covers(Vector3(7.0, 0, 2.0)), "beside the line is safe")
	assert_false(h.covers(Vector3(-2.0, 0, 0)), "behind its start is safe")
	assert_false(h.covers(Vector3(16.0, 0, 0)), "past its end is safe")
	assert_false(h.covers(Vector3(7.0, 1.2, 0)), "a jump clears it")
	h.free()


func test_first_cycle_waits_for_the_enrage() -> void:
	var b := Boss.new()
	b.cycle = 1
	assert_false(b._big_moves_on())
	b.enraged = true
	assert_true(b._big_moves_on())
	b.enraged = false
	b.cycle = 2
	assert_true(b._big_moves_on(), "later cycles fight with everything")
	b.free()


func test_first_boss_telegraphs_longer() -> void:
	var b := Boss.new()
	var killed := Game.bosses_killed
	Game.bosses_killed = 0
	b.cycle = 1
	assert_eq(b._tele(), Boss.GENTLE_TELE)
	b.cycle = 2
	assert_eq(b._tele(), 1.0)
	Game.bosses_killed = killed
	b.free()


func test_a_cut_short_red_signal_never_leaves_the_boss_hidden() -> void:
	var b := Boss.new()
	b.visual = Node3D.new()
	b.add_child(b.visual)
	b._red_mark = MeshInstance3D.new()
	b.add_child(b._red_mark)
	# a child of the boss, so freeing the boss takes it too (no orphan)
	var mark := Node3D.new()
	b.add_child(mark)
	b._line_marks.append(mark)
	b.visual.visible = false
	b.collision_layer = 0
	b.state = Enemy.S.RED_ACT
	b._tidy_red()
	assert_false(b.visual.visible, "hidden on purpose mid NULL CROSS")
	assert_eq(b._line_marks.size(), 1)
	b.state = Enemy.S.STAGGER
	b._tidy_red()
	assert_true(b.visual.visible)
	assert_eq(b.collision_layer, 4)
	assert_eq(b._line_marks.size(), 0, "its red lines go with it")
	assert_false(b._red_mark.visible)
	b.free()
