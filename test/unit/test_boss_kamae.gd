extends GutTest
## Boss KAMAE (posture, spec §5.5): pressure fills the bar, a full bar breaks
## the stance once, backing off drains it slowly, and recovering empties it.


func test_pressure_fills_and_breaks_once() -> void:
	var k := BossKamae.new(100.0)
	assert_false(k.add(60.0))
	assert_almost_eq(k.ratio(), 0.6, 0.001)
	assert_true(k.add(60.0), "the hit that fills the bar breaks it")
	assert_true(k.broken)
	assert_eq(k.ratio(), 1.0)
	assert_false(k.add(10.0), "a broken stance can't break again")


func test_no_drain_inside_the_grace_time() -> void:
	var k := BossKamae.new(100.0)
	k.add(50.0)
	k.update(BossKamae.GRACE - 0.1)
	assert_eq(k.value, 50.0)


func test_drains_slowly_after_backing_off() -> void:
	var k := BossKamae.new(100.0)
	k.add(50.0)
	k.update(BossKamae.GRACE + 0.01)
	k.update(1.0)
	assert_almost_eq(k.value, 50.0 - 100.0 * BossKamae.DRAIN, 0.5)
	k.update(60.0)
	assert_eq(k.value, 0.0, "never below empty")


func test_a_hurt_boss_drains_more_slowly() -> void:
	var full := BossKamae.new(100.0)
	var half := BossKamae.new(100.0)
	var last := BossKamae.new(100.0)
	for k: BossKamae in [full, half, last]:
		k.add(50.0)
	full.update(BossKamae.GRACE + 1.0, 1.0)
	half.update(BossKamae.GRACE + 1.0, 0.5)
	last.update(BossKamae.GRACE + 1.0, 0.0)
	assert_almost_eq(50.0 - full.value, 100.0 * BossKamae.DRAIN, 0.01)
	assert_almost_eq(50.0 - half.value, 100.0 * BossKamae.DRAIN * 0.65, 0.01)
	assert_almost_eq(50.0 - last.value, 100.0 * BossKamae.DRAIN * BossKamae.DRAIN_AT_NO_HP, 0.01)


func test_pressure_resets_the_grace_time() -> void:
	var k := BossKamae.new(100.0)
	k.add(50.0)
	k.update(BossKamae.GRACE - 0.5)
	k.add(1.0)
	k.update(BossKamae.GRACE - 0.5)
	assert_eq(k.value, 51.0)


func test_broken_bar_holds_until_recovered() -> void:
	var k := BossKamae.new(100.0)
	k.add(100.0)
	k.update(30.0)
	assert_eq(k.ratio(), 1.0)
	k.recover()
	assert_false(k.broken)
	assert_eq(k.value, 0.0)
	assert_false(k.add(10.0))


func test_sources() -> void:
	assert_gt(BossKamae.gain_for("katana", 18.0), 18.0, "the katana is the pressure tool")
	assert_lt(BossKamae.gain_for("shotgun", 100.0), 100.0)
	assert_eq(BossKamae.gain_for("burn", 50.0), 0.0, "burning never breaks a stance")
	assert_eq(BossKamae.gain_for("heavy", 100.0), 100.0, "Masamune Edge's heavy cut counts")
	assert_eq(BossKamae.gain_for("katana", -1.0), 0.0)
	assert_almost_eq(BossKamae.gain_for("deflect", 140.0, 80.0), 80.0 * BossKamae.DEFLECT_PER_DAMAGE, 0.001, "a returned bolt counts by its damage")


func test_bosses_ignore_hyakunin_giri() -> void:
	var b := Enemy.new()
	b.is_boss = true
	b.state = Enemy.S.CHASE
	b.stagger_now()
	assert_eq(b.state, Enemy.S.CHASE, "only a full KAMAE breaks a boss")
	assert_almost_eq(b.stagger_length(), b.stagger_time + BossKamae.BREAK_EXTRA, 0.001)
	b.free()
