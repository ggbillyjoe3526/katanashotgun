extends GutTest
## Seeds are law (spec §7.5): the same seed must always give the same run.
## These check the seeded parts that don't need a scene: the RNG streams,
## the palette, mutator rolls, wave plans, and that no script reaches for
## Godot's unseeded global random functions. tools/seed_check.sh checks a
## whole autoplay run.

const SEED := 0x1234ABCD


func after_each() -> void:
	Game.mutator = {}


func _start_run(s: int) -> void:
	Game.next_seed = s
	Game.reset_run()


## Plans waves 1 to `last` the way a run does. With `noise`, every stream
## is drawn from a random number of times between waves, standing in for
## however the fights went.
func _plans(last: int, noise: RandomNumberGenerator = null) -> Array:
	var director := WaveDirector.new()
	director._rng = Game.rng_waves
	director._spawn_rng = Game.rng_spawns
	var out := []
	for w in range(1, last + 1):
		director.plan_wave(w)
		out.append([Game.mutator.get("id", ""), director.boss_kind if director.is_boss_wave(w) else "", director.queue.duplicate(true)])
		if noise != null:
			for rng: RandomNumberGenerator in [Game.rng_waves, Game.rng_spawns, Game.rng_combat, Game.rng_hazards, Game.rng_map]:
				for i in noise.randi_range(0, 400):
					rng.randi()
	director.free()
	return out


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


func test_wave_plans_ignore_how_the_waves_were_played() -> void:
	# The bug this guards: spawns drew from the wave stream mid-fight, so a
	# longer or shorter wave 3 changed wave 4's mutator and line-up.
	_start_run(SEED)
	var calm := _plans(16)
	for k in 5:
		var noise := RandomNumberGenerator.new()
		noise.seed = k
		_start_run(SEED)
		assert_eq_deep(_plans(16, noise), calm)


func test_wave_plans_differ_between_seeds() -> void:
	_start_run(SEED)
	var a := _plans(8)
	_start_run(SEED + 1)
	assert_ne(str(_plans(8)), str(a))


func test_no_script_uses_global_randomness() -> void:
	# randf(), randi() and friends, Array.shuffle() and pick_random() use
	# Godot's global generator, which no seed controls. Gameplay uses the
	# seeded streams in Game; presentation uses Game.rng_fx or its own RNG.
	var re := RegEx.create_from_string("(?<![\\w.])(randf|randi|randf_range|randi_range|randfn|randomize|seed)\\(|\\.(shuffle|pick_random)\\(\\)")
	var hits := []
	for path in _scripts("res://scripts"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].get_slice("#", 0)
			if re.search(code) != null:
				hits.append("%s:%d" % [path, i + 1])
	assert_eq(hits, [], "global randomness in: %s" % ", ".join(hits))


func _scripts(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out


func test_a_resumed_run_plans_the_same_waves() -> void:
	# A suspended run keeps only the director's boss cycle and last mutator
	# (RunSnapshot); the wave streams reseed when the next wave starts.
	_start_run(SEED)
	var straight := _plans(12)
	_start_run(SEED)
	var first := WaveDirector.new()
	first._rng = Game.rng_waves
	first._spawn_rng = Game.rng_spawns
	for w in range(1, 8):
		first.plan_wave(w)
	_start_run(SEED) # the game restarts on the same seed before resuming
	var resumed := WaveDirector.new()
	resumed._rng = Game.rng_waves
	resumed._spawn_rng = Game.rng_spawns
	resumed._boss_cycle = first._boss_cycle.duplicate()
	resumed._cycle_count = first._cycle_count
	resumed.last_mutator = first.last_mutator
	for w in range(8, 13):
		resumed.plan_wave(w)
		var got := [Game.mutator.get("id", ""), resumed.boss_kind if resumed.is_boss_wave(w) else "", resumed.queue]
		assert_eq_deep(got, straight[w - 1])
	first.free()
	resumed.free()
