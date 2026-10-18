extends GutTest
## Seeds are law (spec §7.5): the same seed must always give the same run.
## These check the seeded parts that don't need a scene: the RNG streams,
## the palette, mutator rolls and wave line-ups.

const SEED := 0x1234ABCD


func after_each() -> void:
	Game.mutator = {}


func _start_run(s: int) -> void:
	Game.next_seed = s
	Game.reset_run()


func _lineup(wave: int) -> Array:
	var director := WaveDirector.new()
	director._rng = Game.rng_waves
	var lineup := director._composition(wave)
	director.free()
	return lineup


func test_same_seed_gives_same_streams() -> void:
	_start_run(SEED)
	var first := [Game.palette, Game.rng_map.randi(), Game.rng_waves.randi(), Game.rng_upgrades.randi()]
	_start_run(SEED)
	var again := [Game.palette, Game.rng_map.randi(), Game.rng_waves.randi(), Game.rng_upgrades.randi()]
	assert_eq(Game.run_seed, SEED)
	assert_eq_deep(again, first)


func test_different_seeds_give_different_streams() -> void:
	_start_run(SEED)
	var a := Game.rng_waves.randi()
	_start_run(SEED + 1)
	assert_ne(Game.rng_waves.randi(), a)


func test_streams_are_independent() -> void:
	# Drawing from one stream must not shift another, or a cosmetic roll
	# could change the waves.
	_start_run(SEED)
	var waves := Game.rng_waves.randi()
	_start_run(SEED)
	for i in 50:
		Game.rng_map.randi()
		Game.rng_upgrades.randi()
	assert_eq(Game.rng_waves.randi(), waves)


func test_seed_string_round_trips() -> void:
	# The results screen shows the seed; --seed=XXXX-XXXX must read it back.
	var shown := Game.seed_string(SEED)
	assert_eq(shown, "1234-ABCD")
	assert_eq(shown.replace("-", "").hex_to_int(), SEED)


func test_no_mutator_on_wave_one() -> void:
	_start_run(SEED)
	for i in 100:
		assert_eq(Mutators.roll(Game.rng_waves, 1), {})


func test_same_seed_gives_same_mutators() -> void:
	_start_run(SEED)
	var first := []
	for w in range(2, 30):
		first.append(Mutators.roll(Game.rng_waves, w).get("id", ""))
	_start_run(SEED)
	var again := []
	for w in range(2, 30):
		again.append(Mutators.roll(Game.rng_waves, w).get("id", ""))
	assert_eq_deep(again, first)


func test_same_seed_gives_same_wave_lineups() -> void:
	_start_run(SEED)
	var first := []
	for w in range(1, 13):
		first.append(_lineup(w))
	_start_run(SEED)
	var again := []
	for w in range(1, 13):
		again.append(_lineup(w))
	assert_eq_deep(again, first)


func test_early_waves_stay_small() -> void:
	# Waves 1 to 3 stay easy (spec §6.1): no brutes before wave 4.
	_start_run(SEED)
	for w in range(1, 4):
		for entry in _lineup(w):
			assert_ne(entry[0], "brute", "wave %d has a brute" % w)
