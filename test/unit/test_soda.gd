extends GutTest
## Soda cans (Soda, SodaCans; spec §19.1 #11): the flavour table, the effects
## a can puts on the run, the seeded spots, and the promise that with the dev
## switch off no can is ever made.

const SEED := 0x5EED0C4A

var arena: WellMap
var _saved_arena: Arena
var _saved_cans: bool


func before_all() -> void:
	Game.next_seed = SEED
	Game.reset_run()
	arena = WellMap.new()
	add_child(arena)
	arena.build()
	await wait_physics_frames(2)


func after_all() -> void:
	arena.queue_free()
	Quality.apply(Quality.DEFAULT)


func before_each() -> void:
	_saved_arena = Game.arena
	_saved_cans = DevSettings.cans
	Game.arena = arena
	DevSettings.can_flavour = ""


func after_each() -> void:
	Game.arena = _saved_arena
	DevSettings.cans = _saved_cans
	DevSettings.can_flavour = ""
	Game.combo = 0


func _cans(on: bool) -> SodaCans:
	DevSettings.cans = on
	var c := SodaCans.new()
	add_child_autofree(c)
	return c


func test_flavours_are_complete_and_short() -> void:
	var ids := {}
	var names := {}
	var builds := []
	for b in Upgrades.BUILDS:
		builds.append(b.id)
	for f in Soda.LIST:
		assert_false(ids.has(f.id), "id %s is unique" % f.id)
		assert_false(names.has(f.name), "name %s is unique" % f.name)
		ids[f.id] = true
		names[f.name] = true
		assert_lte(str(f.desc).length(), Soda.MAX_DESC, "%s fits the hint lane" % f.name)
		assert_gt(float(f.time), 0.0)
		assert_lt(float(f.crash_time), float(f.time), "%s: the crash is shorter than the buff" % f.name)
		assert_true(f.has("boosts") or f.has("flags"), "%s does something" % f.name)
		for b in f.builds:
			assert_has(builds, b, "%s feeds a real build" % f.name)
		assert_gte(int(f.get("min_wave", Soda.FIRST_WAVE)), Soda.FIRST_WAVE)


func test_names_are_not_taken_elsewhere() -> void:
	var taken := []
	for m in Mutators.LIST:
		taken.append(str(m.name).split(" ")[0].replace("'S", ""))
	for u in Upgrades.LIST:
		taken.append(str(u.name).split(" ")[0])
	for f in Soda.LIST:
		assert_does_not_have(taken, str(f.name).split(" ")[0], "%s's root word is free" % f.name)


func test_cans_per_wave() -> void:
	assert_eq(Soda.count_for_wave(1, false), 0, "none on wave 1")
	assert_eq(Soda.count_for_wave(2, false), 1)
	assert_eq(Soda.count_for_wave(3, true), 0, "none on boss waves")
	assert_eq(Soda.count_for_wave(Soda.TWO_FROM, false), 2)
	for f in Soda.pool_for_wave(3):
		assert_ne(f.id, "gaki", "the risk can waits for the later waves")


func test_off_means_no_cans_and_no_effect() -> void:
	var c := _cans(false)
	Game.seed_wave(4)
	c.on_wave_start(4, false)
	assert_eq(c._floor.size(), 0, "no can is made with the switch off")
	assert_eq(c.boost("speed"), 1.0)
	assert_false(c.flag("ignite"))


func test_spots_are_seeded_and_never_shift_other_streams() -> void:
	var a := _cans(true)
	Game.seed_wave(7)
	var spawns_state := Game.rng_spawns.state
	a.on_wave_start(7, false)
	assert_eq(Game.rng_spawns.state, spawns_state, "cans draw from their own stream")
	var first := []
	for f in a._floor:
		first.append([f.id, f.n.position])
	assert_eq(first.size(), 2)
	var b := _cans(true)
	Game.seed_wave(7)
	b.on_wave_start(7, false)
	var second := []
	for f in b._floor:
		second.append([f.id, f.n.position])
	assert_eq_deep(second, first)
	assert_gte(first[0][1].distance_to(first[1][1]), SodaCans.SPOT_GAP - 0.01, "the wave's cans sit apart")


func test_spots_are_on_the_map_and_open_above() -> void:
	var spots := arena.pickup_spots()
	assert_gt(spots.size(), 10)
	for s in spots:
		assert_lte(absf(s.x), arena.half, "inside the map")
		assert_lte(s.y, Arena.PICKUP_TOP + 0.01)


func test_a_drink_runs_buff_then_crash() -> void:
	var c := _cans(true)
	c.active = "kaze"
	c.phase = "buff"
	c.phase_t = 0.01
	assert_eq(c.boost("speed"), 1.25)
	assert_eq(c.boost("dash_recharge"), 0.5)
	c._end_phase()
	assert_eq(c.phase, "crash")
	assert_eq(c.boost("speed"), 1.0)
	assert_eq(c.boost("dash_recharge"), 1.5)
	c._end_phase()
	assert_eq(c.phase, "")
	assert_eq(c.boost("dash_recharge"), 1.0)


func test_uzume_holds_the_combo_then_halves_it() -> void:
	var c := _cans(true)
	c.active = "uzume"
	c.phase = "buff"
	assert_true(c.flag("combo_hold"))
	Game.combo = 20
	c._end_phase()
	assert_eq(Game.combo, 10)
	assert_eq(c.phase, "")


func test_restoring_a_run_keeps_only_real_cans() -> void:
	var c := _cans(false)
	c.restore(["kaze", "nope", "gaki", "yuki", "uzume"])
	assert_true(c.enabled, "a run saved with cans keeps them on")
	assert_eq(c.held, ["kaze", "gaki", "yuki"] as Array[String])


func test_a_cans_run_makes_no_top_10_entry() -> void:
	var saved := Profile.high_scores.duplicate(true)
	DevSettings.cans = true
	Game.reset_run()
	assert_true(Game.cans_run)
	Game.score = 99999999
	Game.record_score()
	assert_eq(Game.last_rank, -1)
	Profile.high_scores = saved
	DevSettings.cans = false
	Game.reset_run()
	assert_false(Game.cans_run)
