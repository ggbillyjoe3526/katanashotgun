extends GutTest
## Wave mutators (spec §6.3): sound data, the opening waves stay gentle, no
## mutator twice in a row, and rolls stay in step with the seeded streams.

const SEED := 0x0A11CE55


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(s)
	return r


func test_data_is_consistent() -> void:
	var ids := {}
	var names := {}
	for m in Mutators.LIST:
		assert_false(ids.has(m.id), "duplicate id %s" % m.id)
		assert_false(names.has(m.name), "duplicate name %s" % m.name)
		ids[m.id] = true
		names[m.name] = true
		assert_gt(float(m.score), 1.0, "%s must pay for its risk" % m.id)
		# the HUD shows one decimal ("x1.3"), so the real value must match it
		assert_almost_eq(float(m.score), snappedf(float(m.score), 0.1), 0.0001, "%s score shows rounded" % m.id)
		# the wave intro shows the description on one line
		assert_lt(String(m.desc).length(), 56, "%s description too long" % m.id)
		assert_eq(String(m.desc), String(m.desc).to_upper(), "%s description must be upper case" % m.id)
	assert_eq(Mutators.get_def("grudge").name, "ONRYO'S GRUDGE")
	assert_eq(Mutators.get_def("nope"), {})


func test_harsh_mutators_wait_for_their_wave() -> void:
	for s in 300:
		for w in [2, 3]:
			var m := Mutators.roll(_rng(s * 7 + w), w)
			if not m.is_empty():
				assert_lte(int(m.get("min_wave", 2)), w, "%s on wave %d" % [m.id, w])


func test_never_the_same_twice_in_a_row() -> void:
	var rng := _rng(SEED)
	var last := ""
	for w in range(2, 400):
		var m := Mutators.roll(rng, w, last)
		if m.is_empty():
			continue
		assert_ne(m.id, last, "repeat on wave %d" % w)
		last = m.id


func test_every_mutator_comes_up() -> void:
	var seen := {}
	var rng := _rng(SEED)
	var last := ""
	for w in 2000:
		var m := Mutators.roll(rng, 4 + w % 20, last)
		if not m.is_empty():
			seen[m.id] = true
			last = m.id
	assert_eq(seen.size(), Mutators.LIST.size())


func test_a_roll_always_draws_twice() -> void:
	# whichever mutator comes up (or none), the wave stream moves the same
	# amount, so the line-ups after it don't depend on the pool's size
	for s in 50:
		var a := _rng(s)
		var b := _rng(s)
		Mutators.roll(a, 5, "storm")
		b.randf()
		b.randi()
		assert_eq(a.state, b.state)


func test_hazards_depend_only_on_seed_and_wave() -> void:
	Game.next_seed = SEED
	Game.reset_run()
	Game.seed_wave(4)
	var first := [Game.rng_hazards.randf(), Game.rng_hazards.randf()]
	Game.rng_waves.randi() # other streams moving must not matter
	Game.seed_wave(4)
	assert_eq_deep([Game.rng_hazards.randf(), Game.rng_hazards.randf()], first)
	Game.seed_wave(5)
	assert_ne(Game.rng_hazards.randf(), first[0])
